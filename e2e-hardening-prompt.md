# Pre-Change Prompt: e2e-test-automation-hardening

**Authors:** QA Engineering (Riley Cho) + Performance Engineering (Sam Okafor)  
**Date:** March 2026  
**Prerequisite:** Archive `e2e-test-automation` first via `/opsx:archive`, then run
`/opsx:new e2e-test-automation-hardening` and paste this file.

Paste this into Claude Code **before** running `/opsx:new e2e-test-automation-hardening`.

---

## Context

We are doing spec-driven development using OpenSpec conventions.
Your job is to create and populate markdown specification files only.
Do not write implementation code.
You are working with a senior Java engineer named Corey Cradle.
Active repo: finding-a-bed-tonight (standalone GitHub repo, account: ccradle)
Docs repo: findABed (OpenSpec artifacts, account: ccradle)

OpenSpec workflow rules — non-negotiable:
Do NOT use planning mode (Shift+Tab Shift+Tab) — it blocks file creation.
Command sequence: /opsx:new → /opsx:ff → review artifacts →
paste standing amendments → /opsx:apply → /opsx:verify →
/opsx:sync if drift → /opsx:archive
During spec phase: create and populate markdown files ONLY.
Clear context window before each /opsx:apply session.

---

## What This Change Is

**Change name:** `e2e-test-automation-hardening`

This change extends the completed `e2e-test-automation` OpenSpec change with
eight items that were identified as missing during a QA and performance
engineering review of the existing spec. It also adds a new first-class
capability: a Gatling-based performance test suite that did not exist in the
original change.

This is **not** a re-do of the original change. The 42 tasks from
`e2e-test-automation` stand as-is. This change adds to them.

**Scope:**
- 6 QA test coverage gaps in the existing Playwright/Karate suite
- 2 CI infrastructure prerequisites missing from the original spec
- 1 new capability: Gatling performance test suite with 3 simulations

**Expected task count:** 18-22 tasks total.

---

## Background: What Already Exists

The `e2e-test-automation` change (now archived) delivered:
- Playwright UI tests: login, outreach search, coordinator dashboard, admin panel
- Karate API tests: auth, shelter CRUD, availability, subscriptions
- CI pipeline in `.github/workflows/e2e-tests.yml`
- POM structure, auth fixtures, seed data baseline

Directory structure already established:
```
finding-a-bed-tonight/
  e2e/
    playwright/
      playwright.config.ts
      pages/         # LoginPage, OutreachSearchPage, CoordinatorDashboardPage, AdminPanelPage
      tests/         # auth.spec.ts, outreach-search.spec.ts, coordinator-dashboard.spec.ts, admin-panel.spec.ts
      fixtures/      # auth.fixture.ts (storageState per role)
    karate/
      pom.xml
      src/test/java/
        karate-config.js
        KarateRunner.java
        features/
          auth/
          shelters/
          availability/
          subscriptions/
    gatling/           # NEW — does not exist yet
```

---

## Part 1: QA Coverage Gaps (Riley)

### GAP-1 — DV Shelter Access Control: Missing from Entire Test Suite

**Severity: Go/No-Go for Raleigh pilot.**

The entire existing spec has zero tests asserting that a domestic violence
shelter never appears in a public API response. The backend has 3 RLS
integration tests at the service layer. There are no Karate contract tests
and no Playwright UI tests for this boundary.

This is not a nice-to-have. A misconfigured DV shelter that appears in a
public query is a data protection failure. The test that catches it must be
in CI as a **blocking gate**, not a report artifact.

**New Karate feature file:** `e2e/karate/src/test/java/features/dv-access/dv-access-control.feature`

Required scenarios:

**Scenario 1 — DV shelter absent from public bed search**
- Setup: Ensure at least one shelter exists with `dvShelter: true` in the test
  dataset (add a DV shelter to seed-data.sql or create in test setup)
- Action: POST `/api/v1/queries/beds` as `OUTREACH_WORKER` (no DV_REFERRAL role)
  with no filters — return all results
