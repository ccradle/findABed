## 1. Branch & Baseline

- [x] 1.1 Create branch `sse-emitter-lifecycle-fix` in finding-a-bed-tonight repo
- [x] 1.2 Run existing backend tests (`mvn clean test 2>&1 | tee logs/backend-tests.log`) — confirm green baseline
- [x] 1.3 Capture current backend SSE error logs from production for before/after comparison

## 2. Backend — Emitter Lifecycle Fixes

- [x] 2.1 Fix `sendHeartbeat()` in `NotificationService.java`: on IOException, remove emitter from map FIRST via `emitters.remove(userId)`, THEN call `completeWithError(e)` inside try-catch. Change log from DEBUG to WARN with userId and error class. (Design D1, D4)
- [x] 2.2 Fix `sendEvent()` in `NotificationService.java`: same pattern — remove from map first, then completeWithError in try-catch. WARN-level log. (Design D1, D4)
- [x] 2.3 Make `onError`, `onCompletion`, `onTimeout` callbacks idempotent: check `emitters.containsKey(userId)` before running cleanup. (Design D5)
- [x] 2.4 Add `server.servlet.async.request-timeout: 600000` to `application.yml` (Design D3)
- [x] 2.5 Add `DispatcherType.ASYNC` permitAll for `/api/v1/notifications/**` in `SecurityConfig.java` (Design D2)
- [x] 2.6 Run `mvn clean test` — confirm all 384 tests pass including SSE tests

## 3. Positive Tests — Requirements Met

- [x] 3.1 Add integration test: heartbeat error recovery — register emitter via real SSE HttpClient connection, close the client connection to force IOException, manually invoke `referralTokenService.expireTokens()` or `notificationService.sendHeartbeat()` to trigger a send to the dead emitter, assert no `IllegalStateException` thrown and emitter removed from registry (use `notificationService.getActiveConnectionCount()` to verify)
- [x] 3.2 Add integration test: event broadcast error recovery — register two emitters (user A and user B), close user A's connection, publish a domain event, verify user B still receives it and user A's emitter is cleaned up without affecting user B
- [x] 3.3 Add integration test: SSE connection survives 45 seconds with heartbeats (proves async timeout > 30s default is overridden)
- [x] 3.4 Add integration test: onTimeout cleanup — register emitter with short timeout (5s via test-only constructor or reflection), wait 6s, verify emitter removed cleanly with no cascading exceptions
- [x] 3.5 Verify existing `tc_expireTokens_publishesSseEvent` still passes (SSE event delivery works)
- [x] 3.6 Verify existing `SseNotificationIntegrationTest` suite still passes (all SSE tests green)
- [x] 3.7 Verify WARN-level log emitted on emitter failure — check log output contains userId and error class after forced disconnect

## 4. Negative Tests — Nothing Broken

- [x] 4.1 Verify unauthenticated SSE connection still returns 401 (async permitAll doesn't bypass initial auth)
- [x] 4.2 Verify non-SSE authenticated endpoint still requires auth — `GET /api/v1/shelters` without token returns 401 (confirms async permitAll is scoped to SSE only, not site-wide)
- [x] 4.3 Run full backend test suite — confirm zero regressions
- [x] 4.4 Run full Playwright suite — confirm SSE-dependent tests pass (DV referral expiration, notifications)

## 5. Integration & Release

- [x] 5.1 Run `npm --prefix frontend run build` — confirm clean (no frontend changes, but verify)
- [x] 5.2 Test through nginx proxy with trace logging — verify no SSE errors in backend log
- [x] 5.3 Create `docs/oracle-update-notes-v0.29.2.md` — backend-only deploy runbook (no frontend, no static content)
- [x] 5.4 Commit, PR referencing SSE issue, CI scans pass
- [x] 5.5 Merge and tag v0.29.2
- [x] 5.6 Deploy to Oracle VM following v0.29.2 runbook: backend-only restart (`docker compose ... up -d backend`)
- [x] 5.7 Monitor production logs for 5 minutes after deploy — verify zero AsyncContext/Security errors
- [x] 5.8 Verify "Reconnecting" banner does NOT appear in incognito browser session
- [x] 5.9 Update test counts in README.md and FOR-DEVELOPERS.md if new tests change totals
