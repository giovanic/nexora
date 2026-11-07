# Fase 05 — Goals Engine

- **Estado:** ver [STATUS.md](../STATUS.md), nas linhas `05`, `05.1` e `05.2`
- **Requisitos:** FR-GOALS-001, FR-GOALS-002, FR-GOALS-003, FR-GOALS-004, FR-GOALS-005, FR-GOALS-006, FR-GOALS-007, FR-GOALS-008, FR-GOALS-009
- **ADRs:** [0011](../../architecture/decisions/0011-no-calorie-goals.md), [0016](../../architecture/decisions/0016-closed-beta-milestone.md)

Dividida em duas etapas: `05.1` vai para o beta e não depende do Strava; `05.2` vem depois da Fase 04.

## Objetivo

Metas de hábito configuráveis e acompanhadas por regras reproduzíveis, priorizando consistência, atividades adequadas e recuperação, sem mecanismos de restrição alimentar ou de compensação.

## Escopo

**Etapa 05.1 inclui:** contexto Goals; catálogo de tipos permitidos; metas diárias; check-in manual; progresso e conclusão; histórico; telas móveis.

**Etapa 05.2 inclui:** metas semanais; planejamento da semana; confirmação automática por atividades; dias de recuperação; adaptação à rotina; sugestão por esporte e nível.

**Não inclui:** meta ou teto de calorias, déficit, peso, compensação de comida com exercício, XP (Fase 06).

## Funcionalidades

### Etapa 05.1

- **Tipos permitidos**, em lista fechada, por exemplo: `log_meals`, `include_vegetables`, `drink_water`, `sleep_routine`, `planned_workout`. O plano confirma a lista.
- **Criar, editar e pausar** metas diárias.
- **Check-in manual,** um por dia, considerando o fuso da pessoa. A meta de registrar refeições também pode avançar por `food_entry.confirmed`.
- **Regras versionadas e determinísticas:** os mesmos check-ins geram o mesmo resultado, mesmo depois de uma mudança de regra, por causa de `rule_version`.
- **Histórico** por dia e por meta.
- **Rejeição:** tipos proibidos são recusados pela API e pelo banco, com mensagem neutra.

### Etapa 05.2

- **Metas semanais** e planejamento.
- **Confirmação automática** por `activity.imported`. A exclusão de atividade recalcula a meta.
- **Dias de recuperação** planejados, publicando `recovery_day.planned` e `recovery_day.logged`.
- **Adaptação:** mudar o plano no meio da semana não pune, e a tela sugere ajustes em vez de cobrar.
- **Sugestões** por esporte e nível.

## Dependências

- **Etapa 05.1:** Fase 02 concluída; Fase 03 para metas ligadas a refeições.
- **Etapa 05.2:** etapa 05.1 e Fase 04 concluídas.
- **Fontes:** nenhuma externa.

## Arquivos e módulos esperados

```text
apps/api/app/domains/goals/
apps/api/db/migrate/    goals, goal_check_ins (05.1); weekly_plans (05.2)
apps/mobile/src/features/goals/
```

## Critérios de aceite

### Etapa 05.1

- `AC-05.1-01` (FR-GOALS-001): metas diárias podem ser criadas, editadas e pausadas a partir dos tipos permitidos. **Comprovado por:** testes de requisição e demonstração no app.
- `AC-05.1-02` (FR-GOALS-002): o check-in respeita o fuso, inclusive perto da meia-noite, e é único por dia. **Comprovado por:** testes com fusos e horários fixos.
- `AC-05.1-03` (FR-GOALS-003): reexecutar a avaliação sobre os mesmos check-ins dá o mesmo resultado. **Comprovado por:** teste de propriedade ou tabela de casos.
- `AC-05.1-04` (FR-GOALS-004): o histórico é paginado e isolado por pessoa. **Comprovado por:** testes.
- `AC-05.1-05` (FR-GOALS-005): tipos de calorias, déficit, peso ou compensação são rejeitados pela API, e uma inserção direta é recusada pelo banco. **Comprovado por:** testes de requisição e de constraint.

### Etapa 05.2

- `AC-05.2-01` (FR-GOALS-006): metas semanais e planejamento funcionam. **Comprovado por:** testes e demonstração.
- `AC-05.2-02` (FR-GOALS-007): uma atividade importada confirma a meta, sem duplicar em reprocessamento, e excluir a atividade recalcula, publicando `goal.uncompleted` quando deixar de valer. **Comprovado por:** testes de idempotência e estorno.
- `AC-05.2-03` (FR-GOALS-008): dias de recuperação contam a favor, e mudar o plano não gera punição. **Comprovado por:** testes.
- `AC-05.2-04` (FR-GOALS-009): sugestões variam conforme o esporte e o nível, e nenhuma é de tipo proibido. **Comprovado por:** testes.

## Testes

- Tabela de regras de conclusão.
- Fuso e meia-noite, incluindo mudança de fuso e horário de verão.
- Idempotência dos consumidores de evento.
- Textos contra a lista de [segurança de saúde](../../security/HEALTH_DATA_SAFETY.md).
- Exclusão de conta alcança metas e check-ins.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Pedidos por meta de calorias | Pressão para mudar o produto | Registrar no beta; só o responsável reabre a ADR 0011 |
| Meta vira culpa | Abandono ou dano | Linguagem neutra, pausa fácil, adaptação sem punição |
| Fuso calculado de forma errada | Check-in em dia errado | `local_date` no registro, com testes |

## Entregáveis

Contexto Goals, telas, contrato atualizado e relatório por etapa.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), por etapa. A linha `05` só é concluída quando as duas etapas estiverem concluídas.

## Estratégia de revisão

`software-architect` (eventos), `backend-reviewer` (regras, idempotência), `security-reviewer` (segurança de produto), `frontend-mobile-reviewer` (tom e estados), `qa-reviewer`. O responsável aprova cada etapa em separado.
