## Context

No password recovery mechanism exists. Locked-out field workers must contact an admin. No 2FA exists for local password users. NIST 800-63B requires MFA for systems at AAL2. City procurement (Teresa) increasingly mandates MFA. The platform handles DV survivor data — SIM swap attacks targeting survivors make SMS-based 2FA unacceptable. The auth architecture is fully stateless JWT with no server-side sessions.

## Goals / Non-Goals

**Goals:**
- Admin-generated temporary access codes for field worker recovery (no email needed)
- Email-based password reset for office users
- TOTP two-factor authentication (Google Authenticator, Authy)
- Recovery codes for 2FA device loss
- NIST 800-63B AAL2 compliance

**Non-Goals:**
- SMS-based OTP (SIM swap risk with DV data — disqualifying)
- WebAuthn/passkeys (Phase 2 — requires challenge-response server state)
- Mandatory 2FA enforcement (optional in Phase 1, enforced later via config)
- Email delivery infrastructure (admin-generated codes are the primary path)

## Decisions

### D1: Two-phase login for TOTP

POST /api/v1/auth/login validates password. If user has `totp_enabled=true`, returns `{mfaRequired: true, mfaToken: "<signed-5-min-token>"}` instead of JWTs. The mfaToken proves "password correct, awaiting second factor." POST /api/v1/auth/verify-totp accepts `{mfaToken, totpCode}` and issues real access + refresh JWTs on success. Zero changes to JwtAuthenticationFilter, SseTokenFilter, or SecurityFilterChain — 2FA is entirely pre-JWT.

### D2: TOTP implementation with dev.samstevens.totp

Library: `dev.samstevens.totp:totp` (~50KB, zero external deps). Database: `totp_secret VARCHAR(64)` (base32-encoded), `totp_enabled BOOLEAN DEFAULT false`, `recovery_codes TEXT` (JSON array of bcrypt-hashed codes). Enrollment: POST /auth/enroll-totp (authenticated) returns QR code URI + base32 secret. User scans QR, enters first code to confirm. Server stores secret only after verification.

### D3: Admin-generated temporary access code

Uses Spring Security OTT (one-time token) with JdbcOneTimeTokenService. Admin hits POST /api/v1/users/{id}/generate-access-code (COC_ADMIN+). Server generates UUID token, stores with 15-min expiry, returns plaintext once. Admin communicates code to worker verbally or via phone. Worker enters code on login screen at POST /api/v1/auth/access-code. Server validates, then requires new password before issuing JWTs.

### D4: Email-based password reset (secondary)

POST /api/v1/auth/forgot-password with `{email, tenantSlug}`. Server generates PasswordResetToken (UUID), stores with 30-min expiry. If email delivery is configured (SMTP), sends reset link. Frontend: "Forgot Password?" link on login page. Always returns 200 regardless of email existence (no account enumeration). Rate limited: 3 attempts per email per hour.

### D5: Recovery codes

8 codes generated at TOTP enrollment. Each is a random 8-character alphanumeric string. Stored bcrypt-hashed (same as passwords). Displayed once at enrollment — user must save. Each code is single-use (marked consumed after use). Admin can regenerate codes (audit-logged, old codes invalidated). Recovery code login: same as TOTP verify endpoint but uses recovery code instead of TOTP code.

### D6: DV-role safeguard on password reset

Password reset for users with `dvAccess=true` requires supervisor confirmation. The generate-access-code endpoint checks if target user has dvAccess — if so, requires the admin to have dvAccess themselves (defense-in-depth: only DV-authorized admins can reset DV-authorized users). Audit-logged with elevated visibility.

### D7: Configuration

`FABT_REQUIRE_MFA` env var: `false` (default in dev/lite), `true` in production. When true, users without 2FA enrolled see a prompt on login to set it up (not blocked, just prompted). Future: hard enforcement where unenrolled users must enroll before accessing any other page.

### D8: TOTP scope — local password login only

TOTP applies ONLY to local password authentication (POST /api/v1/auth/login). It does NOT apply to:
- **API key authentication** — machine-to-machine, no interactive second factor possible
- **OAuth2/SSO login** — 2FA is the IdP's responsibility (Google, Microsoft, Keycloak handle their own MFA)
- **MCP server service accounts** — use API keys, exempt from TOTP

This ensures the MCP agent integration (which uses API keys for backend communication) is unaffected by 2FA.

### D9: mfaToken is NOT a regular JWT — filter chain separation

The `mfaToken` returned during two-phase login is signed with the same secret but carries `purpose: "mfa"` in its claims. It is validated ONLY by the `/auth/verify-totp` endpoint, NOT by `JwtAuthenticationFilter`. The filter must skip tokens with `purpose: "mfa"` — they are not access tokens and should not grant API access.

This also prevents interaction with `tokenVersion` (from admin-user-management). The mfaToken does not carry a `ver` claim and is not subject to version checking — it's a 5-minute ephemeral proof of password correctness, not an authorization token.

### D10: Password-change-required enforcement after access code login

After access-code login, the user receives a JWT with `mustChangePassword: true` claim. A new `PasswordChangeRequiredFilter` (after JwtAuthenticationFilter in the chain) checks this claim. If present and true, all requests except PUT /api/v1/auth/password return 403 with error code `password_change_required`. This forces the user to set a new password before accessing any other functionality.

## Risks / Trade-offs

- **No email infrastructure**: admin-generated codes are the primary recovery path. Email reset is secondary and requires SMTP configuration. This is a feature, not a bug — field workers don't have reliable email access.
- **TOTP secret storage**: stored encrypted in DB. If DB is compromised, attacker has secrets. Mitigated by: TOTP alone is useless without the password (second factor), and DB access implies full compromise already.
- **mfaToken signing**: uses the same JWT secret as access tokens. Could use a separate secret for defense-in-depth. Complexity not justified for Phase 1.
- **PasswordChangeRequiredFilter ordering**: must be after JwtAuthenticationFilter and SseTokenFilter but before the security chain's authorization checks. Test with integration tests that verify the 403 response and the exemption for the password-change endpoint.
