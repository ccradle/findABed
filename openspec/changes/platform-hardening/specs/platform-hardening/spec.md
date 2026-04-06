## ADDED Requirements

### Requirement: API key revocation

The admin panel SHALL allow revoking API keys with immediate effect.

#### Scenario: Admin revokes an API key
- **WHEN** an admin clicks "Revoke" on an API key row and confirms
- **THEN** the key is immediately invalidated and cannot authenticate requests

#### Scenario: Revoked key returns 401 on subsequent use
- **WHEN** a revoked API key is used in an `X-API-Key` header
- **THEN** the system SHALL return 401 Unauthorized

#### Scenario: Revoke non-existent key returns 404
- **WHEN** an admin attempts to revoke a key that does not exist
- **THEN** the system SHALL return 404 Not Found

#### Scenario: Non-admin cannot revoke keys
- **WHEN** a COORDINATOR or OUTREACH_WORKER attempts to revoke an API key
- **THEN** the system SHALL return 403 Forbidden

#### Scenario: Revoking an already-revoked key is idempotent
- **WHEN** an admin revokes a key that is already revoked
- **THEN** the system SHALL return 200 (no error)

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

#### Scenario: Admin re-enables auto-disabled subscription
- **WHEN** an admin resumes a subscription that was auto-disabled
- **THEN** the consecutive failure counter SHALL reset to 0
- **AND** delivery attempts SHALL resume on the next matching event

#### Scenario: Successful delivery resets failure counter
- **WHEN** a delivery succeeds after 3 consecutive failures
- **THEN** the consecutive failure counter SHALL reset to 0

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

#### Scenario: Reservation for shelter not in current search results
- **WHEN** the user has a reservation for a shelter not matching the current population filter
- **THEN** the shelter name SHALL still be clickable
- **AND** clicking it SHALL clear the filter or show a message that the shelter is not in current results

### Requirement: SSE bounded event queue (PHASE 2)

The system SHALL protect against slow SSE clients. This requirement is implemented in Phase 2, after all other platform-hardening tasks are verified green.

#### Scenario: Slow client event queue overflow
- **WHEN** a client's SSE event queue reaches 10 pending events
- **THEN** the oldest event is dropped to make room for the new event
- **AND** the client can catch up via REST on reconnection

#### Scenario: Heartbeats have lower priority than real events
- **WHEN** a slow client's queue is full
- **AND** a new real event arrives (availability.updated, dv-referral.*)
- **THEN** the system SHALL drop a heartbeat from the queue before dropping a real event

#### Scenario: Only the sender thread writes to the emitter
- **WHEN** events are queued for delivery to a client
- **THEN** only the per-emitter sender thread SHALL call `emitter.send()`
- **AND** the heartbeat scheduler SHALL enqueue heartbeats, not send directly

#### Scenario: Sender thread cleans up on IOException
- **WHEN** the sender thread encounters an IOException during `emitter.send()`
- **THEN** the emitter SHALL be removed from the registry BEFORE calling `completeWithError()`
- **AND** the sender thread SHALL terminate cleanly
- **AND** no `IllegalStateException` or cascading callback errors SHALL occur

#### Scenario: Sender thread exits on emitter removal
- **WHEN** an emitter is removed (user disconnect, shutdown, heartbeat failure detection)
- **THEN** the corresponding sender thread SHALL receive a poison pill and exit
- **AND** no thread leak SHALL occur

#### Scenario: Graceful shutdown completes all sender threads
- **WHEN** the application shuts down (@PreDestroy)
- **THEN** all sender threads SHALL terminate within 5 seconds
- **AND** all emitters SHALL be completed

#### Scenario: SSE regression — existing tests pass after backpressure change
- **WHEN** the bounded queue implementation is complete
- **THEN** all existing `SseNotificationIntegrationTest` tests SHALL pass
- **AND** all existing `SseStabilityTest` tests SHALL pass
- **AND** all `sse-cache-regression` Playwright tests SHALL pass through nginx
- **AND** the `sse.connections.active` Grafana gauge SHALL be flat (not sawtooth) after 5 minutes

#### Scenario: Fast clients unaffected under load with slow clients present
- **WHEN** 200 SSE clients are connected and 10 are deliberately throttled
- **THEN** the remaining 190 fast clients SHALL receive events within normal SLO (p95 < 500ms)
- **AND** heartbeat delivery to fast clients SHALL not be delayed by slow client queues