- Assert: Response body contains zero shelters whose `shelterId` matches the
  known DV shelter UUID
- Assert: Response contains no shelter name, address, or phone matching the
  DV shelter's profile
- Assert: `unmetDemand` field in response does NOT reveal the DV shelter's
  existence by exposing its ID in any field

**Scenario 2 — DV shelter absent from shelter list endpoint**
- Action: GET `/api/v1/shelters` as `OUTREACH_WORKER`
- Assert: DV shelter UUID does not appear in any result

**Scenario 3 — DV shelter absent from direct shelter detail**
- Action: GET `/api/v1/shelters/{dvShelterId}` as `OUTREACH_WORKER`
- Assert: Response is 404 — not 403. A 403 leaks existence. A 404 is the
  correct behavior: the shelter does not exist from this caller's perspective.

**Scenario 4 — DV shelter absent from HSDS export**
- Action: GET `/api/v1/shelters/{dvShelterId}?format=hsds` as `OUTREACH_WORKER`
- Assert: Response is 404

**Scenario 5 — COC_ADMIN without DV_REFERRAL flag cannot see DV shelter**
- Action: GET `/api/v1/shelters` as `COC_ADMIN` user where `dvAccess: false`
- Assert: DV shelter absent from results
- Note: The `dvAccess` flag on `app_user` controls DV visibility, not role alone

**CI requirement:** This feature file must run as a **separate, blocking job**
in the CI pipeline before any other E2E tests. If `dv-access-control.feature`
fails, the entire pipeline must halt. Do not allow other tests to proceed past
a DV access control failure. Add a `dv-canary` job to
`.github/workflows/e2e-tests.yml` that runs first with `needs: []` and that
all other E2E jobs declare `needs: [dv-canary]`.

---

### GAP-2 — Reservation Tests: Stale Spec, Missing Concurrency

The original spec marked reservation tests as future work with the caveat
"when implemented." The reservation system is fully implemented (44/44 tasks,
pending archive). The caveat is stale. Three new Karate scenarios and one
critical concurrency test must be added.

**New scenarios in:** `e2e/karate/src/test/java/features/reservations/`

**Scenario: Full reservation lifecycle**
- Step 1: PATCH availability for shelter X, population SINGLE_ADULT,
  bedsAvailable: 2
- Step 2: POST `/api/v1/reservations` as OUTREACH_WORKER — assert 201,
  status: HELD, expiresAt is in the future
- Step 3: GET `/api/v1/reservations` — assert the new reservation appears
- Step 4: PATCH `/api/v1/reservations/{id}/confirm` — assert 200, status: CONFIRMED
- Step 5: GET `/api/v1/shelters/{id}` — assert bedsOccupied incremented by 1
- Step 6: Verify bedsAvailable decremented correctly throughout

**Scenario: Cancel reservation releases bed**
- Create a reservation, then PATCH cancel
- Assert status: CANCELLED
- Assert GET shelter shows bedsAvailable returned to pre-hold count

**Scenario: Outreach worker cannot confirm another worker's reservation**
- Worker A creates reservation
- Worker B attempts PATCH confirm on that reservation ID
- Assert 403

**Scenario: Concurrent last-bed hold (the critical one)**

This is the most important test in the reservation suite. It exposes race
conditions in the hold mechanism.

Setup: PATCH availability for shelter X, population SINGLE_ADULT,
bedsAvailable: 1 (exactly one bed)

Execution: Using Karate's parallel runner, fire two simultaneous
`POST /api/v1/reservations` requests for the same shelter and population
type from two different outreach worker sessions.

Assert:
- Exactly one response is 201 (HELD)
- Exactly one response is 409 (Conflict — no beds available)
- After both requests complete, GET shelter shows bedsAvailable: 0
  and bedsOnHold: 1
- No data corruption — bedsAvailable must never go negative

