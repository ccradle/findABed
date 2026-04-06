## ADDED Requirements

### Requirement: in-app-report-problem-link
The authenticated application SHALL display a "Report a Problem" link in the page footer on every page, providing a consistent and discoverable path to submit feedback.

#### Scenario: Footer link visible on all authenticated pages
- **WHEN** an authenticated user views any page (search, coordinator, admin)
- **THEN** the footer SHALL contain a "Report a Problem" link
- **AND** the link SHALL be visible without scrolling past the main content

#### Scenario: Footer link opens GitHub issue template in new tab
- **WHEN** a user clicks the "Report a Problem" footer link
- **THEN** a new browser tab SHALL open to the GitHub `report-a-problem.yml` issue template
- **AND** the URL SHALL include pre-filled parameters for the `triage` label

#### Scenario: Footer link includes app version context
- **WHEN** a user clicks the "Report a Problem" footer link
- **THEN** the issue URL SHALL include the current app version (from `/api/v1/version`) as a URL parameter or in the pre-filled title

#### Scenario: Footer link is keyboard accessible
- **WHEN** a keyboard user tabs through the page
- **THEN** the "Report a Problem" link SHALL be focusable and activatable via Enter key
- **AND** the link SHALL have a visible focus indicator per WCAG 2.4.7

### Requirement: in-app-report-link-i18n
The "Report a Problem" link text SHALL be available in all supported locales.

#### Scenario: English locale shows English link text
- **WHEN** the locale is English
- **THEN** the footer link SHALL display "Report a Problem"

#### Scenario: Spanish locale shows Spanish link text
- **WHEN** the locale is Spanish
- **THEN** the footer link SHALL display "Reportar un Problema"

### Requirement: github-link-behavior
All issue reporting and feedback links SHALL open in a new tab without disrupting the user's current workflow.

#### Scenario: Links open in new tab with security attributes
- **WHEN** a user clicks any feedback link (report, feature, question)
- **THEN** the link SHALL open in a new tab (`target="_blank"`)
- **AND** the link SHALL include `rel="noopener noreferrer"`

#### Scenario: User's app state is preserved after reporting
- **WHEN** a user clicks "Report a Problem" while on the coordinator dashboard mid-update
- **THEN** the coordinator dashboard SHALL remain in its current state in the original tab
- **AND** no data SHALL be lost
