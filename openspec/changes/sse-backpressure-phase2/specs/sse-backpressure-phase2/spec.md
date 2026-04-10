## ADDED Requirements

### Requirement: Single-writer per SSE emitter

The system SHALL guarantee that exactly one thread writes to any given `SseEmitter` instance at a time. The single-writer guarantee SHALL be enforced by encapsulation, not convention.

#### Scenario: Wrapper exposes only enqueue, never send
- **WHEN** a developer needs to deliver an event to an SSE client
- **THEN** the only public API SHALL be `NotificationEmitter.enqueue(OutboundEvent)`
- **AND** there SHALL NOT be a public method that forwards to `delegate.send()`

#### Scenario: Sender thread is the only writer
- **WHEN** an `OutboundEvent` is enqueued
- **THEN** the per-emitter sender virtual thread SHALL drain it from the queue and call `delegate.send()`
- **AND** no other thread SHALL call `delegate.send()` for that emitter

#### Scenario: IOException during send is not propagated as completeWithError
- **WHEN** `delegate.send()` throws `IOException`
- **THEN** the sender thread SHALL log at DEBUG and exit cleanly
- **AND** the sender thread SHALL NOT call `delegate.completeWithError()`
- **AND** the servlet container's `onError` callback SHALL be relied upon for cleanup

### Requirement: Bounded per-emitter event queue

Each `NotificationEmitter` SHALL hold a bounded `LinkedBlockingQueue` of `OutboundEvent`. The queue capacity SHALL be configurable.

#### Scenario: Queue capacity defaults to 32
- **WHEN** the application starts without overriding `fabt.sse.queue-capacity`
- **THEN** every `NotificationEmitter` SHALL be constructed with a queue of capacity 32

#### Scenario: Queue capacity is configurable
- **WHEN** `fabt.sse.queue-capacity` is set to `N`
- **THEN** every `NotificationEmitter` SHALL be constructed with a queue of capacity `N`

#### Scenario: Slow client cannot consume unbounded memory
- **WHEN** a client reads events slower than they are produced
- **THEN** the per-emitter queue SHALL not exceed its configured capacity
- **AND** the slow client SHALL not affect memory consumption of other emitters

### Requirement: Priority-aware enqueue with critical-event protection

The enqueue operation SHALL distinguish CRITICAL from NORMAL events. CRITICAL events SHALL never be silently dropped.

#### Scenario: NORMAL event coalesces by (eventType, resourceId)
- **WHEN** a NORMAL `OutboundEvent` is enqueued
- **AND** an existing entry in the queue has the same `coalesceKey`
- **THEN** the existing entry SHALL be replaced with the new event (latest-wins)
- **AND** the metric `sse.queue.drops{reason=coalesced}` SHALL be incremented

#### Scenario: NORMAL event drops oldest NORMAL on overflow
- **WHEN** a NORMAL `OutboundEvent` is enqueued
- **AND** the queue is full
- **AND** no entry shares the new event's `coalesceKey`
- **THEN** the oldest NORMAL entry in the queue SHALL be removed
- **AND** the new NORMAL event SHALL be appended
- **AND** the metric `sse.queue.drops{reason=normal_dropped}` SHALL be incremented

#### Scenario: CRITICAL event evicts oldest NORMAL on overflow
- **WHEN** a CRITICAL `OutboundEvent` is enqueued
- **AND** the queue is full
- **AND** at least one entry in the queue is NORMAL
- **THEN** the oldest NORMAL entry SHALL be evicted to make room
- **AND** the CRITICAL event SHALL be appended
- **AND** the metric `sse.queue.drops{reason=critical_evicted}` SHALL be incremented

#### Scenario: CRITICAL event disconnects client when queue is full of CRITICAL events
- **WHEN** a CRITICAL `OutboundEvent` is enqueued
- **AND** the queue is full
- **AND** every entry in the queue is also CRITICAL
- **THEN** a poison pill SHALL be enqueued
- **AND** the sender thread SHALL drain in-flight events and exit
- **AND** `delegate.complete()` SHALL be called
- **AND** the metric `sse.disconnect.cause{reason=slow_client}` SHALL be incremented
- **AND** the CRITICAL event SHALL remain available via the persistent notification table for REST catch-up

