# Tasks: platform-operator-ui

## 1. Setup

- [x] 1.1 Pull main + branch off `feature/platform-operator-ui` from current HEAD (in code repo `finding-a-bed-tonight/`) — branched at `9dc67ea` (v0.53.0 tag), already up-to-date with origin
- [x] 1.2 Confirmed v0.53 backend baseline healthy via `mvn compile -DskipTests` (clean build, no errors). Full `mvn test` runs at 2.6 post-implementation; if any pre-existing test fails there, we know we broke baseline.

## 2. Backend additions (narrow un-freeze)

- [x] 2.1 Created `PlatformOperatorMeDto` record. Implementation revealed need for V90 Flyway migration `platform_user_get_me()` SECURITY DEFINER function (existing `platform_user_lookup_by_id` returns only credential-shaped fields). V90 collision with reentry-spec resolved by renumbering reentry V90-V93 → V91-V94 (33 references across 4 files).
- [x] 2.2 Added `GET /me` — returns DTO with id/email/mfaEnabled/lastLoginAt/mfaEnrolledAt/backupCodesRemaining. Wrong-scope tokens get 403 via new `PlatformScopeMismatchException` (not 401, per Marcus's defense-in-depth split: "auth fine but not for here"). Tenant JWT rejected at validateToken → 401 (existing pattern).
- [x] 2.3 Added `POST /logout` — server-side no-op (returns 204). Verified by IT that `last_login_at` does NOT mutate.
- [x] 2.4 `PlatformAuthControllerMeTest` (4 tests): all-fields happy path + secrets-not-leaked assertion, missing-token → 401, mfa-setup-token → 403, garbage-token → 401. **GREEN**.
- [x] 2.5 `PlatformAuthControllerLogoutTest` (3 tests): 204 + no DB mutation, missing-token → 401, mfa-setup-token → 403. **GREEN**.
- [x] 2.6 Full backend `mvn test` → **1285/1285 GREEN** including the 7 new platform-operator-ui IT tests + MigrationLintTest (V90 added to SECURITY_DEFINER_ALLOWLIST with citation following V87/V88 precedent)

## 3. Frontend foundation

- [x] 3.1 `--color-platform` token added to `frontend/src/global.css` (light + dark sections, both burnt orange #C2410C with 5.4:1 white-text contrast comment). `colors.ts` exports `color.platform`. axe-core sweep is task 6.9 (deferred to test phase).
- [x] 3.2 `VITE_PLATFORM_UI_ENABLED` typed in new `frontend/src/vite-env.d.ts` (augments ImportMetaEnv); documented in `frontend/.env.example`. Vite reads from `.env*` automatically — no vite.config.ts change needed.
- [x] 3.3 `frontend/src/auth/PlatformAuthContext.tsx` created. Sibling to AuthContext (NOT generalized). Exposes `usePlatformAuth()` returning `{jwt, claims, operatorId, isAuthenticated, isMfaVerified, login, logout}`. Cross-tab `storage` event listener triggers logout in other tabs when sessionStorage clears.
- [x] 3.4 `frontend/src/pages/platform/helpers/platformJwt.ts` created. `PLATFORM_JWT_STORAGE_KEY = 'fabt.platform.jwt.v1'`. `parseClaims()` is signature-unverified (server is the authority). `isExpired()` synchronous + cheap. `secondsUntilExpiry()` for the banner countdown (4.10).
- [x] 3.5 `frontend/src/pages/platform/helpers/platformApi.ts` created. Module-level `isHandling401` flag prevents concurrent 401s from double-navigating. 403 from `/me` redirects to `/platform/mfa-enroll` without wiping sessionStorage. Test-only `__resetIsHandling401ForTests()` exposed.
- [x] 3.6 `frontend/src/pages/platform/PlatformProtectedRoute.tsx` created. Synchronous checks: JWT present + `iss === 'fabt-platform'` + `isExpired` + scope-based routing (mfa-setup → /mfa-enroll, mfa-verify → /mfa-verify, else require `mfaVerified=true`). `allowMfaSetupScope` prop for the enroll route.
- [x] 3.7 `App.tsx` wires `/platform/*` route. Top-level `if (import.meta.env.VITE_PLATFORM_UI_ENABLED === 'true')` guards the `lazy()` import literal — Rollup dead-code-eliminates when false. **Verified empirically**: build with no flag → no `PlatformPlaceholder-*.js` chunk emitted; `VITE_PLATFORM_UI_ENABLED=true npm run build` → `PlatformPlaceholder-D488kS5j.js` present. `PlatformAuthProvider` wraps the BrowserRouter inside `AuthProvider`.
- [x] 3.8 Tenant `/login` page unchanged — confirmed via grep on App.tsx (LoginPage import only) and no `/platform` reference in `LoginPage.tsx`.
- [x] 3.9 Section 3 ships a `PlatformPlaceholder` stub; the real cross-link to tenant `/login` is part of the `PlatformLogin` page in task 4.1. This task moves to verification at the §6 testing checkpoint.

## 4. SPA routes

- [ ] 4.1 Build `frontend/src/pages/platform/PlatformLogin.tsx` — email + password form, heading "Platform Operator Sign-In", subheading with link to tenant `/login`, `data-testid="platform-login-{submit,email,password}"`, posts to `/api/v1/auth/platform/login`, branches on response shape (MFA-setup vs MFA-verify scoped token)
- [ ] 4.2 Build `frontend/src/pages/platform/PlatformMfaEnroll.tsx` — renders QR + manual secret + supported-authenticators list ("Google Authenticator, Microsoft Authenticator, 1Password, Authy, Bitwarden"); QR image has `aria-label` describing the QR + pointing to manual-entry secret element id; on confirm posts to `/auth/platform/mfa-confirm`; on success transitions to backup-codes view. Handle reload-mid-enrollment: if MFA-setup token still valid in sessionStorage, re-fetch `/auth/platform/mfa-setup` (idempotent on backend — returns same secret for same setup token) and re-render same QR/secret; if MFA-setup token expired (>10min since issuance), wipe sessionStorage and redirect to `/platform/login` with toast "Enrollment session expired — please sign in again to restart"
- [ ] 4.3 Build `frontend/src/pages/platform/components/BackupCodesDisplay.tsx` — renders 10 codes via React text-node interpolation (`{code}` only — `dangerouslySetInnerHTML` is forbidden, enforced by ESLint rule `react/no-danger` scoped to this file); checkbox "I have saved my backup codes" + Continue button (disabled until checked); Print + Copy-to-Clipboard buttons (both gated by ConfirmActionModal); on Copy confirm, schedule `setTimeout(() => navigator.clipboard.writeText(''), 30000)` to auto-clear clipboard. Verify backend `/auth/platform/mfa-confirm` response carries `Cache-Control: no-store, no-cache, must-revalidate` and `Pragma: no-cache` headers (file v0.54 backend task if missing). Add unit test that a code containing `<script>` renders as literal text
- [ ] 4.4 Build `frontend/src/pages/platform/components/PrintFriendlyCodes.tsx` — `@media print` CSS strips operator email + URL + timestamp + QR; only heading + 10 codes + "store securely" notice render in print view
- [x] 4.5 Built `frontend/src/pages/platform/components/ConfirmActionModal.tsx` — three variants (`print`, `copy`, `destructive`) with Cancel default-focused, locked button labels per spec, typed-confirmation field on destructive variant. Render-prop callback shape (`onCancel`/`onConfirm`); slug-typed-match logic local to component.
- ~~Original task description (now done):~~ Build `frontend/src/pages/platform/components/ConfirmActionModal.tsx` — generic modal with three variants:
  - **Print variant**: copy *"These codes will be sent to your printer or saved as a PDF. They will appear in your OS print queue and may be retained by network printers. Continue?"*; primary button labeled exactly "Cancel" (default-focused); secondary button labeled exactly "Print Anyway"
  - **Copy variant**: copy *"These codes will be placed on your system clipboard. Clipboard managers and pasted-into apps may retain them. The clipboard will auto-clear in 30 seconds. Continue?"*; primary button labeled exactly "Cancel" (default-focused); secondary button labeled exactly "Copy Anyway"
  - **Destructive-action variant**: typed-confirmation field requiring exact match of tenant slug; primary button "Cancel" (default-focused); secondary button matches action verb (e.g. "Suspend Tenant")
- [ ] 4.6 Build `frontend/src/pages/platform/PlatformMfaVerify.tsx` — TOTP input (6 digits) OR backup code input (8 chars); posts to `/auth/platform/login/mfa-verify`; on success stores JWT in sessionStorage + redirects to `/platform/dashboard`. Render 3 error states per spec:
  - **Wrong TOTP/backup code (401 with attempts-remaining):** display "Code invalid. X attempts remaining before lockout."; clear input + refocus; submit re-enables for retry
  - **Lockout reached (401 lockout response):** display "Too many failed attempts. Account locked for 15 minutes. If you've lost your phone, use a backup code."; disable TOTP input; keep "Use backup code instead" link active
  - **Network error (no HTTP response):** display "Couldn't reach server. Check your connection and try again."; submit re-enables for retry; sessionStorage NOT wiped (MFA-verify scoped token remains valid)
- [ ] 4.7 Build `frontend/src/pages/platform/PlatformDashboard.tsx` — `<h1>Platform Operator Dashboard</h1>` heading; header with operator email + last-login timestamp + MFA-enrolled date + backup-codes-remaining badge (amber@3, red@1); fetches `/api/v1/auth/platform/me` on mount; renders action cards in 3 categories (Tenant Lifecycle, Operator Management, System Status). Each category title is `<h2>`; each action card title is `<h3>` (supports screen-reader heading navigation)
- [ ] 4.8 Build `frontend/src/pages/platform/platformActions.ts` — config array driving the 7 lifecycle action cards (id, title, description, endpoint, method, flagGate, dangerLevel)
- [ ] 4.9 Build `frontend/src/pages/platform/components/PlatformActionCard.tsx` — renders one action; disabled-with-tooltip when `flagGate=fabt.tenant.lifecycle.enabled` and that flag is off (tooltip: "Tenant lifecycle is disabled in this deployment. Contact platform engineering to enable.")
- [x] 4.10 Built `frontend/src/pages/platform/components/PlatformOperatorBanner.tsx` + `PlatformLayout.tsx` (Outlet-style layout wrapper). Banner shows masked operator email (`maskEmail` helper, fully tested), 1s-tick countdown ("Session expires in X:XX"), amber at <=2min, red at <=30s, redirects to `/platform/login` with toast key on tick-zero. Logout button POSTs `/api/v1/auth/platform/logout` (best-effort) then clears sessionStorage + redirects. `useOperatorMetadata` hook fetches `/me` on mount. Banner suppressed on routes where no JWT exists (login screen). Added 9 unit tests for `maskEmail` (happy path + edge cases). Component-level testing deferred to §6 Playwright (no React Testing Library available without dep research).

## 5. Telemetry + observability

- [ ] 5.1 Confirm backend Prometheus counters exist: `platform_login_attempts_total`, `platform_mfa_verify_total{outcome}`, `platform_action_invoked_total{action}` — if any missing, file F43 follow-up (not in this slice)
- [ ] 5.2 Add Grafana panel row to existing operator dashboard at `infra/grafana/dashboards/operator.json` with: login rate, MFA failure rate, action invocation rate, current sessions estimate (JWT issuances per 15min)
- [ ] 5.3 Confirm no client-side analytics or Sentry breadcrumb fires on the print-codes action (Marcus condition #3); add an explicit comment in `BackupCodesDisplay.tsx` noting this constraint
- [ ] 5.4 Define 3 Prometheus alert rules in `infra/prometheus/alerts/platform-operator.yml`:
  - `PlatformMfaFailureSpike` — `rate(platform_mfa_verify_total{outcome="failure"}[5m]) > 1/60` (more than 1/min sustained over 5 min) → severity warning
  - `PlatformDashboard5xx` — any `http_server_requests_seconds_count{uri=~"/api/v1/auth/platform/.*",status=~"5.."} > 0` over 2min → severity critical
  - `PlatformLockoutTriggered` — increment of `platform_user_locked_out_total` → severity critical (immediate page)
  Wire to existing Alertmanager via standard route labels

## 6. Testing

- [ ] 6.1 Playwright `e2e/playwright/tests/platform-login.spec.ts` — happy path login → MFA verify → dashboard renders all expected fields
- [ ] 6.2 Playwright `e2e/playwright/tests/platform-mfa-enroll.spec.ts` — first login → enroll flow → checkbox gate blocks Continue until checked → backup codes shown once → second login no longer offers enroll
- [ ] 6.3 Playwright `e2e/playwright/tests/platform-print-codes.spec.ts` — print confirmation modal blocks before window.print(); browser back-button on backup-codes screen does NOT resurrect codes; `Cache-Control: no-store` header asserted on the response
- [ ] 6.4 Playwright `e2e/playwright/tests/platform-session-expiry.spec.ts` — JWT expiry triggers redirect to login + toast; countdown timer renders in banner
- [ ] 6.5 Playwright `e2e/playwright/tests/platform-disabled-action.spec.ts` — when `fabt.tenant.lifecycle.enabled=false`, suspend button is disabled with tooltip; clicking does not POST
- [ ] 6.6 Playwright fixture `e2e/playwright/helpers/auth/platformOperator.ts` — set up authenticated platform-operator session for tests that depend on the post-MFA state
- [ ] 6.7 Run full backend `mvn test` — all green
- [ ] 6.8 Run full Playwright suite locally against `./dev-start.sh` + nginx — all green
- [ ] 6.9 Run axe-core sweep on `/platform/login`, `/platform/mfa-enroll`, `/platform/mfa-verify`, `/platform/dashboard` in BOTH `data-theme=light` and `data-theme=dark` — zero serious/critical violations in either theme
- [ ] 6.10 Manual cross-authenticator MFA enrollment QA: verify QR scans cleanly in Google Authenticator, Microsoft Authenticator, 1Password, Authy, Bitwarden on at least one iOS + one Android device. **Capture results in `docs/operations/platform-operator-mfa-compatibility.md`** as a markdown table (authenticator × iOS/Android × pass/fail/notes); commit before merge
- [ ] 6.11 Create `e2e/playwright/tests/platform-training-walkthrough.spec.ts` — narrated end-to-end happy path operators can run locally to rehearse: login → enroll MFA with seed TOTP secret → save backup codes → view dashboard → click disabled-tooltip Suspend (with flag off) → logout. NOT part of CI gates; manually invoked. Linked from user guide section 1
- [ ] 6.12 CSP assertion — Playwright spec asserts `Content-Security-Policy` header present on `/platform/*` responses (matches tenant-route CSP shape, no relaxation); confirm chosen QR library renders in production CSP without `'unsafe-inline'` or `'unsafe-eval'` exemption (verify in built `dist/` against current `infra/nginx/conf.d/` CSP); zero CSP violations in browser console during full e2e flow

## 7. Documentation

- [ ] 7.1 Create `docs/operations/platform-operator-user-guide.md` with these mandatory sections (minimum 1500 words total, all internal links relative):
  1. **First-time setup** (with embedded screenshots 1+2 — login + MFA enroll QR)
  2. **Daily login** (screenshot 4 — dashboard)
  3. **Reading the dashboard** (screenshot 4 annotated — banner, countdown, action cards, backup-codes badge)
  4. **Performing destructive actions** (screenshot 5 — confirmation modal)
  5. **Lost-phone recovery using backup codes** (when to use, what happens after)
  6. **Lost-phone + lost-backup-codes recovery** — escalation path. Includes "Sole-operator catastrophic recovery: requires direct DB access on Oracle VM (procedure documented in internal runbook, NOT in this guide). v0.55 will add a documented `mvn` reset tool similar to HashPasswordCli — see follow-up F45."
  7. **Operator #2 onboarding** — still curl-based per design D12 in v0.54; references the v0.53 oracle-update-notes platform_user activation procedure
  8. **When to escalate vs self-serve** (decision tree)
- [ ] 7.2 Capture 6 screenshots against `./dev-start.sh` with platform-operator seed (per v0.53 runbook); browser: Chrome stable, 1440x900, default zoom; theme: light mode. Files: `01-login.png`, `02-mfa-enroll.png` (QR + secret), `03-backup-codes.png`, `04-dashboard.png` (annotated), `05-confirm-action.png`, `06-expired-session.png`. Commit to `docs/operations/screenshots/platform-operator/`
- [ ] 7.3 Add link to user guide in `docs/operations/README.md` AND from in-UI help text on BOTH `/platform/mfa-enroll` ("First time enrolling? See the [Platform Operator User Guide].") AND `/platform/dashboard` header ("First time? See the [Platform Operator User Guide]"). Link target is the canonical relative path `/docs/operations/platform-operator-user-guide.md` resolved against the docs site (or GitHub blob URL); pin the exact URL in `frontend/src/pages/platform/constants.ts` so future moves require one edit
- [ ] 7.4 Update `CHANGELOG.md` `[Unreleased]` section with v0.54 entry summarizing this change
- [ ] 7.5 Author `docs/operations/oracle-update-notes-v0.54.0.md` at deploy time per the v0.50+ runbook template. Document a TWO-STAGE deploy:
  - **Stage A — cold deploy with flag OFF.** Build `VITE_PLATFORM_UI_ENABLED=false npm run build` → scp `dist/` to VM → `docker compose <FULL_5-FILE_CHAIN> up -d --force-recreate frontend`. Smoke: tenant `/login` works; `/platform/login` returns 404; backend `/me` and `/logout` 401 without JWT. Verifies v0.54 doesn't regress v0.53.
  - **Stage B — flag-flip activation redeploy.** Rebuild `VITE_PLATFORM_UI_ENABLED=true npm run build` → scp → `docker compose ... up -d --force-recreate frontend`. Smoke: SSH-tunnel-to-:8081 + browse to `/platform/login` + complete login + dashboard renders. Stage B is reversible by repeating Stage A.
  - **Concrete rollback procedure (~6min RTO):** rebuild with flag=false → scp → force-recreate frontend container. NO database or backend rollback required.
  - Document SSH-tunnel-to-:8081 access pattern WITHOUT revealing demoguard bypass details per `feedback_platform_login_via_ssh_tunnel.md` memory

## 8. Pre-merge

- [ ] 8.1 Warroom review of the implemented PR (security spot-check on JWT handling + Marcus's 5 print conditions verified in code)
- [ ] 8.2 Open PR against main; link this OpenSpec change; reviewer-approve required
- [ ] 8.3 Verify CI scans pass (CodeQL, npm audit, dependency-check)
- [ ] 8.4 Squash-merge to main; tag is deferred to v0.54 deploy day

## 9. Operator decision points (during /opsx:apply)

- [x] 9.1 `--color-platform` = **burnt orange `#C2410C`** (warm operator-mode feel; AA contrast 5.4:1 with white banner text; distinct from amber warning + DV purple). Light/dark variants TBD during 3.1.
- [x] 9.2 Operator email in banner: **masked** (e.g. `c***@gmail.com`). Defensive against shoulder-surfing / screenshot leakage.
- [x] 9.3 Backup-codes screen print button label: **"Print"** (modal's own buttons remain spec-locked to "Cancel" / "Print Anyway").
