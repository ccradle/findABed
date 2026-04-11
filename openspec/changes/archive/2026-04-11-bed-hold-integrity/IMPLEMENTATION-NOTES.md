# Implementation Notes — bed-hold-integrity (2026-04-11)

This document captures the deltas between the original `proposal.md` /
`design.md` / `tasks.md` and what actually shipped during the local
implementation pass on the `bugfix/issue-102-phantom-beds-on-hold` branch.
The originals are preserved for historical context; this file is the source
of truth for what's in the code.

## Status

**Implemented locally on `bugfix/issue-102-phantom-beds-on-hold` (branched
from `v0.32.3`).** All seven components landed. Backend regression: **517 /
517 tests pass, 0 failures, 0 errors.** Baseline (pre-change) was 500/500;
net +17 tests from the new test classes.

NOT yet pushed to remote, NOT yet deployed.

## Discoveries that changed the plan

### 1. Four call sites in `ReservationService`, not three

The proposal listed `adjustAvailability` as the single delta-math hot spot
called from `confirm`, `cancel`, and `expire`. **`createReservation` had its
own inline delta math** at the original lines 131–148: read latest snapshot,
compute `currentHold + 1`, call `createSnapshot` directly. The proposal
missed this fourth call site. The refactor handles it the same way:

- `createReservation` now calls `applyRecompute(..., 0, "reservation:create",
  "system:reservation")` after the insert, wrapped in a try/catch that
  translates `AvailabilityInvariantViolation` back into the existing
  `IllegalStateException("No beds available...")` for backward compat.
- The explicit pre-throw `updateStatus(CANCELLED)` is preserved (mirrors
  the prior defensive shape).

### 2. Migration is V44 / V45 (was V40 / V41 in first pass)

The proposal originally guessed V44. On this branch (created from
v0.32.3), coc-admin-escalation is **not** merged in the file system —
the latest pre-change migration is V39 — so the first implementation
pass slotted my migrations into V40 / V41.

**Smoke-test discovery (2026-04-11 evening):** the local Postgres
container, however, was running coc-admin-escalation work and already
had migrations V40 ("create escalation policy"), V41 ("referral token
admin columns"), V42 ("audit events nullable actor"), V43 ("referral
token escalation chain broken") applied. My V40 / V41 collided on
version number with coc-admin-escalation's V40 / V41 — Flyway would
have rejected my migrations as checksum mismatches at deploy time
against any database that had already run coc-admin-escalation work.

This collision would also have surfaced at PR / merge time when both
branches eventually land in main. Better to fix it now.

**Resolution — renumber:**

- **`V44__audit_events_allow_null_actor.sql`** (was V41 → V45 →
  finally V44 after the war-room swap) — drops the `NOT NULL`
  constraint on `audit_events.actor_user_id`. coc-admin-escalation's
  V42 makes the same schema change for the same reason. `ALTER
  COLUMN ... DROP NOT NULL` is a Postgres no-op when the column is
  already nullable, so V44 is safe regardless of which branch merges
  first. The migration's header comment documents the idempotency.
- **`V45__backfill_phantom_beds_on_hold.sql`** (was V40 → V44 →
  finally V45 after the war-room swap) — append-only one-time
  backfill with per-correction audit row writes, idempotent, tagged
  `updated_by = 'V45-rca-backfill'`. Slots in after coc-admin-
  escalation's V43. Writes `BED_HOLDS_RECONCILED` audit rows with
  `actor_user_id = NULL` per Casey Drummond's chain-of-custody
  requirement (war room 2026-04-11); this is why V44 (the NOT NULL
  drop) must run first.

**Why the swap:** the original V44 was the backfill and the original
V45 was the schema change. But the war room's Casey-Drummond ask
(write audit rows from the backfill migration) required the NOT NULL
drop to run BEFORE the backfill, not after. Swapping the two file
numbers preserves the intent while making the ordering correct.

Discovered 2026-04-11 evening during the local backfill smoke test.
Swap landed later the same evening after the war-room review.

### 3. `AuditEventTypes` had to be created from scratch

The proposal assumed `AuditEventTypes.java` already exists (it was part
of coc-admin-escalation). On this branch, it does not. New file:
`backend/src/main/java/org/fabt/shared/audit/AuditEventTypes.java` with the
`BED_HOLDS_RECONCILED` constant. Pin test:
`AuditEventTypesTest`.

### 4. Seed file had 3 orphan rows, not 17

The proposal said "17 shelter+population pairs with phantom holds totaling
24 beds." That count came from the live demo's accumulated drift, not the
seed. On this branch, `infra/scripts/seed-data.sql` has **3 orphan
`bed_availability` rows** with `beds_on_hold > 0` totalling **5 phantom
held beds**:

| Shelter | Pop type | beds_on_hold |
|---|---|---|
| `d0...002` Capital Blvd Family | FAMILY_WITH_CHILDREN | 1 |
| `d0...006` Downtown Warming Station | SINGLE_ADULT | 3 |
| `d0...010` Helping Hand Recovery | SINGLE_ADULT | 1 |

Also: there was **no `INSERT INTO reservation` block at all** in the seed.
The seed fix (Component 6) creates the block from scratch with 5 backing
HELD reservations, varied future `expires_at` (10–85 minutes ahead) so the
demo naturally shows the countdown timer at multiple lifecycle stages.

### 5. `ManualHoldController` is a new single-purpose controller

The proposal said "ReservationController (or ShelterController if more
topical — reviewer call)". The default chosen pre-implementation was
`ReservationController`, but Spring's `@RequestMapping` concatenates the
method-level path under the class-level prefix — there is no escape for
absolute paths. `ReservationController` is class-mapped to
`/api/v1/reservations`, so a method-level
`@PostMapping("/api/v1/shelters/{id}/manual-hold")` would resolve to
`/api/v1/reservations/api/v1/shelters/{id}/manual-hold`.

