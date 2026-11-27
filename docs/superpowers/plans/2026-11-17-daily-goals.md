# Etapa 05.1 — Metas diárias: plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: `superpowers:subagent-driven-development` ou `superpowers:executing-plans`, tarefa a tarefa. Passos em checkbox.

**Objetivo:** a pessoa cria, pausa, encerra e apaga metas diárias de hábito de uma lista fechada, marca hoje ou ontem com um toque, vê os dias cumpridos, e a meta de refeições fecha sozinha com a primeira refeição confirmada do dia.

**Arquitetura:** novo contexto `Goals` em `apps/api/app/domains/goals`, com `Goals::Api` como única entrada. O estado de um dia não é gravado: sai dos check-ins mais a regra de `rule_version`. Goals chama só `UserProfile::Api` (`config/domain_boundaries.yml`: `goals: [user_profile]`) e ouve `food_entry.confirmed` e `food_entry.deleted` da Nutrition pela outbox. Publica `goal.created`, `goal.completed`, `goal.uncompleted` e `goal.deleted`, sem consumidor nesta etapa.

**Tecnologias:** Rails 8.1, Ruby 4.0.9, PostgreSQL 18, Sidekiq (outbox existente), Expo SDK 58 com expo-router.

**Spec:** [design aprovado](../specs/2026-11-17-daily-goals-design.md) (2026-11-17, "aprovo"). Leia junto com o [documento da fase](../../roadmap/phases/PHASE_05_GOALS.md). Os `AC-05.1-*` são a definição de pronto, e as seções do design são citadas como "design 4.x".

## Restrições globais

- TDD em todo passo de código: escreva o teste, veja falhar pelo motivo certo, implemente, veja passar.
- **Nenhuma dependência nova**, gem ou npm.
- Nesta máquina o shell exporta `RBENV_VERSION=3.3.4`. Rode todo comando Ruby com `RBENV_VERSION=4.0.9` (ex.: `cd apps/api && RBENV_VERSION=4.0.9 bundle exec rspec`).
- Controllers e código fora de `app/domains/goals` usam só `Goals::Api`, que devolve objetos `Data`, nunca modelos. `bundle exec rspec spec/architecture` impõe isso.
- Toda rota nova entra antes em `packages/contracts/openapi.yaml`. Depois: `npm run generate -w @app/contracts`, `expect_response_to_match_contract` nos request specs, `spec/contract/routes_spec.rb` e `spec/contract/no_calorie_goal_spec.rb` verdes.
- Tipos de meta, exatamente: `log_meals`, `include_fruits_vegetables`, `drink_water`, `sleep_routine`, `planned_workout` (design 4.1).
- `rule_version` inicial: `daily_any_v1`. `cadence` só `daily`, `target` só `1`.
- Nada de `goal_type`, datas, fontes ou ids de refeição em log, Sentry, `error_code` ou mensagem de exceção. `error_code` de lista fechada.
- Todas as rotas de Goals: `require_consent :health_data, except: :destroy`. Meta de outra pessoa ou id malformado: `404`.
- Textos neutros: nada de "falhou", "perdeu", "não esqueça", "!" ou cor de alerta. `apps/mobile/src/features/goals` entra na verificação de linguagem (`scripts/check_language.py`).
- Commits pequenos na branch `phase/05.1-daily-goals`, num worktree. Sem push sem autorização.

## Foco de revisão

1. **Meia-noite com a tela aberta:** a tela de hoje foi carregada às 23:58 e a pessoa toca "Feito" em "Ontem" depois da meia-noite. A data enviada virou anteontem, a API responde `422 outside_window`, e o app mostra "Só dá para marcar hoje ou ontem." e recarrega, sem marcar nada errado. Teste na Tarefa 8.
2. **Toque duplo ou toque junto com a refeição:** dois `POST` iguais, ou um check-in manual chegando com `food_entry.confirmed` no mesmo dia. O resultado é um só check-in manual e um só `goal.completed`. Teste na Tarefa 4.
3. **Evento de refeição para meta que sumiu:** a meta foi apagada, ou a conta foi excluída, entre a publicação e o consumo. O consumidor termina sem erro, sem retentativa e sem dead letter. Teste na Tarefa 5.
4. **Perfil pendente:** `UserProfile::Api.time_zone` devolve `nil` logo após o cadastro, e a janela usa UTC sem quebrar. Teste na Tarefa 2.
5. **Sem rede no toque:** o botão não muda de estado antes da resposta. Com falha, o app mostra o erro com "Tentar de novo" e mantém o estado anterior. Teste na Tarefa 8.

---

## Tarefa 0: Branch, worktree e registro

**Arquivos:** `docs/roadmap/STATUS.md`, o design e este plano.

- [ ] Na `main` (a cópia de trabalho tem o `STATUS.md` alterado, o design e este plano): `git switch -c phase/05.1-daily-goals`, `git add docs/roadmap/STATUS.md docs/superpowers/specs/2026-11-17-daily-goals-design.md docs/superpowers/plans/2026-11-17-daily-goals.md`, commit `docs: plan phase 05.1 daily goals`, e `git switch main` (agora limpa).
- [ ] `superpowers:using-git-worktrees`: worktree em `.claude/worktrees/phase-05.1-goals` com a branch existente `phase/05.1-daily-goals`. No worktree: `npm install` e `RBENV_VERSION=4.0.9 bundle install` em `apps/api`.
- [ ] `STATUS.md`: `05.1` de `Em planejamento` para `Em desenvolvimento`, com evidência `[Plano](../superpowers/plans/2026-11-17-daily-goals.md) e mensagem do responsável de <data>: "<aprovação>"`. `05` continua `Em desenvolvimento`.
- [ ] `bash scripts/verify-harness.sh`, com código 0. Commit: `docs: start phase 05.1 development`.

