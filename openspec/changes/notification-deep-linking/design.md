## Context

Three notification surfaces today (NotificationBell, CriticalNotificationBanner, CoordinatorReferralBanner) all route users to a page with no way to find the specific item that triggered the notification. The backend already stores `referralId`, `shelterId`, `reservationId` in the notification payload JSONB. The gap is entirely in the frontend routing layer.

Related shipped work: v0.35.0 (coc-admin-escalation) introduced the queue. v0.35.1 role-gated the CriticalNotificationBanner CTA, removing the dead-end for coordinators (visible text, no button) — that fix is now reverting cost because coordinators have no action path.

## Goals / Non-Goals

**Goals:**
- Every notification click lands the user on the specific item requiring action, with keyboard focus on the primary action button.
- Role-aware routing: the same notification type routes COC_ADMIN to the admin queue, COORDINATOR to the referral detail in their dashboard.
- Three notification types (`SHELTER_DEACTIVATED`, `HOLD_CANCELLED_SHELTER_DEACTIVATED`, `referral.reassigned`) get user-facing messages and routing.
- Outreach workers get a dedicated "My Past Holds" view that supports hold-cancellation deep-links.
- Notifications track `read` vs `acted` — users can see what they've actually completed.
- No backend API contract changes. All data already in payload.

