## Overview

Add self-service password change and admin-initiated password reset. Two API endpoints, two UI components, JWT invalidation on change.

## Design Decisions

### Authenticated Password Change

`PUT /api/v1/auth/password` — requires valid JWT + current password in request body.

```json
{
  "currentPassword": "old-password",
  "newPassword": "new-password"
}
```

- Verify current password matches stored hash (bcrypt)
- Validate new password strength (minimum 12 characters per NIST 800-63B, no complexity rules — length > complexity per current guidance)
- Update password hash in database
- Invalidate user's JWT by bumping a `passwordChangedAt` timestamp that token validation checks
- Return 200 with message to re-login
- Rate limit: 5 attempts per 15 minutes (uses existing bucket4j infrastructure)

### Admin Password Reset

`POST /api/v1/users/{id}/reset-password` — requires COC_ADMIN or PLATFORM_ADMIN role.

```json
{
  "newPassword": "temporary-password"
}
```

- Admin sets a temporary password for the user
- Same password strength validation
- Same JWT invalidation (force user to re-login)
- Admin should communicate the temporary password out-of-band (not stored, not emailed)
- User should change password on next login (future: `passwordChangeRequired` flag)

### UI Components

**Change Password** — accessible from user profile dropdown or settings:
- Form: current password, new password, confirm new password
- Client-side validation: passwords match, minimum length
- Success: "Password changed. Please sign in again." → redirect to login

**Admin Reset Password** — button in Admin panel Users tab per user row:
- Modal: new password field + confirm
- Success: "Password reset for {user}. They will need to sign in again."

### JWT Invalidation Strategy

Add `password_changed_at` column to `user` table. On password change, update this timestamp. In `JwtService.validateToken()`, compare the token's `iat` (issued at) against `password_changed_at` — if `iat < password_changed_at`, reject the token (401).

This is simpler than a token blocklist and doesn't require Redis.

### MCP-Ready API Design

Both new endpoints must have `@Operation` annotations with semantic descriptions for AI agent consumption (REQ-MCP-1 through REQ-MCP-3). An MCP agent could invoke password reset for a user as part of an automated onboarding or incident response workflow.

### Observability

Three new Micrometer metrics:
- `fabt.auth.password_change.count` (tag: outcome=success|wrong_password|weak_password) — monitors self-service rotation rate
- `fabt.auth.password_reset.count` (tag: admin_role=COC_ADMIN|PLATFORM_ADMIN) — monitors admin resets; high count in short window is suspicious
- `fabt.auth.token_invalidated.count` (tag: reason=password_change|admin_reset) — tracks forced re-logins

### Rate Limiting

- Password change: 5 attempts per 15 minutes per user (bucket4j, existing JCache infrastructure)
- Admin reset: 10 attempts per 15 minutes per admin IP (prevent mass reset with compromised admin credentials)
- Login rate limit interaction: password change does NOT reset the login attempt counter (separate buckets)

### SSO Users and Password Change

Users who authenticate exclusively via SSO (Google, Microsoft, Keycloak) have no local password hash. The "Change Password" option MUST be hidden for SSO-only users. Detection: if `user.passwordHash` is null or the user's only authentication method is an OAuth2 provider, suppress the UI element. The backend endpoint should also return 409 Conflict if invoked for an SSO-only user ("Password is managed by your SSO provider").

Admin reset follows the same rule — the "Reset Password" button is hidden for SSO-only users in the Admin panel.

### Database Column Naming Convention

The new column follows the existing snake_case convention: `password_changed_at` (matching `password_hash`, `dv_access`, `created_at`). The Java entity field is `passwordChangedAt` per standard JPA camelCase mapping.

### No Email-Based Forgot Password (Deferred)

Email-based "forgot password" flow requires email infrastructure (SMTP, templates, secure token generation, rate limiting). This is deferred to a future change. The admin reset provides the immediate need.

## File Changes

| File | Change |
|------|--------|
| `AuthController.java` or new `PasswordController.java` | Password change + admin reset endpoints with `@Operation` |
| `UserController.java` | Remove "password cannot be changed" comment |
| `JwtService.java` | Check `iat` against `password_changed_at` |
| `User.java` | Add `passwordChangedAt` field |
| New Flyway migration | Add `password_changed_at` column to `user` table |
| `application.yml` | bucket4j filter for password change + admin reset |
| Frontend: new `ChangePasswordModal.tsx` | Self-service password change form |
| Frontend: `AdminPanel.tsx` | "Reset Password" button per user row |
| `frontend/src/i18n/en.json` + `es.json` | i18n strings for password forms |
| `docs/runbook.md` | Password management procedures, metric monitoring |
| `docs/government-adoption-guide.md` | Credential management posture |
| `docs/WCAG-ACR.md` | Accessibility review of new forms (if needed) |
| `README.md` | Project Status update |
| Demo screenshots | Admin Users tab recapture, Change Password modal capture |