### Requirement: Heartbeats routed through the per-emitter queue

Heartbeats SHALL be enqueued through the same path as data events. Heartbeats SHALL NOT bypass the per-emitter queue.

#### Scenario: Heartbeat is enqueued
- **WHEN** the heartbeat scheduler fires (every 20 seconds)
- **THEN** a HEARTBEAT `OutboundEvent` SHALL be enqueued to every active emitter
- **AND** the heartbeat payload SHALL be a comment line per the WHATWG SSE spec

#### Scenario: Failed heartbeat enqueue triggers disconnect
- **WHEN** a heartbeat enqueue fails because the queue is full of CRITICAL events
- **THEN** the emitter SHALL be disconnected via the same flow as a CRITICAL queue overflow

### Requirement: Per-user concurrent SSE connection cap

The system SHALL enforce a maximum number of concurrent SSE connections per user. The cap SHALL be configurable. On overflow, the oldest connection SHALL be FIFO-evicted.

#### Scenario: Cap defaults to 5
- **WHEN** the application starts without overriding `fabt.sse.max-connections-per-user`
- **THEN** the cap SHALL be 5

#### Scenario: New connection appended below cap
- **WHEN** a user has fewer than the cap of active SSE connections
- **AND** the user opens a new SSE connection
- **THEN** the new emitter SHALL be appended to the user's emitter list

#### Scenario: FIFO eviction at cap
- **WHEN** a user has exactly the cap of active SSE connections
- **AND** the user opens a new SSE connection
- **THEN** the oldest emitter in the user's list SHALL be removed and `complete()`d
- **AND** the new emitter SHALL be appended
- **AND** an INFO log SHALL record the evicted emitter's userId, source IP, and User-Agent
- **AND** the metric `sse.disconnect.cause{reason=cap_evicted}` SHALL be incremented

### Requirement: Broadcast publisher concurrency cap

The broadcast fan-out method SHALL be bounded by `@ConcurrencyLimit` with the REJECT policy. The limit SHALL be configurable.

#### Scenario: Concurrency limit defaults to 10
- **WHEN** the application starts without overriding `fabt.sse.broadcast-concurrency-limit`
- **THEN** the broadcast fan-out method SHALL accept at most 10 concurrent invocations

#### Scenario: Rejected broadcast does not propagate exception
- **WHEN** the broadcast fan-out is invoked while at the concurrency limit
- **THEN** Spring SHALL throw `InvocationRejectedException`
- **AND** the wrapping aspect SHALL log at WARN with `eventType`, `tenantId`, `recipientCount`
- **AND** the metric `sse.broadcast.rejected{eventType}` SHALL be incremented
- **AND** the producer thread SHALL continue normally (no exception propagation)

#### Scenario: Rejected CRITICAL broadcast still reaches users via persistent notifications
- **WHEN** a CRITICAL broadcast is rejected due to the concurrency limit
- **THEN** the persistent notification row SHALL still exist in the database
- **AND** the user SHALL see the CRITICAL banner on next page mount via REST catch-up

### Requirement: Forced periodic reconnect with jitter

Each `NotificationEmitter` SHALL be force-reconnected after a configured interval with random jitter. The interval and jitter window SHALL be configurable.

#### Scenario: Force-reconnect interval defaults to 25 minutes
- **WHEN** the application starts without overriding `fabt.sse.force-reconnect-minutes`
- **THEN** every emitter SHALL schedule a `forceReconnect()` task at 25 minutes ± 3 minutes jitter

#### Scenario: Force reconnect drains in-flight events
- **WHEN** the force-reconnect task fires
- **THEN** a poison pill SHALL be enqueued
- **AND** the sender thread SHALL drain remaining events from the queue
- **AND** `delegate.complete()` SHALL be called
- **AND** the metric `sse.disconnect.cause{reason=forced_reconnect}` SHALL be incremented

