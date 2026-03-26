## ADDED Requirements

### Requirement: hic-export
The system SHALL generate Housing Inventory Count (HIC) data in HUD-compatible CSV format from the latest bed_availability snapshots.

#### Scenario: HIC export for January snapshot
- **WHEN** an admin requests HIC export for 2026-01-29
- **THEN** a CSV is generated with columns: ProjectID, ProjectName, ProjectType, HouseholdType, BedInventory, TargetPopulation
- **AND** DV shelters are included but with redacted address per existing policy

#### Scenario: HIC export includes all population types
- **WHEN** the HIC is generated
- **THEN** each shelter has one row per population type with beds_total from the snapshot closest to the requested date

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

#### Scenario: HIC export suppresses DV row for single-shelter CoC
- **WHEN** the HIC is generated for a CoC with only 1 DV shelter
- **THEN** the DV aggregate row is omitted from the CSV entirely

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
