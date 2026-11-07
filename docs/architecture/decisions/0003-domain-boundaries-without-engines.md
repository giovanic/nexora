# 0003 — Limites de domínio sem Rails Engines

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-002

## Contexto

O [modelo de domínio](../DOMAIN_MODEL.md) define 12 contextos e regras de dependência. O Master Prompt pede para não criar Rails Engines por domínio sem justificativa concreta. Sem verificação automática, os limites tendem a se perder com o tempo, sobretudo em trabalho feito por agentes.

## Problema

Como manter os limites entre domínios de forma verificável, com o mínimo de infraestrutura?

## Alternativas

1. **Namespaces, sem verificação:** barato, mas os limites dependem só da revisão.
2. **Namespaces com teste de dependência próprio:** um teste analisa referências entre namespaces. Sem dependência nova, mas exige manutenção.
3. **Namespaces com Packwerk:** ferramenta conhecida para isso, com suporte a dependências declaradas. Acrescenta dependência e configuração; o estado atual não foi verificado.
4. **Rails Engine por domínio:** isolamento forte, mas 12 engines trazem custo alto de migrations, rotas e testes.

## Decisão

Domínios como namespaces em `apps/api/app/domains/<contexto>/`, sem Engines. Comunicação apenas por `<Contexto>::Api` e eventos, conforme as regras do modelo de domínio.

**Mecanismo: alternativa 2.** Um teste próprio em RSpec, `spec/architecture/domains_spec.rb`, usa `Architecture::DomainBoundaryCheck`, que percorre `app/domains/**/*.rb` com o Prism, parser que vem com o Ruby. A lista de dependências permitidas fica em `config/domain_boundaries.yml`.

O teste falha quando:

- uma referência a outro contexto não é exatamente `<Contexto>::Api`, inclusive em herança e em string com forma de constante, como `class_name: "FoodCatalog::Item"`;
- a dependência não consta da lista;
- há ciclo, contexto sem regra, ou arquivo que não pode ser analisado.

## Evidência

Avaliação de 2026-11-06, em Ruby 4.0.9:

| Alternativa | Dependência proibida (`Goals` → `Gamification::Api`) | Interno de contexto permitido (`Nutrition` → `FoodCatalog::Item`) | Custo observado |
|---|---|---|---|
| Teste próprio | Detecta | Detecta | Cerca de 100 linhas, sem gem nova |
| Packwerk 3.3.1 | Detecta | **Não detecta** | No Gemfile, a resolução trava o RuboCop em 1.74, que recusa Ruby 4.0 |

O `USAGE.md` do Packwerk declara: *"Packwerk ships with dependency boundary checking only."* A verificação de visibilidade dependeria de outra gem, não avaliada.

Violação plantada na árvore real: `app/domains/goals/planted.rb`, referenciando `Gamification::Api`, faz `spec/architecture/domains_spec.rb` falhar; removida, ele volta a passar. No CI, a prova está no relatório da Fase 01.

## Justificativa

Namespaces entregam a separação necessária hoje. A verificação é o que impede erosão, e o critério era detectar a violação com o menor custo de manutenção: o teste próprio cobre a regra central, "só `<Contexto>::Api`", sem dependência nova.

## Consequências

- Revisores recebem a regra de que modelos de outro contexto não podem ser referenciados.
- **Limite conhecido:** referências montadas em tempo de execução, como `constantize` com string dinâmica, e SQL direto não são detectados. Ficam com os revisores.
- **Limite conhecido:** a verificação é por contexto, não por método. As regras 3 e 7 do modelo de domínio restringem métodos, como `consent_granted?` e `time_zone`, e isso também fica com os revisores.
- **Contradição a resolver na Fase 02:** a regra 3 do modelo libera Identity para todos, mas as seções "Permitido" de vários contextos não o citam. Vale a lista mais restritiva, das seções. Ao implementar `confirm_deletion`, a Fase 02 amplia `config/domain_boundaries.yml` de forma explícita.
- Quem adiciona um contexto precisa declarar suas regras, ou o teste falha.
- Extrair um domínio continua possível.

## Estado da decisão

Aceita
