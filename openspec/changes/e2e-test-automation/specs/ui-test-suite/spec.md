## ADDED Requirements

### Requirement: login-ui-tests
The E2E suite SHALL validate the login flow across all user roles using Playwright browser automation.

#### Scenario: Successful login as outreach worker
- **WHEN** the test navigates to /login, enters tenant slug "dev-coc", email "outreach@dev.fabt.org", password "admin123", and submits
- **THEN** the browser redirects to /outreach
- **AND** the page displays the "Find a Bed" header

#### Scenario: Successful login as coordinator
- **WHEN** the test logs in as cocadmin@dev.fabt.org
- **THEN** the browser redirects to /coordinator
- **AND** the page displays the "Shelter Dashboard" header

#### Scenario: Failed login shows error
- **WHEN** the test submits invalid credentials
- **THEN** the login page displays an error message
- **AND** the browser remains on /login

### Requirement: outreach-search-ui-tests
The E2E suite SHALL validate the outreach bed search workflow including filtering, result display, and shelter detail modal.

#### Scenario: Search displays shelters with availability
- **WHEN** the test is logged in as outreach worker and navigates to /outreach
- **THEN** the page displays shelter result cards
- **AND** each card shows the shelter name, address, and availability data

#### Scenario: Population type filter works
- **WHEN** the test selects "Single Adults" from the population type dropdown
- **THEN** the result list refreshes and shows filtered results

#### Scenario: Shelter detail modal opens
- **WHEN** the test clicks a shelter result card
- **THEN** a detail modal appears with shelter name, availability by population type, constraints, and action buttons (Call, Directions)

### Requirement: coordinator-dashboard-ui-tests
The E2E suite SHALL validate the coordinator availability update workflow.

#### Scenario: Coordinator can update availability
- **WHEN** the test is logged in as cocadmin and expands a shelter card on /coordinator
- **THEN** the availability update form appears with occupied/on-hold steppers per population type
- **AND** the test can increment occupied count and click "Update Availability"
- **AND** a success indicator appears

### Requirement: admin-panel-ui-tests
The E2E suite SHALL validate admin panel operations: shelter creation, user management, and subscription management.

#### Scenario: Admin can create a shelter
- **WHEN** the test is logged in as admin and navigates to the shelter creation form
- **THEN** the test can fill in shelter details and submit
- **AND** the new shelter appears in the shelter list
