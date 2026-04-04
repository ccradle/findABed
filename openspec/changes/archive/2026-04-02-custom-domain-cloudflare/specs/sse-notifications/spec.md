## MODIFIED Requirements

### Requirement: SseEmitter infinite timeout with heartbeat-based cleanup

The `NotificationService` SHALL create `SseEmitter(-1L)` (no server-side timeout). Dead connections SHALL be detected by heartbeat send failures. The SSE response SHALL include the `X-Accel-Buffering: no` header to prevent Cloudflare and upstream nginx proxies from buffering the event stream.

**Acceptance criteria:**
- No `AsyncRequestTimeoutException` in logs during normal operation
- SSE connections remain open indefinitely when client is connected and healthy
- When a client silently disconnects (network loss), the emitter is removed from the registry within 20 seconds (one heartbeat cycle)
- Backend integration test verifies connection stays alive for 60+ seconds without timeout
- SSE response includes `X-Accel-Buffering: no` header

#### Scenario: SSE response includes anti-buffering header
- **WHEN** a client establishes an SSE connection to `/api/v1/notifications/stream`
- **THEN** the response includes the header `X-Accel-Buffering: no`

#### Scenario: SSE works through Cloudflare proxy
- **WHEN** a client connects to SSE through the Cloudflare CDN proxy
- **THEN** events are delivered in real-time without buffering delays
- **AND** the connection is not terminated at the 100-second Cloudflare idle timeout (because heartbeats fire every 20 seconds)
