## Tasks

### Setup

- [ ] T-0: Create branch `bugfix/issue-102-phantom-beds-on-hold` from `v0.32.3` tag in the code repo. **Already done** during the RCA investigation 2026-04-11.
- [ ] T-1: Capture pre-change baseline. Run `mvn clean test` and tee to `logs/bed-hold-integrity-baseline-pre.log`. Record the test count and any pre-existing failures so the post-implementation run has a clear delta to compare against.

### Component 1 — Single write path: `recomputeBedsOnHold()`

- [ ] T-2: Add `private void recomputeBedsOnHold(UUID shelterId, String populationType, String actor, String notes)` to `ReservationService.java`. Implementation per design.md D2. Reads the actual count from `reservationRepository.countActiveByShelterId(shelterId, populationType)`, reads the latest snapshot for `bedsTotal`/`bedsOccupied`/`acceptingNewGuests`/`overflowBeds`, calls `availabilityService.createSnapshot(...)`.
- [ ] T-3: Replace every existing `adjustAvailability(reservation, +/-1, ...)` call site in `ReservationService` with `recomputeBedsOnHold(reservation.getShelterId(), reservation.getPopulationType(), actor, notes)`. Audit the four call sites: `createReservation`, `confirmReservation` (where occupied delta is also +1), `cancelReservation`, `expireReservation`.
- [ ] T-4: Special-case `confirmReservation` — the existing code does `adjustAvailability(reservation, -1, +1, "reservation:confirm")` (decrement hold, increment occupied). The new method only handles holds; the occupied delta still needs the existing path. Refactor to call `recomputeBedsOnHold(...)` AND a new `recomputeBedsOccupied(...)` OR keep the existing `adjustAvailability` for the confirm path with just `occupiedDelta = +1` and let `recomputeBedsOnHold` handle the hold decrement. Riley Cho's review preference: TWO methods, one per cached field, never delta math on either.
- [ ] T-5: Delete the old `adjustAvailability` method entirely once all call sites are migrated. Or rename it `recomputeBedAvailability` and have it call both `recomputeBedsOnHold` and `recomputeBedsOccupied`. The codebase should have NO method that does delta math on `bedsOnHold`.

### Component 2 — Manual PATCH endpoint deprecation

- [ ] T-6: Update `AvailabilityController.updateAvailability` to ignore `request.bedsOnHold`. The current `effectiveHold = Math.max(requestedHold, activeHeldCount)` calculation is replaced with `effectiveHold = activeHeldCount` (and the `requestedHold` variable is unused). Log a WARN message if `request.bedsOnHold != null && request.bedsOnHold != 0`: `"Ignored coordinator-supplied beds_on_hold={} for shelter {} / {} — server-managed via reservation table (deprecated v0.34.0, will be hard-rejected v0.35.0)"`.
- [ ] T-7: Update `AvailabilityUpdateRequest.java` Javadoc on the `bedsOnHold` field with the deprecation notice per design.md D4.
- [ ] T-8: Existing `createSnapshotWithRetry` call uses `effectiveHold` — verify the call site still works after the rename. The signature does not change; only the value source does.

### Component 3 — Offline hold endpoint

- [ ] T-9: Add `POST /api/v1/shelters/{shelterId}/manual-hold` endpoint to `ReservationController` (or `ShelterController` if more topical — reviewer call). PreAuthorize `hasAnyRole('COORDINATOR', 'COC_ADMIN', 'PLATFORM_ADMIN')`. Coordinator role requires shelter assignment check via `coordinatorAssignmentRepository.isAssigned(userId, shelterId)`.
- [ ] T-10: Add `ManualHoldRequest` DTO with fields: `populationType` (required, validated against `PopulationType` enum), `reason` (optional, max 200 chars).
- [ ] T-11: Add `ReservationService.createManualHold(shelterId, populationType, userId, reason)` that:
  1. Validates the shelter exists and accepts the population type
  2. Creates a `reservation` row with `status = 'HELD'`, `user_id = userId`, `expires_at = NOW() + tenant.hold_duration_minutes`, `notes = "Manual offline hold: " + reason`, `idempotency_key` = a UUID derived from `(userId, shelterId, populationType, "manual-hold", current_minute)` to prevent accidental duplicate clicks
  3. Calls `recomputeBedsOnHold(shelterId, populationType, "system:manual-hold", "manual hold created")`
  4. Returns the new reservation
