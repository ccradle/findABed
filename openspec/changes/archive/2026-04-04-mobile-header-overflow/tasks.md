## 1. Branch & Baseline

- [x] 1.1 Create branch `mobile-header-overflow` in finding-a-bed-tonight repo
- [x] 1.2 Run existing backend tests (`mvn clean test 2>&1 | tee logs/backend-tests.log`) — confirm green baseline
- [x] 1.3 Run `npm --prefix frontend run build` — confirm TypeScript compiles clean
- [x] 1.4 Capture baseline mobile screenshots at 412px viewport for before/after comparison

## 2. Mobile Header Implementation

- [x] 2.1 Add `position: relative; z-index: 100` to header in `Layout.tsx` (Design D5 revised — overflow-x: hidden clips dropdown, removed)
- [x] 2.2 Add i18n key `app.nameShort` to `en.json` ("FABT") and `es.json` ("FABT") — brand abbreviation, same in both languages (Design D2)
- [x] 2.3a Conditionally render `app.nameShort` when `isMobile` is true, `app.name` on desktop
- [x] 2.3 Add kebab menu icon button (three-dot `⋮` or SVG) to header, visible only when `isMobile` — add `data-testid="header-kebab-menu"`
- [x] 2.4 Add kebab dropdown menu with `useState` toggle (Design D3): username (display only, `data-testid="header-overflow-username"`), language selector, change password (`data-testid="header-overflow-password"`), security (`data-testid="header-overflow-security"`), sign out (`data-testid="header-overflow-signout"`) — container gets `data-testid="header-overflow-dropdown"`
- [x] 2.5 Wire existing onClick handlers to kebab menu items (change password, security, sign out already have handlers in Layout.tsx)
- [x] 2.6 Move `LocaleSelector` into kebab dropdown on mobile — verify language change works inside the menu and items re-render in selected language
- [x] 2.7 Hide inline username, language selector, change password, security, sign out controls when `isMobile` — notification bell, queue status indicator, and kebab icon remain visible in header bar
- [x] 2.8 Add click-outside handler: `useRef` on dropdown + `useEffect` mousedown listener to close menu (Design D4)
- [x] 2.9 Add Escape key handler to close menu and return focus to kebab icon (WCAG keyboard accessibility)
- [x] 2.9a Add Tab navigation through menu items in logical order; menu closes when focus leaves last item (WCAG 2.1.1, 2.4.3)
- [x] 2.10 Close menu after any action selection (sign out, password, security)
- [x] 2.11 Ensure all menu items have min 44x44px touch targets (WCAG 2.5.5)
- [x] 2.12 Style dropdown: positioned absolute below kebab icon, white background, border, shadow, z-index above page content, dark mode support via existing CSS variables
- [x] 2.13 Run `npm --prefix frontend run build` — confirm TypeScript compiles clean

## 3. Positive Tests — Requirements Met

- [x] 3.1 Playwright test (412px viewport): header shows "FABT" title, notification bell, queue status indicator, kebab icon — no username/password/security/sign-out visible in header bar
- [x] 3.2 Playwright test (412px viewport): page has no horizontal scrollbar (`document.documentElement.scrollWidth <= document.documentElement.clientWidth`)
- [x] 3.3 Playwright test (320px viewport): page has no horizontal scrollbar (WCAG 1.4.10)
- [x] 3.4 Playwright test (412px viewport): tap kebab icon → dropdown appears with all 5 items (username, language, password, security, sign out)
- [x] 3.5 Playwright test (412px viewport): tap outside dropdown → menu closes
- [x] 3.6 Playwright test (412px viewport): press Escape → menu closes
- [x] 3.7 Playwright test (412px viewport): select sign out from kebab → action executes, redirects to login
- [x] 3.8 Playwright test (412px viewport): change language in kebab dropdown → UI re-renders in selected language, menu items translate
- [x] 3.9 axe-core scan at 412px viewport: zero Critical/Serious violations on pages with header visible
- [x] 3.10 Playwright test (412px viewport): Tab through open kebab menu items — focus moves in logical order, menu closes when focus leaves last item
- [x] 3.11 Playwright test (412px viewport, dark mode): open kebab dropdown, verify dropdown visible with dark background — axe-core contrast check
- [x] 3.12 Playwright test (480px viewport — Galaxy S25 Ultra): header shows kebab layout, no horizontal scroll, kebab functional

## 4. Negative Tests — Nothing Broken

- [x] 4.1 Playwright test (1024px viewport): desktop header shows full title "Finding A Bed Tonight" + all inline controls — NO kebab icon visible
- [x] 4.2 Playwright test (1024px viewport): all desktop header buttons functional (password, security, sign out, language, notifications)
- [x] 4.3 Playwright test (768px viewport): verify breakpoint boundary — at exactly 768px, desktop layout shows (no kebab)
- [x] 4.4 Playwright test (767px viewport): verify breakpoint boundary — at 767px, mobile layout shows (kebab visible)
- [x] 4.5 Run existing Playwright test suite (`--trace on`) — confirm zero regressions in coordinator, outreach, admin, DV referral tests
- [x] 4.6 Run existing backend test suite — confirm zero regressions (header is frontend-only, but verify no side effects)
- [x] 4.7 Capture after-change mobile screenshots at 412px, 480px, 768px, 1024px for visual comparison

## 5. Integration & Release

- [x] 5.1 Run `npm --prefix frontend run build` — confirm clean build
- [x] 5.2 Run full Playwright suite with `--trace on` — confirm green (including new mobile tests)
- [x] 5.3 Test through nginx proxy (lesson learned: SSE/layout issues can differ between Vite dev and nginx)
- [x] 5.4 Test in incognito (lesson learned: stale SW may cache old Layout.tsx)
- [x] 5.5 Update test counts in README.md and FOR-DEVELOPERS.md if new Playwright tests change the totals
- [x] 5.6 Commit on branch, create PR referencing #55
- [x] 5.7 Wait for CI scans to pass (lesson learned: don't release until scans are green)
- [x] 5.8 Merge and tag (version TBD — likely v0.29.1 or v0.30.0)
- [x] 5.9 Deploy using `docs/oracle-update-notes-v*.md` runbook pattern (static content to `/var/www/findabed-docs/` via scp, app code via docker rebuild)
- [x] 5.10 Run deploy verification script against live site
