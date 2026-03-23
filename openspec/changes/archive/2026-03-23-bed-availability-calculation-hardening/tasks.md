## 1. Branch Setup

- [x] 1.1 Ensure on main branch in code repo (finding-a-bed-tonight): `git checkout main && git pull`
- [x] 1.2 Create branch `fix/bed-availability-hardening` from main: `git checkout -b fix/bed-availability-hardening`

## 2. Characterize Current Bugs (find before fix)

- [x] 2.1 Run each TC from Groups 1-2 against current code via API calls. Document actual vs expected behavior for: TC-1.1 through TC-1.9, TC-2.1 through TC-2.8
- [x] 2.2 Characterize TC-2.7 specifically: does coordinator PATCH with `bedsOnHold=0` overwrite active reservation holds? Document the exact behavior
- [x] 2.3 Characterize TC-3.2: fire two simultaneous reservation holds on last available bed. Document whether double-hold occurs
- [x] 2.4 Characterize TC-6.2: can the coordinator UI manually set `beds_on_hold`? Document what the UI sends to the API
- [x] 2.5 Verify timestamp precision: check `snapshot_ts` column type and Java layer — is it microsecond or truncated?
- [x] 2.6 Document all findings in a characterization summary before proceeding to fixes

## 3. Server-Side Invariant Validation

- [x] 3.1 Add validation in `AvailabilityService.createSnapshot()`: reject if `bedsTotal < 0`, `bedsOccupied < 0`, `bedsOnHold < 0` (INV-4)
- [x] 3.2 Add validation: reject if `bedsOccupied > bedsTotal` (INV-2) — return 422 with message "beds_occupied cannot exceed beds_total"
- [x] 3.3 Add validation: reject if `bedsOccupied + bedsOnHold > bedsTotal` (INV-5) — return 422 with message "occupied + on_hold cannot exceed total"
- [x] 3.4 Add custom exception class `AvailabilityInvariantViolation` (extends `IllegalArgumentException`) for clear error handling
- [x] 3.5 Add exception handler in `AvailabilityController` (or global handler) to return 422 with structured error body for invariant violations

## 4. Coordinator Hold Protection

- [x] 4.1 In `AvailabilityController.updateAvailability()`: query active HELD reservation count for this shelter + population type
- [x] 4.2 If request `bedsOnHold` < active held count, override to active held count. Log warning: "Coordinator beds_on_hold overridden from X to Y due to active reservations"
- [x] 4.3 If request `bedsOnHold` is null/absent, default to active held count (not 0)
- [x] 4.4 After override, re-validate invariants (the overridden hold count may now violate INV-5 with the submitted total — if so, reject with 422)

## 5. Concurrent Hold Protection

- [x] 5.1 In `ReservationService.createReservation()`: after inserting the new availability snapshot with `bedsOnHold + 1`, re-read the latest snapshot and verify `bedsAvailable >= 0`
- [x] 5.2 If `bedsAvailable < 0` after insert (concurrent race lost), delete the snapshot and return 409 Conflict
- [x] 5.3 Write a concurrent integration test: two threads simultaneously create reservations against 1 available bed. Assert exactly 1 succeeds, exactly 1 fails, `bedsAvailable == 0` (not -1)

## 6. UI Stepper Bounds

- [x] 6.1 In `CoordinatorDashboard.tsx` `updateAvailField()`: cap occupied at `bedsTotal - bedsOnHold` when incrementing
- [x] 6.2 Cap on-hold at `bedsTotal - bedsOccupied` when incrementing
- [x] 6.3 Disable on-hold stepper (or show read-only) when active HELD reservations exist — fetch reservation count on shelter expand
- [x] 6.4 After `saveShelter()` (capacity save), call `fetchShelters()` to refresh the collapsed card badges

## 7. AvailabilityInvariantChecker Test Utility

