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
| FR-PROFILE-001 | 02 | — | `apps/api/app/domains/user_profile/models/profile.rb`, `apps/api/app/domains/user_profile/services/create_profile.rb`, `apps/api/app/domains/user_profile/services/update_profile.rb`, `apps/api/app/controllers/api/v1/profiles_controller.rb`, `apps/mobile/src/features/settings/ProfileSection.tsx` | `apps/api/spec/requests/profiles_spec.rb`, `apps/api/spec/domains/user_profile/profile_spec.rb`, `apps/mobile/src/features/settings/__tests__/settings.test.tsx`. Lacuna aceita em 2026-11-13 | AC-02-08 |
| FR-PROFILE-002 | 02 | — | `apps/api/app/domains/user_profile/models/sport_profile.rb`, `apps/api/app/domains/user_profile/services/set_sport_level.rb`, `apps/api/app/controllers/api/v1/sport_profiles_controller.rb` | `apps/api/spec/requests/profiles_spec.rb`, `apps/api/spec/domains/user_profile/profile_spec.rb` | AC-02-08 |
| FR-PROFILE-003 | 02 | — | `apps/api/app/domains/user_profile/models/sport_profile.rb`, `apps/api/app/domains/user_profile/services/set_sport_level.rb`, `apps/api/db/migrate/20261113120100_create_sport_profiles.rb` | `apps/api/spec/domains/user_profile/profile_spec.rb`. Lacuna aceita em 2026-11-13 | AC-02-08 |
| FR-PROFILE-004 | 02 | — | `apps/api/app/domains/user_profile/services/update_profile.rb`, `apps/api/app/controllers/api/v1/profiles_controller.rb`, `apps/mobile/src/features/onboarding/ConsentStep.tsx` | `apps/api/spec/domains/user_profile/profile_spec.rb`, `apps/api/spec/requests/profiles_spec.rb` | AC-02-08 |
| FR-FOOD-001 | 03 | — | `apps/mobile/src/features/meals/CameraScreen.tsx`, `apps/mobile/src/features/meals/UploadFlow.ts`, `apps/mobile/src/shared/PendingPhotos.ts`, `apps/api/app/domains/food_ai/services/authorize_photo_upload.rb`, `apps/api/app/controllers/api/v1/food_entry_uploads_controller.rb` | `apps/api/spec/requests/food_entry_uploads_spec.rb`, `apps/api/spec/domains/food_ai/authorize_photo_upload_spec.rb`, `apps/mobile/src/features/meals/__tests__/camera.test.tsx`, `apps/mobile/src/features/meals/__tests__/cameraResilience.test.tsx`, `apps/mobile/src/features/meals/__tests__/devicePicker.test.ts` | AC-03-01 |
| FR-FOOD-002 | 03 | — | `apps/api/app/domains/food_ai/services/authorize_photo_upload.rb`, `apps/api/app/domains/food_ai/adapters/object_storage.rb`, `apps/api/app/domains/food_ai/adapters/s3_storage.rb`, `apps/api/app/domains/food_ai/services/normalize_photo.rb`, `docker-compose.yml` | `apps/api/spec/integration/object_storage_spec.rb`, `apps/api/spec/domains/food_ai/normalize_photo_spec.rb`, `apps/api/spec/domains/food_ai/authorize_photo_upload_spec.rb`, `apps/api/spec/domains/food_ai/photo_url_spec.rb` | AC-03-01 |
| FR-FOOD-003 | 03 | 0006 | `apps/api/app/domains/food_ai/services/request_analysis.rb`, `apps/api/app/domains/food_ai/services/run_analysis.rb`, `apps/api/app/domains/food_ai/jobs/analyze_job.rb`, `apps/api/app/domains/nutrition/services/apply_analysis.rb`, `apps/api/app/domains/nutrition/jobs/stuck_entries_job.rb`, `apps/mobile/src/features/meals/MealResultScreen.tsx` | `apps/api/spec/domains/food_ai/run_analysis_spec.rb`, `apps/api/spec/domains/food_ai/request_and_revocation_spec.rb`, `apps/api/spec/domains/nutrition/apply_analysis_spec.rb`, `apps/api/spec/domains/nutrition/recovery_jobs_spec.rb`, `apps/api/spec/requests/food_entry_analyses_spec.rb`, `apps/mobile/src/features/meals/__tests__/result.test.tsx`. Lacuna aceita em 2026-11-17 | AC-03-02 |
| FR-FOOD-004 | 03 | — | `apps/api/config/prompts/food_vision_v1.md`, `apps/api/config/prompts/food_vision_v1.schema.json`, `apps/api/app/domains/food_ai/services/validate_output.rb`, `apps/api/app/domains/food_ai/services/prompt_catalog.rb` | `apps/api/spec/domains/food_ai/validate_output_spec.rb`, `apps/api/spec/domains/food_ai/prompt_catalog_spec.rb`, `apps/api/spec/domains/food_ai/http_adapters_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-02 |
| FR-FOOD-005 | 03 | — | `apps/api/config/prompts/food_vision_v1.schema.json`, `apps/api/app/domains/food_ai/services/validate_output.rb`, `apps/api/app/domains/nutrition/services/item_builder.rb` | `apps/api/spec/domains/food_ai/validate_output_spec.rb`, `apps/api/spec/domains/nutrition/apply_analysis_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-02 |
| FR-FOOD-006 | 03 | 0007 | `apps/api/app/domains/nutrition/services/calculator.rb`, `apps/api/app/domains/nutrition/services/item_builder.rb`, `apps/api/app/domains/nutrition/services/meal_confidence.rb`, `apps/api/app/domains/nutrition/services/entry_view.rb`, `apps/api/app/domains/food_catalog/services/match_food.rb` | `apps/api/spec/domains/nutrition/calculator_spec.rb`, `apps/api/spec/domains/nutrition/meal_confidence_spec.rb`, `apps/api/spec/domains/nutrition/apply_analysis_spec.rb`, `apps/api/spec/requests/food_entries_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-02, AC-03-03 |
| FR-FOOD-007 | 03 | — | `apps/api/app/domains/nutrition/services/confirm_food_entry.rb`, `apps/api/app/controllers/api/v1/food_entries_controller.rb`, `apps/mobile/src/features/meals/MealResultScreen.tsx` | `apps/api/spec/requests/food_entry_management_spec.rb`, `apps/mobile/src/features/meals/__tests__/result.test.tsx`. Lacuna aceita em 2026-11-17 | AC-03-04 |
| FR-FOOD-008 | 03 | — | `apps/api/app/domains/nutrition/services/correct_food_item.rb`, `apps/api/app/domains/nutrition/services/add_food_item.rb`, `apps/api/app/domains/nutrition/services/remove_food_item.rb`, `apps/api/app/domains/nutrition/services/recalculate_entry.rb`, `apps/mobile/src/features/meals/CorrectItemSheet.tsx`, `apps/mobile/src/features/meals/AddItemSheet.tsx` | `apps/api/spec/requests/food_entry_management_spec.rb`, `apps/mobile/src/features/meals/__tests__/result.test.tsx`, `apps/mobile/src/features/meals/__tests__/resultActions.test.tsx`. Lacuna aceita em 2026-11-17 | AC-03-04 |
| FR-FOOD-009 | 03 | — | `apps/api/app/domains/nutrition/services/list_food_entries.rb`, `apps/api/app/controllers/api/v1/food_entries_controller.rb`, `apps/mobile/src/features/meals/MealHistoryScreen.tsx` | `apps/api/spec/requests/food_entry_management_spec.rb`, `apps/mobile/src/features/meals/__tests__/historyAndManual.test.tsx` | AC-03-05 |
| FR-FOOD-010 | 03 | — | `apps/api/app/domains/nutrition/services/delete_food_entry.rb`, `apps/api/app/domains/food_ai/services/erase_on_entry_deleted.rb`, `apps/api/app/domains/food_ai/services/photo_cleanup.rb` | `apps/api/spec/requests/food_entry_management_spec.rb`, `apps/api/spec/domains/nutrition/entry_events_spec.rb`, `apps/api/spec/domains/food_ai/resume_and_erasure_spec.rb`, `apps/mobile/src/features/meals/__tests__/resultActions.test.tsx` | AC-03-05 |
| FR-FOOD-011 | 03 | — | `apps/api/app/domains/nutrition/services/create_manual_entry.rb`, `apps/mobile/src/features/meals/ManualEntryScreen.tsx` | `apps/api/spec/requests/food_entry_management_spec.rb`, `apps/mobile/src/features/meals/__tests__/historyAndManual.test.tsx`. Lacuna aceita em 2026-11-17 | AC-03-06 |
| FR-FOOD-012 | 03 | — | `apps/api/app/domains/food_ai/services/run_analysis.rb`, `apps/api/app/domains/nutrition/services/apply_analysis.rb`, `apps/mobile/src/features/meals/mealMessages.ts` | `apps/api/spec/domains/food_ai/run_analysis_spec.rb`, `apps/api/spec/domains/nutrition/apply_analysis_spec.rb`, `apps/mobile/src/features/meals/__tests__/result.test.tsx`. Lacuna aceita em 2026-11-17 | AC-03-06 |
| FR-FOOD-013 | 03 | 0006 | `apps/api/app/domains/food_ai/adapters/provider_adapter.rb`, `apps/api/app/domains/food_ai/adapters/anthropic_adapter.rb`, `apps/api/app/domains/food_ai/adapters/gemini_adapter.rb`, `apps/api/app/domains/food_ai/adapters/openai_adapter.rb`, `apps/api/config/initializers/food_ai_registrations.rb`, `apps/api/config/domain_boundaries.yml` | `apps/api/spec/domains/food_ai/fake_adapter_spec.rb`, `apps/api/spec/domains/food_ai/http_adapters_spec.rb`, `apps/api/spec/architecture/domains_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-07 |
| FR-FOOD-014 | 03 | 0006 | `apps/api/app/domains/food_ai/services/run_analysis.rb`, `apps/api/app/domains/food_ai/models/analysis_result.rb`, `apps/api/app/domains/food_ai/models/usage_record.rb`, `apps/api/app/domains/food_ai/services/pricing.rb` | `apps/api/spec/domains/food_ai/run_analysis_spec.rb`, `apps/api/spec/domains/food_ai/models_spec.rb`, `apps/api/spec/domains/food_ai/pricing_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-07 |
| FR-FOOD-015 | 03 | 0006 | `evaluation/README.md`, `evaluation/fetch.rb`, `evaluation/runner.rb`, `evaluation/metrics.rb`, `evaluation/report.rb`, `evaluation/reports/2026-11-14-pre-provider.md` | `apps/api/spec/evaluation/fetch_spec.rb`, `apps/api/spec/evaluation/metrics_spec.rb`, `apps/api/spec/evaluation/runner_spec.rb`, `apps/api/spec/evaluation/run_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-08 |
| FR-CATALOG-001 | 03 | 0007 | `apps/api/app/domains/food_catalog/models/catalog_item.rb`, `apps/api/app/domains/food_catalog/services/load_catalog.rb`, `apps/api/db/catalog/usda_fdc.yml`, `apps/api/db/catalog/compositions.yml` | `apps/api/spec/domains/food_catalog/load_catalog_spec.rb` | AC-03-03 |
| FR-CATALOG-002 | 03 | 0007 | `apps/api/app/domains/food_catalog/adapters/project_compositions.rb`, `apps/api/app/domains/food_catalog/models/composition_part.rb`, `apps/api/db/catalog/compositions.yml` | `apps/api/spec/domains/food_catalog/load_catalog_spec.rb`, `apps/api/spec/domains/food_catalog/api_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-09 |
| FR-CATALOG-003 | 03 | 0007 | `apps/api/app/domains/food_catalog/api.rb`, `apps/api/app/domains/food_catalog/services/search_foods.rb`, `apps/api/app/controllers/api/v1/foods_controller.rb`, `apps/mobile/src/features/meals/CatalogSearch.tsx` | `apps/api/spec/requests/foods_spec.rb`, `apps/api/spec/domains/food_catalog/api_spec.rb`, `apps/api/spec/domains/food_catalog/unlogged_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-09 |
| FR-CATALOG-004 | 03 | 0007 | `apps/api/app/domains/food_catalog/services/load_catalog.rb`, `docs/architecture/decisions/0007-nutrition-data-sources.md` | `apps/api/spec/domains/food_catalog/load_catalog_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-09 |
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
| FR-MOBILE-001 | 03 | — | `apps/mobile/src/features/meals/CameraScreen.tsx`, `apps/mobile/src/features/meals/MealResultScreen.tsx`, `apps/mobile/src/features/meals/MealHistoryScreen.tsx`, `apps/mobile/src/features/meals/PhotoConsentStep.tsx`, `apps/mobile/src/app/meals/index.tsx` | `apps/mobile/src/features/meals/__tests__/camera.test.tsx`, `apps/mobile/src/features/meals/__tests__/result.test.tsx`, `apps/mobile/src/features/meals/__tests__/historyAndManual.test.tsx`. Lacuna aceita em 2026-11-17 | AC-03-15 |
| FR-MOBILE-002 | 03 | — | `apps/mobile/src/features/meals/UploadFlow.ts`, `apps/mobile/src/shared/PendingPhotos.ts`, `apps/mobile/src/features/meals/CameraScreen.tsx` | `apps/mobile/src/features/meals/__tests__/cameraResilience.test.tsx`, `apps/mobile/src/features/meals/__tests__/localCopy.test.ts`, `apps/mobile/src/shared/__tests__/sessionCleanup.test.ts`. Lacuna aceita em 2026-11-17 | AC-03-15 |
| FR-MOBILE-003 | 04 | — | — | — | AC-04-12 |
| FR-MOBILE-004 | 07 | — | — | — | AC-07-04 |
| NFR-SEC-001 | 02 | 0018 | `apps/api/app/domains/identity/models/user.rb`, `apps/api/app/domains/identity/models/session.rb`, `apps/api/app/domains/user_profile/models/profile.rb`, `docs/architecture/decisions/0018-application-level-encryption.md` | `apps/api/spec/domains/identity/user_spec.rb`, `apps/api/spec/domains/identity/session_device_label_spec.rb`, `apps/api/spec/domains/user_profile/profile_spec.rb` | AC-02-09, AC-02-11, AC-04-03 |
| NFR-SEC-002 | 03 | — | `apps/api/app/domains/food_ai/adapters/object_storage.rb`, `apps/api/app/domains/food_ai/adapters/s3_storage.rb`, `apps/api/app/domains/food_ai/services/authorize_photo_upload.rb` | `apps/api/spec/integration/object_storage_spec.rb`, `apps/api/spec/domains/food_ai/photo_url_spec.rb`, `apps/api/spec/integration/food_analysis_logging_spec.rb` | AC-03-01 |
| NFR-SEC-003 | 02 | 0005 | `apps/api/app/controllers/concerns/authentication_rate_limits.rb` | `apps/api/spec/requests/registrations_spec.rb`, `apps/api/spec/requests/sessions_spec.rb`, `apps/api/spec/requests/password_resets_spec.rb` | AC-02-09 |
| NFR-SEC-004 | 01 | — | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md` | AC-01-06 |
| NFR-SEC-005 | 01 | — | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md` | AC-01-06 |
| NFR-SEC-006 | 02 | — | `apps/api/app/domains/identity/models/audit_event.rb`, `apps/api/app/domains/identity/services/record_audit.rb`, `apps/api/db/migrate/20261112120200_create_audit_events.rb` | `apps/api/spec/domains/identity/record_audit_spec.rb`, `apps/api/spec/requests/sessions_spec.rb`, `apps/api/spec/requests/password_resets_spec.rb`, `apps/api/spec/domains/identity/account_deletion_spec.rb`, `apps/api/spec/integration/logging_spec.rb` | AC-02-09, AC-02-13 |
| NFR-SEC-007 | 04 | — | — | — | AC-04-11 |
| NFR-PRIVACY-001 | 03 | 0010 | `apps/api/app/domains/food_ai/services/consent_gate.rb`, `apps/api/app/domains/food_ai/services/cancel_on_revocation.rb`, `apps/api/config/initializers/food_ai_config.rb` | `apps/api/spec/domains/food_ai/request_and_revocation_spec.rb`, `apps/api/spec/domains/food_ai/run_analysis_spec.rb`, `apps/api/spec/requests/food_entry_uploads_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-10 |
| NFR-PRIVACY-002 | 02 | — | `docs/security/PRIVACY_AND_LGPD.md`, `apps/api/app/domains/identity/services/export_account.rb`, `apps/api/app/domains/identity/services/request_deletion.rb`, `apps/api/app/domains/identity/services/revoke_consent.rb` | `apps/api/spec/requests/account_export_spec.rb`, `apps/api/spec/requests/account_deletion_spec.rb`, `apps/api/spec/requests/consents_spec.rb` | AC-02-10 |
| NFR-PRIVACY-003 | 02 | — | `apps/api/app/domains/identity/jobs/retention_job.rb`, `docs/security/PRIVACY_AND_LGPD.md` | `apps/api/spec/domains/identity/retention_job_spec.rb` | AC-02-10 |
| NFR-PRIVACY-004 | 03 | — | `apps/api/config/initializers/filter_parameter_logging.rb` | `apps/api/spec/integration/food_analysis_logging_spec.rb`, `apps/api/spec/domains/food_catalog/unlogged_spec.rb` | AC-03-11 |
| NFR-PRIVACY-005 | 03 | 0006 | Lacuna aceita em 2026-11-17 | Lacuna aceita em 2026-11-17 | AC-03-10 |
| NFR-PRIVACY-006 | 04 | 0008 | — | — | AC-04-10, AC-08-06 |
| NFR-PRIVACY-007 | M1 | — | — | — | AC-M1-05 |
| NFR-PRIVACY-008 | M1 | — | — | — | AC-M1-03 |
| NFR-SAFETY-001 | 03 | 0011 | `apps/api/app/domains/nutrition/services/entry_view.rb`, `apps/api/app/domains/nutrition/services/meal_confidence.rb`, `apps/mobile/src/features/meals/formatRange.ts` | `apps/api/spec/requests/food_entries_spec.rb`, `apps/api/spec/domains/nutrition/meal_confidence_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-02 |
| NFR-SAFETY-002 | 03 | — | `scripts/check_language.py`, `scripts/language_denylist.txt`, `scripts/language_denylist_model_text.txt`, `scripts/language_allow.txt`, `apps/api/app/domains/food_ai/services/language_denylist.rb` | `scripts/test-check-language.sh`, `apps/api/spec/domains/food_ai/validate_output_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-13, AC-06-13 |
| NFR-SAFETY-003 | 03 | — | `apps/api/config/prompts/food_vision_v1.md`, `apps/api/app/domains/food_ai/services/validate_output.rb` | `apps/api/spec/domains/food_ai/validate_output_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-13 |
| NFR-SAFETY-004 | 03 | 0011 | `apps/api/app/domains/nutrition/services/entry_view.rb`, `apps/mobile/src/features/meals/formatRange.ts` | `apps/api/spec/contract/no_calorie_goal_spec.rb`, `apps/api/spec/requests/food_entries_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-13 |
| NFR-SAFETY-005 | 09 | 0010 | — | — | AC-09-08 |
| NFR-PERF-001 | 07 | — | — | — | AC-07-08 |
| NFR-PERF-002 | 03 | — | `evaluation/metrics.rb`, `evaluation/runner.rb`. Lacuna aceita em 2026-11-17 | `apps/api/spec/evaluation/metrics_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-14 |
| NFR-PERF-003 | 03 | — | `apps/api/app/domains/nutrition/services/list_food_entries.rb` | `apps/api/spec/requests/food_entry_management_spec.rb` | AC-03-05 |
| NFR-PERF-004 | 09 | — | — | — | AC-09-01 |
| NFR-OBS-001 | 01 | — | `apps/api/lib/observability/json_log_formatter.rb`, `apps/api/lib/observability/correlation.rb`, `apps/api/lib/observability/sidekiq_correlation.rb` | `apps/api/spec/integration/logging_spec.rb`. Lacuna aceita em 2026-11-11 | AC-01-07 |
| NFR-OBS-002 | 01 | — | `apps/api/lib/observability/error_tracking.rb`, `apps/api/lib/observability/error_scrubber.rb`, `apps/web/src/shared/monitoring.ts`, `apps/mobile/src/shared/monitoring.ts` | `apps/api/spec/integration/sentry_spec.rb`, `apps/web/src/shared/monitoring.test.ts`, `apps/mobile/src/shared/__tests__/monitoring.test.ts`. Lacuna aceita em 2026-11-11 | AC-01-07 |
| NFR-OBS-003 | 09 | — | — | — | AC-09-02 |
| NFR-OBS-004 | 01 | — | `apps/api/app/controllers/health_controller.rb`, `apps/api/app/services/health/readiness_check.rb` | `apps/api/spec/requests/health_spec.rb`, `apps/api/spec/requests/health_ready_spec.rb` | AC-01-08 |
| NFR-A11Y-001 | 07 | — | — | — | AC-07-06 |
| NFR-A11Y-002 | 07 | — | — | — | AC-07-07 |
| NFR-COST-001 | 03 | 0006 | `apps/api/app/domains/food_ai/models/usage_record.rb`, `apps/api/app/domains/food_ai/api.rb` | `apps/api/spec/domains/food_ai/retention_spec.rb`, `apps/api/spec/domains/food_ai/run_analysis_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-12 |
| NFR-COST-002 | 03 | 0006 | `apps/api/app/domains/food_ai/services/check_analysis_quota.rb`, `apps/api/app/domains/food_ai/services/config.rb` | `apps/api/spec/domains/food_ai/authorize_photo_upload_spec.rb`, `apps/api/spec/requests/food_entry_uploads_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-12 |
| NFR-COST-003 | 03 | 0006 | `apps/api/app/domains/food_ai/jobs/spend_alert_job.rb`, `apps/api/config/schedule.yml` | `apps/api/spec/domains/food_ai/spend_alert_spec.rb`. Lacuna aceita em 2026-11-17 | AC-03-12 |
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
