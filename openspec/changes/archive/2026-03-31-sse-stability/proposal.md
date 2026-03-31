## Why

The SSE notification stream causes visible UI disruption on the live demo. Three independent failures compound into a refresh storm:

1. **Server:** `SseEmitter(5min)` times out, fires `AsyncRequestTimeoutException`, drops the connection
2. **Proxy:** nginx buffering killed SSE streams (hotfixed in v0.22.1 but only on the demo, not in dev)
3. **Client:** Every reconnect triggers `catchUp()` which dispatches full refetch of beds + referrals

The v0.22.1 hotfix addressed the nginx buffering and added a 30-second debounce to catchUp, but the 5-minute server-side timeout still causes periodic reconnects. Sandra sees the screen blink every 5 minutes. Darius on spotty signal sees it more often as the connection drops and reconnects repeatedly.

The current `EventSource` uses query-param token auth (`?token=jwt`) which leaks credentials in server logs, browser history, and proxy logs. This is a security concern Marcus Webb would flag.

The SSE Playwright test ("queued availability update replays on reconnect") asserts only that the page doesn't crash — it makes zero assertions about SSE connection stability, heartbeat delivery, or reconnection behavior.

## What Changes

**Server (Spring Boot):**
- Change `SseEmitter` timeout from 5 minutes to `-1L` (no timeout). Dead connections detected by heartbeat failure instead.
- Tighten heartbeat interval from 30 seconds to 20 seconds for faster dead-client detection
- Send `retry: 5000` and initial event on connection establishment
- Accept `Last-Event-ID` header and replay missed events from a bounded in-memory buffer
- Add 4 Micrometer custom metrics: `sse.connections.active` (gauge), `sse.reconnections.total` (counter), `sse.event.delivery.duration` (timer), `sse.send.failures.total` (counter)
- Add Grafana dashboard panel for SSE health

**Client (React):**
- Switch from native `EventSource` to `@microsoft/fetch-event-source` (~2KB). Gains: Authorization header auth (eliminates query-param token), controlled retry with exponential backoff + jitter, built-in Page Visibility handling
- Remove `catchUp()` full-refetch pattern. Instead: rely on `Last-Event-ID` server-side replay for missed events. Only refetch if server sends a `refresh` event type (gap too large).
- Add exponential backoff with jitter on reconnect (initial 1s, max 30s, 30% jitter)
- Close SSE when tab backgrounded, reconnect when foregrounded (Page Visibility API — handled by fetch-event-source)

**Testing (4 layers):**
- Backend integration: timeout behavior, heartbeat delivery, dead connection cleanup, Last-Event-ID replay, metrics
- Playwright E2E: SSE stays connected 30 seconds without reconnect, heartbeats received, no refetch storm, Page Visibility behavior
- Gatling performance: 200 concurrent SSE connections through nginx, hold 60 seconds, 0 unexpected disconnects
- Grafana operational: `sse.connections.active` gauge visible on FABT Operations dashboard

## Capabilities

### New Capabilities
- `sse-observability`: Micrometer metrics for SSE connection health, Grafana dashboard panel

### Modified Capabilities
- `pwa-shell`: Switch to `@microsoft/fetch-event-source`, Page Visibility integration, remove catchUp refetch
- `sse-notifications`: SseEmitter timeout -1L, 20s heartbeat, Last-Event-ID replay buffer, `retry:` field

## Impact

- **Backend:** `NotificationService.java` — timeout, heartbeat interval, event buffer, metrics
- **Backend:** `NotificationController.java` — accept `Last-Event-ID`, send `retry:` on connect
- **Backend:** `SseTokenFilter.java` — deprecate (keep for backward compat, log warning when used)
- **Frontend:** `useNotifications.ts` — replace `EventSource` with `fetchEventSource`, remove catchUp, add backoff
- **Frontend:** `package.json` — add `@microsoft/fetch-event-source` dependency
- **Grafana:** `grafana/dashboards/fabt-operations.json` — add SSE health panel
- **Tests:** New backend integration tests (5+), rewritten Playwright SSE tests (4+), new Gatling SSE simulation
- **No database changes**
- **No API contract changes** (SSE wire format unchanged)
- **Prerequisite:** `nginx-dev-parity` must be complete first (Gatling SSE tests must run through nginx)
