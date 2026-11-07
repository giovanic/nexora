# Plano de implementação da Fase 01 — Foundation & DX

> **Para quem executa:** SUB-SKILL OBRIGATÓRIA: `superpowers:executing-plans` ou `superpowers:subagent-driven-development`, conforme a escolha do responsável. Os passos usam checkbox (`- [ ]`). Código de produto segue `superpowers:test-driven-development`.

**Objetivo:** esqueleto real do monorepo, com API, Sidekiq, web e mobile subindo de um clone limpo, conversando por contrato, com CI que reprova defeitos reais e nenhuma funcionalidade de negócio.

**Arquitetura:** monólito Rails em modo API, com domínios como namespaces vazios em `app/domains/`, verificados por um teste de limites. Contrato OpenAPI 3.1 escrito primeiro, validado nos testes do backend e fonte dos tipos dos clientes. PostgreSQL e Valkey em Docker, ligados só a `127.0.0.1`.

**Stack:** Ruby 4.0.9 (candidata), Rails 8.1.4.1, Sidekiq 8.1.7, RSpec, PostgreSQL 18.6, Valkey 9.1.3, Node 26 (candidata), React 19.3, Vite 8.3, Expo SDK 58, TypeScript 6.0, Sentry, GitHub Actions.

**Design:** [2026-11-06-foundation-design.md](../specs/2026-11-06-foundation-design.md). **Critérios:** [PHASE_01_FOUNDATION.md](../../roadmap/phases/PHASE_01_FOUNDATION.md). Leia os dois.

## Restrições globais