## Tarefa 1: Tabelas, modelos, tipos permitidos e dados da pessoa

**Requisitos:** FR-GOALS-001, FR-GOALS-005; LGPD (tabela nova entra na exclusão e na exportação) · **Critérios:** `AC-05.1-05` (banco); testes da fase ("Exclusão de conta alcança metas e check-ins")

**Arquivos:**
- Criar:
  - `apps/api/db/migrate/20261117100000_create_goals.rb`, `apps/api/db/migrate/20261117100100_create_goal_check_ins.rb`;
  - `apps/api/app/domains/goals/models/goal.rb`, `apps/api/app/domains/goals/models/goal_check_in.rb`;
  - `apps/api/app/domains/goals/goal_type.rb`;
  - `apps/api/app/domains/goals/services/user_data.rb`;
  - `apps/api/app/domains/goals/api.rb` (só `USER_DATA_TABLES`, `export_user_data` e `erase_user_data` nesta tarefa);
  - `apps/api/config/initializers/goals_registrations.rb` (`Shared::DataRegistry.register`, como em `nutrition_registrations.rb`).
- Modificar: `apps/api/db/schema.rb` (gerado), `docs/architecture/DATABASE_DESIGN.md` (seção Goals, com o design 4.2).
- Teste:
  - `apps/api/spec/domains/goals/schema_constraints_spec.rb`;
  - `apps/api/spec/domains/goals/user_data_spec.rb`;
  - casos novos em `apps/api/spec/requests/account_deletion_spec.rb` e `account_export_spec.rb`.

**Interfaces (produz):**
- `Goals::GoalType::ALL` = os cinco códigos, congelado; `Goals::GoalType.allowed?(code) -> Boolean`.
- `Goals::Goal` (`goals`): `STATUSES = %w[active paused ended]`, `LIVE = %w[active paused]`; `has_many :check_ins, class_name: "Goals::GoalCheckIn", dependent: :delete_all`.
- `Goals::GoalCheckIn` (`goal_check_ins`): `SOURCES = %w[manual food_entry]`.
- `Goals::Api::USER_DATA_TABLES = %w[goals goal_check_ins]`; `Goals::Api.export_user_data(user_id) -> Hash`; `Goals::Api.erase_user_data(user_id)`.

**Dados da pessoa:**
- A exportação traz as metas (`id`, `goal_type`, `status`, `starts_on`, `ends_on`, `paused_at`, `rule_version`) com os check-ins (`local_date`, `source`, `checked_at`).
- `source_ref` fica fora da exportação, porque é referência interna à tabela de outro contexto.
- O apagamento remove as metas da pessoa, e os check-ins vão em cascata. Pode rodar de novo sem erro.

**Banco (design 4.2):**
- `goals`: `id` uuid; `user_id` uuid `NOT NULL` com FK para `users`, como `food_entries`; `goal_type`; `cadence` padrão `daily`; `target` padrão `1`; `rule_version`, `status` padrão `active`, `starts_on`, tudo `NOT NULL`; `ends_on` e `paused_at` nulos; timestamps.
- `CHECK` em `goals`:
  - `goals_goal_type_allowed`: `goal_type IN (...)`, com os cinco tipos;
  - `goals_cadence_daily`;
  - `goals_target_one`;
  - `goals_status_known`;
  - `goals_ended_has_end`: `status <> 'ended' OR ends_on IS NOT NULL`.
- Índices em `goals`: único parcial `(user_id, goal_type) WHERE status IN ('active','paused')`, e `(user_id, status)`.
- `goal_check_ins`: `goal_id` com FK `ON DELETE CASCADE`; `user_id`, `local_date`, `source` e `checked_at`, `NOT NULL`; `source_ref` uuid nulo.
- `CHECK` em `goal_check_ins`:
  - `goal_check_ins_source_known`;
  - `goal_check_ins_ref_matches_source`: `(source = 'manual') = (source_ref IS NULL)`.
- Índices em `goal_check_ins`:
  - único parcial `(goal_id, local_date) WHERE source = 'manual'`;
  - único parcial `(goal_id, source, source_ref) WHERE source_ref IS NOT NULL`;
  - `(user_id, local_date DESC)` e `(goal_id, local_date DESC)`.

- [ ] **RED** em `schema_constraints_spec.rb`. Cada caso de recusa usa `insert_all`/SQL cru, para passar por cima das validações do modelo:
  - `rejects a forbidden goal type inserted directly`: para cada um de `calorie_target calorie_limit calorie_deficit weight_loss target_weight fasting burn_to_eat`, `expect { insert }.to raise_error(ActiveRecord::CheckViolation, /goals_goal_type_allowed/)`;
  - `accepts each allowed type`: os cinco tipos;
  - `rejects weekly cadence and a target other than 1`;
  - `allows one live goal per type`: uma segunda `active` ou `paused` do mesmo tipo dá `ActiveRecord::RecordNotUnique`, e depois de `ended` (com `ends_on`) outra entra;
  - `allows one manual check-in per goal and day`;
  - `allows one check-in per goal and meal`: o mesmo `source_ref` de `food_entry` duas vezes dá `RecordNotUnique`, e dois `food_entry` diferentes no mesmo dia entram;
  - `requires source_ref exactly for food_entry`;
  - `deleting a goal deletes its check-ins`.
