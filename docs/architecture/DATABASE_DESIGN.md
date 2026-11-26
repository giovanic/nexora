# Desenho do banco de dados

> Este é o desenho inicial, que a fase dona de cada tabela confirma ao criá-la. As tabelas de Identity (Fase 02) e de Nutrition, Food AI e Food Catalog (Fase 03) refletem o `apps/api/db/schema.rb`; as demais ainda são desenho. Mudanças relevantes passam por ADR.

PostgreSQL. Versão decidida na [ADR 0002](decisions/0002-technology-baseline.md).

## Convenções

- **Chave primária:** `id` UUID em todas as tabelas com dados de usuário. Assim um identificador não revela volume nem permite enumeração. A geração (v4 ou v7) é decidida na Fase 01.
- **Tempos:** `created_at` e `updated_at` em UTC. Datas "do dia da pessoa" ficam em `local_date`, calculadas com o fuso dela no momento do registro.
- **Identidade entre contextos:** coluna de identificador. Há chave estrangeira real apenas dentro do mesmo contexto e para `users`, onde a exclusão é controlada.
- **Estimativas:** toda grandeza estimada usa colunas `_min`, `_likely` e `_max`, mais `confidence`. Nunca há coluna única que pareça medição.
- **Soft delete:** só onde indicado. O padrão é apagar de verdade, conforme a [política de privacidade](../security/PRIVACY_AND_LGPD.md).
- **Índices:** cada um precisa de uma consulta que o justifique.
- **Exclusão de conta:** um job de Identity percorre o registro compartilhado de apagadores (`shared/data_registry`), no qual cada contexto inscreve o seu `eraser`. A linha de `users` permanece, anonimizada, ao fim do processo.

## Mapa de relacionamentos

```mermaid
erDiagram
  users ||--|| user_profiles : tem
  users ||--o{ sport_profiles : tem
  users ||--o{ consent_records : concede
  users ||--o{ food_entries : registra
  users ||--o{ food_photos : envia
  users ||--o{ food_analysis_results : possui
  users ||--o{ ai_usage_records : custa
  food_entries ||--o{ food_items : contem
  food_entries }o..o| food_photos : "photo_id (sem FK)"
  food_photos ||--o{ food_analysis_results : analisada_por
  food_catalog }o..o{ food_items : "catalog_item_id (sem FK)"
  food_catalog ||--o{ food_compositions : compoe
  food_analysis_results |o--o{ ai_usage_records : custa
  users ||--o{ integrations : conecta
  integrations ||--|| integration_tokens : autentica
  integrations ||--o{ activity_sync_events : recebe
  users ||--o{ activities : realiza
  users ||--o{ goals : define
  goals ||--o{ goal_check_ins : registra
  missions ||--o{ user_missions : atribuida
  users ||--o{ user_missions : recebe
  users ||--o{ xp_transactions : acumula
  users ||--|| user_levels : possui
  achievements ||--o{ user_achievements : desbloqueada
  users ||--o{ user_achievements : conquista
  users ||--o{ notifications : recebe
```

## Identity & Access

### `users`

Conta e autenticação.

- **Colunas:** `id`, `email`, `password_digest` (na exclusão, trocado pelo hash de um segredo aleatório que ninguém guarda, sem valor utilizável), `adult_confirmed_at`, `deleted_at`. O pedido de exclusão fica em `account_deletions`.
- **Constraints:** `email` único e sem diferença entre maiúsculas e minúsculas; `adult_confirmed_at NOT NULL`, o que impede criar conta sem a declaração de maioridade. A declaração não comprova a idade.
- **Índices:** único em `lower(email)`.
- **Soft delete:** `deleted_at` marca a conta excluída. Ao final do processo a linha permanece com o mesmo UUID, o e-mail trocado por um valor aleatório (mantém o `NOT NULL` e o índice único), sem senha. `consent_records` e `audit_events` seguem ligados a esse UUID, sem conteúdo de saúde. O mesmo e-mail pode criar outra conta.

### `sessions`

Sessões e tokens renováveis, por dispositivo. A forma exata depende da [ADR 0005](decisions/0005-authentication-strategy.md).

