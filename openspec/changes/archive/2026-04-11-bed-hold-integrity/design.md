# Design — bed-hold-integrity

## Context

`bed_availability.beds_on_hold` is a denormalized count cached on the `bed_availability` snapshot table. The canonical source of truth for "how many beds are currently held at this shelter for this population" is `SELECT COUNT(*) FROM reservation WHERE shelter_id = ? AND population_type = ? AND status = 'HELD'`. The denormalization exists for read-path performance — every bed search query computes `beds_available = beds_total - beds_occupied - beds_on_hold` and would otherwise need a JOIN with COUNT for every shelter row in the result set.

The denormalization is a defensible optimization. The bug is that **no write path enforces the invariant** between the cached value and the source of truth. Three independent paths can mutate `beds_on_hold` and not one of them recomputes from the source:

1. **Reservation lifecycle (`ReservationService.adjustAvailability`)** — does delta math (`current.bedsOnHold + holdDelta`) against the latest snapshot's value. If the baseline is wrong, every subsequent create/expire perpetuates the wrong baseline. Bottoming-out at the baseline prevents the value from ever reaching zero.
2. **Manual coordinator PATCH (`AvailabilityController.updateAvailability`)** — accepts a coordinator-supplied `beds_on_hold` value with only a lower-bound check (`max(requestedHold, activeHeldCount)`). A coordinator can set `beds_on_hold = 99` with zero active reservations and the system writes it.
3. **Seed (`infra/scripts/seed-data.sql`)** — directly inserts initial `bed_availability` rows with hardcoded `beds_on_hold > 0` values without inserting matching `HELD` reservation rows.

The reservation expiry job is **healthy** and is not a bug source. Every expired reservation correctly transitions and calls `adjustAvailability(reservation, -1, ...)`. The expiry side propagates correct deltas; the bug is on the write paths that introduce baseline drift.

The live findabed.org demo as of 2026-04-11 has 17 shelter+population pairs with phantom holds totaling 24 beds. The drift was introduced primarily by the seed (path 3) and the manual coordinator PATCH (path 2), and propagated indefinitely by the reservation expiry path (path 1) doing delta math against the wrong baseline.

The four key code locations established by the senior SME war room:

- `backend/src/main/java/org/fabt/reservation/service/ReservationService.java:279-298` — `adjustAvailability` does delta math (Finding 1)
- `backend/src/main/java/org/fabt/availability/api/AvailabilityController.java:80-86` — lower-bound-only protection (Finding 2)
- `backend/src/main/java/org/fabt/availability/api/BedSearchController.java:40` and `AvailabilityService.java:164` — bed search formula consumes the cached value (Finding 3)
- `infra/scripts/seed-data.sql` line 286 (and 16 other rows) — seed introduces orphan baselines

## Goals / Non-Goals

**Goals**

- Eliminate the bug class structurally so no future write path can reintroduce drift.
- Preserve the bed search hot-path performance (no schema change, no read-path change, no JOIN added to bed search queries).
- Provide defense-in-depth against future drift sources we cannot foresee today.
- Provide an operator-visible audit trail for every reconciliation correction.
- Create a load-bearing invariant test that fails loudly if a future refactor reintroduces the bug.
- Preserve the legitimate "coordinator marks beds as held offline" workflow via a new endpoint that goes through the reservation table.

**Non-Goals**

- Drop the `beds_on_hold` column entirely (rejected — see D1 below)
- Add database triggers on the `reservation` table (rejected — see D3)
- Make `beds_on_hold` a database `GENERATED` column (rejected — PostgreSQL `GENERATED` columns cannot reference other tables, only the same row)
- Migrate the existing `ReservationExpiryService` from `@Scheduled` to Spring Batch (out of scope, separate change)
- Add multi-instance coordination via ShedLock (out of scope, FABT is single-instance today and the reconciliation job is idempotent under concurrency)

## Decisions

