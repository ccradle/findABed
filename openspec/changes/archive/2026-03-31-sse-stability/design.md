## Context

The FABT notification system uses Spring Boot's `SseEmitter` to push real-time events (availability updates, DV referral responses) to the React PWA. The current implementation has a `ConcurrentHashMap<UUID, EmitterEntry>` registry, 30-second heartbeat pings, and 5-minute emitter timeout. The frontend uses native `EventSource` with query-param token auth and a `catchUp()` function that refetches all data on every reconnect.

Three production incidents led to this change:
- v0.22.1: nginx buffering killed SSE streams → constant page refresh
- Post-v0.22.1: 5-minute SseEmitter timeout causes `AsyncRequestTimeoutException` → periodic reconnects
- Every reconnect triggers full data refetch → visible UI disruption

## Goals / Non-Goals

**Goals:**
- SSE connection stays alive indefinitely (no artificial timeout disconnects)
- Dead connections detected and cleaned up within 20 seconds via heartbeat failure
- Reconnection is invisible to the user (no UI disruption, no data refetch)
- Auth via Authorization header (eliminate query-param token security concern)
- Micrometer metrics provide operational visibility into SSE health
- Testable at all 4 levels: unit, E2E, performance, operational
- Works through nginx proxy (validated by nginx-dev-parity tests)
- Works on mobile (Page Visibility closes connection when backgrounded)

**Non-Goals:**
- WebFlux migration (SseEmitter on virtual threads is correct for our scale)
- Multi-node SSE with Redis Pub/Sub (single-node is sufficient for pilot)
- Push notifications when app is closed (requires separate infrastructure)
- Replacing SSE with WebSocket (SSE is correct for unidirectional notifications)

## Design

### Server: SseEmitter lifecycle

**Timeout:** `new SseEmitter(-1L)` — no server-side timeout. The emitter lives until:
- Client disconnects (detected by heartbeat send failure)
- Server shuts down gracefully (`@PreDestroy` calls `complete()` on all emitters)
- An explicit `completeWithError()` on any send failure

**Heartbeat:** Every 20 seconds, send a named event (`event: heartbeat`) with incrementing `id:`. Named events (not comments) so they advance the client's `Last-Event-ID` — this ensures accurate replay windows even during quiet periods. This serves triple purpose:
- Keeps nginx idle timer alive (`proxy_read_timeout 120s` gives 6 missed heartbeats before nginx kills it)
- Detects dead clients — `IOException` on send triggers immediate cleanup
- Advances `Last-Event-ID` so reconnect replay is precise (not "everything since last real event")

Each heartbeat send is wrapped in a try-catch with a 5-second timeout. If any individual send is slow or stuck, that emitter is treated as dead and removed without blocking heartbeats to other clients.

**Initial connection:** On new connection, immediately send:
```
retry: 5000
id: {eventId}
event: connected
data: {"heartbeatInterval": 20000}
```
The `retry:` field tells the browser to wait 5 seconds before reconnecting. The `connected` event confirms the stream is established (client can verify receipt).

**Event buffer for Last-Event-ID replay:** Maintain a bounded circular buffer of the last 100 events (or last 5 minutes, whichever is less). When a client reconnects with `Last-Event-ID` header, replay events after that ID. If the ID is too old (not in buffer), send a `refresh` event type instead — the client does a single bulk fetch.

```java
private final ConcurrentLinkedDeque<BufferedEvent> eventBuffer = new ConcurrentLinkedDeque<>();
private static final int MAX_BUFFER_SIZE = 100;
private static final long MAX_BUFFER_AGE_MS = 5 * 60 * 1000L;
```

**Metrics (Micrometer):**
```java
Gauge.builder("sse.connections.active", activeConnections, AtomicInteger::get)
Counter.builder("sse.reconnections.total")     // increment when Last-Event-ID present
Timer.builder("sse.event.delivery.duration")   // wrap emitter.send()
Counter.builder("sse.send.failures.total")     // increment on IOException
```

### Client: @microsoft/fetch-event-source