Resolution: new `ManualHoldController` in `org.fabt.reservation.api`,
class-mapped to `/api/v1/shelters`, single endpoint. Calls
`ReservationService.createManualHold(...)`. The spec'd URL is preserved.

### 6. Idempotency key derivation must hash to a UUID

The proposal said the manual-hold idempotency key would be derived from
`(userId, shelterId, populationType, "manual-hold", current_minute)`. The
straightforward concatenation of those values exceeds the
`reservation.idempotency_key` column's `VARCHAR(36)` width.
`createManualHold` now hashes the derived material via
`UUID.nameUUIDFromBytes(...)` (RFC 4122 v3 / MD5) into a 36-char UUID
string. Collision resistance is sufficient for a same-minute idempotency
key.

### 7. Spring Batch step uses `ResourcelessTransactionManager`

The proposal modeled the tasklet on `ReferralEscalationJobConfig` (which
uses the JPA transaction manager for the step). For this tasklet, that
caused `UnexpectedRollbackException: Transaction rolled back because it
has been marked as rollback-only` whenever any per-row operation triggered
an exception that was caught by my try/catch — Spring's AOP layer marks
the OUTER transaction as rollback-only at the moment the exception is
thrown, before my catch can swallow it.

Resolution: the `reconciliationStep()` bean is built with
`new ResourcelessTransactionManager()` instead of the JPA manager. The
tasklet body runs without an outer transaction; each per-row call to
`ReservationService.recomputeBedsOnHold` then opens its own
`@Transactional(REQUIRED)` boundary in `AvailabilityService.createSnapshot`.
A failure on one row only rolls back that row's transaction; the loop
continues unaffected.

### 8. Audit event publishing bypasses the `@EventListener`

For the same rollback-only reason, the tasklet does NOT use
`ApplicationEventPublisher.publishEvent(new AuditEventRecord(...))` to
record the `BED_HOLDS_RECONCILED` audit row. The `AuditEventService.onAuditEvent`
listener is a synchronous `@EventListener` (not `@Async`), so any exception
inside it (or inside the surrounding tx) marks the tasklet's outer tx as
rollback-only — the same trap captured in
`feedback_transactional_eventlistener` memory.

Resolution: the tasklet calls `auditEventRepository.save(...)` directly via
a private `writeAuditRowDirect(...)` helper, constructing the
`AuditEventEntity` with a `JsonString` details payload. The audit write is
wrapped in its own try/catch so a single audit failure does not roll back
the corrective snapshot — corrections are more important than perfect
audit coverage.

### 9. Per-row `TenantContext` wrapping inside the tasklet

The tasklet runs under
`TenantContext.runWithContext(null, true, ...)` (set by
`BatchJobScheduler.runJob` because the job is registered with
`dvAccess=true`). With `tenantId = null`, the recompute path's downstream
`shelterService.findById` call returned empty because the shelter is
tenant-scoped via RLS.

