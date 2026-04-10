## ADDED Requirements

### Requirement: Edit shelter in create/edit form

The ShelterForm SHALL support both create and edit modes using the same component.

#### Scenario: Admin navigates to shelter edit

- **WHEN** an admin clicks "Edit" on a shelter row in the admin Shelters tab
- **THEN** the ShelterForm opens populated with the shelter's current data
- **AND** saving sends PUT /api/v1/shelters/{id} and navigates back to the Shelters tab

#### Scenario: Coordinator edits own shelter details

- **WHEN** a coordinator clicks "Edit Details" on their shelter card in the Coordinator dashboard
- **THEN** the ShelterForm opens with operational fields editable (phone, curfew, max stay, constraints)
- **AND** structural fields (name, address, DV flag) are read-only for coordinators

#### Scenario: Create mode unchanged

- **WHEN** an admin navigates to /coordinator/shelters/new
- **THEN** the ShelterForm behaves as before (empty form, POST on save)

### Requirement: DV shelter edit safeguards

Editing DV shelters SHALL have tiered safeguards based on field sensitivity and user role.

#### Scenario: DV flag locked for coordinators

- **WHEN** a coordinator opens the edit form for a DV shelter
- **THEN** the dvShelter toggle is disabled with tooltip "Contact your CoC administrator to change DV status"

#### Scenario: DV flag change requires confirmation

- **WHEN** a COC_ADMIN changes dvShelter from true to false
- **THEN** a confirmation dialog appears: "This will make the shelter address visible to all users including outreach workers without DV authorization"
- **AND** the change is only applied after confirmation

#### Scenario: DV shelter address change is audit-logged

- **WHEN** any user changes the address of a DV shelter
- **THEN** an audit event is recorded with the old and new address values

#### Scenario: Backend enforces DV flag role restriction

- **WHEN** a COORDINATOR sends PUT /api/v1/shelters/{id} with a changed dvShelter value
- **THEN** the response is 403 Forbidden

#### Scenario: DV shelter address shown according to redaction policy

- **WHEN** a user opens the edit form for a DV shelter
- **THEN** address fields show the redacted value unless the user's role satisfies the tenant's `dv_address_visibility` policy
- **AND** if address is redacted, address fields are read-only with message "Address protected by DV policy"

### Requirement: Demo flow — 211 Import to Shelter Edit lifecycle

The platform SHALL support a demonstrable end-to-end flow from 211 CSV import through shelter editing, representing a realistic CoC onboarding experience.

#### Scenario: Admin imports 211 CSV and edits an imported shelter

- **WHEN** an admin uploads a 211 CSV file containing multiple shelters via the Import 211 Data page
- **AND** confirms the import after reviewing the column mapping preview
- **THEN** the imported shelters appear in the admin Shelters tab
- **AND** the admin can click "Edit" on any imported shelter to correct details (e.g., phone number)
- **AND** the edit form loads pre-populated with the imported data
- **AND** saving the edit persists the corrected data

#### Scenario: Admin configures DV status on imported shelter

- **WHEN** an admin edits an imported shelter that should be flagged as DV
- **AND** sets the dvShelter toggle to true
- **THEN** the DV safeguards apply immediately (address redaction, audit logging)
- **AND** the shelter is protected according to DV policy from that point forward

#### Scenario: Demo CSV uses iCarol-compatible headers

- **WHEN** the demo CSV file uses iCarol-style column headers (agency_name, street_address, address_city, address_state, postal_code, telephone)
- **THEN** the 211 import adapter's fuzzy matching maps all columns correctly
- **AND** the preview screen shows accurate source-to-target column mapping

### Requirement: Import preview returns structured column mapping with samples

The 211 preview endpoint SHALL return column mappings with sample data values so users can verify correctness before importing.

#### Scenario: Preview shows column mapping with sample values

- **WHEN** a user uploads a CSV for preview
- **THEN** the response includes an array of column mappings, each with sourceColumn, targetField, and up to 3 sample values from the data rows
- **AND** the response includes the total number of data rows
- **AND** unmapped columns are listed separately

### Requirement: Import result displays actionable error details

The import result SHALL return human-readable error messages so users can identify and fix problematic rows.

#### Scenario: Import with row errors shows per-row messages

- **WHEN** an import completes with some row-level errors
- **THEN** the result includes an array of formatted error strings (e.g., "Row 5: name — Shelter name is required")
- **AND** the error count matches the number of error messages

### Requirement: Import history displays correct counts

The import history endpoint SHALL use field names that match the frontend contract.

#### Scenario: Import history shows created/updated/skipped/errors counts

- **WHEN** a user views the import history tab
- **THEN** each import entry shows created, updated, skipped, and errors counts
- **AND** the field names in the API response match the frontend interface

### Requirement: CSV import handles encoding and edge cases

The CSV parser SHALL handle real-world CSV variations without silent data corruption.

#### Scenario: CSV with UTF-8 BOM imports correctly

- **WHEN** a CSV file includes a UTF-8 BOM (byte order mark)
- **THEN** the BOM is stripped transparently and the first column header maps correctly

#### Scenario: CSV with escaped quotes parses correctly

- **WHEN** a CSV field contains escaped quotes (e.g., `"Smith ""Jr."" Shelter"`)
- **THEN** the value is parsed as `Smith "Jr." Shelter`

