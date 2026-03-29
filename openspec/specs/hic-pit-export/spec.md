## ADDED Requirements

### Requirement: HIC export matches HUD Inventory.csv schema (FY2024+)

The HIC CSV export SHALL produce output that conforms to the HUD Inventory.csv column structure with correct coded field values.

#### Scenario: HIC CSV has correct column headers

- **WHEN** a CoC admin exports HIC data
- **THEN** the CSV header matches HUD Inventory.csv: `InventoryID,ProjectID,CoCCode,HouseholdType,Availability,UnitInventory,BedInventory,CHVetBedInventory,YouthVetBedInventory,VetBedInventory,CHYouthBedInventory,YouthBedInventory,CHBedInventory,OtherBedInventory,ESBedType,InventoryStartDate,InventoryEndDate`

#### Scenario: HIC uses integer codes for all coded fields

- **WHEN** HIC data is generated
- **THEN** ProjectType uses HUD integer codes (0=ES Entry/Exit, 1=ES Night-by-Night)
- **AND** HouseholdType uses HUD integer codes (1=without children, 3=with adults and children, 4=only children)
- **AND** Availability uses integer codes (1=Year-round, 2=Seasonal, 3=Overflow)
- **AND** ESBedType uses integer codes (1=Facility-based, 2=Voucher, 3=Other)
- **AND** TargetPopulation uses integer codes (1=DV, 4=N/A)
- **AND** HMISParticipation uses integer codes (1=HMIS, 2=Comparable DB)

#### Scenario: DV shelters report correct HMISParticipation

- **WHEN** a DV shelter appears in the HIC export (aggregated)
- **THEN** HMISParticipation is 2 (Comparable Database Participating), not 1

#### Scenario: Veteran beds populate dedicated columns

- **WHEN** a shelter has VETERAN population type beds
- **THEN** those beds appear in VetBedInventory column
- **AND** other bed inventory columns default to 0

#### Scenario: CoCCode is populated from tenant

- **WHEN** HIC data is generated
- **THEN** CoCCode is populated from the tenant's slug or a configured CoC code

#### Scenario: Unknown population types are rejected

- **WHEN** a shelter has an unmapped population type
- **THEN** the export throws an error rather than silently outputting raw enum values

#### Scenario: HIC export includes all population types

- **WHEN** the HIC is generated
- **THEN** each shelter has one row per population type with beds_total from the snapshot closest to the requested date

#### Scenario: HIC export suppresses DV row for single-shelter CoC

- **WHEN** the HIC is generated for a CoC with only 1 DV shelter
- **THEN** the DV aggregate row is omitted from the CSV entirely

### Requirement: pit-count-export
The system SHALL generate sheltered Point-in-Time count data from bed_availability snapshots.

#### Scenario: Sheltered PIT count for January night

- **WHEN** an admin requests PIT export for 2026-01-29
- **THEN** a CSV shows beds_occupied per shelter per population type from the snapshot closest to midnight on that date

#### Scenario: PIT count aggregates DV shelters

- **WHEN** the PIT export includes DV shelters
- **AND** the CoC has 3 or more distinct DV shelters
- **THEN** DV shelter counts are summed into an aggregated row
- **AND** individual DV shelter names do not appear

#### Scenario: PIT export suppresses DV row for single-shelter CoC

- **WHEN** the PIT is generated for a CoC with only 1 DV shelter
- **THEN** the DV aggregate row is omitted from the CSV entirely

### Requirement: hmis-dv-cell-suppression
The system SHALL suppress DV aggregate data in HMIS push output when the CoC has fewer than 3 distinct DV shelters, to prevent re-identification of individual DV shelters through aggregate counts.

#### Scenario: HMIS push suppresses DV aggregate for single-shelter CoC

- **WHEN** the HMIS push builds inventory for a CoC with 1 DV shelter
- **THEN** the DV aggregate record is omitted from the push payload
- **AND** non-DV shelter records are unaffected

#### Scenario: HMIS push includes DV aggregate for multi-shelter CoC

- **WHEN** the HMIS push builds inventory for a CoC with 4 DV shelters
- **THEN** the DV aggregate record is included with summed bed counts

### Requirement: HIC/PIT edge cases handled correctly

#### Scenario: Empty shelter list produces header-only CSV

- **WHEN** a tenant has no shelters
- **THEN** the HIC export returns a CSV with only the header row and no data

#### Scenario: Zero-bed shelters are excluded

- **WHEN** a shelter has 0 total beds
- **THEN** it does not appear in the HIC export

#### Scenario: Exactly 3 DV shelters triggers aggregation

- **WHEN** exactly 3 DV shelters exist with beds
- **THEN** the aggregated DV row appears (boundary condition met)

#### Scenario: Null population type does not cause crash

- **WHEN** a bed availability snapshot has null population type
- **THEN** the row is skipped with a warning log, not a NullPointerException