Resolution: `findDriftedRows()` now also returns `tenant_id`, and the
tasklet wraps each per-row recompute in
`TenantContext.runWithContext(row.tenantId(), true, ...)`. The drift query
itself still runs under `tenant=null + dvAccess=true` so it sees rows from
every tenant; the per-row recompute then binds the right tenant for the
shelter lookup and snapshot insert.

### 10. ArchUnit boundary preserved without a new rule

The proposal worried that the new `org.fabt.availability.batch` package
would need an ArchUnit allowance for cross-module access to
`reservation.service`. The existing rules already permit this:
`availability_should_not_access_other_repositories` forbids
`reservation.repository..` but does NOT forbid `reservation.service..`.
And `availability_should_not_access_other_domain_entities` forbids
`reservation.domain..` but the only thing the tasklet imports from the
reservation module is `ReservationService` (whose `recomputeBedsOnHold`
method returns `void` and takes only primitives + UUID + String). No
new ArchUnit rule needed; the 22 existing tests in `ArchitectureTest`
all pass against the new code.

## Known wrinkles + follow-ups

### A. SecurityConfig filter rule gap — ROOT-CAUSED and FIXED (war room 2026-04-11)

An earlier draft of this document described a "coordinator-assigned-via-HTTP
test infrastructure wrinkle" in which the `OfflineHoldEndpointTest`
success-path test couldn't use real coordinator headers. That framing
was **wrong**. The root cause was not test infra — it was a real
production bug in `SecurityConfig.java:172`:

```java
// BEFORE (bug):
.requestMatchers(HttpMethod.POST, "/api/v1/shelters/**").hasAnyRole("COC_ADMIN", "PLATFORM_ADMIN")
```

`COORDINATOR` was missing from the role list on the `POST
/api/v1/shelters/**` catch-all. The new `POST /api/v1/shelters/{id}/manual-hold`
endpoint matched this wildcard, so Spring Security's filter chain
rejected every coordinator call at the filter level — **before**
`@PreAuthorize` or the controller's `isAssigned()` check could run. The
403 response body came from the inline `accessDeniedHandler` at
`SecurityConfig.java:195-200`, which writes the same JSON shape
(`{"error":"access_denied","message":"Insufficient permissions","status":403}`)
as `GlobalExceptionHandler.handleAccessDenied`. Because the two response
bodies were indistinguishable, the integration test couldn't tell which
branch rejected the request, and the "wrinkle" framing slipped past
code review.

**Production impact in v0.32.x and v0.33.x pre-fix:** every coordinator
who hits `/manual-hold`, regardless of shelter assignment, gets 403'd
silently. The entire coordinator offline-hold workflow (the legitimate
"phone reservation / expected guest" use case that Component 3 was added
for) is broken. This is production-blocking for any real-tenant
deployment of bed-hold-integrity.

**Fix (landed in this change):** insert a more specific rule before
line 172, matching Spring's first-match-wins semantics:

```java
// Manual offline hold (Issue #102 / bed-hold-integrity): coordinators can
// create offline holds at their assigned shelters. Filter chain admits
// the role; the fine-grained shelter-assignment check is enforced in
// ManualHoldController via CoordinatorAssignmentRepository.isAssigned.
// Two-layer authz contract — filter is the coarse first pass, controller
// is the fine second pass. The filter must never be more restrictive than
// the controller body.
.requestMatchers(HttpMethod.POST, "/api/v1/shelters/*/manual-hold").hasAnyRole("COORDINATOR", "COC_ADMIN", "PLATFORM_ADMIN")
```

**Test coverage additions (Riley Cho gating):**
- New `OfflineHoldEndpointTest.coordinator_creates_offline_hold_succeeds_when_assigned`
  using real `coordinatorHeaders()` — exercises the full filter → controller → isAssigned path.
- `OfflineHoldEndpointTest.coordinator_not_assigned_to_shelter_403` now
  asserts that the `fabt.http.access_denied.count` counter incremented by 1,
  which proves the rejection came from the controller's `isAssigned` branch
  (increments counter via GlobalExceptionHandler) and not from the filter
  chain (does not increment counter). This is the regression guard for
  SecurityConfig ever narrowing below the controller contract again.
- `ManualHoldController.create()` now carries a Javadoc documenting the
  two-layer authz contract.

**Verified against live dev stack 2026-04-11 20:55-21:04 UTC:**
- Pre-fix: POST /manual-hold as `dv-coordinator@dev.fabt.org` → HTTP 403,
  `fabt_http_access_denied_count_total` absent from Prometheus (proving
  GlobalExceptionHandler was never called).
