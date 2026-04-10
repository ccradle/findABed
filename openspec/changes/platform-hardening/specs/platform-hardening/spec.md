## ADDED Requirements

### Requirement: API key revocation

The admin panel SHALL allow revoking API keys with immediate effect.

#### Scenario: Admin revokes an API key
- **WHEN** an admin clicks "Revoke" on an API key row and confirms
- **THEN** the key is immediately invalidated and cannot authenticate requests

#### Scenario: Revoked key returns 401 on subsequent use
- **WHEN** a revoked API key is used in an `X-API-Key` header
- **THEN** the system SHALL return 401 Unauthorized

#### Scenario: Revoke non-existent key returns 404
- **WHEN** an admin attempts to revoke a key that does not exist
- **THEN** the system SHALL return 404 Not Found

#### Scenario: Non-admin cannot revoke keys
- **WHEN** a COORDINATOR or OUTREACH_WORKER attempts to revoke an API key
- **THEN** the system SHALL return 403 Forbidden

#### Scenario: Revoking an already-revoked key is idempotent
- **WHEN** an admin revokes a key that is already revoked
- **THEN** the system SHALL return 200 (no error)

#### Scenario: Revoke during grace period clears old key hash
- **WHEN** an admin revokes a key that has an active grace period (recently rotated)
- **THEN** the key SHALL be immediately deactivated
- **AND** the old key hash and grace period expiry SHALL be cleared
- **AND** neither the current nor the old key SHALL authenticate

### Requirement: API key entropy

API keys SHALL be generated with at least 256 bits of entropy using a cryptographically secure random number generator.

#### Scenario: Generated key has sufficient entropy
- **WHEN** a new API key is created or rotated
- **THEN** the plaintext key SHALL be at least 64 hex characters (256 bits)
- **AND** the key SHALL be generated using SecureRandom

### Requirement: API key rotation with grace period

The system SHALL support key rotation with configurable overlap.

#### Scenario: Admin rotates an API key

- **WHEN** an admin clicks "Rotate" on an API key row
- **THEN** a new key is generated and displayed once
- **AND** the old key remains valid for the grace period (default 24 hours)

#### Scenario: Old key expires after grace period

- **WHEN** the grace period elapses after key rotation
- **THEN** the old key is automatically invalidated

#### Scenario: Expired old key rejected at validation time (not just cleanup)
- **WHEN** a request uses an old key whose grace period has expired
- **AND** the @Scheduled cleanup has not yet run
- **THEN** the system SHALL still reject the key (expiry checked in SQL query, not dependent on cleanup)

### Requirement: API key rate limiting

The system SHALL rate limit all API key authentication attempts (valid and invalid) per IP to prevent brute-force key guessing. Both valid and invalid keys consume tokens — no information leakage.

#### Scenario: 6th API key attempt within 1 minute returns 429
- **WHEN** a client IP sends 5 requests with `X-API-Key` header within 1 minute
- **AND** sends a 6th request
- **THEN** the 6th request SHALL return 429 Too Many Requests
- **AND** the response SHALL include `Retry-After` header with seconds until refill
- **AND** the response SHALL include `X-RateLimit-Limit: 5` and `X-RateLimit-Remaining: 0`

#### Scenario: All API key responses include rate limit headers
- **WHEN** any request with `X-API-Key` header is processed (valid or invalid key)
- **THEN** the response SHALL include `X-RateLimit-Limit` and `X-RateLimit-Remaining` headers

#### Scenario: Rate limit logged at WARN level
- **WHEN** an API key rate limit is triggered (429 returned)
- **THEN** the event SHALL be logged at WARN level with client IP (consistent with REQ-RL-5)

#### Scenario: Nginx edge rate limiting on API paths
- **WHEN** a client IP sends more than 60 requests per minute to `/api/`
- **THEN** nginx SHALL return 429 before the request reaches the JVM (burst=20)

#### Scenario: Different IPs have independent rate limits
- **WHEN** IP-A has been rate-limited
- **AND** IP-B sends a request with an API key
- **THEN** IP-B SHALL not be affected (independent Caffeine-cached buckets)

