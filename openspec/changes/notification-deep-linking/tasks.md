## 0. Setup

> **Branching strategy:** This change ships in 4 phases (see implementation plan), each merging to main independently. Create a new phase branch from **updated** main at the START of each phase. Do NOT use a single long-lived branch.

- [x] 0.1 Switch to the code repo (`finding-a-bed-tonight`), checkout `main`, pull latest, then create and switch to branch `feature/issue-106-phase1-deeplink-foundation` from `main`. (Phase 1 branch.)
- [x] 0.2 **Backend endpoint evaluation:** `GET /api/v1/reservations` returns ONLY HELD for current user (`ReservationController.java:67-73` — `reservationService.getActiveReservations(userId)`). No status filter, no date range. **Phase 3 requires backend addition.** Decision: extend existing endpoint with optional `status=...&sinceDays=N` params — defaults preserve current behavior for existing consumers. Task 8.1 is now REQUIRED (not optional).
- [x] 0.3 **Measurement gate decision:** escalation thresholds are 1h/2h/3.5h/4h per `EscalationPolicy.java`. Worst case per referral: `referral.requested` + 4 escalations = **5 notifications max**. Per-notification PATCH is acceptable at this volume. Decision: stay with per-notification PATCH for Phase 3. Run empirical measurement in 7.1a; if p95 exceeds 500ms, revisit in Phase 4 task 8.2.
- [x] 0.4 **SSE fallback verification** (Dr. Whitfield / W-1): verify the bell's REST fallback polling works when SSE is blocked. Test by disabling SSE via browser DevTools or network rules and confirming bell unread count still updates on next page load or REST refresh. Document behavior for hospital IT environments. **FINDING:** `useNotifications.ts` fetches REST baseline once on mount (works without SSE). No periodic polling — new notifications require page reload in SSE-blocked environments. For Phase 1 deep-linking scope this is sufficient (deep-linking operates on already-visible notifications). Tracked as Phase 4 follow-up: add REST polling interval when SSE disconnected.

## 0a. Backend payload fixes (must ship before frontend deep-linking works)

- [x] 0a.1 Add `shelterId` to `SHELTER_DEACTIVATED` notification payload in `ShelterService.java` (~line 467-468). Change `Map.of("shelterName", shelter.getName(), "reason", reason.name())` to also include `"shelterId", shelterId.toString()`. Marcus Webb lens: shelter UUID alone is not a VAWA leak — address and name remain the protected fields.
- [x] 0a.2 Add `reservationId` to `HOLD_CANCELLED_SHELTER_DEACTIVATED` notification payload in `ShelterService.java` (~line 493-494). Use `hold.reservationId().toString()` from the `CancelledHoldSummary` already in scope. (Also included `shelterId` for parity — enables richer UX context without VAWA risk.)
- [x] 0a.3 Update `ShelterDeactivationIntegrationTest.java` — add assertions on notification payload fields: `SHELTER_DEACTIVATED` includes `shelterId`; `HOLD_CANCELLED_SHELTER_DEACTIVATED` includes `reservationId`. (Added to `test_deactivate_withHolds_cancelsHoldsAndNotifies` and `test_deactivate_dvShelter_notificationRestricted`.)
- [x] 0a.4 Run deactivation integration tests to confirm payload changes don't break existing 12 tests. **Result:** 12/12 tests pass (27.55s). New payload assertions (shelterId on SHELTER_DEACTIVATED, reservationId+shelterId on HOLD_CANCELLED_SHELTER_DEACTIVATED) all green.

## 1. Frontend — Core routing changes

