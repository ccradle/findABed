## Why

Empirical investigation of the notification system (Playwright + code review) found:

1. **Clicking a notification doesn't surface the specific item requiring action.** A dv-coordinator with 22 notifications clicks one about a pending DV referral — the URL stays on `/coordinator`, the referral is not auto-expanded, and the user must manually find it among their 22 assigned shelters.
2. **CriticalNotificationBanner is a dead-end for coordinators.** Shows "18 urgent notifications require action" but no CTA button (CTA was role-gated to COC_ADMIN/PLATFORM_ADMIN in v0.35.1 without a replacement for coordinators).
3. **CoordinatorReferralBanner always opens the FIRST DV shelter**, not the shelter with the pending referral the notification referenced.
4. **Three notification types have no frontend mapping at all**: `SHELTER_DEACTIVATED`, `HOLD_CANCELLED_SHELTER_DEACTIVATED`, `referral.reassigned`. They fall through to `'notifications.unknown'` — users see "Unknown notification" for important events.
5. **Notifications carry `referralId`, `shelterId` in their payloads** — the backend data is already there. The frontend `getNavigationPath(eventType)` signature drops it on the floor.
6. **No notification lifecycle beyond read/unread.** Backend has `markActed()`; frontend doesn't call it. No distinction between "I saw this" and "I acted on this."

Issue #106.

## What Changes

- **Deep-linking**: `getNavigationPath(notification)` takes the full notification object and returns a URL with query params derived from the payload (e.g., `/coordinator?referralId=abc-123`).
- **Role-aware routing**: escalation notifications route COC_ADMIN/PLATFORM_ADMIN to `/admin#dvEscalations?referralId=X`; COORDINATOR to `/coordinator?referralId=X`.
- **Coordinator dashboard auto-open**: `/coordinator?referralId=X` auto-expands the referral's shelter card, scrolls to the specific referral, and moves keyboard focus to the Accept button (WCAG 2.4.3 + 2.4.7).
- **Admin queue auto-select**: `/admin#dvEscalations?referralId=X` opens that row's detail modal automatically.
- **CriticalNotificationBanner CTA for coordinators**: coordinators see "View pending referrals →" which navigates to `/coordinator?referralId=<first-critical-referral>`.
- **Missing notification type mappings**: add frontend mappings for `SHELTER_DEACTIVATED`, `HOLD_CANCELLED_SHELTER_DEACTIVATED`, `referral.reassigned` — each with appropriate message text, navigation path, and (where applicable) deep-link target.
- **"My Past Holds" view**: new `/outreach/my-holds` route showing the outreach worker's HELD + recent terminal holds (CANCELLED, EXPIRED, CONFIRMED, CANCELLED_SHELTER_DEACTIVATED). Hold-cancellation notifications deep-link to this view with the specific hold highlighted.
- **Notification lifecycle — `markActed` wiring**: when a user successfully accepts/rejects a referral (or similar terminal action), the originating notification is marked acted. Bell shows three visual states: unread / read-but-unacted / acted.
- **Focus management**: after deep-link navigation, keyboard focus moves to the primary action button on the target (not just scroll).
- **SSE real-time updates**: when a user acts on a referral in one tab, the bell badge updates across tabs via existing SSE.

## Capabilities

### New Capabilities

- `notification-deep-linking`: payload-driven URL construction, role-aware routing, target auto-open/scroll/focus, markActed lifecycle wiring.
- `my-past-holds`: outreach worker dedicated view of HELD + recent terminal reservations with deep-link anchoring by `reservationId`.

### Modified Capabilities

- `persistent-notification-store`: bell UI distinguishes unread / read-unacted / acted; markActed called after successful action.
- `notification-rest-api`: no API contract change — existing `PATCH /api/v1/notifications/{id}/acted` endpoint wired from frontend.
- `coordinator-referral-banner`: accept optional `referralId` query param to open the shelter containing that referral (not always the first).
- `coc-admin-escalation`: DvEscalationsTab opens detail modal for a specific referralId when URL contains `?referralId=X`.

## Architectural pivot (post-Phase-1 war-room)

Four review rounds against the inline Phase 1 implementation kept turning up new HIGH/MEDIUM stuck-state bugs. Root cause: the deep-link logic was an ad-hoc collection of state, refs, and effects without a coherent model — each new patch closed one stuck state and exposed another. Decision (2026-04-14): extract a `useDeepLink` hook with an explicit state machine (`idle → resolving → awaiting-confirm → expanding → awaiting-target → done | stale`). The state machine eliminates the entire class of stuck-state bugs by construction — every state has a defined exit and a timeout fallback to `stale`. Phase 2 (admin queue) and Phase 3 (my-past-holds) reuse the same hook by plugging in different `resolveTarget` / `expand` / `isTargetReady` callbacks, so the deep-link logic exists in one place and is tested once.

## Impact

- **Frontend**: NotificationBell, CriticalNotificationBanner, CoordinatorReferralBanner, CoordinatorDashboard, AdminPanel (hash router + query params), DvEscalationsTab, notificationMessages.ts, new MyPastHoldsPage. **NEW** `frontend/src/hooks/useDeepLink.ts` containing the state machine and pure reducer; CoordinatorDashboard becomes the first consumer.
- **Backend**: one new read-only endpoint added during the war-room round 1 review — `GET /api/v1/dv-referrals/{id}` returning `ReferralTokenResponse` (zero-PII, RLS-scoped, role-checked COORDINATOR/COC_ADMIN/PLATFORM_ADMIN). The deep-link processor uses this lookup to resolve a notification's `referralId` to its containing shelter so the dashboard can auto-expand the right card. Without this endpoint every notification click would 404. `GET /api/v1/reservations` may also need a query param or new endpoint for Phase 3 historical holds (covered in tasks 0.2 / 8.1).
- **Routing**: new route `/outreach/my-holds`; existing routes accept query params (`?referralId=X`, `?reservationId=X`).
- **Database**: no migration needed. All required fields already in payload JSONB.
- **Testing**: 12-15 new Playwright tests covering each notification type's deep-link path, 5-6 backend integration tests for `markActed` lifecycle, axe-core scans on My Past Holds + deep-linked views.
- **i18n**: new keys for the 3 missing notification types, the coordinator CTA, the My Past Holds page.
- **Accessibility**: focus management on every deep-link target (WCAG 2.4.3 Focus Order, 2.4.7 Focus Visible).
