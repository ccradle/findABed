## Why

The SSE notification system delivers real-time updates by calling `emitter.send()` synchronously from whatever thread happens to publish the event — Spring's `@EventListener`, the `@Scheduled` heartbeat, the servlet thread on initial connect, and the virtual thread that runs catch-up replay. There is no queue, no single-writer guarantee, and no isolation between clients. One slow client on a degraded network blocks the publisher loop until the underlying TCP write times out, which delays event delivery for *every other client* in the same broadcast.

The original `platform-hardening` change (v0.30.0) identified this as Phase 2 work and explicitly deferred it ("Do NOT start these until Phase 1 verification passes"). Phase 1 shipped, persistent notifications shipped on top of it (v0.31.0), and most of the original Phase 2 design's *catch-up* requirements were inadvertently delivered along the way: Last-Event-ID replay, REST catch-up endpoint, persistent storage, idempotent cleanup callbacks, and Micrometer instrumentation are all in place. What remains is the **backpressure work itself** — the bounded queue, the single-writer thread, the priority-aware drop policy, the per-user connection cap, and the Gatling validation that proves slow clients can no longer block fast ones.

The persona drivers haven't changed:

- **Riley Cho (QA)**: "What happens to the person in crisis if this test is missing?" A DV referral expiry warning that gets dropped because the queue is full equals a survivor's advocate not knowing the placement is at risk. CRITICAL events must never be silently lost.
- **Sam Okafor (Performance)**: NYC-scale planning calls for ~200 concurrent SSE clients. The current direct-send pattern has not been load-tested at that scale; the only Gatling SSE simulation we have is single-tenant smoke.
- **Marcus Webb (Pen Tester)**: a slow-client DoS class is currently unmitigated. An attacker maintaining a degraded read pace blocks every other broadcast in the tenant. Bounded buffers + per-user connection caps are the standard Slowloris-family mitigation.
- **Alex Chen (Principal Engineer)**: Spring's `ResponseBodyEmitter` thread-safety contract is undocumented. Multiple threads currently call `emitter.send()` on the same emitter; the underlying `ReentrantLock writeLock` makes this *technically* safe today, but the contract is fragile and one accidental bypass corrupts framing. A `NotificationEmitter` wrapper that exposes only `enqueue()` makes the question moot by enforcing single-writer at the type system.

Two independent research streams (codebase audit + external best-practice research) confirmed the design space and the gaps. See `design.md` for the full decision record and `openspec/changes/platform-hardening/tasks.md` (Phase 1 Follow-up section) for the pointer back.

## What Changes