- [x] 1.1 Refactor `notificationMessages.ts`: change `getNavigationPath(eventType: string)` signature to `getNavigationPath(notification: Notification, userRoles: string[]): string`. Extract `referralId`, `shelterId`, `reservationId` from `notification.payload` (JSON string — must be parsed). Reuses existing `parseNotificationPayload` helper; reads both live-SSE (`data.x`) and persistent (`payload.x`) shapes.
- [x] 1.2 Implement role-aware routing: escalation.* types route COC_ADMIN/PLATFORM_ADMIN to `/admin#dvEscalations?referralId=X` and COORDINATOR to `/coordinator?referralId=X`. All other types use existing role-agnostic paths with query param appended. (Also extends to `referral.requested` and `referral.reassigned` for consistency.)
- [x] 1.3 Add navigation path + message mappings for `SHELTER_DEACTIVATED`, `HOLD_CANCELLED_SHELTER_DEACTIVATED`, `referral.reassigned`. Deep-link `SHELTER_DEACTIVATED` to `/coordinator?shelterId=X` (coordinator) or `/admin?shelterId=X` (admin). Deep-link `HOLD_CANCELLED_SHELTER_DEACTIVATED` to `/outreach/my-holds?reservationId=X`. Deep-link `referral.reassigned` to role-appropriate referral view. (Navigation paths done here; i18n message mappings are task group 2.)
- [x] 1.4 Graceful fallback: if expected payload field is missing (pre-change notifications), fall back to role-based default path without error. Local `getRoleBasedDefaultPath` helper returns `/admin` | `/coordinator` | `/outreach` | `/` based on the user's roles.
- [x] 1.5 Update `NotificationBell.tsx`: pass the full notification object and current user roles (from JWT claims) to `getNavigationPath`. Uses `useAuth()` → `user.roles` (JWT-decoded in AuthContext).

## 2. Frontend — i18n for new notification types

