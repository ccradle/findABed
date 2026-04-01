## Tasks

### Setup

- [ ] T-0: Create branch `feature/password-recovery-2fa` in code repo (`finding-a-bed-tonight`)

### Backend — Database (Flyway range: V31–V32)

- [ ] T-1: Flyway V31: add `totp_secret_encrypted VARCHAR(255)` (AES-256-GCM, NOT plaintext), `totp_enabled BOOLEAN DEFAULT false`, `recovery_codes TEXT` to `app_user`
- [ ] T-2: Flyway V32: create `one_time_access_code` table (id UUID, user_id UUID, code_hash VARCHAR, expires_at TIMESTAMPTZ, used BOOLEAN DEFAULT false)
- [ ] T-3: Add `dev.samstevens.totp:totp` and `spring-boot-starter-mail` dependencies to pom.xml

### Backend — TOTP Encryption (D11 — CRITICAL)

- [ ] T-4: Create `TotpEncryptionService` — AES-256-GCM encrypt/decrypt. Key from `FABT_TOTP_ENCRYPTION_KEY` env var (32 bytes, base64). Never log plaintext secrets.
- [ ] T-5: Startup validation: fail fast if `FABT_TOTP_ENCRYPTION_KEY` is missing or < 32 bytes in production profile

### Backend — TOTP Service

- [ ] T-6: Create `TotpService` — generateSecret(), generateQrUri(), verifyCode(±1 step for clock drift), generateRecoveryCodes(), verifyRecoveryCode()
- [ ] T-7: POST /api/v1/auth/enroll-totp (authenticated) — return QR URI + secret, do NOT store until verified. Only one pending enrollment per user (concurrent enrollment replaces previous).
- [ ] T-8: POST /api/v1/auth/confirm-totp-enrollment — verify first code, store encrypted secret (D11), return 8 backup codes
- [ ] T-9: DELETE /api/v1/users/{id}/totp (COC_ADMIN+) — disable 2FA, clear encrypted secret, audit log
- [ ] T-10: POST /api/v1/auth/regenerate-recovery-codes (authenticated) — invalidate old codes, return 8 new, audit log
- [ ] T-11: POST /api/v1/users/{id}/regenerate-recovery-codes (COC_ADMIN+) — admin-initiated, same behavior

### Backend — Two-Phase Login

- [ ] T-12: Modify `AuthController.login()` — if totp_enabled, return `{mfaRequired: true, mfaToken}` instead of JWTs. mfaToken is a signed 5-min JWT with userId + purpose="mfa" + jti (for single-use tracking)
- [ ] T-13: POST /api/v1/auth/verify-totp — validate mfaToken + TOTP code (or backup code), issue real JWTs. On success, add jti to blocklist (Caffeine cache, 5-min TTL). Reject replayed mfaTokens.
- [ ] T-14: Rate limit verify-totp: 5 attempts per mfaToken (tracked by jti). After 5 failures, mfaToken invalidated — user must re-enter password.
- [ ] T-15: JwtAuthenticationFilter must skip tokens with `purpose: "mfa"` — they are NOT access tokens

### Backend — Admin Access Code

- [ ] T-16: `AccessCodeService` — generate single-use code (UUID), store hashed with 15-min expiry
- [ ] T-17: POST /api/v1/users/{id}/generate-access-code (COC_ADMIN+) — return plaintext code once. If target has dvAccess, require admin to also have dvAccess (D6)
- [ ] T-18: POST /api/v1/auth/access-code — validate code, authenticate user, issue JWT with `mustChangePassword: true`
- [ ] T-19: `PasswordChangeRequiredFilter` (after JwtAuthenticationFilter) — if `mustChangePassword: true`, block all requests except PUT /api/v1/auth/password with 403 `password_change_required`

### Backend — Email Reset (Secondary)

- [ ] T-20: GET /api/v1/auth/capabilities (public) — returns `{emailResetAvailable: boolean, totpAvailable: boolean}` based on SMTP config
- [ ] T-21: POST /api/v1/auth/forgot-password — generate reset token (30-min), send email if SMTP configured, always return 200
- [ ] T-22: POST /api/v1/auth/reset-password — validate token, set new password, invalidate token + all JWTs
- [ ] T-23: Rate limit forgot-password: 3 per email per hour

### Backend — Cleanup

- [ ] T-24: OTT token cleanup scheduler — hourly purge of expired one-time access codes (similar to DV referral token purge)

### Backend — Tests (Positive)

- [ ] T-25: Integration test: TOTP enrollment flow (generate → verify → enabled, secret encrypted in DB)
- [ ] T-26: Integration test: two-phase login (password → mfaRequired → TOTP verify → JWTs)
- [ ] T-27: Integration test: recovery code substitutes for TOTP, code marked consumed
- [ ] T-28: Integration test: admin generates access code, user logs in, must change password
- [ ] T-29: Integration test: dvAccess user access code requires dvAccess admin (D6)
- [ ] T-30: Integration test: TOTP validation accepts ±1 time step (clock drift boundary)
- [ ] T-31: Create `TotpTestHelper` — generates valid TOTP codes from known test secrets

