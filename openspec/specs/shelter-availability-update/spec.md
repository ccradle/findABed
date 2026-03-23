## Purpose

Coordinator-facing availability update flow. Append-only snapshots with concurrent insert safety, cache invalidation, and event publishing.

## Requirements

### Requirement: availability-snapshot-create
The system SHALL allow shelter coordinators to submit availability updates via PATCH `/api/v1/shelters/{id}/availability`. Each update creates an append-only snapshot in the `bed_availability` table. The request body includes: `populationType` (required, one of the valid population type enums), `bedsTotal` (required, integer >= 0), `bedsOccupied` (required, integer >= 0), `bedsOnHold` (optional, integer >= 0, default 0), `acceptingNewGuests` (required, boolean), and `notes` (optional, varchar 500). The `beds_available` value is derived at query time as `beds_total - beds_occupied - beds_on_hold` and is never stored. On successful insert, the system invalidates L1 (Caffeine) and L2 (Redis) caches for the shelter synchronously before returning 200 OK, then publishes an `availability.updated` event to the EventBus. The coordinator must be assigned to the shelter. Update performance target: p95 < 200ms.

#### Scenario: Coordinator submits availability update
- **WHEN** a coordinator assigned to Shelter A sends PATCH `/api/v1/shelters/{id}/availability` with `{"populationType": "SINGLE_ADULT", "bedsTotal": 50, "bedsOccupied": 47, "bedsOnHold": 1, "acceptingNewGuests": true, "notes": "2 beds freed at 11pm shift change"}`
- **THEN** the system inserts a new row in `bed_availability` with `snapshot_ts` set to the current time
- **AND** the response is 200 OK with the snapshot including `beds_available: 2` (derived: 50 - 47 - 1)
- **AND** the coordinator's identity is recorded in the `updated_by` field

#### Scenario: Concurrent updates from same shelter
- **WHEN** two coordinators submit availability updates for the same shelter and population type at the same instant (identical `shelter_id`, `population_type`, `snapshot_ts`)
- **THEN** the system applies `ON CONFLICT DO NOTHING` so one insert succeeds and the duplicate is silently discarded
- **AND** no error is returned to either caller (both receive 200 OK)
- **AND** the resulting latest snapshot is consistent and queryable

#### Scenario: Cache invalidated before 200 returned
- **WHEN** a coordinator submits an availability update
- **THEN** the system invalidates the L1 (Caffeine) cache entry for the shelter before returning the response
- **AND** the system invalidates the L2 (Redis) cache entry for the shelter before returning the response
- **AND** subsequent queries for this shelter read fresh data from PostgreSQL (cache miss, then repopulate)

#### Scenario: availability.updated event published
- **WHEN** a coordinator submits an availability update and the snapshot is inserted successfully
- **THEN** the system publishes an `availability.updated` event to the EventBus after cache invalidation
- **AND** the event includes `shelter_id`, `tenant_id`, `population_type`, `beds_available`, `beds_available_previous`, `shelter_name`, `coc_id`, `snapshot_ts`, and `schema_version`

#### Scenario: Reservation creates availability snapshot
- **WHEN** a reservation is created, confirmed, cancelled, or expired
- **THEN** the system creates a new availability snapshot via AvailabilityService.createSnapshot() with the adjusted `beds_on_hold` and `beds_occupied` values
- **AND** the snapshot's `updated_by` field records the system actor (e.g., "reservation:create", "reservation:expire")
- **AND** cache invalidation and event publishing follow the same synchronous flow as coordinator updates

#### Scenario: Availability update with overflow beds
- **WHEN** a coordinator sends PATCH `/api/v1/shelters/{id}/availability` with `overflowBeds: 15`
- **THEN** the snapshot is created with `overflow_beds = 15`
- **AND** the `availability.updated` event payload includes `overflow_beds`

### Requirement: ui-stepper-bounds
The coordinator dashboard UI SHALL enforce bed count bounds on all steppers. Occupied cannot exceed total minus on-hold. On-hold cannot exceed total minus occupied. The `beds_on_hold` stepper is disabled (read-only) when active reservations exist — holds are system-managed.

#### Scenario: Occupied stepper capped at total minus hold
- **WHEN** `bedsTotal=10, bedsOnHold=2` and coordinator clicks Occupied +
- **THEN** occupied cannot exceed 8

#### Scenario: On-hold stepper disabled when active reservations exist
- **WHEN** active HELD reservations exist for the population type
- **THEN** the on-hold stepper is disabled with a label showing the held count

#### Scenario: Capacity stepper syncs to availability (already fixed)
- **WHEN** coordinator changes total beds via the capacity stepper
- **THEN** the availability section's `bedsAvailable` updates immediately

### Requirement: shelter-list-badge-refresh
The coordinator dashboard SHALL refresh the shelter list summary (including "X avail" badge) after saving capacity changes, not only after availability updates.

#### Scenario: Badge updates after capacity save
- **WHEN** coordinator changes total beds and clicks Save Changes
- **THEN** the collapsed card badge shows the updated available count

### Requirement: merged-capacity-availability-ui
The coordinator dashboard SHALL present a single unified editing section for bed counts per population type. There is no separate "capacity" section — total beds, occupied, and on-hold are all edited in one place, and a single save writes one `bed_availability` snapshot.

#### Scenario: Coordinator sees unified bed editing
- **WHEN** a coordinator expands a shelter card
- **THEN** they see one section per population type with Total, Occupied, On Hold, and Available
- **AND** there is no separate "Total Beds" / capacity section

#### Scenario: Single save writes snapshot
- **WHEN** a coordinator changes total beds from 20 to 25 and occupied from 3 to 5
- **THEN** clicking Save writes one `bed_availability` snapshot with `beds_total=25, beds_occupied=5`
- **AND** `beds_available` is displayed as `25 - 5 - onHold`

### Requirement: cache-consistency
After any availability write operation, an immediate GET request must return the updated values. No stale reads from cache.

#### Scenario: TC-4.1 — GET immediately after PATCH returns updated values
- **WHEN** a coordinator PATCHes availability (occupied increases by 1)
- **THEN** an immediate GET /api/v1/shelters/{id} returns the same updated available count

#### Scenario: TC-4.3 — bed search reflects update
- **WHEN** a coordinator updates a shelter from available=0 to available=3
- **THEN** an immediate POST /api/v1/queries/beds returns the shelter with beds_available=3

### Requirement: availability-snapshot-immutability
The system SHALL enforce append-only semantics on the `bed_availability` table. Snapshots are never updated or deleted through the application layer. Each new availability update creates a new row. The latest snapshot for a given shelter and population type is retrieved via `DISTINCT ON (shelter_id, population_type) ... ORDER BY snapshot_ts DESC`.

#### Scenario: Previous snapshots preserved after new update
- **WHEN** a coordinator submits a new availability update for Shelter A, SINGLE_ADULT population
- **THEN** the previous snapshot row for Shelter A, SINGLE_ADULT remains in the database with its original values
- **AND** the `bed_availability` table contains both the old and new snapshot rows
- **AND** no UPDATE or DELETE statements are executed against existing rows

#### Scenario: Latest snapshot used for query
- **WHEN** Shelter A has three availability snapshots for SINGLE_ADULT with snapshot_ts values of 10:00, 11:00, and 12:00
- **THEN** queries using `DISTINCT ON (shelter_id, population_type) ORDER BY snapshot_ts DESC` return only the 12:00 snapshot
- **AND** the 10:00 and 11:00 snapshots are preserved for audit history but not included in current availability results