**Non-Goals:**
- Rewriting the persistent notification store or bell UI infrastructure.
- Adding new notification types (just routing + messaging for existing ones).
- Changing SSE delivery.
- Mobile push notifications (tracked in #53, Capacitor native app).
- Redesigning the CriticalNotificationBanner visual treatment (dark mode contrast fix already shipped in v0.38.0).

## Decisions

### D1: Query params, not path params

**Decision:** Deep-link targets use query params on existing routes (`/coordinator?referralId=X`) rather than new path-param routes (`/coordinator/referrals/X`).

**Alternatives considered:**
- New path-param routes — would require a new React Router definition, a new dedicated page component, and would fragment the coordinator dashboard into two code paths (list view vs. detail view).
- Hash fragment (`/coordinator#referral-X`) — works but mixes semantics with the admin tab router that already uses `#dvEscalations`. Reserving hash for tab selection keeps the two concerns separate.

**Rationale:** Query param preserves the dashboard context (user sees their other shelters in peripheral vision) and is trivially testable. It also supports the user action of "I'm handling this referral but want to see my other shelters" without backing out of a detail view.

### D2: Role-aware routing lives in the frontend, not backend

**Decision:** `getNavigationPath(notification, currentUserRoles)` in the frontend determines destination based on role. Backend `payload` stays role-agnostic.

**Alternatives considered:**
- Backend computes `targetUrl` per-recipient at send time — requires knowing recipient role at send. Works, but duplicates role logic that already lives in the frontend, and we'd need to re-send if roles change.
- Role-less routing (same URL for all roles) — fails the user story: admin needs the escalation queue, coordinator needs the specific referral.

**Rationale:** Role is already available client-side via JWT claims. Routing decisions are UI concerns. Keep the backend notification contract stable.

### D3: markActed is called only on SUCCESSFUL terminal actions

**Decision:** `PATCH /api/v1/notifications/{id}/acted` is called when:
- A referral accept/reject succeeds (201/200)
- A bed hold confirm/cancel succeeds
- A shelter reactivation is acknowledged

NOT called on:
- Just viewing the deep-linked target (that's "read", not "acted")
- Failed actions
- Dismissal via the `×` button (that's an explicit "not going to act")

**Rationale:** The `acted` state must mean "I completed the operational response" — otherwise it conflates scrolling with completing work. Dismissal remains a distinct signal meaning "I've decided not to act on this."

### D4: Focus management target is the referral row heading, not the action button (REVISED)

**Original Decision:** Focus moves to the primary action button (Accept referral) for "one keystroke away from action" efficiency.

**War room revision (Sandra + Keisha):** Focus moves to the referral row heading, one Tab stop away from Accept.

**Why revised:** For DV referrals, auto-focusing the Accept button creates a safety risk. A coordinator reaching for her phone while receiving a notification could accidentally press Enter and approve a referral without reading it. The survivor gets directed to a shelter that isn't actually ready. Keisha's lens: "Being approved and then un-approved because the coordinator didn't mean to click is worse than being declined cleanly."

**Trade-off accepted:** Two keypresses (Tab + Enter) instead of one. The extra ~0.5 seconds is worth preventing accidental DV acceptance.

**Hold cancellation and shelter-deactivation deep-links** do NOT have this safety concern — they can focus the primary action button directly.

**Rule:**
- DV-referral deep-links → focus row heading (one Tab from Accept)
- All other deep-links → focus primary action button

### D8: Idempotency guard on query-param processing (NEW)

> **SUPERSEDED by D-12 — see below.** The `useRef<Set<string>>()` ad-hoc tracker described here was replaced by intent-equality in the `useDeepLink` reducer. The reducer ignores `INTENT` actions whose intent equals the current state's intent, so re-renders with the same URL are no-ops without a separate ref. Page-refresh re-triggering still works (refresh resets in-memory state, so the new intent is dispatched). The original D-8 text is preserved for historical context only.

**Decision (original, superseded):** Deep-link processing uses a `useRef<Set<string>>()` to track which referralIds/reservationIds have already been processed in the current session. Re-runs of the effect skip already-processed values.

**Why:** React Router `useSearchParams` triggers re-renders on every URL change. Without a guard, navigating back to a URL with `?referralId=X` would re-trigger the auto-expand-scroll-focus sequence, fighting the user's current state.

**Trade-off:** Page refresh resets the guard. Refreshing with `?referralId=X` in the URL re-triggers the deep-link — which is the expected behavior (bookmarkable deep-links).

### D9: Unsaved state confirmation before auto-expand (NEW)

**Decision:** Before auto-collapsing a currently-expanded shelter card during deep-link processing, check for dirty local state (unsaved bed count edits, in-progress forms). If dirty, show confirmation dialog with Save / Discard / Cancel.

**Why:** Sandra's scenario: she's updating bed counts for Shelter A when a notification arrives. Clicking it would collapse Shelter A and discard her edits silently. That's data loss.

**Cancel preserves the current view.** Save commits and proceeds with deep-link. Discard abandons edits and proceeds.

### D10: Stale and auth-failure deep-links share the same fallback (NEW)

**Decision:** When a deep-link target returns 404 (referral no longer exists) OR 403 (user not authorized), the fallback is identical: toast "This referral is no longer pending" + mark notification read-but-not-acted.

**Why:**
1. **Marcus Webb (security):** Different messages for 404 vs 403 would leak whether a referral exists and was stolen vs the user lacks access. Unified message = no information leak.
2. **Notification lifecycle correctness:** The user didn't complete the workflow, so the notification is NOT acted. But they DID see it, so it's read. Distinguishing these states lets the user's bell stay accurate.

### D12: Deep-link logic lives in a `useDeepLink` hook with an explicit state machine (NEW, post-Phase-1 war-room)

**Decision:** All deep-link orchestration (URL → resolve → optional confirm → expand → focus → done | stale) lives in a single custom hook `frontend/src/hooks/useDeepLink.ts` that owns a finite-state machine. CoordinatorDashboard, DvEscalationsTab (Phase 2), and MyPastHoldsPage (Phase 3) consume the hook by passing host-specific callbacks: `resolveTarget`, `needsUnsavedConfirm`, `expand`, `isTargetReady`. Side-effecting concerns (DOM focus, scroll, aria-live announcement, toast, dialog rendering) live in the host and react to `state.kind` transitions.

**State machine:**

| State | Entered by | Exits to |
| --- | --- | --- |
| `idle` | Reducer init, `RESET` action | `resolving` on URL with deep-link params |
| `resolving` | URL effect dispatches `INTENT` | `awaiting-confirm` (needs save), `expanding` (no confirm), `stale` (404/403 → `not-found`, network error → `error`) |
| `awaiting-confirm` | Reducer on `RESOLVED` when host returns `needsConfirm = true` | `expanding` on `confirm('continue')`, `idle` on `confirm('abort')` |
| `expanding` | `RESOLVED` (no confirm) or `CONFIRM_CONTINUE` | `awaiting-target` on `EXPAND_DONE`, `stale: error` if expand throws |
| `awaiting-target` | `EXPAND_DONE` | `done` when host's `isTargetReady(resolved)` returns true, `stale: timeout` after `targetTimeoutMs` (default 5000ms) |
| `done` | `TARGET_READY` | `resolving(new intent)` on URL change |
| `stale` | Any error / timeout | `resolving(new intent)` on URL change, auto-cleared by host's stale toast handler |

**Why a state machine:**
- Stuck states are impossible by construction — every non-terminal state has an outbound transition AND a timeout fallback.
- The transitions are the contract. Tests assert `reducer(state, action)` directly without rendering React.
- Host code becomes a small set of `useEffect`s keyed on `state.kind` — no more interleaving with arbitrary refs/effects.
- Phase 2 and Phase 3 reuse the hook with different host callbacks; the deep-link logic exists exactly once.

**Idempotency:** intent equality (deep-compared on `referralId | shelterId | reservationId`) replaces the prior `processedRef<Set<string>>` ad-hoc tracker. The reducer ignores `INTENT` actions whose intent equals the current state's intent, so re-renders with the same URL are no-ops.

**Cancellation:** the URL effect uses an `AbortController` for the `resolveTarget` fetch and a `cancelled` flag in async chains. URL changes mid-flight cancel the previous resolve and discard its result.

**Why this lives in a hook (not a Redux store / context):** the state is local to the dashboard view. There's no cross-component sharing requirement. A hook keeps the API surface small and the state colocated with the UI that consumes it.

**Why not extract toast/dialog/announcement into the hook too:** those are DOM/UI concerns. The hook stays presentation-agnostic so it's reusable across hosts that may render the same state in different ways (the admin queue might use a modal, the my-holds page might use inline highlighting).

**Supersedes:**
- D8 (idempotency guard via ref) — replaced by intent-equality in the reducer; the ref disappears.
- The setTimeout(200) post-fetch focus race — replaced by `awaiting-target` polling `isTargetReady` until ready or timeout.
- Multiple ad-hoc patches from the war-room rounds (3w.A-1, 3w.H-1 through H-5, 3w.N-1, 3w.N-2) — the underlying bugs they patched are eliminated by the state-machine structure.

### D11: Hold cancellation and shelter deactivation auto-focus primary action (NEW)

**Decision:** For `HOLD_CANCELLED_SHELTER_DEACTIVATED` deep-links to `/outreach/my-holds?reservationId=X`, focus lands on the primary action ("Find another bed") — NOT a row heading.

**Why:** Unlike DV referral accept, there is no safety risk in auto-activating "Find another bed" — it's a navigation link, not a state-changing action. The "one keystroke from action" efficiency applies here where it doesn't for DV referrals.

### D5: "My Past Holds" is a separate route, not a tab on the search page

**Decision:** New `/outreach/my-holds` route. Separate nav entry. Shows HELD + terminal holds in unified list grouped by status.

**Alternatives considered:**
- Tab on the search page — clutters the worker's primary action surface (search for beds). Separates poorly.
- Part of admin panel — wrong audience; outreach workers need this, not admins.

**Rationale:** Outreach workers need to review past holds for shift handoff and pattern recognition. A dedicated route is discoverable, bookmarkable, and provides the deep-link target for hold-cancellation notifications.

### D6: Backward compatibility — notifications from before this change still route correctly

**Decision:** Deep-link path construction is resilient — if `payload.referralId` is missing (pre-change notifications), fall back to the current role-based destination (`/coordinator`) without error.

**Rationale:** The notification table is not being migrated. Existing unread notifications remain in the bell. They must not break.

### D7: Notification lifecycle visual states

**Decision:** Three visual states in the bell:
- **Unread**: background `color.bgHighlight`, text `weight.semibold`, counter increments
- **Read but not acted**: background `color.bg`, text `weight.normal`, small "pending action" indicator
- **Acted**: background `color.bg`, text `weight.normal` + `color.textMuted`, small ✓ icon

**Rationale:** Three states reflect three user mental models. Acted notifications can be collapsed/hidden via a filter in a future enhancement without breaking this design.

## Risks / Trade-offs

- **[Risk] Users expect the bell to "reset" after clicking** — Some users may view the new `acted` state as confusing ("why is it still there?"). → Mitigation: include a "hide acted" filter toggle in the bell header. Bell badge counts unread only (unchanged).
- **[Risk] Deep-link query param collision with other query params** — The coordinator dashboard may add other query params later. → Mitigation: namespace all notification-routing params with `referralId`, `reservationId`, `shelterId` — explicit, typed, document in design.
- **[Risk] Stale notifications deep-link to data that no longer exists** — e.g., a referral was accepted by someone else. → Mitigation: target page handles "not found" gracefully (fallback to list view with a toast: "This referral is no longer pending").
- **[Trade-off] Query param vs. history API push** — Query param creates history entries. Users may hit Back and re-land on the deep-linked view. Acceptable — matches Gmail / GitHub behavior.
- **[Trade-off] Role-aware routing requires client-side role logic** — a minor duplication of role-to-destination knowledge. Not a significant concern; roles rarely change and the mapping is well-documented.

## Open Questions

- **Q1**: Should the My Past Holds view show ALL holds ever, or paginate by date range? → **Default**: last 14 days + all currently HELD (revised from 7 days per Darius's weekend-worker concern). Older via "Show older" button (14-60 days).
- **Q2**: When a coordinator accepts a referral via deep-link, does `markActed` apply to all notifications about that referral (e.g., the request + any escalations), or just the one clicked? → **Default**: all notifications with matching `payload.referralId` are marked acted in a single backend call.
- **Q3**: For admin deep-linking to the escalation queue detail modal — if the referral was already claimed by another admin, does the modal still open? → **Default**: yes, modal opens and shows current claim state. Admin can observe or override per existing claim/release flow.
- **Q4 (resolved)**: Back button behavior after deep-link? → Uses `navigate()` (creates history entry). Back returns to the previous page (typically the bell was dismissed, so prior route). Matches Gmail/GitHub pattern.
- **Q5 (resolved)**: URL cleanup after processing? → Keep query param for bookmarkability. Idempotency guard (D8) prevents re-trigger on re-render.
- **Q6 (resolved)**: Audit event for markActed? → No. The underlying operational action (accept/reject) already emits an audit event with shelter_id, actor, timestamp. markActed is UI hygiene, not a compliance event.
- **Q7 (resolved)**: Notification table purge policy? → Out of scope for this change. File follow-up issue for notification purge after N days acted.

## Rollout Plan

This is a substantive change (112 tasks). It ships in four phases, each as a separate PR. Phases are shippable independently — a rollback of a later phase does not invalidate earlier phases.

### Phase 1: Foundation (core coordinator deep-linking)
**Tasks:** 0, 0a, 1, 2, 3
**Scope:** Backend payload fixes (0a), refactor `getNavigationPath`, i18n for 3 missing types, coordinator dashboard auto-open with idempotency + unsaved-state guard + aria-live + stale fallback, role-aware routing.
**Ship gate:** Sandra's #106 pain point is addressed — clicking a DV referral notification lands on the specific referral with focus on the row heading.

### Phase 2: Admin + banner enhancements
**Tasks:** 4, 5
**Scope:** Admin escalation queue deep-link, CriticalNotificationBanner coordinator CTA, action-oriented copy per Simone.
**Ship gate:** Admin + coordinator both have working CTAs with deep-linked targets.

### Phase 3: My Past Holds + lifecycle
**Tasks:** 6, 7
**Scope:** New `/outreach/my-holds` route, three-state bell visuals, markActed wiring, tooltips, hide-acted filter, tel: link.
**Ship gate:** Outreach workers have a home for cancelled holds. Notifications distinguish read vs acted.

### Phase 4: Observability + tests + docs
**Tasks:** 8, 9, 9a, 10-15
**Scope:** Optional backend endpoints (evaluate first), Vitest + Playwright tests, Micrometer metrics, Grafana panel, accessibility audits, documentation.
**Ship gate:** Priya's differentiator measurement is live. Pilot data collection can begin.

**Phase independence rationale:** Phase 1 is shippable on its own and delivers the core user story. Phases 2-4 are enhancements. If we have to pause (e.g., for a higher-priority issue), Phase 1 is a complete unit.

## Success Targets

- **Primary metric** (Priya's lens): after 2 weeks of pilot data, median time-from-notification-to-accept < 30 seconds. Baseline per coordinator self-report: 2-5 minutes.
- **Secondary metric**: deep-link click-through rate > 70% (users who receive a deep-linkable notification click it within 10 minutes).
- **Accessibility metric**: zero axe-core violations on all 5 deep-link target states (coordinator dashboard, admin queue, My Past Holds — each in light + dark mode).
- **Safety metric**: zero reports of accidental DV referral acceptance via the deep-link focus path (monitored via audit events + user feedback for 30 days post-ship).

If the primary metric median is > 60 seconds after 2 weeks, investigate UX — the deep-link may not be hitting the right target.

## Testing Coverage

This change has high test coverage requirements given the safety-critical nature of DV referral handling.

**Positive flows:**
- Coordinator, admin, outreach worker each clicking a notification and landing on the right target
- markActed successfully marks all related notifications after successful action
- Role-aware routing: same notification routes admin vs coordinator correctly
- CriticalNotificationBanner CTA for coordinator navigates to the first referral
- My Past Holds renders HELD + terminal states with correct action buttons

**Negative flows:**
- Stale referral (404): toast shown, notification marked read-unacted
- Unauthorized (403): same toast, no information leak
- Failed action: no markActed side effect
- Offline: toast shown, no infinite spinner
- Dismiss is not markActed

**Safety flows (DV-specific):**
- Focus lands on row heading, NOT Accept button (accidental Enter prevention)
- Concurrent coordinators: A accepts, B's stale fallback fires cleanly
- Unsaved state: confirmation dialog protects user edits

**Accessibility flows:**
- aria-live announcement on deep-link completion
- aria-label includes lifecycle state on every notification row
- Tooltips on state indicators (hover + focus)
- `:focus-visible` renders after programmatic focus
- Screen reader verification (NVDA or virtual)
- axe-core zero violations on all deep-link target states (light + dark mode)

**i18n flows:**
- Spanish locale end-to-end test for core coordinator flow
- Localized deactivation reason (never raw enum)

**Mobile flows:**
- Galaxy S25 Ultra viewport (412×915) — touch targets, scroll, focus
- Tel-link on My Past Holds rows

**Observability:**
- Deep-link click counter increments with correct tags
- Time-to-action histogram records durations
- Stale-referral counter increments on fallback
- Grafana panel verified in manual smoke

**Regression safety:**
- Full Playwright suite passes (357+ tests)
- Full backend regression passes (619+ tests)
- Existing notification bell unchanged behavior for non-deep-linkable types