### Backend — Tests (Negative / Security)

- [ ] T-32: Integration test: expired access code rejected (15-min expiry)
- [ ] T-33: Integration test: mfaToken is single-use — second use after successful verify rejected
- [ ] T-34: Integration test: verify-totp rate limited — 6th attempt rejected, user must re-login
- [ ] T-35: Integration test: mfaToken with purpose="mfa" does NOT grant API access (JwtAuthenticationFilter skips it)
- [ ] T-36: Integration test: PasswordChangeRequiredFilter blocks all endpoints except password change
- [ ] T-37: Integration test: concurrent TOTP enrollment — second replaces first

### Backend — Tests (Concurrency / Load)

- [ ] T-38: Integration test: concurrent access code generation for same user — both succeed, both valid
- [ ] T-39: Gatling: TOTP verification under load — 100 concurrent verifications during shift change (p95 < 100ms)

### Frontend — TOTP Enrollment

- [ ] T-40: Create `TotpEnrollmentPage.tsx` — QR code display, manual secret, code input, verify button, backup code grid with copy/download/print
- [ ] T-41: Add "Enable Sign-In Verification" button in user profile area (NOT "Enable 2FA" — user-facing language per D15)
- [ ] T-42: Backup codes: display in grid with "Copy All" and "Download" buttons, sealed-envelope storage guidance (Devon)
- [ ] T-43: "Test your code now" confirmation step before codes are shown

### Frontend — Two-Phase Login

- [ ] T-44: Modify LoginPage.tsx — after password submit, if response has `mfaRequired: true`, show TOTP input screen
- [ ] T-45: TOTP input: 6-digit code field with auto-submit on 6 chars, "Use backup code" link
- [ ] T-46: Backup code input: 8-char field, submits to same verify endpoint

### Frontend — Password Recovery

- [ ] T-47: "Forgot Password?" link on LoginPage — ONLY if GET /api/v1/auth/capabilities returns emailResetAvailable=true
- [ ] T-48: Create `ForgotPasswordPage.tsx` — email input, submit, "Check your email" message
- [ ] T-49: Create `ResetPasswordPage.tsx` — token from URL, new password + confirm, submit
- [ ] T-50: Create `AccessCodeLoginPage.tsx` — code input field, submit, redirect to password change
- [ ] T-51: Admin Users tab: "Generate Access Code" button per user row, show code in modal once

### Frontend — i18n & Accessibility

- [ ] T-52: i18n keys (en + es): "Sign-in verification" not "2FA", "backup codes" not "recovery codes", enrollment, verify, forgot password, access code
- [ ] T-53: WCAG: TOTP input auto-focus, backup code grid keyboard-navigable, forgot password form accessible
- [ ] T-54: All colors from design tokens (dark mode safe)

### Frontend — Tests

- [ ] T-55: Playwright: TOTP enrollment flow (mock QR display, enter code, backup codes shown)
- [ ] T-56: Playwright: two-phase login (password → TOTP screen → success)
- [ ] T-57: Playwright: forgot password link visible ONLY when emailResetAvailable=true
- [ ] T-58: Playwright: admin generates access code, code displayed in modal
- [ ] T-59: Playwright: access code login → forced password change before accessing dashboard
- [ ] T-60: Playwright: backup code regeneration flow

### Seed Data & Screenshots

- [ ] T-61: Add user with totp_enabled=true to seed data (known test secret, encrypted)
- [ ] T-62: Capture screenshots: enrollment QR, TOTP login, backup codes, forgot password, access code modal

### Docs-as-Code — DBML, OpenAPI, AsyncAPI

- [ ] T-63: Update `docs/schema.dbml` — `totp_secret_encrypted`, `totp_enabled`, `recovery_codes` on app_user, `one_time_access_code` table
- [ ] T-64: Add `@Operation` annotations to all new endpoints
- [ ] T-65: Verify ArchUnit — TOTP logic in auth module, no cross-module violations
- [ ] T-66: Update AsyncAPI if any new events (audit events for TOTP enrollment/disable)

### Documentation

- [ ] T-67: Update FOR-DEVELOPERS.md — API reference, security notes, TOTP architecture
- [ ] T-68: Update FOR-COORDINATORS.md — "Sign-in verification" setup instructions, backup code storage guidance (Devon's sealed-envelope recommendation)
- [ ] T-69: Update FOR-CITIES.md — note CJIS AAL2 compliance via TOTP 2FA
- [ ] T-70: Update government-adoption-guide.md — CJIS MFA alignment statement (Casey)
- [ ] T-71: Update oracle runbook — TOTP troubleshooting, admin 2FA disable, FABT_TOTP_ENCRYPTION_KEY setup

### Verification

- [ ] T-72: Full frontend lint (ESLint + TypeScript)
- [ ] T-73: Run full backend test suite (including ArchUnit) — all green
- [ ] T-74: Run full Playwright test suite with --trace on — all green
- [ ] T-75: CI green on all jobs
- [ ] T-76: Merge to main, tag, release, deploy
