## Tasks

### Setup

- [x] T-0: Create branch `feature/self-service-password-management` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`).

### Database

- [x] T-1: Create Flyway migration — add `password_changed_at TIMESTAMPTZ` column to `users` table, default NULL (existing users have no change history)

### Backend — Password Change

- [x] T-2: Add `PUT /api/v1/auth/password` endpoint — verify current password, validate new password (min 12 chars), update hash, set `password_changed_at`. Return 409 for SSO-only users (REQ-PWD-1 through REQ-PWD-3, REQ-PWD-10). Remove "Email and password cannot be changed" comment from `UserController.java`
- [x] T-3: Update `JwtService.validateToken()` — check `iat` against user's `password_changed_at`; reject tokens issued before last password change (REQ-PWD-4, REQ-PWD-5)
- [x] T-4: Add rate limiting on password change endpoint — 5 attempts per 15 minutes via bucket4j (REQ-PWD-6)
- [x] T-5: Write `PasswordChangeIntegrationTest.java` — successful change, wrong current password, weak new password, old token rejected after change, SSO-only user returns 409

### Backend — Admin Reset

- [x] T-6: Add `POST /api/v1/users/{id}/reset-password` endpoint — COC_ADMIN/PLATFORM_ADMIN only, same-tenant enforcement, password validation, JWT invalidation (REQ-ARST-1 through REQ-ARST-4)
- [x] T-7: Write `AdminPasswordResetTest.java` — successful reset, cross-tenant denied (404), coordinator denied (403)

### Frontend — Change Password UI

- [x] T-8: Create `ChangePasswordModal.tsx` — current password, new password, confirm, client-side validation, submit to PUT endpoint (REQ-PWD-7)
- [x] T-9: Add "Change Password" option in user profile dropdown or settings — hide for SSO-only users (REQ-PWD-7, REQ-PWD-9)
- [x] T-10: On success, clear tokens from localStorage and redirect to login with message (REQ-PWD-8)
- [x] T-11: Add i18n keys for password change form (en.json + es.json)

### Frontend — Admin Reset UI

- [x] T-12: Add "Reset Password" button per user row in Admin panel Users tab — hide for SSO-only users (REQ-ARST-5, REQ-ARST-7)
- [x] T-13: Create reset password modal — new password + confirm, submit to POST endpoint
- [x] T-14: Add i18n keys for admin reset (en.json + es.json)

### MCP-Ready API Design

- [x] T-15: Add `@Operation` annotations with semantic descriptions to both endpoints — password change and admin reset must be discoverable by AI agents (REQ-MCP-1 through REQ-MCP-3)

### Observability

- [x] T-16: Add Micrometer metrics — `fabt.auth.password_change.count` (tag: success/failure), `fabt.auth.password_reset.count` (tag: admin_role), `fabt.auth.token_invalidated.count` (tag: reason=password_change|admin_reset)
- [x] T-17: Add rate limiting on admin reset endpoint — 10 attempts per 15 minutes per admin (prevent mass reset attack with compromised admin credentials)

### Testing

- [x] T-18: Write Playwright tests — change password flow (login, change, verify old token rejected, login with new password)
- [x] T-19: Write Playwright tests — admin reset flow (admin resets coordinator, coordinator must re-login)
- [x] T-20: Run full test suite — all green (128 passed, 0 failures)
- [x] T-21: Run OWASP ZAP scan — verify new auth endpoints don't introduce findings (116 PASS, 0 FAIL, 2 WARN — same as baseline, no new findings)

### Documentation

- [x] T-22: Update `docs/runbook.md` — password management procedures, metric monitoring, suspicious reset activity alerts
- [x] T-23: Update README Project Status — add password management to completed features
- [x] T-24: Update `docs/government-adoption-guide.md` — credential management posture for city procurement
- [x] T-25: Update `docs/WCAG-ACR.md` if new forms require accessibility review (password inputs, modal focus management)

### Demo Screenshots

- [x] T-26: Recapture Admin panel Users tab screenshot (new Reset Password button)
- [x] T-27: Capture new Change Password modal screenshot for demo walkthrough
- [x] T-28: Update `findABed/demo/index.html` — add new card for Change Password modal with narrative caption, update screenshot count badge (18→19), update Admin Users tab caption to mention password reset capability
- [x] T-29: Update `findABed/demo/capture-screenshots.spec.ts` if needed to capture the new Change Password modal screenshot

### Verification

- [x] T-30: CI green on all jobs
- [x] T-31: Merge to main, tag