- [x] 2.1 Add EN strings: `notifications.shelterDeactivated` ("Shelter {shelterName} was deactivated. Reason: {localizedReason}"), `notifications.holdCancelledShelterDeactivated` ("Your bed hold at {shelterName} was cancelled — the shelter was deactivated."), `notifications.referralReassigned` ("A DV referral was reassigned to you.").
- [x] 2.2 Add ES equivalents with dignity-centered copy (Keisha's lens). Used existing "referencia" convention for referral and matter-of-fact tone (desactivado/cancelada).
- [x] 2.3 Update `getNotificationMessageId()` switch to handle the three new types.
- [x] 2.4 Update `getNotificationMessageValues()` to extract `shelterName`, `reason`, etc. from payload for the new types. Added `reason` + `localizedReason` values; now takes optional `intl: IntlShape` (production callers pass it; tests may omit).
- [x] 2.4a **K-1 fix — localize deactivation reason enum**: `getNotificationMessageValues` for `SHELTER_DEACTIVATED` returns `localizedReason = intl.formatMessage({ id: 'shelter.reason.' + payload.reason })` — resolves enum value `TEMPORARY_CLOSURE` to user-friendly "Temporary closure" using the existing i18n keys shipped in v0.38.0. Never render the raw enum value to the user. NotificationBell.tsx now threads `intl` (from `useIntl()`) through the call. 27/27 existing tests pass.
- [x] 2.4b **Simone copy review — action-oriented CTA**: existing `notifications.criticalBanner.cta` already uses imperative "Review ..." and is compliant. New Phase 1 keys are notification row *descriptions* (not CTAs) — 2.4b applies to the CTA key `notifications.criticalBanner.coordinatorCta` being added in Phase 2 task 5.3. Review-gate enforced there.

## 3. Frontend — Coordinator dashboard deep-link handling

- [ ] 3.1 In `CoordinatorDashboard.tsx`: use `useSearchParams` to read `referralId` and `shelterId` query params on mount.
- [ ] 3.1a **A-1 fix — idempotency guard**: declare `const processedRef = useRef<Set<string>>(new Set())`. In the effect that processes query params, check `if (processedRef.current.has(referralId)) return`. After processing, `processedRef.current.add(referralId)`. Prevents re-processing on re-render, back navigation, or other URL changes.
- [ ] 3.1b **S-1 fix — unsaved state guard**: before auto-collapsing a currently-expanded shelter card, check for unsaved bed count edits (`editAvailability` state differs from the server snapshot). If dirty, show confirmation dialog: "You have unsaved bed count changes. Save before switching to the referral?" with Save / Discard / Cancel options. If user chooses Cancel, do not process the deep-link and do not auto-expand.
- [ ] 3.2 If `referralId` is present: fetch the referral (existing endpoint), find its `shelterId`, auto-expand that shelter card, scroll the referral row into view using `scrollIntoView({ block: 'center' })`, and move keyboard focus to the **referral row heading** (NOT the Accept button — see 3.2a for safety rationale).
- [ ] 3.2a **S-2 fix — focus target is NOT the Accept button**: Keisha + Sandra war room — focusing Accept risks accidental Enter-key acceptance of a DV referral. Focus instead lands on the referral row container (heading), one Tab stop away from Accept. This preserves WCAG D4 intent (user is "near the action") while preventing safety-critical accidental activation. Update design D4 to reflect this.
- [ ] 3.2b **T-1 fix — aria-live announcement**: add `<div role="status" aria-live="polite" aria-atomic="true">` to the dashboard. On successful deep-link processing, update its text content to "Opened pending DV referral: {populationType}, household size {N}, urgency {urgency}." Screen readers announce this after page settle. No PII in announcement.
- [ ] 3.3 If `shelterId` is present (no `referralId`): auto-expand that shelter card and move focus to its heading.
- [ ] 3.4 **Stale-referral handling**: if `referralId` no longer maps to a pending referral, show non-blocking toast "This referral is no longer pending." **X-1 fix**: also call `markNotificationsActedByPayload('referralId', referralId)` with a special "stale" outcome — mark the notification as read-unacted (not acted, since user didn't complete the workflow). Also covers **M-1 (Marcus) authorization case**: same toast + behavior if API returns 403 on fetch — never leak "stolen by another coordinator" vs "not authorized."
- [ ] 3.5 Update `CoordinatorReferralBanner.tsx`: accept a `referralId` prop (passed from dashboard). When present, clicking opens the shelter containing that specific referral, not the first DV shelter. Preserve existing no-param behavior.

## 3z. Phase 1 → Phase 2 transition

- [ ] 3z.1 Ship Phase 1: open PR, address review, merge `feature/issue-106-phase1-deeplink-foundation` to main.
- [ ] 3z.2 Confirm Phase 1 ship-gate criteria all green (see implementation plan).
- [ ] 3z.3 `git checkout main && git pull origin main` to pick up Phase 1 changes.
- [ ] 3z.4 `git checkout -b feature/issue-106-phase2-admin-banner` from updated main.

## 4. Frontend — Admin escalation queue deep-link handling (Phase 2 starts here)

- [ ] 4.1 In `DvEscalationsTab.tsx` (or the queue component): read `referralId` from URL search params.
- [ ] 4.1a Apply idempotency guard pattern from 3.1a (same re-render concern applies).
- [ ] 4.2 If `referralId` is present: find the matching row in the loaded queue, open its detail modal automatically.
- [ ] 4.3 If `referralId` present but not in queue: show non-blocking toast "This escalation is no longer in the queue." Load queue normally. Also mark the notification read-unacted per X-1 pattern.
- [ ] 4.4 Update AdminPanel hash router to preserve query params alongside hash (`#dvEscalations?referralId=X`).

## 5. Frontend — CriticalNotificationBanner coordinator CTA

- [ ] 5.1 In `CriticalNotificationBanner.tsx`: when user role is COORDINATOR and unread CRITICAL notifications include at least one with `type.startsWith('escalation.')` AND `payload.referralId`, show CTA linking to `/coordinator?referralId=<first-critical-referral-id>`. **X-4 fix — "first" is deterministic**: order by `notification.createdAt ASC` (oldest first = most urgent, highest risk of timeout).
- [ ] 5.2 Preserve existing admin CTA behavior for COC_ADMIN/PLATFORM_ADMIN.
- [ ] 5.3 Add i18n key `notifications.criticalBanner.coordinatorCta` with EN + ES. Use action-oriented copy per 2.4b.
- [ ] 5.4 Ensure `color.textInverse` / `color.errorMid` contrast fix from v0.38.0 is preserved (no regression).

## 5z. Phase 2 → Phase 3 transition

- [ ] 5z.1 Ship Phase 2: open PR, address review, merge `feature/issue-106-phase2-admin-banner` to main.
- [ ] 5z.2 Confirm Phase 2 ship-gate criteria all green.
- [ ] 5z.3 `git checkout main && git pull origin main` to pick up Phase 2 changes.
- [ ] 5z.4 `git checkout -b feature/issue-106-phase3-my-holds-lifecycle` from updated main.

## 6. Frontend — My Past Holds view (Phase 3 starts here)

- [ ] 6.1 Create `MyPastHoldsPage.tsx` at `frontend/src/pages/MyPastHoldsPage.tsx`. Route: `/outreach/my-holds` in React Router.
- [ ] 6.2 Fetch user's reservations: HELD + CANCELLED + EXPIRED + CONFIRMED + CANCELLED_SHELTER_DEACTIVATED. **D-1 fix — default window extended to 14 days** (was 7) to cover casual weekend workers whose holds expire 8+ days prior.
- [ ] 6.3 Render grouped by status: Active (HELD) first, then Recent (terminal states). Each row shows shelter name, population type, status with visible text label, created timestamp (using DataAge component), primary action button.
- [ ] 6.4 Status-specific actions: HELD → "Confirm arrival" + "Cancel hold" (existing API). CANCELLED_SHELTER_DEACTIVATED → "Find another bed" link to `/outreach`. CONFIRMED → no action (display only). CANCELLED/EXPIRED → "Find another bed" link. **D-2 fix — add `tel:` link**: every row shows a small "Call shelter" link using the shelter's phone number (existing field on shelter record). Clickable on mobile to initiate call.
- [ ] 6.4a Deep-link highlighting: if URL has `?reservationId=X`, render that row with a visible left border accent (color.primaryText), scroll to it, move focus to its primary action.
- [ ] 6.4b Apply idempotency guard pattern from 3.1a for `reservationId` processing.
- [ ] 6.5 Empty state: "No recent bed holds. Search for beds to create one." with link to `/outreach`. **D-2 (Devon) fix**: separately handle first-ever load state: "You'll see your bed holds here once you start searching." (distinct from "no recent" vs "never created any").
- [ ] 6.6 "Show older" button loads reservations 14-60 days old (adjusted from 7-30 per D-1 change).
- [ ] 6.7 Nav: add "My Holds" link in outreach header (role-gated to OUTREACH_WORKER).
- [ ] 6.8 i18n: all strings in EN + ES.
- [ ] 6.9 data-testid: `my-holds-row-{reservationId}`, `my-holds-action-{reservationId}`, `my-holds-call-{reservationId}`, `my-holds-empty`, `my-holds-load-older`.
- [ ] 6.10 **D-3 fix — offline deep-link handling**: if the user navigates to `/outreach/my-holds?reservationId=X` while offline, display a toast "Can't load your holds — check your connection." and load cached data if available (from SW cache). Do NOT show an infinite spinner. Reuse existing offline queue patterns.

## 7. Frontend — Notification lifecycle (markActed)

- [ ] 7.1 Add `markNotificationsActedByPayload(payloadField: string, payloadValue: string, outcome?: 'acted' | 'stale')` helper in the notification service layer. 'acted' calls `PATCH /api/v1/notifications/{id}/acted`; 'stale' calls `PATCH /api/v1/notifications/{id}/read` (no markActed — user didn't complete).
- [ ] 7.1a **Measurement gate**: after implementing per-notification PATCH (7.1), add a backend test that creates 5 notifications for the same referralId (request + escalation.1h + escalation.2h + escalation.3_5h + escalation.4h). Accept the referral. Assert the markActed flow completes in ≤ 5 round trips and ≤ 500ms wall time. If either threshold exceeded, implement batch endpoint per task 8.2 before proceeding.
- [ ] 7.2 Wire into referral accept flow (CoordinatorDashboard + DvEscalationsTab): after a 200 from accept/reject, call `markNotificationsActedByPayload('referralId', referralId, 'acted')`.
- [ ] 7.3 Wire into reservation confirm/cancel flow (OutreachPage, MyPastHoldsPage): after 200 from confirm, call `markNotificationsActedByPayload('reservationId', reservationId, 'acted')`.
- [ ] 7.4 Update `NotificationBell.tsx` to render three visual states (unread/read-unacted/acted) per design D7. Add small ✓ icon for acted, "• Pending" text for read-unacted. **T-2 fix — aria-label per state**: each notification row's `aria-label` includes the state word: "Unread", "Pending action", or "Completed". Example: "DV referral requested at Safe Haven. Pending action."
- [ ] 7.4a **M-1 fix (Rev. Monroe) — tooltips on state indicators**: the "• Pending" text and ✓ icon each have a hover/focus tooltip explaining the state: "Pending — you've seen this but haven't responded" and "Completed — you've acted on this." Tooltip uses `title=` attribute (native, keyboard-accessible, screen reader-read).
- [ ] 7.5 Add "Hide acted" filter toggle in the bell header. Persist preference to localStorage key `fabt_notif_hide_acted`. **M-2 fix — default OFF** for first-time users (new volunteers see all states to learn the system). Document the filter in the coordinator quick-start card (Devon — task 14.x).
- [ ] 7.6 Ensure bell badge continues to count unread only (read-unacted and acted do not count).
- [ ] 7.7 **T-3 fix — focus visible on deep-link targets**: after programmatic focus on any deep-linked element, verify `:focus-visible` styles render. Use Playwright keyboard path (Tab to bell, Enter on notification) in test 11.9. If `:focus-visible` is suppressed by the browser on programmatic focus, add a class `.deep-link-focus` with matching styles.

## 7z. Phase 3 → Phase 4 transition

- [ ] 7z.1 Ship Phase 3: open PR, address review, merge `feature/issue-106-phase3-my-holds-lifecycle` to main.
- [ ] 7z.2 Confirm Phase 3 ship-gate criteria all green (including 7.1a measurement gate result — decide batch endpoint need for Phase 4).
- [ ] 7z.3 `git checkout main && git pull origin main` to pick up Phase 3 changes.
- [ ] 7z.4 `git checkout -b feature/issue-106-phase4-metrics-tests` from updated main.

## 8. Backend — Optional API additions (deferred unless needed) — Phase 4 starts here

- [ ] 8.1 **Evaluate (result from 0.2)**: if existing `GET /api/v1/reservations` doesn't support status filter + date range, add query params `status=HELD,CANCELLED,...` and `sinceDays=N`. Write backend integration test + OpenAPI annotation.
- [ ] 8.2 **Evaluate (result from 7.1a)**: if measurement gate fails, add batch `POST /api/v1/notifications/mark-acted-by-payload` endpoint. Elena's note: per-notification PATCH is preferred — avoids JSONB expression index. Only add batch if measurement gate fails.
- [ ] 8.3 If batch endpoint added: full integration test + OpenAPI annotation.

## 9. Backend — Tests

- [ ] 9.1 Integration test: markActed marks all notifications with matching payload.referralId (simulate a coordinator with referral.requested + escalation.1h notifications, then accept the referral).
- [ ] 9.2 Integration test: markActed on one user does NOT affect other users' notifications with the same referralId.
- [ ] 9.3 Integration test: failed action does NOT mark acted (accept referral, but API returns 409 — verify no notification is acted).
- [ ] 9.4 **X-1 coverage**: integration test — Coordinator A accepts referral X. Coordinator B's stale-referral fallback runs on deep-link. Verify B's notification is marked read (via `/read` endpoint) but NOT acted.

## 9a. Backend — Metrics (Priya's differentiator)

- [ ] 9a.1 **P-1 / X-3 fix**: add Micrometer counter `fabt.notification.deeplink.click.count` tagged by `type` (notification type), `role`, `outcome` (success/stale/offline).
- [ ] 9a.2 Add Micrometer histogram `fabt.notification.time_to_action.seconds` tagged by `type`. Measured from notification `createdAt` → successful accept/confirm timestamp. Fires in the markActed path.
- [ ] 9a.3 Add Micrometer counter `fabt.notification.stale_referral.count` tagged by `type` and `role`. Fires when the stale-referral toast is shown.
- [ ] 9a.4 Add Grafana panel to existing `DV Referrals` dashboard showing time-to-action histogram (P50/P95/P99) broken down by notification type. This is the metric for Priya's next grant application.
- [ ] 9a.5 Document the three new metric names (`fabt.notification.deeplink.click.count`, `fabt.notification.time_to_action.seconds`, `fabt.notification.stale_referral.count`) in FOR-DEVELOPERS.md. No observability spec delta — metrics are net-new counters/histograms, additive to the observability surface without modifying existing spec behavior.

## 10. Frontend — Tests (Vitest)

- [ ] 10.1 Unit test `getNavigationPath`: each notification type + role combination returns expected path with query params.
- [ ] 10.2 Unit test: missing payload field falls back to role-based default.
- [ ] 10.3 Unit test: `getNotificationMessageId` and `getNotificationMessageValues` handle the three new types.
- [ ] 10.4 **K-1 coverage**: unit test that `getNotificationMessageValues` for `SHELTER_DEACTIVATED` returns a localized reason string, not the raw enum value. Assert intl key lookup happens.
- [ ] 10.5 **A-1 coverage**: React Testing Library test that `useEffect` processing query param fires only once per `referralId` value, even with multiple re-renders.

## 11. Playwright — E2E tests

- [ ] 11.1 Test: dv-coordinator clicks referral.requested notification → lands on `/coordinator?referralId=X`, shelter auto-expands, referral is visible, focus on referral row heading (per S-2 fix). Explicit focus assertion: `await expect(page.locator(':focus')).toHaveAttribute('data-testid', 'screening-<referralId>')`.
- [ ] 11.2 Test: admin clicks escalation.1h notification → lands on `/admin#dvEscalations?referralId=X`, detail modal opens automatically.
- [ ] 11.3 Test: coordinator clicks SAME escalation.1h notification → lands on `/coordinator?referralId=X` (NOT admin queue).
- [ ] 11.4 Test: outreach worker clicks HOLD_CANCELLED_SHELTER_DEACTIVATED → lands on `/outreach/my-holds?reservationId=X`, row highlighted, focus moved. Explicit focus assertion: `await expect(page.locator(':focus')).toHaveAttribute('data-testid', 'my-holds-action-<reservationId>')`.
- [ ] 11.5 Test: coordinator sees CriticalNotificationBanner with CTA (was dead-end before). Assert text uses action-oriented copy per 2.4b.
- [ ] 11.6 Test: My Past Holds renders HELD + terminal holds, status labels visible, status-specific actions correct. Assert `tel:` link present on each row.
- [ ] 11.7 Test: markActed — accept a referral, verify the originating notification shows acted visual state (✓ icon).
- [ ] 11.8 Test: stale referral deep-link — navigate to `?referralId=fake-id`, verify toast appears and notification marked read (not acted).
- [ ] 11.9 Test: keyboard navigation — tab from bell into a notification, press Enter, verify focus lands on referral row heading (per S-2) and `:focus-visible` renders.
- [ ] 11.10 Test: "Hide acted" filter — toggle in bell, verify acted notifications hidden and preference persisted after reload.
- [ ] 11.11 **X-6 fix — Spanish locale coverage**: one end-to-end test covering the core coordinator flow (click notification → land on referral) in Spanish. Assert Spanish translations render for the 3 new notification types.
- [ ] 11.12 **X-2 fix — mobile viewport test**: run 11.1 on `{width: 412, height: 915}` (Galaxy S25 Ultra per memory). Verify 44px touch targets, dropdown fits screen, deep-link completes. Separate test: assert `my-holds-call-{id}` link is at least 44×44px.
- [ ] 11.13 **X-1 concurrency test**: open two browser contexts as dv-coordinator (Alice) and second dv-coordinator (Bob). Alice accepts a referral. Bob clicks his notification for the same referral → stale toast shown, notification marked read-but-not-acted.
- [ ] 11.14 **S-1 unsaved-state test**: coordinator expands Shelter A, edits bed count (no save), clicks a notification for a Shelter B referral. Verify confirmation dialog appears. Choose Cancel → Shelter A stays expanded with edits intact.
- [ ] 11.15 **T-1 aria-live test**: navigate via deep-link, verify the `role="status"` element's text content updates with the "Opened pending DV referral..." message.
- [ ] 11.16 **A-3 auth redirect test**: while on login page (JWT expired), simulate notification click that would deep-link to `/coordinator?referralId=X`. After login, verify redirect preserves the query param and the referral auto-opens.
- [ ] 11.17 **Back button behavior test (Q4)**: complete a deep-link navigation to `/coordinator?referralId=X`. Press browser Back. Verify URL returns to the prior route (e.g., the page where the bell was opened). Verify the bell dropdown is NOT re-opened (fresh page state).

## 12. Accessibility

- [ ] 12.1 axe-core scan on `/outreach/my-holds` — zero violations.
- [ ] 12.2 axe-core scan on deep-linked coordinator dashboard state (`?referralId=X` with shelter expanded) — zero violations.
- [ ] 12.3 axe-core scan on admin escalation detail modal opened via deep-link — zero violations.
- [ ] 12.4 axe-core scan in dark mode on all above states.
- [ ] 12.5 Screen reader verification (NVDA or Playwright virtual screen reader): deep-link navigation announces the target page and new focus via aria-live region.

## 13. Verification

- [ ] 13.1 Run full backend test suite (`mvn clean test`). Tee to `logs/issue-106-regression.log`.
- [ ] 13.2 Run Playwright tests through nginx (`BASE_URL=http://localhost:8081`). Tee to `logs/issue-106-playwright.log`.
- [ ] 13.3 `npm run build` — frontend builds clean.
- [ ] 13.4 Update DBML if any schema changes (likely none — pure frontend + optional backend query params).
- [ ] 13.5 Update OpenAPI docs if task 8.x adds new endpoints.
- [ ] 13.6 Full Playwright regression — no failures in other suites.
- [ ] 13.7 Manual smoke: log in as dv-coordinator, trigger a DV referral from dv-outreach, verify end-to-end flow from notification → accept → mark acted.
- [ ] 13.8 Verify Grafana panel renders time-to-action histogram (Priya's differentiator).

## 14. Documentation (Devon's lens)

> **Note:** Tasks 14.1-14.3 ship as commits to the **docs repo** (`C:\Development\findABed\`), not the code repo. Coordinate timing with the code release — docs update ideally lands the same day as the feature ships to production. Task 14.4 (FOR-DEVELOPERS.md) lives in the code repo under `finding-a-bed-tonight/docs/`.


- [ ] 14.1 **D-1 (Devon) — update coordinator quick-start card** in docs repo: add one-pager "How to respond to a DV referral notification" with screenshots of the three notification states, the CriticalNotificationBanner CTA, and the deep-linked view. Coordinate with Simone for voice/layout.
- [ ] 14.2 Add inline tooltip help in bell header: "?" icon or "Help" link that opens a small overlay explaining the three states.
- [ ] 14.3 Update `docs/FOR-COORDINATORS.md` with the new notification lifecycle and deep-linking behavior.
- [ ] 14.4 Update `docs/FOR-DEVELOPERS.md` with the deep-link URL pattern convention (`?referralId=X`, `?reservationId=X`, `?shelterId=X`) for future notification types.

## 15. Post-deploy

- [ ] 15.1 Update deployment status memory after ship.
- [ ] 15.2 Monitor Grafana time-to-action histogram for 1 week. Collect baseline data.
- [ ] 15.3 Close Issue #106 with release notes summarizing measured improvement.
- [ ] 15.4 Document the measurable outcome in sustainability-narrative.md (Priya): "After deep-linking shipped, median coordinator time-from-notification-to-referral-accept decreased from X to Y."