- **Colunas:** `id`, `user_id` (FK), `token_digest`, `device_label`, `expires_at`, `revoked_at`.
- **Índices:** único em `token_digest`; em `user_id` para listar sessões.

### `consent_records`

Histórico de inclusão apenas: nunca atualizado nem apagado enquanto a conta existir.

- **Colunas:** `id`, `user_id` (FK), `purpose`, `text_version`, `action` (`granted` ou `revoked`), `occurred_at`, `source`.
- **Constraints:** `purpose` e `action` validados por `CHECK`.
- **Índices:** `(user_id, purpose, occurred_at DESC)`, para obter o estado atual.

### `audit_events`

Trilha de ações sensíveis, de inclusão apenas.

- **Colunas:** `id`, `user_ref` (UUID do usuário, sem outros dados; na exclusão da conta continua ligado ao mesmo UUID), `action`, `metadata` (lista fechada de campos por `action`, sem texto livre, e-mail digitado ou dado de saúde), `ip_hmac` (HMAC com chave rotativa, pois hash simples de IPv4 é reversível), `occurred_at`.
- **Índices:** `(user_ref, occurred_at)`.

### `account_deletions`

Acompanha a exclusão de conta até a conclusão.

- **Colunas:** `id`, `user_id` (FK), `requested_at`, `pending_contexts` (nomes de contexto do registro, sem texto livre), `completed_at`. O prazo de 24 horas é contado a partir de `requested_at`.
- **Constraints:** único em `user_id`, o que torna o pedido repetido, mesmo simultâneo, inofensivo; `pending_contexts` só com nomes no formato de contexto; `completed_at` só com `pending_contexts` vazio.
- **Índices:** parcial em `requested_at WHERE completed_at IS NULL`, para a rotina horária do prazo.
- **Fluxo:** o pedido revoga as sessões, cria a linha com `pending_contexts` vindo do registro e publica `user.deletion_requested`, na mesma transação. A partir daí a conta não entra, não redefine senha nem consente, e a outbox descarta os eventos da pessoa, exceto `user.deletion_requested`. Um job de Identity (`EraseAccountJob`) percorre os `erasers` do registro compartilhado (`shared/data_registry`), sem que os contextos chamem Identity. Cada apagador concluído sai de `pending_contexts`, e uma falha repete só o que falta. A rotina horária (`DeletionDeadlineJob`) enfileira de novo as exclusões não concluídas e, passadas 24 horas, dispara alerta só com o id da exclusão. A anonimização final de `users` só ocorre com tudo concluído. A linha permanece como registro mínimo (só o UUID e as datas) para reaplicar exclusões após restauração de backup; por isso não é apagada nem exportada.

## User Profile

### `user_profiles`

Dados pessoais e preferências.

- **Colunas:** `user_id` (PK e FK), `display_name`, `time_zone`, `units`, `notification_preferences` (JSONB), `quiet_hours`, `motivations` (lista fechada de 0 a 4 itens, opcional, sem texto livre).
- **Constraints:** `time_zone NOT NULL`.

### `sport_profiles`

Nível por esporte.

- **Colunas:** `id`, `user_id` (FK), `sport`, `level`, `started_at`, `ended_at` (nulo na linha vigente).
- **Histórico:** mudar o nível encerra a linha atual (`ended_at`) e cria outra, preservando o histórico.
- **Constraints:** único em `(user_id, sport)` com `ended_at` nulo; `level` em `beginner`, `intermediate` ou `advanced`.

## Nutrition

### `food_entries`

Uma refeição.

