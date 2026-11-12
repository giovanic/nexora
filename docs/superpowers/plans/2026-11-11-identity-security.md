# Fase 02 — Identity, Security & Privacy: plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: `superpowers:subagent-driven-development` ou `superpowers:executing-plans`, tarefa a tarefa. Passos em checkbox.

**Objetivo:** contas, sessões, consentimentos, perfil, exportação e exclusão, com isolamento entre pessoas comprovado, antes de qualquer dado de saúde.

**Arquitetura:** os contextos `identity` e `user_profile` ficam em `apps/api/app/domains`. A infraestrutura de eventos e o registro de dados ficam em `shared/`. Controllers usam só `<Contexto>::Api`, que devolve objetos `Data`, nunca modelos. Mobile e web consomem o contrato OpenAPI.

**Tecnologias:** Rails 8.1.4.1, Ruby 4.0.9, PostgreSQL 18.6, Valkey, Sidekiq 8.1, Expo SDK 58, React 19.3 com Vite.

**Spec:** [design aprovado](../specs/2026-11-11-identity-security-design.md). Leia junto com o [documento da fase](../../roadmap/phases/PHASE_02_IDENTITY_SECURITY.md); os `AC-02-*` de lá são a definição de pronto.

## Restrições globais

- TDD em todo passo de código: escreva o teste, veja falhar pelo motivo certo, implemente, veja passar.
- Gems novas: só `bcrypt`, `redis` e `sidekiq-cron`. Pacotes npm novos: só `expo-secure-store` no mobile, por `npx expo install`.
- Controllers e código fora de `app/domains` usam somente `Identity::Api` e `UserProfile::Api`. O teste de limites da Fase 01 impõe isso.
- Toda rota nova entra antes em `packages/contracts/openapi.yaml`. Depois, `npm run generate -w @app/contracts`, `expect_response_to_match_contract` nos request specs e o teste de rotas verde.
- Nada de e-mail, senha, token, link de recuperação ou texto livre em log, Sentry ou `audit_events`.
- Recurso de outra pessoa responde `404`. Falta de `health_data` responde `403 consent_required`.
- Mensagens de interface seguem a lista de linguagem de `docs/security/HEALTH_DATA_SAFETY.md`.
- Commits pequenos na branch `phase/02-identity-security`. Sem push para `main`, que está protegida.

## Foco de revisão

1. **E-mail com maiúsculas ou espaços** (`" Ana@X.com "`): cadastro e entrada tratam como o mesmo e-mail que `ana@x.com`. Teste na Tarefa 3.
2. **Renovação simultânea com o mesmo token:** só uma vence, e a outra recebe `401`. Teste na Tarefa 3.
3. **Token expirado ou revogado no mobile:** o app limpa o SecureStore e volta para a tela de entrada, sem travar. Teste na Tarefa 10.
4. **Exclusão com sessões abertas em outros aparelhos:** todas ficam revogadas na hora. Teste na Tarefa 8.
5. **Fuso inválido enviado pelo aparelho** (`"Marte/Base"`): `422`, sem gravar. Teste na Tarefa 6.

---

## Tarefa 0: Registrar início e fontes

**Arquivos:** `docs/roadmap/STATUS.md` (já em `Em planejamento`), `docs/architecture/EXTERNAL_SOURCES.md`, `docs/product/FUNCTIONAL_REQUIREMENTS.md`, `docs/roadmap/phases/PHASE_02_IDENTITY_SECURITY.md`, `docs/roadmap/TRACEABILITY.md`, `docs/security/PRIVACY_AND_LGPD.md`, `docs/architecture/DATABASE_DESIGN.md`.

- [ ] Registrar `STATUS.md` 02 `Em desenvolvimento`, com o plano e a aprovação do responsável como evidência.
- [ ] Acrescentar ao registro de fontes, com data 2026-11-11, os fatos usados no design:
  - gerador de autenticação do Rails só por cookie;
  - `has_secure_password` com bcrypt e limite de 72 bytes;
  - token de reset de 15 minutos;
  - `rate_limit` usando o cache store;
  - Active Record Encryption por variáveis de ambiente, com cifragem determinística;
  - SecureStore em Keychain e Keystore;
  - recomendações da OWASP.
