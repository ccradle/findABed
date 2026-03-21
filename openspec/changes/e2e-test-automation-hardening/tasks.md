## 0. RLS Enforcement (prerequisite for DV canary tests)

- [ ] 0.1 Create Flyway migration `V16__create_restricted_app_role.sql`: create `fabt_app` role with NOSUPERUSER, LOGIN, GRANT SELECT/INSERT/UPDATE/DELETE on ALL TABLES, GRANT USAGE on ALL SEQUENCES. Run as owner (`fabt`).
- [ ] 0.2 Create docker-compose init script (`infra/scripts/init-app-user.sql`): CREATE ROLE fabt_app with password, used by PostgreSQL `initdb` to create the restricted user before the app starts
- [ ] 0.3 Update `docker-compose.yml`: mount init script to `/docker-entrypoint-initdb.d/` so `fabt_app` user is created on container start
- [ ] 0.4 Create `RlsConnectionInterceptor` Spring component: wraps DataSource, executes `SET LOCAL app.dv_access = 'true/false'` on each `getConnection()` based on `TenantContext.getDvAccess()`
- [ ] 0.5 Update `application.yml`: split datasource — runtime queries use `fabt_app`, Flyway DDL uses `fabt` (owner) via `spring.flyway.user` / `spring.flyway.password`
- [ ] 0.6 Update `dev-start.sh` seed data loading: ensure `fabt_app` role has permissions on tables created by Flyway after migrations run
- [ ] 0.7 Verify existing 109 backend integration tests still pass with the new DataSource configuration
- [ ] 0.8 Verify DV shelter is hidden from outreach user and visible to admin with dvAccess=true via curl against running stack

## 1. DV Canary (GAP-1)

- [x] 1.1 Add DV shelter to seed-data.sql if not already present (verify `d0000000-0000-0000-0000-000000000009` has `dvShelter: true`)
- [x] 1.2 Create `e2e/karate/src/test/java/features/dv-access/dv-access-control.feature` — 5 scenarios (bed search, shelter list, direct access 404, HSDS 404, COC_ADMIN without dvAccess)
- [x] 1.3 Add `dv-canary` as first blocking CI job in `.github/workflows/e2e-tests.yml`; all other E2E jobs declare `needs: [dv-canary]`

## 2. Reservation API Tests (GAP-2)

- [x] 2.1 Create `e2e/karate/src/test/java/features/reservations/reservation-lifecycle.feature` — full lifecycle (create, confirm, verify occupancy)
- [x] 2.2 Create `e2e/karate/src/test/java/features/reservations/reservation-cancel.feature` — cancel releases bed
- [x] 2.3 Create `e2e/karate/src/test/java/features/reservations/reservation-auth.feature` — cross-user 403
- [x] 2.4 Create `e2e/karate/src/test/java/features/reservations/reservation-concurrency.feature` — concurrent last-bed race

## 3. Offline Queue Tests (GAP-3)

- [x] 3.1 Create `e2e/playwright/tests/offline-behavior.spec.ts` — 3 tests: offline banner, queue replay on reconnect, stale cache display (use `page.context().setOffline()`)

## 4. Reservation UI Tests (GAP-4)

- [x] 4.1 Add hold bed test to `e2e/playwright/tests/outreach-search.spec.ts` — click "Hold This Bed", verify countdown timer and bedsAvailable decrement
- [x] 4.2 Add cancel hold test to `e2e/playwright/tests/outreach-search.spec.ts` — cancel hold, verify bedsAvailable returns
- [x] 4.3 Add coordinator hold indicator test to `e2e/playwright/tests/coordinator-dashboard.spec.ts` — verify bedsOnHold count visible
- [x] 4.4 Create `e2e/playwright/pages/ReservationPanel.ts` page object for reservation panel interactions

## 5. Language Switching Test (GAP-5)

- [x] 5.1 Add language switch test to `e2e/playwright/tests/outreach-search.spec.ts` — switch to Español, verify text changes, switch back, verify revert

## 6. Data Freshness Badge Tests (GAP-6)

- [x] 6.1 Create `@Profile("test")` backdating endpoint in backend: `GET /api/v1/test/shelters/{id}/backdate?hours=N` that updates latest snapshot_ts
- [x] 6.2 Add freshness badge test to `e2e/playwright/tests/outreach-search.spec.ts` — verify freshness indicators visible on results
- [ ] 6.3 Add STALE badge test using backdating endpoint — verify red indicator after 9-hour backdate (requires test profile active)

## 7. CI Infrastructure

- [x] 7.1 Add backend health check wait step to `.github/workflows/e2e-tests.yml` — poll `/actuator/health/liveness` for 60s (INFRA-1)
- [x] 7.2 Add frontend health check wait step — poll port 5173 for 30s (INFRA-1)
- [x] 7.3 Create `e2e/playwright/fixtures/worker.fixture.ts` — assign 3 shelters per worker using seed-data.sql UUIDs (INFRA-2)
- [ ] 7.4 Update all mutation Playwright tests to use `workerShelter()` fixture instead of hardcoded shelter IDs (INFRA-2)

## 8. Gatling Performance Suite

- [x] 8.1 Create `e2e/gatling/pom.xml` with Gatling 3.x + Scala dependencies, `perf` Maven profile
- [x] 8.2 Create `e2e/gatling/src/test/scala/fabt/FabtSimulation.scala` base class — HTTP protocol config, shared JWT token acquisition
- [x] 8.3 Create `BedSearchSimulation.scala` — 50 VU ramp over 30s, hold 2 min, 4 payload variants, SLO assertions (p50<100ms, p95<500ms, p99<1000ms, <1% errors)
- [x] 8.4 Create `AvailabilityUpdateSimulation.scala` — Scenario A (10 coordinators, different shelters, 2 min) + Scenario B (5 coordinators, same shelter, 1 min), SLO p95<200ms, post-sim bedsAvailable >= 0 assertion
- [x] 8.5 Create `SurgeLoadSimulation.scala` — stub with full spec in comments and TODO marker for post-surge-mode implementation
- [x] 8.6 Add `performance-tests` job to `.github/workflows/e2e-tests.yml` — main-only (`if: github.ref == 'refs/heads/main'`), needs `dv-canary`
- [x] 8.7 Document `mvn verify -Pperf -pl e2e/gatling` in CONTRIBUTING.md
