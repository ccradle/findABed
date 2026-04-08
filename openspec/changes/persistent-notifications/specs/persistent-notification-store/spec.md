## ADDED Requirements

### Requirement: notification-table-schema
A `notification` table SHALL store all actionable notifications with columns: id (UUID PK), tenant_id (FK), recipient_id (FK to app_user), type (VARCHAR), severity (VARCHAR: INFO, ACTION_REQUIRED, CRITICAL), payload (JSONB), read_at (TIMESTAMPTZ nullable), acted_at (TIMESTAMPTZ nullable), created_at (TIMESTAMPTZ), expires_at (TIMESTAMPTZ nullable). Flyway migration V35.

#### Scenario: Notification row created on DV referral request
- **WHEN** a DV outreach worker submits a referral
- **THEN** a notification row SHALL exist with recipient_id = coordinator, type = 'referral.requested', severity = 'ACTION_REQUIRED'
- **AND** the JSONB payload SHALL contain referralId and shelterId but no PII

### Requirement: notification-unread-index
A partial index on `(recipient_id, created_at DESC) WHERE read_at IS NULL` SHALL exist for fast unread queries.

#### Scenario: Unread count query performance
- **GIVEN** a coordinator with 3 unread and 50 read notifications
- **WHEN** the unread count is queried
- **THEN** the result SHALL be 3

### Requirement: notification-rls
Row Level Security SHALL be enabled on the notification table. Policy: recipient_id must match the authenticated user. Enforced via fabt_app role.

#### Scenario: Cross-user access blocked
- **GIVEN** user A has a notification
- **WHEN** user B queries notifications via fabt_app
- **THEN** user A's notification SHALL NOT be visible

### Requirement: notification-write-through
`NotificationPersistenceService.send()` SHALL write a DB row AND push to the SSE emitter if the user is connected.

#### Scenario: Connected user receives real-time + persistent notification
- **GIVEN** a coordinator is connected via SSE
- **WHEN** a referral notification is created
- **THEN** the notification SHALL be persisted in DB AND delivered via SSE

#### Scenario: Disconnected user receives notification on next login
- **GIVEN** a coordinator is NOT connected via SSE
- **WHEN** a referral notification is created
- **THEN** the notification SHALL be persisted in DB and delivered via catch-up on next SSE connect

### Requirement: notification-zero-pii
JSONB payload SHALL contain zero PII — only opaque identifiers (referralId, shelterId, status). Designed to support VAWA/FVPSA compliance requirements.

#### Scenario: Payload contains no PII
- **WHEN** any notification is created
- **THEN** the JSONB payload SHALL NOT contain names, addresses, phone numbers, or demographic data

### Requirement: notification-cleanup
A `@Scheduled` daily job SHALL delete notifications where read_at IS NOT NULL AND created_at older than 90 days. Unread CRITICAL notifications SHALL never be auto-deleted.

#### Scenario: Old read cleaned, unread critical preserved
- **GIVEN** a read INFO from 91 days ago and an unread CRITICAL from 91 days ago
- **WHEN** the cleanup job runs
- **THEN** the read INFO SHALL be deleted and the unread CRITICAL SHALL be preserved