- [ ] Conferir na fonte a manutenção e a versão atuais de `sidekiq-cron` e da gem `redis`. Se alguma estiver sem manutenção, parar e registrar uma decisão.
- [ ] Acrescentar `FR-PROFILE-004` aos requisitos, citá-lo no `AC-02-08`, e regenerar a matriz. Esperado: `bash scripts/verify-harness.sh` com código 0.
- [ ] Ajustar `PRIVACY_AND_LGPD.md` e `DATABASE_DESIGN.md` ao design: registro de apagadores, o que sobra da conta, `sport_profiles` com `ended_at` e `account_deletions` com prazo de 24 horas.
- [ ] Commit: `docs: start phase 02 and record sources`.

## Tarefa 1: Dependências, cache e chaves

**Arquivos:** `apps/api/Gemfile`, `config/application.rb`, `config/environments/{development,test,production}.rb`, `lib/required_env.rb`, `spec/boot/production_boot_spec.rb`, `docs/operations/ENVIRONMENT_VARIABLES.md`.

**Produz:**
- `Rails.cache` em Valkey (`:redis_cache_store`, `REDIS_URL`) em produção e desenvolvimento; `:memory_store` em teste;
- chaves de cifragem por `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY` e `..._KEY_DERIVATION_SALT`, e `AUDIT_IP_HMAC_KEY`;
- `APP_WEB_URL`, para links de e-mail.

- [ ] **RED:** em `production_boot_spec.rb`:
  - `it "refuses to boot without the encryption keys"`: sem cada uma das 4 variáveis, a inicialização falha com o nome dela;
  - `it "uses the queue service as cache store"`: `Rails.cache.class` é `ActiveSupport::Cache::RedisCacheStore`.
- [ ] **GREEN:** adicionar `bcrypt`, `redis` e `sidekiq-cron` no Gemfile. Acrescentar as variáveis ao `RequiredEnv` de produção. Usar chaves fixas, públicas e explícitas só em `development.rb` e `test.rb`, com um comentário que diga isso.
- [ ] `bundle exec rspec spec/boot` e `bundle exec bundle-audit check --update`. Esperado: código 0.
- [ ] Documentar as variáveis em `ENVIRONMENT_VARIABLES.md`. Commit: `feat(api): add cache store and encryption keys`.

## Tarefa 2: Outbox e registro de dados em `shared/`

**Arquivos:**
- `app/domains/shared/outbox.rb`
- `app/domains/shared/outbox/{event.rb,consumed_event.rb,publish_job.rb,reconcile_job.rb}`
- `app/domains/shared/data_registry.rb`
- `config/initializers/sidekiq_cron.rb`, `config/schedule.yml`
- migrations `outbox_events` e `consumed_events`
- `spec/domains/shared/*`

**Produz:**
- `Shared::Outbox.publish!(name:, user_id:, payload: {}, version: 1) -> Shared::Outbox::Event`: precisa estar dentro de uma transação; levanta erro fora dela.
- `Shared::Outbox.subscribe(event_name, consumer: String) { |event| ... }`: registra o consumidor ao iniciar a aplicação.
- `Shared::Outbox::PublishJob` (a cada minuto): entrega os pendentes a cada consumidor. Idempotência por `consumed_events (consumer, event_id)` gravado na transação do efeito. Até 8 tentativas por consumidor; depois disso, `dead_at` e alerta no Sentry, só com nome do evento e consumidor.
- `Shared::Outbox::ReconcileJob` (a cada hora): avisa sobre evento publicado há mais de 1 hora sem `consumed_events` de algum consumidor esperado.
- `Shared::DataRegistry.register(context:, tables:, exporter:, eraser:)`, `.export(user_id:) -> Hash`, `.erasers -> Array<[context, callable]>`, `.registered_tables -> Array<String>`.