#### Scenario: Rate limit buckets do not grow unbounded
- **WHEN** 100,000+ unique IPs send API key requests
- **THEN** the bucket cache SHALL not exceed 10,000 entries (Caffeine eviction)
- **AND** idle buckets SHALL be evicted after 10 minutes

#### Scenario: Client IP resolved from X-Real-IP header
- **WHEN** the request arrives via nginx proxy
- **THEN** the rate limiter SHALL use the `X-Real-IP` header value (set by nginx)
- **AND** SHALL fall back to `getRemoteAddr()` if the header is absent

### Requirement: Webhook subscription delete

The admin panel SHALL allow deleting webhook subscriptions.

#### Scenario: Admin deletes a subscription
- **WHEN** an admin clicks "Delete" on a subscription row and confirms
- **THEN** the subscription is removed and no further deliveries are attempted

#### Scenario: Delete non-existent subscription returns 404
- **WHEN** an admin attempts to delete a subscription that does not exist
- **THEN** the system SHALL return 404 Not Found

#### Scenario: Non-admin cannot delete subscription
- **WHEN** a COORDINATOR or OUTREACH_WORKER attempts to delete a subscription
- **THEN** the system SHALL return 403 Forbidden

### Requirement: Webhook subscription pause/resume

The system SHALL support pausing and resuming webhook delivery via the existing `status` field (PAUSED value). No separate `active` boolean — single source of truth.

#### Scenario: Admin pauses a subscription
- **WHEN** an admin sends PATCH /api/v1/subscriptions/{id}/status with `{"status": "PAUSED"}`
- **THEN** the subscription status SHALL change to PAUSED
- **AND** events matching the subscription SHALL not be delivered until resumed
- **AND** events during the pause period SHALL be dropped (not queued)

#### Scenario: Admin resumes a paused subscription
- **WHEN** an admin sends PATCH /api/v1/subscriptions/{id}/status with `{"status": "ACTIVE"}`
- **THEN** the subscription status SHALL change to ACTIVE
- **AND** delivery SHALL resume on the next matching event

#### Scenario: Invalid status transition rejected
- **WHEN** an admin attempts to set status to an invalid value (e.g., "FAILING" or "DELETED")
- **THEN** the system SHALL return 400 Bad Request
- **AND** only ACTIVE and PAUSED SHALL be accepted as admin-settable values

#### Scenario: CANCELLED subscription cannot be modified
- **WHEN** an admin attempts to PATCH status on a CANCELLED subscription
- **THEN** the system SHALL return 409 Conflict
- **AND** the subscription SHALL remain CANCELLED

#### Scenario: PAUSED only allowed from ACTIVE
- **WHEN** an admin attempts to PATCH status to PAUSED on a DEACTIVATED or FAILING subscription
- **THEN** the system SHALL return 409 Conflict (re-enable to ACTIVE first, then pause)

#### Scenario: Cross-tenant subscription access returns 404
- **WHEN** an admin from Tenant A attempts to PATCH or GET deliveries for a Tenant B subscription
- **THEN** the system SHALL return 404 (not 403 — avoid confirming cross-tenant existence)

### Requirement: Webhook delivery response redaction

Response bodies stored in the delivery log SHALL be redacted for secrets and PII before persistence.

#### Scenario: Bearer token in response body is redacted
- **WHEN** a webhook endpoint returns a response containing "Bearer eyJhbGci..."
- **THEN** the stored response_body SHALL contain "[REDACTED]" in place of the token

#### Scenario: Email in response body is redacted
- **WHEN** a webhook endpoint returns a response containing "user@example.com"
- **THEN** the stored response_body SHALL contain "[REDACTED]" in place of the email

#### Scenario: Redaction applied before truncation
- **WHEN** a webhook endpoint returns a 2KB response with secrets
- **THEN** secrets SHALL be redacted first, THEN the body SHALL be truncated to 1KB

