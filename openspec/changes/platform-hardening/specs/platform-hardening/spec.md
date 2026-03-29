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

### Requirement: SSE bounded event queue

The system SHALL protect against slow SSE clients.

#### Scenario: Slow client event queue overflow

- **WHEN** a client's SSE event queue reaches 10 pending events
- **THEN** the oldest event is dropped to make room for the new event
- **AND** the client can catch up via REST on reconnection
