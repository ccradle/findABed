# Design: platform-operator-ui

## Context

Phase G-4 (v0.53.0) shipped a production-ready platform-operator backend: separate `platform_user` identity, `/auth/platform/login` + MFA enrollment + verify, lockout, backup codes, audited `@PlatformAdminOnly` endpoints. End-to-end validated this session via curl. The missing piece is the SPA layer that turns 2-curl-per-action operations into a usable workflow.

The change is constrained by:
- **Backend mostly frozen at v0.53** — except for the two small additions (`/me` + `/logout`) ratified in warroom review. No schema changes, no Flyway migrations.
- **Demoguard preservation** — the SPA login route is public-static-JS, but the API endpoint POST stays demoguard-blocked on prod. Operators reach the page via SSH tunnel to nginx :8081 (existing pattern).
- **Anti-confusion** — operators now have TWO logins (tenant admin + platform operator). Visual + URL + copy isolation is mandatory.

## Goals / Non-Goals

**Goals**
- Operator can complete "suspend tenant X with audit trail" in <90 seconds from a clean browser state (after MFA already enrolled).
- Frontend-only rollback path via `VITE_PLATFORM_UI_ENABLED` build flag.
- Zero regression on dark mode, WCAG 2.1 AA, typography tokens.
- Backup-codes display is one-shot and survives no UX path that resurrects them.

