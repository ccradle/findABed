## Tasks

### Database

- [x] ER-1: Flyway V39: create `password_reset_token` table (id UUID PK, user_id FK ON DELETE CASCADE, tenant_id FK, token_hash VARCHAR(64) UNIQUE NOT NULL, expires_at TIMESTAMPTZ NOT NULL, used BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT NOW()). Index on token_hash for O(1) lookup. Index on expires_at for cleanup.

### Backend — PasswordResetService

- [x] ER-2: Create `PasswordResetService` in `org.fabt.auth.service`. Methods: `requestReset(email, tenantSlug)` and `resetPassword(token, newPassword)`. Uses SHA-256 for token hashing, SecureRandom for 256-bit token generation.
- [x] ER-3: `requestReset`: lookup tenant + user, reject silently if not found or dvAccess=true (D3). Generate 32-byte SecureRandom token, SHA-256 hash, store in password_reset_token with 30-min expiry. Send email asynchronously on virtual thread. If email send fails, delete the token row and log error (user sees generic success — no leak). Add timing padding: constant 250ms floor (D8).
- [x] ER-4: `resetPassword`: SHA-256 hash incoming token, SELECT by token_hash WHERE used=false AND expires_at > NOW(). Mark used, update password (BCrypt), increment tokenVersion, set passwordChangedAt. Return success/failure.

### Backend — Wire AuthController Stubs

- [x] ER-5: Wire `forgotPassword()` to PasswordResetService.requestReset(). Accept `{email, tenantSlug}` in body. Keep SMTP-not-configured guard.
- [x] ER-6: Wire `resetPassword()` to PasswordResetService.resetPassword(). Create `EmailResetRequest` record with `@NotBlank token` and `@Size(min=12) newPassword` (matches existing ChangePasswordRequest/ResetPasswordRequest validation). Return 200 on success, 400 on invalid/expired token or validation failure.

### Backend — Email Content (D6)

- [x] ER-7: Update EmailService email subject to "Password Reset Request" (no platform name). Remove "Finding A Bed Tonight" from email body. Generic reset link text only.

### Backend — tokenVersion Bug Fix (D5)

- [x] ER-8: PasswordController.changePassword(): add `user.setTokenVersion(user.getTokenVersion() + 1)` before save.
- [x] ER-9: PasswordController.resetPassword() (admin): add `user.setTokenVersion(user.getTokenVersion() + 1)` before save.

### Backend — Cleanup

- [x] ER-10: Extend AccessCodeCleanupScheduler (or add parallel scheduler) to purge expired/used password_reset_token rows hourly.

### Backend — Tests

- [x] ER-11: Integration test: happy path + GreenMail email verification (subject, recipient, body, no platform name)
- [x] ER-12: Integration test: expired token (31 min) → rejected
- [x] ER-13: Integration test: used token (already consumed) → rejected
- [x] ER-14: Integration test: invalid/random token → rejected
- [x] ER-15: Integration test: non-existent email → 200 same message, no email (enumeration prevention)
- [x] ER-16: Integration test: dvAccess=true user → no email, no token (GreenMail verified)
- [x] ER-17: Integration test: TOTP user resets password → mfaRequired on next login
- [~] ER-18: REJECTED 2026-04-10 — Integration test for "SMTP not configured" deemed unnecessary. The early-return path in `EmailService` is one line; code review confirms it returns silently when `spring.mail.host` is unset (existing `@ConditionalOnProperty` annotation). Writing a test for a one-line conditional adds maintenance burden without proportional risk reduction. No fix needed.
- [x] ER-19: Integration test: tokenVersion increment on self-service password change (dedicated test user)
- [x] ER-20: Integration test: tokenVersion increment on admin password reset (dedicated test user)
- [x] ER-21: Verified SHA-256 format in DB: 64-char hex, not BCrypt, not plaintext
- [~] ER-21b: DEFERRED 2026-04-10 — Integration test for `JavaMailSender` failure path. Requires mocking the SMTP send call, which adds test infrastructure complexity (Mockito spy on the bean injected via GreenMail). Current GreenMail-based tests cover the happy path and DV-user blocking; the failure-path test is incremental defense-in-depth. Reopen as part of the SMTP operational follow-up issue if MailHog/Brevo work happens.