### D1 — `beds_on_hold` stays as a column on `bed_availability`. Read path unchanged.

**Considered alternatives:**
- **D1a** — drop the column, compute at query time via subquery on every bed search row
- **D1b** — keep the column but back it with a `GENERATED` PostgreSQL column referencing the `reservation` table
- **D1c (chosen)** — keep the column, eliminate writes that introduce drift, recompute on every reservation lifecycle event

**Why D1c:** D1a is the cleanest from a "no denormalization" perspective but has the largest blast radius — every bed search row would need a `(SELECT COUNT(*) FROM reservation ...)` subquery. Sam Okafor performance-checked this: with the existing `idx_reservation_shelter_status` index it would be sub-millisecond per shelter, totally affordable. **But** v0.32.1 just shipped a 28x bed search optimization (recursive CTE skip scan) and walking that back without strong reason is unwise. D1b is impossible — PostgreSQL `GENERATED` columns can only reference the same row, not other tables. D1c gives us the bug-class elimination without touching the read path.

**Cost of D1c:** the denormalization stays. The application is the only enforcer. The reconciliation job (D5) is the safety net that catches any escape from the discipline.

### D2 — Single write path: `recomputeBedsOnHold(shelterId, populationType, actor, notes)`

**Considered alternatives:**
- **D2a** — keep delta math, add upper-bound validation that the result matches the actual count (compute the actual count anyway, so why not just use it directly)
- **D2b** — push the recompute to a database stored procedure
- **D2c (chosen)** — replace every delta math call site with a single application-layer method that COUNT-queries the source of truth and writes the result

**Why D2c:** delta math has a fundamental flaw — it assumes the baseline is correct. The fix is to never trust the baseline. Every reservation lifecycle event already knows the shelter and population type; the cost of an indexed COUNT query is negligible. D2b moves the logic into a stored procedure which is harder to test and harder to read. D2c keeps the logic in Java where Riley Cho can write tests for it.

**API:**
```java
private void recomputeBedsOnHold(UUID shelterId, String populationType, String actor, String notes) {
    int actualHeldCount = reservationRepository.countActiveByShelterId(shelterId, populationType);
    BedAvailability current = availabilityRepository.findLatestByShelterId(shelterId).stream()
        .filter(ba -> ba.getPopulationType().equals(populationType))
        .findFirst().orElse(null);
    int bedsTotal = current != null ? current.getBedsTotal() : 0;
    int bedsOccupied = current != null ? current.getBedsOccupied() : 0;
    boolean accepting = current != null ? current.isAcceptingNewGuests() : true;
    int currentOverflow = current != null && current.getOverflowBeds() != null
        ? current.getOverflowBeds() : 0;
    availabilityService.createSnapshot(
        shelterId, populationType,
        bedsTotal, bedsOccupied, actualHeldCount,
        accepting, actor, notes,
        currentOverflow);
}
```

**Replaces:** every existing call to `adjustAvailability(reservation, +/-1, 0, ...)` becomes `recomputeBedsOnHold(reservation.shelterId, reservation.populationType, ...)`. The delta parameters disappear.

### D3 — Database triggers on `reservation` are rejected

**Considered:** an `AFTER INSERT OR UPDATE OR DELETE` trigger on the `reservation` table that recomputes `bed_availability.beds_on_hold` for the affected shelter+population.

**Rejected because:**
- Elena Vasquez: triggers in PostgreSQL are testable in principle but operationally hard to debug. They create cross-table commit dependencies. A trigger firing on every `reservation` write would amplify the bed_availability snapshot append rate significantly.
- Riley Cho: a trigger is invisible from Java tests. The invariant assertion test would still need to be run to prove the trigger works.
- Marcus Webb: trigger logic is harder to evolve than service-layer logic.

The application-layer single-write-path discipline (D2) is preferred. The reconciliation job (D5) is defense-in-depth that catches any escape.

### D4 — Manual PATCH endpoint deprecates `beds_on_hold`

