## Tasks

### Setup

- [ ] T-0: Create branch `feature/password-recovery-2fa` in code repo (`finding-a-bed-tonight`)

### Backend — Database

- [ ] T-1: Flyway migration: add `totp_secret VARCHAR(64)`, `totp_enabled BOOLEAN DEFAULT false`, `recovery_codes TEXT` to `app_user`
- [ ] T-2: Flyway migration: create `one_time_access_code` table (id UUID, user_id UUID, code_hash VARCHAR, expires_at TIMESTAMPTZ, used BOOLEAN DEFAULT false)
- [ ] T-3: Add `dev.samstevens.totp:totp` dependency to pom.xml

### Backend — TOTP Service

- [ ] T-4: Create `TotpService` — generateSecret(), generateQrUri(), verifyCode(), generateRecoveryCodes(), verifyRecoveryCode()
- [ ] T-5: POST /api/v1/auth/enroll-totp (authenticated) — return QR URI + secret, do NOT store until verified
- [ ] T-6: POST /api/v1/auth/confirm-totp-enrollment — verify first code, store secret, return recovery codes
- [ ] T-7: DELETE /api/v1/users/{id}/totp (COC_ADMIN+) — disable 2FA, clear secret, audit log

### Backend — Two-Phase Login

- [ ] T-8: Modify `AuthController.login()` — if totp_enabled, return `{mfaRequired: true, mfaToken}` instead of JWTs. mfaToken is a signed 5-min JWT with userId + purpose="mfa"
- [ ] T-9: POST /api/v1/auth/verify-totp — validate mfaToken + TOTP code (or recovery code), issue real JWTs
- [ ] T-10: Rate limit verify-totp: 5 attempts per mfaToken

### Backend — Admin Access Code

- [ ] T-11: `AccessCodeService` — generate single-use code (UUID), store hashed with 15-min expiry
- [ ] T-12: POST /api/v1/users/{id}/generate-access-code (COC_ADMIN+) — return plaintext code once. If target has dvAccess, require admin to also have dvAccess
- [ ] T-13: POST /api/v1/auth/access-code — validate code, authenticate user, require password change flag
- [ ] T-14: After access-code login, user must call PUT /api/v1/auth/password before any other endpoint (enforce via filter or interceptor)

### Backend — Email Reset (Secondary)

- [ ] T-15: POST /api/v1/auth/forgot-password — generate reset token (30-min), send email if SMTP configured, always return 200
- [ ] T-16: POST /api/v1/auth/reset-password — validate token, set new password, invalidate token + all JWTs
- [ ] T-17: Rate limit forgot-password: 3 per email per hour

### Backend — Tests

- [ ] T-18: Integration test: TOTP enrollment flow (generate → verify → enabled)
- [ ] T-19: Integration test: two-phase login (password → mfaRequired → TOTP verify → JWTs)
- [ ] T-20: Integration test: recovery code substitutes for TOTP
- [ ] T-21: Integration test: admin generates access code, user logs in with it
- [ ] T-22: Integration test: dvAccess user access code requires dvAccess admin
- [ ] T-23: Integration test: expired access code rejected
- [ ] T-24: Create `TotpTestHelper` — generates valid TOTP codes from known test secrets

### Frontend — TOTP Enrollment

- [ ] T-25: Create `TotpEnrollmentPage.tsx` — QR code display (via URI), manual secret display, code input, verify button, recovery code display
- [ ] T-26: Add "Enable 2FA" button in user profile area (header dropdown or settings)
- [ ] T-27: Recovery codes: display in grid, "Copy All" button, warning that they won't be shown again

### Frontend — Two-Phase Login

- [ ] T-28: Modify LoginPage.tsx — after password submit, if response has `mfaRequired: true`, show TOTP input screen
- [ ] T-29: TOTP input: 6-digit code field with auto-submit on 6 chars, "Use recovery code" link
- [ ] T-30: Recovery code input: 8-char field, submits to same verify endpoint

### Frontend — Password Recovery

- [ ] T-31: Add "Forgot Password?" link on LoginPage below sign-in button
- [ ] T-32: Create `ForgotPasswordPage.tsx` — email input, submit, "Check your email" message
- [ ] T-33: Create `ResetPasswordPage.tsx` — token from URL, new password + confirm, submit
- [ ] T-34: Create `AccessCodeLoginPage.tsx` — code input field, submit, redirect to password change
- [ ] T-35: Admin Users tab: add "Generate Access Code" button per user row, show code in modal once

### Frontend — i18n & Accessibility

- [ ] T-36: Add i18n keys for 2FA and recovery (en.json + es.json): enrollment, verify, recovery, forgot password, access code
- [ ] T-37: WCAG: TOTP input auto-focus, recovery code grid keyboard-navigable, forgot password form accessible

### Frontend — Tests

- [ ] T-38: Playwright: TOTP enrollment flow (mock QR display, enter code)
- [ ] T-39: Playwright: two-phase login (password → TOTP screen → success)
- [ ] T-40: Playwright: forgot password link visible on login page
- [ ] T-41: Playwright: admin generates access code, code displayed in modal

### Seed Data & Screenshots

- [ ] T-42: Add user with totp_enabled=true to seed data (known test secret for screenshots)
- [ ] T-43: Capture screenshots: TOTP enrollment QR, TOTP login screen, recovery codes, forgot password, access code modal

### Documentation

- [ ] T-44: Update FOR-DEVELOPERS.md — API reference (TOTP, access code, forgot password), project status, security notes
- [ ] T-45: Update runbook — 2FA troubleshooting (lost device, admin disable), password recovery procedures

### Verification

- [ ] T-46: Run full backend test suite — all green
- [ ] T-47: Run full Playwright test suite — all green
- [ ] T-48: ESLint + TypeScript clean
- [ ] T-49: CI green on all jobs
- [ ] T-50: Merge to main, tag
