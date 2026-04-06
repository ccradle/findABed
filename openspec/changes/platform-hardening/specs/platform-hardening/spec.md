## ADDED Requirements

### Requirement: API key revocation

The admin panel SHALL allow revoking API keys with immediate effect.

#### Scenario: Admin revokes an API key

- **WHEN** an admin clicks "Revoke" on an API key row and confirms
- **THEN** the key is immediately invalidated and cannot authenticate requests

### Requirement: API key rotation with grace period

The system SHALL support key rotation with configurable overlap.

#### Scenario: Admin rotates an API key

- **WHEN** an admin clicks "Rotate" on an API key row
- **THEN** a new key is generated and displayed once
- **AND** the old key remains valid for the grace period (default 24 hours)

#### Scenario: Old key expires after grace period

- **WHEN** the grace period elapses after key rotation
- **THEN** the old key is automatically invalidated

### Requirement: Webhook subscription delete

The admin panel SHALL allow deleting webhook subscriptions.

#### Scenario: Admin deletes a subscription

- **WHEN** an admin clicks "Delete" on a subscription row and confirms
- **THEN** the subscription is removed and no further deliveries are attempted

### Requirement: Webhook subscription pause/resume

The system SHALL support pausing and resuming webhook delivery.

#### Scenario: Admin pauses a subscription

- **WHEN** an admin toggles a subscription to "Paused"
- **THEN** events matching the subscription are not delivered until resumed
- **AND** events during the pause period are dropped (not queued)

### Requirement: Webhook test event

The system SHALL allow sending test events to a subscription endpoint.

#### Scenario: Admin sends a test event

- **WHEN** an admin clicks "Send Test" and selects an event type
- **THEN** a synthetic event is delivered to the subscription endpoint
- **AND** the delivery result (status code, response time) is shown inline

### Requirement: Webhook delivery log

The system SHALL record recent webhook deliveries for admin visibility.

#### Scenario: Admin views delivery log

- **WHEN** an admin expands a subscription's delivery log
- **THEN** the last 20 deliveries are shown with: event type, status code, response time, timestamp, attempt number

#### Scenario: Auto-disable on consecutive failures

- **WHEN** a subscription has 5 consecutive delivery failures
- **THEN** the subscription is automatically paused and the admin is notified

### Requirement: Server-side retry on availability update conflict

The system SHALL retry availability updates on transient lock contention.

#### Scenario: Advisory lock contention is retried transparently

- **WHEN** an availability update encounters a PessimisticLockingFailureException
- **THEN** the operation is retried up to 3 times with exponential backoff (50ms × 2)
- **AND** the client receives 200 if any retry succeeds

#### Scenario: All retries exhausted returns 409

- **WHEN** all 3 retry attempts fail
- **THEN** the client receives 409 Conflict

### Requirement: ACCESS_CODE_USED audit event has correct actor (#58)

The system SHALL set `actor_user_id` to the target user's ID for self-authentication audit events (ACCESS_CODE_USED), preventing NOT NULL constraint violations on the `audit_events` table.

#### Scenario: Access code login creates audit event with correct actor
- **WHEN** a user authenticates via access code
- **THEN** an `ACCESS_CODE_USED` audit event is inserted into `audit_events`
- **AND** `actor_user_id` equals `target_user_id` (the user authenticating themselves)

#### Scenario: Audit event includes IP address
- **WHEN** a user authenticates via access code from a known IP
- **THEN** the `ACCESS_CODE_USED` audit event records the client IP address

#### Scenario: Access code login does not produce database constraint violation
- **WHEN** a user authenticates via access code
- **THEN** no `null value in column "actor_user_id"` error appears in server logs
- **AND** the audit_events INSERT succeeds

#### Scenario: Standard login audit events are not affected
- **WHEN** a user authenticates via email/password
- **THEN** the `LOGIN_SUCCESS` audit event still has the correct `actor_user_id`
- **AND** no regression in existing audit behavior

### Requirement: My Reservations shelter names are clickable (#64)

Each shelter entry in the My Reservations panel SHALL be a clickable link that navigates to the shelter detail view, providing access to shelter details and directions.

#### Scenario: Shelter name links to shelter details
- **WHEN** an outreach worker views My Reservations after holding a bed
- **THEN** the shelter name SHALL be a clickable link
- **AND** clicking it SHALL scroll to and expand the shelter card in the search results

#### Scenario: Hold countdown timer remains visible after clicking
- **WHEN** the user clicks a shelter name in My Reservations
- **THEN** the hold countdown timer SHALL remain visible in the reservations panel
- **AND** the countdown SHALL continue decrementing

#### Scenario: Directions accessible from reservation
- **WHEN** the user clicks a shelter name in My Reservations
- **THEN** the shelter detail view SHALL include the Directions link
- **AND** the shelter address and phone number SHALL be visible

#### Scenario: Multiple reservations are independently clickable
- **WHEN** the user has multiple active reservations
- **THEN** each shelter name SHALL be an independent clickable link
- **AND** clicking one SHALL not affect the other reservations

#### Scenario: Expired reservation shelter name still clickable
- **WHEN** a reservation has expired (hold timed out)
- **THEN** the shelter name SHALL still be clickable for directions
- **AND** the expired badge SHALL remain visible alongside the link

#### Scenario: Reservation shelter link has data-testid
- **WHEN** My Reservations is rendered
- **THEN** each clickable shelter name SHALL have `data-testid="reservation-shelter-link-{shelterId}"`

### Requirement: SSE bounded event queue

The system SHALL protect against slow SSE clients.

#### Scenario: Slow client event queue overflow

- **WHEN** a client's SSE event queue reaches 10 pending events
- **THEN** the oldest event is dropped to make room for the new event
- **AND** the client can catch up via REST on reconnection