- **Colunas:** `id`, `user_id` (FK), `source` (`photo` ou `manual`), `status` (`pending`, `processing`, `analyzed`, `failed`, `confirmed`), `photo_id` (referência a `food_photos`, sem chave estrangeira, e nula só em refeição manual: **o identificador permanece depois do prazo da foto**, e é a ausência de uma foto `stored` que tira a `photo_url` da resposta), `result_code` (`no_food`, `unreadable` ou nulo), `estimate_partial` (booleano), `meal_at`, `local_date`, `calories_min`, `calories_likely`, `calories_max` (`decimal`, sem arredondar), `confirmed_at`, `client_request_id`, `resume_attempts` (inteiro, padrão 0: quantas vezes `StuckEntriesJob` retomou a refeição presa em processamento; no máximo 3 retomadas, e depois a refeição vira `failed`).
- **Constraints:** `calories_min <= calories_likely <= calories_max` quando preenchidas; único em `(user_id, client_request_id)`, para evitar registro duplicado em nova tentativa; `status`, `source` e `result_code` validados por `CHECK`; `resume_attempts >= 0`.
- **Índices:** `(user_id, local_date DESC, meal_at DESC, id DESC)` para o histórico paginado; `photo_id`.
- **Soft delete:** não. Excluir apaga a linha, os itens e a foto. `photo_id` substitui o antigo `photo_key`: a chave do objeto fica só em `food_photos`.

### `food_items`

Itens de uma refeição.

- **Colunas:** `id`, `food_entry_id` (FK, `ON DELETE CASCADE`), `catalog_item_id` (referência), `display_name`, `quantity_grams_min`, `quantity_grams_likely`, `quantity_grams_max`, `household_measure`, `calories_min`, `calories_likely`, `calories_max`, `protein_g_*`, `carbs_g_*`, `fat_g_*`, `confidence`, `hidden_ingredients_possible`, `origin` (`ai` ou `user`), `corrected_from_item_id`, `nutrition_source_ref` (`{source, version, id}`). Os números são `decimal`, sem arredondamento: ele só acontece ao montar a resposta.
- **Constraints:** faixas ordenadas; `confidence` entre 0 e 1 quando presente; item corrigido pela pessoa mantém `origin = 'user'`.
- **Índices:** `food_entry_id`.

## Food AI

### `food_photos`

Dona da foto da refeição e do ciclo de vida do objeto no armazenamento privado. A cota diária conta as linhas desta tabela (URL emitida), e não as refeições.

- **Colunas:** `id`, `user_id`, `food_entry_id` (referência), `client_request_id`, `object_key` (aleatória, `food-photos/<uuid>`, sem `user_id` nem data), `content_type`, `byte_size`, `status` (`awaiting_upload`, `stored`, `deleted`), `authorized_at`, `analyzed_at`, `deleted_at`, `quota_refunded_at`, `analysis_requests` (inteiro, padrão 0: quantos pedidos de análise a foto já recebeu; no máximo 3, o primeiro mais duas novas tentativas depois de uma falha, o que dá `analysis_retry_limit`; também separa o envio abandonado, com 0, da foto que chegou a ser analisada, para o `upload_expired`).
- **Constraints:** único em `object_key`; único em `(user_id, client_request_id)`, para que repetir o envio devolva a mesma foto; `status` validado por `CHECK`; `analysis_requests >= 0`.
- **Índices:** `(user_id, authorized_at)` para a cota; `(status, authorized_at)` para envios abandonados; `(status, analyzed_at)` para o prazo de retenção; `food_entry_id`.
- **Retenção:** 30 dias após a análise, por rotina diária; a linha da foto apagada fica mais 7 dias. Ver a tabela de retenção e [ADR 0019](decisions/0019-photo-storage-and-image-processing.md).

### `food_analysis_results`

Cada execução do pipeline. A linha, com `raw_response`, é **apagada** ao excluir a refeição ou a conta, ou 90 dias depois de criada, o que vier primeiro.

- **Colunas:** `id`, `food_entry_id` (referência), `user_id` (FK), `photo_id` (FK para `food_photos`, `ON DELETE CASCADE`), `provider`, `model`, `prompt_version`, `schema_version`, `status` (`running`, `succeeded`, `no_food`, `unreadable`, `failed`, `cancelled`), `raw_response` (JSONB validado), `error_code` (lista fechada por `CHECK`), `started_at`, `finished_at`.
- **Constraints:** único parcial em `(photo_id, prompt_version)` onde `status` não é `failed` nem `cancelled`: uma foto tem no máximo uma execução viva por versão do prompt, e a nova tentativa depois de uma falha cria outra.
- **Índices:** `food_entry_id`; `photo_id`; `(user_id, started_at)`; `(prompt_version, status)` para avaliação.
- **Retenção:** ver a tabela de retenção.

