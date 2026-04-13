## MODIFIED Requirements

### Requirement: Full-featured shelter CSV import

The system SHALL support importing shelters with the complete data model via CSV: name, address, phone, coordinates, DV flag, population types served, bed counts, and operational constraints. The existing fuzzy header matching SHALL be extended to cover all new columns.

#### Scenario: Import shelter with full data model
- **WHEN** a CSV row includes name, address, phone, dvShelter, populationTypesServed, bedsTotal, bedsOccupied, and constraint columns
- **THEN** the shelter is created with all provided data including constraints and capacities
- **AND** the shelter appears in bed search with correct availability (bedsAvailable = bedsTotal - bedsOccupied)
- **AND** if dvShelter=true, the shelter is RLS-protected and only visible to users with dvAccess=true

#### Scenario: Import shelter with minimal columns
- **WHEN** a CSV row includes only the required columns (name, addressStreet, addressCity, addressState, addressZip)
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
- **THEN** the row is rejected with an error: "Row N: population type 'ADULTS' is not recognized — expected one of: SINGLE_ADULT, FAMILY_WITH_CHILDREN, VETERAN, DV_SURVIVOR, YOUTH_UNDER_18"

#### Scenario: Capacity conflict rejected
- **WHEN** a CSV row has bedsOccupied greater than bedsTotal
- **THEN** the row is rejected with an error: "Row N: bedsOccupied (30) cannot exceed bedsTotal (20)"

### Requirement: Shelter CSV import documentation and guidance

The system SHALL provide comprehensive documentation, downloadable templates, and in-app guidance for the CSV shelter import feature.

#### Scenario: Import page shows quick-start guidance
- **WHEN** an admin navigates to the Import tab
- **THEN** a quick-start card is visible with 3 numbered steps: (1) Download template, (2) Fill in shelter data, (3) Upload here
- **AND** the card includes download links for both the headers-only template and the example CSV
- **AND** the card includes a link to the full format reference documentation

#### Scenario: Template CSV includes example data with all column types
- **WHEN** a user downloads the example template CSV
- **THEN** it contains 3 example rows: one emergency shelter with capacity, one DV shelter with dvShelter=true, one shelter with constraints (sobrietyRequired=true, referralRequired=true)
- **AND** all enum values for population types and boolean constraint fields are demonstrated across the example rows

#### Scenario: Column reference documentation covers all fields
- **WHEN** a user reads the shelter import format documentation
- **THEN** every column is documented in a table with: column name, required/optional, data type, allowed values, and an example value
- **AND** file requirements are stated (UTF-8 encoding, first row = headers, CSV format)
- **AND** multi-value fields (populationTypesServed) document the semicolon delimiter
- **AND** boolean parsing rules are documented (true/yes/1/Y → true)

### Requirement: Row-level import validation feedback

The system SHALL provide specific, non-technical validation error messages at the row and field level during CSV import, with a downloadable error report.

#### Scenario: Validation errors shown per row
- **WHEN** a CSV file is uploaded and contains validation errors
- **THEN** the preview step shows a summary: "{N} valid rows, {M} rows with errors"
- **AND** each error row displays the row number, the field with the error, the actual value, and a human-readable message explaining the expected format

#### Scenario: Downloadable error CSV
- **WHEN** the import preview shows rows with errors
- **THEN** a "Download errors" button is available
- **AND** clicking it downloads a CSV containing only the failed rows with an added "Error" column

#### Scenario: Valid rows succeed despite errors in other rows
- **WHEN** a CSV file contains both valid and invalid rows
- **THEN** valid rows are imported successfully
- **AND** invalid rows are rejected with specific error messages
- **AND** the post-import summary shows: "{N} shelters imported, {M} shelters had errors"

### Requirement: Import upsert behavior with preview

The system SHALL support update-or-create (upsert) behavior on re-import, with a preview showing the expected outcome.

#### Scenario: Re-import updates existing shelters
- **GIVEN** shelter "Hope House" at "123 Main St" already exists in the tenant
- **WHEN** a CSV is uploaded containing a row with the same name and address
- **THEN** the preview shows "Will update: 1 / Will create: 0"
- **AND** on commit, the existing shelter's details, constraints, and capacities are updated

#### Scenario: DV flag change flagged in preview
- **GIVEN** a non-DV shelter exists
- **WHEN** a CSV re-import sets dvShelter=true for that shelter
- **THEN** the preview flags this as a safety-sensitive change
- **AND** a WARN log is written documenting the DV status change

### Requirement: Import test coverage

Backend integration tests SHALL verify all import column types and edge cases.

#### Scenario: Missing required fields
- **WHEN** a CSV row is missing name or address
- **THEN** the row is rejected with a specific error naming the missing field

#### Scenario: DV shelter import creates RLS-protected shelter
- **WHEN** a CSV row has dvShelter=true
- **THEN** the shelter is RLS-protected and only visible to users with dvAccess=true

#### Scenario: Full round-trip: import → bed search finds shelter
- **WHEN** a CSV is imported with name, address, populationTypesServed=SINGLE_ADULT, bedsTotal=50, bedsOccupied=10
- **THEN** a bed search for SINGLE_ADULT returns the shelter with bedsAvailable=40