- [ ] **RED** em `user_data_spec.rb` e nos request specs de conta:
  - `export lists goals with their check-ins and no source_ref`;
  - `erase removes only that person's goals and check-ins, twice safely`;
  - em `account_deletion_spec.rb`: `account deletion removes goals and check-ins`;
  - em `account_export_spec.rb`: `export includes goals`.
- [ ] Rodar `RBENV_VERSION=4.0.9 bundle exec rspec spec/domains/goals spec/requests/account_deletion_spec.rb spec/requests/account_export_spec.rb`. Esperado: falha por tabela inexistente.
- [ ] **GREEN:**
  - migrações e `db:migrate`, que atualiza o `schema.rb`;
  - modelos com as mesmas validações de inclusão;
  - `GoalType`, `UserData`, `Api` e o registro no `DataRegistry`.
- [ ] Rodar `bundle exec rspec` (inclui o spec de cobertura do `DataRegistry` e `spec/architecture`) e `bundle exec rubocop`, com código 0.
- [ ] `DATABASE_DESIGN.md` atualizado. Commit: `feat(goals): add goals and check-ins with closed type list`.

## Tarefa 2: Regra de conclusão e dia local

**Requisitos:** FR-GOALS-002, FR-GOALS-003 · **Critérios:** `AC-05.1-02` (janela e fuso), `AC-05.1-03`

**Arquivos:**
- Criar: `apps/api/app/domains/goals/services/rules.rb`, `apps/api/app/domains/goals/services/evaluate_day.rb`, `apps/api/app/domains/goals/services/local_day.rb`
- Teste: `apps/api/spec/domains/goals/evaluate_day_spec.rb`, `apps/api/spec/domains/goals/local_day_spec.rb`

**Interfaces (produz):**
- `Goals::Rules::TABLE = { "daily_any_v1" => ->(check_ins, local_date) { ... } }`, congelado; `Goals::Rules::CURRENT = "daily_any_v1"`; `Goals::Rules.fetch(version)` levanta `Goals::Rules::UnknownVersion`.
- `Goals::EvaluateDay.call(rule_version:, local_date:, check_ins:) -> Boolean`: função pura. `check_ins` é qualquer lista que responde a `local_date`, para servir a modelos e a `Data`.
- `Goals::LocalDay.zone_for(user_id) -> ActiveSupport::TimeZone`: fuso do `UserProfile::Api.time_zone`, ou UTC se for `nil` ou desconhecido.
- `Goals::LocalDay.today(user_id:, now: Time.current) -> Date`.
- `Goals::LocalDay.window(user_id:, now: Time.current) -> [Date, Date]`: `[ontem, hoje]`.
- `Goals::LocalDay.parse(value) -> Date | nil`: só `AAAA-MM-DD` válido.

- [ ] **RED** em `evaluate_day_spec.rb`, tabela de casos (`daily_any_v1`):

  | Check-ins | Dia | Esperado |
  |---|---|---|
  | nenhum | D | `false` |
  | 1 manual em D | D | `true` |
  | 1 `food_entry` em D | D | `true` |
  | manual e `food_entry` em D | D | `true` |
  | 1 manual em D-1 | D | `false` |
  | 2 `food_entry` em D | D | `true` |

  Mais:
  - `is deterministic`: 200 listas aleatórias com semente fixa (`Random.new(2026)`), avaliadas duas vezes e embaralhadas, sempre iguais a `check_ins.any? { _1.local_date == d }`;
  - `raises for an unknown rule version`;
  - `keeps every version ever used`: `Goals::Rules::TABLE.keys` inclui `"daily_any_v1"`, para impedir que alguém remova uma versão em uso.
- [ ] **RED** em `local_day_spec.rb`, com `travel_to` e fuso gravado no perfil:
  - `America/Sao_Paulo`, 2026-11-17 23:59:59 local, dá hoje = 17; às 00:00:00 do dia 18, dá hoje = 18 e ontem = 17;
  - `Pacific/Auckland` em horário de verão (NZDT, +13), 2026-11-17 00:30 local: hoje = 17, embora em UTC ainda seja dia 16;
  - `America/New_York` em 2026-11-01, troca de horário: 00:30 e 23:30 locais caem ambos no dia 1;
  - `America/Manaus`, sem horário de verão;
  - `pending profile uses UTC`: `time_zone` `nil` (Foco 4);
  - `parse` recusa `2026-13-01`, `2026-11-1`, `""` e `nil`.
- [ ] Rodar os dois specs. Esperado: falha por constante inexistente.
- [ ] **GREEN.** Rodar os dois specs, com código 0. Commit: `feat(goals): versioned daily rule and local day window`.

## Tarefa 3: Criar, pausar, encerrar e apagar

**Requisitos:** FR-GOALS-001, FR-GOALS-005 · **Critérios:** `AC-05.1-01`, `AC-05.1-05` (domínio)

**Arquivos:**
- Modificar: `apps/api/app/domains/goals/api.rb`
- Criar: `apps/api/app/domains/goals/services/create_goal.rb`, `apps/api/app/domains/goals/services/change_status.rb`, `apps/api/app/domains/goals/services/delete_goal.rb`, `apps/api/app/domains/goals/services/goal_view.rb`
- Teste: `apps/api/spec/domains/goals/manage_goals_spec.rb`

