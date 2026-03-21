## Context

FABT has strong backend integration tests (97 passing, Testcontainers + real PostgreSQL) but no frontend testing and no E2E coverage. The bed-availability change added significant UI complexity (search results with availability badges, coordinator availability form) that is only validated manually.

## Goals / Non-Goals

**Goals:**
- Playwright UI tests covering critical user workflows
- Karate API tests covering all endpoint contracts
- CI pipeline running both suites on every push/PR
- Test data isolation (tests don't interfere with each other)
- Fast feedback (parallel execution, < 5 minute CI run)

**Non-Goals:**
- Visual regression testing (screenshot comparison)
- Performance/load testing
- Mobile device testing (responsive testing is future work)
- Testing against Standard/Full tiers (Lite tier only for now)

## Decisions

### D1: Playwright for UI tests (TypeScript)

Playwright over Cypress because:
- Native multi-browser support (Chromium, Firefox, WebKit)
- Better handling of auth state (storageState for session reuse)
- Parallel test execution out of the box
- TypeScript matches the frontend codebase

Directory structure:
```
e2e/playwright/
  playwright.config.ts
  pages/               # Page Object Model
    LoginPage.ts
    OutreachSearchPage.ts
    CoordinatorDashboardPage.ts
    AdminPanelPage.ts
  tests/
    auth.spec.ts
    outreach-search.spec.ts
    coordinator-dashboard.spec.ts
    admin-panel.spec.ts
  fixtures/
    auth.fixture.ts    # Shared login state
```

### D2: Karate for API tests (feature files)

Karate over REST Assured because:
- BDD-style feature files are self-documenting
- Built-in JSON path assertions, schema validation
- No Java boilerplate for simple API tests
- Parallel execution and HTML reporting

Directory structure:
```
e2e/karate/
  pom.xml              # Standalone Maven project
  src/test/java/
    karate-config.js   # Environment config (baseUrl, auth tokens)
    KarateRunner.java  # JUnit 5 test runner
    features/
      auth/            # Login, token refresh, API key auth
      shelters/        # CRUD, constraints, capacity, detail
      availability/    # PATCH update, bed search POST
      subscriptions/   # Webhook CRUD
```

### D3: Test data strategy

**Baseline:** `infra/scripts/seed-data.sql` provides 10 shelters, 3 users, 1 tenant. All E2E tests run against this baseline.

**Per-test isolation:** Tests that create data use unique identifiers (UUID suffixes in shelter names) and clean up after themselves. Tests that modify data use dedicated test shelters, not shared ones.

**Auth state reuse:** Playwright `storageState` caches login sessions per role. Login is performed once in a global setup, not per test.

### D4: CI pipeline (GitHub Actions)

```yaml
e2e-tests:
  runs-on: ubuntu-latest
  services:
    postgres: (same as docker-compose.yml)
  steps:
    - Checkout
    - Build backend (mvn compile)
    - Start backend (mvn spring-boot:run &)
    - Load seed data
    - Start frontend (npm run dev &)
    - Run Karate tests (parallel)
    - Run Playwright tests (parallel, 3 workers)
    - Upload test reports as artifacts
```

Karate and Playwright run in parallel jobs. Total CI time target: < 5 minutes.

### D5: Environment configuration

| Setting | Local (dev-start.sh) | CI (GitHub Actions) |
|---------|---------------------|---------------------|
| Backend URL | http://localhost:8080 | http://localhost:8080 |
| Frontend URL | http://localhost:5173 | http://localhost:5173 |
| Tenant slug | dev-coc | dev-coc |
| Browser | headed (optional) | headless |
| Workers | 1 (serial for debugging) | 3 (parallel) |

Both tools read config from environment variables, defaulting to local dev values.

## Risks / Trade-offs

- **[Flaky UI tests]** → Mitigation: Page Object Model isolates selectors. Playwright auto-wait reduces timing issues. Retry on CI (2 retries max).
- **[Slow CI]** → Mitigation: Parallel execution (Karate + Playwright in separate jobs, Playwright with 3 workers). Target < 5 min total.
- **[Seed data drift]** → Mitigation: Tests assert on data they create, not on specific seed data IDs. Seed data provides baseline auth and tenant context only.
