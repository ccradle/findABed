## Tasks

### Setup

- [ ] T-0: Create branch `feature/self-service-password-management` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`).

### Database

- [ ] T-1: Create Flyway migration — add `password_changed_at TIMESTAMPTZ` column to `users` table, default NULL (existing users have no change history)

### Backend — Password Change

- [ ] T-2: Add `PUT /api/v1/auth/password` endpoint — verify current password, validate new password (min 12 chars), update hash, set `password_changed_at` (REQ-PWD-1 through REQ-PWD-3)
- [ ] T-3: Update `JwtService.validateToken()` — check `iat` against user's `password_changed_at`; reject tokens issued before last password change (REQ-PWD-4, REQ-PWD-5)
- [ ] T-4: Add rate limiting on password change endpoint — 5 attempts per 15 minutes via bucket4j (REQ-PWD-6)
- [ ] T-5: Write `PasswordChangeIntegrationTest.java` — successful change, wrong current password, weak new password, old token rejected after change

### Backend — Admin Reset

- [ ] T-6: Add `POST /api/v1/users/{id}/reset-password` endpoint — COC_ADMIN/PLATFORM_ADMIN only, same-tenant enforcement, password validation, JWT invalidation (REQ-ARST-1 through REQ-ARST-4)
- [ ] T-7: Write `AdminPasswordResetTest.java` — successful reset, cross-tenant denied (404), coordinator denied (403)

### Frontend — Change Password UI

- [ ] T-8: Create `ChangePasswordModal.tsx` — current password, new password, confirm, client-side validation, submit to PUT endpoint (REQ-PWD-7)
- [ ] T-9: Add "Change Password" option in user profile dropdown or settings (REQ-PWD-7)
- [ ] T-10: On success, clear tokens from localStorage and redirect to login with message (REQ-PWD-8)
- [ ] T-11: Add i18n keys for password change form (en.json + es.json)

### Frontend — Admin Reset UI

- [ ] T-12: Add "Reset Password" button per user row in Admin panel Users tab (REQ-ARST-5)
- [ ] T-13: Create reset password modal — new password + confirm, submit to POST endpoint
- [ ] T-14: Add i18n keys for admin reset (en.json + es.json)

### Testing

- [ ] T-15: Write Playwright tests — change password flow (login, change, verify old token rejected, login with new password)
- [ ] T-16: Write Playwright tests — admin reset flow (admin resets coordinator, coordinator must re-login)
- [ ] T-17: Run full test suite — all green
- [ ] T-18: Update docs/runbook.md — password management procedures

### Verification

- [ ] T-19: CI green on all jobs
- [ ] T-20: Merge to main, tag