- [x] 7.1 Create `AvailabilityInvariantChecker.java` in test sources: reads latest snapshot + active reservation count for a shelter/population type
- [x] 7.2 Asserts INV-1 through INV-9 with detailed failure messages including: shelter ID, population type, snapshot_ts, beds_total, beds_occupied, beds_on_hold, computed beds_available, active reservation count
- [x] 7.3 Callable from any integration test: `AvailabilityInvariantChecker.assertInvariantsHold(jdbcTemplate, shelterId, populationType)`

## 8. Integration Tests — Group 1: Baseline Coordinator Updates

- [x] 8.1 TC-1.1: Initial snapshot, verify beds_available = total - occupied - hold
- [x] 8.2 TC-1.2: Increase occupied, verify available decreases
- [x] 8.3 TC-1.3: Decrease occupied, verify available increases
- [x] 8.4 TC-1.4: Increase total, verify available increases
- [x] 8.5 TC-1.5: Decrease total (above occupied), verify available decreases
- [x] 8.6 TC-1.6: Decrease total below occupied → verify 422 rejection
- [x] 8.7 TC-1.7: Decrease total below occupied+hold → verify 422 rejection
- [x] 8.8 TC-1.8: All zeros → verify accepted, available=0
- [x] 8.9 TC-1.9: Rapid sequential updates → verify each snapshot correct, timestamp microsecond precision
- [x] 8.10 After each test case, call `AvailabilityInvariantChecker.assertInvariantsHold()`

## 9. Integration Tests — Group 2: Reservation Interactions

- [x] 9.1 TC-2.1: Hold placed → available decreases by 1, hold increases by 1
- [x] 9.2 TC-2.2: Hold confirmed → available unchanged (INV-6), occupied+1, hold-1
- [x] 9.3 TC-2.3: Hold cancelled → available increases by 1 (INV-7)
- [x] 9.4 TC-2.4: Hold expired → available increases by 1 (INV-7)
- [x] 9.5 TC-2.5: Hold on last bed → available=0, no further holds
- [x] 9.6 TC-2.6: Hold when available=0 → 409 Conflict
- [x] 9.7 TC-2.7: Coordinator update while hold exists → hold count preserved, not zeroed
- [x] 9.8 TC-2.8: Coordinator reduces total while holds exist → 422 if invariant violated
- [x] 9.9 After each test case, call `AvailabilityInvariantChecker.assertInvariantsHold()`

## 10. Integration Tests — Group 3: Concurrent Operations

- [x] 10.1 TC-3.2: Two simultaneous holds on last bed → exactly 1 success, 1 failure, available=0
- [x] 10.2 TC-3.5: Three simultaneous holds on 2 available beds → exactly 2 success, 1 failure, available=0
- [x] 10.3 TC-3.1: Two concurrent coordinator updates → latest snapshot wins, no invalid state
- [x] 10.4 TC-3.3: Coordinator update races with hold → no invariant violations
- [x] 10.5 TC-3.4: Simultaneous hold and confirm → correct final state

## 11. Integration Tests — Groups 4-6: Cache, Edge Cases, UI Consistency

- [x] 11.1 TC-4.1: Cache invalidated synchronously — GET immediately after PATCH returns updated value
- [x] 11.2 TC-4.2: 10 rapid GETs after update all return correct value
- [x] 11.3 TC-4.3: Bed search reflects update immediately
- [x] 11.4 TC-5.1: New shelter with no snapshot → no error, clear "no data" indicator
- [x] 11.5 TC-5.3: Hold for wrong population type → 409, other population unaffected
- [x] 11.6 TC-5.4: Overflow beds during surge → regular available + overflow separate
- [x] 11.7 TC-6.1: Coordinator form pre-populates from latest snapshot (not stale cache)
- [x] 11.8 TC-6.3: Search results consistent with shelter detail (same available from both endpoints)

## 12. Phase 2: Flyway Migration V20 — Drop shelter_capacity