#### Scenario: Client reconnects via Last-Event-ID after forced reconnect
- **WHEN** an emitter is force-reconnected
- **THEN** the client's `EventSource` SHALL automatically reconnect with the `Last-Event-ID` header
- **AND** the new emitter SHALL replay any events missed during the reconnect window

### Requirement: Graceful shutdown deadline

`@PreDestroy` SHALL wait at most a configurable deadline for all sender threads to drain. After the deadline, sender threads SHALL be force-completed.

#### Scenario: Shutdown deadline defaults to 5 seconds
- **WHEN** the application receives `@PreDestroy`
- **AND** `fabt.sse.shutdown-deadline-seconds` is not overridden
- **THEN** the system SHALL wait at most 5 seconds for all sender threads to drain

#### Scenario: Clean shutdown when senders drain in time
- **WHEN** all sender threads drain their queues and exit within the deadline
- **THEN** the shutdown SHALL complete normally
- **AND** an INFO log SHALL record `cleanCount=N`, `forcedCount=0`, `elapsedMs=...`

#### Scenario: Forced shutdown when a sender is stuck
- **WHEN** at least one sender thread is still running after the deadline
- **THEN** the system SHALL call `forceComplete()` on the remaining emitters
- **AND** a WARN log SHALL record `cleanCount=...`, `forcedCount=N`, `elapsedMs >= deadline`
- **AND** a JFR `SseShutdownEvent` SHALL be emitted

### Requirement: SSE transport feature flag

The system SHALL support a feature flag `fabt.sse.transport=sse|polling`. When set to `polling`, the SSE stream endpoint SHALL return 503 with a Retry-After header.

#### Scenario: Default is sse
- **WHEN** `fabt.sse.transport` is not set
- **THEN** the value SHALL default to `sse`
- **AND** the `/api/v1/notifications/stream` endpoint SHALL behave normally

#### Scenario: Polling mode disables SSE stream
- **WHEN** `fabt.sse.transport=polling`
- **AND** a client requests `GET /api/v1/notifications/stream`
- **THEN** the response SHALL be 503 Service Unavailable
- **AND** the response SHALL include `Retry-After: 30`
- **AND** the response body SHALL be `{"error":"sse_disabled","message":"Real-time notifications are disabled; polling fallback active."}`
- **AND** the REST endpoints (`GET /notifications`, `GET /notifications/count`) SHALL continue to work

#### Scenario: Flag is read at request time
- **WHEN** an operator changes `fabt.sse.transport` from `sse` to `polling` without restarting the application
- **THEN** the next request to `/api/v1/notifications/stream` SHALL observe the new value

### Requirement: Slow-client isolation guarantee

A slow client SHALL not block event delivery to other clients.

#### Scenario: Fast clients meet SLO under slow-client load
- **WHEN** 200 SSE clients are connected to the same tenant
- **AND** 10 of those clients are deliberately throttled (consume events at 0.5 events/sec)
- **AND** a broadcast event is published
- **THEN** the 190 fast clients SHALL receive the event with p95 latency < 500ms
- **AND** the throttled clients SHALL eventually be disconnected via the queue-overflow path

### Requirement: Backpressure observability

The system SHALL emit Micrometer metrics for queue depth, queue drops, disconnect causes, and broadcast rejections.

#### Scenario: Queue drops are tagged by reason
- **WHEN** an event is dropped, coalesced, or evicted from a queue
- **THEN** the metric `sse.queue.drops` SHALL be incremented with one of `reason=critical_evicted|normal_dropped|coalesced`

#### Scenario: Disconnect causes are tagged by reason
- **WHEN** an emitter is disconnected by the system (not by the client)
- **THEN** the metric `sse.disconnect.cause` SHALL be incremented with one of `reason=slow_client|forced_reconnect|shutdown|cap_evicted`

#### Scenario: Broadcast rejections are tagged by event type
- **WHEN** the broadcast publisher's `@ConcurrencyLimit` rejects a fan-out
- **THEN** the metric `sse.broadcast.rejected` SHALL be incremented with the rejected event's `eventType` as a tag
