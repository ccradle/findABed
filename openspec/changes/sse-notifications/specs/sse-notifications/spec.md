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
