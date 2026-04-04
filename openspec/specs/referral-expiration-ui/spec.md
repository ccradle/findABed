## Purpose

Real-time expiration UI for DV referral tokens on the coordinator dashboard — countdown timer, disabled buttons, expired badge, SSE event handling, and internationalized text.

## Requirements

### Requirement: Referral countdown timer on coordinator dashboard
The coordinator dashboard SHALL display a live countdown timer for each pending DV referral, decrementing every second from the `remainingSeconds` value returned by the API.

#### Scenario: Countdown ticks every second
- **WHEN** a coordinator views a pending referral with `remainingSeconds: 180`
- **THEN** the display shows "3m remaining" and decrements to "2m 59s" after one second
- **AND** the countdown continues until reaching 0

#### Scenario: Countdown displays minutes and seconds below 5 minutes
- **WHEN** `remainingSeconds` is below 300 (5 minutes)
- **THEN** the display format changes from "{N}m remaining" to "{M}m {S}s remaining"

### Requirement: Expired referral buttons disabled with badge
The coordinator dashboard SHALL disable Accept and Reject buttons and show an "Expired" badge when a DV referral token has expired, either by local countdown reaching zero or by SSE expiration event.

#### Scenario: Countdown reaches zero — buttons disable
- **WHEN** the local countdown timer for a pending referral reaches 0
- **THEN** the Accept and Reject buttons SHALL be visually disabled (grayed, not clickable)
- **AND** an "Expired" badge SHALL appear on the referral card
- **AND** the countdown text SHALL show "Expired"

#### Scenario: SSE expiration event — buttons disable
- **WHEN** the coordinator dashboard receives an SSE `dv-referral.expired` event containing a referral's token ID
- **THEN** the Accept and Reject buttons for that referral SHALL be visually disabled
- **AND** an "Expired" badge SHALL appear on the referral card

#### Scenario: Active referral buttons remain functional
- **WHEN** a pending referral has `remainingSeconds > 0` and no expiration event has been received
- **THEN** the Accept and Reject buttons SHALL remain enabled and clickable

#### Scenario: Expired token API error shows specific message
- **WHEN** a coordinator clicks Accept or Reject on a referral that the backend has already expired
- **AND** the API returns a 409 error with "Token has expired"
- **THEN** the UI SHALL display a message indicating the referral has expired (not a generic error)
- **AND** the referral card SHALL update to the expired visual state

### Requirement: useNotifications hook dispatches expiration events
The `useNotifications.ts` hook SHALL handle `dv-referral.expired` SSE events and dispatch a window event that `CoordinatorDashboard.tsx` listens for.

#### Scenario: SSE expired event dispatched to dashboard
- **WHEN** the SSE connection receives a `dv-referral.expired` event
- **THEN** `useNotifications.ts` SHALL dispatch an `SSE_REFERRAL_EXPIRED` window event with the expired token IDs
- **AND** `CoordinatorDashboard.tsx` SHALL listen for this event and update referral state

#### Scenario: Expired event replayed after reconnection
- **WHEN** the SSE connection reconnects and replays a buffered `dv-referral.expired` event
- **THEN** the hook SHALL dispatch the window event identically to a live event

### Requirement: Internationalized expiration text
All user-facing text introduced by the referral expiration UI SHALL use `react-intl` `FormattedMessage` with IDs defined in both `en.json` and `es.json`.

#### Scenario: Expired badge text is internationalized
- **WHEN** a referral token expires on the coordinator dashboard
- **THEN** the "Expired" badge text SHALL use i18n message ID `referral.expired`
- **AND** the Spanish translation SHALL display the equivalent text

#### Scenario: Expiration error message is internationalized
- **WHEN** a coordinator clicks Accept/Reject on an already-expired token and gets an API error
- **THEN** the error message SHALL use i18n message ID `referral.expiredError`
- **AND** the Spanish translation SHALL display the equivalent text

#### Scenario: Countdown format text is internationalized
- **WHEN** a referral countdown is displayed
- **THEN** the remaining time text SHALL use i18n message IDs `referral.remainingMinutes` and `referral.remainingMinutesSeconds`

### Requirement: data-testid attributes for referral expiration UI
All interactive elements and status indicators in the referral expiration UI SHALL have `data-testid` attributes for Playwright test stability.

#### Scenario: Testable elements present
- **WHEN** the coordinator dashboard renders a pending referral
- **THEN** the following `data-testid` attributes SHALL exist:
  - `referral-countdown-{tokenId}` on the countdown timer
  - `referral-expired-badge-{tokenId}` on the expired badge (when visible)
  - `accept-referral-{tokenId}` on the accept button (existing)
  - `reject-referral-{tokenId}` on the reject button (existing)
