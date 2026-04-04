## Why

Three open issues (#31, #39, #40) block external demos and erode trust across key personas. Issue #31 is a DV safety bug where expired referral tokens remain clickable — Sandra Kim wastes her 3-5 tap budget, and Keisha Thompson's clients face delayed safety screening. Issue #40 has stale test counts and migration numbers that undermine Teresa Nguyen's procurement review and Priya Anand's funder evaluation. Issue #39 sends Rev. Alicia Monroe and funders to raw GitHub markdown instead of professional on-domain pages, bleeding SEO authority from findabed.org. All three are low-to-medium effort and can ship together as v0.29.0.

## What Changes

### DV Referral Expiration (Issue #31)
- Backend: `expireTokens()` publishes a `dv-referral.expired` SSE event when tokens are batch-expired
- Backend: `NotificationService` handles `dv-referral.expired` and pushes to COORDINATOR role
- Frontend: `useNotifications.ts` hook adds `dv-referral.expired` case to dispatch window event
- Frontend: Live countdown timer on pending referrals (decrementing `remainingSeconds` every second)
- Frontend: When countdown reaches 0 or SSE expiration event received, buttons disable and show internationalized "Expired" badge
- Frontend: Specific error handling for expired-token API responses (not generic error)
- Frontend: i18n message IDs for expired badge and error text in `en.json` and `es.json`
- Add `data-testid` attributes for all new/modified interactive elements

### README Accuracy (Issue #40)
- Update Flyway migration count: 30 → (verify at implementation; currently 33 files)
- Update Karate scenario count: 73 → (verify at implementation; currently ~160 scenarios)
- Update Playwright test count: 217 → (verify at implementation; currently ~231 tests)
- Update JUnit/ArchUnit test count: 351 → (verify at implementation; currently ~354 @Test)
- Fix counts in `README.md` (1 location) and `docs/FOR-DEVELOPERS.md` (4 locations: lines 33, 38, 87, 895)
- Fix ArchUnit rule count discrepancy (line 66 says 21, line 1257 says 22)

### Audience Page Conversion (Issue #39)
- Create `demo/for-coordinators.html` from `docs/FOR-COORDINATORS.md`
- Create `demo/for-coc-admins.html` from `docs/FOR-COC-ADMINS.md`
- Create `demo/for-funders.html` from `docs/FOR-FUNDERS.md`
- Follow established pattern from `demo/for-cities.html` (FAQ schema, OG tags, dark mode, WCAG)
- Update `index.html` to point all 3 cards to on-domain HTML pages with audience-specific link text (not generic "Read more")

## Capabilities

### New Capabilities
- `referral-expiration-ui`: Frontend countdown timer, disabled button state, and "Expired" badge for DV referral tokens that reach expiration on the coordinator dashboard

### Modified Capabilities
- `dv-referral-token`: Backend publishes `dv-referral.expired` event from `expireTokens()` scheduled task
- `sse-notifications`: `NotificationService` handles new `dv-referral.expired` event type, pushes to coordinators
- `audience-specific-docs`: Convert 3 remaining audience pages from GitHub markdown links to on-domain HTML
- `readme-navigation-hub`: Correct stale test counts and migration numbers in README.md and FOR-DEVELOPERS.md

## Impact

**Backend (finding-a-bed-tonight/backend):**
- `ReferralTokenService.java` — add event publishing to `expireTokens()`
- `ReferralTokenRepository.java` — replace `expirePendingTokens()` with `UPDATE...RETURNING` variant
- `NotificationService.java` — add `dv-referral.expired` handler
- `DvReferralIntegrationTest.java` — add SSE expiration event and tenant isolation tests

**Frontend (finding-a-bed-tonight/frontend):**
- `useNotifications.ts` — add `dv-referral.expired` event dispatch
- `CoordinatorDashboard.tsx` — countdown timer, button disable logic, expired badge, error handling
- `en.json` / `es.json` — i18n messages for expired badge and error text
- New Playwright tests for expiration flow in `dv-referral.spec.ts`

**Docs site (findABed/):**
- `index.html` — update 3 audience card hrefs
- `demo/for-coordinators.html` — new file
- `demo/for-coc-admins.html` — new file
- `demo/for-funders.html` — new file

**Docs (finding-a-bed-tonight/):**
- `README.md` — test count corrections (line 60, 62)
- `docs/FOR-DEVELOPERS.md` — test count corrections (lines 33, 38, 66, 87, 895, 938, 1257)
