## Context

The password-recovery-2fa change (archived 2026-04-01) implemented admin access codes, TOTP 2FA, and recovery codes. The email reset endpoints were stubbed but never wired. The `EmailService` exists and is ready to send. The `one_time_access_code` table handles admin codes with BCrypt hashing. The `/auth/capabilities` endpoint already gates frontend visibility on SMTP configuration.

The platform handles DV survivor data. An email sent to a compromised inbox is a safety risk — not just a security risk. The design must account for this.

## Goals / Non-Goals

**Goals:**
- Wire `forgotPassword()` and `resetPassword()` stubs to real implementation
- SHA-256 token hashing for O(1) lookup (OWASP recommendation for high-entropy tokens)
- DV user protection: block email reset for dvAccess=true users
- TOTP intact after reset: email compromise alone does not bypass 2FA
- Fix tokenVersion bug in PasswordController
- Generic email content (no platform name in subject)

**Non-Goals:**
- Frontend pages (ForgotPasswordPage rewrite, ResetPasswordPage) — deferred if time-constrained
- SMTP infrastructure provisioning — assume configured via env vars
- Password strength meter (zxcvbn) — future enhancement
- Rate limiting changes — 3/hour already configured

## Design Decisions

### D1: SHA-256 for Token Hashing (Not BCrypt)

Reset tokens are 256 bits of cryptographic randomness — brute force is computationally infeasible (2^256 attempts). BCrypt's slow hashing is designed for low-entropy passwords where brute force is a real threat. For high-entropy tokens, BCrypt wastes CPU without security benefit.

SHA-256 enables O(1) database lookup: hash the incoming token, SELECT WHERE token_hash = ?. The current AccessCodeService uses BCrypt which requires O(n) comparisons (loop through all valid codes and BCrypt-compare each one).

**Source:** [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), [Password Reset Tokens Implementation Guide](https://www.onlinehashcrack.com/guides/password-recovery/password-reset-tokens-secure-implementation-guide.php)

### D2: Separate Table (Not Reusing one_time_access_code)

The `one_time_access_code` table uses BCrypt hashing with an O(n) validation pattern. Mixing SHA-256 and BCrypt in the same table creates confusion about which algorithm applies to which row. A separate `password_reset_token` table with `token_hash VARCHAR(64)` (SHA-256 hex) as a unique indexed column is cleaner.

The cleanup scheduler can be extended to purge both tables.

### D3: DV User Email Reset Blocked

Per [NNEDV Safety Net](https://nnedv.org/content/technology-safety/): an abuser who controls a survivor's email can trigger a password reset, which (a) reveals the survivor has an account on a DV-serving platform, and (b) enables password change. For `dvAccess=true` users:
- `forgotPassword()` returns the same 200 response but does NOT generate a token or send an email
- The user is invisible to the email reset flow — identical to a non-existent account
- Admin access codes remain the safe recovery path (requires DV-authorized admin per D6 of the original spec)

### D4: TOTP Stays Intact After Email Reset

Per [OWASP MFA Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html): "Account recovery is, in essence, a bypass of the main account security protocols." Email reset changes ONLY the password. `totp_enabled` and `totp_secret_encrypted` are untouched. The next login requires both the new password AND the TOTP code.

This means email compromise alone does not grant access to an MFA-protected account. The attacker would need the email AND the authenticator device.

### D5: tokenVersion Increment on All Password Changes

The codebase audit found that `PasswordController.changePassword()` and `resetPassword()` set `passwordChangedAt` but do NOT increment `tokenVersion`. While `JwtAuthenticationFilter` checks `passwordChangedAt` as a secondary defense, `tokenVersion` is the primary JWT invalidation mechanism.

Fix: increment `tokenVersion` in both existing `PasswordController` methods and in the new `PasswordResetService`. This forces all existing JWTs to become invalid immediately.

### D6: Generic Email Content

Per Keisha Thompson (lived experience advisor): the email subject should not identify the platform's purpose. "Finding A Bed Tonight — Password Reset" could be recognizable to an abuser monitoring a survivor's email.

- Subject: "Password Reset Request"
- Body: generic reset link text with no organizational branding
- No mention of shelters, beds, DV, or homelessness

### D7: Token Format and Entropy

- 32 bytes from `SecureRandom` = 256 bits of entropy (exceeds OWASP 128-bit minimum)
- Encoded as URL-safe base64 (43 chars)
- Stored as SHA-256 hex digest (64 chars) in `token_hash` column
- Token appears in email link: `/login/reset-password?token={base64token}`

### D9: Demo Site — Email Reset Not Allowlisted

DemoGuard does NOT allowlist `POST /forgot-password` or `POST /reset-password`. On the demo site (no SMTP configured), `emailResetAvailable=false` → "Forgot Password?" link is hidden in the frontend. This is intentional:
- Demo visitors use admin access codes for the password recovery demo
- No risk of real email delivery from the demo site
- Future ticket: add MailHog to Docker Compose behind `mail` profile, configure SMTP, add to DemoGuard allowlist

For Charlotte pilot: configure real SMTP (Brevo or Resend free tier), no DemoGuard (pilot runs without demo profile).

### D10: No mustChangePassword After Email Reset

The admin access code flow sets `mustChangePassword: true` because the admin knows the temporary password — the user must choose their own. Email reset is different: the user already chose their new password in the reset form. Setting `mustChangePassword` would force them to change it again immediately — poor UX with no security benefit.

The reset endpoint does NOT issue JWTs — it only changes the password and returns 200. The user must then log in normally (password + TOTP if enabled). This full login flow is sufficient re-authentication.

### D8: Account Enumeration Prevention

- `forgotPassword()` always returns 200 with identical message regardless of: email exists, email doesn't exist, DV user blocked, SMTP not configured
- Response timing must be consistent. Mechanism: record `System.nanoTime()` at method entry. Before returning, compute elapsed time. If elapsed < 250ms, `Thread.sleep(250 - elapsed)` to pad to a constant floor. 250ms is sufficient to cover token generation + SHA-256 hash + DB insert. The actual email send happens asynchronously (virtual thread) so it doesn't affect response time.
- Rate limiting (3/hour per IP, already configured) prevents enumeration via repeated attempts