- [x] 12.1 Create `V20__drop_shelter_capacity.sql`: for each `(shelter_id, population_type)` in `shelter_capacity` with no corresponding `bed_availability` row, INSERT a snapshot with `beds_total` from capacity, `beds_occupied=0, beds_on_hold=0, snapshot_ts=NOW()`
- [x] 12.2 In V20: DROP POLICY IF EXISTS `dv_shelter_capacity_access` ON `shelter_capacity`
- [x] 12.3 In V20: DROP TABLE `shelter_capacity`
- [x] 12.4 Verified: V20 migration ran clean — shelter_capacity dropped, Flyway shows V20 as latest, all seed data intact in bed_availability

## 13. Phase 2: Delete Shelter Capacity Java Files

- [x] 13.1 Delete `ShelterCapacity.java` (domain class)
- [x] 13.2 Refactor `ShelterCapacityDto.java` (API DTO) — kept as pure API shape, removed domain backing
- [x] 13.3 Delete `ShelterCapacityRepository.java` (repository)
- [x] 13.4 Fix all compilation errors from deleted classes (tracked in subsequent tasks)

## 14. Phase 2: Refactor ShelterService — Capacity via Availability

- [x] 14.1 Remove `ShelterCapacityRepository` field and constructor injection from `ShelterService`
- [x] 14.2 Add `AvailabilityService` injection to `ShelterService` (with @Lazy to break circular dep)
- [x] 14.3 Refactor `create()`: instead of `capacityRepository.save()`, call `availabilityService.createSnapshot()` with `beds_total=bedsTotal, beds_occupied=0, beds_on_hold=0` for each capacity entry
- [x] 14.4 Refactor `update()`: instead of delete+re-insert capacity rows, for each capacity entry read latest snapshot (to preserve occupied/onHold), then write new snapshot with updated `beds_total`
- [x] 14.5 Refactor `delete()`: remove `capacityRepository.deleteByShelterId()` call (cascade on shelter handles availability cleanup, or availability rows are retained as historical data)
- [x] 14.6 Refactor `getDetail()`: replace `capacityRepository.findByShelterId()` with `availabilityService` query to get latest snapshot per population type; build `ShelterDetail.capacities` from snapshot data
- [x] 14.7 Update `ShelterDetail` record: change `capacities` type from `List<ShelterCapacity>` to `List<CapacityFromAvailability>` with `populationType` + `bedsTotal` fields

## 15. Phase 2: Refactor ShelterController and Response DTOs

- [x] 15.1 Update `ShelterDetailResponse.from()`: populate `capacities` list from availability-derived data instead of `ShelterCapacity` objects
- [x] 15.2 Keep `CreateShelterRequest.capacities` and `UpdateShelterRequest.capacities` fields — semantics change but field shape stays the same (populationType + bedsTotal)
- [x] 15.3 Verify `ShelterController` create/update/get endpoints compile and work with refactored `ShelterService`

## 16. Phase 2: Refactor Data Import and HSDS Export

- [x] 16.1 Refactor `ShelterImportService`: no changes needed — passes capacities through ShelterService which now routes to AvailabilityService
- [x] 16.2 Refactor `ShelterHsdsMapper`: updated to use `CapacityFromAvailability` record accessors instead of `ShelterCapacity` getters
- [x] 16.3 Import/export integration tests pass (ImportIntegrationTest: 7/7, ShelterIntegrationTest: 11/11)

## 17. Phase 2: Refactor Seed Data

- [x] 17.1 In `seed-data.sql`: removed `INSERT INTO shelter_capacity` block — `bed_availability` rows already contain correct `beds_total` values
- [x] 17.2 Verified: all `bed_availability` seed rows have `beds_total` matching former `shelter_capacity` values — no desync
- [x] 17.3 No duplicate rows — single `bed_availability` INSERT block is the sole source of truth

## 18. Phase 2: Refactor Frontend — Unified Bed Editing

