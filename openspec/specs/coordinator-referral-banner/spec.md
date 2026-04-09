## ADDED Requirements

### Requirement: pending-count-endpoint
`GET /api/v1/dv-referrals/pending/count` SHALL return total PENDING referral count across the coordinator's assigned DV shelters.

#### Scenario: Count reflects all assigned shelters
- **GIVEN** a coordinator assigned to 3 DV shelters with 1, 0, and 1 pending referrals
- **WHEN** GET /dv-referrals/pending/count
- **THEN** response SHALL be {"count": 2}

### Requirement: dashboard-referral-banner
The coordinator dashboard SHALL show a persistent banner when pending count > 0.

#### Scenario: Banner appears on login with pending referrals
- **GIVEN** 2 pending DV referrals
- **WHEN** the coordinator dashboard loads
- **THEN** a red banner SHALL display "2 referrals waiting for review"

#### Scenario: Banner not dismissable
- **GIVEN** the banner is showing
- **WHEN** the coordinator tries to dismiss it
- **THEN** the banner SHALL remain visible until all referrals are actioned

### Requirement: banner-click-navigation
Clicking the banner SHALL scroll to the first DV shelter with pending referrals.

#### Scenario: Click navigates to shelter
- **WHEN** the coordinator clicks the banner
- **THEN** the page SHALL scroll to and expand the first DV shelter card with pending referrals

### Requirement: collapsed-card-badge
Pending referral badges SHALL be visible on COLLAPSED shelter cards for DV shelters.

#### Scenario: Badge on collapsed card
- **GIVEN** a DV shelter with 1 pending referral
- **WHEN** the coordinator views the dashboard with the shelter card collapsed
- **THEN** the card SHALL show a "1 referral" badge without expansion

### Requirement: banner-realtime-update
The banner SHALL update in real-time via SSE events without page reload.

#### Scenario: New referral increments banner
- **GIVEN** the banner shows "1 referral waiting"
- **WHEN** a new referral SSE event arrives
- **THEN** the banner SHALL update to "2 referrals waiting"

### Requirement: banner-wcag
The banner SHALL use role="alert", color tokens for dark mode, and meet WCAG 2.1 AA contrast and touch target requirements.

#### Scenario: Screen reader announces banner
- **WHEN** the banner appears
- **THEN** screen readers SHALL announce the content via role="alert"