Implementation note: Use Karate's `callSingle` or a background thread
approach. Both requests must be in-flight simultaneously, not sequential.
The test is invalid if one request completes before the other starts.

---

### GAP-3 — PWA Offline Queue: Zero Test Coverage

The offline queue is built, the service worker is active, and the feature is
called out in the README as a key differentiator for field use. There are
zero automated tests for it.

**New Playwright test:** `e2e/playwright/tests/offline-behavior.spec.ts`

**Test 1: Offline banner appears on connectivity loss**
```
Given: Logged in as outreach worker at /outreach
When: page.context().setOffline(true)
Then: A yellow/amber banner containing "offline" text is visible
And: The banner does not disappear after 3 seconds
```

**Test 2: Offline queue holds update and replays on reconnect**
```
Given: Logged in as coordinator at /coordinator
And: page.context().setOffline(true)
And: Offline banner is visible
When: User expands shelter card and submits an availability update
Then: UI shows "queued" or "pending sync" indicator (not an error)
When: page.context().setOffline(false) (reconnect)
Then: The queued action fires — verify via API:
      GET /api/v1/shelters/{id} shows updated availability snapshot
      with snapshot_ts within 5 seconds of reconnect time
```

**Test 3: Search results are stale-served from cache while offline**
```
Given: Logged in as outreach worker, search has loaded results
When: page.context().setOffline(true)
Then: Existing results remain visible (cache serves them)
And: Each result card shows STALE freshness badge or explicit stale indicator
And: No error page or blank state is shown
```

Implementation note: Use Playwright's `page.context().setOffline()` for
network simulation — do NOT use `page.route()` for this. `setOffline()`
properly simulates the browser's online/offline event which triggers the
service worker. `page.route()` only intercepts fetch calls and will not
trigger the `navigator.onLine` change that the offline queue listens to.

---

### GAP-4 — Reservation UI Tests: Fully Built Feature, Zero UI Coverage

The reservation UI is complete — "Hold This Bed" buttons, countdown timers,
confirm/cancel flow, coordinator hold indicators. None of it is tested.

**New Playwright tests:** Add to `e2e/playwright/tests/outreach-search.spec.ts`
and `e2e/playwright/tests/coordinator-dashboard.spec.ts`

**Outreach search additions:**

*Test: Hold a bed*
```
Given: Logged in as outreach worker, search shows shelter with bedsAvailable > 0
When: User clicks "Hold This Bed" button on a shelter result
Then: A confirmation dialog or inline confirmation appears
When: User confirms
Then: The button changes to "Bed Held" or similar held state
And: A countdown timer is visible showing remaining hold time (minutes:seconds)
And: The shelter's bedsAvailable count decrements by 1 in the UI
```

*Test: Cancel a hold*
```
Given: A hold is active (from previous test or setup)
When: User clicks "Cancel Hold" or equivalent
Then: The hold is released
And: bedsAvailable increments back in the UI
And: Verify via API: GET /api/v1/reservations returns empty list for this user
```

**Coordinator dashboard additions:**

*Test: Coordinator sees active holds indicator*
```
Given: Logged in as coordinator for shelter X
And: An outreach worker has placed a hold on shelter X (set up via API in beforeEach)
When: Coordinator expands shelter X card
Then: The availability form shows bedsOnHold: 1 (or equivalent held indicator)
And: The total capacity math is visible: total - occupied - onHold = available
```

---

### GAP-5 — Language Switching: Feature Exists, No Test

**New Playwright test:** Add to `e2e/playwright/tests/outreach-search.spec.ts`

```
Given: Logged in as outreach worker at /outreach (English UI)
When: User selects "Español" from the language selector
Then: At minimum these three strings change language:
      - The page heading ("Find a Bed" → Spanish equivalent)
      - At least one filter label
      - The offline banner text (if visible)
When: User selects "English" from the language selector
Then: All text reverts to English
```

Note: Do not assert on specific Spanish string values — assert that the text
is different from the English version. Hardcoding Spanish strings in the test
creates maintenance coupling to the translation files.

