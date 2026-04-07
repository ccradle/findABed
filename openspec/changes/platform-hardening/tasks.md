## Tasks

### Setup

- [x] T-0: Create branch `feature/platform-hardening` in code repo (`finding-a-bed-tonight`)

### Backend — API Key Lifecycle (Flyway range: V32–V33)

- [x] T-1: `ApiKeyService.deactivate()` — already implements revoke (sets active=false, immediate). No cache layer exists.
- [x] T-2: `ApiKeyService.rotate()` — preserve old hash in `oldKeyHash`, set `oldKeyExpiresAt` to +24h, generate new key
- [x] T-3: `ApiKeyService.validate()` — check old key hash within grace period if current key not found. Expiry checked in SQL (`old_key_expires_at > NOW()`).
- [x] T-4: `@Scheduled` cleanup every hour — clear `oldKeyHash`/`oldKeyExpiresAt` after grace period expires. ShedLock noted for multi-instance.
- [x] T-5: Flyway V33: add `old_key_hash VARCHAR(255)` and `old_key_expires_at TIMESTAMPTZ` to api_key table (last_used_at already existed)

### Backend — API Key Principal Review Fixes (2026-04-07)

- [x] T-5a: Key entropy: 256 bits (32 bytes) — was 128 bits (16 bytes). One-line fix in `generateRandomKey()`.
- [x] T-5b: `deactivate()` clears grace period — nulls `oldKeyHash` and `oldKeyExpiresAt` on revoke. Prevents old key auth on revoked keys.
- [x] T-5c: Grace period expiry pushed to SQL — `findByOldKeyHashWithinGracePeriod` includes `AND old_key_expires_at > NOW()`. No unnecessary DB round-trips.
- [x] T-5d: Remove unused `ConditionalOnProperty` import.
- [x] T-5e: Add ShedLock comment on `@Scheduled` cleanup for future multi-instance deployments.
- [ ] T-5f: Integration test — revoke during active grace period: old key no longer authenticates
- [ ] T-5g: Integration test — expired grace period old key rejected even if cleanup hasn't run (use short grace period in test, sleep, verify)
- [ ] T-5h: Integration test — rotated key is 64 hex chars (256 bits)

### Backend — API Key Brute-Force Rate Limiting

- [ ] T-RL-1: Add Bucket4j filter config for API key failures: `cache-name: rate-limit-api-key`, url pattern matching `X-API-Key` header presence, 5 failed attempts per minute per IP
- [ ] T-RL-2: Modify `ApiKeyAuthenticationFilter` — on validation failure, increment Bucket4j counter. If exhausted, return 429 with `Retry-After` and `{"error":"rate_limited"}` body. Log at WARN.
- [ ] T-RL-3: Add nginx `limit_req_zone api_key_auth` in `00-rate-limit.conf` — 20 req/min per IP for `/api/v1/` paths with `X-API-Key`
- [ ] T-RL-4: Integration test (positive): valid API key succeeds after failed attempts from different IP
- [ ] T-RL-5: Integration test (positive): 5 invalid keys from same IP → 6th returns 429 with Retry-After header
- [ ] T-RL-6: Integration test (negative): valid API key from rate-limited IP still authenticates (failure counter separate from success)
- [ ] T-RL-7: Integration test (negative): rate limit does not cross IPs (IP-A limited, IP-B succeeds)

### Backend — Webhook Management (Flyway range: V34–V35)

- [ ] T-6: Flyway V34: add `active BOOLEAN DEFAULT true` to `subscription` table
- [ ] T-7: Flyway V35: create `webhook_delivery_log` table (id, subscription_id, event_type, status_code, response_time_ms, attempted_at, attempt_number, response_body TEXT)
- [ ] T-8: PATCH /api/v1/subscriptions/{id}/status — pause/resume toggle
- [ ] T-9: POST /api/v1/subscriptions/{id}/test — generate synthetic event, deliver, return result
- [ ] T-10: `WebhookDeliveryService` — check `active` flag before delivery, skip paused subscriptions
- [ ] T-11: `WebhookDeliveryService` — log each delivery attempt to webhook_delivery_log
- [ ] T-12: Auto-disable after 5 consecutive failures — set active=false, publish notification event
- [ ] T-13: GET /api/v1/subscriptions/{id}/deliveries — return last 20 delivery log entries
- [ ] T-14: `@Scheduled` cleanup: delete delivery logs older than 14 days

### Backend — Server-Side Retry

- [ ] T-15: Add `spring-retry` dependency to pom.xml
- [ ] T-16: `@EnableRetry` on Application or config class
- [ ] T-17: `@Retryable` on availability update — retryFor PessimisticLockingFailureException, maxAttempts=3, backoff 50ms×2. **CRITICAL: `@Retryable` MUST be OUTSIDE the `@Transactional` boundary** (on the controller or a non-transactional wrapper). If retry wraps a @Transactional method, the second attempt inherits a rolled-back transaction.
- [ ] T-18: `@Recover` method: log exhausted retries, return 409
- [ ] T-18a: Integration test — retry succeeds on second attempt, verify only ONE domain event is published (not one per attempt)
- [ ] T-18b: Integration test — verify @Retryable is outside @Transactional by confirming second attempt gets a fresh transaction (not rollback-only)