**Interfaces (produz), em `Goals::Api`:**
- `GoalInfo = Data.define(:id, :goal_type, :status, :starts_on, :ends_on, :done_today, :done_yesterday, :created)`, com `ok? = true` (`created` padrão `false`).
- `Errors = Data.define(:code, :details)`, com `ok? = false`. Códigos: `validation_failed` (`details` com `{ field:, code: }`) e `goal_not_active`.
- `goal_types -> Array<String>`, igual a `GoalType::ALL`.
- `create_goal(user_id:, goal_type:) -> GoalInfo | Errors`:
  - tipo fora da lista dá `validation_failed` com `[{ field: "goal_type", code: "unsupported_goal_type" }]`;
  - meta viva do tipo devolve a existente com `created: false`.
- `change_status(user_id:, goal_id:, status:) -> GoalInfo | :not_found | Errors`:
  - `status` fora de `active paused ended` dá `validation_failed` com `{ field: "status", code: "inclusion" }`;
  - meta `ended` dá `goal_not_active`;
  - o mesmo status devolve a meta sem mudança.
- `delete_goal(user_id:, goal_id:) -> :deleted | :not_found`.
- `Goals::GoalView.call(goal, today:, yesterday:) -> GoalInfo`: calcula `done_*` com `EvaluateDay` a partir dos check-ins de hoje e ontem.

**Regras (design 4.7):**
- Criar grava `starts_on = LocalDay.today` e `rule_version = Rules::CURRENT`.
- Corrida de criação: em `RecordNotUnique`, a operação relê a meta viva do tipo e devolve a existente.
- Pausar grava `paused_at`, retomar o limpa, e encerrar grava `ends_on = today`.
- Eventos na mesma transação: `goal.created` (`goal_id`, `goal_type`) e `goal.deleted` (`goal_id`). Pausar e encerrar não publicam nada.

- [ ] **RED** em `manage_goals_spec.rb`:
  - `creates a daily goal of an allowed type and publishes goal.created`: payload exatamente `{ goal_id:, goal_type: }`;
  - `rejects forbidden types with a neutral validation error`: os sete códigos da Tarefa 1, mais `"LOG_MEALS"` e `nil`; nenhuma linha e nenhum evento;
  - `returns the live goal of the same type instead of a second one`, inclusive pausada;
  - `two concurrent creates of the same type make one goal`: duas threads com conexões próprias, no padrão de `spec/domains/nutrition/concurrency_spec.rb`;
  - `pauses, resumes and ends`, com `paused_at` e `ends_on`;
  - `an ended goal cannot change status`, que dá `goal_not_active`;
  - `after ending, the same type can be created again`;
  - `delete removes the goal and its check-ins and publishes goal.deleted`;
  - `another person's goal is not_found for change_status and delete_goal`; um id malformado também.
- [ ] Rodar o spec. Esperado: falha por `Goals::Api` inexistente.
- [ ] **GREEN.** Rodar o spec, `spec/architecture` e `rubocop`, com código 0. Commit: `feat(goals): create, pause, end and delete daily goals`.

## Tarefa 4: Check-in manual e eventos de conclusão

**Requisitos:** FR-GOALS-002, FR-GOALS-003 · **Critérios:** `AC-05.1-02`, `AC-05.1-03`

**Arquivos:**
- Criar: `apps/api/app/domains/goals/services/record_day.rb`, `apps/api/app/domains/goals/services/check_in.rb`, `apps/api/app/domains/goals/services/uncheck.rb`
- Modificar: `apps/api/app/domains/goals/api.rb`, `docs/architecture/DOMAIN_MODEL.md` (catálogo: payloads de `goal.created`, `goal.completed`, `goal.uncompleted` e `goal.deleted`, conforme o design 4.6; Goals como consumidor de `food_entry.confirmed` e `food_entry.deleted`)
- Teste: `apps/api/spec/domains/goals/check_in_spec.rb`, `apps/api/spec/domains/goals/check_in_concurrency_spec.rb`

**Interfaces:**
- **Consome:** `EvaluateDay`, `LocalDay`, `Rules` (Tarefa 2); `Goal` e `GoalCheckIn` (Tarefa 1).
- **Produz:**
  - `Goals::RecordDay.call(goal:, local_date:) { ... }`: trava a meta (`goal.lock!`) e avalia o dia antes do bloco. Executa o bloco, que grava ou apaga check-ins, avalia de novo e publica a transição. Tudo dentro da transação de quem chama. É usado aqui e na Tarefa 5.
  - `Goals::Api::DayInfo = Data.define(:goal_id, :local_date, :done, :sources)`, com `ok? = true`. `sources` é a lista ordenada e sem repetição de `manual` e `food_entry` naquele dia.
  - `check_in(user_id:, goal_id:, local_date:) -> DayInfo | :not_found | Errors`.
  - `uncheck(user_id:, goal_id:, local_date:) -> DayInfo | :not_found | Errors`.

**Regras (design 4.3, 4.4 e 4.6):**
- **Publicação:**
  - de não cumprido para cumprido: `goal.completed` com `{ goal_id:, goal_type:, local_date:, period_key: local_date.iso8601, rule_version: }`;
  - de cumprido para não cumprido: `goal.uncompleted` com `{ goal_id:, period_key: }`;
  - sem transição, nada.