### `ai_usage_records`

Custo por chamada.

- **Colunas:** `id`, `analysis_id` (FK anulável, `ON DELETE SET NULL`, para o custo sobreviver à exclusão da refeição sem vínculo), `user_id` (FK anulável, que a retenção e a exclusão de refeição ou de conta zeram), `provider`, `model`, `input_tokens`, `output_tokens`, `cost_usd`, `occurred_at`.
- **Índices:** `(user_id, occurred_at)` para limite e custo por usuário; `occurred_at` para custo total.

### `prompt_versions`

- **Colunas:** `id`, `version`, `schema_version`, `body_ref`, `activated_at`.
- **Constraints:** único em `version`.

## Food Catalog

### `food_catalog`

Referência sem dados pessoais.

- **Colunas:** `id`, `source`, `source_version`, `source_item_id`, `license`, `name`, `name_pt`, `name_search` (nome normalizado, sem acento e sem caixa, para a busca), `kind` (`ingredient` ou `composition`), `nutrients_per_100g` (JSONB), `review` (`pending_nutritionist` nas composições próprias).
- **Constraints:** único em `(source, source_version, source_item_id)`; `license NOT NULL`, para que nada entre sem licença registrada.
- **Índices:** GIN com `pg_trgm` em `name_search` para a busca (no lugar do `search_vector` do desenho inicial).

### `food_compositions`

Receitas-base de pratos próprios.

- **Colunas:** `id`, `catalog_item_id` (FK), `ingredient_catalog_item_id` (FK), `grams_per_100g`, `notes`.
- **Constraints:** único em `(catalog_item_id, ingredient_catalog_item_id)`.

## Activities

### `activities`

- **Colunas:** `id`, `user_id` (FK), `provider` (`manual` ou `strava`), `external_id`, `activity_type`, `started_at`, `local_date`, `duration_seconds`, `distance_meters`, `elevation_meters`, `visibility`, `backfill`, `source_updated_at`, `deleted_at`.
- **Campos de origem externa:** lista permitida. Rota, coordenadas, ponto de partida e título livre não são gravados ([Strava](STRAVA_INTEGRATION.md)).
- **Constraints:** único parcial em `(provider, external_id)` quando `external_id` existe; `duration_seconds >= 0`.
- **Índices:** `(user_id, local_date DESC)`; `(user_id, activity_type, local_date DESC)` para filtros.
- **Soft delete:** breve (`deleted_at`), para estornos e reconciliação. Removida em definitivo pela rotina de retenção. Em desconexão do Strava, a remoção é imediata.

## Strava Integration

### `integrations`

- **Colunas:** `id`, `user_id` (FK), `provider`, `external_account_id`, `granted_scopes`, `status` (`active`, `revoked`, `error`), `backfill_cursor`, `last_reconciled_at`, `connected_at`.
- **Constraints:** único em `(provider, external_account_id)`; único em `(user_id, provider)`.

### `integration_tokens`

Tokens, cifrados em nível de aplicação.

- **Colunas:** `integration_id` (PK e FK, `ON DELETE CASCADE`), `access_token_ciphertext`, `refresh_token_ciphertext`, `expires_at`, `lock_version`.
- **Concorrência:** `lock_version` e bloqueio na renovação, porque o refresh token antigo é invalidado imediatamente pelo Strava.
- **Índices:** `expires_at`, para renovação antecipada.

### `activity_sync_events`

Registro bruto dos eventos recebidos e estado do processamento.

- **Colunas:** `id`, `integration_id` (referência), `provider`, `object_type`, `object_id`, `aspect_type`, `owner_external_id`, `event_time`, `payload` (JSONB), `status`, `attempts`, `processed_at`.
- **Constraints:** único em `(provider, object_type, object_id, aspect_type, event_time)`, para idempotência no recebimento.
- **Índices:** parcial em `status` para os pendentes.

## Goals

### `goals`

Meta diária de hábito (etapa 05.1). `weekly` e `activity` entram na 05.2, com nova migração.

