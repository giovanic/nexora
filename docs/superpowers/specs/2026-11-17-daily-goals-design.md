# Design — Etapa 05.1: metas diárias

- **Data:** 2026-11-17
- **Estado:** aprovado pelo responsável em 2026-11-17 ("aprovo")
- **Fase:** [PHASE_05_GOALS.md](../../roadmap/phases/PHASE_05_GOALS.md), etapa `05.1`. Os critérios `AC-05.1-01` a `AC-05.1-05` de lá são a definição de pronto, e este design não os repete.
- **Arquitetura de referência:** [DOMAIN_MODEL.md](../../architecture/DOMAIN_MODEL.md) (seção 8, Goals, e catálogo de eventos), [DATABASE_DESIGN.md](../../architecture/DATABASE_DESIGN.md) (Goals), [API_DESIGN.md](../../architecture/API_DESIGN.md) (Goals), [HEALTH_DATA_SAFETY.md](../../security/HEALTH_DATA_SAFETY.md) (metas permitidas e textos), [ADR 0011](../../architecture/decisions/0011-no-calorie-goals.md).
- **Fontes externas:** nenhuma, conforme o documento da fase.

Marcações: **[R]** decisão do responsável; **[E]** escolha de engenharia, delegada pelo responsável em 2026-11-17 ("faça da forma que achar melhor para todas as perguntas") e sujeita à aprovação deste documento.

## 1. Intenção

A pessoa escolhe alguns hábitos diários de uma lista fechada e segura, marca o que fez no dia com um toque, e vê o que já cumpriu. A meta de registrar refeições avança sozinha quando uma refeição é confirmada. É a segunda metade do primeiro entregável e entra no beta (M1). O tom é de constância sem cobrança: nada de "você falhou", nada de medo de perder, pausa fácil.

## 2. Decisões do responsável [R]

1. **Cumprir é "fiz hoje"** (opção A, 2026-11-17). Cada meta diária é binária: um check-in fecha o dia. Não há quantidade por dia ("6 copos", "3 refeições").

## 3. Objetivos, não objetivos, antiobjetivos

**Objetivos:** os critérios `AC-05.1-*`; contexto `Goals` com API pública; consumo de `food_entry.confirmed` e `food_entry.deleted`; eventos `goal.created`, `goal.completed`, `goal.uncompleted` e `goal.deleted` na outbox; telas móveis de metas do dia, criação, detalhe e histórico; exclusão e exportação de conta alcançando as tabelas novas.

**Não objetivos:** metas semanais, planejamento, dias de recuperação, confirmação por atividade e sugestões (etapa 05.2); XP, sequências e conquistas (Fase 06); lembretes e notificações (Fase 08); tela web de metas; tratamento visual (Fase 07); `goal.progressed` (sem sentido numa meta binária; fica para metas semanais).

**Antiobjetivos:** qualquer tipo ligado a calorias, déficit, peso, medidas, jejum ou compensação; mostrar dias "perdidos", "falhados" ou em vermelho; contagem de dias seguidos (é da Fase 06, com tolerância); texto livre digitado pela pessoa na meta; comparação com outras pessoas; meta que o cliente conclua por conta própria.

## 4. Decisões técnicas [E]

### 4.1 Tipos de meta

Lista fechada, igual no código (`Goals::GoalType::ALL`) e no `CHECK` do banco:

| `goal_type` | Texto no app | Como é cumprida |
|---|---|---|
| `log_meals` | Registrar as refeições do dia | Primeira refeição confirmada no dia, ou check-in manual |
| `include_fruits_vegetables` | Incluir frutas ou vegetais | Check-in manual |
| `drink_water` | Beber água ao longo do dia | Check-in manual |
| `sleep_routine` | Dormir no horário que escolhi | Check-in manual |
| `planned_workout` | Fazer o treino planejado | Check-in manual (confirmação por atividade só na 05.2) |

O nome `include_fruits_vegetables` substitui o exemplo `include_vegetables` do documento da fase, para casar com a tabela de metas permitidas ("Incluir vegetais ou frutas"). "Respeitar o dia de recuperação" fica para a 05.2, junto com o planejamento.

