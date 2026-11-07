# 0008 — Limites de uso dos dados do Strava

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-STRAVA-001, FR-STRAVA-011, FR-STRAVA-013, NFR-PRIVACY-006

## Contexto

O API Agreement do Strava, em vigor desde 2026-06-01 ([fontes](../EXTERNAL_SOURCES.md)), diz: *"Strava Data provided by a specific user can only be displayed or disclosed in your Developer Application to that user."* Também diz: *"You may not create applications that compete with or replicate Strava functionality."* Ao encerrar, todos os dados precisam ser apagados, com certificação por escrito. O texto lido não menciona IA ou machine learning. Violações podem levar à revogação do token.

## Problema

O que o produto pode fazer com dados vindos do Strava sem violar os termos e sem perder a integração?

## Alternativas

1. **Usar os dados em qualquer função interna e social:** viola os termos.
2. **Dados apenas para o dono, com escopo mínimo, sem IA:** seguro, reduz alguns recursos.
3. **Dados apenas para o dono, permitindo envio à IA por não haver menção:** ausência de texto não é autorização, e o risco é perder a integração.

## Decisão

Alternativa 2:

- Dados do Strava são exibidos **somente ao dono**. Isso inclui atividades, derivados que revelem dados dele, relatórios e qualquer ranking futuro.
- Escopo mínimo: `activity:read`. Outros só com ADR.
- **Sem envio a provedores de IA** até uma reavaliação documentada (NFR-PRIVACY-006).
- Sem funcionalidades que repliquem o Strava: feed, segmentos, comentários, kudos, leaderboards.
- Desconexão, revogação e encerramento apagam todos os dados.
- Código e tabelas guardam `provider`, para que a origem de cada dado seja sempre identificável.

## Justificativa

Os termos são claros quanto à exibição, e a integração é valiosa demais para arriscar. Quanto à IA, a postura conservadora tem custo baixo, porque a Fase 08 pode gerar insights por regras.

## Consequências

- A Fase 08 precisa gerar relatórios sobre atividades sem enviá-las à IA, ou reavaliar esta decisão.
- Um ranking não pode usar dados do Strava ([ADR 0013](0013-sport-ranking.md)).
- XP de atividades vindas do Strava permanece privado ao dono.
- O termo pode mudar. A Fase 04 consulta de novo a versão vigente.

## Estado da decisão

Aceita
