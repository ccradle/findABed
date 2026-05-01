## ADDED Requirements

### Requirement: My Past Holds view for outreach workers
The system SHALL provide a dedicated route `/outreach/my-holds` where outreach workers can view their active HELD reservations and recent terminal reservations (CONFIRMED, CANCELLED, EXPIRED, CANCELLED_SHELTER_DEACTIVATED). The view SHALL be the deep-link target for hold-cancellation notifications.

#### Scenario: Outreach worker sees their active and recent holds
- **WHEN** an outreach worker navigates to `/outreach/my-holds`
- **THEN** the page shows their HELD reservations at the top, followed by terminal-state reservations from the last 7 days
- **AND** each row shows shelter name, population type, status, created timestamp, and primary action (e.g., "Find another bed" for cancelled, "Confirm arrival" for HELD)

#### Scenario: Deep-link highlights specific hold
- **WHEN** the outreach worker navigates to `/outreach/my-holds?reservationId=res-001`
- **THEN** the specified reservation is rendered with a visible highlight (e.g., left border accent)
- **AND** the page scrolls to that row
- **AND** keyboard focus moves to that row's primary action button

#### Scenario: Load more historical holds
- **WHEN** the outreach worker clicks "Show older" at the bottom of the list
- **THEN** reservations from 7-30 days old are loaded and appended

#### Scenario: Empty state
- **WHEN** an outreach worker has no active and no recent holds
- **THEN** the page shows a friendly empty state: "No recent bed holds. Search for beds to create one."
- **AND** a link directs them to `/outreach` (bed search)

#### Scenario: Status-specific actions
- **WHEN** a hold is HELD
- **THEN** the row shows "Confirm arrival" and "Cancel hold" actions (existing functionality)
- **WHEN** a hold is CANCELLED_SHELTER_DEACTIVATED
- **THEN** the row shows a reason tag "Shelter deactivated" and a "Find another bed" link

#### Scenario: Accessibility — WCAG AA
- **WHEN** axe-core scans `/outreach/my-holds`
- **THEN** zero violations are reported for wcag2a, wcag2aa, wcag21a, wcag21aa tags
- **AND** all rows are keyboard-reachable with visible focus indicators
- **AND** status tags include text labels (not color-only per WCAG 1.4.1)

#### Scenario: Call-shelter tel: link on every row
- **WHEN** a row renders with a shelter phone number
- **THEN** a "Call shelter" affordance using `tel:` URI is present on the row
- **AND** the touch target is at least 44x44 CSS pixels (WCAG 2.5.5)
- **AND** on mobile devices, tapping initiates the phone call
- **AND** the link is keyboard-reachable and announced to screen readers as "Call {shelterName}"