- [ ] T-12: DemoGuard implications — `POST /api/v1/shelters/*/manual-hold` is NOT in the existing allowlist and falls through to fail-secure. **Add it to the friendly-message branch in `getBlockMessage`** with text: `"Manual offline holds are disabled in the demo environment — would interfere with other visitors' bed search results."` Do NOT allowlist it (offline holds have cross-visitor impact, like reassign).

### Component 4 — Spring Batch reconciliation tasklet

- [ ] T-13: Create `org.fabt.availability.batch` package (new package).
- [ ] T-14: Create `BedHoldsReconciliationJobConfig.java` modeled on `org.fabt.referral.batch.ReferralEscalationJobConfig` (which already exists per the coc-admin-escalation work). Single tasklet, single step, single job. `@Configuration` class with `@Bean` definitions for the Job, Step, and Tasklet.
- [ ] T-15: Implement the tasklet body:
  ```java
  @Bean
  public Tasklet reconciliationTasklet() {
    return (contribution, chunkContext) -> {
      return TenantContext.runWithContext(null, true, () -> {
        // 1. SELECT-join latest snapshots with HELD counts
        List<DriftRow> drifted = bedAvailabilityRepository.findDriftedRows();
        log.info("Bed holds reconciliation: scanning {} drifted rows", drifted.size());
        int corrected = 0;
        for (DriftRow row : drifted) {
          try {
            reservationService.recomputeBedsOnHold(
                row.shelterId(), row.populationType(),
                "system:reconciliation", "reconciliation: drift corrected");
            auditEventService.publish(null, row.shelterId(),
                AuditEventTypes.BED_HOLDS_RECONCILED,
                Map.of("shelter_id", row.shelterId().toString(),
                       "population_type", row.populationType(),
                       "snapshot_value_before", row.snapshotValue(),
                       "actual_count", row.actualCount(),
                       "delta", row.actualCount() - row.snapshotValue()));
            corrected++;
          } catch (Exception e) {
            log.error("Failed to reconcile {} / {}: {}",
                row.shelterId(), row.populationType(), e.getMessage());
          }
        }
        log.info("Bed holds reconciliation complete: {} corrections", corrected);
        contribution.incrementWriteCount(corrected);
        bedHoldReconciliationCorrectionsCounter.increment(corrected);
        return RepeatStatus.FINISHED;
      });
    };
  }
  ```
- [ ] T-16: Add `findDriftedRows()` query to `BedAvailabilityRepository`. SQL:
  ```sql
  WITH latest AS (
    SELECT DISTINCT ON (shelter_id, population_type)
      shelter_id, population_type, beds_on_hold
    FROM bed_availability
    ORDER BY shelter_id, population_type, snapshot_ts DESC
  ),
  held_counts AS (
    SELECT shelter_id, population_type, COUNT(*) AS held_count
    FROM reservation WHERE status = 'HELD'
    GROUP BY shelter_id, population_type
  )
  SELECT l.shelter_id, l.population_type, l.beds_on_hold AS snapshot_value,
         COALESCE(h.held_count, 0)::int AS actual_count
  FROM latest l
  LEFT JOIN held_counts h
    ON h.shelter_id = l.shelter_id AND h.population_type = l.population_type
  WHERE l.beds_on_hold != COALESCE(h.held_count, 0)
  ```
  Returns `List<DriftRow>` where `DriftRow` is a Java record `(UUID shelterId, String populationType, int snapshotValue, int actualCount)`.