**Why switch:** Native `EventSource` cannot send Authorization headers (only cookies and query params). The query-param token (`?token=jwt`) leaks credentials in nginx access logs, browser history, and Referer headers. `fetch-event-source` uses the standard `fetch()` API under the hood, supporting all headers.

**Reconnection strategy:**
```typescript
fetchEventSource('/api/v1/notifications/stream', {
  headers: { Authorization: `Bearer ${token}` },
  onmessage(ev) {
    retryCount = 0;
    if (ev.event === 'refresh') {
      // Server says gap too large — do single bulk refetch
      fetchBeds();
      fetchReferrals();
      return;
    }
    handleNotification(ev);
  },
  onerror(err) {
    retryCount++;
    // Exponential backoff with jitter: 1s, 2s, 4s, 8s, 16s, 30s max
    const delay = Math.min(1000 * Math.pow(2, retryCount), 30000);
    const jitter = delay * 0.3 * Math.random();
    return delay + jitter;
  },
  openWhenHidden: false, // auto-close when tab backgrounded
});
```

**Remove catchUp entirely.** The current `catchUp()` function dispatches `SSE_REFERRAL_UPDATE` and `SSE_AVAILABILITY_UPDATE` window events on every reconnect, triggering full refetches. This is replaced by:
- `Last-Event-ID` server-side replay for small gaps (most reconnects)
- `refresh` event type for large gaps (rare — only after 5+ minutes offline)

**Page Visibility:** `fetch-event-source` handles this automatically with `openWhenHidden: false`. When the tab is backgrounded, the connection closes. When foregrounded, it reconnects with `Last-Event-ID` and the server replays missed events. No full refetch needed.

### SseTokenFilter deprecation

The `SseTokenFilter` extracts JWT from the `?token=` query parameter for native `EventSource` which can't send headers. After switching to `fetch-event-source`, the primary auth path is the `Authorization` header (handled by `JwtAuthenticationFilter`).

Keep `SseTokenFilter` for backward compatibility but:
- Add a log warning when it's used: "SSE auth via query param is deprecated, use Authorization header"
- Do NOT remove it yet — older cached service workers may still use the old pattern

### Grafana dashboard

Add an "SSE Health" row to the FABT Operations dashboard:
- Panel 1: `sse.connections.active` gauge (should be flat, not sawtooth)
- Panel 2: `rate(sse.reconnections.total[5m])` (should be near-zero)
- Panel 3: `rate(sse.send.failures.total[5m])` (dead connection detection rate)

### Testing strategy

**Layer 1 — Backend integration (JUnit):**
Tests verify server-side behavior in isolation. Use Java `HttpClient` with `BodyHandlers.ofLines()` to consume SSE streams in tests.

**Layer 2 — Playwright E2E (browser):**
Wrap `EventSource` constructor (or `fetch` for fetch-event-source) via `addInitScript` to capture events into `window.__sseEvents`. Assert on event contents, connection count, and absence of refetch storms.

**Layer 3 — Gatling performance:**
New `SseStabilitySimulation` with 200 concurrent SSE connections held for 60 seconds. Verify 0 unexpected disconnects, heartbeats received at expected intervals. **Must run through nginx** (depends on nginx-dev-parity).

**Layer 4 — Grafana operational:**
After deployment, verify `sse.connections.active` is stable (not sawtooth). Alert if reconnection rate spikes.

## Risks

- **`fetch-event-source` is a new dependency:** ~2KB, maintained by Microsoft (Azure team), 3K+ GitHub stars, actively maintained. Low risk.
- **`SseEmitter(-1L)` memory leak if cleanup fails:** Mitigated by aggressive cleanup on any IOException + the `sse.connections.active` gauge as a canary. If it grows monotonically, there's a leak.
- **Event buffer grows unboundedly:** Mitigated by MAX_BUFFER_SIZE (100) and MAX_BUFFER_AGE_MS (5 minutes). Oldest events evicted first.
- **Gatling SSE test requires nginx-dev-parity:** This change depends on nginx-dev-parity being complete. The Gatling test must run through the nginx proxy to catch buffering regressions.