- **`NotificationEmitter` wrapper class** that holds a bounded `LinkedBlockingQueue<OutboundEvent>` (capacity 32, configurable via `fabt.sse.queue-capacity`) and exposes only `enqueue(event)` — direct `send()` becomes a private implementation detail. This is the type-system enforcement of the single-writer invariant.
- **One virtual-thread sender per emitter**, started when the emitter is created, that loops `take() → send() → catch IOException silently`. Spring Framework guidance ([Stoyanchev #21091](https://github.com/spring-projects/spring-framework/issues/21091)) is to *not* call `completeWithError()` from the user code on send IOException — the servlet container will drive cleanup through the registered callbacks. This eliminates the v0.29.2 cascade bug class permanently.
- **Priority-aware enqueue with coalescing**:
  - CRITICAL events (DV referral expiry, surge activation): if the queue is full, evict NORMAL events first; if no NORMAL events to evict, **disconnect the client** with a `retry: 2000` hint and let them reconnect via Last-Event-ID + REST catch-up. CRITICAL events are never silently dropped.
  - NORMAL events: coalesce by `(eventType, resourceId)` so 5 rapid `availability.updated` events for the same shelter collapse to the latest. Coalescing applies to all event types — no strict-ordering guarantees in this phase. CRITICAL events bypass coalescing.
- **Heartbeats** routed through the same per-emitter queue (not bypassed). Failure to enqueue a heartbeat is a disconnect signal.
- **Per-user concurrent SSE cap of 5** (configurable via `fabt.sse.max-connections-per-user`, default `5`). Sixth connection: **FIFO eviction** of the oldest connection, with a server-side log entry. Per-user scope (not per-IP) — Sandra Kim's "desktop + iPhone for rounds" pattern stays supported across networks.
- **Broadcast publisher concurrency cap** via Spring Framework 7's `@ConcurrencyLimit(value=10, policy=REJECT)` (configurable via `fabt.sse.broadcast-concurrency-limit`, default `10`). Rejected fan-outs log at WARN with eventType + tenant and increment a Micrometer counter `sse.broadcast.rejected{eventType}`. CRITICAL events still reach users via the persistent notification table on next bell mount.
- **Forced periodic reconnect** every 25 minutes ± 3 minutes jitter (configurable via `fabt.sse.force-reconnect-minutes`, default `25`). Netflix Zuul Push pattern. Prevents resource creep, state drift, and stale TCP connections. Client `EventSource` auto-reconnects and resends `Last-Event-ID`.
- **Graceful shutdown deadline**: `@PreDestroy` waits up to 5 seconds (configurable via `fabt.sse.shutdown-deadline-seconds`, default `5`) for all per-emitter sender threads to drain and complete. Forces `complete()` after the deadline. JFR-tracked.
- **Feature flag** `fabt.sse.transport=sse|polling` as a kill-switch. Default `sse`. Insurance against the corporate-proxy buffering class of failures (memory: `feedback_test_with_nginx_in_dev`).
- **Gatling SSE simulations** (3): 200 SSE + bed search concurrent load, 200 SSE with 10 deliberately throttled clients (proves fast-client isolation), forced-reconnect storm (proves jitter prevents thundering herd).
- **New Micrometer metrics**: `sse.queue.depth{user}`, `sse.queue.drops{reason=critical_evicted|normal_dropped|coalesced}`, `sse.disconnect.cause{reason=slow_client|forced_reconnect|shutdown|cap_evicted}`, `sse.broadcast.rejected{eventType}`. Grafana dashboard updates.

## Capabilities

### New Capabilities

- `sse-backpressure`: bounded per-client queues, single-writer enforcement, priority-aware drop policy with critical-event protection, per-user connection cap with FIFO eviction, broadcast concurrency cap, forced periodic reconnect, graceful shutdown with deadline.

### Modified Capabilities

- `notification-sse`: existing send path becomes a thin wrapper around `NotificationEmitter.enqueue()`. All direct `emitter.send()` call sites are refactored. Existing tests must continue to pass without modification.

## Out of Scope

- **WebFlux migration.** Spring's official position is that virtual threads are the recommended concurrency model for Spring Boot 4. The bounded-queue + single-writer pattern works on top of plain `SseEmitter`. Migrating one feature to WebFlux inside an otherwise WebMVC monolith introduces architectural complexity disproportionate to the benefit.
- **HTTP/2 upstream from nginx to Tomcat.** Phase 2 builds assuming HTTP/1.1 nginx → Tomcat (current state). If Sam Okafor's Gatling simulation at 200 clients reveals an nginx worker bottleneck, file a follow-up change `sse-http2-upstream`. Tomcat 11 HTTP/2 has the [#33832](https://github.com/spring-projects/spring-framework/issues/33832) gotcha (async client-disconnect IOExceptions bypass try/catch) and adds operational complexity.
- **Frontend changes.** The browser-side `EventSource` reconnect + REST catch-up flow already works (verified in audit). No frontend changes required for Phase 2.
- **Event schema changes.** The wire format for `availability.updated`, `dv-referral.*`, `notification.created`, etc. is unchanged.
- **WebSocket migration.** Out of scope. SSE remains the transport.

## Impact

- **Backend**: new `NotificationEmitter` wrapper class, refactored `NotificationService` send path, new `@ConcurrencyLimit` on broadcast publisher, new config keys (`fabt.sse.{max-connections-per-user, broadcast-concurrency-limit, transport, queue-capacity, force-reconnect-minutes, shutdown-deadline-seconds}`), no Flyway migrations, no API surface changes (HTTP/SSE wire format unchanged).
- **Tests**: 5 new backend integration tests (slow-client isolation, critical-not-dropped, coalescing, per-user cap, shutdown deadline), 3 new Gatling simulations with memory-capture acceptance criteria.
- **Performance**: expect p95 < 200ms business event → wire under 200-client load with 10 deliberately throttled. Memory per idle client: 100–400KB estimate, to be measured against local Docker compose during T-15/T-16/T-17 (NOT against findabed.org production VM).
- **Operations**: new Micrometer metrics + Grafana panels. Feature flag for SSE kill-switch.
- **Frontend**: zero changes.
- **Docs**: FOR-DEVELOPERS.md backpressure section, AsyncAPI documentation of the queue-overflow disconnect signal.