### Requirement: Webhook test event

The system SHALL allow sending test events to a subscription endpoint.

#### Scenario: Admin sends a test event

- **WHEN** an admin clicks "Send Test" and selects an event type
- **THEN** a synthetic event is delivered to the subscription endpoint
- **AND** the delivery result (status code, response time) is shown inline

### Requirement: Webhook delivery timeout

Webhook delivery HTTP calls SHALL have configurable connection and read timeouts to prevent thread blocking on hanging endpoints. Both timeouts SHALL default to the values from design D3 (10s connect, 30s read).

#### Scenario: Webhook endpoint hangs
- **WHEN** a webhook delivery endpoint does not respond within the configured read timeout (default 30 seconds)
- **THEN** the delivery SHALL timeout and be recorded as a failure in the delivery log
- **AND** the failure SHALL count toward the consecutive failure counter
- **AND** the result envelope SHALL NOT report the upstream's would-be success status code

#### Scenario: Webhook endpoint unreachable
- **WHEN** a webhook delivery cannot establish a TCP connection within the configured connect timeout (default 10 seconds)
- **THEN** the delivery SHALL timeout and be recorded as a failure

#### Scenario: Read timeout is configurable
- **WHEN** `fabt.webhook.read-timeout-seconds` (env: `FABT_WEBHOOK_READ_TIMEOUT_SECONDS`) is overridden
- **THEN** the new value SHALL be applied to subsequent outbound webhook deliveries via `JdkClientHttpRequestFactory.setReadTimeout()`
- **AND** existing in-flight requests SHALL complete under their original timeout

#### Scenario: Connect timeout is configurable
- **WHEN** `fabt.webhook.connect-timeout-seconds` (env: `FABT_WEBHOOK_CONNECT_TIMEOUT_SECONDS`) is overridden
- **THEN** the new value SHALL be applied to subsequent outbound webhook deliveries via `HttpClient.Builder.connectTimeout()`

### Requirement: Webhook delivery log

The system SHALL record recent webhook deliveries for admin visibility.

#### Scenario: Admin views delivery log
- **WHEN** an admin expands a subscription's delivery log
- **THEN** the last 20 deliveries are shown with: event type, status code, response time, timestamp, attempt number

#### Scenario: Delivery log response body truncated
- **WHEN** a webhook endpoint returns a response body longer than 1KB
- **THEN** the stored response_body SHALL be truncated to 1KB

#### Scenario: Auto-disable on consecutive failures
- **WHEN** a subscription has 5 consecutive delivery failures
- **THEN** the subscription status SHALL change to DEACTIVATED (not PAUSED — distinguishes auto-disable from admin pause)
- **AND** the admin SHALL be notified via SSE

#### Scenario: Admin re-enables auto-disabled subscription
- **WHEN** an admin sends PATCH /api/v1/subscriptions/{id}/status with `{"status": "ACTIVE"}`
- **AND** the subscription was previously DEACTIVATED
- **THEN** the consecutive failure counter SHALL reset to 0
- **AND** delivery attempts SHALL resume on the next matching event

#### Scenario: Successful delivery resets failure counter
- **WHEN** a delivery succeeds after 3 consecutive failures
- **THEN** the consecutive failure counter SHALL reset to 0

### Requirement: Server-side retry on transient availability update failures

The system SHALL retry availability updates on transient DataAccessException using Spring Framework 7 native @Retryable. No external dependency (spring-retry is maintenance mode).

#### Scenario: Transient DataAccessException retried transparently
- **WHEN** an availability update encounters a transient DataAccessException (connection pool exhaustion, PessimisticLockingFailureException, etc.)
- **THEN** the operation SHALL be retried up to 2 times (3 total attempts) with exponential backoff (100ms initial, multiplier 2, max 1s)
- **AND** the client SHALL receive 200 if any attempt succeeds

#### Scenario: All retries exhausted returns 409
- **WHEN** all 3 attempts fail with DataAccessException
- **THEN** the client SHALL receive 409 Conflict (via GlobalExceptionHandler mapping)