**Considered alternatives:**
- **D4a** — hard-reject any non-null `bedsOnHold` in the request with a 400 error
- **D4b (chosen)** — soft-deprecate: log a WARN if non-null and non-zero, ignore the value, return the response from `recomputeBedsOnHold`'s output

**Why D4b for v0.33.0/v0.34.0:** existing API consumers may be passing `bedsOnHold = 0` as a no-op, and rejecting them hard would break those clients. The soft deprecation gives one release window of warning. v0.35.0 can flip to hard rejection (D4a) once the warning logs prove no real client is sending non-zero values.

The Javadoc on `AvailabilityUpdateRequest.bedsOnHold` is updated to:
```
@deprecated As of v0.33.0, beds_on_hold is server-managed via the reservation
table. This field is ignored and will be removed in v0.35.0. To mark beds as
held for offline reasons, use POST /api/v1/shelters/{id}/manual-hold instead.
```

### D5 — Spring Batch reconciliation tasklet (not @Scheduled)

**Considered alternatives:**
- **D5a** — `@Scheduled(fixedDelay = 5 * 60 * 1000)` Spring scheduled task, simple method, no batch framework
- **D5b (chosen)** — Spring Batch tasklet wrapped in a `@Scheduled` invocation that calls `JobLauncher.run(reconciliationJob, ...)`

**Why D5b:** the senior SME war room reviewed industry guidance (Databricks, Monte Carlo, Airbyte, Spring Batch reference docs) which converges on the following:
- Use Spring Batch when you want **job execution metadata, restartability, observability, multi-instance future-proofing** — even for small datasets
- Use plain `@Scheduled` for simple, short-lived, stateless tasks where you don't need any of the above

For the reconciliation job we want all five Spring Batch advantages:
- **Consistency** with the existing `ReferralEscalationJobConfig` (the only other operational batch in this codebase). Two batch frameworks in one codebase is confusing; one is not.
- **Job execution history** lives in `batch_job_execution` and `batch_step_execution` tables (already provisioned by Flyway). Operators can see when the job last ran, how long it took, what it processed.
- **Built-in Micrometer integration** for the duration Timer metric — the metrics infrastructure plumbing is already wired in `ReferralEscalationJobConfig`'s pattern.
- **NYC-scale comfort** — chunk processing is built in if the shelter+population pair count grows beyond a few hundred. For the current ~50 pairs we don't need it, but the framework provides it for free.
- **Multi-instance future-proofing** — the `JobRepository` lets us add ShedLock or rely on `batch_job_execution` status semantics if FABT ever scales beyond single-instance.

**Cost of D5b:** more boilerplate than `@Scheduled`. ~80 lines of Spring Batch configuration vs ~20 for `@Scheduled`. Acceptable cost for the operational visibility.

**Schedule:** `@Scheduled(fixedDelay = 5 * 60 * 1000)` invoking `JobLauncher.run(...)`. Per industry guidance: use `fixedDelay` not `fixedRate` for batch-style work (naturally throttles if a run takes longer than expected).

**RLS gotcha (Elena Vasquez):** the tasklet runs without `TenantContext` by default, which means RLS would filter out DV shelter rows. The `ReservationExpiryService` (which has the same problem) handles this by NOT being wrapped in TenantContext at all (it works because reservation RLS filters via shelter FK and DV shelters use the referral token system, not the reservation system). For the reconciliation job we DO need to see DV shelter rows because they have `beds_on_hold > 0` from the seed too. The job MUST be wrapped in `TenantContext.runWithContext(null, true, () -> { ... })` to set `dv_access = true` so DV shelter rows are visible to the reconciliation query.

### D6 — One-time backfill via Flyway migration

**Considered alternatives:**
- **D6a** — manual SQL run by an operator at deploy time
- **D6b (chosen)** — Flyway migration that runs automatically on backend startup

