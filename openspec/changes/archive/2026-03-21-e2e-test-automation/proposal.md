## Why

The platform has 97 backend integration tests but zero frontend tests and zero cross-layer end-to-end coverage. API contract changes, frontend regressions, and auth flow breakages aren't caught until manual testing. As the codebase grows (reservation-system, surge-mode), the risk of undetected regressions compounds. An automated E2E suite catches what unit and integration tests miss: real browser interactions, full request chains, and deployment-tier-specific behavior.

## What Changes

- New Playwright test suite for UI workflows: login, outreach bed search, coordinator availability updates, admin panel management
- New Karate test suite for API flows: auth lifecycle, shelter CRUD, availability PATCH, bed search POST, webhook subscriptions, reservation lifecycle (when implemented)
- Test infrastructure: GitHub Actions CI workflow running both suites in parallel against `dev-start.sh` stack
- Page Object Model (POM) for Playwright tests — maintainable abstraction over page selectors
- Test data management: seed-data.sql for baseline, per-test setup/teardown for isolation
- Environment configuration: local dev (dev-start.sh) and CI (docker-compose headless)

## Capabilities

### New Capabilities
- `ui-test-suite`: Playwright browser tests covering all user-facing workflows (login, search, dashboard, admin)
- `api-test-suite`: Karate feature-file tests covering all API endpoints with contract validation
- `test-infrastructure`: CI pipeline, test data management, environment configuration, reporting

### Modified Capabilities

_(none — this change is additive testing infrastructure)_

## Impact

- **New directories**: `finding-a-bed-tonight/e2e/playwright/`, `finding-a-bed-tonight/e2e/karate/`
- **New CI workflow**: `.github/workflows/e2e-tests.yml` — runs on push to main and PRs
- **New dependencies**: Playwright (npm), Karate (Maven), GitHub Actions runner minutes
- **Modified files**: `finding-a-bed-tonight/docker-compose.yml` (optional: CI-specific test profile)
- **No production code changes** — purely additive test infrastructure
