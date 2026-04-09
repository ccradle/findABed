## MODIFIED Requirements

### Requirement: bell-badge-persistent-source
Bell badge notification count SHALL be sourced from `GET /api/v1/notifications/count` (persistent DB) on component mount, replacing the in-memory counter that starts at 0 on each login.

#### Scenario: Accurate count after logout/login
- **GIVEN** 3 notifications arrived while the user was logged out
- **WHEN** they log back in
- **THEN** the bell badge SHALL immediately show 3 (from REST), not 0

### Requirement: bell-badge-realtime-increment
SSE events SHALL increment/decrement the count after the initial REST-sourced value. Frontend deduplicates by notification ID.

#### Scenario: New event increments count
- **GIVEN** the bell shows 3 (from REST on login)
- **WHEN** a new SSE notification arrives
- **THEN** the bell SHALL show 4

### Requirement: sse-catchup-batch
`NotificationService.registerEmitter()` SHALL send a batch of unread persistent notifications after the "connected" event.

#### Scenario: Catch-up on reconnect
- **GIVEN** a coordinator reconnects after network interruption
- **WHEN** SSE re-establishes
- **THEN** unread DB notifications SHALL be delivered as a catch-up batch before new real-time events

### Requirement: catchup-standard-format
Catch-up events SHALL use the standard SSE event format. Frontend processes them identically to real-time events.

#### Scenario: Frontend handles catch-up transparently
- **WHEN** catch-up notifications arrive via SSE
- **THEN** the frontend SHALL process them using the same handler as real-time events
