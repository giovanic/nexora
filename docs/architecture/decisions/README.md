# Registro de decisões de arquitetura (ADRs)

Toda decisão técnica relevante fica aqui, no formato do [modelo](TEMPLATE.md). Decisão hipotética não aparece como definitiva.

## Estados

| Estado | Significado |
|---|---|
| `Proposta` | Alternativas descritas, decisão ainda não definitiva. Pode ter uma parte que já vale, separada no campo Decisão |
| `Aceita` | Decisão em vigor |
| `Rejeitada` | Avaliada e descartada |
| `Substituída` | Trocada por outra ADR, indicada no texto |

## Regras

- ADR aceita não é editada, exceto para mudar o estado. Mudança de decisão gera uma nova ADR, que substitui a anterior.
- Uma ADR `Proposta` diz como e em que fase será decidida.
- Critérios de aceite de uma fase podem depender de uma decisão `Proposta` apenas se a própria fase incluir o passo de decidi-la, ou se dependerem só da parte que a ADR declara como "já vale".
- Decisões que dependem de fato externo apontam para o [registro de fontes](../EXTERNAL_SOURCES.md).
- Numeração sequencial de quatro dígitos: `NNNN-slug-em-ingles.md`.

## Índice

| ADR | Título | Estado | Quando decidir |
|---|---|---|---|
| [0001](0001-modular-monolith-monorepo.md) | Monólito modular em monorepo | Aceita | n/a |
| [0002](0002-technology-baseline.md) | Baseline de tecnologias e versões | Aceita | n/a |
| [0003](0003-domain-boundaries-without-engines.md) | Limites de domínio sem Rails Engines | Aceita | n/a |
| [0004](0004-domain-events-transactional-outbox.md) | Eventos de domínio com outbox transacional | Proposta | Fila decidida na Fase 01; o restante na Fase 02 |
| [0005](0005-authentication-strategy.md) | Estratégia de autenticação | Aceita | n/a |
| [0006](0006-food-ai-pipeline-and-provider-abstraction.md) | Pipeline de Food AI e abstração de provedor | Proposta | Fase 03 |
| [0007](0007-nutrition-data-sources.md) | Bases de dados nutricionais | Proposta | Fase 03 |
| [0008](0008-strava-data-boundaries.md) | Limites de uso dos dados do Strava | Aceita | n/a |
| [0009](0009-gamification-safety-principles.md) | Princípios de segurança da gamificação | Aceita | n/a |
| [0010](0010-adults-only-mvp-and-consent.md) | MVP só para adultos e consentimento | Aceita | n/a |
| [0011](0011-no-calorie-goals.md) | Sem meta de calorias | Proposta | Após o M1 |
| [0012](0012-monetization-options.md) | Opções de monetização | Proposta | Após o M1 |
| [0013](0013-sport-ranking.md) | Ranking por esporte | Proposta | Fora das nove fases |
| [0014](0014-api-contract-tooling.md) | Ferramentas de contrato da API | Aceita | n/a |
| [0015](0015-hosting-and-deployment.md) | Hospedagem e deploy | Proposta | M1 |
| [0016](0016-closed-beta-milestone.md) | Marco de beta fechado | Aceita | n/a |
| [0017](0017-derived-data-after-source-removal.md) | Dados derivados após remover a origem | Proposta | Fase 04 |
| [0018](0018-application-level-encryption.md) | Cifragem em nível de aplicação | Aceita | n/a |
