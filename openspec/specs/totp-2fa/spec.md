## Purpose

TOTP two-factor authentication ("sign-in verification") via authenticator apps. Designed to support NIST 800-63B AAL2 and CJIS Security Policy MFA requirements. TOTP secrets AES-256-GCM encrypted at rest.

## ADDED Requirements

### Requirement: TOTP enrollment
Authenticated users can enroll via POST /enroll-totp → QR code + secret (encrypted, stored pending) → POST /confirm-totp-enrollment with first valid code → 8 backup codes returned (displayed once, bcrypt-hashed). Concurrent enrollment replaces previous pending secret.

### Requirement: Two-phase TOTP login
POST /auth/login with TOTP-enabled user returns `{mfaRequired: true, mfaToken}`. POST /auth/verify-totp accepts mfaToken + 6-digit TOTP code (or 8-char backup code). mfaToken is single-use (jti blocklist) with 5-attempt rate limit. Clock drift ±1 step tolerance (RFC 6238). JwtAuthenticationFilter skips tokens with `purpose: "mfa"`.

### Requirement: Recovery code regeneration
Users and admins can regenerate backup codes, invalidating all previous codes. Audit-logged.

### Requirement: Admin can disable 2FA
COC_ADMIN+ can DELETE /auth/totp/{id} to clear TOTP enrollment for locked-out users. Audit-logged.

### Requirement: TOTP secret encrypted at rest
AES-256-GCM encryption with key from `FABT_TOTP_ENCRYPTION_KEY` env var. Key must NOT be the dev-start.sh key in production (runtime check rejects it). Plaintext secrets never logged or persisted unencrypted.

### Requirement: TOTP encryption key in all environments
Dev: dev-start.sh exports dev key. Test: BaseIntegrationTest sets via DynamicPropertySource. CI: workflow env var. Production: unique key in .env.prod (generated with openssl rand -base64 32).

### Requirement: Full-flow E2E verification
Playwright tests complete full TOTP enrollment, two-phase login, and access code flows with real TOTP code generation (otpauth npm library). No tests skip silently.
