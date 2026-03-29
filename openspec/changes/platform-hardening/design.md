## Context

API keys can be created but not revoked or rotated. Webhook subscriptions can be created but not deleted, paused, or tested. The Gatling AvailabilityUpdate test shows 2.05% KO from advisory lock contention (SLO: <1%). SSE notifications have no backpressure protection for slow clients. Webhook deliveries are fire-and-forget with no visibility into failures.

## Goals / Non-Goals

**Goals:**
- Complete API key lifecycle (revoke, rotate with grace period)
- Complete webhook subscription lifecycle (delete, pause, test, delivery log)
- Eliminate 409 Conflict from client perspective via server-side retry
- Protect SSE from slow-client accumulation
- Provide webhook delivery visibility to admins

**Non-Goals:**
- Scoped API key permissions (future — currently all keys have the assigned role's full access)
- API key expiration enforcement (future — currently no TTL)
- Webhook retry configuration per subscription (fixed policy for now)
- SSE horizontal scaling via Redis pub/sub (future multi-instance deployment)

## Decisions

### D1: API key rotation with grace period

POST /api/v1/api-keys/{id}/rotate generates a new key. The old key remains valid for a configurable grace period (default 24 hours, tenant-configurable). Both keys authenticate successfully during overlap. After the grace period, the old key is automatically invalidated by a @Scheduled cleanup task. Frontend shows both keys during grace period with countdown.

### D2: Webhook subscription pause/resume

New `active BOOLEAN DEFAULT true` on `subscription` table. PATCH /api/v1/subscriptions/{id}/status with `{active: true|false}`. WebhookDeliveryService checks `active` flag before delivery. Paused subscriptions remain visible in the list with "Paused" badge. Events during pause are dropped (not queued) — documented in UI tooltip.

### D3: Webhook test event

POST /api/v1/subscriptions/{id}/test with `{eventType}`. Server generates a synthetic DomainEvent with test flag and delivers it to the subscription endpoint. Response includes the delivery result (status code, response time). Frontend shows the result inline after clicking "Send Test."

### D4: Webhook delivery log

New `webhook_delivery_log` table: `id UUID`, `subscription_id UUID`, `event_type VARCHAR`, `status_code INTEGER`, `response_time_ms INTEGER`, `attempted_at TIMESTAMPTZ`, `attempt_number INTEGER`, `response_body TEXT` (truncated to 1KB). WebhookDeliveryService logs each attempt. Retained for 14 days (scheduled cleanup). Frontend shows last 20 deliveries per subscription in an expandable panel.

### D5: Auto-disable on consecutive failures

After 5 consecutive delivery failures to the same subscription, set `active=false` and publish a notification event to the tenant's admin users. The admin can re-enable after fixing the endpoint. This prevents resource waste on dead endpoints.

### D6: Server-side retry with Spring Retry

Add `spring-retry` dependency. `@Retryable` on `AvailabilityService.createSnapshot()` for `PessimisticLockingFailureException` and `CannotAcquireLockException`. Max 3 attempts, 50ms initial backoff, multiplier 2. The client never sees 409 — the server absorbs transient lock contention. Recovery method logs and returns 409 only if all retries exhausted.

### D7: SSE bounded event queue

Instead of calling `emitter.send()` synchronously per event, queue events into a bounded `ArrayDeque<SseEvent>` per client (max 10). A background sender drains the queue. If the queue is full when a new event arrives, drop the oldest event. This prevents slow clients from blocking the event fan-out loop. The sender thread detects dead clients via IOException on send and cleans up.

## Risks / Trade-offs

- **Grace period key rotation**: two valid keys simultaneously increases attack surface slightly. Mitigated by short default window (24h) and audit logging of key usage.
- **Dropped events during webhook pause**: admins must understand events are lost, not queued. Documented in UI and API response.
- **Spring Retry masking real errors**: retry absorbs transient lock contention but could mask persistent issues. Mitigated by logging each retry attempt and returning 409 if all retries exhausted.
- **SSE queue drop-oldest**: slow clients may miss events. Mitigated by client-side REST catch-up on reconnection (already implemented in useNotifications hook).
- **@Scheduled cleanup tasks disabled in tests**: v0.18.1 gates scheduling via `fabt.scheduling.enabled=false` in test profile. New @Scheduled tasks (API key expiry cleanup T-4, delivery log cleanup T-14) won't run in tests. Test cleanup logic via direct service method calls, not by waiting for the scheduler. @Retryable (T-17) is separate from scheduling and works regardless.
