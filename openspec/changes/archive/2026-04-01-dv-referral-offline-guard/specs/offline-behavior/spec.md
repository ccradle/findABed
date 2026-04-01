## MODIFIED Requirements

### Requirement: DV referral button offline guard

When offline, the "Request Referral" button on DV shelter cards SHALL be visually muted and prevent the referral modal from opening.

#### Scenario: Worker taps Request Referral while offline
- **GIVEN** the device is offline (`navigator.onLine === false` or `offline` event fired)
- **WHEN** a DV-authorized outreach worker taps "Request Referral" on a DV shelter card
- **THEN** the referral modal does NOT open
- **AND** an inline action-oriented message appears below the shelter card: "Referral requests need a connection. Call [shelter phone] to request a referral by phone."
- **AND** the shelter phone number is a clickable `tel:` link

#### Scenario: Request Referral button visual state when offline
- **GIVEN** the device is offline
- **THEN** all "Request Referral" buttons use `aria-disabled="true"` (NOT the `disabled` attribute)
- **AND** buttons have reduced opacity (0.5) but remain visible and keyboard-focusable
- **AND** screen readers announce the button as disabled

#### Scenario: Connectivity restored clears offline state
- **GIVEN** the device was offline and referral buttons were aria-disabled
- **WHEN** connectivity is restored (`online` event fires)
- **THEN** all "Request Referral" buttons return to full opacity and normal behavior
- **AND** any inline offline messages are dismissed

### Requirement: Offline banner mentions referral limitation

The offline banner SHALL explicitly state that DV referral requests require a connection.

#### Scenario: Offline banner copy
- **GIVEN** the device is offline
- **THEN** the offline banner reads: "You are offline. Cached searches are still visible. Bed holds and updates will be queued and sent when you reconnect. DV referral requests require a connection."
- **AND** English and Spanish translations are provided

### Requirement: Playwright tests for offline referral guard

#### Scenario: Request Referral button aria-disabled when offline
- **GIVEN** a DV-authorized outreach worker is viewing search results with DV shelters
- **WHEN** the device goes offline
- **THEN** `[data-testid^="request-referral-"]` buttons have `aria-disabled="true"`

#### Scenario: Tapping offline referral button shows inline message
- **GIVEN** the device is offline
- **WHEN** the worker taps a Request Referral button
- **THEN** the referral modal does NOT appear
- **AND** an inline message with a `tel:` link is visible

#### Scenario: Offline banner includes referral language
- **GIVEN** the device is offline
- **THEN** the offline banner contains "DV referral requests require a connection"