**Non-Goals**
- Operator self-management (creating operator #2 from inside the UI). v0.55.
- Refresh tokens or silent JWT renewal. Operator re-MFAs every 15 minutes is the correct posture.
- Mobile-first design. Platform-operator work is desktop-first; mobile-responsive is "doesn't break" not "optimized for."
- Multi-language. English only for v0.54; i18n is a v0.55+ follow-up if a non-English-speaking operator joins.

## Decisions

### Decision D1 — sessionStorage, not localStorage, for platform JWT
**What:** Platform JWT lives in `sessionStorage`. Tab close = forced re-login.
**Why:** localStorage survives tab close + cross-tab and is XSS-readable. Platform JWT carries `PLATFORM_OPERATOR` role — too sensitive. httpOnly cookie would be ideal but requires backend Set-Cookie + CSRF plumbing not in v0.53 scope.
**Tradeoff:** Operator re-logs-in after closing the tab. Acceptable for the user class.
**Ratified by:** Marcus (security), Alex (frontend lead).

### Decision D2 — Separate `PlatformAuthContext`, NOT a generalization of `useAuth`
**What:** Build `PlatformAuthContext.tsx` and `usePlatformAuth` as siblings to the existing tenant auth context. Zero shared mutable state.
**Why:** Generalizing the existing context would create a class of cross-contamination bugs (stale tenant JWT served to a platform endpoint, etc.). Two separate stores, two separate hooks, two separate guards is mechanically clearer.
**Tradeoff:** Slight code duplication. Worth it.

### Decision D3 — `fabt.tenant.lifecycle.enabled=false` posture: render disabled with tooltip
**What:** Lifecycle action buttons render in the dashboard but are visually disabled with tooltip "Tenant lifecycle is disabled in this deployment. Contact platform engineering to enable."
**Why:** Hiding entirely obscures the operator's mental model of "what platform operators CAN do." Disabled-with-tooltip trains the operator and is honest about deployment posture.
**Tradeoff:** Slight visual clutter. Worth it for training value.
**Ratified by:** Alex (frontend lead), Devon (training), Sam (UX).

### Decision D4 — Persistent "PLATFORM OPERATOR MODE" banner with new `--color-platform` token
**What:** A new semantic color token `--color-platform` (NOT reused `--color-warning`). Banner shows operator email + Logout button + session-expiry countdown. Always visible on every `/platform/*` route.
**Why:** Operators have two logins; the banner is the single biggest anti-confusion lever. A dedicated token (rather than reusing `--color-warning`) makes the semantic distinct — "warning" means something specific in the design system, and "platform mode" deserves its own.
**Tradeoff:** One more token to audit for WCAG contrast. Add to the existing axe-core sweep.
**Ratified by:** Sam (UX) + operator decision Q3.

### Decision D5 — Add `GET /me` and `POST /logout` to backend (un-freezing v0.53 scope, narrowly)
**What:**
- `GET /api/v1/auth/platform/me` returns `{email, mfaEnabled, lastLoginAt, mfaEnabledAt, backupCodesRemaining}`. No last-login-IP (deferred to v0.55).
- `POST /api/v1/auth/platform/logout` returns 204. Server-side no-op for v0.54; future hook for token revocation when Phase H+ adds the `token_invalidation_at` column.
**Why:** Without `/me`, the dashboard renders "—" placeholders for everything except email (decoded from JWT `sub` client-side). Backup-codes-remaining is the urgency-driver Sam + Jordan called out — without it, operators don't know they're 1 backup code from a Sev-1.
**Tradeoff:** ~3 backend tasks added. Justified.
**Ratified by:** Operator decision Q1 (chose option C: hybrid with minimal backend addition).

### Decision D6 — Print-friendly backup codes with 5 Marcus conditions
**What:** Print button is allowed. Conditions:
1. `@media print` CSS strips everything except heading + 10 codes + "store securely" notice. No operator email, URL, timestamp, QR.
2. Confirmation modal before `window.print()` fires, naming OS-print-queue + network-printer retention as risks.
3. No client-side telemetry on the print action — no analytics event, no Sentry breadcrumb.
4. `Cache-Control: no-store` + codes rendered from a one-shot response not re-fetchable. Browser back-button cannot resurrect them. Asserted by Playwright.
5. Copy-to-clipboard button gets the same confirmation modal pattern. Don't pretend clipboard is safer.
**Why:** Paper-in-a-safe is the strongest offline recovery for this user class. Worse than print: a screenshot synced to iCloud, or codes pasted into a password manager that becomes the SPOF.
**Tradeoff:** Multiple Marcus conditions, all merge-blocking, all cheap.
**Ratified by:** Marcus (security) — APPROVE WITH CONDITIONS.

### Decision D7 — `VITE_PLATFORM_UI_ENABLED` build-time flag for rollback
**What:** A Vite env var gates the entire `/platform/*` route tree. Set to `false` → routes return 404 (React Router fallback to NotFound).
**Why:** Frontend-only rollback path. If the new UI breaks in prod, redeploy with flag off; backend is untouched so no DB rollback needed.
**Tradeoff:** One more env var to manage. Documented in the runbook.
**Ratified by:** Jordan (SRE).

### Decision D8 — 15-minute hard JWT expiry with visible countdown, no silent refresh
**What:** Banner shows "Session expires in X:XX." Goes amber at 2 minutes, red at 30 seconds. At 0, redirect to login with toast: "Session expired — please sign in again." No refresh token.
**Why:** Operator re-MFAs every 15 minutes. Sensitive user class; this is the correct posture. Silent renewal would weaken the security model.
**Tradeoff:** Mid-incident-response 15-min interruptions. Operators can re-MFA in <30s; acceptable.
**Ratified by:** Marcus (security), Jordan flagged for v0.55+ threat-model revisit.

### Decision D9 — JWT scope check on every action POST
**What:** Every action button POST has a 401 handler that wipes sessionStorage + redirects to login. Don't trust that a JWT is valid just because it has the right shape.
**Why:** Defense in depth against backend revocation (when Phase H+ ships) and against bugs that leave a stale JWT in storage.
**Ratified by:** Marcus (security).

### Decision D10 — Action confirmation modals on destructive operations only
**What:** Suspend, unsuspend, hard-delete (when those land) require typed-confirmation of the tenant slug. List/read endpoints do not.
**Why:** Defense against fat-fingering. Typed-confirmation is a cheap forcing function for high-blast-radius operations.
**Ratified by:** Jordan (SRE), Sam (UX).

### Decision D11 — Backup-codes-remaining badge ships in MVP
**What:** Dashboard header shows "8 of 10 backup codes remaining." Amber at 3, red at 1.
**Why:** Drives the regenerate-codes urgency without requiring the regenerate flow itself in MVP. Without it, operators don't know they're approaching MFA-recovery exposure.
**Ratified by:** Sam (UX), Jordan (SRE).

### Decision D12 — Operator #2 activation in v0.54 stays curl-based
**What:** No "operator creates second operator" UI in this slice. Backend doesn't have an endpoint for it either. v0.55+ OpenSpec.
**Why:** Operator #2 onboarding is a one-time event per FABT lifetime. The painful path is the operator's *daily* work, which this slice fixes.
**Ratified by:** Devon (training).

## Architecture sketch

```
frontend/src/
├── auth/
│   ├── AuthContext.tsx                    (existing, tenant)
│   └── PlatformAuthContext.tsx            (NEW — sibling, not generalization)
├── pages/
│   ├── login/                             (existing tenant login — UNCHANGED)
│   └── platform/                          (NEW — lazy-loaded chunk)
│       ├── PlatformLogin.tsx
│       ├── PlatformMfaEnroll.tsx
│       ├── PlatformMfaVerify.tsx
│       ├── PlatformDashboard.tsx
│       ├── PlatformProtectedRoute.tsx
│       ├── platformActions.ts             (config-driven action list)
│       ├── components/
│       │   ├── PlatformOperatorBanner.tsx (persistent across routes)
│       │   ├── PlatformActionCard.tsx
│       │   ├── BackupCodesDisplay.tsx
│       │   ├── PrintFriendlyCodes.tsx     (@media print scoped)
│       │   └── ConfirmActionModal.tsx
│       └── helpers/
│           ├── platformJwt.ts             (sessionStorage + claim parsing)
│           └── platformApi.ts             (fetch wrapper with 401 handler)
├── theme/
│   └── colors.ts                          (add --color-platform token)
└── vite.config.ts                         (VITE_PLATFORM_UI_ENABLED flag)

backend/src/main/java/org/fabt/auth/platform/
├── api/
│   └── PlatformAuthController.java        (ADD 2 methods: getMe + logout)
└── dto/
    └── PlatformOperatorMeDto.java         (NEW)
```

## Risks / Open follow-ups

- **F37 (NEW):** Last-login-IP display — backend already captures it in `platform_admin_access_log.details` for lockout events; for ALL logins we'd need either an audit-log query (slower) or a new `platform_user.last_login_ip` column (Flyway migration). Deferred to v0.55.
- **F38 (NEW):** Server-side token revocation — `POST /logout` is no-op for v0.54. Phase H+ adds `token_invalidation_at` column + JwtService check. Until then, logout = client clears sessionStorage.
- **F39 (NEW):** Refresh token / silent renewal — explicit v0.55+ threat-model revisit. Mid-incident 15-min re-MFA is painful; not painful enough to weaken security in v0.54.
- **F40 (NEW):** Operator-creates-operator-#2 self-management UI — file as separate v0.55 OpenSpec. Until then, op #2 onboarding follows the curl bootstrap procedure documented in v0.53 runbook.
- **F41 (NEW):** Regenerate-backup-codes flow — file as separate v0.55 OpenSpec with sensitive-action re-MFA ladder. v0.54 ships the urgency badge but not the regenerate path.
- **F42 (NEW):** Favicon swap on `/platform/*` — Sam wanted, Alex pushed back. v0.55 micro-follow-up.
- **F43 (NEW):** Backend Prometheus counters audit — confirm `platform_login_attempts_total`, `platform_mfa_verify_total{outcome}`, `platform_action_invoked_total{action}` exist. If not, file separate v0.55 backend follow-up.
- **F44 (NEW):** Print-utilization signal is intentionally absent (Marcus condition #3 forbids client-side telemetry on print). Operator interview at v0.55 to confirm whether print is the chosen offline-recovery path or copy-to-password-manager dominates. If print is rare, the print button can be removed in v0.56.
- **F45 (NEW):** Sole-operator MFA reset path is currently DB-only (direct psql UPDATE on Oracle VM). v0.55 should add a documented `mvn` Java tool similar to `org.fabt.tooling.HashPasswordCli` that performs the bootstrap-equivalent reset (`password_hash = NULL, mfa_enabled = false, mfa_secret = NULL, account_locked = true`) with safety guards (refuses to run when >1 active platform_user exists, requires explicit confirmation flag).

## Migration / rollout

1. Build with `VITE_PLATFORM_UI_ENABLED=false` in initial deploy → routes 404 even though code is shipped. Smoke test the rest of v0.54.
2. Flip flag to `true` in a follow-up redeploy (no code change, just env).
3. Operator validates new flow against dev seed data via the training Playwright spec.
4. If anything regresses, redeploy with flag off — rolls back the UI without DB or backend impact.

## Test plan summary

**Backend (~3 tasks):** IT for `GET /me` (returns expected fields, requires platform JWT, rejects tenant JWT). IT for `POST /logout` (returns 204, requires platform JWT).

**Frontend unit (per-component):** PlatformAuthContext storage/retrieval; route guard redirect logic; banner countdown timer; backup-codes confirmation gate.

**Playwright e2e (~5 specs):**
- `platform-login.spec.ts` — happy path login → MFA verify → dashboard.
- `platform-mfa-enroll.spec.ts` — first login enroll flow + backup codes display + checkbox gate.
- `platform-print-codes.spec.ts` — print confirmation modal + `@media print` strips PII + back-button cannot resurrect codes.
- `platform-session-expiry.spec.ts` — JWT expiry triggers redirect + toast.
- `platform-disabled-action.spec.ts` — lifecycle button disabled with tooltip when flag off.

**Manual QA:**
- Cross-authenticator MFA enrollment: Google Authenticator, Microsoft Authenticator, 1Password, Authy, Bitwarden on iOS + Android.
- Print-friendly view actually prints to a real printer + PDF.
- WCAG axe-core sweep on all 4 routes.