---

### GAP-6 — Data Freshness Badge: API Tested, UI Not Tested

Karate task 9.2 validates `dataAgeSeconds` and `dataFreshness` in the API
response. There is no Playwright test verifying the UI renders the correct
badge.

**New Playwright test:** Add to `e2e/playwright/tests/outreach-search.spec.ts`

```
Setup (via API in beforeEach):
  1. PATCH availability for shelter X with a valid update (creates FRESH snapshot)
  2. Verify via API that dataFreshness: "FRESH"

Test 1: FRESH badge renders
  Given: Search results loaded
  Then: Shelter X result card shows FRESH badge (green indicator or "Fresh" text)

Setup for STALE test:
  This requires manipulating snapshot_ts — either:
  Option A: Directly update snapshot_ts via test-only API endpoint
            (add GET /api/v1/test/shelters/{id}/age?hours=9 that backdates
            the latest snapshot — test-only, profile-gated, never in prod)
  Option B: Accept that STALE cannot be tested in E2E without time travel,
            and test only FRESH and the absence of STALE when data is current

Recommended: Option A — add a test-only backdating endpoint gated on the
`test` Spring profile. This is a small implementation task but it makes the
STALE test deterministic. Document clearly that this endpoint is
test-only and unreachable in non-test profiles.

Test 2: After backdating, STALE badge renders
  Given: snapshot_ts backdated to 9 hours ago via test endpoint
  When: Search results reload
  Then: Shelter X result card shows STALE badge (amber/red indicator)
  And: "Hold This Bed" button is either disabled or shows a staleness warning
```

---

## Part 2: CI Infrastructure Prerequisites (Sam)

### INFRA-1 — Backend Health Check Wait: Missing from CI Pipeline

**Severity: Will cause false test failures on every CI run without this fix.**

The current CI task (task 11.2) starts the backend with `mvn spring-boot:run &`
and immediately starts tests. Spring Boot with 15 Flyway migrations takes
30-60 seconds to start on a GitHub Actions runner. Tests that fire before the
backend is ready will fail with connection refused.

**Add to `.github/workflows/e2e-tests.yml` after the backend start step:**

```yaml
- name: Wait for backend readiness
  run: |
    echo "Waiting for backend health..."
    for i in {1..30}; do
      if curl -sf http://localhost:8080/actuator/health/liveness; then
        echo "Backend is ready after ${i} attempts"
        exit 0
      fi
      echo "Attempt ${i}/30 — waiting 2s..."
      sleep 2
    done
    echo "Backend failed to start within 60 seconds"
    curl -v http://localhost:8080/actuator/health/liveness || true
    exit 1
```

**Same pattern for frontend:**
```yaml
- name: Wait for frontend readiness
  run: |
    for i in {1..15}; do
      if curl -sf http://localhost:5173; then exit 0; fi
      sleep 2
    done
    exit 1
```

Both waits must appear between the start commands and the test execution steps.
The verbose `curl -v` on failure is intentional — it gives the CI log something
useful to debug with when the start fails.

---

### INFRA-2 — Worker-to-Shelter Assignment: Required Before Parallel Playwright

**Severity: Will cause intermittent test failures under parallel execution.**

3 Playwright workers running simultaneously against the same 10 seed shelters
create race conditions in mutation tests (availability updates, holds). Two
workers updating the same shelter's availability concurrently will produce
assertion failures that are timing-dependent and difficult to diagnose.

**Required: Add a worker fixture to `e2e/playwright/fixtures/worker.fixture.ts`**

Assignment:
```
Worker 0 → shelters[0..2]  (seed shelter indices 0, 1, 2)
Worker 1 → shelters[3..5]  (seed shelter indices 3, 4, 5)
Worker 2 → shelters[6..8]  (seed shelter indices 6, 7, 8)
Shelter[9] → reserved for creation tests (creates and deletes its own data)
```