Os textos ficam no app, como as motivações da Fase 02 (`MotivationsStep.tsx`). A API devolve só o código. `GET /goal_types` devolve a lista, e o app ignora códigos que não conhece.

**Rejeição (AC-05.1-05):** `POST /goals` com tipo fora da lista responde `422 validation_failed` com `details: [{ field: "goal_type", code: "unsupported_goal_type" }]` e mensagem neutra ("Esse tipo de meta não está disponível."). Os specs cobrem explicitamente códigos proibidos (`calorie_target`, `calorie_limit`, `calorie_deficit`, `weight_loss`, `target_weight`, `fasting`, `burn_to_eat`) e uma inserção SQL direta que viola o `CHECK`. A mensagem não explica nem julga o pedido.

### 4.2 Modelo de dados

Segue o [DATABASE_DESIGN.md](../../architecture/DATABASE_DESIGN.md), com estes ajustes, que o plano grava lá:

**`goals`:** `id` (UUID), `user_id` (FK para `users`), `goal_type` (`CHECK` na lista), `cadence` (`CHECK` em `daily`; `weekly` entra na 05.2 com nova migração), `target` (inteiro, `CHECK = 1` enquanto só houver metas diárias), `rule_version` (texto, `NOT NULL`), `status` (`active`, `paused`, `ended`), `starts_on` (data local da criação), `ends_on` (nulo até encerrar), `paused_at`, timestamps.

- Índice único parcial em `(user_id, goal_type)` com `status IN ('active','paused')`: uma meta viva por tipo. Depois de encerrada, a pessoa pode criar de novo.
- Índice `(user_id, status)`.

**`goal_check_ins`:** `id`, `goal_id` (FK, `ON DELETE CASCADE`), `user_id`, `local_date`, `source` (`manual`, `food_entry`; `activity` entra na 05.2), `source_ref` (UUID nulo para `manual`; `food_entry_id` para `food_entry`), `checked_at`.

- Único em `(goal_id, local_date)` onde `source = 'manual'`.
- Único em `(goal_id, source, source_ref)` onde `source_ref IS NOT NULL`: uma refeição gera no máximo um check-in por meta, mesmo em reprocessamento.
- Índices `(user_id, local_date DESC)` e `(goal_id, local_date DESC)`.

Sem tabela de "dias cumpridos": o estado de um dia é calculado (4.3). Não há chave estrangeira para tabelas de outro contexto; `source_ref` é só uma referência.

### 4.3 Regra de conclusão e versão

- **Regra `daily_any_v1`:** um dia `D` de uma meta está cumprido quando existe pelo menos um check-in com `local_date = D`. Qualquer fonte conta.
- `rule_version` é gravado na criação da meta e não muda. `Goals::EvaluateDay.call(goal:, local_date:, check_ins:)` escolhe a regra pela versão, numa tabela `RULES = { "daily_any_v1" => ... }`. Uma regra nova vira `daily_..._v2` só para metas novas, e a v1 continua avaliando as antigas. Remover uma versão em uso é proibido por spec.
- A avaliação é uma função pura: os mesmos check-ins, a mesma versão e o mesmo dia dão o mesmo resultado. O AC-05.1-03 é comprovado por tabela de casos mais um spec que reavalia o histórico de uma pessoa e compara.

### 4.4 Check-in manual, fuso e janela

- **Rota:** `POST /goals/:id/check_ins` com `{ "local_date": "2026-11-17" }`. A pessoa pode marcar **hoje ou ontem**, no fuso atual dela (`UserProfile::Api.time_zone`, ou UTC enquanto o perfil está pendente, como em `Nutrition::MealTime`). Fora disso: `422 validation_failed`, `details: [{ field: "local_date", code: "outside_window" }]`. Datas antes de `starts_on` recebem o mesmo código.
- **Desmarcar:** `DELETE /goals/:id/check_ins/:local_date` remove só o check-in manual daquele dia, com a mesma janela. Rota nova, que entra no `API_DESIGN.md`.
- **Repetição:** marcar um dia já marcado responde `200` com o mesmo check-in (idempotente, sem chave extra). Desmarcar o que não existe responde `204`.
- **Meta pausada ou encerrada:** `409 goal_not_active`.
- **Meta de outra pessoa:** `404`.
- **Concorrência:** cada mudança de check-in trava a linha da meta (`SELECT ... FOR UPDATE`) e avalia o dia antes e depois, dentro da mesma transação. Isso evita dois `goal.completed` quando o toque manual e a refeição chegam juntos.
- **Testes de fuso (AC-05.1-02):** horário fixo com `travel_to` em `America/Sao_Paulo`, `America/Manaus`, `Pacific/Auckland` (horário de verão) e `America/New_York` (troca de horário em 2026-11-01). Casos: 23:59 e 00:00 locais; mudança de fuso da pessoa entre dois check-ins; "ontem" logo depois da meia-noite.