### Frontend (defer if time-constrained)

- [x] ER-22: ForgotPasswordPage.tsx rewritten — email + tenant slug form, confirmation screen, access code + login links
- [x] ER-23: ResetPasswordPage.tsx created — token from URL, new password + confirm, 12-char validation, success/error states
- [x] ER-24: i18n: 17 new keys (en + es) — forgotPassword.*, resetPassword.*. Route added to App.tsx.

### Documentation

- [x] ER-25: FOR-DEVELOPERS.md updated — forgot-password, reset-password, capabilities endpoints
- [x] ER-26: CHANGELOG v0.32.0 — all Charlotte pilot features documented

### Test Infrastructure

- [x] ER-30: GreenMail embedded SMTP added to pom.xml (greenmail-junit5 2.1.2)
- [x] ER-31: GreenMail configured in BaseIntegrationTest — shared static server, @DynamicPropertySource for spring.mail.host/port

### Unit Tests

- [x] ER-32: PasswordResetServiceTest — SHA-256 known vector, fixed length, deterministic, lowercase hex, collision resistance (5 tests)

### Additional Integration Tests

- [x] ER-33: Merged into ER-11 — GreenMail email verified (subject, recipient, body, no platform name)
- [x] ER-34: Merged into ER-16 — GreenMail verified zero new emails for DV user
- [x] ER-35: Enumeration timing test — valid vs invalid response times both >= 240ms, within 100ms
- [x] ER-36: Concurrent reset — new token invalidates previous, first token fails, second succeeds
- [x] ER-37: Password too short → 400 validation error

### Karate API Tests

- [x] ER-38: Karate: password-reset-lifecycle.feature — 6 scenarios (forgot 200, non-existent same, invalid tenant, invalid token 400, short password, capabilities)
- [x] ER-39: Karate: password-reset-security.feature — 5 scenarios (DV user same 200, empty token, missing fields, missing email, missing slug)

### Playwright E2E Tests (no SMTP required — API-assisted)

- [x] ER-40: Playwright: forgot password link visibility based on capabilities
- [x] ER-41: Playwright: forgot password form submit → check-email confirmation + access code link
- [x] ER-42: Playwright: reset page renders with token, token cleared from URL (Marcus), form functional
- [x] ER-43: Playwright: invalid token shows error after submit, no token shows warning + disabled submit

### Deferred to Future Operational Change

These three items are out of scope for the implementation change (which shipped the backend + frontend + tests in v0.32.0). They are operational/deployment follow-ups for actually exercising the feature on the demo site and during the Charlotte pilot. They will need a tracking issue and a small follow-up change when SMTP infrastructure is provisioned.

- [~] DEFERRED 2026-04-10: Add MailHog to docker-compose.yml behind `mail` profile for demo site visual email testing. Operational deployment work, not feature work. Belongs in a separate `email-reset-demo-smtp` change.
- [~] DEFERRED 2026-04-10: Add `forgot-password` and `reset-password` to DemoGuard allowlist. Depends on MailHog (above) or a real SMTP on the demo site. Requires DemoGuard policy review.
- [~] DEFERRED 2026-04-10: Configure Brevo/Resend free tier SMTP for Charlotte pilot. Pilot infrastructure work; happens when the Charlotte pilot date is firm and the deploying organization decides on a transactional email provider. Casey Drummond may need to review the data-processor agreement before this lands.

### Verification

- [x] ER-27: Full backend test suite — 496 tests, 0 failures, 0 errors
- [x] ER-28: npm run build — zero errors
- [x] ER-29: ESLint clean — zero errors on all changed files
