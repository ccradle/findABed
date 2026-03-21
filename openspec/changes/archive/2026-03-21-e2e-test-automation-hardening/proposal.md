## Why

A QA and performance engineering review of the `e2e-test-automation` spec identified 6 test coverage gaps, 2 CI infrastructure prerequisites, and the absence of performance testing. The existing 42-task spec covers the happy-path E2E flows but misses safety-critical DV shelter access control tests, reservation lifecycle tests (feature was built after the spec), PWA offline behavior, reservation UI interactions, language switching, and data freshness badge rendering. Two CI infra items (health check waits, worker-to-shelter isolation) will cause false failures without fixes. A Gatling performance suite is needed for SLO validation.

Additionally, implementing the DV canary tests revealed a **critical infrastructure gap**: PostgreSQL Row Level Security policies exist in the database (V8, V8.1, V13, V15) but are never enforced at runtime because (a) the application never propagates `TenantContext.dvAccess` to the PostgreSQL session variable `app.dv_access`, and (b) the database connection user owns the tables, which bypasses RLS entirely. This must be fixed before DV access control can be tested or trusted in any environment.

## What Changes

- **RLS-FIX**: Add JDBC connection interceptor that runs `SET LOCAL app.dv_access` per request based on `TenantContext.getDvAccess()`. Create restricted `fabt_app` database role (NOSUPERUSER, DML-only). Configure application to connect as `fabt_app` while Flyway DDL runs as `fabt` (owner). This makes RLS actually enforceable in dev, test, and production.
- **GAP-1**: DV shelter access control Karate tests (5 scenarios) + CI `dv-canary` blocking gate
- **GAP-2**: Reservation API lifecycle Karate tests including concurrent last-bed race condition
- **GAP-3**: PWA offline queue Playwright tests (banner, queue replay, stale cache)
- **GAP-4**: Reservation UI Playwright tests (hold, cancel, coordinator indicator)
- **GAP-5**: Language switching Playwright test
- **GAP-6**: Data freshness badge Playwright test + test-only `@Profile("test")` backdating endpoint
- **INFRA-1**: Backend + frontend health check waits in CI pipeline
- **INFRA-2**: Worker-to-shelter fixture for parallel Playwright execution
- **NEW**: Gatling performance suite (3 simulations: bed search, availability update, surge load stub)

## Capabilities

### New Capabilities

- `dv-access-control-e2e`: DV shelter exclusion tests as a blocking CI canary gate
- `performance-suite`: Gatling simulations with SLO assertions for bed search and availability update
- `rls-enforcement`: JDBC connection interceptor + restricted DB role for RLS enforcement

### Modified Capabilities

- `ui-test-suite`: Reservation UI, offline behavior, language switching, data freshness badge tests
- `api-test-suite`: Reservation lifecycle + DV access control Karate features
- `test-infrastructure`: Health check waits, worker fixture, dv-canary CI job, performance CI job
- `deployment-profiles`: Application datasource configuration split (DDL owner vs DML restricted user)

## Impact

- **New files**: Karate features (dv-access, reservations), Playwright tests (offline, reservation UI), Gatling simulations, worker fixture, JDBC connection interceptor, Flyway migration (restricted user)
- **Modified files**: `.github/workflows/e2e-tests.yml`, `playwright.config.ts`, existing test files, `application.yml` (datasource config), `docker-compose.yml` (add app user init)
- **Backend code changes**: `@Profile("test")` backdating endpoint, `RlsConnectionInterceptor` component, Flyway migration for `fabt_app` role
- **Seed data change**: Init script to create `fabt_app` user in docker-compose PostgreSQL
