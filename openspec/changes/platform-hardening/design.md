## Context

API keys can be created but not revoked or rotated. Webhook subscriptions can be created but not deleted, paused, or tested. The Gatling AvailabilityUpdate test shows 2.05% KO from advisory lock contention (SLO: <1%). SSE notifications have no backpressure protection for slow clients. Webhook deliveries are fire-and-forget with no visibility into failures.

## Goals / Non-Goals

**Goals:**
- Complete API key lifecycle (revoke, rotate with grace period)
- Rate limit API key authentication to prevent brute-force attacks
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

POST /api/v1/api-keys/{id}/rotate generates a new key. The old key hash is preserved in `old_key_hash` with `old_key_expires_at` set to +24h. Both current and old keys authenticate during overlap. `validate()` checks current key first, then old key with SQL-level expiry filter (`old_key_expires_at > NOW()`). After the grace period, a @Scheduled cleanup nulls the old hash. Frontend shows both keys during grace period with countdown.

### D1a: API key security decisions (principal review, 2026-04-07)

1. **Key entropy: 256 bits (32 bytes)** — industry standard. 128 bits was used initially but doubled at no cost. Matches Stripe/GitHub.
2. **SHA-256 for hashing** — correct for high-entropy machine-generated keys. bcrypt/argon2 would be a DoS vector. Hash comparison happens in PostgreSQL (btree index lookup), not in Java — no timing attack surface.
3. **Revoke clears grace period** — `deactivate()` nulls `oldKeyHash` and `oldKeyExpiresAt` to prevent any authentication path for a revoked key.
4. **Grace period expiry checked in SQL** — `findByOldKeyHashWithinGracePeriod` includes `AND old_key_expires_at > NOW()` in the query, avoiding unnecessary database round-trips for expired old keys.
5. **@Scheduled cleanup is supplemental, not the security boundary** — `validate()` always checks expiry inline. Cleanup is hygiene for database size.
6. **ShedLock deferred** — cleanup is idempotent, acceptable for single-instance `lite` profile. Comment added noting ShedLock needed for multi-instance.
7. **Timing attack note** — all hash comparison happens database-side via btree index. If future caching moves comparison to Java, must use `MessageDigest.isEqual()` (constant-time). Documented for future.

### D1b: API key brute-force rate limiting

**Two-layer defense** matching the existing auth rate limiting pattern:

**Layer 1 — Nginx (edge):** Add `limit_req` zone for API-key-bearing requests. New zone `api_key_auth` in `00-rate-limit.conf`: 20 requests/minute per IP with burst=10. This stops volumetric brute-force before it reaches the JVM. Applied to all `/api/v1/` paths that accept `X-API-Key` header.

**Layer 2 — Bucket4j (application):** Separate rate limit filter for failed API key attempts. Track per-IP, 5 failed attempts per minute. On exceeding: return 429 with `Retry-After` header and `{"error":"rate_limited"}` body. Consistent with existing Bucket4j patterns (login: 10/15min, password: 5/15min).

**Implementation approach:** The `ApiKeyAuthenticationFilter` already processes every request with an `X-API-Key` header. On validation failure (key not found or inactive), it currently silently proceeds to the next filter. Change: on failed validation, increment a Bucket4j counter. If counter exhausted, return 429 directly from the filter before the request reaches the controller. Log at WARN level (consistent with REQ-RL-5).

**Why both layers:**
- Nginx layer: protects against volumetric attacks that could overwhelm JVM memory (Bucket4j stores counters in-memory)
- Bucket4j layer: fine-grained per-IP tracking with business logic (distinguishes valid vs. invalid keys, logs failures)

**What about rate limiting valid API key requests?** Deferred — valid key usage limits (per-key quotas) are a future enhancement. The immediate concern is brute-force protection on the authentication path.

### D2: Webhook subscription pause/resume

New `active BOOLEAN DEFAULT true` on `subscription` table. PATCH /api/v1/subscriptions/{id}/status with `{active: true|false}`. WebhookDeliveryService checks `active` flag before delivery. Paused subscriptions remain visible in the list with "Paused" badge. Events during pause are dropped (not queued) — documented in UI tooltip.

### D3: Webhook test event

POST /api/v1/subscriptions/{id}/test with `{eventType}`. Server generates a synthetic DomainEvent with test flag and delivers it to the subscription endpoint. Response includes the delivery result (status code, response time). Frontend shows the result inline after clicking "Send Test." HTTP client uses 10s connect timeout and 30s read timeout — a hanging endpoint will not block the delivery thread indefinitely.

### D4: Webhook delivery log

New `webhook_delivery_log` table: `id UUID`, `subscription_id UUID`, `event_type VARCHAR`, `status_code INTEGER`, `response_time_ms INTEGER`, `attempted_at TIMESTAMPTZ`, `attempt_number INTEGER`, `response_body TEXT` (truncated to 1KB). WebhookDeliveryService logs each attempt. Retained for 14 days (scheduled cleanup). Frontend shows last 20 deliveries per subscription in an expandable panel.

### D5: Auto-disable on consecutive failures

After 5 consecutive delivery failures to the same subscription, set `active=false` and publish a notification event to the tenant's admin users. The admin can re-enable after fixing the endpoint. This prevents resource waste on dead endpoints.

### D6: Server-side retry with Spring Retry

