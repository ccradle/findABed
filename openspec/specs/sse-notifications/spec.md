## MODIFIED Requirements

### Requirement: SseEmitter infinite timeout with heartbeat-based cleanup

The `NotificationService` SHALL create `SseEmitter(-1L)` (no server-side timeout). Dead connections SHALL be detected by heartbeat send failures.

**Acceptance criteria:**
- No `AsyncRequestTimeoutException` in logs during normal operation
- SSE connections remain open indefinitely when client is connected and healthy
- When a client silently disconnects (network loss), the emitter is removed from the registry within 20 seconds (one heartbeat cycle)
- Backend integration test verifies connection stays alive for 60+ seconds without timeout

### Requirement: 20-second heartbeat interval

The heartbeat `@Scheduled` task SHALL send SSE named events (`event: heartbeat`) with incrementing `id:` every 20 seconds (changed from 30-second comments).

**Acceptance criteria:**
- Heartbeat events sent at 20-second intervals to all registered emitters
- Heartbeats are named events (not SSE comments) so they advance `Last-Event-ID`
- Each heartbeat includes a monotonic `id:` field
- Failed heartbeat sends trigger immediate emitter cleanup (IOException → remove from registry)
- Individual slow sends (>5 seconds) treated as dead connections — emitter removed without blocking other clients
- Backend integration test receives at least 2 heartbeats in a 45-second window

### Requirement: Initial connection event with retry field

On new SSE connection, the server SHALL immediately send an event containing `retry: 5000`, a monotonic event `id:`, event type `connected`, and data containing `{"heartbeatInterval": 20000}`.

**Acceptance criteria:**
- Client receives the `connected` event within 1 second of establishing the stream
- The `retry:` field is set to 5000 (milliseconds)
- Every subsequent event includes a monotonic `id:` field
- Backend integration test verifies initial event format

### Requirement: Last-Event-ID replay from bounded buffer

The server SHALL maintain a bounded circular buffer of recent events (max 100 events, max 5 minutes). When a client reconnects with `Last-Event-ID` header, the server SHALL replay events after that ID. If the ID is not in the buffer (too stale), the server SHALL send a `refresh` event type.

**Acceptance criteria:**
- Reconnecting client with valid `Last-Event-ID` receives only missed events (not full history)
- Replayed events are filtered by the reconnecting user's tenant and role permissions (no cross-tenant leakage)
- Reconnecting client with stale/unknown `Last-Event-ID` receives a `refresh` event
- Buffer evicts entries older than 5 minutes or when size exceeds 100
- Buffer entries include tenant ID and DV access flag for per-user filtering
- Backend integration test verifies replay with valid ID, refresh with stale ID, and tenant isolation

### Requirement: Graceful shutdown closes all emitters

On application shutdown (`@PreDestroy`), the service SHALL call `complete()` on all registered emitters to trigger immediate client reconnection to a healthy node.

**Acceptance criteria:**
- All emitters completed during shutdown
- Clients reconnect within `retry` interval (5 seconds) after server restart

### Requirement: SSE dv-referral.expired event
The `NotificationService` SHALL handle `dv-referral.expired` domain events and push them to connected coordinators who are assigned to the affected shelters.

#### Scenario: Expired tokens pushed to coordinator via SSE
- **WHEN** `expireTokens()` publishes a `dv-referral.expired` event with token IDs
- **THEN** the `NotificationService` SHALL send an SSE event with type `dv-referral.expired` to all connected COORDINATOR users for the matching tenant
- **AND** the event data SHALL include the list of expired token IDs

#### Scenario: Expired event replayed on reconnection
- **WHEN** a coordinator reconnects with a `Last-Event-ID` that precedes a `dv-referral.expired` event still in the buffer
- **THEN** the expired event SHALL be replayed to the reconnecting client

#### Scenario: Expired event filtered by tenant
- **WHEN** a `dv-referral.expired` event is published for tenant A
- **THEN** coordinators connected for tenant B SHALL NOT receive the event

### Requirement: SseTokenFilter deprecation warning

The `SseTokenFilter` SHALL log a deprecation warning when query-param token auth is used for SSE, directing clients to use the `Authorization` header instead.

**Acceptance criteria:**
- Warning logged at WARN level: "SSE auth via query param is deprecated, use Authorization header"
- Filter continues to work (backward compatible)
- No query-param tokens in new client code
