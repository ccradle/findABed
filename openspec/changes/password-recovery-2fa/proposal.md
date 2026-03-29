## Why

Darius (Outreach Worker) is in the field at 11pm and forgot his password. His only option is to call Marcus — who may not answer. There is no self-service password recovery. For a platform designed for field workers on mobile phones in crisis situations, this is a critical gap. Additionally, for city procurement (Teresa) and DV data protection (Marcus Webb, pen tester), multi-factor authentication is increasingly mandatory. The platform currently has no 2FA for local password users.

## What Changes

- **Admin-generated temporary access code** (primary recovery): supervisor generates a time-limited, single-use code for a locked-out worker. Uses Spring Security OTT (one-time token) with JDBC persistence. Code expires in 15 minutes. Worker enters code on login screen, then must set a new password. No email infrastructure needed.
- **Email-based password reset** (secondary): standard flow for office users. Forgot Password link on login page. Server generates reset token with 30-min expiry. No account enumeration (always returns 200).
- **TOTP two-factor authentication**: `dev.samstevens.totp` library. Two-phase login — password validates first, returns mfaRequired response, then TOTP code verified before JWTs are issued. Zero changes to JwtAuthenticationFilter or SseTokenFilter. QR code enrollment flow. 8 hashed recovery codes generated at enrollment.
- **DV-role safeguard**: password reset for dvAccess users requires supervisor approval.

## Capabilities

### New Capabilities
- `password-recovery`: Admin-generated OTT access codes, email-based password reset, DV-role supervisor approval
- `totp-2fa`: TOTP enrollment (QR + verify), two-phase login, recovery codes, admin disable/reset

### Modified Capabilities

## Impact

- **Backend**: Flyway migrations (totp_secret, totp_enabled, recovery_codes on app_user; one_time_token table), TotpService, modified AuthController login flow, OTT generation endpoint, email reset endpoint (if email configured)
- **Frontend**: TOTP enrollment page (QR code display, verify), TOTP input screen in login flow, Forgot Password page, Generate Access Code button on admin user row, recovery code display
- **Security**: NIST 800-63B AAL2 compliance with TOTP, no account enumeration, rate limiting on reset attempts
- **Testing**: Backend integration for OTT, TOTP enrollment/verify, two-phase login, recovery codes. Playwright e2e for all UI flows. TotpTestHelper for programmatic code generation in tests.
- **Config**: FABT_REQUIRE_MFA env var (false in dev, true in prod)
