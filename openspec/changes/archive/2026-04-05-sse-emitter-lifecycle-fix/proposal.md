## Why

The live site shows a persistent "Reconnecting to live updates..." banner. Backend logs reveal a cascading SSE failure: `IllegalStateException` on AsyncContext, `response already committed` from Spring Security, and null request in error page rendering. Root cause: `sendHeartbeat()` calls `completeWithError()` inside a `forEach()` iteration, triggering the `onError` callback which modifies the emitter map during iteration. Spring Security re-challenges on async dispatch against an already-committed SSE response. No async timeout is configured, defaulting to 30s — dangerously close to the 20s heartbeat interval.

This is a production reliability issue affecting all users. Sandra Kim (coordinator) and Darius Webb (outreach worker) see the "Reconnecting" banner constantly, eroding trust in real-time bed updates.

## What Changes

### SSE Emitter Lifecycle Hardening
- Fix `sendHeartbeat()` race: remove emitter from map BEFORE calling `completeWithError()`, wrap in try-catch
- Fix all event broadcast methods (`notifyReferralResponse`, `notifyReferralRequest`, `notifyReferralExpired`, `notifyAvailabilityUpdate`): same forEach + completeWithError race pattern
- Add `DispatcherType.ASYNC` permitAll for SSE endpoint in SecurityConfig to prevent Spring Security re-challenge on async dispatch
- Configure `server.servlet.async.request-timeout: 600000` (10 min) in application.yml
- Add WARN-level diagnostic logging on emitter failures (userId, error type, emitter state)

## Capabilities

### Modified Capabilities
- `sse-notifications`: Fix emitter lifecycle race conditions in heartbeat and event broadcast, add async timeout config
- `security-headers`: Add DispatcherType.ASYNC permitAll for SSE endpoint

## Impact

**Backend (finding-a-bed-tonight/backend):**
- `NotificationService.java` — heartbeat and event broadcast error handling refactored
- `SecurityConfig.java` — add async dispatch permitAll for SSE endpoint
- `application.yml` — add async timeout configuration
- `SseNotificationIntegrationTest.java` — add emitter error recovery test
- `DvReferralIntegrationTest.java` — verify SSE still works after fixes

**No frontend changes.** The reconnecting banner behavior is correct — it shows when the SSE connection drops. The fix is making the connection stop dropping.
