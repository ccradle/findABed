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

**Layer 1 — Nginx (edge):** `limit_req_zone api_edge` at 1 req/sec (60/min) per IP with burst=20. Applied to all `/api/` paths. Catches volumetric brute-force before JVM. Generous enough for normal authenticated use — the Bucket4j layer handles fine-grained control.

**Layer 2 — Bucket4j (application):** Programmatic Bucket4j in `ApiKeyAuthenticationFilter`. Single atomic `tryConsumeAndReturnRemaining(1)` per request bearing `X-API-Key`. Both valid and invalid keys consume tokens (5/min per IP). This is intentional — attacker cannot distinguish valid from invalid based on rate limit behavior.

**Implementation decisions (revised after principal + security review):**

1. **Single atomic call** — `tryConsumeAndReturnRemaining(1)` replaces the broken `tryConsume(0)` + `tryConsume(1)` pattern. `tryConsume(0)` always returns true (requests zero tokens). The atomic call provides consume result, remaining count, and retry-after timing in one CAS operation.

2. **Caffeine cache for buckets** — `Caffeine.newBuilder().maximumSize(10_000).expireAfterAccess(10 min)` replaces unbounded `ConcurrentHashMap`. Prevents memory DoS from IP rotation attacks (millions of unique IPs). Caffeine already a dependency (Bucket4j JCache backend).

3. **Client IP from `X-Real-IP`** — nginx sets this from `$remote_addr` (container nginx sees the upstream proxy IP). In production behind Cloudflare, the host nginx should set `X-Real-IP` from `CF-Connecting-IP` for true client IP. Falls back to `getRemoteAddr()` for local dev. Trust model: iptables restricts 80/443 to Cloudflare IPs, so direct header forgery is blocked at the network level.

4. **`X-RateLimit-*` response headers** on all API-key-bearing responses: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`. Values from `ConsumptionProbe`. Enables client self-throttling (Stripe/GitHub pattern).

5. **Both valid and invalid keys consume** — the rate limit is per-IP, not per-key. An IP gets 5 attempts/min regardless of key validity. This prevents information leakage (attacker can't tell if a key exists by whether it consumed a token or not).

### D2: Webhook subscription pause/resume (revised — use existing status field)

**No new `active BOOLEAN` column.** The subscription entity already has a `status VARCHAR` field with values: ACTIVE, CANCELLED, FAILING, DEACTIVATED. Add `PAUSED` to represent admin-initiated pause. This avoids dual-state ambiguity (`active=false` + `status=ACTIVE` would be contradictory).

PATCH /api/v1/subscriptions/{id}/status with `{"status": "PAUSED"}` or `{"status": "ACTIVE"}`. WebhookDeliveryService checks `status = 'ACTIVE'` before delivery (already does via `findActiveByEventType`). Paused subscriptions remain visible in the list with "Paused" badge. Events during pause are dropped (not queued) — documented in UI tooltip.

**Subscription state machine:**
```
ACTIVE → PAUSED    (admin toggle)
ACTIVE → FAILING   (delivery failure detected)
ACTIVE → CANCELLED (admin delete — soft delete)
PAUSED → ACTIVE    (admin toggle / re-enable)
FAILING → ACTIVE   (successful delivery resets)
FAILING → DEACTIVATED (5 consecutive failures — auto-disable)
DEACTIVATED → ACTIVE  (admin re-enables)
```

**Flyway impact:** No migration needed for pause/resume — the status column already exists as VARCHAR. V34 is freed for webhook_delivery_log.

### D3: Webhook test event

POST /api/v1/subscriptions/{id}/test with `{eventType}`. Server generates a synthetic DomainEvent with test flag and delivers it to the subscription endpoint. Response includes the delivery result (status code, response time). Frontend shows the result inline after clicking "Send Test." HTTP client uses 10s connect timeout and 30s read timeout — a hanging endpoint will not block the delivery thread indefinitely.

### D4: Webhook delivery log

New `webhook_delivery_log` table: `id UUID`, `subscription_id UUID`, `event_type VARCHAR`, `status_code INTEGER`, `response_time_ms INTEGER`, `attempted_at TIMESTAMPTZ`, `attempt_number INTEGER`, `response_body TEXT` (truncated to 1KB, redacted via `WebhookResponseRedactor`). WebhookDeliveryService logs each attempt. Retained for 14 days (scheduled cleanup). Frontend shows last 20 deliveries per subscription in an expandable panel.

### D4a: Response body redaction (added after security review)

`WebhookResponseRedactor` applies regex-based redaction BEFORE persistence — secrets are never written to the database. Patterns: Bearer tokens, AWS access keys, generic API key/token/secret values, email addresses, US SSNs, credit card numbers. Applied in `recordDelivery()` before constructing the log entity. Truncation (1KB) in entity constructor applies after redaction.

**Why regex and not Phileas/NER:** For webhook response bodies, the primary concern is leaked credentials/tokens (deterministic patterns), not person names (requires NLP). Regex adds no dependency and handles the high-confidence cases. For future DV/shelter PII detection, evaluate Phileas (ai.philterd:phileas).

### D5: Auto-disable on consecutive failures

After 5 consecutive delivery failures to the same subscription, set `status='DEACTIVATED'` and publish a notification event to the tenant's admin users. The admin can re-enable (set status back to ACTIVE) after fixing the endpoint. This prevents resource waste on dead endpoints.

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
