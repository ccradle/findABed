## Tasks

### Setup

- [x] Task 0: (all tasks complete — see commit history on sse-stability branch) Create feature branch in code repo
  **Repo:** `finding-a-bed-tonight/`
  **Action:** `git checkout -b sse-stability main`

### Server — SseEmitter Hardening

- [x] Task 1: Change SseEmitter timeout to -1L
  **File:** `backend/src/main/java/org/fabt/notification/service/NotificationService.java`
  **Action:** Change `EMITTER_TIMEOUT_MS` from `5 * 60 * 1000L` to `-1L`. Update the comment to explain: no server-side timeout; dead connections detected by heartbeat failure. Verify `onTimeout` callback still registered (it becomes a no-op with -1L but doesn't hurt).

- [x] Task 2: Tighten heartbeat to 20 seconds
  **File:** `backend/src/main/java/org/fabt/notification/service/NotificationService.java`
  **Action:** Change `@Scheduled(fixedRate = 30_000)` to `@Scheduled(fixedRate = 20_000)`. Update constant/comment. This gives nginx 6 heartbeat cycles before `proxy_read_timeout 120s` expires. Wrap each individual heartbeat send in a try-catch — if any send throws or takes longer than 5 seconds, treat as dead connection and remove the emitter immediately. Do not let one slow/stuck emitter block heartbeats to other clients.

- [x] Task 3: Send initial connection event with retry field
  **File:** `backend/src/main/java/org/fabt/notification/service/NotificationService.java`
  **Action:** In the `register()` method, after creating the emitter, immediately send:
  ```java
  emitter.send(SseEmitter.event()
      .id(String.valueOf(eventIdCounter.incrementAndGet()))
      .name("connected")
      .data("{\"heartbeatInterval\":20000}")
      .reconnectTime(5000));
  ```
  Include monotonic `id:` on this and ALL subsequent events. **Heartbeats should also be named events** (`event: heartbeat`) with incrementing `id:` — not SSE comments. This ensures `Last-Event-ID` stays current even during quiet periods (if heartbeats are comments, they don't advance the ID, and reconnect replay would include everything since the last real event). The client's `onmessage` handler ignores `heartbeat` events (no UI action).

- [x] Task 4: Add Last-Event-ID replay buffer
  **File:** `backend/src/main/java/org/fabt/notification/service/NotificationService.java`
  **Action:** Add a `ConcurrentLinkedDeque<BufferedEvent>` with max 100 entries and 5-minute age limit. On every `broadcast()`, add the event to the buffer (evict old). In `register()`, check for `Last-Event-ID` (passed from controller). If present and found in buffer, replay events after that ID **filtered by the reconnecting user's tenant and role permissions** (same filtering logic already in `onDomainEvent`). If not found, send a `refresh` event type. Add `BufferedEvent` record: `(long id, String eventType, String data, UUID tenantId, boolean requiresDvAccess, Instant timestamp)`. The tenant and DV fields enable per-user filtering during replay without leaking cross-tenant events.

- [x] Task 5: Accept Last-Event-ID in controller
  **File:** `backend/src/main/java/org/fabt/notification/api/NotificationController.java`
  **Action:** Add `@RequestHeader(value = "Last-Event-ID", required = false) String lastEventId` parameter. Pass to `notificationService.register(...)`. Parse to `long` if present.

- [x] Task 6: Add graceful shutdown for emitters
  **File:** `backend/src/main/java/org/fabt/notification/service/NotificationService.java`
  **Action:** Add `@PreDestroy` method that iterates all emitters and calls `complete()`. Log the count of closed connections.

- [x] Task 7: Add deprecation warning to SseTokenFilter
  **File:** `backend/src/main/java/org/fabt/shared/security/SseTokenFilter.java`
  **Action:** When the filter extracts a token from the `?token=` query param, log at WARN level: `"SSE auth via query param is deprecated — use Authorization header instead (user: {})"`. Keep filter functional for backward compatibility.

### Server — Observability

- [ ] Task 8: Add Micrometer SSE metrics
  **File:** `backend/src/main/java/org/fabt/notification/service/NotificationService.java`
  **Action:** Inject `MeterRegistry`. Register 4 metrics:
  - `Gauge.builder("sse.connections.active", activeConnections, AtomicInteger::get)`
  - `Counter.builder("sse.reconnections.total")` — increment when `lastEventId` is present on register
  - `Timer.builder("sse.event.delivery.duration")` — wrap the `emitters.forEach(send)` loop
  - `Counter.builder("sse.send.failures.total")` — increment on IOException in send/heartbeat

- [ ] Task 9: Add Grafana SSE health panel
  **File:** `grafana/dashboards/fabt-operations.json`
  **Action:** Add an "SSE Health" row with 3 panels: active connections gauge, reconnection rate, send failure rate. Use Prometheus queries matching the metric names from Task 8.

### Client — fetch-event-source Migration

- [ ] Task 10: Install @microsoft/fetch-event-source
  **Action:** `cd frontend && npm install @microsoft/fetch-event-source`

- [ ] Task 11: Rewrite useNotifications hook
  **File:** `frontend/src/hooks/useNotifications.ts`
  **Action:** Replace native `EventSource` with `fetchEventSource`:
  - Use `Authorization: Bearer ${token}` header (not query-param)
  - Set `openWhenHidden: false` (Page Visibility auto-handling)
  - In `onmessage`: route `ev.event` through a dispatch map matching the current `addEventListener` names: `{ 'dv-referral.responded': handleReferralResponse, 'dv-referral.requested': handleReferralRequest, 'availability.updated': handleAvailabilityUpdate, 'connected': handleConnected, 'refresh': handleRefresh }`. Reset retry counter on any message.
  - In `onerror`: return exponential backoff delay (initial 1s, max 30s, factor 2, 30% jitter)
  - In `onopen`: verify response is OK, set `connected = true`
  - Remove `catchUp()` function entirely
  - Remove `SSE_REFERRAL_UPDATE` and `SSE_AVAILABILITY_UPDATE` window event dispatching on reconnect
  - On `refresh` event: dispatch both events ONCE (single bulk refetch for large gap)
  - Remove `reconnectingRef` and `lastCatchUpRef` (no longer needed)

- [ ] Task 12: Preserve real-time update listeners, remove reconnect-triggered refetch
  **File:** `frontend/src/pages/OutreachSearch.tsx`
  **Action:** The `SSE_REFERRAL_UPDATE` and `SSE_AVAILABILITY_UPDATE` window event listeners in OutreachSearch MUST REMAIN — they are how real-time updates reach the search results when a coordinator updates availability or a referral is responded to. What changes is WHO dispatches them:
  - **Before:** `catchUp()` dispatched both events on every SSE reconnect → refetch storm
  - **After:** The `onmessage` handler in `useNotifications` dispatches `SSE_AVAILABILITY_UPDATE` only when an actual `availability.updated` SSE event arrives, and `SSE_REFERRAL_UPDATE` only when a `dv-referral.*` event arrives. The `refresh` event type dispatches both (single bulk catchup for large gaps).
  - **Verify:** After implementation, real-time updates still work (coordinator updates beds → outreach worker sees change within seconds).

### Backend Tests

- [ ] Task 13: Add SSE stability integration tests
  **File:** `backend/src/test/java/org/fabt/notification/SseStabilityTest.java` (new)
  **Action:** Using Java HttpClient with `BodyHandlers.ofLines()`:
  - `test_sseConnection_staysAlive_60seconds` — connect, wait 60s, verify no timeout/disconnect
  - `test_heartbeat_receivedEvery20Seconds` — count heartbeat comments in 45s window, expect ≥ 2
  - `test_initialEvent_containsRetryAndId` — verify first event has `retry:`, `id:`, `event: connected`
  - `test_lastEventId_replaysFromBuffer` — send events, disconnect, reconnect with Last-Event-ID, verify missed events replayed
  - `test_lastEventId_stale_sendsRefresh` — reconnect with unknown ID, verify `refresh` event
  - `test_deadConnection_cleanedUp` — close client, wait 25s, verify emitter removed from registry
  - `test_metrics_registered` — verify all 4 Micrometer metrics exist and update

- [ ] Task 14: Verify existing SSE tests pass (run BEFORE Task 13)
  **File:** `backend/src/test/java/org/fabt/notification/SseNotificationIntegrationTest.java`
  **Action:** Run existing SSE tests first to establish baseline after Tasks 1-9 changes. Verify they still pass with the new timeout (-1L) and heartbeat (20s) changes. Update any assertions that depended on the 5-minute timeout behavior. This must pass before writing new stability tests (Task 13).

### Playwright E2E Tests

- [ ] Task 15: Add EventSource/fetch wrapper for test instrumentation
  **File:** `e2e/playwright/fixtures/sse-instrumentation.ts` (new)
  **Action:** Create a reusable `addInitScript` that wraps `fetch` calls to the SSE endpoint, capturing:
  - Connection count (how many times SSE endpoint was opened)
  - Events received (array of `{type, data, id}`)
  - Expose via `window.__sseConnections` and `window.__sseEvents`

- [ ] Task 16: Rewrite SSE Playwright tests
  **File:** `e2e/playwright/tests/sse-connectivity.spec.ts` (new, replaces assertions in offline-behavior.spec.ts)
  **Action:** Using the instrumentation from Task 15:
  - `test_sseStaysConnected_30seconds` — assert `window.__sseConnections === 1` after 30 seconds (use `test.slow()`)
  - `test_sseReceivesHeartbeats` — assert heartbeat events received in `window.__sseEvents`
  - `test_noRefetchStorm` — count requests to `/api/v1/queries/beds` over 30s, assert ≤ 1 (initial load only)
  - `test_pageVisibility_closesAndReconnects` — background tab, verify connection closed, foreground, verify reconnect without UI disruption
  - Run in both default (Vite) and nginx Playwright profiles

- [ ] Task 17: Remove misleading offline test assertion
  **File:** `e2e/playwright/tests/offline-behavior.spec.ts`
  **Action:** Remove or rewrite test 3 ("queued availability update replays on reconnect") which only asserts page doesn't crash. This test's real assertions are now in `sse-connectivity.spec.ts` (Task 16) and will be in the `offline-honesty` change for actual queue/replay behavior.

### Gatling Performance

- [ ] Task 18: Create SseStabilitySimulation
  **File:** `e2e/gatling/src/gatling/java/fabt/SseStabilitySimulation.java` (new)
  **Action:** Gatling SSE simulation:
  - Login, obtain JWT
  - Open SSE connection to `/api/v1/notifications/stream` with `Authorization` header
  - Hold connection for 60 seconds
  - Verify heartbeat events received at ~20s intervals
  - Close connection
  - Inject: ramp 200 users over 60 seconds
  - Assertions: 0 unexpected disconnects, heartbeats received, p99 heartbeat latency < 100ms
  - **Must run through nginx** (use `baseUrl: http://localhost:8081` when `nginx-dev-parity` is available)
  - Verify Gatling SSE API supports custom headers (`sse("Connect").get(url).header("Authorization", "Bearer #{jwt}")`). If not supported, keep query-param token auth as Gatling-only fallback and document why.

### Documentation

- [ ] Task 19: Update documentation
  **Files:** `oracle-demo-runbook-v0.21.0.md` (local only), `docs/FOR-DEVELOPERS.md` (committed)
  **Action:**
  - **Runbook:** Update "Bed Search page keeps refreshing" troubleshooting entry to reflect the root cause fix (SseEmitter timeout, not just nginx buffering). Add: "If `sse.connections.active` shows a sawtooth pattern in Grafana, the SseEmitter timeout may have regressed."
  - **FOR-DEVELOPERS.md:** Add "SSE Architecture" section explaining: SseEmitter with -1L timeout, 20s named-event heartbeats, Last-Event-ID replay buffer, `@microsoft/fetch-event-source` with backoff+jitter, Page Visibility integration, 4 Micrometer metrics. This ensures the architecture persists with the code, not just in the runbook.

### Verification

- [ ] Task 20: Run full test suite (4 layers)
  **Action:** All with output saved to log files:
  1. Backend: `mvn test 2>&1 | tee /tmp/backend-sse.log`
  2. Playwright (Vite): `npx playwright test 2>&1 | tee /tmp/pw-vite-sse.log`
  3. Playwright (nginx): `npx playwright test --project=nginx 2>&1 | tee /tmp/pw-nginx-sse.log` (requires nginx-dev-parity)
  4. Gatling SSE: `mvn gatling:test -Pperf -Dgatling.simulationClass=fabt.SseStabilitySimulation 2>&1 | tee /tmp/gatling-sse.log`
  5. Grafana: verify `sse.connections.active` is flat (not sawtooth) after 5 minutes of demo use

### Merge and Deploy

- [ ] Task 21: Merge to main, tag, push
  **Action:** Merge, create tag (version TBD), push. CHANGELOG entry.

- [ ] Task 22: Deploy to Oracle demo
  **Action:** SSH, checkout tag, build backend + frontend, rebuild Docker images, redeploy.

- [ ] Task 23: Smoke test live demo
  **Action:** Open demo site on phone and desktop. Navigate to Bed Search. Wait 5 minutes. Verify:
  - No screen refresh/blink
  - No console errors related to SSE
  - Grafana `sse.connections.active` is stable
  - Browser DevTools Network tab shows single long-lived SSE connection