#### Scenario: Business logic exceptions are NOT retried
- **WHEN** an availability update encounters AvailabilityInvariantViolation or NoSuchElementException
- **THEN** the exception SHALL propagate immediately without retry
- **AND** the client SHALL receive the appropriate error response (422 or 404)

#### Scenario: Retry wrapper is outside @Transactional boundary
- **WHEN** the first attempt fails and a retry occurs
- **THEN** the retry SHALL execute in a fresh transaction (not a rolled-back one)
- **AND** domain events SHALL be published only from the successful attempt

### Requirement: ACCESS_CODE_USED audit event has correct actor (#58)

The system SHALL set `actor_user_id` to the target user's ID for self-authentication audit events (ACCESS_CODE_USED), preventing NOT NULL constraint violations on the `audit_events` table.

#### Scenario: Access code login creates audit event with correct actor
- **WHEN** a user authenticates via access code
- **THEN** an `ACCESS_CODE_USED` audit event is inserted into `audit_events`
- **AND** `actor_user_id` equals `target_user_id` (the user authenticating themselves)

#### Scenario: Audit event includes IP address
- **WHEN** a user authenticates via access code from a known IP
- **THEN** the `ACCESS_CODE_USED` audit event records the client IP address

#### Scenario: Access code login does not produce database constraint violation
- **WHEN** a user authenticates via access code
- **THEN** no `null value in column "actor_user_id"` error appears in server logs
- **AND** the audit_events INSERT succeeds

#### Scenario: Standard login audit events are not affected
- **WHEN** a user authenticates via email/password
- **THEN** the `LOGIN_SUCCESS` audit event still has the correct `actor_user_id`
- **AND** no regression in existing audit behavior

### Requirement: My Reservations shelter names are clickable (#64)

Each shelter entry in the My Reservations panel SHALL be a clickable link that navigates to the shelter detail view, providing access to shelter details and directions.

#### Scenario: Shelter name links to shelter details
- **WHEN** an outreach worker views My Reservations after holding a bed
- **THEN** the shelter name SHALL be a clickable link
- **AND** clicking it SHALL scroll to and expand the shelter card in the search results

#### Scenario: Hold countdown timer remains visible after clicking
- **WHEN** the user clicks a shelter name in My Reservations
- **THEN** the hold countdown timer SHALL remain visible in the reservations panel
- **AND** the countdown SHALL continue decrementing

#### Scenario: Directions accessible from reservation
- **WHEN** the user clicks a shelter name in My Reservations
- **THEN** the shelter detail view SHALL include the Directions link
- **AND** the shelter address and phone number SHALL be visible

#### Scenario: Multiple reservations are independently clickable
- **WHEN** the user has multiple active reservations
- **THEN** each shelter name SHALL be an independent clickable link
- **AND** clicking one SHALL not affect the other reservations

#### Scenario: Expired reservation shelter name still clickable
- **WHEN** a reservation has expired (hold timed out)
- **THEN** the shelter name SHALL still be clickable for directions
- **AND** the expired badge SHALL remain visible alongside the link

#### Scenario: Reservation shelter link has data-testid
- **WHEN** My Reservations is rendered
- **THEN** each clickable shelter name SHALL have `data-testid="reservation-shelter-link-{shelterId}"`

#### Scenario: Reservation for shelter not in current search results
- **WHEN** the user has a reservation for a shelter not matching the current population filter
- **THEN** the shelter name SHALL still be clickable
- **AND** clicking it SHALL clear the filter or show a message that the shelter is not in current results

<!-- SSE bounded event queue requirement MOVED 2026-04-10 to
     openspec/changes/sse-backpressure-phase2/specs/sse-backpressure-phase2/spec.md
     where it is captured by 10 ADDED requirements with more detail
     (single-writer wrapper, priority-aware enqueue, per-user cap,
     broadcast concurrency limit, forced reconnect, shutdown deadline,
     transport flag). Tracking issue: ccradle/finding-a-bed-tonight#97. -->