Add `spring-retry` dependency. `@Retryable` on `AvailabilityService.createSnapshot()` for `PessimisticLockingFailureException` and `CannotAcquireLockException`. Max 3 attempts, 50ms initial backoff, multiplier 2. The client never sees 409 — the server absorbs transient lock contention. Recovery method logs and returns 409 only if all retries exhausted.

### D7: SSE bounded event queue — PHASED IMPLEMENTATION

**PHASE 2 — implement AFTER all other platform-hardening tasks are verified green.**

The SSE send path has caused four production bugs across three versions (v0.28.0 SW interception, v0.28.2 nginx buffering, v0.29.2 cascading emitter errors). Every bug was caused by unexpected interactions between concurrent access, Spring callback lifecycle, or proxy buffering. This change modifies that exact code path and must be isolated from the rest of the hardening work.

Instead of calling `emitter.send()` synchronously per event, queue events into a bounded `ArrayDeque<SseEvent>` per client (max 10). A background sender drains the queue. If the queue is full when a new event arrives, drop the oldest event. This prevents slow clients from blocking the event fan-out loop.

### D7a: Heartbeat vs. queue interaction

Heartbeats MUST go through the bounded queue, not bypass it. Two concurrent write paths to the same emitter (heartbeat direct + queue sender thread) would reintroduce the race condition fixed in v0.29.2 (remove-before-completeWithError pattern depends on single-threaded access).

Consequences:
- The `@Scheduled sendHeartbeat()` method queues a heartbeat event rather than calling `emitter.send()` directly
- The background sender thread is the ONLY writer to `emitter.send()`
- If a slow client's queue fills with heartbeats, real events may be dropped — mitigated by giving heartbeats lower priority (drop heartbeats before real events when queue is full)

### D7b: Background sender thread lifecycle

Each emitter gets one sender thread (virtual thread, not platform thread). The thread:
- Blocks on a `LinkedBlockingQueue` (not `ArrayDeque` — needs blocking take)
- On `IOException` during send: removes emitter from registry FIRST, then completes with error, then exits. This preserves the v0.29.2 remove-before-complete pattern.
- On emitter removal (cleanup/shutdown): the queue is poisoned with a sentinel value, sender thread exits cleanly
- Thread naming: `sse-sender-{userId}` for diagnostics

### D7c: Regression safety net

Before any SSE changes:
1. Run full `SseNotificationIntegrationTest` + `SseStabilityTest` — save baseline output
2. Run `sse-cache-regression` Playwright tests through nginx — save baseline
3. Verify `sse.connections.active` Grafana gauge is flat (not sawtooth) on live site

After SSE changes:
4. Re-run all SSE backend tests — compare to baseline
5. Re-run Playwright SSE tests through nginx — compare to baseline
6. Deploy to local nginx, connect 3 users, wait 5 minutes — verify gauge is flat
7. Gatling SSE load test: 200 connections, 10 deliberately slow — verify fast clients unaffected

### D8: ACCESS_CODE_USED audit event fix (#58)

The access code authentication flow authenticates without an existing user context — the "actor" IS the target user. The audit event publisher must set `actor_user_id = target_user_id` for this self-authentication flow. The INSERT currently fails with a NOT NULL constraint violation on `audit_events.actor_user_id`, meaning access code logins are silently not audited — a gap Marcus Okafor would discover when asking "what happened the night of X."

### D9: My Reservations clickable shelter names (#64)

Shelter names in the My Reservations panel are rendered as static text. They should be clickable links that navigate to the shelter detail view (expanding the shelter card or opening the detail modal). This completes Darius's core workflow: search → hold → transport (needs directions from the reservation). The link should include the shelter ID to scroll/expand the correct card. The hold countdown timer must remain visible — the link must not replace or obscure it.

## Risks / Trade-offs

- **Grace period key rotation**: two valid keys simultaneously increases attack surface slightly. Mitigated by short default window (24h) and audit logging of key usage.
- **Dropped events during webhook pause**: admins must understand events are lost, not queued. Documented in UI and API response.
- **Spring Retry masking real errors**: retry absorbs transient lock contention but could mask persistent issues. Mitigated by logging each retry attempt and returning 409 if all retries exhausted.
- **SSE queue drop-oldest**: slow clients may miss events. Mitigated by client-side REST catch-up on reconnection (already implemented in useNotifications hook).
- **SSE regression risk (HIGHEST)**: The SSE send path caused 4 production bugs in 3 versions. D7 introduces a new concurrent writer (background thread) to this path. Mitigated by: phased implementation (Phase 2, after all other tasks green), comprehensive regression baseline before changes, thread-per-emitter with single-writer guarantee (only the sender thread calls `emitter.send()`), preserving the v0.29.2 remove-before-complete pattern.
- **@Retryable + @Transactional interaction**: `@Retryable` on `AvailabilityService.createSnapshot()` must execute OUTSIDE the transaction boundary. If `@Retryable` wraps a `@Transactional` method, the second retry attempt inherits a rolled-back transaction context. Mitigated by: placing `@Retryable` on the controller or a non-transactional service wrapper, integration test verifying only ONE domain event published per successful retry sequence.
- **@Scheduled cleanup tasks disabled in tests**: v0.18.1 gates scheduling via `fabt.scheduling.enabled=false` in test profile. New @Scheduled tasks (API key expiry cleanup T-4, delivery log cleanup T-14) won't run in tests. Test cleanup logic via direct service method calls, not by waiting for the scheduler. @Retryable (T-17) is separate from scheduling and works regardless.
