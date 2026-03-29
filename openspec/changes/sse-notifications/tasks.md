## Tasks

### Setup

- [x] T-0: Create branch `feature/sse-notifications` in code repo (`finding-a-bed-tonight`)

### Backend — SSE Infrastructure

- [x] T-1: Create `NotificationService` — manages `ConcurrentHashMap<UUID, SseEmitter>`, register/unregister methods, `onCompletion`/`onTimeout`/`onError` callbacks for cleanup (Spring #33421/#33340)
- [x] T-2: Create `NotificationController` — `GET /api/v1/notifications/stream` returns `SseEmitter` with 5-minute timeout, `retry: 5000` directive. Token passed as query parameter (EventSource doesn't support Authorization header).
- [x] T-3: Create `SseTokenFilter` — extracts JWT from `?token=` query parameter for SSE endpoint only, sets SecurityContext. Applied only to `/api/v1/notifications/stream` path.
- [x] T-4: Add SecurityConfig rule: `.requestMatchers("/api/v1/notifications/stream").authenticated()` before catch-all
- [x] T-5: Create `@EventListener` method in `NotificationService` — receives `DomainEvent` directly (verified: SpringEventBus publishes DomainEvent, not wrapper), switches on `event.type()`
- [x] T-6: Implement event filtering: `dv-referral.responded` → only the creating outreach worker; `dv-referral.requested` → DV-authorized coordinators in tenant; `availability.updated` → all users in tenant
- [x] T-7: DV safety: verify referral response payloads sent via SSE contain status + phone (if accepted) + rejection reason (if rejected), never shelter name or address
- [x] T-8: Add `@Scheduled` keepalive — send SSE comment (`:keepalive`) to all emitters every 30 seconds to prevent proxy/LB idle timeout
- [x] T-9: Add `@Operation` annotation to SSE endpoint for MCP discoverability

### Backend — Metrics

- [x] T-10: Add `fabt.sse.connections.active` gauge (AtomicInteger in NotificationService, increment on register, decrement on cleanup)
- [x] T-11: Add `fabt.sse.events.sent.count` counter (tag: eventType) — increment on each successful SSE send

### Backend — Tests

- [x] T-12: Write `SseNotificationIntegrationTest` — connect to SSE endpoint with token query param, trigger referral acceptance, verify event received by correct user only
- [x] T-13: Write cross-tenant isolation test — verify Tenant B user does not receive Tenant A events
- [x] T-14: Write DV safety test — verify SSE event for referral acceptance does not contain shelter name or address

### Frontend — EventSource Connection

- [x] T-15: Create `useNotifications` hook — establishes `EventSource` to `/api/v1/notifications/stream?token=<jwt>`, parses SSE events, manages notification state (last 10 in-memory)
- [x] T-16: Handle reconnection — on `EventSource` `onerror`/reconnect, fetch current referral list and bed search results via REST to catch up
- [x] T-17: Connect hook in Layout.tsx — establish SSE on login, disconnect on logout

### Frontend — Notification Bell UI

- [x] T-18: Create `NotificationBell.tsx` — bell icon with count badge, dropdown of recent notifications, click-to-navigate
- [x] T-19: Add to Layout header between locale selector and Password button
- [x] T-20: WCAG accessibility: `aria-live="polite"` hidden region (pre-rendered empty on page load), `aria-hidden="true"` on badge, `aria-label` on button with count, `data-testid="notification-bell"`
- [x] T-21: Auto-refresh referral list when `dv-referral.responded` event arrives (OutreachSearch)
- [x] T-22: Auto-refresh search results when `availability.updated` event arrives (OutreachSearch)

### Frontend — i18n

- [x] T-23: Add i18n keys for notifications (en.json + es.json): bell label, "New referral accepted", "Referral rejected", "Bed availability updated", "No notifications"

### Grafana

- [x] T-24: Add "SSE Active Connections" gauge panel to operations dashboard

### Documentation

- [x] T-25: Update runbook — SSE connection monitoring, keepalive heartbeat, expected connection count, troubleshooting (proxy blocking, connection accumulation)
- [x] T-26: Update `demo/dvindex.html` caption — change "when Darius refreshes" to describe real-time notification
- [x] T-27: Update FOR-DEVELOPERS.md — project status section, API reference (new endpoint), SseTokenFilter security note

### Demo Screenshots

- [x] T-28: Update capture script for notification bell in header (visible in all screenshots)
- [x] T-29: Create `capture-notification-screenshots.spec.ts` + `notifications.spec.ts` (8 e2e tests, 3 dedicated screenshots). Recapture requires running app.

### Verification

- [x] T-30: Run full backend test suite (mvn test) — 272 tests, all green
- [x] T-31: Run Karate API tests — 26 tests, all green
- [x] T-32: Run full Playwright test suite — 138 passed, 2 skipped, 0 failures
- [x] T-33: Run Gatling performance tests — p99=206ms, 0 KO, SSE connections don't degrade search latency
### Persona Review — WCAG Disclosure Pattern (Teresa Nguyen)

- [x] T-36: Fix NotificationBell.tsx — replace `role="menu"` / `role="menuitem"` with WAI-ARIA disclosure pattern: `aria-expanded`, `aria-controls`, remove `aria-haspopup`. Panel uses `<ul role="list">` not `role="menu"`.
- [x] T-37: Add keyboard navigation — Escape closes panel and returns focus to bell button. On open, move focus to first notification item or panel heading.
- [x] T-38: Update Playwright notifications.spec.ts — test `aria-expanded` toggles, Escape-to-close, focus management, no `role="menu"` present.

### Persona Review — Connection Status Indicator (Darius Webb)

- [x] T-39: Create `ConnectionStatusBanner.tsx` — hidden when connected, "Reconnecting to live updates..." banner on disconnect, "Reconnected" toast (3s) on recovery. `role="status"` + `aria-live="polite"`.
- [x] T-40: Wire banner in Layout.tsx — display below header, above main content. Driven by `connected` state from `useNotifications`.
- [x] T-41: Add i18n keys for connection status (en.json + es.json): reconnecting message, reconnected toast, updates unavailable.
- [x] T-42: Playwright test for connection banner — verify banner not visible when connected, verify `role="status"` and `aria-live="polite"` attributes exist.

### Persona Review — Person-Centered Language (Keisha Thompson)

- [x] T-43: Update notification i18n keys — "A shelter responded to your referral" (not "Referral response received"), "New referral needs your review" (not "New referral request"), "Bed availability changed at {shelterName}" (not "Bed availability updated"). Include status (Accepted/Rejected) in referral notification text. Update en.json + es.json.
- [x] T-44: Update NotificationBell.tsx — pass shelterName and status into notification message rendering so they appear without tapping through.

### Persona Review — DV Safety Payload Assertion (Riley Cho)

- [x] T-45: Rewrite DV safety integration test — use `HttpClient.sendAsync()` + `BodyHandlers.ofLines()` to read actual SSE wire data. Assert event data lines do NOT contain `shelter_name` or `shelter_address`. Replace current no-error-on-send assertion.

### Persona Review — Gatling SSE + Search Concurrent Load (Sam Okafor)

- [x] T-46: Write `SseSearchConcurrentSimulation.java` — hold N SSE connections open (using Gatling SSE support or raw HTTP) while running the standard BedSearchSimulation workload. Assert bed search p99 stays under SLO threshold with SSE connections active.

### Final Verification

- [x] T-47: Re-run full backend test suite — 272 tests, all green
- [x] T-48: Re-run full Playwright test suite — 143 passed, 2 skipped, 0 failures
- [ ] T-49: CI green on all jobs
- [ ] T-50: Merge to main, tag
