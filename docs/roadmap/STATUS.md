# Estado das fases

Fonte única sobre em que ponto o projeto está. Regras em [PHASE_EXECUTION_PROTOCOL.md](PHASE_EXECUTION_PROTOCOL.md). O registro de transições só recebe inclusões, e toda mudança tem data e evidência.

A linha `05` é um resumo de `05.1` e `05.2`.

## Estado atual

| Linha | Estado | Desde | Evidência |
|---|---|---|---|
| 00 | Concluída | 2026-11-06 | [Relatório](reports/PHASE_00_REPORT.md) e mensagem do responsável de 2026-11-06, com a lacuna do check `scope` aceita |
| 01 | Concluída | 2026-11-11 | [Relatório](reports/PHASE_01_REPORT.md) e mensagem do responsável de 2026-11-11: "Aprovo a Fase 01." Lacuna aceita: AC-01-07 sem envio real ao Sentry, pendente antes do M1 |
| 02 | Em desenvolvimento | 2026-11-13 | Teste instável da web reprovou o CI do PR #18 ([execução 43490332198](https://github.com/giovanic/nexora/actions/runs/43490332198)); correção autorizada pelo responsável em 2026-11-13 |
| 03 | Não iniciada | 2026-11-05 | — |
| 04 | Não iniciada | 2026-11-05 | — |
| 05 | Não iniciada | 2026-11-05 | — |
| 05.1 | Não iniciada | 2026-11-05 | — |
| 05.2 | Não iniciada | 2026-11-05 | — |
| 06 | Não iniciada | 2026-11-05 | — |
| 07 | Não iniciada | 2026-11-05 | — |
| 08 | Não iniciada | 2026-11-05 | — |
| 09 | Não iniciada | 2026-11-05 | — |
| M1 | Não iniciada | 2026-11-05 | — |

## Registro de transições

| Data | Linha | De | Para | Evidência |
|---|---|---|---|---|
| 2026-11-05 | 00 | Não iniciada | Em desenvolvimento | [Design aprovado](../superpowers/specs/2026-11-05-engineering-harness-design.md) e [plano](../superpowers/plans/2026-11-05-engineering-harness.md) aprovados pelo responsável |
| 2026-11-05 | 00 | Em desenvolvimento | Em revisão | [Relatório](reports/PHASE_00_REPORT.md), com a lacuna do check `scope` aguardando decisão do responsável |
| 2026-11-06 | 00 | Em revisão | Concluída | [Relatório](reports/PHASE_00_REPORT.md) e mensagem do responsável de 2026-11-06: "Aprovo a Fase 00, aceitando a lacuna do check scope." Lacuna aceita: `FALHA scope` em `apps` e `packages` enquanto a linha 01 não estiver em desenvolvimento |
| 2026-11-06 | 01 | Não iniciada | Em planejamento | Mensagem do responsável de 2026-11-06: "Vamos iniciar a fase 01." |
| 2026-11-06 | 01 | Em planejamento | Em desenvolvimento | [Plano](../superpowers/plans/2026-11-06-foundation.md) e mensagem do responsável de 2026-11-06: "Aprovo o plano da Fase 01, com execução na sessão." |
| 2026-11-11 | 01 | Em desenvolvimento | Em revisão | [Relatório](reports/PHASE_01_REPORT.md), com o AC-01-07 parcial por decisão do responsável |
| 2026-11-11 | 01 | Em revisão | Concluída | [Relatório](reports/PHASE_01_REPORT.md) e mensagem do responsável de 2026-11-11: "Aprovo a Fase 01." Lacuna aceita: AC-01-07 sem envio real ao Sentry, pendente antes do M1 |
| 2026-11-11 | 02 | Não iniciada | Em planejamento | Mensagem do responsável de 2026-11-11: "Vamos iniciar a fase 02." |
| 2026-11-11 | 02 | Em planejamento | Em desenvolvimento | [Plano](../superpowers/plans/2026-11-11-identity-security.md) e mensagem do responsável de 2026-11-11: "nova sessao com subagentes" (execução por subagent-driven-development, em sessão nova) |
| 2026-11-13 | 02 | Em desenvolvimento | Em revisão | [Relatório](reports/PHASE_02_REPORT.md): todas as verificações executadas em 2026-11-13 no commit `6b832a4`, sem achado crítico ou importante em aberto; AC-02-07 parcial (textos aguardam aprovação), AC-02-08 parcial (FR-PROFILE-001 e 003), AC-02-11 aguarda o aceite das ADRs; CI do PR pendente da autorização de push |
| 2026-11-13 | 02 | Em revisão | Concluída | [Relatório](reports/PHASE_02_REPORT.md) e mensagem do responsável de 2026-11-13: "Aprovo os textos de consentimento v1. Aceito as ADRs 0004, 0005 e 0018. Pode fazer o push e abrir o PR. Aprovo a Fase 02." Lacuna aceita: AC-02-08 parcial (FR-PROFILE-001: preferências de notificação na Fase 08 e unidades só `metric`; FR-PROFILE-003: metas e XP ainda não existem). [PR #18](https://github.com/giovanic/nexora/pull/18), [CI 43489537643](https://github.com/giovanic/nexora/actions/runs/43489537643) com 6 de 6 jobs verdes |
| 2026-11-13 | 02 | Concluída | Em desenvolvimento | Defeito: o teste "stays on the page and offers a retry when sign out fails" (`apps/web/src/features/privacy/PrivacyScreen.test.tsx:206`) confere o foco antes de o efeito do React rodar e reprovou o CI do PR #18 ([execução 43490332198](https://github.com/giovanic/nexora/actions/runs/43490332198)); reproduzido localmente 1 vez em 8 execuções da suíte web. Correção autorizada pelo responsável em 2026-11-13: "Autorizo a correção" |
