## Tasks

### Setup

- [ ] T-0: Create branch `feature/sse-notifications` in code repo (`finding-a-bed-tonight`)

### Backend — SSE Infrastructure

- [ ] T-1: Create `NotificationService` — manages `ConcurrentHashMap<UUID, SseEmitter>`, register/unregister methods, `onCompletion`/`onTimeout`/`onError` callbacks for cleanup (Spring #33421/#33340)
- [ ] T-2: Create `NotificationController` — `GET /api/v1/notifications/stream` returns `SseEmitter` with 5-minute timeout, `retry: 5000` directive. Token passed as query parameter (EventSource doesn't support Authorization header).
- [ ] T-3: Create `SseTokenFilter` — extracts JWT from `?token=` query parameter for SSE endpoint only, sets SecurityContext. Applied only to `/api/v1/notifications/stream` path.
- [ ] T-4: Add SecurityConfig rule: `.requestMatchers("/api/v1/notifications/stream").authenticated()` before catch-all
- [ ] T-5: Create `@EventListener` method in `NotificationService` — receives `DomainEvent` directly (verified: SpringEventBus publishes DomainEvent, not wrapper), switches on `event.type()`
- [ ] T-6: Implement event filtering: `dv-referral.responded` → only the creating outreach worker; `dv-referral.requested` → DV-authorized coordinators in tenant; `availability.updated` → all users in tenant
- [ ] T-7: DV safety: verify referral response payloads sent via SSE contain status + phone (if accepted) + rejection reason (if rejected), never shelter name or address
- [ ] T-8: Add `@Scheduled` keepalive — send SSE comment (`:keepalive`) to all emitters every 30 seconds to prevent proxy/LB idle timeout
- [ ] T-9: Add `@Operation` annotation to SSE endpoint for MCP discoverability

### Backend — Metrics

- [ ] T-10: Add `fabt.sse.connections.active` gauge (AtomicInteger in NotificationService, increment on register, decrement on cleanup)
- [ ] T-11: Add `fabt.sse.events.sent.count` counter (tag: eventType) — increment on each successful SSE send

### Backend — Tests

- [ ] T-12: Write `SseNotificationIntegrationTest` — connect to SSE endpoint with token query param, trigger referral acceptance, verify event received by correct user only
- [ ] T-13: Write cross-tenant isolation test — verify Tenant B user does not receive Tenant A events
- [ ] T-14: Write DV safety test — verify SSE event for referral acceptance does not contain shelter name or address

### Frontend — EventSource Connection

- [ ] T-15: Create `useNotifications` hook — establishes `EventSource` to `/api/v1/notifications/stream?token=<jwt>`, parses SSE events, manages notification state (last 10 in-memory)
- [ ] T-16: Handle reconnection — on `EventSource` `onerror`/reconnect, fetch current referral list and bed search results via REST to catch up
- [ ] T-17: Connect hook in Layout.tsx — establish SSE on login, disconnect on logout

### Frontend — Notification Bell UI

- [ ] T-18: Create `NotificationBell.tsx` — bell icon with count badge, dropdown of recent notifications, click-to-navigate
- [ ] T-19: Add to Layout header between locale selector and Password button
- [ ] T-20: WCAG accessibility: `aria-live="polite"` hidden region (pre-rendered empty on page load), `aria-hidden="true"` on badge, `aria-label` on button with count, `data-testid="notification-bell"`
- [ ] T-21: Auto-refresh referral list when `dv-referral.responded` event arrives (OutreachSearch)
- [ ] T-22: Auto-refresh search results when `availability.updated` event arrives (OutreachSearch)

### Frontend — i18n

- [ ] T-23: Add i18n keys for notifications (en.json + es.json): bell label, "New referral accepted", "Referral rejected", "Bed availability updated", "No notifications"

### Grafana

- [ ] T-24: Add "SSE Active Connections" gauge panel to operations dashboard

### Documentation

- [ ] T-25: Update runbook — SSE connection monitoring, keepalive heartbeat, expected connection count, troubleshooting (proxy blocking, connection accumulation)
- [ ] T-26: Update `demo/dvindex.html` caption — change "when Darius refreshes" to describe real-time notification
- [ ] T-27: Update FOR-DEVELOPERS.md — project status section, API reference (new endpoint), SseTokenFilter security note

### Demo Screenshots

- [ ] T-28: Update capture script for notification bell in header (visible in all screenshots)
- [ ] T-29: Recapture all screenshots showing notification bell

### Verification

- [ ] T-30: Run full backend test suite (mvn test) — all green
- [ ] T-31: Run Karate API tests — all green
- [ ] T-32: Run full Playwright test suite — all green
- [ ] T-33: Run Gatling performance tests — verify SSE connections don't degrade search latency
- [ ] T-34: CI green on all jobs
- [ ] T-35: Merge to main, tag
