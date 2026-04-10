## Tasks

### Setup

- [x] T-0: Create branch `feature/coordinator-shelter-assignment` from main

### DV Referral Expiry Fix (Critical — bundled)

- [x] FIX-1: Remove `@Transactional` from `ReferralTokenService.expireTokens()`, add fail-fast dvAccess assertion, add diagnostic logging
- [x] FIX-2: Remove `@Transactional` from `ReferralTokenPurgeService.purgeTerminalTokens()`, add fail-fast dvAccess assertion, add diagnostic logging
- [x] FIX-3: Integration test `DvReferralExpiryRlsTest` — proves expireTokens() works for DV referrals when called without outer TenantContext (as @Scheduled does)
- [x] FIX-4: Run full backend test suite — all green (459 tests, 0 failures, 0 errors)
- [x] FIX-5: Document `@Transactional + runWithContext` pattern rule in `docs/FOR-DEVELOPERS.md` Troubleshooting section
- [x] FIX-6: Merge PR #93 to main, pull on Oracle VM
- [x] FIX-7: Build: `mvn clean package -DskipTests -q` — old 0.31.0 JAR removed, single 0.31.2 JAR verified
- [x] FIX-8: Docker image: `docker build --no-cache`
- [x] FIX-9: Restart: `docker compose ... up -d --force-recreate backend`
- [x] FIX-10: Health check: UP
- [x] FIX-11: Verify class in container: ReferralTokenService.class present, version=0.31
- [x] FIX-12: Stuck tokens auto-expired by fix on first run: `expireTokens: dvAccess=true, expired=3`
- [x] FIX-13: Subsequent runs: `expireTokens: dvAccess=true, expired=0` every 60s
- [x] FIX-14: Smoke tests: login, notifications, shelters, users all 200. Zero PENDING referrals remain.
- [x] FIX-15: Monitoring: dvAccess=true on every run, purgeTerminalTokens also working (cleaned 2 old tokens)
- [x] FIX-16: Cleanup: `docker image prune -f`, single JAR in target/

### Notification Dismiss Fix (discovered during deploy verification)

- [x] FIX-17: Fix `useNotifications.ts` dismiss callback — call `PATCH /notifications/{id}/read` before removing from local state. Without this, CRITICAL notifications reappear after page refresh or SSE reconnect.
- [x] FIX-18: Frontend build clean (`npm run build` — zero errors)
- [x] FIX-19: Deploy frontend fix to findabed.org, verified via Playwright test: dismiss → refresh → notification stays gone
- [x] FIX-20: User confirmed fix works in browser

### Backend — User Shelters API

- [x] T-1: `GET /api/v1/users/{id}/shelters` — `UserShelterController` in shelter module (ArchUnit: auth can't access shelter repos). Uses `CoordinatorAssignmentRepository.findShelterSummariesByUserId()` join query. COC_ADMIN/PLATFORM_ADMIN.
- [x] T-2: Integration test: coordinator with 2 assigned shelters → returns 2 shelter objects
- [x] T-3: Integration test: user with no assignments → returns empty array (+ authorization test: outreach worker gets 403)

### Frontend — Shelter Edit: Assigned Coordinators (Primary)

- [x] T-4: Create `CoordinatorCombobox` component — W3C APG Combobox Pattern, role="combobox", aria-haspopup, aria-activedescendant, keyboard nav
- [x] T-5: Fetch eligible coordinators on mount — `GET /api/v1/users` filtered to COORDINATOR/COC_ADMIN, `GET /api/v1/shelters/{id}/coordinators` for current assignments
- [x] T-6: DV shelters — dvAccess badge in dropdown, warning on non-dvAccess users
- [x] T-7: Integrated into `ShelterForm.tsx` after capacities section (edit mode only). Added `GET /shelters/{id}/coordinators` backend endpoint.
- [x] T-8: On save — diff staged vs original, POST additions, DELETE removals (Promise.all)
- [x] T-9: Chip styling — color tokens (primaryLight, primaryText, border), 44px touch targets, dark mode via CSS custom properties
- [x] T-10: i18n — en + es for all 5 strings (assignedCoordinators, searchCoordinators, noCoordinatorsAssigned, removeCoordinator, dvAccessWarning)

### Frontend — User Edit: Assigned Shelters (Read-Only)

- [x] T-11: Added "Assigned Shelters" section to `UserEditDrawer.tsx` after dvAccess checkbox. Fetches from `GET /api/v1/users/{id}/shelters` on drawer open.
- [x] T-12: Shelter names as read-only linked chips → `/coordinator/shelters/{id}/edit?from=/admin`
- [x] T-13: "No shelters assigned" empty state with color.textMuted
- [x] T-14: i18n: en + es for assignedShelters, noSheltersAssigned

### Frontend — Tests

- [x] T-15: Playwright: admin opens shelter edit → "Assigned Coordinators" section visible with combobox
- [x] T-16: Playwright: admin types coordinator name → dropdown filters → select adds chip
- [x] T-17: Playwright: admin removes chip → chip disappears (staged, not persisted)
- [x] T-18: Playwright: admin saves shelter → assignment persisted (verify via API)
- [x] T-19: Playwright: admin opens user edit drawer → "Assigned Shelters" chips visible
- [x] T-20: Playwright: WCAG — combobox has role="combobox", chips have aria-label, keyboard navigation works

### Documentation

- [x] T-21: Update docs/FOR-DEVELOPERS.md — added `GET /users/{id}/shelters` and `GET /shelters/{id}/coordinators` endpoints
- [~] T-22: REJECTED 2026-04-10 — Update docs/asyncapi.yaml deferred. The coordinator-shelter assignment endpoints are REST CRUD only; no new domain events were added that would warrant an AsyncAPI channel. If a future change adds `coordinator.assigned` / `coordinator.unassigned` events for the SSE bell badge, that change will own the AsyncAPI update.

### Verification

- [x] T-23: npm run build — zero errors (verified after every commit)
- [x] T-24: ESLint clean — zero errors on all changed files
- [x] T-25: Full backend test suite — 467 tests, 0 failures, 0 errors
- [x] T-26: Full Playwright suite through nginx — all green. Ran as part of the v0.32.0 release CI gate (PR merged 2026-04-09; Playwright job exit 0 in the same workflow run that promoted the build to release).
- [x] T-27: Merge to main (v0.32.0, 2026-04-09), tag, GitHub release published. **Deploy held** per project decision — will bundle with v0.33.0 alongside coc-admin-escalation per the deploy plan. The merge/tag/release portions of T-27 are complete; the deploy portion is intentionally pending.
