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

### Requirement: notification-surge-activation
When a surge event is activated, a CRITICAL notification SHALL be created for ALL coordinators in the CoC. When deactivated, an INFO notification SHALL be created.

#### Scenario: Surge activated notifies all coordinators
- **GIVEN** a CoC with 5 coordinators, 2 currently logged out
- **WHEN** a surge is activated
- **THEN** CRITICAL notification rows SHALL exist for all 5 coordinators
- **AND** the 2 logged-out coordinators SHALL see the notification on next login via catch-up

### Requirement: notification-reservation-expiry
When a bed reservation expires, an ACTION_REQUIRED notification SHALL be created for the outreach worker who created the hold.

#### Scenario: Expired hold notifies outreach worker
- **GIVEN** an outreach worker held a bed 80 minutes ago and logged out
- **WHEN** the reservation expires
- **THEN** an ACTION_REQUIRED notification SHALL exist for that worker
- **AND** the worker SHALL see it on next login: "Your bed hold at {shelter} has expired"

### Requirement: notification-cleanup
A `@Scheduled` daily job SHALL delete notifications where read_at IS NOT NULL AND created_at older than 90 days. Unread CRITICAL notifications SHALL never be auto-deleted.

#### Scenario: Old read cleaned, unread critical preserved
- **GIVEN** a read INFO from 91 days ago and an unread CRITICAL from 91 days ago
- **WHEN** the cleanup job runs
- **THEN** the read INFO SHALL be deleted and the unread CRITICAL SHALL be preserved

### Requirement: Notification lifecycle visual distinction
The notification bell SHALL display three visual states per notification: unread, read-but-unacted, and acted. Only unread notifications SHALL count toward the bell badge.

#### Scenario: Bell badge counts unread only
- **WHEN** a user has 3 unread, 5 read-but-unacted, and 2 acted notifications
- **THEN** the bell badge shows "3"

#### Scenario: Acted notifications remain visible in list
- **WHEN** a user opens the bell dropdown
- **THEN** all notifications are visible ordered by createdAt DESC
- **AND** each is rendered in its visual state (unread/read-unacted/acted)

#### Scenario: Filter to hide acted notifications
- **WHEN** the user clicks the "Hide acted" filter toggle in the bell header
- **THEN** only unread and read-but-unacted notifications are shown
- **AND** the filter preference persists across sessions (localStorage)

#### Scenario: Hide-acted filter default is OFF for first-time users
- **WHEN** a user opens the bell for the first time (no `fabt_notif_hide_acted` localStorage key)
- **THEN** the filter is OFF by default — all notifications are visible including acted ones
- **AND** first-time volunteers see the full lifecycle (unread → pending → acted) to learn the system before opting in to filtering

### Requirement: markActed wired from frontend
The frontend SHALL call `PATCH /api/v1/notifications/{id}/acted` after a user successfully completes the terminal action related to the notification. Failed actions SHALL NOT mark notifications acted.

> **Note:** This requirement describes the store-side behavior (persistence and visual states). The notification-deep-linking spec describes the action-flow wiring (which action triggers markActed). The two specs are complementary — implementation satisfies both.

#### Scenario: Referral accept marks related notifications acted
- **WHEN** a coordinator successfully accepts DV referral `abc-123`
- **THEN** all of that coordinator's unread and read-unacted notifications with `payload.referralId = "abc-123"` are marked acted via API call
- **AND** the bell updates to show the acted visual state

#### Scenario: Bulk mark-acted by payload field
- **WHEN** multiple notifications reference the same operational entity (e.g., a referral and its escalation)
- **THEN** a single user action (accept the referral) marks all of them acted together
