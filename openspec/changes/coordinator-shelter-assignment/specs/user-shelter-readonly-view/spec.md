## ADDED Requirements

### Requirement: user-assigned-shelters-view
The user edit drawer SHALL show an "Assigned Shelters" section displaying the user's current shelter assignments as a read-only chip list.

#### Scenario: Coordinator with 3 assigned shelters
- **GIVEN** a coordinator assigned to Safe Haven, Harbor House, and Bridges to Safety
- **WHEN** an admin opens the user edit drawer for this coordinator
- **THEN** 3 shelter name chips SHALL be displayed under "Assigned Shelters"
- **AND** the chips SHALL NOT have remove buttons (read-only)

#### Scenario: User with no assignments
- **GIVEN** a coordinator not assigned to any shelters
- **WHEN** an admin opens the user edit drawer
- **THEN** the "Assigned Shelters" section SHALL show "No shelters assigned"

### Requirement: user-shelter-links
Each shelter chip in the read-only view SHALL link to the shelter edit page.

#### Scenario: Click shelter chip navigates to edit
- **GIVEN** a coordinator assigned to Safe Haven
- **WHEN** the admin clicks the "Safe Haven" chip
- **THEN** the browser SHALL navigate to `/coordinator/shelters/{id}/edit?from=/admin`

### Requirement: user-shelters-api
A new endpoint `GET /api/v1/users/{id}/shelters` SHALL return the shelters assigned to a user.

#### Scenario: API returns assigned shelters
- **GIVEN** a coordinator assigned to 2 shelters
- **WHEN** GET /api/v1/users/{id}/shelters is called
- **THEN** response SHALL contain 2 shelter objects with id and name
- **AND** response SHALL return 200

#### Scenario: Non-coordinator returns empty
- **GIVEN** an outreach worker with no assignments
- **WHEN** GET /api/v1/users/{id}/shelters is called
- **THEN** response SHALL return an empty array and 200
