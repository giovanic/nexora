# Matriz de rastreabilidade

Liga cada requisito à fase, à decisão e ao critério de aceite. As colunas **Implementação** e **Teste** são preenchidas no encerramento de cada fase, com caminhos reais, pela skill `phase-closeout`. As tarefas ficam ligadas aos requisitos pelo plano da fase, em `docs/superpowers/plans/`.

Requisitos: [FUNCTIONAL_REQUIREMENTS.md](../product/FUNCTIONAL_REQUIREMENTS.md). ADRs: [decisions](../architecture/decisions/README.md). Regras: [protocolo](PHASE_EXECUTION_PROTOCOL.md). Quando um requisito tem mais de um critério, a coluna **Fase** indica a primeira linha de entrega.

| Requisito | Fase | ADR | Implementação | Teste | Critério de aceite |
|---|---|---|---|---|---|
| FR-ID-001 | 02 | 0010 | `apps/api/app/domains/identity/services/register.rb`, `apps/api/app/controllers/api/v1/registrations_controller.rb`, `apps/api/app/domains/identity/models/user.rb`, `apps/api/db/migrate/20261112120000_create_users.rb` | `apps/api/spec/requests/registrations_spec.rb`, `apps/api/spec/domains/identity/user_spec.rb` | AC-02-01 |
| FR-ID-002 | 02 | 0005 | `apps/api/app/domains/identity/services/authenticate.rb`, `apps/api/app/domains/identity/services/refresh_session.rb`, `apps/api/app/domains/identity/services/revoke_session.rb`, `apps/api/app/domains/identity/models/session.rb`, `apps/api/app/controllers/api/v1/sessions_controller.rb`, `apps/api/app/controllers/concerns/authentication.rb`, `apps/mobile/src/shared/session.ts` | `apps/api/spec/requests/sessions_spec.rb`, `apps/api/spec/domains/identity/session_device_label_spec.rb`, `apps/web/src/features/auth/SignInForm.test.tsx`, `apps/mobile/src/features/auth/__tests__/auth.test.tsx`, `apps/mobile/src/shared/__tests__/session.test.ts` | AC-02-02 |
| FR-ID-003 | 02 | 0005 | `apps/api/app/domains/identity/services/request_password_reset.rb`, `apps/api/app/domains/identity/services/reset_password.rb`, `apps/api/app/domains/identity/jobs/password_reset_job.rb`, `apps/api/app/controllers/api/v1/password_resets_controller.rb`, `apps/web/src/features/reset-password/ResetPasswordScreen.tsx`, `apps/mobile/src/features/auth/ForgotPasswordScreen.tsx` | `apps/api/spec/requests/password_resets_spec.rb`, `apps/web/src/features/reset-password/ResetPasswordScreen.test.tsx` | AC-02-03 |
| FR-ID-004 | 02 | 0004 | `apps/api/app/domains/identity/services/request_deletion.rb`, `apps/api/app/domains/identity/jobs/erase_account_job.rb`, `apps/api/app/domains/identity/jobs/deletion_deadline_job.rb`, `apps/api/app/domains/identity/models/account_deletion.rb`, `apps/api/app/controllers/api/v1/accounts_controller.rb` | `apps/api/spec/requests/account_deletion_spec.rb`, `apps/api/spec/domains/identity/account_deletion_spec.rb`, `apps/api/spec/integration/account_deletion_scan_spec.rb`, `apps/api/spec/integration/deletion_requested_delivery_spec.rb`, `apps/api/spec/domains/identity/deletion_delivery_race_spec.rb` | AC-02-04, AC-02-12 |
| FR-ID-005 | 02 | 0004 | `apps/api/app/domains/identity/services/export_account.rb`, `apps/api/app/domains/identity/services/user_data.rb`, `apps/api/app/domains/user_profile/services/user_data.rb`, `apps/api/app/controllers/api/v1/accounts_controller.rb` | `apps/api/spec/requests/account_export_spec.rb`, `apps/api/spec/domains/shared/data_registry_coverage_spec.rb`, `apps/api/spec/requests/isolation_spec.rb` | AC-02-05 |
| FR-ID-006 | 02 | — | `apps/api/app/controllers/concerns/authentication.rb`, `apps/api/lib/api_error_app.rb` | `apps/api/spec/requests/isolation_spec.rb`, `apps/api/spec/contract/routes_spec.rb`, `apps/api/spec/requests/internal_routes_spec.rb` | AC-02-06 |
| FR-ID-007 | 02 | 0010 | `apps/api/app/domains/identity/services/grant_consent.rb`, `apps/api/app/domains/identity/models/consent_record.rb`, `apps/api/app/domains/identity/consent_texts.rb`, `apps/api/app/controllers/api/v1/consents_controller.rb`, `apps/api/config/consents/food_photo_ai.v1.md` | `apps/api/spec/requests/consents_spec.rb`, `apps/api/spec/domains/identity/consents_spec.rb` | AC-02-07 |
| FR-ID-008 | 02 | 0010 | `apps/api/app/domains/identity/services/revoke_consent.rb`, `apps/api/app/domains/user_profile/services/erase_health_data.rb`, `apps/api/app/controllers/api/v1/consents_controller.rb`, `apps/web/src/features/privacy/ConsentsSection.tsx`, `apps/mobile/src/features/settings/ConsentsSection.tsx` | `apps/api/spec/requests/consents_spec.rb`, `apps/api/spec/domains/identity/consents_spec.rb`, `apps/api/spec/domains/user_profile/revocation_race_spec.rb`, `apps/web/src/features/privacy/PrivacyScreen.test.tsx` | AC-02-07 |
| FR-PROFILE-001 | 02 | — | `apps/api/app/domains/user_profile/models/profile.rb`, `apps/api/app/domains/user_profile/services/create_profile.rb`, `apps/api/app/domains/user_profile/services/update_profile.rb`, `apps/api/app/controllers/api/v1/profiles_controller.rb`, `apps/mobile/src/features/settings/ProfileSection.tsx` | `apps/api/spec/requests/profiles_spec.rb`, `apps/api/spec/domains/user_profile/profile_spec.rb`, `apps/mobile/src/features/settings/__tests__/settings.test.tsx`. Parcial: preferências de notificação não são expostas até a Fase 08 (ruling R22), e as unidades só aceitam `metric` no MVP. Lacuna aceita em 2026-11-13 | AC-02-08 |
| FR-PROFILE-002 | 02 | — | `apps/api/app/domains/user_profile/models/sport_profile.rb`, `apps/api/app/domains/user_profile/services/set_sport_level.rb`, `apps/api/app/controllers/api/v1/sport_profiles_controller.rb` | `apps/api/spec/requests/profiles_spec.rb`, `apps/api/spec/domains/user_profile/profile_spec.rb` | AC-02-08 |
| FR-PROFILE-003 | 02 | — | `apps/api/app/domains/user_profile/models/sport_profile.rb`, `apps/api/app/domains/user_profile/services/set_sport_level.rb`, `apps/api/db/migrate/20261113120100_create_sport_profiles.rb` | `apps/api/spec/domains/user_profile/profile_spec.rb`. Parcial: metas e XP ainda não existem, então a regra de não reescrever o histórico só é provada para o histórico de níveis. Lacuna aceita em 2026-11-13 | AC-02-08 |
| FR-PROFILE-004 | 02 | — | `apps/api/app/domains/user_profile/services/update_profile.rb`, `apps/api/app/controllers/api/v1/profiles_controller.rb`, `apps/mobile/src/features/onboarding/ConsentStep.tsx` | `apps/api/spec/domains/user_profile/profile_spec.rb` (trocar o conjunto de motivações e limpar com `[]`), `apps/api/spec/requests/profiles_spec.rb` (os mesmos dois casos, pela API HTTP) | AC-02-08 |
| FR-FOOD-001 | 03 | — | — | — | AC-03-01 |
| FR-FOOD-002 | 03 | — | — | — | AC-03-01 |
| FR-FOOD-003 | 03 | 0006 | — | — | AC-03-02 |
| FR-FOOD-004 | 03 | — | — | — | AC-03-02 |
| FR-FOOD-005 | 03 | — | — | — | AC-03-02 |
| FR-FOOD-006 | 03 | 0007 | — | — | AC-03-02, AC-03-03 |
| FR-FOOD-007 | 03 | — | — | — | AC-03-04 |
| FR-FOOD-008 | 03 | — | — | — | AC-03-04 |
| FR-FOOD-009 | 03 | — | — | — | AC-03-05 |
| FR-FOOD-010 | 03 | — | — | — | AC-03-05 |
| FR-FOOD-011 | 03 | — | — | — | AC-03-06 |
| FR-FOOD-012 | 03 | — | — | — | AC-03-06 |
| FR-FOOD-013 | 03 | 0006 | — | — | AC-03-07 |
| FR-FOOD-014 | 03 | 0006 | — | — | AC-03-07 |
| FR-FOOD-015 | 03 | 0006 | — | — | AC-03-08 |
| FR-CATALOG-001 | 03 | 0007 | — | — | AC-03-03 |
| FR-CATALOG-002 | 03 | 0007 | — | — | AC-03-09 |
| FR-CATALOG-003 | 03 | 0007 | — | — | AC-03-09 |
| FR-CATALOG-004 | 03 | 0007 | — | — | AC-03-09 |
| FR-ACT-001 | 04 | — | — | — | AC-04-01 |
| FR-ACT-002 | 04 | — | — | — | AC-04-01 |
| FR-ACT-003 | 04 | — | — | — | AC-04-06 |
| FR-STRAVA-001 | 04 | 0008 | — | — | AC-04-02 |
| FR-STRAVA-002 | 04 | 0008 | — | — | AC-04-03 |
| FR-STRAVA-003 | 04 | 0008 | — | — | AC-04-04 |
| FR-STRAVA-004 | 04 | 0008 | — | — | AC-04-05 |
| FR-STRAVA-005 | 04 | 0008 | — | — | AC-04-05 |
| FR-STRAVA-006 | 04 | 0008 | — | — | AC-04-05 |
| FR-STRAVA-007 | 04 | 0008 | — | — | AC-04-07 |
| FR-STRAVA-008 | 04 | 0008 | — | — | AC-04-06 |
| FR-STRAVA-009 | 04 | 0008 | — | — | AC-04-07 |
| FR-STRAVA-010 | 04 | 0008 | — | — | AC-04-08 |
| FR-STRAVA-011 | 04 | 0008 | — | — | AC-04-09 |
| FR-STRAVA-012 | 04 | 0008 | — | — | AC-04-09 |
| FR-STRAVA-013 | 04 | 0008 | — | — | AC-04-10 |
| FR-GOALS-001 | 05.1 | — | — | — | AC-05.1-01 |
| FR-GOALS-002 | 05.1 | — | — | — | AC-05.1-02 |
| FR-GOALS-003 | 05.1 | — | — | — | AC-05.1-03 |
| FR-GOALS-004 | 05.1 | — | — | — | AC-05.1-04 |
| FR-GOALS-005 | 05.1 | 0011 | — | — | AC-05.1-05 |
| FR-GOALS-006 | 05.2 | — | — | — | AC-05.2-01 |
| FR-GOALS-007 | 05.2 | 0004 | — | — | AC-05.2-02 |
| FR-GOALS-008 | 05.2 | — | — | — | AC-05.2-03 |
| FR-GOALS-009 | 05.2 | — | — | — | AC-05.2-04 |
| FR-GAME-001 | 06 | 0004 | — | — | AC-06-01 |
| FR-GAME-002 | 06 | 0004 | — | — | AC-06-01 |
| FR-GAME-003 | 06 | — | — | — | AC-06-02 |
| FR-GAME-004 | 06 | — | — | — | AC-06-03 |
| FR-GAME-005 | 06 | — | — | — | AC-06-04 |
| FR-GAME-006 | 06 | — | — | — | AC-06-05 |
| FR-GAME-007 | 06 | 0009 | — | — | AC-06-06 |
| FR-GAME-008 | 06 | 0009 | — | — | AC-06-07 |
| FR-GAME-009 | 06 | 0017 | — | — | AC-06-08 |
| FR-GAME-010 | 06 | 0009 | — | — | AC-06-09 |
| FR-GAME-011 | 06 | — | — | — | AC-06-10 |
| FR-GAME-012 | 06 | — | — | — | AC-06-11 |
| FR-GAME-013 | 06 | — | — | — | AC-06-12 |
| FR-NOTIF-001 | 08 | — | — | — | AC-08-07 |
| FR-NOTIF-002 | 08 | — | — | — | AC-08-07 |
| FR-NOTIF-003 | 08 | — | — | — | AC-08-07 |
| FR-PROG-001 | 08 | — | — | — | AC-08-01 |
| FR-PROG-002 | 08 | — | — | — | AC-08-02 |
| FR-PROG-003 | 08 | — | — | — | AC-08-03, AC-08-04 |
| FR-PROG-004 | 08 | — | — | — | AC-08-05 |
| FR-WEB-001 | 07 | — | — | — | AC-07-01 |
| FR-WEB-002 | 07 | — | — | — | AC-07-01 |
| FR-WEB-003 | 07 | — | — | — | AC-07-02 |
| FR-WEB-004 | 07 | — | — | — | AC-07-03 |
| FR-WEB-005 | 08 | — | — | — | AC-08-08 |
| FR-MOBILE-001 | 03 | — | — | — | AC-03-15 |
| FR-MOBILE-002 | 03 | — | — | — | AC-03-15 |
| FR-MOBILE-003 | 04 | — | — | — | AC-04-12 |
| FR-MOBILE-004 | 07 | — | — | — | AC-07-04 |
| NFR-SEC-001 | 02 | 0018 | `apps/api/app/domains/identity/models/user.rb`, `apps/api/app/domains/identity/models/session.rb`, `apps/api/app/domains/user_profile/models/profile.rb`, `docs/architecture/decisions/0018-application-level-encryption.md` | `apps/api/spec/domains/identity/user_spec.rb`, `apps/api/spec/domains/identity/session_device_label_spec.rb`, `apps/api/spec/domains/user_profile/profile_spec.rb` | AC-02-09, AC-02-11, AC-04-03 |
| NFR-SEC-002 | 03 | — | — | — | AC-03-01 |
| NFR-SEC-003 | 02 | 0005 | `apps/api/app/controllers/concerns/authentication_rate_limits.rb` | `apps/api/spec/requests/registrations_spec.rb`, `apps/api/spec/requests/sessions_spec.rb`, `apps/api/spec/requests/password_resets_spec.rb` | AC-02-09 |
| NFR-SEC-004 | 01 | — | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md` | AC-01-06 |
| NFR-SEC-005 | 01 | — | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md` | AC-01-06 |
| NFR-SEC-006 | 02 | — | `apps/api/app/domains/identity/models/audit_event.rb`, `apps/api/app/domains/identity/services/record_audit.rb`, `apps/api/db/migrate/20261112120200_create_audit_events.rb` | `apps/api/spec/domains/identity/record_audit_spec.rb`, `apps/api/spec/requests/sessions_spec.rb`, `apps/api/spec/requests/password_resets_spec.rb`, `apps/api/spec/domains/identity/account_deletion_spec.rb`, `apps/api/spec/integration/logging_spec.rb` | AC-02-09, AC-02-13 |
| NFR-SEC-007 | 04 | — | — | — | AC-04-11 |
| NFR-PRIVACY-001 | 03 | 0010 | — | — | AC-03-10 |
| NFR-PRIVACY-002 | 02 | — | `docs/security/PRIVACY_AND_LGPD.md`, `apps/api/app/domains/identity/services/export_account.rb`, `apps/api/app/domains/identity/services/request_deletion.rb`, `apps/api/app/domains/identity/services/revoke_consent.rb` | `apps/api/spec/requests/account_export_spec.rb`, `apps/api/spec/requests/account_deletion_spec.rb`, `apps/api/spec/requests/consents_spec.rb` | AC-02-10 |
| NFR-PRIVACY-003 | 02 | — | `apps/api/app/domains/identity/jobs/retention_job.rb`, `docs/security/PRIVACY_AND_LGPD.md` | `apps/api/spec/domains/identity/retention_job_spec.rb` | AC-02-10 |
| NFR-PRIVACY-004 | 03 | — | — | — | AC-03-11 |
| NFR-PRIVACY-005 | 03 | 0006 | — | — | AC-03-10 |
| NFR-PRIVACY-006 | 04 | 0008 | — | — | AC-04-10, AC-08-06 |
| NFR-PRIVACY-007 | M1 | — | — | — | AC-M1-05 |
| NFR-PRIVACY-008 | M1 | — | — | — | AC-M1-03 |
| NFR-SAFETY-001 | 03 | 0011 | — | — | AC-03-02 |
| NFR-SAFETY-002 | 03 | — | — | — | AC-03-13, AC-06-13 |
| NFR-SAFETY-003 | 03 | — | — | — | AC-03-13 |
| NFR-SAFETY-004 | 03 | 0011 | — | — | AC-03-13 |
| NFR-SAFETY-005 | 09 | 0010 | — | — | AC-09-08 |
| NFR-PERF-001 | 07 | — | — | — | AC-07-08 |
| NFR-PERF-002 | 03 | — | — | — | AC-03-14 |
| NFR-PERF-003 | 03 | — | — | — | AC-03-05 |
| NFR-PERF-004 | 09 | — | — | — | AC-09-01 |
| NFR-OBS-001 | 01 | — | `apps/api/lib/observability/json_log_formatter.rb`, `apps/api/lib/observability/correlation.rb`, `apps/api/lib/observability/sidekiq_correlation.rb` | `apps/api/spec/integration/logging_spec.rb`. Lacuna aceita em 2026-11-11 | AC-01-07 |
| NFR-OBS-002 | 01 | — | `apps/api/lib/observability/error_tracking.rb`, `apps/api/lib/observability/error_scrubber.rb`, `apps/web/src/shared/monitoring.ts`, `apps/mobile/src/shared/monitoring.ts` | `apps/api/spec/integration/sentry_spec.rb`, `apps/web/src/shared/monitoring.test.ts`, `apps/mobile/src/shared/__tests__/monitoring.test.ts`. Lacuna aceita em 2026-11-11 | AC-01-07 |
| NFR-OBS-003 | 09 | — | — | — | AC-09-02 |
| NFR-OBS-004 | 01 | — | `apps/api/app/controllers/health_controller.rb`, `apps/api/app/services/health/readiness_check.rb` | `apps/api/spec/requests/health_spec.rb`, `apps/api/spec/requests/health_ready_spec.rb` | AC-01-08 |
| NFR-A11Y-001 | 07 | — | — | — | AC-07-06 |
| NFR-A11Y-002 | 07 | — | — | — | AC-07-07 |
| NFR-COST-001 | 03 | 0006 | — | — | AC-03-12 |
| NFR-COST-002 | 03 | 0006 | — | — | AC-03-12 |
| NFR-COST-003 | 03 | 0006 | — | — | AC-03-12 |
| NFR-OPS-001 | 01 | 0001 | `docker-compose.yml`, `docs/operations/LOCAL_DEVELOPMENT.md` | `docs/roadmap/reports/evidence/phase-01/clean-clone-2026-11-11.log` | AC-01-01 |
| NFR-OPS-002 | 01 | 0001 | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md`, `scripts/test-verify-harness.sh` | AC-01-05 |
| NFR-OPS-003 | M1 | 0015 | — | — | AC-M1-02 |
| NFR-OPS-004 | M1 | 0015 | — | — | AC-M1-01 |
| NFR-OPS-005 | M1 | 0016 | — | — | AC-M1-05 |
| NFR-OPS-006 | 09 | — | — | — | AC-09-04 |
| NFR-HARNESS-001 | 00 | — | `scripts/verify_harness.py`, `scripts/verify-harness.sh`, Lacuna aceita em 2026-11-06 | `scripts/test-verify-harness.sh`, Lacuna aceita em 2026-11-06 | AC-00-01 |
| NFR-HARNESS-002 | 00 | — | `CLAUDE.md` | `docs/roadmap/reports/PHASE_00_REPORT.md` | AC-00-02 |
| NFR-HARNESS-003 | 00 | 0016 | `docs/roadmap/STATUS.md`, `.claude/skills/phase-kickoff/SKILL.md`, `.claude/skills/phase-closeout/SKILL.md` | `scripts/test-verify-harness.sh`, `docs/roadmap/reports/PHASE_00_REPORT.md` | AC-00-03 |
| NFR-HARNESS-004 | 00 | — | `docs/roadmap/TRACEABILITY.md` | `scripts/test-verify-harness.sh` | AC-00-04 |
