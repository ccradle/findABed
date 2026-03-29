## Tasks

### Setup

- [ ] T-0: Create branch `feature/platform-hardening` in code repo (`finding-a-bed-tonight`)

### Backend — API Key Lifecycle

- [ ] T-1: `ApiKeyService.revokeKey()` — immediate invalidation, clear from cache
- [ ] T-2: `ApiKeyService.rotateKey()` — generate new key, set `old_key_expires_at` on previous (default 24h grace), return new plaintext once
- [ ] T-3: `ApiKeyAuthenticationFilter` — check `old_key_expires_at` for grace period validation
- [ ] T-4: `@Scheduled` cleanup: invalidate expired old keys past grace period
- [ ] T-5: Add `last_used_at TIMESTAMPTZ` column to api_key table (Flyway migration), update on each successful auth

### Backend — Webhook Management

- [ ] T-6: Flyway migration: add `active BOOLEAN DEFAULT true` to `subscription` table
- [ ] T-7: Flyway migration: create `webhook_delivery_log` table (id, subscription_id, event_type, status_code, response_time_ms, attempted_at, attempt_number, response_body TEXT)
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
- [ ] T-17: `@Retryable` on `AvailabilityService.createSnapshot()` — retryFor PessimisticLockingFailureException, maxAttempts=3, backoff 50ms×2
- [ ] T-18: `@Recover` method: log exhausted retries, return 409

### Backend — SSE Backpressure

- [ ] T-19: Replace direct `emitter.send()` with bounded per-client `ArrayDeque<SseEvent>` (max 10)
- [ ] T-20: Background sender thread per emitter drains queue, detects dead clients via IOException
- [ ] T-21: On queue overflow, drop oldest event (log at DEBUG)

### Backend — Tests

- [ ] T-22: Integration test: revoke API key, verify subsequent auth fails
- [ ] T-23: Integration test: rotate key, verify both old and new work during grace, old fails after
- [ ] T-24: Integration test: pause subscription, verify events not delivered
- [ ] T-25: Integration test: send test event, verify delivery
- [ ] T-26: Integration test: 5 consecutive failures auto-disable subscription
- [ ] T-27: Integration test: availability update retry on lock contention (mock advisory lock failure)
- [ ] T-28: Integration test: delivery log persisted on webhook send

### Frontend — API Keys Tab

- [ ] T-29: Add "Revoke" button on each API key row with confirmation dialog
- [ ] T-30: Add "Rotate" button — show new key once, show grace period countdown on old key
- [ ] T-31: Show last_used_at column and status badge (Active/Grace Period/Revoked)

### Frontend — Subscriptions Tab

- [ ] T-32: Add "Delete" button on each subscription row with confirmation dialog
- [ ] T-33: Add pause/resume toggle switch on each subscription
- [ ] T-34: Add "Send Test" button with event-type dropdown, show result inline
- [ ] T-35: Add expandable delivery log panel per subscription (last 20 deliveries)

### Frontend — i18n & Accessibility

- [ ] T-36: Add i18n keys for API key lifecycle and webhook management (en.json + es.json)
- [ ] T-37: WCAG: confirmation dialogs keyboard-navigable, status badges have accessible labels

### Frontend — Tests

- [ ] T-38: Playwright: revoke API key, verify status badge changes
- [ ] T-39: Playwright: rotate API key, new key displayed once
- [ ] T-40: Playwright: delete subscription, confirm dialog, row removed
- [ ] T-41: Playwright: pause subscription, toggle visible, resume
- [ ] T-42: Playwright: send test event, result shown inline

### Performance — Gatling

- [ ] T-43: Re-run Gatling AvailabilityUpdate with server-side retry — verify KO < 1%
- [ ] T-44: New Gatling simulation: 200 SSE connections + bed search concurrent load
- [ ] T-45: Verify bed search p99 stays under SLO with 200 SSE connections

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
