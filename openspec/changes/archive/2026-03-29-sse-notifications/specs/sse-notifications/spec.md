## ADDED Requirements

### Requirement: SSE notification endpoint

The system SHALL provide a Server-Sent Events endpoint at `GET /api/v1/notifications/stream` that pushes domain events to authenticated users in real time.

#### Scenario: Authenticated user connects to SSE stream

- **WHEN** an authenticated user sends GET /api/v1/notifications/stream with a valid Bearer token
- **THEN** the response has Content-Type `text/event-stream` and the connection remains open

#### Scenario: Token passed as query parameter

- **WHEN** an authenticated user connects via `GET /api/v1/notifications/stream?token=<jwt>`
- **THEN** the SseTokenFilter extracts the JWT, sets the SecurityContext, and the connection opens
- **AND** the Authorization header is NOT required (EventSource API limitation)

#### Scenario: Unauthenticated request is rejected

- **WHEN** a request to /api/v1/notifications/stream has no token parameter and no Bearer header
- **THEN** the response is 401 Unauthorized

#### Scenario: Connection timeout and reconnection

- **WHEN** an SSE connection has been idle for 5 minutes
- **THEN** the server closes the connection and the client's EventSource auto-reconnects

#### Scenario: Keepalive prevents proxy timeout

- **WHEN** an SSE connection is open with no domain events for 30 seconds
- **THEN** the server sends an SSE comment (`:keepalive`) that keeps the connection alive without triggering client event handlers

### Requirement: DV referral response notification

The system SHALL push a notification to the outreach worker who created a DV referral when the coordinator accepts or rejects it.

#### Scenario: Referral accepted — outreach worker notified

- **WHEN** a DV coordinator accepts a referral
- **THEN** the outreach worker who created it receives an SSE event with type `dv-referral.responded`, status `ACCEPTED`, and the shelter phone number
- **AND** the event does NOT contain the shelter name or address

#### Scenario: Referral rejected — outreach worker notified

- **WHEN** a DV coordinator rejects a referral with a reason
- **THEN** the outreach worker who created it receives an SSE event with type `dv-referral.responded`, status `REJECTED`, and the rejection reason
- **AND** the event does NOT contain the shelter name or address

#### Scenario: Other users do not receive referral notifications

- **WHEN** a DV referral is accepted for outreach worker A
- **THEN** outreach worker B (same tenant) does NOT receive the notification

### Requirement: DV referral request notification

The system SHALL push a notification to DV-authorized coordinators when a new referral is submitted for their shelter.

#### Scenario: New referral — DV coordinator notified

- **WHEN** an outreach worker submits a DV referral
- **THEN** DV-authorized coordinators in the same tenant receive an SSE event with type `dv-referral.requested`

### Requirement: Availability update notification

The system SHALL push a notification to authenticated users when bed availability changes in their tenant.

#### Scenario: Coordinator updates availability — outreach workers notified

- **WHEN** a coordinator updates bed availability for a shelter
- **THEN** all authenticated users in the same tenant receive an SSE event with type `availability.updated`, including shelterId, shelterName, populationType, and bedsAvailable

### Requirement: Multi-tenant isolation

SSE events SHALL only be delivered to users in the same tenant as the event source.

#### Scenario: Cross-tenant event isolation

- **WHEN** a domain event occurs in Tenant A
- **THEN** users connected via SSE in Tenant B do NOT receive the event

### Requirement: Notification bell UI

The frontend SHALL display a notification bell icon in the header that shows unread notification count and a dropdown of recent notifications.

#### Scenario: Notification badge updates on new event

- **WHEN** an SSE event arrives while the user is on any page
- **THEN** the notification bell badge count increments and the notification appears in the dropdown

#### Scenario: Notification bell is accessible

- **WHEN** the notification count changes
- **THEN** a hidden `aria-live="polite"` region announces the new count to screen readers
- **AND** the bell button's `aria-label` is updated to include the current count

#### Scenario: Client reconnects and catches up

- **WHEN** the SSE connection drops and EventSource reconnects
- **THEN** the client fetches current state via REST (referral list, search results) to close any gap from missed events

### Requirement: SSE connection status indicator

The frontend SHALL display connection status when the SSE connection is not healthy, following the Slack disconnect-only pattern.

#### Scenario: Connected — no indicator shown

- **WHEN** the SSE EventSource is connected and receiving keepalives
- **THEN** no connection status indicator is visible

#### Scenario: Disconnected — banner shown

- **WHEN** the SSE EventSource fires an error or closes
- **THEN** a banner appears below the header: "Reconnecting to live updates..."
- **AND** the banner has `role="status"` and `aria-live="polite"` for screen reader announcement

#### Scenario: Reconnected — brief toast

- **WHEN** the SSE EventSource reconnects after a disconnect
- **THEN** a brief "Reconnected" toast appears for 3 seconds and auto-dismisses
- **AND** the disconnect banner is removed

### Requirement: WAI-ARIA disclosure pattern for notification bell

The notification bell SHALL use the WAI-ARIA disclosure pattern, not the menu pattern.

#### Scenario: Bell button has correct ARIA attributes

- **WHEN** the notification bell is rendered
- **THEN** the button has `aria-expanded="false"` (or `"true"` when open) and `aria-controls` referencing the panel ID
- **AND** the button does NOT have `aria-haspopup`

#### Scenario: Panel uses list semantics, not menu

- **WHEN** the notification dropdown is open
- **THEN** the panel does NOT have `role="menu"` and items do NOT have `role="menuitem"`

#### Scenario: Keyboard navigation

- **WHEN** the user presses Escape while the notification panel is open
- **THEN** the panel closes and focus returns to the bell button

#### Scenario: Focus management on open

- **WHEN** the user opens the notification panel
- **THEN** focus moves to the first notification item (or the panel heading if empty)

### Requirement: Person-centered notification language

Notification messages SHALL be written from the user's perspective, not system-centric.

#### Scenario: Referral response notification uses person-centered language

- **WHEN** a `dv-referral.responded` notification arrives with status ACCEPTED
- **THEN** the notification text reads "A shelter accepted your referral" (not "Referral response received")
- **AND** the status is visible in the notification without requiring a tap

#### Scenario: Availability notification includes shelter name

- **WHEN** an `availability.updated` notification arrives
- **THEN** the notification text includes the shelter name: "Bed availability changed at {shelterName}"

### Requirement: DV safety payload assertion

The DV safety integration test SHALL assert on actual SSE wire data, not just successful send.

#### Scenario: Wire-level DV safety verification

- **WHEN** a `dv-referral.responded` SSE event is delivered
- **THEN** the actual event data lines do NOT contain `shelter_name` or `shelter_address`
