# Tasks: platform-operator-ui

## 1. Setup

- [ ] 1.1 Pull main + branch off `feature/platform-operator-ui` from current HEAD (in code repo `finding-a-bed-tonight/`)
- [ ] 1.2 Confirm v0.53 backend `/auth/platform/*` endpoints still pass smoke locally (`./dev-start.sh` + curl `/health`)

## 2. Backend additions (narrow un-freeze)

- [ ] 2.1 Create `PlatformOperatorMeDto` record at `backend/src/main/java/org/fabt/auth/platform/dto/PlatformOperatorMeDto.java` with fields `(UUID id, String email, boolean mfaEnabled, Instant lastLoginAt, Instant mfaEnabledAt, int backupCodesRemaining)`
- [ ] 2.2 Add `GET /api/v1/auth/platform/me` to `PlatformAuthController` — requires platform JWT; rejects tenant JWT with 403; returns DTO populated from `PlatformUserRepository.findById` + `findUnusedBackupCodes(id).size()` + min(`platform_user_backup_code.created_at`) for `mfaEnabledAt`
- [ ] 2.3 Add `POST /api/v1/auth/platform/logout` to `PlatformAuthController` — requires platform JWT; returns 204 No Content; server-side no-op for v0.54 (future hook for Phase H+ token revocation)
- [ ] 2.4 IT `PlatformAuthControllerMeTest` — covers: returns expected fields, requires platform JWT (401 without), rejects tenant JWT (403), returns correct backup-code count after one is used
- [ ] 2.5 IT `PlatformAuthControllerLogoutTest` — covers: returns 204, requires platform JWT, no DB mutation
- [ ] 2.6 Run `mvn test` — confirm all backend tests green

## 3. Frontend foundation

- [ ] 3.1 Add `--color-platform` semantic color token to `frontend/src/theme/colors.ts` with light + dark variants; verify WCAG AA contrast against banner text via axe-core
- [ ] 3.2 Add `VITE_PLATFORM_UI_ENABLED` build-time flag handling in `frontend/vite.config.ts` + `frontend/src/env.d.ts`; default `true` in dev, `true` in prod (operator can flip to `false` for emergency rollback)
- [ ] 3.3 Create `frontend/src/auth/PlatformAuthContext.tsx` — sessionStorage-backed; exposes `usePlatformAuth()` hook with `{operator, jwt, jwtExpiresAt, login, logout, isAuthenticated, isMfaVerified}`; explicit decision NOT to extend existing `AuthContext`
- [ ] 3.4 Create `frontend/src/pages/platform/helpers/platformJwt.ts` — sessionStorage R/W under namespaced+versioned key constant `PLATFORM_JWT_STORAGE_KEY = 'fabt.platform.jwt.v1'`; claim parsing (decode `iss`, `sub`, `roles`, `mfaVerified`, `exp`); 15-min countdown calculator; expose synchronous `isExpired(jwt): boolean` helper for guard use
- [ ] 3.5 Create `frontend/src/pages/platform/helpers/platformApi.ts` — fetch wrapper that injects `Authorization: Bearer <platform-jwt>`; 401 handler wipes sessionStorage + redirects to `/platform/login` (guarded by module-level `isHandling401` flag so concurrent 401s do not double-navigate); 403 handler from `/me` redirects to `/platform/mfa-enroll` WITHOUT wiping sessionStorage
- [ ] 3.6 Create `frontend/src/pages/platform/PlatformProtectedRoute.tsx` — synchronous checks BEFORE rendering children: (a) JWT present in sessionStorage, (b) `iss === "fabt-platform"`, (c) `mfaVerified === true`, (d) `Date.now() >= exp*1000` synchronous expiry check. Any failure redirects to `/platform/login` BEFORE child fetches initiate (prevents 401 race vs expiry redirect)
- [ ] 3.7 Wire `/platform/*` route tree in `frontend/src/App.tsx` (or main router) using `React.lazy` for the entire `pages/platform/` chunk. CRITICAL: guard the lazy import literal with `if (import.meta.env.VITE_PLATFORM_UI_ENABLED === 'true')` at the TOP LEVEL of the module, so Rollup dead-code-eliminates the dynamic import when the flag is false. Without this top-level guard, React.lazy still emits the chunk to `dist/assets/`. Add a CI assertion (script in `frontend/scripts/`) that builds with `VITE_PLATFORM_UI_ENABLED=false` and confirms `dist/assets/platform-*.js` is ABSENT. When flag is false, `/platform/*` falls through to NotFound
- [ ] 3.8 Confirm tenant `/login` page is unchanged and does NOT link to `/platform/login`
- [ ] 3.8b Confirm `/platform/login` displays the explicit cross-link to tenant `/login` per the spec subheading scenario ("If you're a CoC administrator, [go to your CoC sign-in page →]")

