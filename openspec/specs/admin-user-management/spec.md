# admin-user-management Specification

## Purpose
TBD - created by archiving change admin-user-management. Update Purpose after archive.
## Requirements
### Requirement: Edit user details

The admin panel SHALL allow COC_ADMIN and PLATFORM_ADMIN to edit user details via a slide-out drawer.

#### Scenario: Admin edits user display name and roles

- **WHEN** an admin clicks "Edit" on a user row in the Users tab
- **THEN** a slide-out drawer opens with editable fields: display name, email, roles, dvAccess
- **AND** saving sends PUT /api/v1/users/{id} and the drawer closes with a success message

#### Scenario: Role change invalidates user's JWT

- **WHEN** an admin changes a user's roles
- **THEN** the user's `token_version` is incremented
- **AND** the user's existing JWTs are rejected on next request, forcing re-authentication with updated roles

#### Scenario: dvAccess change is audit-logged

- **WHEN** an admin toggles a user's dvAccess flag
- **THEN** an audit event is recorded with action DV_ACCESS_CHANGED, old value, new value, actor, and timestamp

### Requirement: Deactivate and reactivate users

The admin panel SHALL support soft-deactivation of user accounts.

#### Scenario: Admin deactivates a user

- **WHEN** an admin clicks "Deactivate" on a user row
- **THEN** a confirmation dialog appears explaining the consequences
- **AND** on confirmation, the user's status is set to DEACTIVATED, token_version is incremented, and an audit event is recorded

#### Scenario: Deactivated user cannot log in

- **WHEN** a deactivated user attempts to log in
- **THEN** the response is 401 with message "Account deactivated. Contact your administrator."

#### Scenario: Deactivated user's JWT is rejected

- **WHEN** a deactivated user makes an API request with a previously valid JWT
- **THEN** the request is rejected (token_version mismatch)

#### Scenario: Deactivated user's SSE connection is closed

- **WHEN** a user is deactivated while connected via SSE
- **THEN** their SseEmitter is completed and removed from the emitter map

#### Scenario: Admin reactivates a user

- **WHEN** an admin clicks "Reactivate" on a deactivated user
- **THEN** the user's status is set to ACTIVE, token_version is incremented, and an audit event is recorded

### Requirement: JWT token versioning

The system SHALL invalidate JWTs when a user's roles, dvAccess, or status change.

#### Scenario: JWT with stale token_version is rejected

- **WHEN** a request includes a JWT with a `ver` claim that does not match the user's current `token_version`
- **THEN** the request is rejected with 401
- **AND** the user must re-authenticate to get a new JWT with the current token_version

### Requirement: Admin audit trail

The system SHALL record audit events for all admin actions on user accounts.

#### Scenario: Audit event recorded on role change

- **WHEN** an admin changes a user's roles
- **THEN** an audit event is persisted with: action=ROLE_CHANGED, actor_user_id, target_user_id, details={oldRoles, newRoles}, ip_address, timestamp

#### Scenario: Audit event recorded on password reset

- **WHEN** an admin resets a user's password
- **THEN** an audit event is persisted with action=PASSWORD_RESET

#### Scenario: Audit events are queryable

- **WHEN** an admin queries audit events for a target user
- **THEN** all audit events for that user are returned in reverse chronological order

