## MODIFIED Requirements

### Requirement: shelter-crud
The system SHALL support creating, reading, updating, and listing shelter profiles scoped to a tenant, aligned with HSDS 3.0 organization/service/location model. The shelter detail response now includes the latest availability per population type, showing `beds_available` (derived), `snapshot_ts`, and `data_age_seconds` alongside static constraints and total capacity. The shelter list response includes an availability summary per shelter.

#### Scenario: Create a shelter
- **WHEN** a CoC admin sends POST `/api/v1/shelters` with name, address, phone, and capacity
- **THEN** the system creates the shelter within the admin's tenant and returns 201 with the shelter resource including a generated UUID

#### Scenario: Read a shelter
- **WHEN** an authenticated user sends GET `/api/v1/shelters/{id}` for a shelter in their tenant
- **THEN** the system returns the full shelter profile including constraints

#### Scenario: Update a shelter
- **WHEN** a coordinator or CoC admin sends PUT `/api/v1/shelters/{id}`
- **THEN** the system updates the shelter profile and returns 200

#### Scenario: List shelters with pagination
- **WHEN** an authenticated user sends GET `/api/v1/shelters?page=0&size=20`
- **THEN** the system returns a paginated list of shelters in the user's tenant
- **AND** the response includes total count and page metadata

#### Scenario: Shelter detail includes availability
- **WHEN** an authenticated user sends GET `/api/v1/shelters/{id}` for a shelter that has availability snapshots
- **THEN** the response includes an `availability` array with one entry per population type containing: `populationType`, `bedsTotal`, `bedsOccupied`, `bedsOnHold`, `bedsAvailable` (derived: bedsTotal - bedsOccupied - bedsOnHold), `acceptingNewGuests`, `snapshotTs`, `dataAgeSeconds` (seconds since snapshotTs), and `dataFreshness` (FRESH/AGING/STALE/UNKNOWN)
- **AND** when a shelter has no availability snapshots, the `availability` array is empty and `dataFreshness` at the shelter level is UNKNOWN

#### Scenario: Shelter list includes availability summary
- **WHEN** an authenticated user sends GET `/api/v1/shelters`
- **THEN** each shelter in the results includes an `availabilitySummary` object with: `totalBedsAvailable` (sum of beds_available across all population types), `populationTypesServed` (count of population types with snapshots), `lastUpdated` (most recent snapshot_ts across all population types), `dataAgeSeconds`, and `dataFreshness`
- **AND** shelters without any availability snapshots have `totalBedsAvailable: null`, `lastUpdated: null`, and `dataFreshness: "UNKNOWN"`
