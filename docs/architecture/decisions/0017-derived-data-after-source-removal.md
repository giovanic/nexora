# 0017 — Dados derivados após remover a origem

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-GAME-009, FR-STRAVA-011, FR-STRAVA-012

## Contexto

Desconectar o Strava, apagar uma refeição ou revogar um consentimento remove dados de origem. XP, metas, sequências, relatórios e notificações podem ter sido derivados desses dados. O termo do Strava manda apagar os dados ao encerrar o uso ([fontes](../EXTERNAL_SOURCES.md)). **Não foi verificado** se isso alcança dados derivados. Estornar XP em massa ao desconectar criaria um custo para quem exerce um direito.

## Problema

O que acontece com o que foi derivado, sem violar o termo e sem punir quem remove os próprios dados?

## Alternativas

1. **Estorno completo:** todo derivado é desfeito. Coerente, mas a pessoa perde o progresso ao revogar.
2. **Manter o saldo agregado, removendo o vínculo com a origem:** o nível permanece, e datas e referências do Strava somem. Preserva a pessoa, mas depende de o agregado não contar como dado do Strava.
3. **Recalcular em silêncio, sem exibir perda:** resultado honesto, sem penalidade visível, com mais complexidade.

## Decisão

**Já vale:**

- Eventos de exclusão causados por remoção de origem carregam o motivo `source_revoked`, para que consumidores não os tratem como ação da pessoa sobre uma atividade.
- A interface nunca apresenta a remoção de dados como perda ou punição.
- Projeções guardam `provider`, para apagamento seletivo.
- Eventos relacionados na outbox são apagados na desconexão.

**Fica para a Fase 04:** escolher a alternativa, relendo o termo vigente e perguntando ao Strava, se a dúvida permanecer. Definir também quais derivados contam como dados do Strava. A Fase 04 repete a varredura de apagamento, e as Fases 05 a 08 também, quando criarem novos derivados.

**Proposta a validar:** alternativa 2, se o termo permitir.

## Justificativa

A escolha depende da leitura de um termo de terceiro e, em parte, de revisão jurídica. Registrar agora evita que o comportamento surja por acidente.

## Consequências

- A certificação de apagamento ao Strava depende desta decisão.
- `xp_transactions`, `goal_check_ins` e projeções precisam identificar a origem.

## Estado da decisão

Proposta
