## Context

The SSE notification service (`NotificationService.java`) currently calls `emitter.send()` directly from the event listener thread, the heartbeat scheduler, the servlet thread on register, and the catch-up virtual thread. There is no per-emitter queue, no single-writer guarantee, no slow-client isolation, no per-user connection cap, and no broadcast concurrency limit. The original `platform-hardening` Phase 2 design (D7) called this out and explicitly deferred it pending Phase 1 verification.

Phase 1 verified clean (PR #96, merged 2026-04-10). Persistent notifications (v0.31.0) and the notification RLS hotfix (v0.31.1) shipped on top, inadvertently delivering several Phase 2 catch-up requirements: Last-Event-ID buffer + replay, REST catch-up endpoint, durable notification storage, idempotent cleanup callbacks, and per-emitter Micrometer instrumentation. What remains is the **backpressure work itself**.

This change captures the remaining Phase 2 work as a standalone OpenSpec, informed by:

1. A **codebase audit** (2026-04-10) of `NotificationService.java`, `NotificationPersistenceService.java`, `SseNotificationIntegrationTest.java`, `SseStabilityTest.java`, and the v0.31.x git history.
2. **External best-practice research** spanning Spring Framework 7 docs, Spring issue tracker #17815/#21091/#33340/#33832, the WHATWG HTML5 SSE spec, JEP 491 (Synchronize Virtual Threads without Pinning), Netflix Zuul Push, and several production reports.
3. **Persona consultation** with Alex Chen (Principal), Sam Okafor (Performance), Marcus Webb (Pen Test), Riley Cho (QA), and Keisha Thompson (Lived Experience).

Five open questions were resolved with the project lead before this design was written. Their answers are baked into the decisions below.

## Goals / Non-Goals

**Goals:**
- Eliminate the slow-client cascade — one slow client must never block event delivery to other clients in the same tenant.
- Enforce single-writer per emitter through the type system, not by convention.
- Guarantee CRITICAL events are never silently dropped — they reach the user via SSE OR persistent notification + REST catch-up on next mount.
- Bound per-user resource consumption (connection cap with FIFO eviction).
- Bound publisher-side fan-out work (broadcast concurrency limit).
- Validate the design at 200-client NYC scale with Gatling, including memory-per-connection measurement.
- Provide a kill-switch to fall back to polling if corporate proxies misbehave in pilot deployments.

**Non-Goals:**
- WebFlux migration. Spring's official position is virtual threads + WebMVC for Spring Boot 4.
- HTTP/2 upstream from nginx to Tomcat. Defer until measured bottleneck.
- WebSocket migration. SSE stays.
- Frontend changes. The existing `EventSource` reconnect + REST catch-up flow works.
- Strict event ordering guarantees. Coalescing may collapse repeated updates of the same `(type, resourceId)`.

## Decisions

### D1: Bounded `LinkedBlockingQueue` per emitter, encapsulated in `NotificationEmitter` wrapper

Each `SseEmitter` is wrapped in a `NotificationEmitter` class that holds:

```java
public final class NotificationEmitter {
    private final SseEmitter delegate;          // package-private accessor only
    private final BlockingQueue<OutboundEvent> inbox;  // bounded, capacity 32
    private final Thread sender;                // virtual thread, one per emitter
    private volatile boolean shuttingDown;
    // ... lifecycle methods, metrics, no public send()
    public boolean enqueue(OutboundEvent event) { ... }
}
```

Capacity 32 is configurable via `fabt.sse.queue-capacity` (default `32`). Rationale: 32 events × 2KB ≈ 64KB worst-case per client; well within the 100–400KB per-client estimate. Larger capacities increase memory linearly without proportional benefit (slow clients should disconnect, not buffer indefinitely).

The wrapper exposes only `enqueue(event)`. Direct `send()` becomes a private implementation detail of the sender thread. **This is the type-system enforcement of the single-writer invariant.** Anyone who later writes "send broadcast from a Kafka listener" cannot bypass the queue without modifying the wrapper itself, which is a code-review-visible action.

### D2: One virtual-thread sender per emitter — only writer to `delegate.send()`

Each `NotificationEmitter` starts a dedicated virtual thread on construction:

```java
this.sender = Thread.ofVirtual()
    .name("sse-sender-" + userId + "-" + emitterIdx)
    .start(this::drainLoop);
```

The `drainLoop` is:

```java
while (!shuttingDown) {
    OutboundEvent event = inbox.take();      // blocks
    if (event == POISON_PILL) break;
    try {
        delegate.send(event.toSseEventBuilder());
    } catch (IOException ioe) {
        // Per Stoyanchev: do NOT call completeWithError. Let the
        // servlet container's onError callback drive cleanup.
        log.debug("SSE send failed for {}: {}", userId, ioe.getMessage());
        break;
    }
}
```

Spring Framework guidance ([#21091](https://github.com/spring-projects/spring-framework/issues/21091), [#33832](https://github.com/spring-projects/spring-framework/issues/33832)): the user code must NOT call `completeWithError()` from a send IOException — the servlet container will fire `onError` asynchronously, and double-cleanup corrupts state. This is especially important on Tomcat HTTP/2 where client-disconnect IOExceptions arrive on a separate thread.

Because virtual threads on JDK 25 LTS no longer pin on `synchronized` ([JEP 491](https://openjdk.org/jeps/491)), the sender thread can park on `inbox.take()` indefinitely without consuming a carrier OS thread. ~few KB per parked sender × 500 emitters = manageable.

### D3: Priority-aware enqueue with critical-event protection

`OutboundEvent` carries a `Priority { CRITICAL, NORMAL }` and an optional `coalesceKey: (eventType, resourceId)`.

Enqueue logic:

1. **NORMAL event**:
   - If `coalesceKey` matches an existing entry in the queue, replace it (latest-wins). Increment `sse.queue.drops{reason=coalesced}`.
   - Otherwise `offer()` to the queue. If full, drop the oldest NORMAL entry to make room. Increment `sse.queue.drops{reason=normal_dropped}`.
2. **CRITICAL event**:
   - `offer()` to the queue. If full, evict the oldest NORMAL entry to make room (`sse.queue.drops{reason=critical_evicted}`).
   - If queue is still full (all entries are CRITICAL), **disconnect the client**: enqueue a poison pill, schedule `delegate.complete()` after a short flush window, and let the client reconnect via `Last-Event-ID` + REST catch-up. Increment `sse.disconnect.cause{reason=slow_client}`.
   - **CRITICAL events are never silently dropped.** The persistent notification table already has the event (Riley's safety net) — if SSE delivery fails, the bell badge + REST catch-up on next page mount delivers the CRITICAL banner.

Coalescing applies to all event types. The project lead confirmed (2026-04-10) that no event type requires strict ordering "at this time." Distinct resources stay distinct (different `referralId` → different keys → both delivered); only repeated updates for the *same* resource collapse to the latest.

### D4: Heartbeats routed through the same per-emitter queue

The `@Scheduled` heartbeat sender enqueues a `HEARTBEAT` event (NORMAL priority, no coalesce key, payload `: keepalive`) to every active emitter. Two reasons:

1. **Single-writer enforcement.** Direct heartbeat sends would bypass the sender thread, reintroducing the multi-writer race that the wrapper exists to eliminate.
2. **Liveness signal.** If the queue is full and the heartbeat can't be enqueued, the client is already in trouble — disconnecting them via the same flow as a CRITICAL queue overflow is the right response.

The HTML5 SSE spec recommends heartbeats every "15 seconds or so." Current code uses 20s. Phase 2 keeps 20s. Heartbeats are sent as named comment lines (`: keepalive\n\n`) rather than data events; they advance the SSE event ID for client-side liveness detection.

### D5: Per-user concurrent SSE cap of 5 with FIFO eviction

`fabt.sse.max-connections-per-user` (default `5`). On register:

1. Look up the user's existing `NotificationEmitter` list in the `ConcurrentHashMap<UUID, List<NotificationEmitter>>`.
2. If size < cap → append the new emitter.
3. If size == cap → **FIFO evict** the oldest emitter (`emitters.remove(0)`), call `complete()` on it, increment `sse.disconnect.cause{reason=cap_evicted}`, log at INFO with userId and the new connection's source IP/User-Agent.

Per-user (not per-IP). Sandra Kim's "desktop at front desk + iPhone on rounds from a different network" pattern stays supported. Marcus Okafor's 5-tab admin pattern fits exactly at the default. Configurability lets per-CoC operators bump it for power users.

The 5-cap is the application layer; nginx's `limit_conn_zone` provides a per-IP outer limit independently. Together they form the Slowloris-class mitigation Marcus Webb's review identified as missing.

### D6: Broadcast publisher concurrency cap via `@ConcurrencyLimit(REJECT)`

Spring Framework 7's `@ConcurrencyLimit` is applied to the broadcast fan-out method (e.g. `notifyReferralResponse`, `notifyAvailabilityUpdate`):

```java
@ConcurrencyLimit(value = 10, policy = ConcurrencyLimit.Policy.REJECT)
public void broadcast(DomainEvent event) { ... }
```

Configurable via `fabt.sse.broadcast-concurrency-limit` (default `10`). Rejected calls throw `InvocationRejectedException`, which a wrapping aspect catches and:

1. Logs at WARN with `eventType`, `tenantId`, `recipientCount` (would-be).
2. Increments `sse.broadcast.rejected{eventType}`.
3. Does **not** propagate the exception — the producer (Spring `@EventListener` thread, scheduled job, REST handler) continues normally.

REJECT was chosen over BLOCK because:

- BLOCK propagates SSE backpressure into unrelated upstream code (bed search, REST handlers, batch jobs). One slow client can subtly degrade unrelated SLOs.
- The persistent notifications safety net means rejected CRITICAL fan-outs still reach the user via the bell badge / banner on next mount. SSE is a hint, REST is the source of truth.
- Spring's own resilience docs ([Spring Framework 7 reference](https://docs.spring.io/spring-framework/reference/core/resilience.html)) call out REJECT as "particularly useful with virtual threads where there is generally no thread pool limit in place."

### D7: Forced periodic reconnect with jitter (Netflix Zuul Push pattern)

Each `NotificationEmitter` schedules its own forced-reconnect at construction:

```java
long jitterMs = ThreadLocalRandom.current().nextLong(-180_000, 180_000);  // ±3 min
long forceAfterMs = TimeUnit.MINUTES.toMillis(forceReconnectMinutes) + jitterMs;
scheduler.schedule(this::forceReconnect, forceAfterMs, MILLISECONDS);
```

`fabt.sse.force-reconnect-minutes` (default `25`). Range with jitter: 22–28 minutes.

`forceReconnect()` enqueues a poison pill (so the sender drains in-flight events) and then calls `delegate.complete()`. The client's `EventSource` automatically reconnects with `Last-Event-ID`, the REST catch-up replays anything missed, and the new emitter starts fresh.

Why force reconnect:

- Long-lived TCP connections accumulate kernel-level state and can drift into half-open states across NAT timeouts.
- Server-side per-emitter resources (queue, virtual thread, scheduler entry) eventually become stale references if cleanup callbacks misfire under load.
- Jitter prevents thundering-herd reconnects after a server restart or rolling deploy.

Netflix Zuul Push ([wiki](https://github.com/Netflix/zuul/wiki/Push-Messaging)) operates 5.5M concurrent push connections with this exact pattern, with `zuul.push.reconnect.dither.seconds = 180`. The 25-min ± 3-min default is shorter than Zuul's because FABT's tenant-scale doesn't yet justify Zuul's 30-min interval.

### D8: Graceful shutdown deadline of 5 seconds

`@PreDestroy` runs:

```java
shuttingDown = true;
emitters.values().forEach(list -> list.forEach(NotificationEmitter::shutdown));
boolean clean = shutdownLatch.await(5, SECONDS);
if (!clean) {
    log.warn("SSE shutdown deadline exceeded — forcing complete on remaining {} emitters",
             emitters.size());
    emitters.values().forEach(list -> list.forEach(NotificationEmitter::forceComplete));
}
```

`fabt.sse.shutdown-deadline-seconds` (default `5`). Per-emitter `shutdown()` enqueues a poison pill (sender drains in-flight events, then exits) and waits up to 1 second per emitter for the sender thread to terminate. `forceComplete()` interrupts the sender thread and calls `delegate.complete()` immediately.

Without the deadline, `@PreDestroy` could hang indefinitely if a single client's TCP write is stuck (kernel buffer full and no ACKs). The deadline forces forward progress at the cost of in-flight events on stuck connections — those clients will reconnect and catch up via REST.

JFR-tracked: a custom `SseShutdownEvent` records `cleanCount`, `forcedCount`, `elapsedMs` for each shutdown. Helps Jordan Reyes correlate restarts with stuck-client incidents.

### D9: Feature flag `fabt.sse.transport=sse|polling` as kill-switch

`fabt.sse.transport` (default `sse`). When set to `polling`, the `/api/v1/notifications/stream` endpoint returns 503 with a Retry-After header, and the frontend's existing fallback logic (already present per the audit) reverts to REST polling at the bell badge interval.

This is insurance against the corporate-proxy buffering class of failures. The audit found `feedback_test_with_nginx_in_dev` flagging this exact risk: "customers have migrated from SSE to WebSockets after discovering their SSE connections work in development but buffer unpredictably in production." Some pilot deployments will be behind enterprise proxies we don't control. A flag flip is faster than a rollback.

The flag is read at request time (not application startup), so flipping it takes effect on the next page load without a restart.

## Risks / Trade-offs

- **Spring `ResponseBodyEmitter` thread-safety is undocumented.** D1+D2 (single-writer wrapper + dedicated sender thread) eliminate the question. Mitigation: enforce via type system, not convention. The wrapper class has no public `send()` method.
- **Critical events dropped under cascading load.** Mitigated by D3's "evict NORMAL first, then disconnect rather than drop" policy + the persistent notification table as the durable source of truth. SSE is a hint; REST catch-up is authoritative.
- **Forced-reconnect storm after server restart.** Mitigated by D7's ±3 minute jitter. With 500 clients reconnecting over a 6-minute window, the rate is ~1.4/sec — well within nginx and Tomcat connector limits.
- **Coalescing breaks ordering.** Project lead confirmed strict ordering is not required at this time. Any future event type that *does* require strict ordering must opt out by setting `coalesceKey = null` and accepting the queue-overflow drop policy.
- **`@ConcurrencyLimit(REJECT)` silently drops events.** Mitigated by structured logging + Micrometer counter so operators can tune the limit. CRITICAL events still reach users via the persistent notification path independent of SSE broadcast.
- **Corporate proxy buffering.** Independent of backend; D9's polling fallback is the only available mitigation. Backend can't fix what it doesn't control.
- **Per-user cap of 5 may surprise power users.** Configurable. Default chosen to fit Marcus Okafor's 5-tab admin workflow exactly. If logs show frequent FIFO evictions for legitimate users, bump the default.
- **Memory-per-connection estimates are unverified.** D8's Gatling tasks (T-15/T-16/T-17) include memory-capture acceptance criteria specifically to validate or invalidate the 100–400KB estimate. Run against local Docker compose, NOT findabed.org production VM (Jordan Reyes constraint).
- **Phase 2 enables, doesn't deploy.** This change adds backpressure. It does NOT change the wire format, the persistent notification schema, or the REST catch-up path. Phase 2 is purely additive: existing tests must continue to pass without modification, and the rollout is a feature flag flip plus a code deploy.

## Open Questions Resolved Before Design

The five questions below were resolved with the project lead on 2026-04-10. Their answers are baked into the decisions above.

1. **Strict ordering required for any event type?** No, not at this time. → D3 coalesces all event types by `(eventType, resourceId)`.
2. **Behavior when user has more than the cap of concurrent SSE connections?** Cap of 5, configurable, FIFO eviction, per-user. → D5.
3. **`@ConcurrencyLimit(BLOCK)` vs `(REJECT)`?** REJECT, default 10, configurable, with structured logging + Micrometer counter. → D6.
4. **HTTP/2 termination at nginx or Tomcat?** Defer. Phase 2 builds assuming HTTP/1.1 nginx → Tomcat. Listed in proposal "Out of scope". → trigger for revisiting is a Gatling-measured nginx worker bottleneck.
5. **Benchmark memory-per-connection on Oracle VM before pilot?** Option B: measure during Phase 2 Gatling tasks against local Docker compose, NOT findabed.org production. → T-15/T-16/T-17 acceptance criteria include heap histogram + JFR capture.