- **Validação da data:**
  - fora de `LocalDay.window`, ou antes de `starts_on`: `validation_failed`, `[{ field: "local_date", code: "outside_window" }]`;
  - inválida: `{ field: "local_date", code: "invalid" }`.
- **Meta não ativa** (`paused` ou `ended`): `goal_not_active`.
- **Repetição:**
  - check-in repetido devolve o `DayInfo` sem novo evento (insere com `insert_all ... unique_by` no índice parcial, ou relê depois de `RecordNotUnique`);
  - `uncheck` sem check-in manual devolve `DayInfo` sem evento.
- `uncheck` remove só o `manual`. Com um `food_entry` restante, o dia continua `done: true`, sem `goal.uncompleted`.

- [ ] **RED** em `check_in_spec.rb`:
  - `checks in today and publishes goal.completed once`;
  - `checks in yesterday`;
  - `refuses two days ago and tomorrow as outside_window`;
  - `refuses a date before the goal started`;
  - `refuses a malformed date as invalid`;
  - `a repeated check-in returns the same day without a second event`;
  - `uncheck publishes goal.uncompleted`;
  - `uncheck keeps the day done when a meal also completed it`, sem evento;
  - `paused and ended goals refuse check-in and uncheck with goal_not_active`;
  - `uses the person's time zone near midnight`: `America/Sao_Paulo`, 00:05 local do dia 18 com 02:05 UTC; `local_date` 17 é ontem e é aceito, 16 é recusado;
  - `the person changing time zone between check-ins`: com o fuso trocado de `America/Sao_Paulo` para `Asia/Tokyo` às 22:00 UTC, a janela passa a refletir o novo fuso e o check-in gravado continua com a data original;
  - `re-evaluating a person's recorded days gives the same results`: grava uma sequência de check-ins e desmarcações, guarda os `DayInfo#done`, reavalia cada dia com `EvaluateDay` a partir das linhas do banco e compara (`AC-05.1-03`);
  - `events carry only identifiers and tokens`: `Shared::Outbox::PayloadCheck` aceita, e não há `user_id` nem fonte no payload.
- [ ] **RED** em `check_in_concurrency_spec.rb` (Foco 2): duas threads fazendo `check_in` no mesmo dia dão um check-in e um `goal.completed`. Uma thread em `check_in` e outra gravando um check-in de refeição pelo `RecordDay` dão um `goal.completed`.
- [ ] Rodar os specs. Esperado: falha.
- [ ] **GREEN.** Rodar os specs, `spec/architecture` e `rubocop`, com código 0. Atualizar o `DOMAIN_MODEL.md`. Commit: `feat(goals): manual check-in with completion events`.

## Tarefa 5: Refeições cumprem a meta

**Requisitos:** FR-GOALS-002 · **Critérios:** `AC-05.1-02` (refeição), `AC-05.1-03`

**Arquivos:**
- Criar: `apps/api/app/domains/goals/services/check_in_from_food_entry.rb`, `apps/api/app/domains/goals/services/remove_food_entry_check_in.rb`
- Modificar: `apps/api/config/initializers/goals_registrations.rb` (Tarefa 1)
- Teste: `apps/api/spec/domains/goals/food_entry_consumers_spec.rb`

**Interfaces:**
- **Consome:** `RecordDay` (Tarefa 4).
- **Produz:**
  - consumidor `goals.check_in_from_food_entry` de `food_entry.confirmed`: `Goals::CheckInFromFoodEntry.call(event)`, com `event.user_id`, `event.payload["food_entry_id"]` e `event.payload["local_date"]`;
  - consumidor `goals.remove_food_entry_check_in` de `food_entry.deleted`: `Goals::RemoveFoodEntryCheckIn.call(event)`.

**Regras (design 4.5 e 4.12):**
- `food_entry.confirmed`: procura a meta `log_meals` com `status = active` da pessoa. Grava um check-in `source: "food_entry"`, `source_ref: food_entry_id`, na `local_date` do evento. Não aplica a janela de hoje e ontem.
- Não faz nada quando: não existe meta ativa; a data é anterior a `starts_on`; já existe check-in daquela refeição (`unique_by` no índice parcial); a data é inválida.
- `food_entry.deleted`: apaga o check-in com aquele `source_ref` em qualquer meta da pessoa, e reavalia o dia pelo `RecordDay`.
- Nenhum dos dois levanta erro por dado ausente (Foco 3).

- [ ] **RED** em `food_entry_consumers_spec.rb` (`:real_consumers`, publicando pela outbox e rodando `run_publisher`):
  - `a confirmed meal completes the day of an active log_meals goal and publishes goal.completed`;
  - `a second meal the same day adds a check-in but no event`;
  - `the same event twice makes one check-in`, com o consumidor chamado direto duas vezes e também pela outbox;
  - `a meal dated before the goal started is ignored`;
  - `a paused goal ignores meals`, e nenhum check-in surge ao retomar;
  - `no log_meals goal: nothing happens`;
  - `deleting the only meal of the day publishes goal.uncompleted`;
  - `deleting one of two meals keeps the day done`;
  - `deleting a meal keeps a manual check-in of the same day`;
  - `events for a deleted goal or account finish without error`: o consumidor não levanta e o `consumed_events` é gravado (Foco 3);
  - `other goal types are not touched by meals`.
