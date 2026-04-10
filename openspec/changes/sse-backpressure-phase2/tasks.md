## Tasks

### Setup

- [ ] T-0: Create branch `feature/sse-backpressure-phase2` in code repo (`finding-a-bed-tonight`) from main.
- [ ] T-1: Capture pre-change baseline. Run `mvn test -Dtest='SseNotificationIntegrationTest,SseStabilityTest'` and tee to `logs/sse-baseline-pre-phase2.log`. Run the existing Playwright `sse-cache-regression.spec.ts` and `sse-connectivity.spec.ts` through nginx and tee to `logs/sse-playwright-baseline-pre-phase2.log`. Store both as the regression bar — every test in baseline must still pass after Phase 2.

### Backend — Core Implementation (D1-D9)

- [ ] T-2: Create `OutboundEvent` value type carrying `eventType`, `payload`, `priority` (CRITICAL/NORMAL), `coalesceKey` (nullable `(eventType, resourceId)` tuple), `eventId`, `timestamp`. Immutable record.
- [ ] T-3: Create `NotificationEmitter` wrapper class encapsulating `SseEmitter` + bounded `LinkedBlockingQueue<OutboundEvent>` (capacity from `fabt.sse.queue-capacity`, default 32). Public surface: `enqueue(OutboundEvent)`, `shutdown()`, `forceComplete()`, `userId()`, `createdAt()`. NO public `send()`. Direct `delegate.send()` is private to the sender thread loop. (D1)
  - *Persona — Alex Chen:* the type-system enforcement of single-writer is the load-bearing decision. Anyone who later writes "send broadcast from a Kafka listener" cannot bypass the queue without modifying the wrapper itself, which is a code-review-visible action. Don't expose `send()`.
  - *Persona — Sam Okafor:* capacity 32 chosen to keep per-client memory under ~64KB (32 events × 2KB JSON). Larger capacities don't help — slow clients should disconnect, not buffer indefinitely. Validate against the actual measurement in T-28 before tuning.