- Post-fix (pending verification): POST /manual-hold same user/shelter → expect HTTP 201.

### B. V45/seed-Component-6 ordering — FIXED (war room 2026-04-11)

An earlier draft of this document counted 3 `BED_HOLDS_RECONCILED` audit
rows at T+5 min on every fresh restart as "transient artifacts." Casey
Drummond pointed out that the audit trail was misleading: the rows
described corrections for drift that the system had itself induced via
a V45-backfill/seed-Component-6 ordering bug. Flyway's V45 backfill
runs during Spring context init, BEFORE dev-start.sh loads seed-data.sql.
At V45 time the reservation table has zero HELD rows for the seed's
orphan pairs, so V45 writes corrective snapshots of `beds_on_hold = 0`.
Then seed Component 6 inserts 5 HELD reservations, creating reverse
drift (snapshot=0, held=1/3/1). The scheduled reconciliation tasklet
catches it within 5 minutes, but those 5 minutes are a phantom-LOW
window where outreach workers see 1 fewer bed at 3 shelters than
actually exists. Opposite direction from the original #102 bug, but
still wrong and still misleading the audit trail.

**Fix (landed in this change):** add an `INSERT INTO bed_availability`
block to seed-data.sql Component 6 AFTER the `INSERT INTO reservation`
block, writing fresh snapshots with `clock_timestamp()` (strictly later
than V45's `clock_timestamp()`) and the correct `beds_on_hold` values
(1, 3, 1). Both blocks wrapped in a single `BEGIN; ... COMMIT;`
transaction per Elena Vasquez — if the script crashes between them,
the DB is left in the same drift state we started with rather than
a half-committed reverse-drift state.

### C. V44/V45 ordering rename

V44 and V45 were swapped from their previous placement. V44 is now
`audit_events_allow_null_actor.sql` (previously V45) and V45 is now
`backfill_phantom_beds_on_hold.sql` (previously V44). This ordering is
required so the V45 backfill can write audit_events rows with
`actor_user_id = NULL` (Casey Drummond's chain-of-custody requirement,
war room 2026-04-11). Flyway runs migrations in version order, so
V44 → V45 is guaranteed.

### D. V45 writes audit_events rows for each corrective snapshot

Per Casey Drummond's war room ask: the one-time backfill migration
should not be a silent system-initiated state change. V45 now writes
one `audit_events` row per actually-inserted snapshot, via a single
compound CTE that captures `RETURNING shelter_id, population_type`
from the `INSERT INTO bed_availability` and joins back to the drifted
row for the before/after values. The audit row payload is:

```json
{
  "shelter_id": "...",
  "population_type": "SINGLE_ADULT",
  "snapshot_value_before": 3,
  "actual_count": 0,
  "delta": -3,
  "correction_source": "V45_backfill",
  "github_issue": "https://github.com/ccradle/finding-a-bed-tonight/issues/102"
}
```

An auditor asking "why did `beds_on_hold` change on the Oracle demo at
deploy time on 2026-04-12 for Downtown Warming Station" can find this
exact row in `audit_events` with `action = 'BED_HOLDS_RECONCILED'` and
`correction_source = 'V45_backfill'`.

### B. Pre-existing tests that relied on coordinator-supplied `bedsOnHold`

Three tests had to be updated because they passed `bedsOnHold > 0` via
the deprecated PATCH path and expected the value to be honored:

- `BedAvailabilityHardeningTest.tc_1_7_decreaseTotalBelowOccupiedPlusHold_rejected`
  — rewritten to place real reservations first, then attempt the total
  reduction. Mirrors the existing TC-2.8 pattern at finer granularity.
- `OverflowBedsIntegrationTest.overflow_doesNot_alterBedsAvailable`
  — changed inputs from `(30, 20, 2, 15)` to `(30, 20, 0, 15)` and
  updated the assertion. The test's intent (overflow doesn't enter the
  bedsAvailable derivation) is preserved; the hold value was incidental.
- `AvailabilityIntegrationTest.test_shelterDetail_includesAvailability`
  — same shape: `hold=2` → `hold=0`, assertion follows.

All three updates have inline comments referencing Issue #102.

### C. Backfill timing — RESOLVED 2026-04-11