- [x] 18.1 In `CoordinatorDashboard.tsx`: removed separate capacity section, moved total beds stepper into unified availability section
- [x] 18.2 Removed `editCapacities` state, `saveShelter()`, `adjustCount()`, `ShelterCapacity` interface, `savedId` state
- [x] 18.3 `submitAvailability()` already sends `bedsTotal` — no change needed
- [x] 18.4 `updateAvailField()` now handles `bedsTotal` field — auto-clamps occupied/onHold when total decreases
- [x] 18.5 In `ShelterForm.tsx`: no change needed — sends capacities in POST which backend routes to availability snapshots
- [x] 18.6 In `OutreachSearch.tsx`: no change needed — `ShelterCapacity` interface matches unchanged API response shape
- [x] 18.7 No i18n changes needed — existing `coord.bedsTotal` label reused in unified availability section

## 19. Phase 2: Refactor Karate and Integration Tests

- [x] 19.1 `shelter-crud.feature`: no change needed — API response shape for `capacities` is unchanged, assertions pass
- [x] 19.2 Added TC-7.1: create shelter with capacity → GET detail → verify capacity comes from `bed_availability` snapshot
- [x] 19.3 Added TC-7.2: update shelter capacity → verify new snapshot with updated `beds_total`, preserved `beds_occupied`/`beds_on_hold`
- [x] 19.4 Added TC-7.3: verify capacity and availability `beds_total` always in sync (the bug that was found)
- [x] 19.5 No test references `shelter_capacity` table directly — no changes needed

## 20. Phase 2: Update Documentation

- [x] 20.1 Updated `schema.dbml`: removed `shelter_capacity` table, added note about V20 drop, added D10 note to `bed_availability`
- [x] 20.2 Updated runbook: added "Bed Availability Invariants" section with 9 rules table, enforcement details, and investigation guide
- [x] 20.3 Updated code repo README: V20 migration in table, V6 marked as dropped, migration count updated
- [x] 20.4 Updated code repo README Project Status: added "Completed: Bed Availability Calculation Hardening"
- [x] 20.5 Docs repo README: no changes needed — no `shelter_capacity` references

## 21. Playwright Tests — UI Verification (post-refactor)

- [x] 21.1 Rewrote both Playwright test files to use `data-testid` locators — layout-independent, survives refactors
- [x] 21.2 `coordinator-beds.spec.ts`: occupied stepper cannot produce negative available (verified via data-testid)
- [x] 21.3 `coordinator-beds.spec.ts`: on-hold is read-only — asserts no `onhold-plus-`/`onhold-minus-` test IDs exist
- [x] 21.4 `coordinator-availability-math.spec.ts`: on page load, verifies `available == total - occupied - onHold` for every shelter
- [x] 21.5 `coordinator-beds.spec.ts`: save and reload — all values consistent (via data-testid)
- [x] 21.6 `coordinator-beds.spec.ts`: negative available never displayed (stepper bounds prevent it)

## 22. Full Regression and PR

- [x] 22.1 Run full backend test suite: 179 tests, 0 failures (including 27 hardening + 3 new D10 tests)
- [x] 22.2 Fixed: AvailabilityIntegrationTest used positional `availability[0]` (now finds by populationType); fixed TC-3.5 flakiness (NOW()→clock_timestamp() for distinct snapshot_ts in serialized transactions)
- [x] 22.3 Playwright suite: 62 passed, 0 failed (including data-testid refactored coordinator tests)
- [x] 22.4 Karate suite: 32/32 passed (ObservabilityRunnerTest skipped — requires `--observability` stack)
- [x] 22.5 Gatling: 3 simulations (AvailabilityUpdate, BedSearch, SurgeLoad), 0 KO, 42ms p99
- [x] 22.6 Committed: 28 files changed, 2094 insertions, 661 deletions
- [x] 22.7 Pushed branch, created PR #5 with full test plan
- [x] 22.8 CI — no CI configured, tests verified locally across all suites
- [x] 22.9 Merged PR #5 to main (2026-03-23T12:47:52Z)
- [x] 22.10 Deleted feature branch (local + origin)
- [x] 22.11 Tagged v0.9.2, pushed to origin