- **Colunas:** `id`, `user_id` (FK para `users`), `goal_type`, `cadence` (padrão `daily`), `target` (inteiro, padrão 1), `rule_version` (`NOT NULL`, inicial `daily_any_v1`), `status` (`active`, `paused` ou `ended`; padrão `active`), `starts_on` (data local da criação), `ends_on` (nulo até encerrar), `paused_at` (nulo), `created_at`, `updated_at`.
- **Constraints (`CHECK`, no próprio banco):**
  - `goals_goal_type_allowed`: `goal_type` na lista fechada `log_meals`, `include_fruits_vegetables`, `drink_water`, `sleep_routine`, `planned_workout`, que **não** contém calorias, déficit, peso, jejum ou compensação;
  - `goals_cadence_daily` (`cadence = 'daily'`) e `goals_target_one` (`target = 1`);
  - `goals_status_known`;
  - `goals_ended_has_end`: `status <> 'ended' OR ends_on IS NOT NULL`.
- **Índices:** único parcial em `(user_id, goal_type)` com `status IN ('active','paused')` (uma meta viva por tipo; depois de encerrada, a pessoa pode criar de novo); `(user_id, status)` para listar as metas da pessoa.

### `goal_check_ins`

Um dia marcado numa meta. Sem tabela de "dias cumpridos": o estado do dia é calculado.

- **Colunas:** `id`, `goal_id` (FK, `ON DELETE CASCADE`), `user_id` (FK para `users`), `local_date`, `source` (`manual` ou `food_entry`), `source_ref` (UUID nulo; é o `food_entry_id` quando a fonte é `food_entry`, sem chave estrangeira, porque domínios não se ligam por tabela), `checked_at`, `created_at`, `updated_at`.
- **Constraints:** `goal_check_ins_source_known`; `goal_check_ins_ref_matches_source`: `(source = 'manual') = (source_ref IS NULL)`.
- **Índices:** único parcial em `(goal_id, local_date)` com `source = 'manual'` (um check-in manual por meta e dia); único parcial em `(goal_id, source, source_ref)` com `source_ref IS NOT NULL` (uma refeição gera no máximo um check-in por meta, mesmo em reprocessamento); `(user_id, local_date DESC)` e `(goal_id, local_date DESC)` para o histórico.
- **Dados da pessoa:** `goals` e `goal_check_ins` entram na exportação e na exclusão de conta (contexto `goals` no `Shared::DataRegistry`). A exportação não traz `source_ref`, por ser referência interna a outro contexto. Apagar a meta apaga os check-ins em cascata.

### `weekly_plans`

Criada na etapa 05.2.

- **Colunas:** `id`, `user_id` (FK), `week_start`, `planned_items` (JSONB), `recovery_days` (`date[]`).
- **Constraints:** único em `(user_id, week_start)`.

## Missions

### `missions`

- **Colunas:** `id`, `code`, `sport`, `level`, `rule_code`, `rule_version`, `xp_reward`, `starts_at`, `ends_at`, `active`.
- **Constraints:** único em `(code, rule_version)`.

### `user_missions`

- **Colunas:** `id`, `user_id` (FK), `mission_id` (FK), `status` (`assigned`, `completed`, `expired`), `assigned_at`, `completed_at`, `period_key`, `completing_event_id`.
- **Constraints:** único em `(user_id, mission_id, period_key)`.
- **Índices:** `(user_id, status)`.

## Gamification

### `xp_transactions`

Livro-razão de inclusão apenas.

- **Colunas:** `id`, `user_id` (FK), `amount` (positivo ou negativo), `kind` (`award` ou `reversal`), `rule_code`, `rule_version`, `source_event_id`, `source_event_name`, `source_entity_type`, `source_entity_id`, `reverses_transaction_id`, `occurred_at`.
- **Constraints:** único em `(user_id, source_event_id, rule_code)`, o que impede concessão duplicada, inclusive depois de mudar a versão da regra; único em `reverses_transaction_id`, o que impede estorno duplicado. Sem `UPDATE` nem `DELETE` por aplicação, salvo exclusão de conta.
- **Índices:** `(user_id, occurred_at DESC)`; `(user_id, source_entity_type, source_entity_id)` para estornos.