- [ ] Rodar o spec. Esperado: falha por consumidor não registrado.
- [ ] **GREEN:** serviços e os dois `Shared::Outbox.subscribe` em `goals_registrations.rb`.
- [ ] Rodar o spec e `bundle exec rspec spec/domains`, com código 0. Commit: `feat(goals): confirmed meals complete the log_meals goal`.

## Tarefa 6: Lista do dia e histórico

**Requisitos:** FR-GOALS-004 · **Critérios:** `AC-05.1-04`

**Arquivos:**
- Criar: `apps/api/app/domains/goals/services/list_goals.rb`, `apps/api/app/domains/goals/services/history.rb`
- Modificar: `apps/api/app/domains/goals/api.rb`
- Teste: `apps/api/spec/domains/goals/list_and_history_spec.rb`

**Interfaces (produz), em `Goals::Api`:**
- `GoalList = Data.define(:today_local_date, :yesterday_local_date, :goals)`, com `goals` como lista de `GoalInfo`.
- `list_goals(user_id:) -> GoalList`: metas `active` e `paused`, ordenadas por `status` (ativas primeiro) e `created_at`.
- `HistoryDay = Data.define(:goal_id, :goal_type, :goal_status, :local_date, :sources)`.
- `HistoryPage = Data.define(:days, :next_cursor)`, com `ok? = true`.
- `history(user_id:, goal_id: nil, cursor: nil, limit: nil) -> HistoryPage | :not_found | Errors`:
  - limite padrão `30`, máximo `100`;
  - limite fora de 1 a 100: `validation_failed` com `{ field: "limit", code: "out_of_range" }`;
  - cursor ilegível: `{ field: "cursor", code: "invalid" }`;
  - `goal_id` de outra pessoa ou malformado: `:not_found`.

**Regras (design 4.8):**
- Só dias cumpridos (pela regra da versão de cada meta), do mais recente para o mais antigo, com desempate por `goal_id`. Inclui metas encerradas.
- Cursor opaco sobre `(local_date, goal_id)`.
- A consulta agrupa por `(goal_id, local_date)` no banco, sem carregar todos os check-ins.

- [ ] **RED** em `list_and_history_spec.rb`:
  - `lists active then paused goals with done_today and done_yesterday`;
  - `a paused goal keeps its recorded days`;
  - `ended goals are not in the list but are in the history`;
  - `history has only completed days, newest first, with their sources`;
  - `history is paginated by cursor without gaps or repeats`: 45 dias, `limit` 20, três páginas;
  - `history filters by goal`;
  - `history is isolated per person`: a segunda pessoa vê só os seus dias, e o `goal_id` alheio dá `:not_found`;
  - `limit 0, 101 and a bad cursor are validation errors`;
  - `history query count is the same for 10 and 30 days`: contagem de consultas com N e 3N, como na Fase 03.
- [ ] Rodar o spec. Esperado: falha.
- [ ] **GREEN.** Rodar o spec e `rubocop`, com código 0. Commit: `feat(goals): today list and paginated history`.

## Tarefa 7: Contrato, rotas e controllers

**Requisitos:** FR-GOALS-001 a FR-GOALS-005 · **Critérios:** `AC-05.1-01`, `AC-05.1-02`, `AC-05.1-04`, `AC-05.1-05` (API)

**Arquivos:**
- Modificar: `packages/contracts/openapi.yaml` e `packages/contracts/generated/*` (gerado), `apps/api/config/routes.rb`, `apps/api/app/controllers/concerns/error_rendering.rb`, `docs/architecture/API_DESIGN.md` (rotas da 05.1, `DELETE` de check-in, códigos `goal_not_active`, `unsupported_goal_type` e `outside_window`), `docs/security/PRIVACY_AND_LGPD.md` (efeito de revogar `health_data` sobre as metas, design 4.9)
- Criar: `apps/api/app/controllers/api/v1/goal_types_controller.rb`, `apps/api/app/controllers/api/v1/goals_controller.rb`, `apps/api/app/controllers/api/v1/goal_check_ins_controller.rb`, `apps/api/app/controllers/api/v1/goal_history_controller.rb`, `apps/api/app/controllers/concerns/goal_responses.rb`
- Teste: `apps/api/spec/requests/goals_spec.rb`, `apps/api/spec/requests/goal_check_ins_spec.rb`, `apps/api/spec/requests/goal_history_spec.rb`

**Rotas (uuid com a mesma `constraints` das refeições; `local_date` com `/\d{4}-\d{2}-\d{2}/`; `format: false`):**

| Rota | Resposta |
|---|---|
| `GET /api/v1/goal_types` | `200 { goal_types: [...] }` |
| `GET /api/v1/goals` | `200 GoalList`: `{ today_local_date, yesterday_local_date, goals: [Goal] }` |
| `POST /api/v1/goals` `{ goal_type }` | `201 Goal` se nova; `200 Goal` se já existia; `422` |
| `PATCH /api/v1/goals/:id` `{ status }` | `200 Goal`; `404`; `409 goal_not_active`; `422` |
| `DELETE /api/v1/goals/:id` | `204`; `404`. **Não exige `health_data`** |
| `POST /api/v1/goals/:id/check_ins` `{ local_date }` | `200 GoalDay` (`{ goal_id, local_date, done, sources }`); `404`; `409`; `422` |
| `DELETE /api/v1/goals/:id/check_ins/:local_date` | `200 GoalDay`; `404`; `409`; `422` |
| `GET /api/v1/goals/history?goal_id=&cursor=&limit=` | `200 { items: [GoalHistoryDay], next_cursor }`; `404`; `422` |

