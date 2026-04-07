## Why

The admin panel creates API keys and webhook subscriptions but cannot manage their lifecycle — no revoke, rotate, delete, pause, or test. Marcus (CoC Admin) can't revoke a compromised key or remove a decommissioned webhook. The Gatling AvailabilityUpdate test shows 2.05% KO (above 1% SLO) from advisory lock contention that could be absorbed by server-side retry. The SSE notification system has no backpressure protection for slow clients. These are operational gaps that block production readiness.

## What Changes

- **API key lifecycle**: revoke button (confirmation, immediate invalidation — clears grace period), rotate with grace period (old key hash preserved in `old_key_hash` with `old_key_expires_at`, default 24h, Stripe model), 256-bit key entropy, SQL-level expiry validation, metadata display (last used, status badge, expiry).
- **API key rate limiting**: Two-layer defense — nginx edge (1r/s, burst=20) + Bucket4j per-IP (5/min, Caffeine-cached, atomic `tryConsumeAndReturnRemaining`). Both valid and invalid keys consume tokens (no info leak). `X-RateLimit-*` headers on all responses (Stripe/GitHub pattern). Client IP from `X-Real-IP` (nginx-set).
- **Webhook subscription management**: delete button (confirmation), pause/resume toggle, send test event button with event-type dropdown, recent delivery log table (last 20 deliveries per subscription). Webhook HTTP client: 10s connect timeout, 30s read timeout. Response body truncated to 1KB in delivery log.
- **Server-side retry on 409**: spring-retry with @Retryable on availability update for advisory lock contention. 3 attempts, 50ms backoff × 2. Eliminates 409 from client perspective.
- **SSE slow-client protection**: bounded per-client event queue (max 10) with drop-oldest on overflow. Gatling simulation with 200 SSE connections + bed search.
- **Webhook delivery log**: new table for recent deliveries with status, response time, attempt count. Auto-disable endpoint after 5 consecutive failures.
- **Audit event fix (#58)**: ACCESS_CODE_USED audit event has null actor_user_id — set actor_user_id = target_user_id for self-authentication flows.
- **My Reservations clickable (#64)**: Shelter names in My Reservations are static text — make them clickable links to shelter details with directions access.

## Capabilities

### New Capabilities
- `platform-hardening`: API key revoke/rotate, webhook delete/pause/test, delivery log, server-side retry, SSE backpressure

- `audit-event-fix`: Fix ACCESS_CODE_USED null actor_user_id (#58)
- `reservation-clickable-shelters`: Make shelter names clickable in My Reservations (#64)

### Modified Capabilities

## Impact

- **Backend**: Flyway migration (webhook_delivery_log table, subscription active flag), spring-retry dependency, @Retryable on AvailabilityService, webhook pause/test endpoints, SSE bounded queue
- **Frontend**: API key revoke/rotate buttons + metadata in admin tab, subscription delete/pause/test buttons + delivery log panel
- **Performance**: Gatling AvailabilityUpdate KO rate expected to drop below 1% with retry. New Gatling simulation for 200-connection SSE load.
- **Testing**: Backend integration for key rotate, subscription pause/test, retry, delivery log. Playwright e2e for all admin UI additions. Gatling performance verification.