- [ ] T-4: Implement the per-emitter sender virtual thread in `NotificationEmitter`. Loop: `take() → send() → catch IOException silently → exit`. Per Spring guidance ([#21091](https://github.com/spring-projects/spring-framework/issues/21091)), do NOT call `completeWithError()` on send IOException — let the servlet container's `onError` callback drive cleanup. Thread name: `sse-sender-{userId}-{emitterIdx}`. (D2)
- [ ] T-5: Implement priority-aware enqueue in `NotificationEmitter.enqueue()`: NORMAL → coalesce by `coalesceKey` (replace existing entry), drop oldest NORMAL if full; CRITICAL → evict oldest NORMAL if full, disconnect-via-poison-pill if all entries are CRITICAL. Increment `sse.queue.drops{reason}` per branch. (D3)
  - *Persona — Riley Cho ("person in crisis"):* CRITICAL events (DV referral expiry, surge activation) are never silently dropped. The disconnect-rather-than-drop policy + persistent notification table fallback is the safety net. T-17 enforces this — if you change the enqueue logic, T-17 must still pass.
- [ ] T-6: Refactor `NotificationService.sendHeartbeat()` to enqueue a HEARTBEAT `OutboundEvent` (NORMAL priority, no coalesceKey, payload `: keepalive\n\n`) to every active emitter via `NotificationEmitter.enqueue()`. Failure to enqueue is treated identically to a CRITICAL queue overflow — the emitter is disconnected. (D4)
- [ ] T-7: Refactor `NotificationService.register()` to use `ConcurrentHashMap<UUID, List<NotificationEmitter>>`. On register: count existing emitters for the user; if size < `fabt.sse.max-connections-per-user` (default 5) → append; if size == cap → FIFO evict the oldest emitter, log at INFO with userId + remote IP + User-Agent, increment `sse.disconnect.cause{reason=cap_evicted}`, then append the new emitter. (D5)
  - *Persona — Marcus Webb (pen test):* the per-user cap is a Slowloris-class mitigation. It pairs with nginx `limit_conn_zone` (per-IP, outer layer) to bound total resource consumption per attacker.
  - *Persona — Marcus Okafor (CoC admin):* default cap of 5 fits exactly his "5-tab admin" workflow. If logs show frequent FIFO evictions for legitimate users in production, bump the default. Configurability matters — don't hardcode.
- [ ] T-8: Add `@ConcurrencyLimit(value=10, policy=REJECT)` to the broadcast fan-out method. Configurable via `fabt.sse.broadcast-concurrency-limit`. Add a `@Around` aspect or local catch around `InvocationRejectedException` that logs at WARN with `eventType`, `tenantId`, `recipientCount` (would-be) and increments `sse.broadcast.rejected{eventType}`. Do NOT propagate the exception — producer continues. (D6)
  - *Persona — Alex Chen:* REJECT (not BLOCK) is the correct policy for virtual-thread Spring Boot 4. BLOCK propagates SSE backpressure into unrelated upstream code paths (bed search, batch jobs, REST handlers calling `eventBus.publish`). Keep the producer thread free.
  - *Persona — Sam Okafor:* SLO is bed-search p95 < 500ms. SSE backpressure must not be allowed to leak into bed-search latency. REJECT + structured logging is the firewall.
  - *Persona — Riley Cho:* the "rejected CRITICAL events still reach users via REST catch-up" guarantee is load-bearing. Verify the persistent notification row exists before the rejected SSE broadcast — order of operations matters.
- [ ] T-9: Implement forced periodic reconnect in `NotificationEmitter` constructor. Schedule a `forceReconnect()` task at `fabt.sse.force-reconnect-minutes` (default 25) ± `ThreadLocalRandom.nextLong(-180_000, 180_000)` ms. `forceReconnect()` enqueues a poison pill, waits a short flush window for the sender to drain, then calls `delegate.complete()`. Increment `sse.disconnect.cause{reason=forced_reconnect}`. (D7)
- [ ] T-10: Refactor `NotificationService.@PreDestroy` to enforce a graceful shutdown deadline. Set `shuttingDown=true` on every emitter, enqueue poison pills, await a `CountDownLatch` with `fabt.sse.shutdown-deadline-seconds` timeout (default 5). On timeout, call `forceComplete()` on remaining emitters. Log `cleanCount`/`forcedCount`/`elapsedMs`. Add JFR `SseShutdownEvent`. (D8)
- [ ] T-11: Add feature flag `fabt.sse.transport=sse|polling` (default `sse`). When `polling`, the `/api/v1/notifications/stream` endpoint returns 503 with `Retry-After: 30` and a JSON body `{"error":"sse_disabled","message":"Real-time notifications are disabled; polling fallback active."}`. Read at request time, not startup — flag flip takes effect on next page load. (D9)
- [ ] T-12: Add the new config keys to `application.yml` with documentation comments. Add corresponding `FABT_SSE_*` env var overrides. Verify `application-prod.yml`, `application-lite.yml`, `application-standard.yml`, `application-full.yml` inherit defaults correctly.

### Backend — Refactor existing send paths (no behavior change)

- [ ] T-13: Refactor `NotificationService.notifyReferralResponse()`, `notifyReferralRequest()`, `notifyReferralExpired()`, `notifyAvailabilityUpdate()` to enqueue events through `NotificationEmitter.enqueue()` instead of calling `sendAndBufferEvent()` directly. Set `priority=CRITICAL` for `dv-referral.expired` and surge activation events; everything else NORMAL. Set `coalesceKey=(eventType, resourceId)` for `availability.updated` and `surge.level.changed`; null for `dv-referral.*` and `notification.created`.
- [ ] T-14: Refactor `NotificationPersistenceService.pushNotification()` to enqueue via `NotificationEmitter.enqueue()`. Severity CRITICAL → priority CRITICAL; INFO/ACTION_REQUIRED → priority NORMAL.
- [ ] T-15: Refactor `NotificationController.stream()` catch-up path. The virtual thread that runs `findUnreadForCatchup()` must also enqueue through `NotificationEmitter.enqueue()` instead of calling `sendAndBufferEvent()`. Order: most recent CRITICAL first, then ACTION_REQUIRED, then INFO, capped at 100.

### Backend — Tests

- [ ] T-16: `SlowClientIsolationTest` — 10 emitters, 1 throttled (sender thread artificially slowed via `Thread.sleep` injection or a test-only `BlockedSseEmitter` subclass), publish 50 events. Verify the 9 fast clients receive all 50 events within p95 < 500ms. Verify the throttled client's queue overflows and the client is disconnected (NOT the others). (Riley's "person in crisis" lens)
- [ ] T-17: `CriticalEventNotDroppedTest` — fill an emitter's queue with 32 NORMAL events, publish a CRITICAL event, verify the oldest NORMAL is evicted and the CRITICAL is delivered. Then fill the queue with 32 CRITICAL events, publish another CRITICAL, verify the client is disconnected (poison pill enqueued, `delegate.complete()` called) and `sse.disconnect.cause{reason=slow_client}` is incremented. Verify the persistent notification table still contains the CRITICAL row (REST catch-up safety net).
- [ ] T-18: `CoalescingTest` — publish 5 `availability.updated` events for the same shelter in rapid succession before the queue drains. Verify only 1 (the latest) reaches the wire and `sse.queue.drops{reason=coalesced}` is incremented by 4. Then publish 5 events for 5 *different* shelters; verify all 5 reach the wire (no coalescing across distinct keys).
- [ ] T-19: `PerUserConnectionCapTest` — register 5 emitters for the same userId, verify all 5 are active. Register a 6th, verify the 1st is FIFO-evicted (`completed`, removed from map) and the 6th is appended. Verify `sse.disconnect.cause{reason=cap_evicted}` is incremented exactly once.
- [ ] T-20: `BroadcastConcurrencyLimitTest` — set `fabt.sse.broadcast-concurrency-limit=2` via `@TestPropertySource`, simulate 5 concurrent broadcast invocations (e.g. via `CountDownLatch` to hold the first 2 in the method body). Verify exactly 2 succeed, 3 are rejected with `InvocationRejectedException`, the producer threads continue normally, `sse.broadcast.rejected{eventType}` is incremented by 3, and a WARN is logged for each.
- [ ] T-21: `GracefulShutdownDeadlineTest` — register 3 emitters, manually inject a "stuck" sender on one (sender that never drains the queue). Trigger `@PreDestroy`. Verify `cleanCount=2`, `forcedCount=1`, `elapsedMs >= 5000` (the deadline fired), and the JFR `SseShutdownEvent` was emitted.
- [ ] T-22: `ForcedReconnectTest` — set `fabt.sse.force-reconnect-minutes=0` and a fixed jitter via test-only setter. Register an emitter, verify it is `complete()`d on schedule with `sse.disconnect.cause{reason=forced_reconnect}` incremented. Connect a fresh client with `Last-Event-ID` matching the buffer; verify catch-up replays cleanly.
- [ ] T-23: `TransportFlagPollingTest` — set `fabt.sse.transport=polling` via `@TestPropertySource`. Verify `GET /api/v1/notifications/stream` returns 503 with `Retry-After: 30` and the expected JSON body. Verify the REST endpoints (`GET /notifications`, `GET /notifications/count`) still work.
- [ ] T-24: Re-run the full baseline from T-1 against the new implementation. ALL tests in the baseline must pass without modification. Save to `logs/sse-baseline-post-phase2.log` and `logs/sse-playwright-post-phase2.log`. Diff vs baseline; zero regressions allowed.

### Performance — Gatling

- [ ] T-25: Create `e2e/gatling/src/gatling/java/fabt/SseBackpressureSimulation.java`. Scenario A (mixed load): 200 SSE clients connect and stay subscribed for 10 minutes; concurrent bed search load at 50 req/s; 1 `availability.updated` event per shelter every 30s; 1 `notification.created` event per user every 60s. SLO: p95 SSE event delivery < 500ms, p99 < 1s, bed search p95 < 500ms, KO rate < 1%. **Run against local Docker compose, NOT findabed.org production.**
- [ ] T-26: Scenario B (slow-client isolation): same 200 SSE clients, but 10 of them are deliberately throttled (test-only `Thread.sleep(2000)` per event read in the simulation client). Verify: the 190 fast clients still meet p95 < 500ms; the 10 throttled clients are eventually disconnected with `sse.disconnect.cause{reason=slow_client}` increments visible in metrics; total Gatling KO rate stays < 5% (the slow-client disconnects count as KOs).
- [ ] T-27: Scenario C (forced reconnect storm): 500 SSE clients, force-reconnect-minutes set to 1 with ±30s jitter. Verify all 500 reconnect within a ~2-minute window (jitter prevents thundering herd), the nginx connector stays under p95 < 200ms for the reconnect requests, and the persistent notification REST catch-up endpoint stays under p95 < 200ms during the storm.
- [ ] T-28: **Memory capture during T-25/T-26/T-27.** Run the JVM with `-XX:StartFlightRecording=duration=15m,filename=sse-phase2.jfr`. Capture heap histograms (`jcmd <pid> GC.class_histogram`) at minute 0, 5, 10. Report: average heap delta per SSE client, total RSS at 200 clients, total RSS at 500 clients. Compare against the 100–400KB per-client estimate from the design research. If actual is > 1MB per client, file a follow-up to revisit `fabt.sse.queue-capacity` default.

### Observability

- [ ] T-29: Register new Micrometer metrics in `NotificationService` and `NotificationEmitter`:
  - `sse.queue.depth` — **single bounded gauge** reporting the *max* queue depth across all active emitters. **DO NOT tag by userId** — at NYC scale (500 users) per-user tagging produces 500 series, blowing through Sam Okafor's Prometheus storage budget. If per-user observability is later needed, add a histogram of queue-depth distribution or sample the top-10 fullest queues, NOT a per-user gauge.
  - `sse.queue.drops{reason=critical_evicted|normal_dropped|coalesced}` — counter, low cardinality
  - `sse.disconnect.cause{reason=slow_client|forced_reconnect|shutdown|cap_evicted}` — counter, low cardinality
  - `sse.broadcast.rejected{eventType}` — counter, tagged by event type only (NOT by tenant or recipient)
  - Existing metrics (`sse.connections.active`, `sse.send.failures.total`, `sse.event.delivery.duration`) preserved unchanged.
  - *Persona — Sam Okafor:* Prometheus cardinality budget is finite. Every label combination is a separate time series. Resist the urge to tag by `userId`, `tenantId`, or `subscriptionId` on counters — those fields are properties of the *event*, not the *metric*. Low-cardinality tags only.
- [ ] T-30: Update the Grafana dashboard JSON in `docs/observability/` (or wherever the dashboards live) with panels for the new metrics. Add an alert rule: `sse.disconnect.cause{reason=slow_client}` > 5 in 5 minutes → page Jordan Reyes (or whoever owns SRE alerts).

### Documentation

- [ ] T-31: Add a "SSE backpressure" section to `FOR-DEVELOPERS.md` covering the new config keys, the priority/coalescing semantics, the operational signal of each new metric, and the polling-fallback feature flag.
- [ ] T-32: Update `docs/asyncapi.yaml` to document the queue-overflow disconnect signal: when an SSE stream closes with a `retry: 2000` field, the client should reconnect via Last-Event-ID. (No new event types — the disconnect is communicated via the SSE close itself.)
- [ ] T-33: Update `CHANGELOG.md` under `[Unreleased]` with the Phase 2 entry (or promote to v0.33.0 when we tag).

### Pre-Merge

- [ ] T-34: Run full backend test suite (`mvn clean test`). All tests green, no regressions, ArchUnit boundaries intact. Tee to `logs/backend-full-suite-sse-phase2.log`.
- [ ] T-35: Run full Playwright suite through nginx. All tests green. Tee to `logs/playwright-sse-phase2.log`.
- [ ] T-36: Run all 3 Gatling scenarios (T-25/T-26/T-27). All SLO assertions pass. Tee outputs to `logs/gatling-sse-phase2-{a,b,c}.log`. Memory capture report (T-28) committed to `docs/performance/sse-phase2-memory-report.md`.
- [ ] T-37: Open PR against main, link to this OpenSpec change and the GitHub tracking issue. Hold for scans (memory: `feedback_release_after_scans`).
- [ ] T-38: After merge: bump `pom.xml` version (probably `0.33.0` since this is a substantive feature), promote CHANGELOG `[Unreleased]` → `[v0.33.0]`, tag, GitHub release.
- [ ] T-39: After release: archive this OpenSpec change via `/opsx:archive sse-backpressure-phase2`. Sync delta specs via `/opsx:sync` first if not already done.
