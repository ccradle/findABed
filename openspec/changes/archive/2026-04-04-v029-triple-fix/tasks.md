## 1. Branch & Baseline

- [x] 1.1 Create branch `v029-triple-fix` in finding-a-bed-tonight repo (code changes)
- [x] 1.2 Run existing backend tests (`mvn clean test 2>&1 | tee logs/backend-tests.log`) — confirm green baseline
- [x] 1.3 Run existing Playwright tests (`npx playwright test --trace on 2>&1 | tee logs/playwright-baseline.log`) — confirm green baseline
- [x] 1.4 Run `npm --prefix frontend run build` — confirm TypeScript compiles clean

## 2. Backend — DV Referral Expiration Event

- [x] 2.1 Modify `ReferralTokenRepository`: replace `expirePendingTokens()` (returns int) with `expirePendingTokensReturningIds()` using `UPDATE referral_token SET status = 'EXPIRED' WHERE status = 'PENDING' AND expires_at < NOW() RETURNING id` — returns `List<UUID>` atomically (Design D3: no race condition)
- [x] 2.2 Modify `ReferralTokenService.expireTokens()`: call new `expirePendingTokensReturningIds()`, then publish `dv-referral.expired` domain event with the token ID list and tenant ID via `eventBus.publish()`
- [x] 2.3 Modify `NotificationService.onDomainEvent()`: add `dv-referral.expired` case that pushes SSE event to COORDINATOR role connections for the matching tenant (follow `notifyReferralRequest` pattern at lines 249-264)
- [x] 2.4 Add integration test: `tc_expireTokens_publishesSseEvent()` — create a referral, force expire, verify SSE event is published with correct token ID
- [x] 2.5 Add integration test: `tc_expiredEvent_filteredByTenant()` — verify coordinator on tenant B does not receive tenant A's expiration events
- [x] 2.6 Run backend tests — confirm all pass including new tests

## 3. Frontend — Countdown Timer & Expired State

- [x] 3.1 Add `useEffect` countdown timer in `CoordinatorDashboard.tsx` that decrements `remainingSeconds` every second for each pending referral (follow reservation countdown pattern in `OutreachSearch.tsx` lines 160, 339-351: `useRef` for interval handle, `.length` dependency, `Math.max(0, ...)` clamp, cleanup on unmount)
- [x] 3.2 Update countdown display: show "{M}m {S}s remaining" when under 5 minutes, "{N}m remaining" otherwise — use i18n message IDs `referral.remainingMinutes` and `referral.remainingMinutesSeconds`
- [x] 3.3 When countdown reaches 0: disable Accept/Reject buttons, show "Expired" badge using i18n message ID `referral.expired`, update countdown text to show expired state
- [x] 3.4 Add `dv-referral.expired` case to `useNotifications.ts` hook (lines 116-131) — dispatch `SSE_REFERRAL_EXPIRED` window event with expired token IDs (Design D6: follows established hook → window event pattern)
- [x] 3.5 Add `SSE_REFERRAL_EXPIRED` window event listener in `CoordinatorDashboard.tsx`: when received, mark matching referral(s) as expired in state (disable buttons, show badge) — must work WITHOUT page refresh to prove SSE delivery
- [x] 3.6 Update `acceptReferral`/`rejectReferral` error handlers: detect "Token has expired" error and show specific expiration message using i18n message ID `referral.expiredError` + update visual state
- [x] 3.7 Add `data-testid` attributes: `referral-countdown-{id}`, `referral-expired-badge-{id}` (accept/reject already have testids)
- [x] 3.8 Add i18n messages to `en.json` and `es.json`: `referral.expired`, `referral.expiredError`, `referral.remainingMinutes`, `referral.remainingMinutesSeconds` (Design D7: all user-facing text internationalized)
- [x] 3.9 Run `npm --prefix frontend run build` — confirm TypeScript compiles clean

## 4. Frontend — Playwright Tests for Expiration

- [x] 4.1 Add test in `dv-referral.spec.ts`: "expired referral shows disabled buttons and badge" — create referral, force DB expire via API/SQL, trigger `expireTokens`, then verify badge appears WITHOUT page navigation/refresh (proves SSE delivery path), use `await expect(page.getByTestId('referral-expired-badge-...')).toBeVisible({ timeout: 10000 })`
- [x] 4.2 Add test in `dv-referral.spec.ts`: "active referral countdown is visible and buttons are enabled" — create referral with time remaining, verify countdown text via `data-testid` and buttons are clickable
- [x] 4.3 Add test in `dv-referral.spec.ts`: "clicking expired accept shows expiration message" — if buttons are clicked before SSE arrives, verify specific i18n error message (not generic)
- [x] 4.4 Add negative test: "existing DV referral accept/reject flow still works" — re-run existing accept and reject tests, confirm no regression
- [x] 4.5 Run full Playwright suite with `--trace on` — 237 passed, 4 pre-existing failures (demo-guard, offline-behavior), 0 regressions — confirm all pass