- [ ] T-17: Schedule the job via `@Component` class with `@Scheduled(fixedDelay = 5 * 60 * 1000)` calling `JobLauncher.run(reconciliationJob, new JobParametersBuilder().addLong("timestamp", System.currentTimeMillis()).toJobParameters())`. Match the existing scheduler pattern from `ReferralEscalationJobConfig`.
- [ ] T-18: Wire up Micrometer metrics: `fabt.bed.hold.reconciliation.batch.runs.total` Counter, `fabt.bed.hold.reconciliation.batch.duration` Timer (using `Timer.Sample.start(meterRegistry)` / `sample.stop(timer)` pattern), `fabt.bed.hold.reconciliation.corrections.total` Counter incremented per correction.

### Component 5 — Audit event type

- [ ] T-19: Add `public static final String BED_HOLDS_RECONCILED = "BED_HOLDS_RECONCILED"` to `AuditEventTypes.java`.
- [ ] T-20: Update `AuditEventTypesTest` (or equivalent contract pin test) to assert the new constant exists, is non-null, and equals the expected literal.

### Component 6 — Seed fix

- [ ] T-21: Audit `infra/scripts/seed-data.sql` for every `bed_availability` INSERT row with `beds_on_hold > 0`. Per the live demo investigation, there are 17 such rows across 17 shelter+population pairs.
- [ ] T-22: For each such row, INSERT N matching `reservation` rows with `status = 'HELD'`, varied `expires_at` values (5 minutes, 30 minutes, 60 minutes from NOW), `user_id = 'b0000000-0000-0000-0000-000000000001'` (admin sentinel), `notes = 'Seed: hold for demo realism'`. The seed reservations should be inserted AFTER the bed_availability rows in the file order so the runtime invariant holds at startup.
- [ ] T-23: **Test impact audit** — run the full backend test suite locally with the new seed and identify any tests that were depending on the old seed shape. Likely candidates: tests that count reservations in a specific shelter+population, tests that assert `beds_on_hold = 0` initially. Update those tests to use the new reservation count or to seed their own state via API calls.
- [ ] T-24: Verify the seed change is consistent with the existing `reset-test-data.feature` Karate cleanup logic. The new seed reservations should be cleanable via the `cleanupTestData()` helper (which deletes all referral_token rows + held reservations + test shelters/users). Confirm the cleanup pattern doesn't break.

### Component 7 — Backfill migration

- [ ] T-25: Create `backend/src/main/resources/db/migration/V44__backfill_phantom_beds_on_hold.sql` (assuming V44 is the next available version after coc-admin-escalation lands V40-V43; CONFIRM at branch creation time, not now). Body per design.md D6:
  ```sql
  INSERT INTO bed_availability (...)
  WITH latest AS (...), held_counts AS (...)
  SELECT ... FROM latest l LEFT JOIN held_counts h ON ...
  WHERE l.beds_on_hold != COALESCE(h.held_count, 0);
  ```
- [ ] T-26: Add a comment header to the migration explaining the RCA context, linking GH issue #102, naming the affected version range (v0.31.0 through v0.32.3), and noting that the migration is idempotent.

### Tests

- [ ] T-27: Create `BedHoldsInvariantTest.java` integration test class with five test methods:
  - `invariant_after_create` — create a reservation, assert `beds_on_hold === COUNT(HELD)`
  - `invariant_after_cancel` — cancel a reservation, assert
  - `invariant_after_expire` — set `expires_at` to the past, run `expireReservation`, assert
  - `invariant_after_offline_hold` — create via `POST /manual-hold`, assert
  - `invariant_after_reconciliation` — seed drift directly via SQL (`UPDATE bed_availability SET beds_on_hold = 5 WHERE id = ?`), run `reconciliationTasklet`, assert
