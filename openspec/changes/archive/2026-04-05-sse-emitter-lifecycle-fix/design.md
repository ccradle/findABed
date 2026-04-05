## Context

`NotificationService.java` manages SSE emitters in a `ConcurrentHashMap<UUID, EmitterEntry>`. A `@Scheduled` heartbeat sends every 20 seconds. When a send fails (IOException), the code calls `completeWithError()` inside the `forEach()` lambda, which triggers the `onError` callback that removes the entry from the same map — a race condition. Spring Security then re-challenges the async dispatch against an already-committed response.

Spring Boot 4.0.5 ships Spring Framework 7.0.6, which includes the AsyncListener#onError synchronization fix (spring-framework#34192). But our application code still has the map-mutation-during-iteration race and the missing async dispatch security config.

## Goals / Non-Goals

**Goals:**
- Eliminate cascading SSE errors on the live site
- SSE connections survive client disconnects gracefully without error cascades
- Spring Security does not re-challenge on async dispatch for SSE
- Async timeout configured explicitly (not relying on 30s default)
- Diagnostic logging sufficient to troubleshoot future SSE issues

**Non-Goals:**
- Changing SseEmitter(-1L) to a finite timeout (future consideration)
- Refactoring SSE to WebSocket (unnecessary — SSE is the right pattern)
- Changing the heartbeat interval (20s is correct for Cloudflare's 100s timeout)

## Decisions

### D1: Remove from map BEFORE completeWithError

In `sendHeartbeat()` and `sendEvent()`, remove the emitter from the map first, then call `completeWithError()` in a try-catch. This prevents the `onError` callback from trying to remove an entry that's already being processed.

**Why:** The race is: `completeWithError()` → `onError` callback → `cleanup.run()` → `emitters.remove(userId)` — all while `forEach()` is still iterating. By removing first, the `onError` callback's `cleanup.run()` becomes a no-op (entry already gone).

**Note on ConcurrentHashMap.forEach:** Removal during `forEach` is safe per the CHM contract (weakly consistent iterators). The issue is not `ConcurrentModificationException` — it's `completeWithError()` triggering Spring's async error dispatch pipeline, which re-enters the security filter chain.

### D2: DispatcherType.ASYNC permitAll for SSE endpoint

Add `.dispatcherTypeMatchers(DispatcherType.ASYNC).permitAll()` to SecurityConfig. Note: Spring Security's API does not support chaining `.requestMatchers()` after `.dispatcherTypeMatchers()`, so this applies site-wide. This is safe because only the SSE endpoint uses async dispatch — all other endpoints are synchronous. The initial SSE connection is authenticated; the async dispatch is the error/cleanup path only.

**Why:** When an SSE emitter errors, Tomcat performs an async dispatch. Spring Security re-executes the filter chain on this dispatch, finds no security context, and tries to send a 401 — but the response is already committed. Per spring-security#16266, the fix is to allow async dispatches through without re-authentication.

**Security impact:** None — the initial SSE connection IS authenticated. The async dispatch is just the cleanup/error path. Marcus Webb confirms: this does not create a security gap.

### D3: Explicit async timeout of 600 seconds

Set `server.servlet.async.request-timeout: 600000` (10 minutes) in application.yml.

**Why:** The default is 30 seconds — too close to the 20-second heartbeat interval. If a heartbeat is slightly delayed (GC pause, virtual thread scheduling), the async request can timeout before the next heartbeat, killing the connection silently. 600 seconds gives ample margin; clients reconnect naturally via Last-Event-ID if the server restarts.

### D4: WARN-level diagnostic logging on emitter failures

Add structured WARN logs when emitters fail, including userId, error class, and message. Currently only DEBUG level, which is invisible in production.

**Why:** The current DEBUG-level logs meant we couldn't see these failures in production logs until we explicitly searched. WARN ensures they appear in standard log monitoring (Grafana/Loki).

### D5: Idempotent onError callback

Make the `onError`, `onCompletion`, and `onTimeout` callbacks idempotent by checking if the entry still exists in the map before running cleanup. This prevents double-removal when the heartbeat has already removed the entry.

**Why:** Defense in depth. If `sendHeartbeat()` removes the entry (D1) and then `onError` fires asynchronously, the callback should be a no-op, not a second removal attempt.

## Risks / Trade-offs

**[Risk] DispatcherType.ASYNC permitAll is too broad** → Mitigation: Scoped to `/api/v1/notifications/**` path only, not site-wide. Only the SSE endpoint uses async dispatch.

**[Risk] 600s async timeout is too long** → Mitigation: The heartbeat (20s) detects dead connections within one cycle. The 600s timeout is a safety net, not the primary cleanup mechanism. If it fires, the connection was truly abandoned.

**[Risk] Changing error handling may mask real errors** → Mitigation: D4 adds WARN-level logging. We're not swallowing errors — we're handling them gracefully instead of cascading.