### Backend — SSE Backpressure (PHASE 2 — after all other tasks green)

**Do NOT start these until Phase 1 verification (T-55 through T-59) passes.**

- [ ] T-SSE-B1: Run full `SseNotificationIntegrationTest` + `SseStabilityTest` — save baseline output to `logs/sse-baseline-pre-backpressure.log`
- [ ] T-SSE-B2: Run `sse-cache-regression` Playwright tests through nginx — save baseline to `logs/sse-playwright-baseline.log`
- [ ] T-SSE-B3: Verify `sse.connections.active` gauge is flat on local nginx (3 users, 5 min wait)
- [ ] T-19: Replace direct `emitter.send()` with bounded per-client `LinkedBlockingQueue<SseEvent>` (max 10). Use virtual threads for sender (not platform threads)
- [ ] T-20: Background sender thread per emitter — ONLY writer to `emitter.send()`. On IOException: remove emitter from registry FIRST, then completeWithError, then exit thread. Preserve v0.29.2 remove-before-complete pattern.
- [ ] T-20a: Sender thread lifecycle — poison pill on emitter removal, thread naming `sse-sender-{userId}`, clean exit on shutdown (@PreDestroy completes all within 5 seconds)
- [ ] T-21: On queue overflow, drop oldest event. Heartbeats have lower priority than real events (drop heartbeat first). Log at DEBUG.
- [ ] T-21a: Heartbeat scheduler enqueues to the per-client queue — does NOT call `emitter.send()` directly
- [ ] T-SSE-R1: Re-run full `SseNotificationIntegrationTest` + `SseStabilityTest` — compare to baseline, zero regressions
- [ ] T-SSE-R2: Re-run `sse-cache-regression` Playwright tests through nginx — compare to baseline
- [ ] T-SSE-R3: Verify `sse.connections.active` gauge flat (not sawtooth) on local nginx (3 users, 5 min wait)
- [ ] T-SSE-R4: Integration test — sender thread terminates when emitter is removed (no thread leak)
- [ ] T-SSE-R5: Integration test — IOException in sender triggers cleanup AND thread exit, no cascading errors
- [ ] T-SSE-R6: Integration test — concurrent heartbeat enqueue + event enqueue on same client — no race condition
- [ ] T-SSE-R7: Integration test — graceful shutdown completes all sender threads within 5 seconds

### Backend — Audit Event Fix (#58)

- [x] T-58a: Fix ACCESS_CODE_USED audit event: set `actor_user_id = target_user_id` in access code authentication flow
- [x] T-58b: Integration test (positive): access code login creates `ACCESS_CODE_USED` audit event with non-null `actor_user_id` matching the authenticated user
- [x] T-58c: Integration test (positive): audit event includes client IP address
- [x] T-58d: Integration test (negative): verify standard email/password login audit events still have correct `actor_user_id` (no regression)
- [x] T-58e: Integration test (negative): verify audit_events INSERT does not produce constraint violation in server logs during access code login

### Backend — Tests

- [ ] T-22: Integration test (positive): revoke API key, verify subsequent auth returns 401
- [ ] T-22a: Integration test (negative): revoke non-existent key returns 404
- [ ] T-22b: Integration test (negative): non-admin revoke attempt returns 403
- [ ] T-22c: Integration test (negative): revoke already-revoked key is idempotent (200, no error)
- [ ] T-23: Integration test: rotate key, verify both old and new work during grace, old fails after
- [ ] T-24: Integration test (positive): pause subscription, verify events not delivered
- [ ] T-24a: Integration test (negative): pause non-existent subscription returns 404
- [ ] T-24b: Integration test (negative): non-admin pause attempt returns 403
- [ ] T-24c: Integration test (negative): send test event to paused subscription — verify behavior documented
- [ ] T-25: Integration test (positive): send test event, verify delivery
- [ ] T-25a: Integration test (positive): webhook delivery uses 10s connect + 30s read timeout — hanging endpoint times out
- [ ] T-26: Integration test (positive): 5 consecutive failures auto-disable subscription
- [ ] T-26a: Integration test (positive): re-enable auto-disabled subscription resets failure counter
- [ ] T-26b: Integration test (positive): successful delivery after 3 failures resets counter to 0
- [ ] T-27: Integration test (positive): availability update retry on lock contention (mock advisory lock failure)
- [ ] T-27a: Integration test (negative): non-retryable exception (DataIntegrityViolationException) is NOT retried — fails immediately
- [ ] T-28: Integration test (positive): delivery log persisted on webhook send
- [ ] T-28a: Integration test (positive): delivery log response_body truncated to 1KB for long responses

