## Why

The Admin panel can create users but cannot edit them after creation. Marcus (CoC Admin) can't fix a wrong role assignment, update a display name, or disable an account when someone leaves. The only path is to delete and recreate, losing referral history and audit context. Teresa (City Official) flags this as a self-service gap in procurement review. For a system handling DV survivor data, the inability to immediately deactivate a compromised account is a security risk.

## What Changes

- **User edit drawer**: slide-out panel from the admin Users table row. Edit display name, email, roles (multi-select), dvAccess toggle. Uses PUT /api/v1/users/{id}.
- **User deactivation**: soft-delete with `status` field (ACTIVE/DEACTIVATED) on app_user. Deactivated users can't log in. Separate confirmation dialog. Admin can reactivate.
- **JWT invalidation on role/status change**: new `token_version` column. Increment on role change, deactivation, or reactivation. JwtAuthenticationFilter checks token version — mismatch rejects the token, forcing re-auth with updated claims.
- **Audit trail**: new `audit_events` table recording who changed what, when, and from where. Actions: ROLE_CHANGED, USER_DEACTIVATED, USER_REACTIVATED, PASSWORD_RESET, DV_ACCESS_CHANGED. Published via Spring application events with async persistence.

## Capabilities

### New Capabilities
- `admin-user-management`: User edit, deactivation/reactivation, JWT invalidation on role change, audit trail for admin actions

### Modified Capabilities
- `sse-notifications`: User deactivation must also complete the user's SSE emitter (disconnect notification stream)

## Impact

- **Backend**: Flyway migrations (user status, token_version, audit_events table), UserService edit/deactivate methods, JwtService tokenVersion claim, JwtAuthenticationFilter version check, AuditEventService
- **Frontend**: User edit drawer component in AdminPanel Users tab, deactivation confirmation dialog, status badge on user rows
- **Security**: Immediate JWT rejection on role/status change via token versioning
- **Testing**: Integration tests for edit, deactivate, JWT invalidation, audit persistence. Playwright e2e for drawer, confirmation dialog, role change reflected after re-login.
