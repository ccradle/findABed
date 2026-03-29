## Context

The platform has an `EventBus` abstraction (`SpringEventBus` for in-process, `KafkaEventBus` for distributed) that already publishes domain events: `dv-referral.requested`, `dv-referral.responded`, `availability.updated`. These events are consumed by webhooks and metrics but not pushed to connected UI clients. Spring Boot 4.0 with virtual threads makes SSE connections cheap — no thread-per-connection cost.

Research confirmed: SseEmitter + virtual threads is production-ready on Spring Boot 4.0. The pinning fix landed in Spring Framework 6.1 (issue #30996). Gotchas: register `onCompletion`/`onTimeout`/`onError` callbacks to avoid deadlock (#33421) and memory leaks (#33340).

## Goals / Non-Goals

**Goals:**
- Real-time push notifications for DV referral status changes (outreach workers) and new referral arrivals (DV coordinators)
- Real-time push when bed availability changes (outreach workers on search page)
- WCAG-compliant notification badge with `aria-live="polite"` announcements
- Multi-tenant isolation: events only pushed to users in the same tenant
- DV safety: no shelter address or name in notification payloads
- Graceful reconnection with REST catch-up for missed events

**Non-Goals:**
- Persisting notifications to a database (events are transient — current state is always available via REST)
- Push notifications via Service Worker / Web Push API (future enhancement)
- Bi-directional communication (WebSocket not needed — server→client only)
- Notification preferences / mute (future enhancement)
- Email or SMS notifications

## Decisions

### D1: SseEmitter per authenticated user

Each authenticated user gets one `SseEmitter` when they connect to `GET /api/v1/notifications/stream`. The `NotificationService` maintains a `ConcurrentHashMap<UUID, SseEmitter>` keyed by userId. On domain event, filter by tenantId + user role and send to relevant emitters.

- `SseEmitter` timeout: 5 minutes. Client `EventSource` auto-reconnects with `retry: 5000` (5s).
- Register `onCompletion`, `onTimeout`, `onError` callbacks to remove emitter from map (Spring #33421 deadlock prevention).
- Virtual threads handle connections — no thread pool sizing concern.

**Alternative considered:** One emitter per role per tenant (fewer connections). Rejected because user-level filtering is needed for DV referral notifications (only the requesting worker should see the response).

### D2: Event filtering by tenant and role

| Domain Event | Who receives | Payload to client |
|---|---|---|
| `dv-referral.requested` | DV coordinators (dvAccess=true, COORDINATOR role) in same tenant | referralId, householdSize, urgency, populationType (no client PII) |
| `dv-referral.responded` | The outreach worker who created the referral | referralId, status (ACCEPTED/REJECTED), shelterPhone (if accepted), rejectionReason (if rejected). Never shelter name or address. |
| `availability.updated` | All authenticated users in same tenant | shelterId, shelterName, populationType, bedsAvailable, bedsAvailablePrevious |

The JWT claims (userId, tenantId, roles, dvAccess) are extracted at SSE connection time and stored alongside the emitter for filtering.

### D3: Hybrid reconnection — SSE + REST catch-up

`EventSource` auto-reconnects and sends `Last-Event-ID`. Research confirms Last-Event-ID is best-effort only. Our approach:

1. Each SSE event includes an `id:` field (monotonic counter per emitter session).
2. Server does NOT replay missed events on reconnect (no durable buffer — events are transient).
3. Client sends a REST fetch of current state after reconnection (referral list, bed search results) to close any gap.

This is simpler than maintaining a server-side event buffer and sufficient for our use case — the REST endpoints already return current state.

### D4: Notification bell UI

Header component between the locale selector and the Password button:

```
[Finding A Bed Tonight]  [Dev Outreach Worker]  [EN ▾]  [🔔 3]  [Password]  [Sign Out]
```

- Bell icon with count badge (red circle, white number).
- Click opens a dropdown showing recent notifications (last 10, in-memory on client).
- Each notification is dismissible. Clicking navigates to the relevant view (referral list, search results).
- Count badge: `aria-hidden="true"`. Button: `aria-label="Notifications, 3 unread"`. Hidden `aria-live="polite"` region announces count changes.
- Pre-render the live region empty on page load (screen readers miss dynamically created regions).

### D5: DV safety in notifications

Referral response notifications to outreach workers contain:
- Referral ID
- Status (ACCEPTED / REJECTED)
- Shelter phone number (if ACCEPTED) — same data visible in the referral list
- Rejection reason (if REJECTED)

Never: shelter name, shelter address, coordinator name. The notification is a signal to check the referral list, not a replacement for it.

### D6: SecurityConfig + EventSource token handling

**Problem:** The browser `EventSource` API does not support custom headers. `Authorization: Bearer` cannot be set. This is a known limitation of the SSE spec.

**Solution:** Token-as-query-parameter for SSE only. The client connects to `/api/v1/notifications/stream?token=<jwt>`. A `SseTokenFilter` extracts the JWT from the `token` query parameter and sets the SecurityContext — applied only to the SSE endpoint path.

**Security trade-off:** Token in URL is logged by proxies and browser history. Mitigations:
1. Access tokens are short-lived (15 min in production, 60 min in dev)
2. The SSE endpoint is read-only (no mutations possible via this connection)
3. The `SseTokenFilter` only applies to the `/api/v1/notifications/stream` path
4. HTTPS encrypts the URL in transit (proxy logs depend on TLS termination point)

This is the standard approach used by GitHub, Slack, and other SSE implementations. The alternative (cookie-based auth) would require changes to the entire auth architecture.

Add to SecurityConfig before the catch-all:
```java
.requestMatchers("/api/v1/notifications/stream").authenticated()
```

### D7: EventListener receives DomainEvent directly

`SpringEventBus.publish()` calls `publisher.publishEvent(event)` with the `DomainEvent` record directly (verified in code). The `@EventListener` methods in `NotificationService` should use `DomainEvent` as the parameter type and filter by `event.type()`:

```java
@EventListener
public void onDomainEvent(DomainEvent event) {
    switch (event.type()) {
        case "dv-referral.responded" -> notifyReferralResponse(event);
        case "dv-referral.requested" -> notifyReferralRequest(event);
        case "availability.updated" -> notifyAvailabilityUpdate(event);
    }
}
```

### D8: SSE keepalive heartbeat

Some proxies and load balancers close idle connections after 60-90 seconds. A `@Scheduled` keepalive sends an SSE comment (`:keepalive\n\n`) to all connected emitters every 30 seconds. SSE comments are ignored by `EventSource` — they keep the connection alive without triggering client-side event handlers.

### D9: Metrics

- `fabt.sse.connections.active` (gauge) — current number of connected SSE clients
- `fabt.sse.events.sent.count` (counter, tag: eventType) — events pushed to clients
- Grafana panel: "SSE Active Connections" gauge added to operations dashboard

## Risks / Trade-offs

- **Risk:** SseEmitter deadlock on abrupt client disconnect (Spring #33421). → **Mitigation:** Register `onCompletion`/`onTimeout`/`onError` callbacks, remove emitter from map immediately.
- **Risk:** Memory leak from accumulated emitters (Spring #33340). → **Mitigation:** 5-minute timeout, cleanup callbacks, periodic sweep of stale emitters.
- **Risk:** SSE blocked by corporate proxy/firewall. → **Mitigation:** `EventSource` auto-reconnects. Falls back to manual refresh (current behavior). No functionality lost.
- **Risk:** High connection count in large deployments. → **Mitigation:** Virtual threads handle thousands of connections. Gauge metric for monitoring. Future: consider shared SSE via Redis pub/sub for multi-instance deployments.