The fixture exposes `workerShelter(index: 0|1|2)` that returns the UUID of
the shelter assigned to this worker's slot. Tests use `workerShelter(0)` for
their primary mutation target — never hardcode seed shelter UUIDs.

Implementation:
```typescript
// fixtures/worker.fixture.ts
import { test as base } from '@playwright/test';

const SEED_SHELTER_UUIDS = [
  'd0000000-0000-0000-0000-000000000001',  // slot 0 — worker 0
  'd0000000-0000-0000-0000-000000000002',  // slot 1 — worker 0
  'd0000000-0000-0000-0000-000000000003',  // slot 2 — worker 0
  'd0000000-0000-0000-0000-000000000004',  // slot 3 — worker 1
  // ... etc
];

export const test = base.extend({
  workerShelter: async ({}, use, testInfo) => {
    const workerIndex = testInfo.workerIndex;
    const baseSlot = workerIndex * 3;
    await use((slot: 0 | 1 | 2) => SEED_SHELTER_UUIDS[baseSlot + slot]);
  },
});
```

UUIDs must match the actual seed-data.sql shelter IDs. Verify seed UUIDs
before hardcoding — the README shows `d0000000-0000-0000-0000-000000000001`
as a sample in the curl examples.

---

## Part 3: New Capability — Gatling Performance Test Suite (Sam)

### Why This Exists Here

Performance testing was explicitly declared out of scope in the original
`e2e-test-automation` design doc. It belongs in this hardening change rather
than a separate OpenSpec change because the performance test suite shares the
same test infrastructure (stack startup, seed data, environment configuration)
and should ship alongside the hardened E2E suite.

### Directory Structure

```
finding-a-bed-tonight/e2e/gatling/
  pom.xml                        # Standalone Maven project, Gatling 3.x + Scala
  src/
    test/
      scala/
        fabt/
          FabtSimulation.scala    # Shared base: HTTP protocol, auth helper
          BedSearchSimulation.scala
          AvailabilityUpdateSimulation.scala
          SurgeLoadSimulation.scala
      resources/
        gatling.conf
        logback-test.xml
```

### Simulation 1: BedSearchSimulation

**Target endpoint:** `POST /api/v1/queries/beds`

**Why this is the most critical simulation:** This is the highest-frequency
path in production. Every outreach worker, every surge event, every mobile
app session hits this endpoint. It is the latency SLO path.

**Load profile:**
```
Ramp from 1 to 50 concurrent users over 30 seconds
Hold at 50 concurrent users for 2 minutes
Ramp down to 0 over 15 seconds
Total duration: ~3 minutes
```

50 concurrent users models a moderate surge event in a mid-size city — not
Raleigh at peak capacity, but a realistic busy night. The 2-minute hold gives
enough data to distinguish startup behavior from steady-state.

**Request payload rotation:** Do not use a single static payload. Rotate across
4 payload variants to simulate realistic query diversity:

```scala
val queries = Array(
  """{"populationType": "SINGLE_ADULT", "limit": 10}""",
  """{"populationType": "FAMILY_WITH_CHILDREN", "petsAllowed": true, "limit": 5}""",
  """{"populationType": "SINGLE_ADULT", "wheelchairAccessible": true, "limit": 10}""",
  """{"populationType": "VETERAN", "limit": 10}"""
)
```

**SLO assertions (fail the build if violated):**
```scala
assertions(
  global.responseTime.percentile(50).lt(100),    // p50 < 100ms
  global.responseTime.percentile(95).lt(500),    // p95 < 500ms
  global.responseTime.percentile(99).lt(1000),   // p99 < 1000ms
  global.failedRequests.percent.lt(1)            // < 1% error rate
)
```

**Cache behavior note:** Run this simulation AFTER loading seed data but BEFORE
any availability updates. The Caffeine L1 cache will warm on the first few
requests. That's intentional — we want steady-state cache performance, not
cold-start performance. A separate cold-start test can be added later.

---

