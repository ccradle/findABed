## ADDED Requirements

### Requirement: sse-catchup-on-connect
On SSE emitter registration, the server SHALL query unread notifications from DB and send as SSE events before any real-time events.

#### Scenario: Missed referral delivered on login
- **GIVEN** a coordinator was logged out when a DV referral arrived
- **WHEN** they log in and SSE connects
- **THEN** the pending referral notification SHALL be delivered via SSE catch-up

### Requirement: catchup-severity-ordering
Catch-up notifications SHALL be ordered by severity DESC, created_at DESC — CRITICAL first.

#### Scenario: Critical arrives before info
- **GIVEN** 1 CRITICAL and 3 INFO unread notifications
- **WHEN** SSE catch-up runs
- **THEN** the CRITICAL notification SHALL be the first event after "connected"

### Requirement: catchup-limit
Catch-up SHALL be limited to 50 most recent unread notifications.

#### Scenario: Large backlog truncated
- **GIVEN** 100 unread notifications
- **WHEN** SSE catch-up runs
- **THEN** only the 50 most recent (by severity then date) SHALL be delivered

### Requirement: catchup-deduplication
Frontend SHALL deduplicate catch-up notifications by notification ID.

#### Scenario: Duplicate ignored
- **GIVEN** a notification was already displayed via real-time SSE
- **WHEN** the same notification appears in a catch-up batch
- **THEN** the frontend SHALL display it only once

### Requirement: bell-badge-from-rest
Bell badge count SHALL be initialized from REST on mount, then maintained by SSE events.

#### Scenario: Badge accurate on first render
- **GIVEN** 3 unread notifications in the DB
- **WHEN** the bell component mounts
- **THEN** the badge SHALL show 3 immediately (from REST), not 0