**Why D6b:** Flyway gives us:
- Audit trail in `flyway_schema_history` (timestamp, who, success status)
- Automatic execution on every deployment that hasn't yet applied it
- Idempotent — re-running the migration is a no-op because Flyway tracks application
- The migration body itself is also idempotent at the data level (the `WHERE` clause only matches drifted rows; once corrected, re-applying inserts zero rows)

**Migration name:** `V40__backfill_phantom_beds_on_hold.sql` (assuming V40 is the next available version on the demo; the actual next number depends on what coc-admin-escalation lands first — see the `Compatibility / sequencing` section below).

### D7 — Audit event type `BED_HOLDS_RECONCILED`

**Considered alternatives:**
- **D7a** — log corrections at INFO level only, no audit event
- **D7b** — write one audit row per correction with action `BED_HOLDS_RECONCILED`
- **D7c** — write one audit row per reconciliation job RUN summarizing the corrections

**Why D7b (per Casey Drummond):** auditors want one row per state change, not one row per batch. D7c hides the individual corrections behind the summary which is harder to query. D7a is invisible to the audit table which is the wrong layer for chain-of-custody questions.

The audit row payload:
```json
{
  "shelter_id": "...",
  "population_type": "SINGLE_ADULT",
  "snapshot_value_before": 3,
  "actual_count": 0,
  "delta": -3
}
```

The `actor_user_id` for these rows is `null` because the system is the actor (V42 made `actor_user_id` nullable for exactly this kind of system action). The `action` is `BED_HOLDS_RECONCILED` (new constant added to `AuditEventTypes.java`).

### D8 — Seed fix backs orphan `beds_on_hold` with real reservations

**Considered alternatives:**
- **D8a** — set all seed `beds_on_hold = 0` (cleanest, loses "lived in" demo feel)
- **D8b (chosen)** — for every seed `bed_availability` row with `beds_on_hold = N > 0`, INSERT N matching `reservation` rows with `status = 'HELD'`, varied `expires_at` (some past for "expired but still in the queue" demo states, some future for "active hold" states), and `user_id = 'b0000000-0000-0000-0000-000000000001'` (the admin sentinel)

**Why D8b:** D8a loses the demo realism that the existing seed was trying to convey. D8b preserves the "shelter has 3 beds on hold right now" visual signal while making it consistent with the runtime invariant. After the change, `--fresh` produces a clean baseline where every seed-introduced hold is backed by a real reservation row. The demo stays "lived in" but no longer drifts.

**Seed structure (concrete example for Downtown Warming Station):**
```sql
-- 3 HELD reservations to back the seeded beds_on_hold = 3
INSERT INTO reservation (shelter_id, tenant_id, population_type, user_id, status, expires_at, notes)
VALUES
('d0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001',
 'SINGLE_ADULT', 'b0000000-0000-0000-0000-000000000001', 'HELD',
 NOW() + INTERVAL '60 minutes', 'Seed: active hold for demo realism'),
('d0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001',
 'SINGLE_ADULT', 'b0000000-0000-0000-0000-000000000001', 'HELD',
 NOW() + INTERVAL '30 minutes', 'Seed: active hold for demo realism'),
('d0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001',
 'SINGLE_ADULT', 'b0000000-0000-0000-0000-000000000001', 'HELD',
 NOW() + INTERVAL '5 minutes', 'Seed: active hold for demo realism');
```

The 5-minute one is intentionally close to expiry so the demo shows the lifecycle: a held bed about to release, a held bed in the middle of its window, a held bed early in its window. Operators see the natural progression.

### D9 — Riley Cho's invariant assertion test is gating

**Decision:** the invariant test must land in the SAME change as the fix, not as a follow-up. The whole point of the test is to prevent a future refactor from reintroducing the bug class. If the test ships separately, there's a window where the fix exists without its guardrail.