### 4.5 Refeições

- **`food_entry.confirmed`** (`food_entry_id`, `local_date`): o consumidor `goals.check_in_from_food_entry` procura a meta `log_meals` ativa da pessoa e grava um check-in `source = 'food_entry'`, `source_ref = food_entry_id`, na `local_date` do evento. Sem a janela de hoje e ontem, porque a data vem da refeição, que a Nutrition já limita a 30 dias. Ignora datas anteriores a `starts_on`, meta pausada ou encerrada, e pessoa sem a meta. Duplicata não faz nada (`consumed_events` mais o índice único). Depois de travar a meta e antes de gravar, se existe marcador de refeição apagada para `(user_id, food_entry_id)`, termina sem gravar e sem evento.
- **`food_entry.deleted`** (`food_entry_id`): o consumidor `goals.remove_food_entry_check_in` apaga o check-in com aquele `source_ref`, se existir, e reavalia o dia. Antes de procurar o check-in, trava as metas `log_meals` da pessoa (qualquer status, em ordem de `id`) e grava o marcador `(user_id, food_entry_id)` na tabela `goal_removed_food_entries` (idempotente, sem chave estrangeira para Nutrition).
- **Ordem dos eventos:** `confirmed` e `deleted` da mesma refeição podem chegar em qualquer ordem (`PublishJob` com `SKIP LOCKED` e vários workers; um evento que falha volta depois dos seguintes). Os dois consumidores começam tomando a mesma trava consultiva da pessoa (`pg_advisory_xact_lock` sobre a chave `goals.meal_events:<user_id>`, de transação), que é o que os serializa, inclusive quando a pessoa ainda não tem meta `log_meals` ou a cria no meio (uma trava nas linhas de `goals` não cobre esse caso). Depois travam as linhas das metas, que também serializam com o check-in manual. A ordem de travas na entrega é sempre: linha do evento na outbox, `users` (`FOR SHARE`), trava consultiva, linhas de `goals` (por `id`) e, por fim, o marcador (cuja FK toma `FOR KEY SHARE` em `users`); um caminho novo que trave `users FOR UPDATE` e depois `goals` quebraria essa ordem. Se a confirmação commita antes, a exclusão espera e enxerga o check-in; se a exclusão commita antes, a confirmação enxerga o marcador e não grava. Exclusão de pessoa sem linha em `users` (conta já apagada) é um no-op silencioso: o marcador não é gravado e o evento é publicado normalmente. Uma exclusão que commita depois da exclusão de conta pode deixar um marcador (só ids), removido pela retenção de 30 dias. Os marcadores são apagados 30 dias após a criação, o mesmo prazo dos eventos publicados da outbox, por `Goals::RemovedFoodEntriesRetentionJob` (diário). O marcador não entra na exportação, como `source_ref`: é só o id de uma refeição de outro contexto; entra na exclusão de conta. *Alterado em 2026-11-27 por decisão do responsável (opção b).*
- **Meta criada depois da refeição:** não há retroativo. Goals não consulta Nutrition (fronteira `goals: [user_profile]`), e a pessoa pode marcar à mão. Mudar isso exigiria alterar a fronteira, o que não se justifica agora.

### 4.6 Eventos publicados

Todos pela outbox, na mesma transação da mudança, e passando no `PayloadCheck`:

| Evento | Quando | Payload |
|---|---|---|
| `goal.created` | Criação | `goal_id`, `goal_type` |
| `goal.completed` | Um dia passa de não cumprido a cumprido | `goal_id`, `goal_type`, `local_date`, `period_key` (a data ISO, para metas diárias), `rule_version` |
| `goal.uncompleted` | Um dia passa de cumprido a não cumprido | `goal_id`, `period_key` |
| `goal.deleted` | A pessoa apaga a meta (4.7) | `goal_id` |

Nenhum consumidor nesta etapa. Pausar, retomar e encerrar não geram eventos novos (o catálogo do `DOMAIN_MODEL.md` não os prevê, e ninguém precisa deles ainda). `rule_version` entra em `goal.completed` para a Fase 06 poder reproduzir decisões. O plano atualiza o catálogo de eventos.

### 4.7 Criar, editar, pausar, encerrar (AC-05.1-01)

- `POST /goals` `{ goal_type }`. `cadence = daily`, `target = 1`, `rule_version = daily_any_v1`, `starts_on` = hoje no fuso da pessoa. Responde `201` com a meta nova, ou `200` com a meta viva (ativa ou pausada) que já existe daquele tipo. A repetição é idempotente pelo índice único parcial, sem `client_request_id`.
- `PATCH /goals/:id` `{ status: "paused" | "active" | "ended" }`. Na meta binária, editar é pausar, retomar ou encerrar. Não há outro campo editável nesta etapa, porque texto livre não é permitido e `target` é fixo. Encerrar grava `ends_on` = hoje, mantém o histórico visível e é definitivo: `ended` não volta a `active`. Para retomar, a pessoa cria outra meta do mesmo tipo.
- `DELETE /goals/:id` **apaga** a meta e seus check-ins (eliminação, LGPD art. 18), como `DELETE /food_entries/{id}` na Fase 03. Publica `goal.deleted` (`goal_id`), e não um `goal.uncompleted` por dia. O efeito sobre XP é decidido na Fase 06, que já encontra o evento pronto.
- `GET /goals` lista as metas ativas e pausadas, com `today_local_date` e, para cada uma, `done_today` e `done_yesterday`, calculados pelo backend. O app não decide nada.

### 4.8 Histórico (AC-05.1-04)

- `GET /goals/history?goal_id=&cursor=&limit=` devolve **só os dias cumpridos**, do mais recente para o mais antigo, com `local_date`, `goal_id`, `goal_type` e as fontes do dia (`manual`, `food_entry`). Paginação por cursor em `local_date`, limite padrão 30 e máximo 100.
- Dias não cumpridos não aparecem e não são contados. Isso evita a lista de "falhas", que funcionaria como cobrança.
- Metas encerradas aparecem no histórico, com `status`.
- Isolamento por pessoa: specs com duas contas e `goal_id` alheio (`404`).

### 4.9 Privacidade, exclusão e exportação

- `goals` e `goal_check_ins` são registradas no `Shared::DataRegistry` (`config/initializers/goals_registrations.rb`), com exportador e apagador. O spec de cobertura já exige isso de todo contexto com modelos.
- Metas de hábito são dado sensível (LGPD): nada de `goal_type`, datas ou fontes em log, Sentry ou mensagem de erro. Os `error_code` são de lista fechada.
- **Consentimento:** todas as rotas de Goals usam `require_consent :health_data, except: :destroy`, como as de refeição (`food_entries_controller.rb`). Sem o consentimento, `403 consent_required`. Revogar `health_data` bloqueia as metas e mantém os dados até a pessoa apagar cada meta ou excluir a conta, como as refeições (tabela de efeitos em `PRIVACY_AND_LGPD.md`, que o plano atualiza com a linha de Goals). Os consumidores de refeição não checam consentimento: com `health_data` revogado, as rotas de refeição já não confirmam nada.

### 4.10 App móvel

