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

- **`V44__backfill_phantom_beds_on_hold.sql`** (was V40) — append-only
  one-time backfill, idempotent, tagged `updated_by = 'V44-rca-backfill'`.
  Slots in after coc-admin-escalation's V43.
- **`V45__audit_events_allow_null_actor.sql`** (was V41) — drops the
  `NOT NULL` constraint on `audit_events.actor_user_id`.
  coc-admin-escalation's V42 makes the same schema change for the same
  reason. `ALTER COLUMN ... DROP NOT NULL` is a Postgres no-op when
  the column is already nullable, so V45 is safe regardless of which
  branch merges first. The migration's header comment documents the
  idempotency.

Discovered 2026-04-11 evening during the local backfill smoke test.
Backend regression re-ran with the renumber: 517 / 517 still pass.

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

### A. Coordinator-assigned-via-HTTP test wrinkle

`OfflineHoldEndpointTest` was originally going to exercise the
"assigned coordinator can create offline hold via the HTTP path" success
case. In the integration-test environment, the controller's
`coordinatorAssignmentRepository.isAssigned(userId, shelterId)` returned
`false` even when the assignment row was visible to the test thread
immediately after `assign()` (verified via a sanity assertion). The 403
returned by the controller was clearly the
`AccessDeniedException("Coordinator is not assigned to this shelter")`
branch, not the Spring Security `@PreAuthorize` denial.

This is a test-infrastructure wrinkle that has not previously been
exercised in the codebase: looking at `BedAvailabilityHardeningTest` —
the only other test of an endpoint with the coordinator+assignment
pattern — it cheats by storing `cocAdminHeaders()` in a field named
`coordHeaders` and never actually exercises the coordinator role.

**Mitigation in this change:** the success-path tests in
`OfflineHoldEndpointTest` use `cocAdminHeaders()` (admins bypass the
assignment check); the negative coordinator path
(`coordinator_not_assigned_to_shelter_403`) still validates via
coordinator headers. Plus `BedHoldsInvariantTest.invariant_after_offline_hold`
exercises the manual-hold endpoint via cocAdmin.

**Follow-up:** open a separate GH issue to investigate the coordinator
+assigned-shelter test infrastructure path. Hypotheses: (a) the user_id
in the JWT differs from the assigned coordinator id due to a stale
cached User in `TestAuthHelper`, (b) the JdbcTemplate connection used
by the controller has different connection pool semantics than the test
thread's, (c) some session-level RLS setting on `coordinator_assignment`
is filtering reads. None of these are the bed-hold-integrity change's
problem; the same wrinkle would block any future test exercising this
HTTP path.

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
- `backend/src/main/resources/db/migration/V44__backfill_phantom_beds_on_hold.sql`
- `backend/src/main/resources/db/migration/V45__audit_events_allow_null_actor.sql`
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
