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

**Já vale:** domínios como namespaces em `apps/api/app/domains/<contexto>/`, sem Engines. Comunicação apenas por `<Contexto>::Api` e eventos, conforme as regras do modelo de domínio.

**Fica para a Fase 01:** o mecanismo de verificação (alternativa 2 ou 3), com critério de escolha: detectar no CI uma violação plantada, com o menor custo de manutenção.

## Justificativa

Namespaces entregam a separação necessária hoje. A verificação é o que impede erosão, e a ferramenta só pode ser avaliada com uma aplicação Rails real.

## Consequências

- Revisores recebem a regra de que modelos de outro contexto não podem ser referenciados.
- A Fase 01 inclui um teste que demonstra a falha ao violar o limite.
- Extrair um domínio continua possível.

## Estado da decisão

Proposta
