# Matriz de rastreabilidade

Liga cada requisito à fase, à decisão e ao critério de aceite. As colunas **Implementação** e **Teste** são preenchidas no encerramento de cada fase, com caminhos reais, pela skill `phase-closeout`. As tarefas ficam ligadas aos requisitos pelo plano da fase, em `docs/superpowers/plans/`.

Requisitos: [FUNCTIONAL_REQUIREMENTS.md](../product/FUNCTIONAL_REQUIREMENTS.md). ADRs: [decisions](../architecture/decisions/README.md). Regras: [protocolo](PHASE_EXECUTION_PROTOCOL.md). Quando um requisito tem mais de um critério, a coluna **Fase** indica a primeira linha de entrega.

| Requisito | Fase | ADR | Implementação | Teste | Critério de aceite |
|---|---|---|---|---|---|
| FR-ID-001 | 02 | 0010 | — | — | AC-02-01 |
| FR-ID-002 | 02 | 0005 | — | — | AC-02-02 |
| FR-ID-003 | 02 | 0005 | — | — | AC-02-03 |
| FR-ID-004 | 02 | — | — | — | AC-02-04 |
| FR-ID-005 | 02 | — | — | — | AC-02-05 |
| FR-ID-006 | 02 | — | — | — | AC-02-06 |
| FR-ID-007 | 02 | 0010 | — | — | AC-02-07 |
| FR-ID-008 | 02 | 0010 | — | — | AC-02-07 |
| FR-PROFILE-001 | 02 | — | — | — | AC-02-08 |
| FR-PROFILE-002 | 02 | — | — | — | AC-02-08 |
| FR-PROFILE-003 | 02 | — | — | — | AC-02-08 |
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
| NFR-SEC-001 | 02 | — | — | — | AC-02-09, AC-04-03 |
| NFR-SEC-002 | 03 | — | — | — | AC-03-01 |
| NFR-SEC-003 | 02 | 0005 | — | — | AC-02-09 |
| NFR-SEC-004 | 01 | — | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md` | AC-01-06 |
| NFR-SEC-005 | 01 | — | `.github/workflows/ci.yml` | `docs/roadmap/reports/PHASE_01_REPORT.md` | AC-01-06 |
| NFR-SEC-006 | 02 | — | — | — | AC-02-09 |
| NFR-SEC-007 | 04 | — | — | — | AC-04-11 |
| NFR-PRIVACY-001 | 03 | 0010 | — | — | AC-03-10 |
| NFR-PRIVACY-002 | 02 | — | — | — | AC-02-10 |
| NFR-PRIVACY-003 | 02 | — | — | — | AC-02-10 |
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
