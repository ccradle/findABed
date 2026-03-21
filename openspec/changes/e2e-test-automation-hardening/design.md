## Context

The `e2e-test-automation` change delivered Playwright UI + Karate API test infrastructure. A QA + performance engineering review identified 6 coverage gaps, 2 CI prerequisites, and the need for a Gatling performance suite. This change extends (not replaces) the original 42 tasks.

## Goals / Non-Goals

**Goals:**
- DV shelter access control as a blocking CI canary gate
- Reservation API + UI test coverage (feature built after original spec)
- PWA offline queue validation
- Language switching and data freshness badge UI tests
- CI health check waits and parallel worker isolation
- Gatling performance simulations with SLO assertions

**Non-Goals:**
- Visual regression testing / screenshot comparison
- Mobile device testing
- Kafka consumer lag testing (Full-tier specific, out of scope)
- Replacing any of the original 42 tasks

## Decisions

### D1: DV canary as first blocking CI job

The `dv-access-control.feature` Karate test runs in a separate `dv-canary` CI job that executes first. All other E2E jobs declare `needs: [dv-canary]`. If DV shelter data leaks into a public query, the entire pipeline halts. A DV data protection failure is a go/no-go for the Raleigh pilot — it must not be buried in a 50-test report.

### D2: Worker-to-shelter fixture for parallel Playwright

3 Playwright workers running concurrently against the same 10 seed shelters creates race conditions. Each worker gets a dedicated set of 3 shelters via `fixtures/worker.fixture.ts`. Shelter[9] is reserved for creation tests. Workers never mutate another worker's shelters.

### D3: Test-only backdating endpoint for data freshness

To test STALE badge rendering, we need a shelter with `snapshot_ts` older than 8 hours. A `@Profile("test")` controller endpoint (`GET /api/v1/test/shelters/{id}/backdate?hours=9`) updates the latest snapshot timestamp. Gated on the `test` Spring profile — unreachable in Lite/Standard/Full.

### D4: Gatling simulation architecture

Three simulations sharing a `FabtSimulation` base class with HTTP protocol config and shared JWT token acquisition:

1. **BedSearchSimulation** — 50 VU ramp, 4 payload variants, SLO: p50<100ms, p95<500ms, p99<1000ms, <1% errors
2. **AvailabilityUpdateSimulation** — Scenario A (10 coordinators, different shelters) + Scenario B (5 coordinators, same shelter). SLO: p95<200ms, <1% errors
3. **SurgeLoadSimulation** — Stub with TODO. Full spec documented for post-surge-mode implementation.

Performance tests run main-only in CI (cost control), in a separate `performance-tests` job that needs `dv-canary`.

### D5: Concurrent reservation test approach

The Karate concurrent last-bed test uses parallel threads (not sequential requests). Both requests must be in-flight simultaneously. Karate's `callSingle` or explicit Java threading achieves this. The test asserts: exactly one 201, exactly one 409, `bedsAvailable` never negative.

### D6: Offline testing uses page.context().setOffline()

Playwright's `setOffline()` properly simulates the browser's online/offline event which triggers the service worker. `page.route()` only intercepts fetch calls and would not trigger `navigator.onLine` changes.