### Simulation 2: AvailabilityUpdateSimulation

**Target endpoint:** `PATCH /api/v1/shelters/{id}/availability`

**Why this matters:** This path has synchronous cache invalidation before
returning 200 OK. Under concurrent updates from different shelters, the
invalidation must not become a bottleneck. Under concurrent updates from the
SAME shelter (e.g., two coordinators on the same shift), the `ON CONFLICT DO
NOTHING` behavior must not cause unexpected latency.

**Load profile:**
```
Scenario A — Multi-shelter concurrent updates (normal operation):
  10 virtual coordinators, each assigned to a different shelter (no overlap)
  Each coordinator sends one update every 5 seconds
  Duration: 2 minutes

Scenario B — Same-shelter concurrent updates (stress test):
  5 virtual coordinators, ALL assigned to the same shelter
  Each coordinator sends one update every 2 seconds
  Duration: 1 minute
```

Run Scenario A first, then Scenario B without restarting the backend.
The goal is to confirm the `ON CONFLICT DO NOTHING` handling doesn't degrade
under the same-shelter concurrency that CLAUDE-CODE-BRIEF.md hard rule #13
was written to address.

**Auth:** All coordinators authenticate via API key (not JWT). The simulation
must acquire 10 distinct API keys in global setup via the REST API, store them
in a feeder, and rotate through them — one per virtual coordinator.

**SLO assertions:**
```scala
assertions(
  global.responseTime.percentile(95).lt(200),   // p95 < 200ms (tighter than query)
  global.failedRequests.percent.lt(1)
)
```

**Key assertion beyond SLO:** After the simulation completes, make a single
`GET /api/v1/shelters/{id}` call and assert that `bedsAvailable` is a
non-negative integer. The simulation does not assert a specific value —
concurrent updates to the same shelter produce non-deterministic final counts —
but `bedsAvailable` must never be negative. Add this as a post-simulation
check in the Gatling teardown or as a separate Karate verification step.

---

### Simulation 3: SurgeLoadSimulation

**Purpose:** Model the worst-case scenario — a White Flag cold-weather event
activates at 9pm and every outreach worker in Wake County queries simultaneously.

**This simulation is specced now, implemented after `surge-mode` is complete.**
Add the spec and stub the implementation with a `// TODO: requires surge-mode
OpenSpec change` comment. Do not block this change on surge-mode.

**Load profile (for when surge-mode is ready):**
```
Phase 1 — Pre-surge baseline (2 minutes):
  20 concurrent users sending bed search queries
  Establishes baseline latency

Phase 2 — Surge activation (instant):
  Admin user sends POST /api/v1/surge-events (activates surge)
  This triggers a broadcast event to all connected sessions

Phase 3 — Post-surge spike (3 minutes):
  Ramp from 20 to 100 concurrent users in 15 seconds
  (Simulates all outreach workers querying simultaneously after broadcast)
  Hold at 100 concurrent users for 2 minutes
  Ramp down

Phase 4 — Surge deactivation (instant):
  Admin deactivates surge
```

**SLO assertions (post-surge spike):**
```scala
assertions(
  // P95 may degrade during spike — acceptable threshold is 2x normal
  global.responseTime.percentile(95).lt(1000),
  global.failedRequests.percent.lt(2)  // 2% error threshold during spike
)
```

The 2% error threshold during the surge spike acknowledges that connection
pool exhaustion or cache stampede may cause a small percentage of failures.
The acceptable threshold matches the Gatling guidance from CLAUDE-CODE-BRIEF.md
hard-won lesson #25 (2% for local Docker load tests).

---

### Performance CI Integration

**Maven profile:** Performance tests SHALL use the profile named `perf`
(CLAUDE-CODE-BRIEF.md hard-won lesson #13: standard perf profile name is `perf`
across all projects).

```bash
mvn verify -Pperf -pl e2e/gatling
```

**CI job:** Add a separate `performance-tests` job to `.github/workflows/e2e-tests.yml`.

