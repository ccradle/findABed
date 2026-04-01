## Tasks

### Backend Implementation
- [x] Task 0: Create feature branch — `git checkout -b overflow-beds-management main`
- [x] Task 1: ReservationService.java — hold check uses `effectiveAvailable = bedsAvailable + overflowBeds` (no new imports, BedAvailability already in scope)
- [x] Task 2: BedSearchService.java — ranking comparator uses `bedsAvailable + (surgeActive ? overflowBeds : 0)` for primary and tertiary sort
- [x] Task 3: BedSearchService.java — cache key: NOT needed. Cache stores raw availability data (List<BedAvailability>), ranking is computed AFTER cache read using surgeActive parameter. Same data, different sort order per-request. No stale ranking risk.

### Frontend — Coordinator Dashboard
- [x] Task 4: Fetch surge state in CoordinatorDashboard.tsx (GET /api/v1/surge-events, same pattern as OutreachSearch)
- [x] Task 5: Add overflow stepper (StepperButton pattern) visible only when surge active, with data-testid attributes
- [x] Task 6: Pre-populate overflow from latest snapshot: change `overflowBeds: 0` (line 133) to `overflowBeds: a?.overflowBeds ?? 0`
- [x] Task 7: Wire existing i18n keys `surge.overflowBeds` → "Temporary Beds" and `surge.overflowHint`; update key text from "Overflow Beds" to "Temporary Beds" (en + es)
- [x] Task 8: Add updateOverflow() state handler (same pattern as updateAvailField but for overflow)

### Frontend — Outreach Search
- [x] Task 9: Compute `effectiveAvailable = activeSurge ? bedsAvailable + overflowBeds : bedsAvailable`; use for badge display count
- [x] Task 10: Replace red `+N overflow` text (line 744) with "(includes N temporary beds)" in `color.textMuted`
- [x] Task 11: Hold This Bed button and Request Referral button use `effectiveAvailable > 0` instead of `a.bedsAvailable > 0`
- [x] Task 12: Add i18n key `search.includesTemporary`: "(includes {count} temporary beds)" / "(incluye {count} camas temporales)"

### Accessibility
- [x] Task 13: Overflow stepper aria-labels via StepperButton (same pattern as existing Total/Occupied steppers)
- [x] Task 14: Overflow value display has aria-label with count context
- [x] Task 15: Verify `color.textMuted` contrast against `color.successBg` badge background in both light and dark mode

### Backend Tests — Positive
- [x] Task 16: Integration test — hold SUCCEEDS at overflow-only shelter (0 regular + N overflow → effectiveAvailable > 0)
- [x] Task 17: Integration test — hold SUCCEEDS with mixed capacity (regular + overflow both contribute)
- [x] Task 18: Integration test — search ranking includes overflow during surge (shelter with overflow ranks above shelter without)
- [x] Task 19: Integration test — cache key changes on surge state (search returns fresh ranking after surge activation)

### Backend Tests — Negative
- [x] Task 20: Integration test — hold REJECTED when effectiveAvailable = 0 (0 regular + 0 overflow)
- [x] Task 21: Integration test — no surge: ranking uses only bedsAvailable (overflow ignored in sort even if overflow > 0 from stale data)
- [x] Task 22: Integration test — overflow does NOT alter beds_available derivation (getBedsAvailable() = total - occupied - on_hold, unchanged)

### Backend Tests — Concurrency (Riley: "Try to break this")
- [x] Task 23: Integration test — concurrent last-overflow-bed hold: 2 workers hold simultaneously when effectiveAvailable = 1 (0 regular + 1 overflow). One succeeds, one gets 409. beds_on_hold = exactly 1.
- [x] Task 24: Integration test — concurrent overflow update + hold: coordinator updates overflow to 0 while worker holds the last overflow bed. Verify no negative availability.
- [x] Task 25: Integration test — surge deactivates during hold creation: hold should still succeed if snapshot had overflow at creation time (point-in-time correctness)

### Playwright Tests — Positive
- [x] Task 26: Overflow stepper visible during active surge, hidden when no surge
- [x] Task 27: Coordinator saves overflow value, re-opens card → value persists
- [x] Task 28: Outreach search shows combined count during surge (e.g., "25" not "5 +20")
- [x] Task 29: Transparency note "(includes N temporary beds)" visible when overflow > 0 during surge
- [x] Task 30: Hold This Bed button visible when ONLY overflow beds available during surge (0 regular + N overflow)

### Playwright Tests — Negative / Regression
- [x] Task 31: No surge: outreach search shows bedsAvailable only, no transparency note, no "overflow" or "temporary" text
- [x] Task 32: No surge: coordinator dashboard has no overflow stepper
- [x] Task 33: Existing coordinator-availability-math.spec.ts tests still pass (INV-9 math unchanged)
- [x] Task 34: Existing coordinator-beds.spec.ts tests still pass (steppers for Total/Occupied/On-Hold unchanged)
- [x] Task 35: Existing surge integration tests still pass
- [x] Task 36: Dark mode screenshot — overflow stepper and transparency note render correctly with design token colors

### Documentation & Verification
- [x] Task 37: Update FOR-COORDINATORS.md — "During White Flag nights" section with overflow reporting instructions
- [x] Task 38: Update i18n: change `surge.overflowBeds` from "Overflow Beds" to "Temporary Beds" (en + es)
- [x] Task 39: ESLint + TypeScript check on all modified files
- [x] Task 40: Full frontend lint (entire src/)
- [x] Task 41: Run full backend test suite (332+ tests)
- [x] Task 42: Run full Playwright suite (chromium + nginx), verify 0 new failures
