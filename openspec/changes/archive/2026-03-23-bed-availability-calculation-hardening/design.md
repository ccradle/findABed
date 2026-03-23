## Context

The bed availability calculation (`beds_available = beds_total - beds_occupied - beds_on_hold`) is derived, never stored. Three operations modify it: coordinator updates (PATCH availability), reservation holds (POST reservation), and reservation transitions (confirm/cancel/expire). The QA briefing (bed-availability-qa-briefing.md) defines 9 invariants and 30+ test cases across 6 groups. Current implementation has no server-side validation — any values are accepted and written as a snapshot.

## Goals / Non-Goals

**Goals:**
- Enforce all 9 invariants from the QA briefing at the application layer
- Prevent negative bed availability under all operation sequences
- Prevent coordinator updates from silently overwriting active reservation holds
- Characterize and fix concurrent operation race conditions
- Comprehensive test suite covering all QA test cases (Groups 1-6)
- Zero false confidence — tests must fail against unfixed logic
- Eliminate dual source of truth: `beds_total` must exist in exactly one place (`bed_availability`)
- Every code path that reads or writes `beds_total` must use `bed_availability` snapshots

**Non-Goals:**
- Performance optimization of the availability query
- Changing the append-only snapshot model (it works — the problem was the second table)

## Decisions

### D1: Branch strategy

All changes on branch `fix/bed-availability-hardening` created from main in the code repo. The docs repo continues on main. PR to main after full test suite passes.

### D2: Server-side invariant enforcement

Add validation in `AvailabilityService.createSnapshot()` before inserting the snapshot:

```
if (bedsTotal < 0) → reject 422 "beds_total cannot be negative" (INV-4)
if (bedsOccupied < 0) → reject 422 "beds_occupied cannot be negative"
if (bedsOnHold < 0) → reject 422 "beds_on_hold cannot be negative"
if (bedsOccupied > bedsTotal) → reject 422 "beds_occupied cannot exceed beds_total" (INV-2)
if (bedsOccupied + bedsOnHold > bedsTotal) → reject 422 "occupied + on_hold cannot exceed total" (INV-5)
```

Return 422 Unprocessable Entity with a clear error message. The coordinator must adjust values to satisfy invariants (e.g., reduce occupied before reducing total).

### D3: Coordinator hold protection

When a coordinator submits a PATCH availability update, the system must ensure `beds_on_hold` is not reduced below the count of active HELD reservations for that shelter/population type.

