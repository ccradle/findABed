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
