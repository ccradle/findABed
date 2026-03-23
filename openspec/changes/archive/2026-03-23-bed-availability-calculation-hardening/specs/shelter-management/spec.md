## MODIFIED Requirements

### Requirement: single-source-of-truth-for-beds-total
The system SHALL use `bed_availability` snapshots as the single source of truth for `beds_total`. The `shelter_capacity` table SHALL be dropped. All capacity reads and writes SHALL operate through `bed_availability`.

#### Scenario: Shelter create with initial capacity
- **WHEN** an admin creates a shelter with `capacities: [{populationType: "SINGLE_ADULT", bedsTotal: 20}]`
- **THEN** the system creates a `bed_availability` snapshot with `beds_total=20, beds_occupied=0, beds_on_hold=0`
- **AND** no row is written to any capacity table

#### Scenario: Shelter update changes capacity
- **WHEN** an admin updates a shelter's capacities from `bedsTotal=20` to `bedsTotal=30` for SINGLE_ADULT
- **THEN** the system writes a new `bed_availability` snapshot with `beds_total=30` and the current `beds_occupied` and `beds_on_hold` values preserved from the latest snapshot
- **AND** invariants INV-1 through INV-5 are validated before writing

#### Scenario: Shelter detail returns capacity from availability
- **WHEN** a user requests GET /api/v1/shelters/{id}
- **THEN** the `capacities` array is populated from the latest `bed_availability` snapshot per population type
- **AND** `bedsTotal` matches the snapshot's `beds_total` exactly

#### Scenario: Data import writes availability snapshots
- **WHEN** a CSV import includes capacity data for a shelter
- **THEN** the import service writes `bed_availability` snapshots instead of capacity rows
- **AND** existing availability data (occupied, on_hold) is preserved

#### Scenario: HSDS export reads from availability
- **WHEN** a shelter is exported in HSDS 3.0 format
- **THEN** the `fabt:capacity` extension is populated from the latest `bed_availability` snapshot

#### Scenario: Coordinator capacity change writes snapshot
- **WHEN** a coordinator changes total beds via the UI stepper
- **THEN** a new `bed_availability` snapshot is written with the updated `beds_total`
- **AND** `beds_occupied` and `beds_on_hold` are preserved from the previous snapshot
- **AND** the UI displays `beds_available = beds_total - beds_occupied - beds_on_hold` correctly

### Requirement: migration-v20-drop-shelter-capacity
The system SHALL include a Flyway migration V20 that migrates capacity-only data to `bed_availability` and drops the `shelter_capacity` table.

#### Scenario: Capacity-only shelters migrated
- **WHEN** V20 runs and `shelter_capacity` has rows with no corresponding `bed_availability` row
- **THEN** a `bed_availability` snapshot is created with `beds_total` from capacity, `beds_occupied=0, beds_on_hold=0`

#### Scenario: Shelters with existing availability unchanged
- **WHEN** V20 runs and `bed_availability` already has a snapshot for a shelter/population
- **THEN** no additional snapshot is created (the existing data is authoritative)

#### Scenario: Table and RLS policy dropped
- **WHEN** V20 completes
- **THEN** the `shelter_capacity` table no longer exists
- **AND** the `dv_shelter_capacity_access` RLS policy no longer exists