### `user_levels`

Projeção recalculável do livro-razão.

- **Colunas:** `user_id` (PK e FK), `total_xp`, `level`, `curve_version`, `lock_version`, `updated_at`.

### `streaks`

- **Colunas:** `id`, `user_id` (FK), `kind`, `current_count`, `best_count`, `last_counted_date`, `tolerance_used`.
- **Constraints:** único em `(user_id, kind)`.

### `achievements`

- **Colunas:** `id`, `code`, `rule_code`, `rule_version`, `active`.
- **Constraints:** único em `code`.

### `gamification_counters` e `planned_recovery_days`

Projeções locais de Gamification, derivadas só de eventos.

- **`gamification_counters`:** `user_id`, `counter_code`, `period_key`, `value`. Único em `(user_id, counter_code, period_key)`. Sustenta tetos, missões como "3 vezes na semana" e conquistas.
- **`planned_recovery_days`:** `user_id`, `local_date`. Único nos dois campos. Impede pontuar atividade em dia de recuperação planejado.

### `user_achievements`

- **Colunas:** `id`, `user_id` (FK), `achievement_id` (FK), `unlocked_at`, `source_event_id`.
- **Constraints:** único em `(user_id, achievement_id)`.

## Notifications

### `notifications`

- **Colunas:** `id`, `user_id` (FK), `kind`, `template`, `params` (JSONB), `dedupe_key`, `delivered_at`, `read_at`.
- **Constraints:** único em `(user_id, dedupe_key)`.
- **Índices:** `(user_id, read_at, created_at DESC)`.

### `device_tokens`

- **Colunas:** `id`, `user_id` (FK), `token_ciphertext`, `token_digest`, `platform`, `revoked_at`.
- **Constraints:** único em `token_digest`.

## Progress & Analytics

### `progress_snapshots` e `weekly_reports`

Projeções reconstruíveis pelas APIs públicas dos contextos de origem, porque eventos expiram. Sem dado que não exista na origem. Dados de origem Strava mantêm `provider` para apagamento seletivo.

- **Colunas de `progress_snapshots`:** `id`, `user_id` (FK), `local_date`, `metrics` (JSONB de constância, sem calorias).

- **Colunas de `weekly_reports`:** `id`, `user_id` (FK), `week_start`, `summary` (JSONB), `generated_at`.
- **Constraints:** único em `(user_id, week_start)`.

### `usage_facts`

Métricas de ativação e retenção, somente com o consentimento `usage_metrics`. Criada no M1.

- **Colunas:** `user_ref`, `fact` (lista fechada), `occurred_on`. Sem conteúdo de refeições.
- **Constraints:** único em `(user_ref, fact, occurred_on)`.

## Infraestrutura de eventos

### `outbox_events`

- **Colunas:** `id`, `name`, `version`, `user_id`, `correlation_id`, `payload` (JSONB), `occurred_at`, `published_at`, `attempts`, `next_attempt_at`, `dead_at`. `next_attempt_at` guarda a espera crescente entre tentativas (1, 2, 4… 64 minutos); na oitava falha, `dead_at`.
- **Constraints:** `CHECK` no formato de `name` (`contexto.fato`), em `version >= 1`, `attempts >= 0` e `payload` como objeto JSON. `user_id` sem chave estrangeira, porque `shared/` não referencia outro contexto.
- **Índices:** parcial em `(occurred_at) WHERE published_at IS NULL AND dead_at IS NULL`, para o publicador e a conferência; em `user_id`, para a exclusão de conta.
- **Registro de dados:** inscrita no `shared/data_registry` pelo contexto `shared`. A exportação devolve vazio, porque o payload só tem IDs; o apagador remove os eventos da pessoa, exceto `user.deletion_requested`.
- **Descarte:** evento cuja regra registrada em `Shared::Outbox.discard_if` responda verdadeiro é apagado sem entrega. `user.deletion_requested` nunca é descartado. Se a regra falhar, o evento não é entregue e a falha conta como tentativa, com o consumidor `outbox.discard_rule` no alerta.
- **Retenção:** apagar os publicados 30 dias após a publicação. Eventos pendentes e mortos nunca são apagados pela rotina, porque não foram processados: um `consent.revoked` de `health_data` morto continua impedindo um novo consentimento até ser resolvido ([runbook](../operations/RUNBOOK_OUTBOX.md)). Eventos de usuário em exclusão são removidos pelo fluxo de exclusão.

