## Why

Sandra's question: "Who do we call at 2am when a coordinator is locked out?" Admin-generated access codes (shipped v0.27.0) answer this when an admin is available. But for office users, self-service email reset eliminates the dependency on an admin being awake. Teresa's city IT procurement checklist assumes self-service password recovery exists. Marcus Webb's pen test flags this as a gap for production readiness.

The backend stubs exist (`forgotPassword()` returns 200 with no action, `resetPassword()` returns 503). The `EmailService` is written. The `one_time_access_code` table and cleanup scheduler exist. The `/auth/capabilities` endpoint already gates the frontend "Forgot Password?" link on SMTP configuration. This change wires the remaining pieces.

## What Changes

- **Password reset token table** — Flyway V39: `password_reset_token` with SHA-256 hashed tokens. Separate from `one_time_access_code` (BCrypt) because reset tokens are high-entropy (256 bits) and use O(1) hash lookup, not O(n) BCrypt comparison.
- **PasswordResetService** — generate token (SecureRandom 32 bytes), SHA-256 hash, store with 30-min expiry, send email. Validate token by SHA-256 hash lookup. Single-use. Increments `tokenVersion` to invalidate all existing JWTs.
- **Wire AuthController stubs** — `forgotPassword()` calls PasswordResetService. `resetPassword()` validates token and sets new password.
- **DV user protection** — email reset is blocked for `dvAccess=true` users. An email to a compromised inbox reveals the user has an account on a DV-serving platform. Admin access codes remain the safe recovery path.
- **TOTP interaction** — email reset changes password only. TOTP stays intact. Next login still requires the second factor. Email compromise alone does not grant access.
- **Email content** — generic subject ("Password Reset Request"), no platform name in subject line. Protects DV survivors whose email may be monitored.
- **tokenVersion fix** — increment `tokenVersion` on all password changes (existing PasswordController bug: currently only sets `passwordChangedAt`).
- **Demo site** — email reset NOT allowlisted in DemoGuard. No SMTP configured. "Forgot Password?" link hidden. Demo visitors use admin access codes. Future ticket: MailHog + DemoGuard allowlist for demo visibility.

## Capabilities

### Modified Capabilities
- `password-recovery`: Email-based reset implemented (was stubbed). DV user gate added.
- `auth-and-roles`: tokenVersion incremented on password change (bug fix).

## Impact

- **Database**: V39 migration — new `password_reset_token` table (id, user_id, tenant_id, token_hash, expires_at, used, created_at).
- **Backend**: PasswordResetService (new), AuthController stubs wired, PasswordController tokenVersion fix.
- **Frontend**: ForgotPasswordPage rewrite (real email form), new ResetPasswordPage (token + new password). Deferred to follow-up if time-constrained.
- **Security**: SHA-256 token hashing (OWASP), DV user blocking (NNEDV), TOTP intact on reset (OWASP MFA), tokenVersion invalidation.
- **Testing**: 10+ integration tests covering happy path, expiry, single-use, enumeration, rate limiting, DV blocking, TOTP interaction.
