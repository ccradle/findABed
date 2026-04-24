## ADDED Requirements

### Requirement: shelter-type-and-county-edit
The admin shelter edit form SHALL expose `shelter_type` and `county` as editable fields. `shelter_type` SHALL be a dropdown constrained to the controlled vocabulary. `county` SHALL be a dropdown or searchable select constrained to the deployment's `active_counties` list.

Changes to `dvShelter` or `shelter_type = 'DV'` are subject to existing DV safeguards (confirmation dialog, audit logging) per the existing `shelter-edit` spec requirements.

#### Scenario: Admin selects shelter type from dropdown
- **WHEN** a COC_ADMIN opens the shelter edit form
- **THEN** a "Shelter Type" dropdown is visible with all controlled vocabulary values
- **AND** the current `shelter_type` is pre-selected
- **AND** selecting "DV" while `dvShelter = false` is prevented with a tooltip: "Set the DV Shelter toggle to enable DV type"

#### Scenario: Setting shelter_type to DV requires dvShelter toggle
- **WHEN** a COC_ADMIN attempts to save a shelter with `shelter_type = 'DV'` and `dvShelter = false`
- **THEN** the backend returns 400 Bad Request (check constraint enforcement at application layer)

#### Scenario: Enabling dvShelter toggle auto-selects DV shelter type and disables dropdown
- **WHEN** a COC_ADMIN enables the dvShelter toggle while `shelter_type` is set to a non-DV value
- **THEN** the `shelter_type` dropdown automatically updates to `'DV'`
- **AND** the `shelter_type` dropdown becomes disabled (read-only) while dvShelter is true
- **AND** the user cannot manually deselect DV type while dvShelter remains enabled

#### Scenario: County dropdown filtered to deployment's active counties
- **WHEN** a COC_ADMIN opens the shelter edit form on a deployment with `active_counties` configured
- **THEN** the county dropdown shows only the configured active counties
- **AND** free-text entry outside the controlled list is not permitted

#### Scenario: County field is optional — no county is a valid state
- **WHEN** a COC_ADMIN saves a shelter without setting a county
- **THEN** the shelter is saved with `county = null`
- **AND** no validation error is shown (county is optional)

### Requirement: eligibility-criteria-admin-edit
The admin shelter edit form SHALL expose an "Eligibility Criteria" section for COC_ADMIN and PLATFORM_ADMIN roles. The section SHALL use a structured guided form (not a raw JSON editor) with purpose-labeled controls for each schema key. COORDINATOR role SHALL NOT have access to this section.

Criminal record policy fields SHALL use dignity-centered labels: "Accepts individuals with felony convictions" (not "accepts_felonies"), "Offense types excluded" with controlled vocabulary multi-select (not raw string input).

The section SHALL be clearly optional — all fields labeled "Optional" and unfilled state displayed as "Not specified."

#### Scenario: COC_ADMIN sees eligibility criteria section
- **WHEN** a COC_ADMIN opens the shelter edit form
- **THEN** an "Eligibility Criteria" section is present
- **AND** the section contains: accepts-felonies toggle, excluded offense types multi-select, individualized assessment toggle, VAWA protections checkbox, program requirements tag editor, documentation required tag editor, intake hours text field

#### Scenario: Coordinator does not see eligibility criteria section
- **WHEN** a COORDINATOR opens the shelter edit form
- **THEN** the eligibility criteria section is absent (not rendered for COORDINATOR role)
- **AND** existing coordinator-editable fields (phone, curfew, max stay, constraints) are unaffected

#### Scenario: Excluded offense types uses controlled vocabulary multi-select
- **WHEN** a COC_ADMIN opens the excluded offense types field
- **THEN** the multi-select shows: "Sex offense/RSO", "Arson", "Drug manufacturing", "Violent felony", "Pending charges", "Open warrants"
- **AND** each option has a localized display label (not the raw enum value)
- **AND** selecting one or more saves the corresponding controlled vocabulary values to JSONB

#### Scenario: Disclaimer visible in eligibility criteria section
- **WHEN** the eligibility criteria section is open and criminal record policy fields are visible
- **THEN** the `CriminalRecordPolicyDisclaimer` is rendered within the section
- **AND** it is non-dismissable

#### Scenario: VAWA protections field shows contextual note when enabled
- **WHEN** a COC_ADMIN enables the "VAWA protections apply" checkbox in the eligibility criteria section
- **THEN** an informational note (`shelter.vawaProtectionsApplyNote`) appears adjacent to the checkbox
- **AND** the note explains the shelter's potential obligation under VAWA for survivors with DV-related criminal records
- **AND** the note is non-dismissable within the form session

### Requirement: requires-verification-call-edit
The admin shelter edit form SHALL expose a `requires_verification_call` toggle. When enabled, the shelter's search card displays a "Call to verify eligibility" badge regardless of the JSONB content.

#### Scenario: Admin enables requires_verification_call toggle
- **WHEN** a COC_ADMIN enables the "Requires verification call" toggle and saves
- **THEN** `requires_verification_call = true` is stored on the shelter record
- **AND** search results for this shelter display the "Call to verify" badge

#### Scenario: requires_verification_call defaults to false for new shelters
- **WHEN** an admin creates a new shelter without setting the toggle
- **THEN** `requires_verification_call = false` is stored