**Test shape:**
```java
@Test
void invariant_beds_on_hold_matches_held_reservation_count_after_create() {
    // ... create reservation ...
    int actualHeld = jdbcTemplate.queryForObject(
        "SELECT COUNT(*) FROM reservation WHERE shelter_id = ? AND population_type = ? AND status = 'HELD'",
        Integer.class, shelterId, populationType);
    int snapshotHold = availabilityRepository.findLatestByShelterId(shelterId).stream()
        .filter(ba -> ba.getPopulationType().equals(populationType))
        .findFirst().map(BedAvailability::getBedsOnHold).orElse(0);
    assertThat(snapshotHold).isEqualTo(actualHeld);
}
```

The same assertion runs in `BedHoldsInvariantTest.invariant_after_cancel`, `invariant_after_expire`, `invariant_after_offline_hold_endpoint`. Four test methods covering four lifecycle paths.

### D10 — `beds_on_hold` column NOT renamed, NOT moved

**Considered:** renaming the column to `beds_on_hold_cached` to signal its derived nature.

**Rejected because:** the schema rename would break every existing query and migration. The name doesn't reflect the new discipline anywhere outside the schema. A Javadoc on `BedAvailability.bedsOnHold` documenting the discipline is sufficient:

```java
/**
 * Cached count of HELD reservations for this shelter+population. SERVER-MANAGED ONLY.
 *
 * <p><b>Do not write this field directly outside ReservationService.recomputeBedsOnHold().</b>
 * The canonical source of truth is COUNT(*) of `reservation` rows with status='HELD' for the
 * same shelter+population. This field is a denormalized cache for the bed search hot path
 * (BedSearchController formula: beds_available = beds_total - beds_occupied - beds_on_hold).
 *
 * <p>Three drift sources existed in v0.32.x and earlier (see openspec/changes/archive/
 * bed-hold-integrity for the RCA): delta-math against stale baselines, manual coordinator
 * PATCH writes, and seed-introduced orphans. All three were eliminated in v0.34.0 by routing
 * every write through {@link ReservationService#recomputeBedsOnHold}. The reconciliation
 * tasklet ({@link BedHoldsReconciliationJobConfig}) is the safety net.
 *
 * <p>If you need to add a new write path, route it through recomputeBedsOnHold. Direct writes
 * to this field will be caught by BedHoldsInvariantTest.
 */
private int bedsOnHold;
```

## Risks / Trade-offs

| Risk | Severity | Mitigation |
|---|---|---|
| Reconciliation job runs forever, masking the underlying bug | LOW | Every correction writes an audit row + INFO log + counter increment. Operations can monitor the counter and investigate if it climbs above zero. |
| New offline-hold endpoint creates a race with reservation expiry | LOW | Offline holds use the same `expires_at` field; the existing expiry job naturally cleans them up. No new lifecycle code path. |
| Soft-deprecation of `bedsOnHold` in PATCH breaks an external API consumer | LOW | The field is still ACCEPTED, just ignored. Logged as WARN so the breakage signal is visible. v0.35.0 can flip to hard rejection after one release window of warnings. |
| Spring Batch boilerplate is heavier than @Scheduled for a small job | MEDIUM | Accepted cost for operational visibility per D5. Mitigated by following the existing `ReferralEscalationJobConfig` pattern as a template. |
| Backfill migration is destructive | NONE | Migration is INSERT-only (append-only snapshot pattern). No UPDATE, no DELETE. Reversible by another INSERT. Idempotent re-runs are zero-row no-ops. |
| The reconciliation tasklet RLS wrap (TenantContext.runWithContext(null, true, ...)) lets it see DV shelter data, which is sensitive | LOW | Per Elena Vasquez. The tasklet only WRITES to bed_availability snapshots and audit_events; it does not log DV shelter names or addresses. The RLS wrap is necessary for correctness. |
| Multi-instance race writes duplicate corrective snapshots | LOW | Idempotent under concurrency. Two corrections produce two audit rows but the data converges. ShedLock deferred. |

## Compatibility / sequencing

This change targets the v0.34.0 release window. The recommended sequence:

1. **v0.33.0 ships first** (coc-admin-escalation feature). Already in flight on `feature/coc-admin-escalation`. No interaction with this change.
2. **v0.34.0 is the bed-hold-integrity release** (this change). Branched from main after v0.33.0 lands.
3. The Flyway migration version number for the backfill (Component 7) depends on what v0.33.0 lands. v0.33.0 introduces V40 (escalation policy) per the coc-admin-escalation deploy plan. This change's backfill migration is therefore **V41** (or whatever the next available version is at branch time — confirm at branch creation, not at design time).

**Open question (resolve at branch time):** does v0.33.0's coc-admin-escalation deploy plan use Flyway V40 or a later version? The coc-admin-escalation OpenSpec lists V40 (escalation_policy table), V41 (referral_token columns), V42 (audit nullable actor), V43 (referral chain broken column). So this change's backfill should be **V44** at the earliest.

**Branch isolation rule (per the founder's earlier "preserve v0.33.0 work" instruction):** the bed-hold-integrity branch is separate from `feature/coc-admin-escalation`. The two changes do not share files. The reservation/availability code paths this change touches are completely independent of the escalation queue work. Conflict-free rebases in either direction.

## Migration Plan

1. **Tag the v0.32.3 baseline** as the known-bad-but-running state on the live demo. (Already tagged as `v0.32.3` from the hotfix.)
2. **Create branch** `bugfix/issue-102-phantom-beds-on-hold` from `v0.32.3` for the RCA work. (Already done.)
3. **Implement Components 1-7** on the bugfix branch in the order documented in `tasks.md`.
4. **Local validation:** `mvn clean test` (expect ~560+ tests passing including the new `BedHoldsInvariantTest`, `BedHoldsReconciliationJobTest`, `OfflineHoldEndpointTest`).
5. **Demo dry-run:** stop local stack, `--fresh --nginx` restart, exercise the bed search → reservation create → expire → search cycle, verify `beds_on_hold` math is correct end-to-end.
6. **Open the v0.34.0 PR** against `main` after v0.33.0 has merged.
7. **Apply the v0.34.0 deploy plan** (similar shape to v0.32.3 hotfix and v0.33.0 — `mvn clean package`, no-cache Docker build, force-recreate, post-deploy smoke).
8. **Post-deploy smoke** includes a manual SQL check: `SELECT shelter_id, population_type, beds_on_hold, (SELECT COUNT(*) FROM reservation WHERE shelter_id=ba.shelter_id AND population_type=ba.population_type AND status='HELD') AS held FROM (latest snapshots) ba WHERE beds_on_hold > 0;` — every row should show `beds_on_hold === held`.

## Open Questions

- **OQ1:** Should the offline-hold endpoint be available to COORDINATOR role or admin-only? Initial proposal: COORDINATOR + COC_ADMIN + PLATFORM_ADMIN, since the legitimate use case (phone reservations, expected guests) is fundamentally a coordinator workflow. Validate with Marcus Okafor before implementation.
- **OQ2:** Should the reconciliation tasklet emit a metric for "drift detected per run" so operations can dashboard the trend? Sam Okafor's instinct says yes (you want to see drift as a leading indicator of a future bug, not just react to corrections). Implementing in Component 4.
- **OQ3:** Is the seed fix (Component 6) breaking for the existing test suite? Several tests likely depend on the current seed shape. Audit during implementation. If broken, either update tests OR keep the existing seed shape and rely on the backfill migration to clean up the live demo separately.
- **OQ4:** Does the Bed Maintenance UI (issue #101) need to wait for this change to ship first, or can the two be developed in parallel? The UI reads from the reconciled values, so it's safer to ship after this fix. But the UI is read-only (it doesn't write `beds_on_hold` directly), so theoretically it could ship in parallel. Recommend serializing — bed-hold-integrity first, Bed Maintenance UI second, both shipped in the same release window if possible.
