## MODIFIED Requirements

### Requirement: SseEmitter infinite timeout with heartbeat-based cleanup

The `NotificationService` SHALL create `SseEmitter(-1L)` (no server-side timeout). Dead connections SHALL be detected by heartbeat send failures. When a heartbeat send fails, the emitter SHALL be removed from the registry BEFORE calling `completeWithError()` to prevent race conditions with the `onError` callback.

#### Scenario: Heartbeat failure removes emitter safely
- **WHEN** a heartbeat send fails with IOException
- **THEN** the emitter SHALL be removed from the registry first
- **AND** `completeWithError()` SHALL be called in a try-catch (may be a no-op if already completed)
- **AND** no cascading `IllegalStateException` on AsyncContext SHALL occur

#### Scenario: Event broadcast failure removes emitter safely
- **WHEN** an SSE event send fails with IOException during broadcast (referral, availability, expiration)
- **THEN** the emitter SHALL be removed from the registry first
- **AND** `completeWithError()` SHALL be called in a try-catch
- **AND** no other emitters in the broadcast loop SHALL be affected

#### Scenario: onError callback is idempotent
- **WHEN** the `onError` callback fires for an emitter that has already been removed from the registry
- **THEN** the callback SHALL be a no-op (no exception, no double-removal)

#### Scenario: onCompletion callback is idempotent
- **WHEN** the `onCompletion` callback fires for an emitter that has already been removed
- **THEN** the callback SHALL be a no-op

#### Scenario: onTimeout callback is idempotent
- **WHEN** the async request timeout fires for an emitter
- **THEN** the emitter SHALL be removed from the registry cleanly
- **AND** no cascading exceptions SHALL occur

#### Scenario: Emitter failure logged at WARN level
- **WHEN** an emitter send fails (heartbeat or event)
- **THEN** a WARN-level log SHALL be emitted with userId and error class/message
- **AND** the log SHALL be structured JSON (consistent with existing log format)

## ADDED Requirements

### Requirement: Async request timeout configuration
The application SHALL configure `server.servlet.async.request-timeout` to 600000ms (10 minutes) to prevent premature SSE connection termination.

#### Scenario: SSE connection survives beyond 30 seconds
- **WHEN** an SSE connection is idle between heartbeats (up to 20 seconds)
- **THEN** the async request SHALL NOT timeout (600s timeout >> 20s heartbeat interval)

#### Scenario: Truly abandoned connections eventually timeout
- **WHEN** an SSE connection receives no heartbeat response for 600 seconds
- **THEN** the async request SHALL timeout and the emitter SHALL be cleaned up