- [ ] **RED, outbox:**
  - `publishes in the same transaction`: rollback faz o evento sumir;
  - `delivers once even if run twice`;
  - `retries a failing consumer without repeating the ones that succeeded`;
  - `marks dead after 8 attempts`;
  - `reconcile reports a missing consumer`;
  - `refuses publish! outside a transaction`.
- [ ] **RED, registro:** `spec/domains/shared/data_registry_coverage_spec.rb` lê `ActiveRecord::Base.connection.tables` e exige que toda tabela com coluna `user_id`, mais `users`, esteja em `registered_tables`. Nesta tarefa ainda não há tabelas de usuário, então o teste roda e passa; ele precisa reprovar quando a Tarefa 3 criar uma tabela nova sem registro.
- [ ] **GREEN:** implementar, com o cron em `config/schedule.yml`.
- [ ] `bundle exec rspec spec/domains/shared spec/architecture`. Esperado: código 0. Commit: `feat(shared): add transactional outbox and data registry`.

## Tarefa 3: Contas e sessões

**Arquivos:**
- `app/domains/identity/{api.rb,models/user.rb,models/session.rb,models/audit_event.rb,services/register.rb,services/authenticate.rb,services/refresh_session.rb,services/revoke_session.rb,services/record_audit.rb}`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/api/v1/{registrations,sessions}_controller.rb`
- migrations `users`, `sessions`, `audit_events`
- `config/routes.rb`, `packages/contracts/openapi.yaml`, specs

**Esquema:**
- **`users`:** `email`, cifrado de forma determinística, `NOT NULL`, índice único; `password_digest NOT NULL`; `adult_confirmed_at NOT NULL`; `deleted_at`.
- **`sessions`:** `user_id`, `token_digest` com índice único, `client` (`web` ou `mobile`), `device_label`, `last_used_at`, `idle_expires_at`, `absolute_expires_at`, `revoked_at`.
- **`audit_events`:** `user_ref`, `action`, `metadata` em JSONB com lista fechada por ação, `ip_hmac`, `occurred_at`.

**Produz:**

```ruby
Identity::Api.register(email:, password:, adult_confirmed:, client:, device_label:, ip:) # => Result(session_token:, user_id:) | Errors
Identity::Api.authenticate(email:, password:, client:, device_label:, ip:)              # => Result | :invalid
Identity::Api.session_for(token:)    # => Identity::Api::SessionInfo(id:, user_id:, client:) | nil; atualiza last_used_at e idle
Identity::Api.refresh(token:)        # => novo token | nil (token antigo revogado na mesma transação, FOR UPDATE)
Identity::Api.sessions(user_id:)     # => [SessionInfo]
Identity::Api.revoke_session(user_id:, session_id:) # => true | :not_found
Identity::Api.revoke_all(user_id:)
Identity::Api.verify_password(user_id:, password:)  # => Boolean
```

**Rotas** (todas no contrato):
- `POST /api/v1/registrations`;
- `POST /api/v1/sessions`, `GET /api/v1/sessions`, `POST /api/v1/sessions/refresh`;
- `DELETE /api/v1/sessions/current`, `DELETE /api/v1/sessions/{id}`.

**Regras:**
- **Transporte:** o corpo traz `client`. Com `mobile`, a resposta traz `token`. Com `web`, define o cookie `__Host-session` (`httponly`, `secure`, `same_site: :lax`, `path: "/"`), sem token no corpo.
- **Concern `Authentication`:** lê `Authorization: Bearer` ou o cookie, e expõe `current_user_id`. Para cookie, exige `Origin` em `AllowedOrigins` nos métodos que alteram estado.
- **Tempos:** inatividade de 30 dias e prazo absoluto de 90.
- **Senha:** de 12 caracteres a 72 bytes.
- **E-mail:** `normalizes :email, with: ->(e) { e.strip.downcase }`.
- **Limites:** `rate_limit` com `name:` em cadastro, entrada e refresh (10 em 3 minutos por IP; 5 em 15 minutos por e-mail), respondendo `429` com `Retry-After`.
- **Erros:** entrada inválida dá `401 invalid_credentials`, com a mesma mensagem para e-mail inexistente e senha errada. Cadastro com e-mail existente dá `422 email_taken`; essa é a exceção aceita no design.
- **Eventos e dados:** publica `user.registered` e registra no `DataRegistry` as tabelas `users`, `sessions` e `audit_events`.

- [ ] **RED**, em `spec/requests/registrations_spec.rb` e `sessions_spec.rb`, mais specs de modelo:
  - `rejects sign up without adult confirmation` (API `422`) e `database rejects a user without adult_confirmed_at` (`ActiveRecord::NotNullViolation`);
  - `treats " Ana@X.com " as ana@x.com` (Foco 1);
  - `stores only the token digest`;
  - `web gets a __Host- cookie and no token in the body`;
  - `mobile gets a token and no cookie`;
  - `revoked and expired sessions get 401`;
  - `idle and absolute expiry`, com `travel_to`;
  - `concurrent refresh: one wins, the other gets 401` (Foco 2), com threads e banco real;
  - `cookie request with a foreign Origin is refused`;
  - `rate limit answers 429 with Retry-After`;
  - `same message for unknown email and wrong password`;
  - `audit records a failed sign in without the typed email`;
  - `email is encrypted at rest`: o SQL bruto não contém o e-mail;
  - `password between 12 characters and 72 bytes`.
- [ ] **GREEN:** implementar, seguindo os padrões do gerador do Rails. Só a Api é pública.
- [ ] `bundle exec rspec`, `bundle exec rubocop`, `bundle exec brakeman -q --no-pager -w2`, `npm run check -w @app/contracts`. Esperado: código 0.
- [ ] Commit: `feat(identity): add accounts and device sessions`.

## Tarefa 4: Recuperação de senha

**Arquivos:**
- `app/domains/identity/{services/request_password_reset.rb,services/reset_password.rb,mailers/password_reset_mailer.rb}` e views de texto do mailer
- `app/controllers/api/v1/password_resets_controller.rb`
- contrato e specs

**Produz:**
- `Identity::Api.request_password_reset(email:)`: sempre devolve `nil`, exista ou não a conta, com tempo de resposta parecido.
- `Identity::Api.reset_password(token:, password:) -> true | :invalid`.

**Rotas:**
- `POST /api/v1/password_resets` responde sempre `202`;
- `PATCH /api/v1/password_resets/{token}` responde `204` ou `422 invalid_token`.

**Regras:**
- Link `"#{APP_WEB_URL}/reset-password#token=..."`. O token vai no fragmento, para não chegar a logs de servidor.
- Validade de 15 minutos, pelo `has_secure_password reset_token`.
- Trocar a senha revoga todas as sessões e não entra automaticamente.
- `rate_limit` por IP e por e-mail.
- Em desenvolvimento, `delivery_method :file`, em `tmp/mails`.

- [ ] **RED:**
  - `answers 202 for unknown and known emails`, sem e-mail enviado no caso desconhecido;
  - `token works once`;
  - `token expires after 15 minutes`;
  - `reset revokes every session`;
  - `link uses the fragment and APP_WEB_URL`;
  - `logs never contain the token`.
- [ ] **GREEN**, testes verdes e commit: `feat(identity): add password reset`.

## Tarefa 5: Consentimentos e filtro de `health_data`

**Arquivos:**
- `app/domains/identity/{models/consent_record.rb,services/grant_consent.rb,services/revoke_consent.rb,consent_texts.rb}`
- `config/consents/{health_data,food_photo_ai,strava_integration,usage_metrics}.v1.md`
- `app/controllers/api/v1/consents_controller.rb`
- `require_consent` no concern
- migration `consent_records` e specs

**Produz:**
- `Identity::Api.consent_granted?(user_id:, purpose:) -> Boolean`, calculado a partir do registro mais recente;
- `Identity::Api.consents(user_id:)`, com finalidade, estado, versão vigente e versão aceita;
- `.grant_consent(user_id:, purpose:, version:)` e `.revoke_consent(user_id:, purpose:)`.

**Rotas:**
- `GET /api/v1/consents`;
- `POST /api/v1/consents` com `{purpose, version}`;
- `DELETE /api/v1/consents/{purpose}`;
- `GET /api/v1/consents/{purpose}/text` devolve o texto da versão vigente.

**Regras:**
- Finalidades em lista fechada, com `CHECK` no banco.
- Aceitar uma versão diferente da vigente responde `409 outdated_version`.
- `DELETE` de `health_data` responde `409 deletion_required`, e o consentimento continua.
- Publica `consent.granted` e `consent.revoked`. Registra a tabela no `DataRegistry`: na exclusão, os registros ficam ligados ao UUID.
- `require_consent :health_data` é usado pelas rotas de perfil da Tarefa 6.

- [ ] **RED:**
  - `history keeps every grant and revoke`;
  - `current state comes from the latest record`;
  - `unknown purpose is rejected by the database`;
  - `outdated version is refused`;
  - `revoking health_data answers 409 and keeps it`;
  - `texts are served from config/consents`.
- [ ] **Textos:** rascunhar os quatro em português claro e específico por finalidade, sem autorização genérica, citando a transferência internacional no `food_photo_ai`. **Pedir aprovação do responsável antes de encerrar a fase.**
- [ ] **GREEN**, testes verdes e commit: `feat(identity): add consent records`.

## Tarefa 6: Perfil, motivações e esportes

**Arquivos:**
- `app/domains/user_profile/{api.rb,models/profile.rb,models/sport_profile.rb,services/update_profile.rb,services/set_sport_level.rb}`
- `app/controllers/api/v1/{profiles,sport_profiles}_controller.rb`
- migrations `user_profiles`, `sport_profiles`; contrato e specs

**Esquema:**
- **`user_profiles`:** `user_id` como PK e FK; `display_name`, cifrado de forma não determinística; `time_zone NOT NULL`; `units` (`metric`); `notification_preferences` (JSONB, `{}`); `motivations` (`text[]`, lista fechada `start_caring`, `training_consistency`, `understand_food`, `track_progress`, de 0 a 4).
- **`sport_profiles`:** `user_id`, `sport` (`running`, `walking`, `cycling`, `strength`, `swimming`, `other`), `level` (`beginner`, `intermediate`, `advanced`), `started_at`, `ended_at`. Índice único parcial em `(user_id, sport) WHERE ended_at IS NULL`.

**Produz:**
- `UserProfile::Api.profile(user_id:)`;
- `.update_profile(user_id:, attrs)`;
- `.time_zone(user_id:) -> String`;
- `.sports(user_id:)`, `.set_sport(user_id:, sport:, level:)`, `.remove_sport(user_id:, sport_id:)`.

Consome `user.registered` para criar o perfil vazio, com o fuso enviado no cadastro. Publica `sport_profile.changed`. Registra exportador e apagador.

**Rotas:** `GET/PATCH /api/v1/profile`, `GET/POST /api/v1/sport_profiles`, `DELETE /api/v1/sport_profiles/{id}`. Todas exigem `health_data`.

- [ ] **RED:**
  - `changing a level ends the current row and starts a new one`;
  - `history survives a level change`;
  - `invalid time zone is 422 and nothing is saved` (Foco 5);
  - `motivations outside the list are refused`;
  - `more than 4 motivations are refused`;
  - `without health_data the routes answer 403 consent_required`;
  - `display_name is encrypted at rest`;
  - `profile is created on user.registered, once`.
- [ ] **GREEN**, testes verdes e commit: `feat(user_profile): add profile, motivations and sports`.

## Tarefa 7: Exportação

**Arquivos:**
- `app/domains/identity/services/export_account.rb`
- `app/controllers/api/v1/accounts_controller.rb#export`
- contrato e specs