- `Goal` é `{ id, goal_type, status, starts_on, ends_on, done_today, done_yesterday }`, e `GoalHistoryDay` é `{ goal_id, goal_type, goal_status, local_date, sources }`.
- `goal_type` no contrato é `string` com `enum` dos cinco tipos nas respostas. Na requisição é `string` sem `enum`, para que um tipo proibido chegue ao `422` do domínio e não ao `400` do validador.
- `GoalResponses` mapeia `validation_failed` para `422` e `goal_not_active` para `409`.
- `ErrorRendering::MESSAGES["goal_not_active"]` = "Esta meta não está ativa. Retome a meta para marcar o dia."

- [ ] **RED**, com `expect_response_to_match_contract` em cada caso:
  - `goals_spec.rb`:
    - `needs a session`, `needs health_data` (`403 consent_required`);
    - `lists goal types`;
    - `creates and lists a goal`;
    - `a repeated create is 200 with the same goal`;
    - `forbidden types are 422 unsupported_goal_type with the neutral message and no row` (`AC-05.1-05`);
    - `pauses, resumes, ends`;
    - `ended goal is 409 goal_not_active`;
    - `delete works after revoking health_data` (revoga pelo `DELETE /api/v1/consents/health_data` e roda o publicador);
    - `another person's goal is 404 on PATCH and DELETE`.
  - `goal_check_ins_spec.rb`:
    - `checks in today and yesterday`;
    - `two days ago is 422 outside_window`;
    - `unchecks`;
    - `paused goal is 409`;
    - `another person's goal is 404`;
    - `near midnight in America/Sao_Paulo` (`travel_to`, `AC-05.1-02`).
  - `goal_history_spec.rb`:
    - `paginates`;
    - `filters by goal`;
    - `another person's goal_id is 404`;
    - `limit 101 is 422`.
- [ ] Rodar. Esperado: falha por rota inexistente.
- [ ] **GREEN:** contrato primeiro, `npm run generate -w @app/contracts`, depois rotas e controllers.
- [ ] Rodar `RBENV_VERSION=4.0.9 bundle exec rspec`, `bundle exec rubocop`, `bundle exec brakeman -q --no-pager -w2` e `npm run check -w @app/contracts`, todos com código 0. `API_DESIGN.md` e `PRIVACY_AND_LGPD.md` atualizados. Commit: `feat(goals): goals API and contract`.

## Tarefa 8: Telas móveis

**Requisitos:** FR-GOALS-001, FR-GOALS-002, FR-GOALS-004 · **Critérios:** `AC-05.1-01` (demonstração), `AC-05.1-02`, `AC-05.1-04`

**Arquivos:**
- Criar:
  - em `apps/mobile/src/features/goals/`: `goalMessages.ts`, `GoalsTodayScreen.tsx`, `NewGoalScreen.tsx`, `GoalDetailScreen.tsx`;
  - testes em `apps/mobile/src/features/goals/__tests__/`: `today.test.tsx`, `newGoal.test.tsx`, `detail.test.tsx`, `copy.test.ts`;
  - rotas em `apps/mobile/src/app/goals/`: `index.tsx`, `new.tsx`, `[id].tsx`.
- Modificar:
  - `apps/mobile/src/shared/api.ts` (tipos `Goal`, `GoalList`, `GoalDay`, `GoalHistoryPage` e `GoalType`; métodos abaixo);
  - `apps/mobile/src/features/meals/CameraScreen.tsx` e `apps/mobile/src/app/meals/index.tsx` (prop `onGoals`, para o link "Metas" ao lado do histórico);
  - `scripts/check_language.py` (incluir `apps/mobile/src/features/goals` em `SCAN_PATHS`).

**Interfaces (produz), em `api`:**
- `listGoalTypes()`, `listGoals()`;
- `createGoal(goalType)`;
- `updateGoalStatus(id, status)`, `deleteGoal(id)`;
- `checkInGoal(id, localDate)`, `uncheckGoal(id, localDate)`;
- `goalHistory({ goalId?, cursor? })`.

Todos devolvem `Result<T>`, como as refeições.

**Textos (design 4.10), em `goalMessages.ts`:**
- Tipos:

  | Código | Texto |
  |---|---|
  | `log_meals` | Registrar as refeições do dia |
  | `include_fruits_vegetables` | Incluir frutas ou vegetais |
  | `drink_water` | Beber água ao longo do dia |
  | `sleep_routine` | Dormir no horário que escolhi |
  | `planned_workout` | Fazer o treino planejado |

  Um código desconhecido não aparece.
- Botão: "Feito". Seletor: "Hoje" e "Ontem".
- Vazio: "Escolha um hábito para acompanhar."
- Pausada: "Pausada. Retome quando quiser."
- Cumprida por refeição: "Cumprida pela refeição registrada."
- Erros por código:
  - `outside_window`: "Só dá para marcar hoje ou ontem.";
  - `goal_not_active`: "Esta meta está pausada. Retome para marcar.";
  - `unsupported_goal_type`: "Esse tipo de meta não está disponível.";
  - sem rede e outros: o padrão de `shared/messages.ts`.
- Confirmações:
  - encerrar: "Encerrar esta meta? O histórico continua disponível.";
  - apagar: "Apagar esta meta e o histórico dela? Isso não pode ser desfeito."
- Histórico vazio: "Os dias marcados aparecem aqui."