### `consumed_events`

- **Colunas:** `consumer`, `event_id`, `consumed_at`.
- **Constraints:** chave primária em `(consumer, event_id)`, base da idempotência dos consumidores. Chave estrangeira para `outbox_events` com `ON DELETE CASCADE`, com índice em `event_id`.

## Concorrência

| Situação | Controle |
|---|---|
| Duas renovações do mesmo token do Strava | Bloqueio em `integration_tokens` |
| Dois eventos iguais simultâneos | Índices únicos em `activity_sync_events` e `consumed_events` |
| Concessão simultânea de XP | Índice único em `xp_transactions`; atualização de `user_levels` por `lock_version` |
| Conquista desbloqueada duas vezes | Índice único em `user_achievements` |
| Reenvio de foto pelo cliente | Índice único em `(user_id, client_request_id)` em `food_entries` e em `food_photos` |

## Auditoria

- `audit_events` registra ações sensíveis ([SECURITY.md](../security/SECURITY.md)).
- `consent_records` e `xp_transactions` são históricos que não se reescrevem durante a vida da conta. `food_analysis_results` segue a vida da refeição.
- Metadados de auditoria não contêm dados de saúde.

## Retenção

Prazos iniciais, a confirmar com a revisão jurídica ([PRIVACY_AND_LGPD.md](../security/PRIVACY_AND_LGPD.md)). Aplicados por rotina automática.

| Dado | Retenção | Ao excluir a conta |
|---|---|---|
| Fotos (`food_photos`) | O objeto sai 30 dias após a análise (`PhotoRetentionJob`, diário), ou na exclusão da refeição ou da conta, o que vier primeiro. Sem comida detectada ou ilegível: apagado na hora. Envio abandonado (autorizado e não concluído): apagado em 1 hora. Foto armazenada e nunca analisada: apagada em 24 horas. A linha fica marcada `deleted` por 7 dias de carência e depois sai, se o objeto foi de fato apagado | Apagadas |
| Refeições e itens | Enquanto a conta existir | Apagados |
| `food_analysis_results` (inclui `raw_response`) | **O que vier primeiro** entre o fim da vida da refeição (a análise é apagada junto, com a foto) e 90 dias após a criação. Depois disso não sobra nada da análise: o custo fica em `ai_usage_records` | Apagados, incluindo `raw_response` |
| `ai_usage_records` | Vínculo com a pessoa e com a análise por 90 dias, ou até apagar a refeição, o que vier primeiro; depois, só provedor, modelo, tokens e custo | Vínculo removido; só contagem e custo |
| Atividades | Enquanto a conta existir e, no caso do Strava, enquanto a integração durar | Apagadas |
| Tokens | Até a desconexão | Apagados |
| `activity_sync_events` | 30 dias | Apagados |
| `outbox_events` e `consumed_events` | 30 dias após a publicação; pendentes e mortos ficam até serem resolvidos | Removidos ou anonimizados |
| XP, metas, missões e conquistas | Enquanto a conta existir | Apagados |
| `consent_records` e `audit_events` | Proposta provisória de 5 anos, a confirmar na revisão jurídica. Em conta ativa, `consent_records` mantém o último registro de cada finalidade além dos 5 anos, porque prova o consentimento vigente; o de conta excluída segue o prazo | Mantidos sem conteúdo de saúde, ligados ao mesmo UUID |
| `sessions` e `device_tokens` | Até expirar ou revogar, mais 30 dias | Apagados |
| `notifications` | 90 dias | Apagadas |
| `weekly_reports`, `progress_snapshots`, `weekly_plans` | Enquanto a conta existir | Apagados |
| `usage_facts` | Definida no M1; apagada ao revogar `usage_metrics` | Apagada |
| Backups | Rotação definida no M1 | Expiram com a rotação; a lista de exclusões é reaplicada após qualquer restauração |