**Produz:**
- `Identity::Api.export(user_id:, password:) -> Hash | :invalid_password`.
- Rota `POST /api/v1/account/export` com `{password}`. Responde `200` em JSON com `Cache-Control: no-store`, gerado na hora pelo `DataRegistry.export`, sem gravar arquivo.

- [ ] **RED:**
  - `wrong password is 401 and exports nothing`;
  - `export has every registered context and no other person's data`, com duas contas;
  - `registry coverage fails if a context has no exporter`;
  - `response is no-store and never logged`.
- [ ] **GREEN**, testes verdes e commit: `feat(identity): export account data`.

## Tarefa 8: Exclusão de conta

**Arquivos:**
- `app/domains/identity/{models/account_deletion.rb,services/request_deletion.rb,jobs/erase_account_job.rb,jobs/deletion_deadline_job.rb}`
- `accounts_controller#destroy`
- migration `account_deletions`; contrato e specs

**Produz:**
- `Identity::Api.request_deletion(user_id:, password:) -> :scheduled | :invalid_password`.
- Rota `DELETE /api/v1/account` com `{password}`, que responde `202`.

**Fluxo:**
1. Na mesma transação: revoga todas as sessões, cria `account_deletions` com `pending_contexts` a partir do registro, e publica `user.deletion_requested`.
2. `EraseAccountJob` roda cada apagador ainda pendente e marca os concluídos.
3. No fim, anonimiza `users`: e-mail aleatório, `password_digest` sem valor utilizável e `deleted_at`.
4. `DeletionDeadlineJob` (a cada hora) alerta quando uma exclusão passa de 24 horas.
5. `Shared::Outbox` descarta eventos de usuário com `deleted_at`.

