## ADDED Requirements

### Requirement: notification-list-endpoint
`GET /api/v1/notifications` SHALL return notifications for the authenticated user ordered by severity DESC, created_at DESC. Supports `?unread=true` filter.

#### Scenario: Fetch unread only
- **GIVEN** a coordinator with 2 unread and 3 read notifications
- **WHEN** GET /api/v1/notifications?unread=true
- **THEN** 2 notifications SHALL be returned, CRITICAL severity first

### Requirement: notification-count-endpoint
`GET /api/v1/notifications/count` SHALL return `{"unread": N}` for bell badge.

#### Scenario: Count reflects persistent state
- **GIVEN** 5 unread notifications created while user was logged out
- **WHEN** GET /api/v1/notifications/count
- **THEN** response SHALL be {"unread": 5}

### Requirement: notification-mark-read
`PATCH /api/v1/notifications/{id}/read` SHALL set read_at. Idempotent (204).

#### Scenario: Mark as read
- **WHEN** PATCH called on an unread notification
- **THEN** read_at SHALL be set and response SHALL be 204
- **AND** calling again SHALL return 204 (idempotent)

### Requirement: notification-mark-acted
`PATCH /api/v1/notifications/{id}/acted` SHALL set acted_at and read_at for CRITICAL notifications.

#### Scenario: Act on critical notification
- **WHEN** coordinator accepts a referral and PATCH /acted is called
- **THEN** both acted_at and read_at SHALL be set

### Requirement: notification-mark-all-read
`POST /api/v1/notifications/read-all` SHALL mark all unread as read for the authenticated user (204).

#### Scenario: Mark all read
- **GIVEN** 5 unread notifications
- **WHEN** POST /read-all
- **THEN** all 5 SHALL have read_at set and subsequent count SHALL return 0

### Requirement: notification-demo-guard
Notification mutation endpoints (read, acted, read-all) SHALL be allowlisted in demo mode.

#### Scenario: Demo site allows marking notifications
- **GIVEN** the demo profile is active
- **WHEN** PATCH /notifications/{id}/read is called
- **THEN** response SHALL be 204 (not 403 demo_restricted)