## 4. SPA routes

- [ ] 4.1 Build `frontend/src/pages/platform/PlatformLogin.tsx` — email + password form, heading "Platform Operator Sign-In", subheading with link to tenant `/login`, `data-testid="platform-login-{submit,email,password}"`, posts to `/api/v1/auth/platform/login`, branches on response shape (MFA-setup vs MFA-verify scoped token)
- [ ] 4.2 Build `frontend/src/pages/platform/PlatformMfaEnroll.tsx` — renders QR + manual secret + supported-authenticators list ("Google Authenticator, Microsoft Authenticator, 1Password, Authy, Bitwarden"); on confirm posts to `/auth/platform/mfa-confirm`; on success transitions to backup-codes view
- [ ] 4.3 Build `frontend/src/pages/platform/components/BackupCodesDisplay.tsx` — renders 10 codes via React text-node interpolation (`{code}` only — `dangerouslySetInnerHTML` is forbidden, enforced by ESLint rule `react/no-danger` scoped to this file); checkbox "I have saved my backup codes" + Continue button (disabled until checked); Print + Copy-to-Clipboard buttons (both gated by ConfirmActionModal); on Copy confirm, schedule `setTimeout(() => navigator.clipboard.writeText(''), 30000)` to auto-clear clipboard. Verify backend `/auth/platform/mfa-confirm` response carries `Cache-Control: no-store, no-cache, must-revalidate` and `Pragma: no-cache` headers (file v0.54 backend task if missing). Add unit test that a code containing `<script>` renders as literal text
- [ ] 4.4 Build `frontend/src/pages/platform/components/PrintFriendlyCodes.tsx` — `@media print` CSS strips operator email + URL + timestamp + QR; only heading + 10 codes + "store securely" notice render in print view
- [ ] 4.5 Build `frontend/src/pages/platform/components/ConfirmActionModal.tsx` — generic modal with three variants:
  - **Print variant**: copy *"These codes will be sent to your printer or saved as a PDF. They will appear in your OS print queue and may be retained by network printers. Continue?"*; primary button labeled exactly "Cancel" (default-focused); secondary button labeled exactly "Print Anyway"
  - **Copy variant**: copy *"These codes will be placed on your system clipboard. Clipboard managers and pasted-into apps may retain them. The clipboard will auto-clear in 30 seconds. Continue?"*; primary button labeled exactly "Cancel" (default-focused); secondary button labeled exactly "Copy Anyway"
  - **Destructive-action variant**: typed-confirmation field requiring exact match of tenant slug; primary button "Cancel" (default-focused); secondary button matches action verb (e.g. "Suspend Tenant")
- [ ] 4.6 Build `frontend/src/pages/platform/PlatformMfaVerify.tsx` — TOTP input (6 digits) OR backup code input (8 chars); posts to `/auth/platform/login/mfa-verify`; on success stores JWT in sessionStorage + redirects to `/platform/dashboard`
- [ ] 4.7 Build `frontend/src/pages/platform/PlatformDashboard.tsx` — `<h1>Platform Operator Dashboard</h1>` heading; header with operator email + last-login timestamp + MFA-enrolled date + backup-codes-remaining badge (amber@3, red@1); fetches `/api/v1/auth/platform/me` on mount; renders action cards in 3 categories (Tenant Lifecycle, Operator Management, System Status). Each category title is `<h2>`; each action card title is `<h3>` (supports screen-reader heading navigation)
- [ ] 4.8 Build `frontend/src/pages/platform/platformActions.ts` — config array driving the 7 lifecycle action cards (id, title, description, endpoint, method, flagGate, dangerLevel)
- [ ] 4.9 Build `frontend/src/pages/platform/components/PlatformActionCard.tsx` — renders one action; disabled-with-tooltip when `flagGate=fabt.tenant.lifecycle.enabled` and that flag is off (tooltip: "Tenant lifecycle is disabled in this deployment. Contact platform engineering to enable.")
- [ ] 4.10 Build `frontend/src/pages/platform/components/PlatformOperatorBanner.tsx` — persistent banner using `--color-platform` token; shows operator email + Logout + 15-min countdown ("Session expires in X:XX", amber@2min, red@30s); always rendered on `/platform/*` routes via layout wrapper

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

- [ ] 9.1 Confirm `--color-platform` token chosen color value (default proposal: amber/orange family distinct from `--color-warning`); operator approves before commit
- [ ] 9.2 Confirm operator email shown in banner — full email vs masked (`c***@gmail.com`)? Default: full email (only operator sees it).
- [ ] 9.3 Confirm "Print" button label vs "Save as PDF" — UK-English vs US-English? Default: "Print".