- [ ] **RED:**
  - `deletion revokes sessions on every device at once` (Foco 4);
  - `scan seeds every table, including JSON columns, with a marker and finds none after erase`;
  - `a late event does not recreate data`;
  - `failing eraser is retried and finished ones are not repeated`;
  - `user row keeps the UUID without email or password`;
  - `same email can sign up again`;
  - `alert after 24 hours`;
  - `consent and audit rows stay linked to the UUID`.
- [ ] **GREEN**, testes verdes e commit: `feat(identity): delete accounts through the registry`.

## Tarefa 9: Retenção, isolamento e logs

**Arquivos:**
- `app/domains/identity/jobs/retention_job.rb`
- `spec/requests/isolation_spec.rb`
- `spec/integration/logging_spec.rb` (ampliar)
- `docs/security/PRIVACY_AND_LGPD.md`

**Regras de retenção:**
- `sessions` vencidas ou revogadas há mais de 30 dias são apagadas;
- `account_deletions` concluídas há mais de 30 dias ficam só com UUID e data;
- prazos de `audit_events` e consentimentos conforme `DATABASE_DESIGN.md`. O job roda diariamente pelo cron.

- [ ] **RED:**
  - `retention removes what is past its period and keeps the rest`;
  - `isolation: every authenticated route has a case where another person gets 404 and nothing changes`. O spec lê as rotas do Rails e falha se uma rota autenticada não estiver na tabela de casos;
  - `logs of sign up, sign in, reset, export and deletion, including failures, contain no email, password, token or reset link`.