#### Scenario: Invalid coordinates are rejected with warning

- **WHEN** a CSV row contains latitude outside -90 to 90 or longitude outside -180 to 180
- **THEN** the coordinates are set to null and a warning is logged

### Requirement: File upload size is limited

The platform SHALL enforce a maximum file upload size to prevent memory exhaustion.

#### Scenario: File exceeding size limit returns 413

- **WHEN** a user uploads a file larger than the configured maximum (10MB)
- **THEN** the response is 413 Payload Too Large with a clear error message

### Requirement: CSV exports are injection-safe

HIC/PIT CSV exports SHALL sanitize cell values to prevent formula injection when opened in Excel.

#### Scenario: Shelter name with formula prefix is sanitized

- **WHEN** a shelter name starts with `=`, `+`, `-`, or `@`
- **THEN** the exported CSV cell is prefixed with a tab character inside quotes to prevent Excel formula execution

### Requirement: Import data is tenant-isolated

Import operations SHALL be scoped to the authenticated user's tenant.

#### Scenario: Import from one tenant does not appear in another

- **WHEN** a user in Tenant A imports shelters
- **THEN** the imported shelters are only visible to users in Tenant A
- **AND** import history for Tenant A does not include imports from Tenant B

### Requirement: GitHub Pages shelter onboarding walkthrough

The demo site SHALL include a dedicated shelter onboarding walkthrough page that tells the import-to-edit story.

#### Scenario: Shelter onboarding page is accessible from main walkthrough

- **WHEN** a user visits the main demo walkthrough
- **THEN** the "More Walkthroughs" section includes a link to "Shelter Onboarding"
- **AND** Card 11 (Shelter Management) mentions edit and import capability

#### Scenario: Shelter onboarding page tells the complete story

- **WHEN** a user visits the shelter onboarding walkthrough
- **THEN** the page shows 7 cards in narrative order: import preview → import success → shelters tab with edit → phone edit → DV toggle → DV confirmation → coordinator view
- **AND** every caption leads with the human story (Simone's lens)
- **AND** every card is self-explanatory without external context (Devon's lens)

### Requirement: Assigned coordinators combobox on shelter edit

The shelter edit page SHALL include an "Assigned Coordinators" section with a searchable combobox after the capacities section.

#### Scenario: Admin assigns coordinator to shelter
- **GIVEN** an admin is editing a shelter
- **WHEN** they type a coordinator name in the combobox
- **THEN** a filtered dropdown SHALL show matching users with COORDINATOR role
- **AND** selecting a user adds a removable chip below the combobox

#### Scenario: Admin removes coordinator assignment
- **GIVEN** a shelter has 2 assigned coordinators shown as chips
- **WHEN** the admin clicks the remove button on one chip
- **THEN** the chip SHALL be removed from the list
- **AND** the change is staged (not persisted until Save)

### Requirement: Coordinator assignment persisted on shelter save

Assignment changes SHALL be persisted when the shelter form is saved, not immediately on chip add/remove.

#### Scenario: Staged changes persisted on save
- **GIVEN** the admin added coordinator A and removed coordinator B
- **WHEN** they click Save
- **THEN** `POST /shelters/{id}/coordinators` SHALL be called for A
- **AND** `DELETE /shelters/{id}/coordinators/{B}` SHALL be called for B

#### Scenario: Unsaved changes lost on cancel
- **GIVEN** the admin added a coordinator chip but did not save
- **WHEN** they navigate away or cancel
- **THEN** the assignment SHALL NOT be persisted

### Requirement: Coordinator combobox filters to eligible roles

The combobox SHALL only show users eligible for coordinator assignment.

#### Scenario: Only COORDINATOR and COC_ADMIN role users shown
- **GIVEN** 10 users in the tenant: 3 COORDINATOR, 2 COC_ADMIN, 5 OUTREACH_WORKER
- **WHEN** the admin opens the combobox dropdown
- **THEN** only COORDINATOR and COC_ADMIN users SHALL appear (5 total)
- **AND** OUTREACH_WORKER users SHALL NOT appear

#### Scenario: DV access indicator on DV shelters
- **GIVEN** a DV shelter is being edited
- **WHEN** the combobox dropdown shows eligible coordinators
- **THEN** users with dvAccess=true SHALL be visually indicated
- **AND** users without dvAccess SHALL show a warning that they won't receive DV referral notifications

### Requirement: Coordinator combobox WCAG keyboard and screen reader

The combobox SHALL follow W3C APG Combobox Pattern for WCAG 2.1 AA compliance.

#### Scenario: Keyboard navigation
- **WHEN** the combobox is focused
- **THEN** Arrow keys SHALL navigate the dropdown options
- **AND** Enter SHALL select the highlighted option
- **AND** Escape SHALL close the dropdown

#### Scenario: Screen reader announcement
- **WHEN** a coordinator chip is added
- **THEN** screen readers SHALL announce the addition
- **AND** each chip's remove button SHALL have `aria-label="Remove {name}"`

### Requirement: Coordinator combobox dark mode token compliance

The combobox and chips SHALL use existing color tokens for both light and dark mode. No hardcoded colors.

#### Scenario: Dark mode rendering
- **WHEN** the user has dark mode enabled (prefers-color-scheme: dark)
- **THEN** the combobox, dropdown, and chips SHALL render with correct contrast using color tokens