In `AvailabilityController.updateAvailability()`:
1. Query active HELD reservation count for this shelter + population type
2. If request `bedsOnHold < activeHeldCount`, override to `activeHeldCount` (don't reject — the coordinator may not know about holds)
3. Log a warning when override occurs

Alternative considered: reject the request. Rejected because the coordinator shouldn't need to know the exact hold count to update occupied beds.

### D4: UI stepper bounds

In `CoordinatorDashboard.tsx`:
- `updateAvailField('bedsOccupied', +1)`: cap at `bedsTotal - bedsOnHold` (cannot occupy a held bed)
- `updateAvailField('bedsOnHold', +1)`: cap at `bedsTotal - bedsOccupied` (cannot hold an occupied bed)
- The `bedsOnHold` stepper should be **read-only** (or disabled) when active reservations exist — holds are system-managed, not coordinator-managed
- The `−` button on both steppers is already capped at 0

### D5: Concurrent hold protection (TC-3.2)

The current `ReservationService.createReservation()` reads the latest snapshot, checks `bedsAvailable > 0`, and creates a new snapshot with `bedsOnHold + 1`. Two concurrent requests can both read `bedsAvailable=1` and both succeed.

Fix: Use `SELECT ... FOR UPDATE` on the latest snapshot row, or use the existing `ON CONFLICT ON CONSTRAINT uq_bed_avail_shelter_pop_ts DO NOTHING` mechanism — if two inserts race with identical timestamps, one is silently dropped. But this relies on timestamp collision which is microsecond-unlikely.

Better fix: Add a check after inserting the snapshot — re-read the latest and verify `bedsAvailable >= 0`. If violated, delete the snapshot and return 409. This is an optimistic concurrency approach.

### D6: Timestamp precision (TC-1.9, TC-3.1)

Verify that `snapshot_ts` has microsecond precision (PostgreSQL `TIMESTAMPTZ` default). Check that the Java layer (JDBC, Spring Data) does not truncate to milliseconds or seconds. If truncation occurs, two rapid updates could have identical timestamps, making `DISTINCT ON` non-deterministic.

### D7: AvailabilityInvariantChecker test utility

Create a reusable test utility that verifies all 9 invariants hold for a given shelter after any operation. Callable from any integration test:

```java
AvailabilityInvariantChecker.assertInvariantsHold(shelterId, populationType);
```

Checks INV-1 through INV-9 by reading the latest snapshot and active reservation count. Provides detailed failure messages including snapshot state and reservation state.

### D8: Cache invalidation verification

After every availability write (coordinator update, hold, confirm, cancel, expire):
- The PATCH/POST response must return the correct updated values
- An immediate GET must return the same values (no stale cache)
- A bed search query must reflect the update

Test with rapid GET after write — zero tolerance for stale reads after synchronous invalidation.

### D9: Shelf list badge refresh after capacity save

`saveShelter()` in `CoordinatorDashboard.tsx` must call `fetchShelters()` after success to refresh the "X avail" badge on collapsed cards.

### D10: Single source of truth — eliminate `shelter_capacity.beds_total`

**Problem**: `shelter_capacity.beds_total` and `bed_availability.beds_total` are independent values for the same concept. The UI reads total from `shelter_capacity` but computes available from `bed_availability`, producing wrong numbers when they diverge. There is no mechanism to keep them in sync.

**Decision**: Make `bed_availability` the single source of truth for `beds_total`. Drop the `shelter_capacity` table entirely. All capacity changes write a new `bed_availability` snapshot.

**Alternatives considered**:
- Option B (sync on write): Keep both tables, enforce sync. Rejected — still two sources, sync could break.
- Option C (DB trigger): Auto-create snapshot when capacity changes. Rejected — hidden write side-effects.
- Option D (computed view): Replace shelter_capacity with a view on bed_availability. Rejected — unnecessary indirection.

**Migration strategy (V20)**:
1. For each `(shelter_id, population_type)` in `shelter_capacity` that has NO corresponding row in `bed_availability`: insert a `bed_availability` snapshot with `beds_total` from `shelter_capacity`, `beds_occupied=0`, `beds_on_hold=0`
2. For rows that already have `bed_availability` data: the latest snapshot already has `beds_total`, no migration needed
3. Drop the `shelter_capacity` table and its RLS policy

**Refactor layers**:

| Layer | File | Change |
|-------|------|--------|
| Domain | `ShelterCapacity.java` | DELETE |
| DTO | `ShelterCapacityDto.java` | DELETE |
| Repository | `ShelterCapacityRepository.java` | DELETE |
| Service | `ShelterService.java` | Remove capacity CRUD. Capacity changes call `AvailabilityService.createSnapshot()` |
| Controller | `ShelterController.java` | GET detail: read capacity from latest `bed_availability` snapshot via `AvailabilityService`. Create/Update: delegate capacity to `AvailabilityService` |
| Response DTO | `ShelterDetailResponse.java` | Populate `capacities` from `bed_availability` snapshots instead of `shelter_capacity` rows |
| Request DTOs | `CreateShelterRequest.java`, `UpdateShelterRequest.java` | Keep `capacities` field — semantics change from "write to capacity table" to "write availability snapshot" |
| Import | `ShelterImportService.java` | `buildCapacities()` output feeds `AvailabilityService.createSnapshot()` instead of `ShelterCapacityRepository` |
| HSDS Export | `ShelterHsdsMapper.java` | Read capacity from `ShelterDetail.capacities` (now populated from bed_availability) — minimal change |
| Seed Data | `seed-data.sql` | Replace `shelter_capacity` INSERTs with `bed_availability` snapshot INSERTs |
| Schema Doc | `schema.dbml` | Remove `shelter_capacity` table definition |
| Migration | `V20__drop_shelter_capacity.sql` | Migrate data + drop table + drop RLS policy |
| Frontend | `CoordinatorDashboard.tsx` | Remove separate capacity editing section. Total beds stepper lives in the availability section. Single save writes one snapshot. |
| Frontend | `ShelterForm.tsx` | On shelter create, write initial capacity as `bed_availability` snapshot (via API) instead of `capacities` field |
| Frontend | `OutreachSearch.tsx` | Read capacity from availability data (API already returns this) |
| Karate | `shelter-crud.feature` | Update assertions: `response.capacities` still returned but populated from availability |

**Cross-module boundary**: `ShelterService` (shelter module) must call `AvailabilityService` (availability module). This is service-to-service, which ArchUnit allows. No repository cross-access.
