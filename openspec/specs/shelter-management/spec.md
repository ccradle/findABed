## Purpose

Shelter lifecycle management: creation, updates, capacity management, and data migration. Ensures `bed_availability` is the single source of truth for all bed counts.

## Requirements

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

#### Scenario: Deactivation metadata stored on shelter
- **WHEN** an admin deactivates a shelter with reason SEASONAL_END
- **THEN** `shelter.deactivated_at`, `shelter.deactivated_by`, and `shelter.deactivation_reason` are populated
- **AND** on reactivation, all three fields are cleared to null

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

### Requirement: full-featured-shelter-csv-import
The system SHALL support importing shelters with the complete data model via CSV: name, address, phone, coordinates, DV flag, population types served, bed counts, and operational constraints. The existing fuzzy header matching SHALL be extended to cover all new columns.

#### Scenario: Import shelter with full data model
- **WHEN** a CSV row includes name, address, phone, dvShelter, populationTypesServed, bedsTotal, bedsOccupied, and constraint columns
- **THEN** the shelter is created with all provided data including constraints and capacities
- **AND** the shelter appears in bed search with correct availability (bedsAvailable = bedsTotal - bedsOccupied)
- **AND** if dvShelter=true, the shelter is RLS-protected and only visible to users with dvAccess=true

#### Scenario: Import shelter with minimal columns
- **WHEN** a CSV row includes only the required columns (name, addressCity)
- **THEN** the shelter is created with defaults: dvShelter=false, no constraints, no capacities
- **AND** the shelter exists in the system but shows zero beds available until capacities are configured manually

#### Scenario: Boolean columns accept flexible values
- **WHEN** a CSV row contains boolean values like "yes", "true", "1", "Y", "TRUE"
- **THEN** all are parsed as true
- **AND** "no", "false", "0", "N", "FALSE", empty, or absent are parsed as false

#### Scenario: Population types are semicolon-delimited
- **WHEN** a CSV row has populationTypesServed = "SINGLE_ADULT;FAMILY_WITH_CHILDREN;VETERAN"
- **THEN** the shelter is created serving all three population types
- **AND** bed capacities are created for each listed population type using the bedsTotal and bedsOccupied values

#### Scenario: Invalid population type rejected
- **WHEN** a CSV row has populationTypesServed containing "ADULTS" (not a recognized value)
- **THEN** the row is rejected with an error listing valid population type values

#### Scenario: Capacity conflict rejected
- **WHEN** a CSV row has bedsOccupied greater than bedsTotal
- **THEN** the row is rejected with an error explaining the conflict

### Requirement: shelter-csv-import-documentation
The system SHALL provide comprehensive documentation, downloadable templates, and in-app guidance for the CSV shelter import feature.

#### Scenario: Import page shows quick-start guidance
- **WHEN** an admin navigates to the Import tab
- **THEN** a quick-start card is visible with numbered steps, template download links, and a link to the full format reference

#### Scenario: Template CSV includes example data with all column types
- **WHEN** a user downloads the example template CSV
- **THEN** it contains example rows demonstrating emergency, DV, and constrained shelter types

#### Scenario: Column reference documentation covers all fields
- **WHEN** a user reads the shelter import format documentation
- **THEN** every column is documented with name, required/optional, data type, allowed values, and example

### Requirement: row-level-import-validation-feedback
The system SHALL provide specific, non-technical validation error messages at the row and field level during CSV import, with a downloadable error report.

#### Scenario: Validation errors shown per row
- **WHEN** a CSV file contains validation errors
- **THEN** the preview shows a summary of valid vs. error rows with per-row details

#### Scenario: Downloadable error CSV
- **WHEN** the import preview shows rows with errors
- **THEN** a "Download errors" button exports a CSV of only the failed rows

#### Scenario: Valid rows succeed despite errors in other rows
- **WHEN** a CSV file contains both valid and invalid rows
- **THEN** valid rows are imported successfully and invalid rows are rejected with specific error messages

### Requirement: import-upsert-with-preview
The system SHALL support update-or-create (upsert) behavior on re-import, with a preview showing the expected outcome.

#### Scenario: Re-import updates existing shelters
- **GIVEN** a shelter with a given name and city already exists in the tenant
- **WHEN** a CSV is uploaded containing a row with the same name and city
- **THEN** the preview shows update vs. create counts and on commit the existing shelter is updated

#### Scenario: DV flag change flagged in preview
- **GIVEN** a non-DV shelter exists
- **WHEN** a CSV re-import sets dvShelter=true for that shelter
- **THEN** the preview flags this as a safety notice and a WARN log is written
- **AND** the DV flag is NOT changed by the import (manual admin action required)
