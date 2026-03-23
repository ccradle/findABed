## Why

The QA engineering team (Riley Cho, bed-availability-qa-briefing.md) identified that the core bed availability calculation — the most important number in the platform — has multiple correctness bugs. An outreach worker at midnight trusts `beds_available` to decide whether to drive across Raleigh with a family. If that number is wrong, a family arrives at a shelter that is full.

Confirmed bugs: the backend accepts snapshots where `beds_occupied > beds_total` (producing negative available), the UI steppers have no upper bounds, and coordinator updates can silently overwrite system-managed reservation holds. Concurrent operations (double-hold on last bed, simultaneous coordinator updates) have not been characterized but represent the highest-risk failure modes.

The goal is not to make tests pass. The goal is to find every situation in which the availability calculation produces a wrong answer, fix the underlying logic, and write tests that will catch any future regression.

## What Changes

### Phase 1 (complete): Invariant Enforcement
- **Server-side invariant validation**: `AvailabilityService.createSnapshot()` enforces 9 invariants — rejects snapshots that violate `beds_available >= 0`, `beds_occupied <= beds_total`, `beds_occupied + beds_on_hold <= beds_total`
- **Coordinator hold protection**: Coordinator availability PATCH cannot reduce `beds_on_hold` below the count of active HELD reservations for that shelter/population type
- **UI stepper bounds**: `bedsOccupied` capped at `bedsTotal`, `bedsOnHold` capped at `bedsTotal - bedsOccupied`, held beds shown read-only (system-managed)
- **Concurrent operation safety**: PostgreSQL advisory locks fix double-hold on last bed (TC-3.2), concurrent coordinator updates (TC-3.1), coordinator vs hold race (TC-3.3)
- **Comprehensive test suite**: Integration tests for QA test cases TC-1.1 through TC-6.3, including an `AvailabilityInvariantChecker` utility

### Phase 2 (new): Eliminate Dual Source of Truth
During testing, we discovered that `shelter_capacity.beds_total` and `bed_availability.beds_total` can diverge — the UI reads total from `shelter_capacity` but computes available from `bed_availability`, producing wrong numbers (e.g., total=20 displayed but available computed from beds_total=10 in the snapshot).

**Root cause**: Two independent tables store `beds_total`. The `shelter_capacity` table stores the "configured" capacity, while `bed_availability` snapshots store the operational capacity used in calculations. Nothing enforces they stay in sync.

**Fix (Option A — single source of truth)**: Eliminate `shelter_capacity.beds_total` entirely. Make `bed_availability` the sole owner of `beds_total`. All capacity changes write a new `bed_availability` snapshot instead of updating `shelter_capacity`. This is a structural refactor, not a patch.

- **Delete `shelter_capacity` table** via Flyway migration V20, after migrating any capacity-only data into `bed_availability` snapshots
- **Delete 3 Java files**: `ShelterCapacity.java`, `ShelterCapacityDto.java`, `ShelterCapacityRepository.java`
- **Refactor shelter CRUD**: `ShelterService`, `ShelterController`, `ShelterDetailResponse`, `CreateShelterRequest`, `UpdateShelterRequest` — capacity changes become snapshot writes via `AvailabilityService`
- **Refactor data import**: `ShelterImportService` converts imported capacities to `bed_availability` snapshots
- **Refactor HSDS export**: `ShelterHsdsMapper` reads capacity from latest `bed_availability` snapshot
- **Refactor UI**: `CoordinatorDashboard.tsx` merges capacity and availability editing into a single save flow; `ShelterForm.tsx` writes snapshots on shelter create; `OutreachSearch.tsx` reads capacity from availability data
- **Update seed data**: Replace `shelter_capacity` INSERTs with `bed_availability` snapshot INSERTs
- **Update Karate tests**: `shelter-crud.feature` — capacity assertions read from availability data
- **Update documentation**: `schema.dbml`, runbook, README

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `bed-availability-query`: Server-side invariant validation on snapshot creation; single source of truth for `beds_total`
- `bed-reservation`: Hold protection against coordinator override
- `shelter-availability-update`: UI stepper bounds enforcement, hold display; merged capacity/availability editing
- `shelter-management`: Capacity changes write availability snapshots instead of separate capacity table

## Impact

- **Deleted files**: `ShelterCapacity.java`, `ShelterCapacityDto.java`, `ShelterCapacityRepository.java`
- **Modified files (backend)**: `AvailabilityService.java`, `AvailabilityController.java`, `ReservationService.java`, `ShelterService.java`, `ShelterController.java`, `ShelterDetailResponse.java`, `CreateShelterRequest.java`, `UpdateShelterRequest.java`, `ShelterImportService.java`, `ShelterHsdsMapper.java`
- **Modified files (frontend)**: `CoordinatorDashboard.tsx`, `ShelterForm.tsx`, `OutreachSearch.tsx`
- **Modified files (data/config)**: `seed-data.sql`, `schema.dbml`
- **New files**: `V20__drop_shelter_capacity.sql` (Flyway migration), `AvailabilityInvariantChecker.java` (test utility), `BedAvailabilityHardeningTest.java` (integration tests), `coordinator-beds.spec.ts` (Playwright tests), `coordinator-availability-math.spec.ts` (Playwright math verification)
- **Database changes**: V20 migration drops `shelter_capacity` table and its RLS policy after migrating data to `bed_availability`
- **Risk**: Structural refactor touches shelter CRUD, import, export, and all UIs. Must be tested end-to-end.
- **Branch strategy**: All changes on `fix/bed-availability-hardening` branch from main, PR after full test suite passes
