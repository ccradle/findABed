## ADDED Requirements

### Requirement: feedback-support-section
The landing page SHALL include a "Feedback & Support" section providing visitors with clear paths to report issues, request features, and ask questions.

#### Scenario: Feedback section visible on landing page
- **WHEN** a visitor views the landing page
- **THEN** a "Feedback & Support" section SHALL be visible
- **AND** it SHALL contain three links: "Report a Problem", "Request a Feature", and "Ask a Question"

#### Scenario: Report a Problem links to issue template
- **WHEN** a visitor clicks "Report a Problem"
- **THEN** a new tab SHALL open to the GitHub `report-a-problem.yml` issue template

#### Scenario: Request a Feature links to feature template
- **WHEN** a visitor clicks "Request a Feature"
- **THEN** a new tab SHALL open to the GitHub `feature-request.yml` issue template

#### Scenario: Ask a Question links to Discussions
- **WHEN** a visitor clicks "Ask a Question"
- **THEN** a new tab SHALL open to the GitHub Discussions Q&A category

#### Scenario: Feedback section accessible in dark mode
- **WHEN** the visitor's OS is set to dark mode
- **THEN** the feedback section SHALL render with adequate contrast per existing dark mode tokens

#### Scenario: Feedback section accessible on mobile
- **WHEN** the visitor views the landing page on a 320px viewport
- **THEN** the feedback section SHALL reflow without horizontal scrolling
- **AND** all links SHALL have minimum 44x44px touch targets