The founder confirmed: backfill happens as part of this release, not
sooner. The V40 migration handles it automatically when v0.34.0 deploys
to the demo site. No separate manual SQL run needed pre-Asheville. If
the demo shows phantom holds before that, brief the audience that the
fix is shipping in the same release.

## OpenSpec questions (OQ1–OQ4) — resolved

- **OQ1 (DemoGuard for `/manual-hold`):** friendly-block. Implemented in
  `DemoGuardFilter.getBlockMessage`. Path matches
  `/api/v1/shelters/[^/]+/manual-hold`.
- **OQ2 (offline hold expiry):** same `tenant.hold_duration_minutes` as
  regular holds. `createManualHold` delegates to `createReservation` which
  uses the existing `getHoldDurationMinutes(tenantId)` lookup.
- **OQ3 (reconciliation cadence):** 5 minutes (`0 */5 * * * *`).
- **OQ4 (gating profile):** standard `mvn test` profile. No separate
  profile needed.

## Files added or modified

### New files (10)

- `backend/src/main/java/org/fabt/shared/audit/AuditEventTypes.java`
- `backend/src/main/java/org/fabt/availability/batch/BedHoldsReconciliationJobConfig.java`
- `backend/src/main/java/org/fabt/reservation/api/ManualHoldController.java`
- `backend/src/main/java/org/fabt/reservation/api/ManualHoldRequest.java`
- `backend/src/main/resources/db/migration/V44__audit_events_allow_null_actor.sql`
- `backend/src/main/resources/db/migration/V45__backfill_phantom_beds_on_hold.sql`
- `backend/src/test/java/org/fabt/reservation/BedHoldsInvariantTest.java` (7 tests)
- `backend/src/test/java/org/fabt/availability/batch/BedHoldsReconciliationJobTest.java` (4 tests)
- `backend/src/test/java/org/fabt/reservation/OfflineHoldEndpointTest.java` (5 tests)
- `backend/src/test/java/org/fabt/shared/audit/AuditEventTypesTest.java` (1 test)

### Modified files (8)

- `backend/src/main/java/org/fabt/reservation/service/ReservationService.java` — refactor + `createManualHold`
- `backend/src/main/java/org/fabt/availability/api/AvailabilityController.java` — ignore `bedsOnHold`
- `backend/src/main/java/org/fabt/availability/api/AvailabilityUpdateRequest.java` — deprecation Javadoc + remove unused helper
- `backend/src/main/java/org/fabt/availability/repository/BedAvailabilityRepository.java` — `findDriftedRows()` + `DriftRow` record
- `backend/src/main/java/org/fabt/availability/service/AvailabilityService.java` — (no change needed; existing `createSnapshot` handles INV-5)
- `backend/src/main/java/org/fabt/observability/ObservabilityMetrics.java` — three new bed-hold reconciliation metrics
- `backend/src/main/java/org/fabt/shared/security/DemoGuardFilter.java` — friendly-block message for `/manual-hold`
- `infra/scripts/seed-data.sql` — new `INSERT INTO reservation` block

### Modified test files (3)

- `backend/src/test/java/org/fabt/availability/BedAvailabilityHardeningTest.java` — TC-1.7 rewritten
- `backend/src/test/java/org/fabt/availability/OverflowBedsIntegrationTest.java` — hold inputs zeroed
- `backend/src/test/java/org/fabt/availability/AvailabilityIntegrationTest.java` — hold inputs zeroed

## Backend regression deltas

| Metric | Pre-change baseline | Post-change |
|---|---|---|
| Total tests | 500 | 517 |
| Failures | 0 | 0 |
| Errors | 0 | 0 |
| Skipped | 0 | 0 |
| Build | SUCCESS | SUCCESS |
| Wall clock | ~1:48 min | ~1:50 min |

## Pre-merge verification still pending (your queue)

These are the items I deliberately did NOT run (per the no-push, no-ssh,
no-dev-start, no-playwright restrictions on this session):

- [ ] Local end-to-end smoke via `./dev-start.sh --fresh --nginx` and the
      bed search → reservation create → expire → reconciliation cycle
      manually through the UI.
- [ ] Manual SQL verification: `SELECT shelter_id, population_type,
      beds_on_hold, ... WHERE beds_on_hold != held_count` should return
      zero rows on a freshly seeded local stack.
- [ ] Full Playwright suite (`BASE_URL=http://localhost:8081 npx playwright
      test`).
- [ ] Push the branch to remote.
- [ ] Open the PR.
- [ ] CHANGELOG and `pom.xml` version bump (when ready to release).
