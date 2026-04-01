## Why

Darius (Outreach Worker) is in the field at 11pm and forgot his password. His only option is to call Marcus — who may not answer. There is no self-service password recovery. For a platform designed for field workers on mobile phones in crisis situations, this is a critical gap. Additionally, for city procurement (Teresa) and DV data protection (Marcus Webb, pen tester), multi-factor authentication is increasingly mandatory. The platform currently has no 2FA for local password users.

## What Changes

- **Admin-generated temporary access code** (primary recovery): supervisor generates a time-limited, single-use code for a locked-out worker. Uses Spring Security OTT (one-time token) with JDBC persistence. Code expires in 15 minutes. Worker enters code on login screen, then must set a new password. No email infrastructure needed.
- **Email-based password reset** (secondary): standard flow for office users. Forgot Password link on login page. Server generates reset token with 30-min expiry. No account enumeration (always returns 200).
- **TOTP two-factor authentication**: `dev.samstevens.totp` library. Two-phase login — password validates first, returns mfaRequired response, then TOTP code verified before JWTs are issued. Zero changes to JwtAuthenticationFilter or SseTokenFilter. QR code enrollment flow. 8 hashed backup codes generated at enrollment.
- **TOTP secret encryption at rest** (CRITICAL): AES-256-GCM encryption with key from env var. Plaintext secrets never stored in database, never logged. (Marcus Webb: a DB dump without the key reveals nothing.)
- **mfaToken security**: single-use (jti blocklist), 5-attempt rate limit on verify-totp (prevents brute-force of 6-digit TOTP space).
- **DV-role safeguard**: password reset for dvAccess users requires supervisor approval.
- **User-facing language**: "Sign-in verification" not "2FA" (Simone/Devon). "Backup codes" not "recovery codes."
- **Conditional Forgot Password**: hidden when SMTP not configured. Auth capabilities endpoint lets frontend adapt.
- **CJIS AAL2 alignment**: documented for government adoption guide (Casey: CJIS mandated AAL2 MFA as of Oct 2024).

## Capabilities

### New Capabilities
- `password-recovery`: Admin-generated OTT access codes, email-based password reset, DV-role supervisor approval
- `totp-2fa`: TOTP enrollment (QR + verify), two-phase login, recovery codes, admin disable/reset

### Modified Capabilities

## Impact

- **Backend**: Flyway V31-V32, TotpService + TotpEncryptionService (AES-256-GCM), modified login flow, mfaToken single-use blocklist, PasswordChangeRequiredFilter, OTT generation, email reset, cleanup scheduler
- **Frontend**: TOTP enrollment page (QR + backup codes), two-phase login screen, Forgot Password (conditional), Access Code login, admin access code modal, backup code regeneration
- **Security**: NIST 800-63B AAL2, TOTP secrets encrypted at rest, mfaToken single-use + rate-limited, no account enumeration, CJIS alignment documented
- **Testing**: 13 backend integration tests (positive + negative + security + concurrency), 7+ Playwright E2E (including full-flow TOTP enrollment, two-phase login, and access code), TotpTestHelper. Gatling deferred.
- **Testing gap fix (D16/D17)**: TOTP encryption key must be configured in dev/test/CI — without it, ALL TOTP tests skip silently and the core 2FA feature has zero E2E verification. Dev key in dev-start.sh, test key in BaseIntegrationTest, CI key in workflow.
- **Config**: FABT_REQUIRE_MFA, FABT_TOTP_ENCRYPTION_KEY env vars
- **Docs**: FOR-DEVELOPERS, FOR-COORDINATORS, FOR-CITIES, government adoption guide, oracle runbook