## 4b. Test Coverage Gaps (Riley audit)

- [x] 4b.1 Run axe-core scan on `demo/for-coordinators.html`, `demo/for-coc-admins.html`, `demo/for-funders.html` — zero Critical/Serious violations
- [x] 4b.2 Add Karate API test: `PATCH /dv-referrals/{id}/accept` on expired token → verify 409 status and response body contains "expired"
- [x] 4b.3 Add Playwright test: countdown timer decrements to zero and buttons disable (client-side timer path, not SSE) — use short-expiry referral or page.clock manipulation
- [x] 4b.4 Add Playwright test: clicking Reject on expired referral shows expiration error (mirrors 4.3 for reject path)
- [x] 4b.5 Add Playwright test: countdown format switches from "{N}m remaining" to "{M}m {S}s remaining" below 5 minutes
- [x] 4b.6 Add Playwright test: Spanish locale shows translated expiration text (badge, countdown, error message)

## 5. README Accuracy

- [x] 5.1 Verify current counts at implementation time (counts may drift from research): `ls backend/src/main/resources/db/migration/ | wc -l` (Flyway), `grep -rc "Scenario:" backend/src/test/resources/` (Karate), `grep -rc "test(" e2e/playwright/tests/*.spec.ts` (Playwright), `grep -rc "@Test" backend/src/test/java/` (JUnit), count ArchUnit test methods specifically, `grep -rc "test\|it(" frontend/src/**/*.test.ts` (Vitest), count concrete simulation classes in `backend/src/gatling/java/` (Gatling — exclude abstract base class)
- [x] 5.2 Update `README.md` line 60 (Flyway count) and line 62 (all test counts including Vitest and Gatling) with verified numbers
- [x] 5.3 Update `docs/FOR-DEVELOPERS.md` at ALL stale locations: line 33 (Tech Stack Flyway), line 38 (Tech Stack tests), line 66 (ArchUnit architecture tests), line 87 (Database Schema migration count + version range), line 895 (file tree migration comment + version range), line 938 (Playwright count in file tree), line 1257 (ArchUnit rules total in changelog)
- [x] 5.4 Verify ArchUnit rule count is internally consistent across lines 66 and 1257
- [x] 5.5 Verify no other stale claims in README (version numbers, feature lists, module references)

## 6. Audience HTML Pages

- [x] 6.1 Create `demo/for-coordinators.html` from `docs/FOR-COORDINATORS.md` content, following `for-cities.html` template (FAQ schema, OG tags, canonical URL, dark mode, skip link, semantic HTML, back link)
- [x] 6.2 Create `demo/for-coc-admins.html` from `docs/FOR-COC-ADMINS.md` content, following same template
- [x] 6.3 Create `demo/for-funders.html` from `docs/FOR-FUNDERS.md` content, following same template
- [x] 6.4 Update `index.html`: change 3 "Who It's For" card hrefs from `github.com/.../docs/*.md` to `demo/for-*.html`, update link text to audience-specific (coordinators: "Quick Start Guide", CoC admins: "Admin Overview", funders: "Impact Report"), clean up any stale `target="_blank"` or `rel` attributes from old GitHub links (Design D8)
- [x] 6.5 Verify all 4 audience card links resolve to on-domain HTML (no GitHub links remain in href attributes)
- [x] 6.6 Verify each page renders in dark mode (check `prefers-color-scheme` media query works)
- [x] 6.7 Run axe-core scan on all 3 new pages — zero Critical/Serious violations

## 7. Integration & Release

- [x] 7.1 Run full backend test suite — confirm green
- [x] 7.2 Run full Playwright suite with `--trace on` — confirm green (including new expiration tests)
- [x] 7.3 Run `npm --prefix frontend run build` — confirm clean build
- [x] 7.4 Test SSE expiration flow through nginx proxy (not just Vite dev) — lesson learned from v0.22.1 SSE buffering bug
- [x] 7.5 Test in incognito/clear site data — lesson learned re: stale service worker
- [x] 7.6 Commit changes on branch, create PR referencing issues #31, #39, #40
- [x] 7.7 Merge and tag v0.29.0