- [ ] **GREEN.** Atualizar a tabela do art. 18 em `PRIVACY_AND_LGPD.md` com o fluxo de cada direito e o efeito da revogação nesta fase. Testes verdes e commit: `feat(identity): add retention, isolation and log checks`.
- [ ] **Revisão:** `security-reviewer` e `backend-reviewer` sobre as Tarefas 1 a 9. Tratar com `superpowers:receiving-code-review`.

## Tarefa 10: Mobile

**Arquivos:**
- `apps/mobile/src/shared/{api.ts,session.ts}`
- `apps/mobile/src/features/auth/*` (cadastro, entrada, recuperar senha)
- `apps/mobile/src/features/onboarding/*` (consentimento de saúde, motivações, esportes, pronto)
- `apps/mobile/src/features/settings/*` (perfil, esportes, consentimentos, sessões, sair, excluir conta, link para exportar pela web)
- rotas em `src/app/`, com testes em `__tests__`

**Produz:**
- `api.ts`: cliente tipado pelo contrato, com `Authorization: Bearer`. Em `401`, chama `session.clear()` e redireciona para a entrada.
- `session.ts`: `getToken`, `setToken` e `clear` sobre o `expo-secure-store`, com try/catch e chave `session_token`.

**Fluxo:** os cinco passos da seção 2 do design. Passos 3 e 4 têm "pular". Quem volta sem `health_data` recomeça do passo 2. "Pronto" leva a uma tela "em breve".