- Nenhuma funcionalidade de negócio, tela de produto, outbox, cadastro, deploy.
- Sem marca: `Fitness Companion` e `nexora` não aparecem em código ou tela. Módulo Rails `Backend`; pacote `@app/contracts`.
- API na porta `3010`; PostgreSQL em `127.0.0.1:5434`; Valkey em `127.0.0.1:6380`; web em `5173`.
- Variável da fila continua `REDIS_URL`.
- Commit com autor `giovanic.miranda@gmail.com` (já configurado no repositório) e terminando em `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Repositório público: nenhum segredo real, nem em branch descartável.
- Nunca em logs, erros ou monitoramento: tokens, senhas, e-mails, fotos, URLs assinadas, itens de refeição, valores nutricionais.
- Dependência fora das listadas no design exige justificativa registrada: por que, alternativa, manutenção, licença.
- Falha em comando: `superpowers:systematic-debugging` antes de corrigir. Nada de `continue-on-error`, teste ignorado ou mudar o teste para passar.
- Toda evidência (comando, código de saída, resultado) é anotada para o relatório da fase.
- Comandos da API rodam em `apps/api`, com a pilha de `docker compose up -d` no ar.

## Foco de revisão

Situações que o design implica e os critérios não testam diretamente. Cada uma tem teste na tarefa dona.

1. PostgreSQL ou Valkey **travados**, aceitando conexão sem responder: `/health/ready` responde 503 em até 3 segundos, sem pendurar (Tarefa 4).
2. `X-Correlation-Id` hostil, com quebra de linha, JSON ou 10 KB: é descartado e um novo é gerado, sem alterar o formato do log (Tarefa 6).
3. API responde HTML de proxy, 502 ou JSON com formato inesperado: o cliente mostra o estado de erro, sem quebrar; e 503 de prontidão válido aparece como problema de dependência, não como falha de rede (Tarefas 10 e 11).
4. Corpo JSON malformado e rota inexistente: resposta no formato central de erro, nunca HTML nem exceção exposta (Tarefa 3).
5. Rotas `/internal/*` em produção: inexistentes. Produção sem variável obrigatória: não inicia, e a mensagem cita o nome da variável, não o valor (Tarefas 3 e 5).

---

## Tarefa 0: Registrar o início e isolar o trabalho

**Critérios:** nenhum; evidência do protocolo. **Depende da autorização de commit e push.**

- [ ] Registrar em `docs/roadmap/STATUS.md` a transição `01`: `Em planejamento` → `Em desenvolvimento`, com a mensagem de aprovação e a data.
- [ ] Rodar `bash scripts/verify-harness.sh`. Esperado: código 0, porque o check `scope` deixa de reprovar.
- [ ] Criar `docs/close-phase-00` a partir de `main`, levando as alterações locais (sem `stash`): `git switch -c docs/close-phase-00`.
- [ ] Fazer commit de `STATUS.md`, `TRACEABILITY.md`, relatório da Fase 00, `EXTERNAL_SOURCES.md`, design e este plano. Mensagem: `docs: close phase 00 and plan phase 01`.
- [ ] Push, PR e merge por `gh pr merge --squash --delete-branch`; em seguida, `git switch main && git pull --ff-only`.
- [ ] Usar `superpowers:using-git-worktrees` para criar `.worktrees/phase-01` na branch `phase/01-foundation`, a partir de `main`. Todo o resto acontece lá.

## Tarefa 1: Validar versões antes de fixar

**Critérios:** `AC-01-10` (NFR-OPS-001). **Arquivos:** `docs/architecture/decisions/0002-technology-baseline.md`, `0004-domain-events-transactional-outbox.md`, `docs/architecture/EXTERNAL_SOURCES.md`.

Trabalho descartável, em diretório temporário fora do repositório, por isso sem TDD. Só o resultado fica.

- [ ] Instalar Ruby 4.0.9 com `rbenv install 4.0.9`, e Node 26 com `nvm install 26`.
- [ ] Subir `postgres:18.6` e `valkey/valkey:9.1.3` em containers temporários, em portas livres.
- [ ] Gerar uma aplicação mínima com Rails 8.1.4.1 em modo API e adicionar `sidekiq`, `rspec-rails`, `openapi_first`, `lograge`, `sentry-rails`, `sentry-sidekiq`, `rack-cors`, `brakeman`, `bundler-audit`, `packwerk`.
- [ ] Comprovar: `bundle install` e `rails db:prepare`; um job enfileirado é processado por um processo `sidekiq` real no Valkey; um request spec passa; `openapi_first` aprova um contrato 3.1 correto e reprova uma resposta divergente.
- [ ] Rodar Packwerk contra duas violações plantadas: dependência proibida e referência a constante que não seja `Api`. Anotar o que detecta.
- [ ] Em Node 26: `npm ci` e `tsc` em web e mobile, geração com `openapi-typescript` usando TypeScript 5, e `npx expo-doctor` no mobile.
- [ ] **Se Ruby 4.0.9 falhar:** repetir com 3.4.12. **Se Node 26 falhar:** repetir com 24, depois 22. **Se Valkey falhar:** parar e levar ao responsável, porque o Redis 8 exige aprovação.
- [ ] Atualizar a ADR 0002 para `Aceita`: versões, comandos, resultados, risco do Rails 8.1 só com correções de segurança até 2027-10-10, Valkey e licença. Atualizar a ADR 0004: fila decidida, Sidekiq com Valkey; o restante continua com a Fase 02.
- [ ] Apagar os containers e o diretório temporários.
- [ ] Rodar `bash scripts/verify-harness.sh`. Esperado: código 0. Commit: `docs: decide technology baseline with execution evidence`.

## Tarefa 2: Serviços locais e raiz do monorepo

**Critérios:** `AC-01-01` (parte, NFR-OPS-001). **Arquivos:** criar `docker-compose.yml`, `.nvmrc`, `package.json` (workspaces `apps/web`, `apps/mobile`, `packages/contracts`), `.env.example`. Remover `apps/web/package-lock.json` e `apps/mobile/package-lock.json`, em favor de um lockfile na raiz.

- [ ] `docker-compose.yml` com `name: app-dev`, `postgres:18.6` em `127.0.0.1:5434:5432` (usuário `app`, senha `app_dev`), `valkey/valkey:9.1.3` em `127.0.0.1:6380:6379`, volumes nomeados e `healthcheck`.
- [ ] Rodar `docker compose up -d --wait`. Esperado: código 0. Conferir: `psql` em `5434` responde; `docker compose exec valkey valkey-cli ping` retorna `PONG`.
- [ ] `.env.example`, criado uma vez com a ferramenta de escrita e sem valores reais: `DATABASE_URL`, `REDIS_URL`, `ALLOWED_ORIGINS`, `ERROR_TRACKING_DSN`, `LOG_LEVEL`, `VITE_API_URL`, `VITE_ERROR_TRACKING_DSN`, `EXPO_PUBLIC_API_URL`, `EXPO_PUBLIC_ERROR_TRACKING_DSN`.
- [ ] Commit: `chore: add local services and monorepo root`.

## Tarefa 3: Regenerar a API, saúde do processo e erro central

**Critérios:** `AC-01-08` (NFR-OBS-004). **Arquivos:** regenerar `apps/api`. Criar `app/controllers/health_controller.rb`, `app/controllers/errors_controller.rb`, `lib/required_env.rb`, `config/initializers/required_env.rb`, `spec/requests/health_spec.rb`, `spec/requests/errors_spec.rb`, `spec/lib/required_env_spec.rb`, `spec/boot/production_boot_spec.rb`.

**Produz:** `GET /health/live` → `200 {"status":"ok"}`. Erro central: `{"error":{"code","message","request_id"}}`, com `details` quando houver.

- [ ] `git rm -r apps/api` e gerar de novo com o Ruby decidido: `rails new apps/api --name=backend --api --database=postgresql --skip-test --skip-solid --skip-kamal --skip-thruster --skip-active-storage --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-action-cable --skip-active-job --skip-ci --skip-docker --skip-git`. O nome `backend` evita colisão entre o módulo `Api` e `Api::V1`.
- [ ] Remover `config/credentials.yml.enc` e a rota `/up`. Adicionar `rspec-rails`. Padrões em `database.yml`: desenvolvimento e teste em `postgres://app:app_dev@127.0.0.1:5434/app_<env>`, `connect_timeout: 2`, `checkout_timeout: 1`; `DATABASE_URL` tem precedência. Porta do Puma: `3010`.
- [ ] Rodar `bin/rails db:prepare` e `bundle exec rspec`. Esperado: 0 exemplos, código 0.
- [ ] **RED:** escrever os specs e ver falhar.
  - `health_spec`: `GET /health/live` → 200, `{"status":"ok"}`, **e continua 200 com o PostgreSQL e o Valkey indisponíveis** (dublê de falha nas duas conexões, sem que sejam chamadas).
  - `errors_spec`: `GET /nao/existe` → 404, `error.code == "not_found"`; `POST` com `Content-Type: application/json` e corpo `{"a":` → 400, `error.code == "bad_request"`; exceção provocada → 500, `error.code == "internal_error"`, corpo sem nome de classe nem mensagem da exceção; em todos, `error.request_id` igual ao cabeçalho `X-Request-Id`, e `Content-Type` JSON.
  - `required_env_spec`: `RequiredEnv.missing(env_hash) -> Array<String>` devolve os nomes ausentes entre `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`, `ALLOWED_ORIGINS`.
  - `production_boot_spec`: subprocesso `RAILS_ENV=production bin/rails runner 'exit 0'` com ambiente limpo sai com código diferente de zero e cita os nomes; com as variáveis presentes, sai com 0.
- [ ] **GREEN:** `HealthController#live`; `ErrorsController` como `config.exceptions_app = routes`, além de rota curinga para 404; `config.action_dispatch.show_exceptions = :all` em teste; `RequiredEnv` e inicializador que falha em produção.
- [ ] Rodar `bundle exec rspec` (esperado: tudo verde), `bundle exec rubocop`, `bundle exec brakeman -q --no-pager`, `bundle exec bundle-audit check --update`.
- [ ] Commit: `feat(api): regenerate rails app with liveness and central errors`.

## Tarefa 4: Prontidão real

**Critérios:** `AC-01-02`, `AC-01-08` (NFR-OBS-004). **Arquivos:** criar `app/services/health/readiness_check.rb`; alterar `health_controller.rb`; testar em `spec/requests/health_ready_spec.rb` e `spec/services/health/readiness_check_spec.rb`.

**Produz:** `GET /health/ready` → 200 `{"status":"ok","checks":{"database":"ok","queue":"ok"}}`, ou 503 `{"status":"unavailable","checks":{"database":"ok"|"error","queue":"ok"|"error"}}`. `Health::ReadinessCheck.new(database:, queue:).call -> Result(ok?, checks)`, em que `database` e `queue` respondem a `call`.

- [ ] **RED:**
  - Com PostgreSQL e Valkey reais → 200, corpo exato acima.
  - `queue` em `redis://127.0.0.1:1` → 503, `queue: "error"`, `database: "ok"`.
  - `database` levantando `ActiveRecord::ConnectionNotEstablished` → 503, `database: "error"`, `queue: "ok"`.
  - **Servidor TCP de teste que aceita e nunca responde**, como destino do `queue` → 503 em menos de 3 segundos.
  - Corpo 503 sem URL, host, porta ou mensagem de exceção.
- [ ] **GREEN:** `SELECT 1` no PostgreSQL; `RedisClient.config(url:, connect_timeout: 0.5, read_timeout: 0.5, write_timeout: 0.5)` com `PING`. Toda exceção vira `"error"`.
- [ ] Rodar `bundle exec rspec`. Esperado: tudo verde.
- [ ] **Demonstração, para o relatório:** com a API no ar, `curl -i localhost:3010/health/ready` em cada um dos casos: tudo no ar, `docker compose stop valkey`, `docker compose start valkey` seguido de `docker compose stop postgres`, e tudo de volta. Esperado: 200, 503, 503, 200.
- [ ] Commit: `feat(api): add readiness check for database and queue`.

## Tarefa 5: Sidekiq com prova real

**Critérios:** `AC-01-03`. **Arquivos:** criar `config/sidekiq.yml`, `config/initializers/sidekiq.rb`, `app/jobs/smoke_job.rb`, `app/controllers/internal/smoke_jobs_controller.rb`, `spec/integration/smoke_job_spec.rb`, `spec/requests/internal_routes_spec.rb`, `spec/support/sidekiq_process.rb`.

**Produz:** `POST /internal/smoke_jobs` → 202 `{"id":"<uuid>"}`. `GET /internal/smoke_jobs/:id` → 200 `{"status":"pending"|"done"}`. `SmokeJob.perform_async(id)`, de `Sidekiq::Job`, grava `smoke:<id>` no Valkey com expiração de 60 s. `spec/support/sidekiq_process.rb` inicia um `bundle exec sidekiq` real e captura o stdout em arquivo temporário.

- [ ] Adicionar `sidekiq`. `REDIS_URL` padrão: `redis://127.0.0.1:6380/0` em desenvolvimento e `/1` em teste.
- [ ] **RED:**
  - `smoke_job_spec`, sem `Sidekiq::Testing`: inicia o processo real, faz `POST`, consulta até `done` com limite de 15 s, encerra o processo.
  - `internal_routes_spec`: com `Rails.env` em `production` e rotas recarregadas, `/internal/smoke_jobs` → 404 no formato central; ao final, restaura as rotas.
- [ ] **GREEN:** rotas `/internal` só em `Rails.env.local?`; controller e job, recebendo só o identificador.
- [ ] Rodar `bundle exec rspec`. Esperado: tudo verde.
- [ ] Commit: `feat(api): process a smoke job through sidekiq and valkey`.

## Tarefa 6: Logs JSON e correlação

**Critérios:** `AC-01-07` (NFR-OBS-001). **Arquivos:** criar `lib/middleware/correlation_id.rb`, `lib/observability/json_log_formatter.rb`, `lib/observability/sidekiq_correlation.rb`, `app/models/current.rb`, `config/initializers/lograge.rb`; alterar `config/initializers/filter_parameter_logging.rb`, `config/initializers/sidekiq.rb`. Testar em `spec/lib/middleware/correlation_id_spec.rb`, `spec/integration/logging_spec.rb`.

**Produz:** `Current.correlation_id`. Cabeçalho `X-Correlation-Id` na resposta. Campos JSON: `timestamp`, `level`, `message`, `request_id`, `correlation_id`, `duration_ms`, quando aplicáveis.

- [ ] Adicionar `lograge`.
- [ ] **RED:**
  - `correlation_id_spec`: valor `abc12345` é preservado e devolvido; ausente gera um novo; `"a\nb"`, `{"x":1}`, 10 KB e menos de 8 caracteres são descartados e substituídos. Formato aceito: `/\A[A-Za-z0-9_-]{8,64}\z/`.
  - `logging_spec`, sobre o processo real de `sidekiq_process.rb` e o log capturado da API: `POST /internal/smoke_jobs` com `X-Correlation-Id: corr-test-1` → toda linha da requisição e do job é JSON válido, e as duas trazem `correlation_id == "corr-test-1"`.
  - `logging_spec`, dados sensíveis: requisição com `?email=a@b.example&token=tok-secret` e corpo com `password`, `photo_url`, `food_items`, `calories` → nenhum dos valores aparece no log, nem depois de uma exceção provocada.
  - Job enfileirado fora de requisição recebe `correlation_id` gerado, nunca `null`.
- [ ] **GREEN:** middleware antes de `Rails::Rack::Logger`; `Lograge` com `custom_options`; formatador JSON em `config.log_formatter`; `Sidekiq::Logger::Formatters::JSON`; middleware de cliente e de servidor do Sidekiq com `Sidekiq::Context.add`; filtro com `password`, `token`, `secret`, `email`, `photo`, `signed_url`, `food`, `meal`, `item`, `nutrition`, `calorie`, `activity`. `LOG_LEVEL` respeitado.
- [ ] Rodar `bundle exec rspec`, `bundle exec rubocop`. Esperado: verde.
- [ ] Commit: `feat(api): add json logs with request-to-job correlation`.

## Tarefa 7: Monitoramento de erros na API

**Critérios:** `AC-01-07` (NFR-OBS-002). **Arquivos:** criar `config/initializers/sentry.rb`, `lib/observability/error_scrubber.rb`, `app/controllers/internal/smoke_errors_controller.rb`; testar em `spec/lib/observability/error_scrubber_spec.rb`, `spec/integration/sentry_spec.rb`.

**Produz:** `POST /internal/smoke_errors`, só em `Rails.env.local?`, levanta `Internal::SmokeError`. `Observability::ErrorScrubber.call(event, hint) -> event`.

- [ ] Adicionar `sentry-ruby`, `sentry-rails`, `sentry-sidekiq`. Antes de configurar, ler de novo a página oficial da versão instalada, porque as opções de privacidade mudaram de nome.
- [ ] **RED**, com o transporte de teste do SDK:
  - Sem `ERROR_TRACKING_DSN`, `Sentry.initialized?` é falso e nada é enviado.
  - Com DSN falso, exceção na requisição gera um evento com o `correlation_id` em tag.
  - O evento não traz `user`, cookies, cabeçalhos de autorização, query string nem corpo, mesmo com `email=` e `token=` na requisição.
  - Exceção em job com `sentry-sidekiq` gera evento com os argumentos removidos.
- [ ] **GREEN:** inicialização condicional, envio de dados pessoais desligado, `before_send` com o `ErrorScrubber`.
- [ ] Rodar `bundle exec rspec`. Esperado: verde.
- [ ] Commit: `feat(api): report errors to sentry without personal data`.

## Tarefa 8: Limites de domínio

**Critérios:** `AC-01-09`, `AC-01-10` (ADR 0003). **Arquivos:** criar `app/domains/<contexto>/.keep`, `app/domains/shared/.keep`, `config/domain_boundaries.yml`, `lib/architecture/domain_boundary_check.rb`, `spec/lib/architecture/domain_boundary_check_spec.rb`, `spec/architecture/domains_spec.rb`; alterar a ADR 0003.

**Produz:** `Architecture::DomainBoundaryCheck.new(root:, rules:).violations -> Array<Violation(file, line, from, to, constant, reason)>`, em que `reason` é `:private_constant` ou `:forbidden_dependency`.

`domain_boundaries.yml`, derivado de `DOMAIN_MODEL.md`. `identity` é permitido a todos, exceto a si mesmo. `shared` é permitido a todos e não referencia nenhum contexto.

| Contexto | Pode chamar `::Api` de |
|---|---|
| `user_profile`, `food_ai`, `food_catalog`, `activities`, `goals`, `missions` | Só `identity`, mais `user_profile` em `activities`, `goals`, `missions` |
| `nutrition` | `food_ai`, `food_catalog`, `user_profile` |
| `strava_integration` | `activities` |
| `gamification` | Nenhum, além de `identity` |
| `notifications` | `user_profile` |
| `progress_analytics` | Qualquer um, exceto `gamification` e `notifications` |
| `identity` | Nenhum |

- [ ] **RED**, com árvores de fixture em diretório temporário:
  - `Nutrition` referencia `FoodCatalog::Api` → sem violação; `FoodCatalog::Item` → `:private_constant`; `::FoodCatalog::Item` → `:private_constant`.
  - `Goals` referencia `Gamification::Api` → `:forbidden_dependency`.
  - `has_many :x, class_name: "FoodCatalog::Item"` → `:private_constant`, por string literal com forma de constante de contexto.
  - Constante do próprio contexto e de fora dos domínios, como `ActiveRecord::Base` → sem violação.
  - Arquivo com sintaxe inválida → falha com o nome do arquivo, nunca passa em silêncio.
  - `domain_boundaries.yml` não tem ciclos e cita só contextos existentes.
  - `domains_spec`: `app/domains` real → `violations == []`.
- [ ] **GREEN:** percorrer com `Prism.parse_file`, visitando `ConstantPathNode`, `ConstantReadNode` e strings literais. Sem nova gem.
- [ ] **Violação plantada, para o relatório:** criar `app/domains/goals/planted.rb` referenciando `Gamification::Api`, rodar `bundle exec rspec spec/architecture/domains_spec.rb` (esperado: FAIL), remover e rodar de novo (esperado: PASS).
- [ ] ADR 0003 para `Aceita`: alternativa, resultado do Packwerk da Tarefa 1, limite conhecido (referência dinâmica e SQL direto). Rodar `bash scripts/verify-harness.sh`. Esperado: código 0.
- [ ] Commit: `feat(api): enforce domain boundaries with a prism check`.
- [ ] **Revisão:** `backend-reviewer`, `software-architect` e `security-reviewer` sobre as Tarefas 3 a 8. Tratar achados com `superpowers:receiving-code-review`.

## Tarefa 9: Contrato

**Critérios:** `AC-01-04` (parte), `AC-01-10` (ADR 0014). **Arquivos:** criar `packages/contracts/openapi.yaml`, `packages/contracts/package.json`, `packages/contracts/generated/api.d.ts`, `apps/api/spec/support/openapi.rb`; alterar `health_spec.rb`, `health_ready_spec.rb`, ADR 0014.

**Produz:** pacote `@app/contracts`, que exporta `components` e `paths`. Esquemas `HealthLive`, `HealthReady`, `Error`. Scripts `generate` e `check` (regenera em arquivo temporário e falha com diferença).

- [ ] Escrever `openapi.yaml`, em OpenAPI 3.1.1, com `/health/live`, `/health/ready` (200 e 503) e o esquema de erro.
- [ ] **RED:** adicionar `openapi_first` e `OpenapiFirst::Test`. Apontar os request specs de saúde para o contrato. Alterar temporariamente um campo do contrato e ver o spec falhar.
- [ ] **GREEN:** restaurar o campo; rodar `bundle exec rspec`. Esperado: verde. Uma rota real fora do contrato também deve reprovar, se a ferramenta permitir; caso contrário, registrar o limite na ADR.
- [ ] Configurar `openapi-typescript` 7.13 com `typescript` 5 só neste pacote. Rodar `npm run generate -w @app/contracts`.
- [ ] Alterar `generated/api.d.ts` à mão, rodar `npm run check -w @app/contracts` (esperado: FAIL), regenerar, e rodar de novo (esperado: PASS).
- [ ] ADR 0014 para `Aceita`: versão 3.1, ferramentas, evidência e riscos. Rodar `bash scripts/verify-harness.sh`. Esperado: código 0.
- [ ] Commit: `feat(contracts): add openapi contract validated by request specs`.

## Tarefa 10: Cliente web

**Critérios:** `AC-01-04`, `AC-01-07` (NFR-OBS-002). **Arquivos:** em `apps/web`, remover a demonstração e `.oxlintrc.json`. Criar `eslint.config.js`, `vitest.config.ts`, `src/features/api-status/{fetchReadiness.ts,useApiStatus.ts,ApiStatusView.tsx,ApiStatusScreen.tsx}`, com testes `*.test.ts(x)` ao lado, `src/shared/monitoring.ts`, `src/shared/monitoring.test.ts`; alterar `src/App.tsx`, `src/main.tsx`, `package.json`.

**Consome:** `components["schemas"]["HealthReady"]` de `@app/contracts`. **Produz:** `fetchReadiness(baseUrl, fetchFn?) -> Promise<ReadinessResult>`, com `ReadinessResult = {kind:"ready", checks} | {kind:"degraded", checks} | {kind:"unreachable"}`. `ApiStatusView` recebe `{state: "loading" | ReadinessResult}`.

- [ ] Trocar TypeScript 7 por 6.0 e oxlint por ESLint com `typescript-eslint`. Adicionar `vitest`, `jsdom`, `@testing-library/react`, `@sentry/react`, `@app/contracts`. Rodar `npm run typecheck -w apps/web`.
- [ ] **RED:**
  - `fetchReadiness`: 200 válido → `ready`; 503 com corpo válido → `degraded`, com os `checks`; 502 com HTML → `unreachable`; 200 com JSON de outro formato → `unreachable`; rejeição de rede → `unreachable`.
  - `ApiStatusView`: `loading` → "Verificando a API…"; `ready` → "API pronta"; `degraded` com `queue: "error"` → "API com problema: fila"; `unreachable` → "Não foi possível falar com a API". Cada estado em elemento com `role="status"`.
  - `ApiStatusScreen`, com `fetch` dublê: mostra carregando e depois o resultado.
  - `monitoring`: sem DSN, não inicializa; com DSN, inicializa com coleta de dados de usuário desligada; o filtro antes do envio remove query string da URL e `user`.
- [ ] **GREEN:** implementar, lendo antes a página atual do `@sentry/react`. Botão "Provocar erro de teste" só se `import.meta.env.DEV`, com teste de que não aparece fora disso. Variáveis `VITE_API_URL` (padrão `http://localhost:3010`) e `VITE_ERROR_TRACKING_DSN`.
- [ ] Configurar `rack-cors` na API, com `spec/requests/cors_spec.rb`: origem em `ALLOWED_ORIGINS` recebe o cabeçalho; outra não; sem configuração, nenhuma; padrão de desenvolvimento `http://localhost:5173`.
- [ ] Rodar typecheck, lint, testes e build de `apps/web`; `bundle exec rspec`. Esperado: todos com código 0.
- [ ] **Captura:** API e web no ar, tela `ready` e tela com `docker compose stop valkey`, por Playwright, salva para o relatório.
- [ ] Commit: `feat(web): show api status from contract types`.

## Tarefa 11: Cliente mobile

**Critérios:** `AC-01-04`, `AC-01-07` (NFR-OBS-002). **Arquivos:** em `apps/mobile`, remover `.claude/`, `AGENTS.md`, `LICENSE`, `.vscode/`, `scripts/reset-project.js`, a demonstração e as dependências e assets que só ela usava. Criar `eslint.config.js`, `src/features/api-status/{fetchReadiness.ts,useApiStatus.ts,ApiStatusView.tsx,ApiStatusScreen.tsx}`, com `__tests__`, `src/shared/monitoring.ts`; alterar `src/app/index.tsx`, `src/app/_layout.tsx`, `package.json`, `app.json`, `metro.config.js`.

**Consome:** o mesmo contrato e a mesma forma de `ReadinessResult` da Tarefa 10. A duplicação é aceita: são dois arquivos pequenos, e pacote compartilhado de código não se justifica agora.

- [ ] Adicionar por `npx expo install`: `jest-expo`, `jest`, `@testing-library/react-native`, `@sentry/react-native`, ESLint. Adicionar `@app/contracts`. Configurar o Metro para o monorepo, conforme a doc da Expo do SDK 58.
- [ ] Rodar `npx tsc --noEmit -p apps/mobile` e `npx expo-doctor` em `apps/mobile`. **Se o Metro não resolver os workspaces:** gerar os tipos em cada cliente, conforme o design, e registrar na ADR 0014.
- [ ] **RED:** os mesmos casos da Tarefa 10 para `fetchReadiness` e `ApiStatusView`, com `accessibilityRole` e texto idênticos; `monitoring` com `sendDefaultPii: false`, e filtro que remove `user` e query string; botão de erro de teste só com `__DEV__`.
- [ ] **GREEN:** implementar, consultando a doc da Expo da versão do SDK. `EXPO_PUBLIC_API_URL` sem padrão fixo de IP; sem ela, a tela mostra `unreachable`.
- [ ] Rodar typecheck, lint e testes. Esperado: código 0.
- [ ] **Com o responsável:** aparelho Android na mesma rede. Testar Expo Go. Se não servir, development build. Resolver a rede até o WSL 2 e anotar exatamente o que funcionou. Capturar a tela pronta e a de problema.
- [ ] Atualizar `docs/engineering/CODING_STANDARDS.md`: usar `npx expo install` e a doc da versão do SDK.
- [ ] Commit: `feat(mobile): show api status from contract types`.
- [ ] **Revisão:** `frontend-mobile-reviewer` sobre as Tarefas 9 a 11. Tratar achados.

## Tarefa 12: CI

**Critérios:** `AC-01-05` (NFR-OPS-002), `AC-01-06` (NFR-SEC-004, NFR-SEC-005). **Arquivos:** criar `.github/workflows/ci.yml`, `.gitleaks.toml` só se houver falso positivo justificado; remover `apps/api/.github` se a geração tiver criado.

**Produz:** jobs `harness`, `secrets`, `api`, `contracts`, `web`, `mobile`, nomes usados na proteção de `main`.

- [ ] Workflow em `pull_request` e `push` para `main`, `permissions: contents: read`, ações fixadas por hash de commit, conferido na fonte. Versões lidas de `.nvmrc` e `apps/api/.ruby-version`.
- [ ] `harness`: `bash scripts/test-verify-harness.sh` e `bash scripts/verify-harness.sh`.
- [ ] `secrets`: `fetch-depth: 0`, binário do Gitleaks v8.30.1 com SHA-256 do arquivo de checksums oficial, `gitleaks git --redact`.
- [ ] `api`: serviços `postgres:18.6` e `valkey/valkey:9.1.3`; `bundle exec rubocop`; `brakeman -w3 --no-pager`; `bundle-audit check --update`; `bin/rails db:prepare`; `bundle exec rspec`, que inclui contrato, limites e processo Sidekiq real.
- [ ] `contracts`: `npm ci`, `npm run check -w @app/contracts`.
- [ ] `web`: `npm ci`, `npm audit --audit-level=high`, typecheck, lint, testes, build.
- [ ] `mobile`: `npm ci`, typecheck, lint, testes.
- [ ] Rodar localmente cada comando acima. Esperado: código 0. Conferir com `grep -n continue-on-error .github/workflows/ci.yml`: nenhuma ocorrência.
- [ ] Commit: `ci: add pipeline with real checks`.
- [ ] Push de `phase/01-foundation` e abrir o PR como rascunho. Acompanhar com `gh run watch`. Esperado: todos os jobs verdes. Anotar o link.

## Tarefa 13: Provar que o CI reprova

**Critérios:** `AC-01-05`, `AC-01-06`, `AC-01-09`. Sem arquivos permanentes.

- [ ] Para cada defeito, criar branch `defect/<nome>` a partir de `phase/01-foundation`, com um único commit, abrir PR contra `phase/01-foundation`, anotar o link da execução e o job que reprovou, fechar o PR com `gh pr close --delete-branch`.

| Branch | Defeito | Job que precisa reprovar |
|---|---|---|
| `defect/api-test` | Expectativa errada em `health_spec` | `api` |
| `defect/api-lint` | Violação do RuboCop | `api` |
| `defect/api-security` | `eval(params[:x])` em um controller | `api` |
| `defect/domain-boundary` | `app/domains/goals/planted.rb` referenciando `Gamification::Api` | `api` |
| `defect/contract` | Campo alterado em `openapi.yaml` sem mudar o código | `api` e `contracts` |
| `defect/web-test` | Texto trocado em `ApiStatusView` | `web` |
| `defect/web-lint` | Variável não usada | `web` |
| `defect/web-types` | `const x: number = "a"` | `web` |
| `defect/mobile-test` | Texto trocado em `ApiStatusView` | `mobile` |
| `defect/mobile-lint` | Variável não usada | `mobile` |
| `defect/mobile-types` | `const x: number = "a"` | `mobile` |
| `defect/harness` | Remover um documento de fase | `harness` |
| `defect/secret` | `api_key = "<40 hex aleatórios gerados na hora>"`, valor falso. Antes de subir, confirmar com o Gitleaks local que detecta | `secrets` |

- [ ] Se um defeito **não** reprovar: isso é bug do CI. Usar `superpowers:systematic-debugging`, corrigir na branch da fase e repetir.
- [ ] Depois que o CI estiver verde: proteger `main` via `gh api`, exigindo os seis jobs. Confirmar lendo a configuração de volta. Se o GitHub recusar, registrar como lacuna no relatório.

## Tarefa 14: Clone limpo e documentação

**Critérios:** `AC-01-01` (NFR-OPS-001), `AC-01-07` (demonstração), `AC-01-10`. **Arquivos:** `docs/operations/LOCAL_DEVELOPMENT.md`, `docs/operations/ENVIRONMENT_VARIABLES.md`, `docs/engineering/CI_CD.md`, `docs/engineering/OBSERVABILITY.md`, `docs/engineering/TESTING_STRATEGY.md`, `docs/security/SECURITY.md`, `docs/security/PRIVACY_AND_LGPD.md`, `docs/roadmap/ROADMAP.md`, `README.md`.

- [ ] `LOCAL_DEVELOPMENT.md`: remover "a confirmar" e descrever pré-requisitos, serviços, API, Sidekiq, web, mobile (com o caminho de rede que funcionou) e testes.
- [ ] Atualizar `CI_CD.md` (repositório público, pendências antigas, etapa de migrations adiada, proteção de `main`, decisão de **não** adotar lint de Markdown, porque o verificador já cobre o formato), `ENVIRONMENT_VARIABLES.md` (sem `RAILS_MASTER_KEY`), `OBSERVABILITY.md` (métricas e alertas para o M1; retenção de logs definida como padrão do ambiente até o M1), `TESTING_STRATEGY.md` (ferramentas confirmadas), `SECURITY.md` (ferramentas e pendência da licença do Brakeman), `PRIVACY_AND_LGPD.md` (Sentry como operador e pendência dos termos do plano gratuito), `ROADMAP.md` (pendência do remoto resolvida) e `EXTERNAL_SOURCES.md` (o que a execução confirmou).
- [ ] **Clone limpo:** clonar `phase/01-foundation` em diretório temporário, com os serviços de desenvolvimento parados, e seguir **só** o documento. Registrar a saída: API responde em `/health/ready` com 200, um job é processado pelo Sidekiq, web abre, Expo sobe. Corrigir o documento e repetir até passar sem improviso.
- [ ] **Demonstração do Sentry, com os DSNs do responsável,** em variáveis de ambiente locais e nunca em arquivo versionado: provocar um erro na API, em um job, na web e no mobile; ver os quatro no Sentry; conferir que nenhum traz dado pessoal. Sem os DSNs, o `AC-01-07` fica **parcial** no relatório.
- [ ] Rodar `bash scripts/verify-harness.sh`, `bash scripts/test-verify-harness.sh`. Esperado: código 0.
- [ ] Commit: `docs: document tested local setup and operations`.

## Tarefa 15: Encerrar

**Critérios:** todos.

- [ ] Remover a seção "Falha conhecida" do `CLAUDE.md` e a menção equivalente no documento da fase e em `LOCAL_DEVELOPMENT.md`.
- [ ] Usar a skill `phase-closeout`: execução final, matriz `TRACEABILITY.md`, revisores (`software-architect`, `backend-reviewer`, `frontend-mobile-reviewer`, `security-reviewer`, `qa-reviewer`), relatório `PHASE_01_REPORT.md`, estado `Em revisão`.
- [ ] Apresentar o relatório e **parar**. A integração da branch depende da decisão do responsável.

## Cobertura dos critérios

| Critério | Tarefas | Prova |
|---|---|---|
| `AC-01-01` | 2, 11, 14 | Clone limpo, saída registrada |
| `AC-01-02` | 4 | Request specs e demonstração com `docker compose stop` |
| `AC-01-03` | 5 | Teste com processo Sidekiq real |
| `AC-01-04` | 9, 10, 11 | Testes de componente e capturas |
| `AC-01-05` | 12, 13 | Execuções no GitHub Actions |
| `AC-01-06` | 12, 13 | Execução com segredo falso plantado |
| `AC-01-07` | 6, 7, 10, 11, 14 | Testes de log e demonstração no Sentry |
| `AC-01-08` | 3, 4 | Request specs |
| `AC-01-09` | 8, 13 | Violação plantada local e no CI |
| `AC-01-10` | 1, 8, 9, 14 | ADRs e check `adr` |
