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
3. **Namespaces com Packwerk:** ferramenta conhecida para isso, com suporte a dependências declaradas. Acrescenta dependência e configuração. Avaliado abaixo, com fontes no [registro](../EXTERNAL_SOURCES.md).
4. **Rails Engine por domínio:** isolamento forte, mas 12 engines trazem custo alto de migrations, rotas e testes.

## Decisão

Domínios como namespaces em `apps/api/app/domains/<contexto>/`, sem Engines. Comunicação apenas por `<Contexto>::Api` e eventos, conforme as regras do modelo de domínio.

**Mecanismo: alternativa 2.** Um teste próprio em RSpec, `spec/architecture/domains_spec.rb`, usa `Architecture::DomainBoundaryCheck`, que percorre com o Prism, parser que vem com o Ruby, `app/domains` e também `app/controllers`, `app/jobs`, `app/models` e `app/services`. A lista de dependências permitidas fica em `config/domain_boundaries.yml`.

O teste falha quando:

- uma referência a outro contexto não é exatamente `<Contexto>::Api`, inclusive em herança e em string com forma de constante, como `class_name: "FoodCatalog::Item"`;
- a dependência não consta da lista;
- um domínio declara `polymorphic: true`, que alcança a tabela de qualquer contexto sem citar constante alguma;
- código fora de `app/domains` reabre o namespace de um contexto ou usa algo além de `<Contexto>::Api`;
- aparece arquivo novo em `app/jobs`, `app/models` ou `app/services` fora da lista fechada de infraestrutura, porque uma constante sem namespace, como `FoodEntry`, não pode ser ligada a um contexto;
- há ciclo, contexto sem regra, ou arquivo que não pode ser analisado.

**Estrutura interna dos contextos:** `models/`, `services/` e `jobs/` só organizam arquivos, então `app/domains/nutrition/models/food_entry.rb` define `Nutrition::FoodEntry`. As demais pastas, como `adapters/`, `events/` e `consumers/`, fazem parte do nome da constante. Consequência: um modelo não pode ter o nome do próprio contexto, então o perfil em User Profile é `UserProfile::Profile`, e não `UserProfile::UserProfile`.

**Progress & Analytics** não acessa Food AI nem Strava Integration, porque dados do Strava não podem chegar a um provedor de IA. A Fase 08 amplia a lista se precisar, com justificativa.

## Evidência

Avaliação de 2026-11-06, em Ruby 4.0.9:

| Alternativa | Dependência proibida (`Goals` → `Gamification::Api`) | Interno de contexto permitido (`Nutrition` → `FoodCatalog::Item`) | Custo observado |
|---|---|---|---|
| Teste próprio | Detecta | Detecta | Cerca de 100 linhas, sem gem nova |
| Packwerk 3.3.1 | Detecta | **Não detecta** | No Gemfile, a resolução trava o RuboCop em 1.74, que recusa Ruby 4.0 |

O `USAGE.md` do Packwerk declara: *"Packwerk ships with dependency boundary checking only."* A verificação de visibilidade dependeria de outra gem, não avaliada.

Violação plantada na árvore real: `app/domains/goals/planted.rb`, referenciando `Gamification::Api`, fez `spec/architecture/domains_spec.rb` falhar; removida, ele voltou a passar. A execução em 2026-11-06 foi local. A prova no CI é pendência da Tarefa 13 do plano da Fase 01, com o link registrado no relatório da fase.

Estrutura interna: `zeitwerk:check` aprova um arquivo plantado em `models/`, `services/` e `jobs/` de um contexto (`spec/architecture/domain_layout_spec.rb`).

## Justificativa

Namespaces entregam a separação necessária hoje. A verificação é o que impede erosão, e o critério era detectar a violação com o menor custo de manutenção: o teste próprio cobre a regra central, "só `<Contexto>::Api`", sem dependência nova.

## Consequências

- Revisores recebem a regra de que modelos de outro contexto não podem ser referenciados.
- **Limites conhecidos, que ficam com os revisores:**
  - referências montadas em tempo de execução, como `constantize` com string dinâmica ou `const_get`;
  - apelidos, como `Atalho = FoodCatalog::Api`, e `Object::FoodCatalog::Item`;
  - acesso a tabela de outro contexto por SQL, `joins` com string ou `self.table_name`;
  - uma `Api` que devolva um modelo, o que a regra 1 do modelo de domínio proíbe e a análise de constantes não enxerga;
  - restrições por método, como `consent_granted?` e `time_zone`, porque a verificação é por contexto;
  - cliente externo chamado direto no domínio, em vez de ficar atrás de um adaptador.
- **Contradição a resolver na Fase 02:** a regra 3 do modelo libera Identity para todos, mas as seções "Permitido" de vários contextos não o citam. Vale a lista mais restritiva, das seções. Ao implementar a exclusão de conta, a Fase 02 decide entre o registro em `shared/` da regra 8, que manteria a lista, e ampliá-la de forma explícita.
- Quem adiciona um contexto precisa declarar suas regras, ou o teste falha.
- Extrair um domínio continua possível.

## Estado da decisão

Aceita