- [ ] **RED:**
  - `stores the token only in SecureStore`;
  - `401 clears the session and goes to sign in` (Foco 3);
  - `sign up requires the adult checkbox`;
  - `onboarding resumes at consent when health_data is missing`;
  - `skip works on motivations and sports`;
  - `delete account asks for the password`;
  - carregando, vazio e erro em cada tela;
  - rótulos de acessibilidade.
- [ ] **GREEN:** typecheck, lint e testes do mobile com código 0. Commit: `feat(mobile): add sign up, onboarding and settings`.
- [ ] **Demonstração no emulador**, como na Fase 01: cadastro, primeira entrada, sair e entrar. Capturas em `docs/roadmap/reports/evidence/phase-02/`.

## Tarefa 11: Web

**Arquivos:**
- `apps/web/src/shared/api.ts`
- `apps/web/src/features/{auth,privacy,reset-password}/*`
- `apps/web/vite.config.ts` (proxy `/api` para a API em desenvolvimento, para manter web e API no mesmo site)
- testes

**Telas:** entrar, sair, consentimentos, exportar (baixa o JSON), excluir conta e redefinir senha (lê o token do fragmento).

**Regras:**
- `credentials: "include"`, sem token no JavaScript;
- a página de redefinição usa `Referrer-Policy: no-referrer` (meta tag);
- CORS da API com `credentials: true` só para as origens permitidas, se o proxy não for usado.

- [ ] **RED:**
  - `no token reaches localStorage or sessionStorage`;
  - `reset page reads the token from the fragment and clears it from the address`;
  - `export downloads JSON after the password`;
  - estados e acessibilidade.
- [ ] **GREEN:** typecheck, lint, testes e build da web com código 0. Commit: `feat(web): add sign in, privacy and password reset`.
- [ ] **Revisão:** `frontend-mobile-reviewer` sobre as Tarefas 10 e 11.

## Tarefa 12: Documentos e decisões

- [ ] ADR 0005 em `Aceita`, com a evidência dos testes.
- [ ] Nova ADR `0018-application-level-encryption.md`, com a tabela do design, em `Aceita` e com evidência. Incluí-la no índice e no manifesto do harness.
- [ ] Atualizar:
  - `API_DESIGN.md`, com rotas reais e o campo `client`;
  - `SECURITY.md`, com transporte, cookie e limites;
  - `LOCAL_DEVELOPMENT.md`, com e-mails em `tmp/mails`, proxy e variáveis;
  - `DOMAIN_MODEL.md`, com o registro de dados e o que a Identity consome.
- [ ] `bash scripts/verify-harness.sh` e `bash scripts/test-verify-harness.sh`. Esperado: código 0. Commit: `docs: record phase 02 decisions`.

## Tarefa 13: Encerrar

- [ ] Usar a skill `phase-closeout`:
  - execução completa;
  - matriz preenchida;
  - os cinco revisores;
  - relatório `PHASE_02_REPORT.md`;
  - `STATUS.md` em `Em revisão`;
  - push da branch, PR para `main` e CI verde.
- [ ] Confirmar a aprovação dos textos de consentimento pelo responsável. Sem ela, o `AC-02-07` fica parcial.
- [ ] Apresentar o relatório e **parar**.

## Cobertura dos critérios

| Critério | Tarefas |
|---|---|
| `AC-02-01` | 3 |
| `AC-02-02` | 3, 10 |
| `AC-02-03` | 4 |
| `AC-02-04` | 2, 8 |
| `AC-02-05` | 2, 7 |
| `AC-02-06` | 9 |
| `AC-02-07` | 5, 10, 11 |
| `AC-02-08` | 6, 10 |
| `AC-02-09` | 1, 3 |
| `AC-02-10` | 9 |
| `AC-02-11` | 12 |
| `AC-02-12` | 2 |
| `AC-02-13` | 4, 9 |