### Frontend — API Keys Tab

- [ ] T-29: Add "Revoke" button on each API key row with confirmation dialog
- [ ] T-30: Add "Rotate" button — show new key once, show grace period countdown on old key
- [ ] T-31: Show last_used_at column and status badge (Active/Grace Period/Revoked)

### Frontend — Subscriptions Tab

- [ ] T-32: Add "Delete" button on each subscription row with confirmation dialog
- [ ] T-33: Add pause/resume toggle switch on each subscription
- [ ] T-34: Add "Send Test" button with event-type dropdown, show result inline
- [ ] T-35: Add expandable delivery log panel per subscription (last 20 deliveries)

### Frontend — My Reservations Clickable Shelters (#64)

- [x] T-64a: Make shelter name in My Reservations a clickable link that opens shelter detail modal (same as clicking the card)
- [x] T-64b: Add `data-testid="reservation-shelter-link-{shelterId}"` on each clickable shelter name
- [x] T-64c: Ensure hold countdown timer remains visible and continues after clicking (stopPropagation + modal doesn't affect timer)
- [x] T-64d: Expired reservations — panel only shows HELD status; expired reservations are removed on next fetch. Name is clickable while visible.
- [x] T-64e: Add i18n for any new link text or aria-label (en.json + es.json)

### Frontend — i18n & Accessibility

- [ ] T-36: Add i18n keys for API key lifecycle and webhook management (en.json + es.json)
- [ ] T-37: WCAG: confirmation dialogs keyboard-navigable, status badges have accessible labels

### Frontend — Tests

- [ ] T-38: Playwright: revoke API key, verify status badge changes
- [ ] T-39: Playwright: rotate API key, new key displayed once
- [ ] T-40: Playwright: delete subscription, confirm dialog, row removed
- [ ] T-41: Playwright: pause subscription, toggle visible, resume
- [ ] T-42: Playwright: send test event, result shown inline

### Frontend Tests — My Reservations (#64)

- [x] T-64f: Playwright (positive): hold a bed → My Reservations shows shelter name as clickable link with `data-testid="reservation-shelter-link-{id}"`
- [x] T-64g: Playwright (positive): click reservation shelter link → shelter detail modal opens with details
- [x] T-64h: Playwright (positive): hold countdown timer still visible and decrementing after clicking shelter link
- [x] T-64i: Playwright (positive): multiple reservations → each shelter name independently clickable
- [x] T-64j: Playwright (negative): expired reservations removed from panel (only HELD shown)
- [x] T-64k: Playwright (negative): clicking shelter link does NOT navigate away from the search page (stays on same page)
- [ ] T-64l: Playwright (negative): reservation for shelter not in current filter — click still opens detail modal (fetches by ID regardless of filter)

### Performance — Gatling

- [ ] T-43: Re-run Gatling AvailabilityUpdate with server-side retry — verify KO < 1%. Also verify API key validation latency unchanged (grace period adds potential second query).
- [ ] T-44: New Gatling simulation: 200 SSE connections + bed search concurrent load (PHASE 2 — after SSE backpressure)
- [ ] T-44a: Gatling SSE slow-client scenario: 200 connections, 10 deliberately throttled (sleep 2s per event read). Verify fast clients receive events within p95 < 500ms. (PHASE 2)
- [ ] T-45: Verify bed search p99 stays under SLO with 200 SSE connections (PHASE 2)

### Seed Data & Screenshots

- [ ] T-46: Add API key with last_used_at timestamp for screenshot
- [ ] T-47: Add subscription with delivery log entries for screenshot
- [ ] T-48: Capture screenshots: API key management, subscription management, delivery log

### Docs-as-Code — DBML, AsyncAPI, OpenAPI

- [ ] T-49: Update `docs/schema.dbml` — add `webhook_delivery_log` table, `active` to subscription table, `last_used_at` and `old_key_expires_at` to api_key table
- [ ] T-50: Update `docs/asyncapi.yaml` — document webhook test event channel, subscription auto-disable notification event
- [ ] T-51: Add `@Operation` annotations to all new endpoints: subscription pause/status, subscription test, subscription deliveries, API key rotate (verify existing revoke has it)
- [ ] T-52: Verify ArchUnit — subscription delivery log stays in subscription module, retry logic stays in availability module, SSE backpressure stays in notification module

### Documentation

- [ ] T-53: Update FOR-DEVELOPERS.md — API reference (key rotate, subscription pause/test, delivery log), project status
- [ ] T-54: Update runbook — API key rotation procedure, webhook troubleshooting, retry behavior

### Verification

- [ ] T-55: Run full backend test suite (including ArchUnit) — all green
- [ ] T-56: Run full Playwright test suite — all green
- [ ] T-57: ESLint + TypeScript clean
- [ ] T-58: CI green on all jobs
- [ ] T-59: Merge to main, tag
