## MODIFIED Requirements

### Requirement: notification-rls (MODIFIED)
Row Level Security SHALL remain ENABLED on the notification table. All 4 policies SHALL use `USING (true)` — unrestricted for `fabt_app`. Per-user access control SHALL be enforced by the service layer, not the database.

#### Scenario: System operation sees all notifications
- **GIVEN** the escalation job runs without user context
- **WHEN** it queries for existing notifications (dedup check)
- **THEN** the query SHALL return matching rows regardless of recipient_id

#### Scenario: Cleanup job deletes across all users
- **GIVEN** the cleanup job runs without user context
- **WHEN** it deletes read notifications older than 90 days
- **THEN** the DELETE SHALL affect rows for all users, not just one

#### Scenario: INSERT RETURNING works without set_config
- **GIVEN** NotificationPersistenceService.send() creates a notification for a different user
- **WHEN** Spring Data JDBC executes INSERT ... RETURNING *
- **THEN** the operation SHALL succeed without requiring set_config('app.current_user_id')

### Requirement: notification-service-layer-isolation (ADDED)
The service layer SHALL enforce per-user notification access. NotificationController SHALL extract userId from JWT authentication for all read and mutation operations.

#### Scenario: User can only read own notifications via REST
- **GIVEN** coordinator A has 2 notifications and coordinator B has 3
- **WHEN** coordinator A calls GET /api/v1/notifications
- **THEN** only coordinator A's 2 notifications SHALL be returned

#### Scenario: User cannot mark another user's notification via REST
- **GIVEN** coordinator A has notification X
- **WHEN** coordinator B calls PATCH /api/v1/notifications/X/read
- **THEN** the operation SHALL have no effect on notification X (repository query includes recipient_id filter)

#### Scenario: Cross-tenant isolation via service layer
- **GIVEN** tenant A coordinator has notifications, tenant B coordinator has notifications
- **WHEN** tenant A coordinator calls GET /api/v1/notifications
- **THEN** only tenant A notifications SHALL be returned (controller operates within tenant context)

### Requirement: notification-no-reset-role (ADDED)
No notification code path SHALL use RESET ROLE, raw JDBC connections, or set_config overrides. All notification queries SHALL use standard Spring Data JDBC repository methods or JdbcTemplate through the normal DataSource.

#### Scenario: Escalation dedup uses repository
- **WHEN** the escalation job checks for existing notifications
- **THEN** it SHALL use NotificationRepository.existsByTypeAndReferralId() without RESET ROLE

#### Scenario: Cleanup uses repository
- **WHEN** the cleanup job deletes old notifications
- **THEN** it SHALL use NotificationRepository.deleteOldRead() without RESET ROLE or @Transactional wrapping

#### Scenario: send() uses repository
- **WHEN** NotificationPersistenceService creates a notification
- **THEN** it SHALL use NotificationRepository.save() without set_config override