```yaml
performance-tests:
  needs: [dv-canary]    # DV canary must pass first
  runs-on: ubuntu-latest
  # Only run on push to main, NOT on PRs (cost control)
  if: github.ref == 'refs/heads/main'
```

**Rationale for main-only:** Gatling simulations run for 3-6 minutes total
and consume significant GitHub Actions minutes. Running on every PR would
exhaust the free tier quickly for an open-source project. Running on main
provides sufficient signal — a performance regression that ships to main will
be caught before it reaches a deployed environment.

**Token acquisition for Gatling auth:**
Per CLAUDE-CODE-BRIEF.md hard-won lesson #14 (Gatling OAuth2 token acquisition),
all Gatling simulations that hit secured endpoints MUST acquire a Bearer token
in the base simulation class and inject it into the HTTP protocol config. Do
NOT acquire tokens per virtual user — acquire once in the base class and share.

**Gatling + Kafka (Full tier) note:** The Gatling simulations described here
target the Lite/Standard tier REST API. Kafka consumer lag tests for the Full
tier require programmatic JUnit with `KafkaConsumer.poll()` loops, not Gatling
HTTP simulations (CLAUDE-CODE-BRIEF.md hard-won lesson #6). Those are out of
scope for this change.

---

## Standing Amendments

This change involves implementation code (test code, Gatling Scala, CI YAML).
The following standing amendments apply selectively:

- **Webhook/Status API** — Not applicable to this change
- **Resilience4J** — Not applicable to this change
- **Caffeine L1 + Redis L2** — Not applicable to this change
- **Reactive Programming** — Not applicable (tests are not reactive)
- **CI/CD** — **APPLIES.** The existing E2E CI workflow is being extended.
  All new jobs must follow the same artifact upload pattern. Performance tests
  go in a separate job, main-only. DV canary goes in a blocking first job.
- **Terraform IaC** — Not applicable to this change

---

## Constraints

- **No production code changes** — except one: the test-only backdating endpoint
  for GAP-6 (data freshness badge). This endpoint must be gated on the `test`
  Spring profile: `@Profile("test")` on the controller, so it is unreachable
  in Lite/Standard/Full profiles. This is the only production code change
  permitted in this change.

- **Seed data is the baseline.** Tests do not create tenants or users. The
  `dev-coc` tenant, 3 users, and 10 shelters from seed-data.sql are the
  foundation everything runs on. If a test requires a DV shelter and seed
  data does not have one, add one DV shelter to seed-data.sql — it is a
  production code change but a small, justified one.

- **Worker isolation is mandatory before parallel runs.** INFRA-2 must be
  implemented before any mutation Playwright tests run in parallel.
  If INFRA-2 is not in place, set `workers: 1` in `playwright.config.ts`
  until it is. Flaky parallel tests are worse than slow serial tests.

- **Gatling profile name is `perf`.** Non-negotiable. Matches the portfolio
  platform standard.

---

## Expected Output from `/opsx:ff`

1. `proposal.md` — Why this change exists, what it extends, what is new
2. `design.md` — Decisions covering: DV canary pipeline position, worker
   fixture design, Gatling simulation architecture, test-only Spring profile
   endpoint for data freshness test, concurrent reservation test approach
3. `specs/dv-access-control/spec.md` — Full requirements and scenarios for GAP-1
4. `specs/reservation-e2e/spec.md` — Requirements and scenarios for GAP-2
5. `specs/offline-behavior/spec.md` — Requirements and scenarios for GAP-3
6. `specs/reservation-ui/spec.md` — Requirements and scenarios for GAP-4
7. `specs/language-switching/spec.md` — Requirements and scenarios for GAP-5
8. `specs/data-freshness-ui/spec.md` — Requirements and scenarios for GAP-6
9. `specs/ci-infrastructure/spec.md` — Requirements for INFRA-1 and INFRA-2
10. `specs/performance-suite/spec.md` — Requirements for all 3 Gatling simulations
11. `tasks.md` — Full task list (expected 18-22 tasks)

---

## Expected Tasks (Guidance for `/opsx:ff`)

Claude Code should produce tasks roughly matching this structure.
Adjust numbering to fit the generated artifact:

**DV Canary (GAP-1):**
- [ ] Create `features/dv-access/dv-access-control.feature` — 5 scenarios
- [ ] Add DV shelter to seed-data.sql (if not present)
- [ ] Add `dv-canary` as first blocking CI job; all other E2E jobs declare `needs: [dv-canary]`

**Reservation API Tests (GAP-2):**
- [ ] Create `features/reservations/reservation-lifecycle.feature` — full lifecycle
- [ ] Create `features/reservations/reservation-cancel.feature`
- [ ] Create `features/reservations/reservation-auth.feature` — cross-user 403
- [ ] Create `features/reservations/reservation-concurrency.feature` — last-bed race

**Offline Queue (GAP-3):**
- [ ] Create `tests/offline-behavior.spec.ts` — 3 tests using `page.context().setOffline()`

**Reservation UI (GAP-4):**
- [ ] Add hold/cancel tests to `tests/outreach-search.spec.ts`
- [ ] Add coordinator hold indicator test to `tests/coordinator-dashboard.spec.ts`
- [ ] Add `ReservationPanel` page object to `pages/` if needed

**Language Switching (GAP-5):**
- [ ] Add language switch test to `tests/outreach-search.spec.ts`

**Data Freshness Badge (GAP-6):**
- [ ] Add `@Profile("test")` backdating endpoint to backend (single controller method)
- [ ] Add FRESH badge test to `tests/outreach-search.spec.ts`
- [ ] Add STALE badge test using backdating endpoint

**CI Infrastructure:**
- [ ] Add backend health check wait step to `e2e-tests.yml` (INFRA-1)
- [ ] Add frontend health check wait step to `e2e-tests.yml` (INFRA-1)
- [ ] Create `fixtures/worker.fixture.ts` with workerShelter assignment (INFRA-2)
- [ ] Update all mutation tests to use `workerShelter()` fixture (INFRA-2)

**Gatling Performance Suite:**
- [ ] Create `e2e/gatling/pom.xml` with Gatling 3.x + Scala dependencies
- [ ] Create `FabtSimulation.scala` base class with HTTP protocol + auth helper
- [ ] Create `BedSearchSimulation.scala` — 50 VU ramp, 4 payload variants, SLO assertions
- [ ] Create `AvailabilityUpdateSimulation.scala` — Scenario A (multi-shelter) + Scenario B (same-shelter)
- [ ] Create `SurgeLoadSimulation.scala` — stub with TODO, full spec documented
- [ ] Add `performance-tests` job to `e2e-tests.yml` (main-only, needs dv-canary)
- [ ] Document `mvn verify -Pperf` in CONTRIBUTING.md

---

## How to Start

1. Paste this entire file into Claude Code
2. Run `/opsx:new e2e-test-automation-hardening`
3. Run `/opsx:ff` — Claude Code will draft all artifacts
4. Review artifacts carefully — pay special attention to:
   - DV canary pipeline position (must be first, blocking)
   - Concurrent reservation test design (must be truly concurrent, not sequential)
   - Gatling SLO values (must match the targets in this document exactly)
   - Worker fixture UUID list (must match actual seed-data.sql shelter IDs)
5. Paste CI/CD standing amendment before `/opsx:apply`
6. Implementation is two sessions:
   - Session A: GAP-1 through GAP-6 + INFRA-1 + INFRA-2 (Playwright/Karate/CI)
   - Session B: Gatling suite (separate session — clear context between sessions)
7. `/opsx:verify` — DV canary must pass locally before declaring complete
8. `/opsx:archive`

---

*Finding A Bed Tonight — QA + Performance Engineering*  
*Riley Cho · Sam Okafor*  
*github.com/ccradle/finding-a-bed-tonight*
