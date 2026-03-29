## Context

The Admin panel Users tab shows a read-only table with Create User and Reset Password. Users cannot be edited, deactivated, or audited after creation. The backend has PUT /api/v1/users/{id} but it's not wired to any frontend form. JWT tokens embed roles but have no invalidation mechanism beyond the 15-minute expiry and password-change timestamp check.

## Goals / Non-Goals

**Goals:**
- Edit user details (name, email, roles, dvAccess) from the admin panel
- Deactivate/reactivate users with soft-delete (preserves referral history, audit trail)
- Immediately invalidate JWTs when roles or status change (tokenVersion mechanism)
- Record all admin actions in an audit trail (who changed what, when, from where)

**Non-Goals:**
- User self-service profile editing (separate change)
- Bulk user import/export
- User activity dashboard (login history, last active)
- Hard-delete users (soft-delete with deferred anonymization only)

## Decisions

### D1: Slide-out drawer for user editing

Edit via a right-side drawer panel triggered from the user table row. The table stays visible in the background for context. Fields: display name, email, role dropdown (multi-select), dvAccess toggle. Not a full page (too few fields) and not inline editing (too many fields for a table cell).

### D2: Soft-delete with status enum

New `status` column on `app_user`: `ACTIVE` (default), `DEACTIVATED`. Deactivated users cannot log in (AuthService rejects at login), existing JWTs are invalidated via tokenVersion. Admin can reactivate. No hard-delete — preserves referential integrity for reservations, referrals, and audit events. Future: scheduled PII anonymization after 30 days for GDPR.

### D3: Token versioning for JWT invalidation

New `token_version INTEGER DEFAULT 0` column on `app_user`. JwtService embeds `ver` claim in JWT. JwtAuthenticationFilter compares `ver` claim against DB value on each request (cached with JWT claims in Caffeine cache — same pattern as passwordChangedAt check). Mismatch rejects the token. Increment on: role change, dvAccess change, deactivation, reactivation. This forces re-auth, which issues a new JWT with updated claims.

### D4: Audit events table

New `audit_events` table: `id UUID`, `timestamp TIMESTAMPTZ`, `actor_user_id UUID`, `target_user_id UUID`, `action VARCHAR` (enum), `details JSONB` (old/new values), `ip_address VARCHAR`. Published via Spring application events (`AuditEvent` record + `@EventListener`), persisted asynchronously to avoid slowing admin operations. Retained indefinitely (security audit trail, not subject to GDPR erasure).

### D5: Deactivation also disconnects SSE

When a user is deactivated, NotificationService must complete their SSE emitter (if connected) to immediately disconnect the notification stream. Use the existing `emitters.remove(userId)` + `emitter.complete()` pattern.

### D6: i18n key naming convention (applies to all v0.19.0 changes)

Establish namespace convention for all new i18n keys: `<module>.<feature>.<element>`. Examples:
- `admin.user.editTitle`, `admin.user.deactivateConfirm`, `admin.user.statusActive`
- `shelter.edit.saveSuccess`, `shelter.edit.dvConfirmation`
- `auth.totp.enrollTitle`, `auth.totp.verifyPrompt`, `auth.recovery.codeExpired`
- `admin.apiKey.revokeConfirm`, `admin.webhook.testSuccess`

Document in `en.json` header comment for all v0.19.0 developers.

## Risks / Trade-offs

- **Token version DB check on every request**: adds a cache lookup per request. Mitigated by existing Caffeine JWT claims cache (already does passwordChangedAt check in the same lookup).
- **Soft-delete complexity**: deactivated users still occupy DB rows. Mitigated by status filter in all user queries and future scheduled anonymization.
- **Audit events table growth**: unbounded append-only. Mitigated by BRIN index on timestamp for range queries, future archival policy.