**Comportamento:**
- **Metas do dia:**
  - dia escolhido em `today_local_date` ou `yesterday_local_date`, vindos da API, sem calcular datas no app;
  - "Feito" alterna entre `checkInGoal` e `uncheckGoal`;
  - o botão fica ocupado durante o pedido, e o estado só muda com a resposta;
  - metas pausadas aparecem recolhidas no fim;
  - link "Nova meta".
- **Nova meta:** os tipos de `listGoalTypes` sem os que já estão vivos. Ao criar, volta para Metas do dia.
- **Detalhe:**
  - status e ações pausar/retomar, encerrar e apagar, as duas últimas com confirmação;
  - histórico paginado por `goalHistory({ goalId })` com "Carregar mais";
  - estados carregando, vazio, erro com "Tentar de novo" e sem rede, como em `MealHistoryScreen.tsx`.

- [ ] **RED** (com `jsonResponse` de `shared/testing/fakes`):
  - `today.test.tsx`:
    - `shows today's goals and marks one done`;
    - `switches to yesterday using the dates from the API`;
    - `tapping done again unchecks`;
    - `log_meals completed by a meal says so and stays done after unchecking`;
    - `keeps the previous state and offers retry when the request fails` (Foco 5);
    - `after midnight an outside_window answer shows the message and reloads` (Foco 1);
    - `paused goals are listed last`;
    - `empty state`.
  - `newGoal.test.tsx`:
    - `offers only types not already live`;
    - `ignores unknown type codes`;
    - `creating returns to today`.
  - `detail.test.tsx`:
    - `pauses and resumes`;
    - `ending asks for confirmation`;
    - `deleting asks for confirmation and leaves the screen`;
    - `history loads more pages`;
    - `history empty state`.
  - `copy.test.ts`:
    - `every allowed type has a label`;
    - `no text uses an exclamation mark`.

    A lista de linguagem proibida é conferida pelo `check_language.py`, com a pasta `features/goals` incluída em `SCAN_PATHS`.
- [ ] Rodar `npm test -w apps/mobile -- src/features/goals`. Esperado: falha.
- [ ] **GREEN.**
- [ ] Rodar `npm run typecheck -w apps/mobile`, `npm run lint -w apps/mobile`, `npm test -w apps/mobile`, `python3 scripts/check_language.py`, `bash scripts/test-check-language.sh`, `bash scripts/verify-harness.sh` e `bash scripts/test-verify-harness.sh`, todos com código 0. Commit: `feat(mobile): daily goals screens`.

## Tarefa 9: Demonstração, rastreabilidade e verificação completa

**Critérios:** `AC-05.1-01` (demonstração no app), todos (evidência)

**Arquivos:** `docs/roadmap/TRACEABILITY.md` (linhas FR-GOALS-001 a 005: módulos, testes e evidência), `docs/roadmap/reports/evidence/phase-05.1/` (capturas).

- [ ] **Demonstração real** no emulador Android com Expo Go, contra a API local, com conta fictícia (`@example.test`). Roteiro:
  1. cadastro com consentimento `health_data`;
  2. criar "Registrar as refeições do dia" e "Beber água ao longo do dia";
  3. marcar água hoje e ontem, depois desmarcar ontem;
  4. registrar uma refeição à mão e ver "Registrar as refeições" cumprida pela refeição;
  5. apagar a refeição e ver a meta voltar;
  6. pausar e retomar;
  7. histórico;
  8. encerrar e apagar.
  Capturas `mobile-01` em diante. Conferir também, no banco local, que os eventos `goal.*` existem com o payload do design 4.6, e que o log da API não tem `goal_type` nem datas de check-in (`grep` no `log/development.log` do período).
- [ ] `TRACEABILITY.md` preenchido. `bash scripts/verify-harness.sh`, com código 0.
- [ ] Verificação completa, todos com código 0:
  - `RBENV_VERSION=4.0.9 bundle exec rspec`, `rubocop`, `brakeman` e `bundle-audit check --update`;
  - `npm run check -w @app/contracts`, `npm audit --audit-level=high` (com as exceções vigentes);
  - web: typecheck, lint, testes e build;
  - mobile: typecheck, lint e testes;
  - `bash scripts/verify-harness.sh` e `bash scripts/test-verify-harness.sh`.
- [ ] Commit: `docs: record phase 05.1 evidence and traceability`.

## Tarefa 10: Encerrar

- [ ] Usar a skill `phase-closeout`:
  - execução completa;
  - matriz de rastreabilidade preenchida;
  - os revisores do documento da fase: `software-architect`, `backend-reviewer`, `security-reviewer`, `frontend-mobile-reviewer` e `qa-reviewer`;
  - relatório `PHASE_05.1_REPORT.md`;
  - `STATUS.md` em `Em revisão`;
  - push e PR só com autorização.
- [ ] Registrar como pendente do M1 (fora desta etapa) a revisão dos textos e tipos de meta por profissional de saúde (`AC-M1-11`).
- [ ] Apresentar o relatório e **parar**.

## Cobertura dos critérios

| Critério | Tarefas |
|---|---|
| `AC-05.1-01` | 1, 3, 7, 8, 9 |
| `AC-05.1-02` | 2, 4, 5, 7, 8 |
| `AC-05.1-03` | 2, 4, 5 |
| `AC-05.1-04` | 6, 7, 8 |
| `AC-05.1-05` | 1, 3, 7 |