- **Metas do dia** (`/goals`): lista das metas ativas com um botão "Feito" por meta. Um seletor "Hoje / Ontem" no topo troca o dia marcado. Toque de novo desmarca. Metas pausadas aparecem recolhidas no fim. Acesso por um link na tela da câmera, como o do histórico de refeições.
- **Nova meta:** a lista de tipos de `GET /goal_types`, sem os tipos que a pessoa já tem vivos.
- **Detalhe da meta:** pausar ou retomar, encerrar e apagar (as duas com confirmação, e apagar avisa que o histórico some), e o histórico dos dias cumpridos.
- **Estados:** carregando, vazio ("Escolha um hábito para acompanhar."), erro com tentar de novo, sem rede, ação em andamento. O mesmo padrão das telas de refeição da Fase 03.
- **Textos:** neutros e curtos ("Feito", "Registrado.", "Pausada. Retome quando quiser."). Nada de "falhou", "perdeu", "não esqueça" ou "!". Um spec confere os textos de `goalMessages.ts` contra a lista de expressões proibidas da segurança de saúde.
- A meta `log_meals` mostra "Feito" quando a refeição a cumpriu, com o mesmo visual do check-in manual. Desmarcar só remove o manual. Se o dia continuar cumprido por uma refeição, o app diz "Cumprida pela refeição registrada."

### 4.11 Contrato, ADRs e dependências

- Toda rota entra antes em `packages/contracts/openapi.yaml`, com tipos gerados e `expect_response_to_match_contract`.
- **Nenhuma dependência nova**, gem ou npm.
- **Nenhuma ADR nova.** O design segue a arquitetura já aceita. A ADR 0011 continua `Proposta`, e sua regra (sem meta de calorias) é imposta pela API e pelo banco.
- Documentos que o plano atualiza: `DATABASE_DESIGN.md` (4.2), `API_DESIGN.md` (rotas e códigos de erro), `DOMAIN_MODEL.md` (consumidores e payloads), `TRACEABILITY.md`.

### 4.12 Escolhas registradas depois da revisão independente [E]

1. **Refeição editada:** corrigir, acrescentar ou remover itens de uma refeição confirmada não muda o `status` nem a `local_date` (`editable_entry.rb`, `remove_food_item.rb`, `recalculate_entry.rb`, conferidos em 2026-11-17). Só a exclusão desfaz a confirmação, e ela publica `food_entry.deleted`. O check-in de refeição não fica desatualizado, e a Nutrition não precisa de evento novo.
2. **Fuso:** `UserProfile::Api.time_zone(user_id:)` já existe e devolve `nil` com o perfil pendente. Goals usa UTC nesse caso, como `Nutrition::MealTime.zone_for`.
3. **Meta pausada:** `GET /goals` devolve `done_today` e `done_yesterday` calculados normalmente, porque os check-ins gravados continuam valendo. Check-in manual recebe `409 goal_not_active`, e refeições confirmadas durante a pausa não geram check-in. Pausar significa "não acompanhar agora". Ao retomar, a pessoa pode marcar hoje e ontem à mão.
4. **Criação repetida:** idempotente pela meta viva do mesmo tipo (4.7), sem coluna `client_request_id`.
5. **`goal.deleted`:** publicado agora, sem consumidor, para a Fase 06 não precisar mudar Goals.

## 5. Abordagens consideradas

1. **Estado calculado a partir dos check-ins** (escolhida). Os check-ins são a única fonte, e a regra versionada calcula cada dia. A reprodutibilidade (AC-05.1-03) sai de graça, e os eventos são disparados pela transição calculada dentro da transação.
2. **Tabela de dias cumpridos**, atualizada a cada check-in. As leituras ficam mais simples, mas surge uma segunda fonte de verdade, que pode divergir dos check-ins e enfraquece a garantia de reavaliação.
3. **Cálculo no app.** Proibido pela regra de que o backend decide a conclusão das metas.

## 6. Restrições

As do `CLAUDE.md` e das rules: TDD; regras no backend; Goals só fala com User Profile por `UserProfile::Api` e ouve Nutrition por eventos; outbox na mesma transação; consumidores idempotentes; nenhum dado de saúde em logs; textos contra a lista de segurança de saúde; textos de metas revisados por profissional de saúde antes do M1 (`AC-M1-11`, fora desta etapa).

## 7. O que fica a critério de quem executar

Nomes de classes e serviços internos; formato exato do cursor; organização dos componentes do app; o número exato de casos da tabela de regras, desde que cubra fontes misturadas, desmarcar com refeição restante, refeição apagada com check-in manual restante e datas fora da janela.