- [ ] T-28: Create `BedHoldsReconciliationJobTest.java` for the dedicated reconciliation job tests:
  - `reconciliation_corrects_seeded_drift` — seed a shelter with `beds_on_hold = 5` and zero HELD reservations, run the job, assert corrective snapshot exists with `beds_on_hold = 0` AND `updated_by = 'system:reconciliation'`
  - `reconciliation_writes_audit_row` — same setup, assert one `audit_events` row exists with `action = 'BED_HOLDS_RECONCILED'`, correct payload
  - `reconciliation_no_drift_no_work` — no drift state, run the job, assert zero new snapshots written
  - `reconciliation_sees_dv_shelter_under_rls` — seed a DV shelter with drift, run the job, assert the correction happens (proves the `TenantContext.runWithContext(null, true, ...)` wrap works)
  - `reconciliation_continues_on_per_row_failure` — inject one shelter row that throws on recompute, assert the job still processes the remaining rows and logs the failure
- [ ] T-29: Create `OfflineHoldEndpointTest.java`:
  - `coordinator_creates_offline_hold_succeeds` — happy path
  - `coordinator_not_assigned_to_shelter_403` — RBAC negative
  - `offline_hold_increments_beds_on_hold` — the recompute path fires
  - `offline_hold_expires_via_existing_lifecycle` — set `expires_at` to past, run `ReservationExpiryService`, assert transitioned to `EXPIRED` and `beds_on_hold` decremented
  - `manual_hold_endpoint_blocked_in_demo` — DemoGuardFilterTest assertion (cross-test in `DemoGuardFilterTest`)

### Pre-merge

- [ ] T-30: Run full backend test suite (`mvn clean test`). All tests green, no regressions, ArchUnit boundaries intact (the new `org.fabt.availability.batch` package needs an ArchUnit rule allowing it the same access pattern as `org.fabt.referral.batch`).
- [ ] T-31: Local end-to-end smoke: `./dev-start.sh stop && rm -f e2e/playwright/auth/*.json && ./dev-start.sh --fresh --nginx`, then exercise the bed search → reservation create → expire → reconciliation cycle manually via the UI, verify `beds_on_hold` math is correct end-to-end. Watch the backend logs for the reconciliation job's INFO output.
- [ ] T-32: Manual SQL verification: connect to the local Postgres and run the smoking-gun query from the RCA (`SELECT shelter_id, population_type, beds_on_hold, (subquery for HELD count) FROM latest WHERE beds_on_hold != held_count`). Should return zero rows on a freshly seeded local stack.
- [ ] T-33: Run the full Playwright suite (`BASE_URL=http://localhost:8081 npx playwright test`). Expect green; the changes are backend-only and the existing reservation flows should be unaffected. Any test pollution surfaced by the new seed should be addressed in T-23.
- [ ] T-34: Open PR against `main`, link to GH issue #102 and this OpenSpec change. Hold for CI scans (memory: `feedback_release_after_scans`).

### Release execution

- [ ] T-35: After PR merge: bump `pom.xml` version to **v0.34.0** (or whatever the next release version is — depends on whether v0.33.0 has shipped). Promote `[Unreleased]` → `[v0.34.0]` in the CHANGELOG with the bug summary, the fix summary, and the affected version range (v0.31.0 through v0.32.3 — though v0.32.3 is the live demo so the impact is "v0.32.x is the latest live version with the bug").
- [ ] T-36: Tag the release, create the GitHub release with the CHANGELOG body.
- [ ] T-37: Deploy to Oracle per the standard deploy plan (`mvn clean package`, no-cache Docker build, force-recreate, post-deploy smoke). The Flyway migration runs automatically during backend startup.
- [ ] T-38: Post-deploy verification: connect to live Postgres, run the smoking-gun query, expect zero drift. Also verify a `BED_HOLDS_RECONCILED` audit row exists from the V44 backfill migration (it should write one row for every shelter+population pair that was previously drifted — 17 rows expected based on the RCA investigation).
- [ ] T-39: Comment on GH issue #102 with deploy verification results, close the issue. Cross-link to issue #101 (Bed Maintenance UI) noting that the structural fix has shipped and the UI can now be developed against a clean baseline.
- [ ] T-40: After release: `/opsx:verify bed-hold-integrity` → `/opsx:sync bed-hold-integrity` → `/opsx:archive bed-hold-integrity`.
