# Proposal: platform-operator-ui

## Why

v0.53.0 shipped the platform-operator backend (separate `platform_user` table, `/auth/platform/login`, MFA enrollment + verify, JWT issuance, lockout, backup codes). The bootstrap operator was activated successfully on the live VM during the v0.53 deploy — but ENTIRELY via curl from the VM (since demoguard blocks public POST). The operator's verbatim feedback after deploy: *"It was somewhat inconvenient to not have the login screen."* Each subsequent platform-admin operation today requires 2 curls (POST /login → POST /login/mfa-verify) — not viable for ad-hoc operator work.

This change ships the SPA layer that turns the validated v0.53 backend flow into a usable operator workflow, plus two small backend additions (`GET /me` and `POST /logout`) discovered as gaps during warroom design review.

## What Changes

**New SPA routes (frontend-only, except where noted):**
- `/platform/login` — email + password form, distinct branding from tenant `/login`
- `/platform/mfa-enroll` — QR code + manual secret + supported-authenticators list + backup-codes one-shot display
- `/platform/mfa-verify` — TOTP input OR backup code input
- `/platform/dashboard` — operator metadata + 7 lifecycle action cards (rendered disabled with tooltip when `fabt.tenant.lifecycle.enabled=false`) + backup-codes-remaining badge

**Two small backend endpoints (un-freezing the backend for this slice only):**
- `GET /api/v1/auth/platform/me` — returns `{email, mfaEnabled, lastLoginAt, mfaEnabledAt, backupCodesRemaining}`. Required so the dashboard can display operator metadata + backup-codes urgency. Last-login-IP deferred to v0.55.
- `POST /api/v1/auth/platform/logout` — server-side no-op (returns 204). Gives the SPA a clean affordance and a future hook for token revocation in Phase H+.

**Anti-confusion safeguards:**
- Persistent "PLATFORM OPERATOR MODE" banner (new `--color-platform` semantic token) on every `/platform/*` page
- Distinct route prefix `/platform/*` lazy-loaded as a separate chunk
- Tenant `/login` page does NOT link to `/platform/login` — tenant users should not even know it exists
- Login page heading and copy explicitly call out "Platform Operator Sign-In"

**Security posture:**
- Platform JWT in `sessionStorage` (NOT localStorage) — survives only the tab session
- 15-minute hard expiry with countdown timer in banner; redirect-on-expiry, no silent refresh, no refresh token
- `<PlatformProtectedRoute>` guard checks sessionStorage + `mfa_verified` claim
- Backup codes: one-shot display + checkbox-confirmation gate before continuing
- Print and copy-to-clipboard both gated by confirmation modal naming the OS-print-queue / clipboard-history tradeoff
- `@media print` CSS strips everything except heading + 10 codes + "store securely" notice (no email, URL, timestamp, QR)
- Page sets `Cache-Control: no-store`; codes never re-fetchable

**Operability:**
- `VITE_PLATFORM_UI_ENABLED` build-time flag for fast rollback (deploy with flag off → `/platform/*` returns 404)
- Action confirmation modals on destructive operations (typed tenant slug for suspend/unsuspend)
- Grafana panel row for platform-operator activity (login rate, MFA failure rate, action invocation rate)
- Comprehensive Playwright e2e (happy path, expired session, MFA failure, disabled lifecycle button, print confirmation, browser back-button cannot resurrect codes)

## Impact

**Affected capabilities:**
- `platform-operator-identity` (MODIFIED) — adds `/me` and `/logout` endpoints
- `platform-operator-ui` (NEW) — the SPA layer

**Affected code:**
- `frontend/src/pages/platform/` (new directory; lazy-loaded)
- `frontend/src/auth/PlatformAuthContext.tsx` (new; sibling to tenant auth, NOT a generalization)
- `frontend/src/components/PlatformOperatorBanner.tsx` (new)
- `frontend/src/theme/colors.ts` (add `--color-platform` semantic token)
- `frontend/vite.config.ts` (add `VITE_PLATFORM_UI_ENABLED` flag handling)
- `backend/src/main/java/org/fabt/auth/platform/api/PlatformAuthController.java` (add 2 methods)
- `backend/src/main/java/org/fabt/auth/platform/dto/` (new `PlatformOperatorMeDto.java`)

**Out of scope (deferred to v0.55+):**
- Multi-language UI — English only for v0.54; i18n is a v0.55+ follow-up if a non-English-speaking operator joins
- Regenerate-backup-codes flow (needs sensitive-action re-MFA ladder; separate OpenSpec)
- Operator-creates-second-operator UI (needs own threat model + backend endpoint; operator #2 in v0.54 still uses curl bootstrap)
- Refresh-token / silent renewal (needs explicit threat-model review)
- httpOnly-cookie JWT storage (backend Set-Cookie + CSRF plumbing)
- Server-side token revocation (logout endpoint is no-op for now)
- Last-login-IP display (would require either audit-log query or new `last_login_ip` column)
- Favicon swap on `/platform/*`

**Documentation deliverables:**
- `docs/operations/platform-operator-user-guide.md` (new) — login, MFA enrollment, daily actions, recovery, escalation
- 6 screenshots captured against dev env: login, MFA enroll, backup codes, dashboard, action confirmation, expired-session redirect
- Update `docs/operations/oracle-update-notes-v0.54.0.md` at deploy time — SSH-tunnel access pattern + `VITE_PLATFORM_UI_ENABLED` flag
