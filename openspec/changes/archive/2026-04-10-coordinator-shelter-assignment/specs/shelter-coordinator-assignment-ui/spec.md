## ADDED Requirements

### Requirement: coordinator-combobox
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

### Requirement: assignment-persist-on-save
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

### Requirement: combobox-filter-eligible
The combobox SHALL only show users eligible for coordinator assignment.

#### Scenario: Only COORDINATOR role users shown
- **GIVEN** 10 users in the tenant: 3 COORDINATOR, 2 COC_ADMIN, 5 OUTREACH_WORKER
- **WHEN** the admin opens the combobox dropdown
- **THEN** only COORDINATOR and COC_ADMIN users SHALL appear (5 total)
- **AND** OUTREACH_WORKER users SHALL NOT appear

#### Scenario: DV access indicator on DV shelters
- **GIVEN** a DV shelter is being edited
- **WHEN** the combobox dropdown shows eligible coordinators
- **THEN** users with dvAccess=true SHALL be visually indicated
- **AND** users without dvAccess SHALL show a warning that they won't receive DV referral notifications

### Requirement: combobox-wcag
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

### Requirement: combobox-dark-mode
The combobox and chips SHALL use existing color tokens for both light and dark mode. No hardcoded colors.

#### Scenario: Dark mode rendering
- **WHEN** the user has dark mode enabled (prefers-color-scheme: dark)
- **THEN** the combobox, dropdown, and chips SHALL render with correct contrast using color tokens
