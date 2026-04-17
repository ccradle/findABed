## ADDED Requirements

### Requirement: per-tenant-rate-limiting
The system SHALL rate-limit using a two-tier key scheme (per E1, D5): unauthenticated endpoints use `(SHA-256(api_key_header_value)[:16], ip)`; authenticated endpoints use `(tenant_id, ip)` once `TenantContext` is bound. Pre-auth `tenant_id`-keyed buckets are not supported because the tenant is unknown before JWT or API key validation.

#### Scenario: Pre-auth login endpoint keyed by api_key_hash + ip
- **GIVEN** two attackers share a NAT IP but target different tenants via different api-key headers
- **WHEN** both hit POST `/api/v1/auth/login` at high rate
- **THEN** each attacker's bucket is independent (`(sha256(attacker1_key), ip)` ≠ `(sha256(attacker2_key), ip)`)
- **AND** one attacker exhausting their bucket does NOT exhaust the other's login quota

#### Scenario: Authenticated endpoint keyed by tenant_id + ip
- **GIVEN** a user in tenant A authenticates
- **WHEN** the user hits a post-auth endpoint
- **THEN** the rate bucket is `(tenantA-uuid, ip)`
- **AND** tenant A's budget is not shared with tenant B even if they share the IP (unlikely, but documented)

#### Scenario: Unauthenticated forgot-password rate-limited
- **WHEN** a caller hits POST `/api/v1/auth/forgot-password` 10+ times per minute from one IP
- **THEN** the bucket is `(sha256(header_or_default), ip)` and the caller is throttled
- **AND** the throttle does not bleed into tenant-scoped buckets once the caller authenticates

### Requirement: tenant-rate-limit-config-table
The system SHALL maintain a `tenant_rate_limit_config` typed table (per E2) with per-tenant overrides for each endpoint-class rule (login, password-change, admin-reset, forgot-password, verify-totp, api-key) plus `statement_timeout_ms` and `work_mem`. Config changes SHALL emit an audit event, and config-load failures SHALL fall back to safe defaults (never fail-open).

#### Scenario: Per-tenant override applied
- **GIVEN** tenant A has a row in `tenant_rate_limit_config` with `login_per_minute=20`
- **WHEN** a user hits login in tenant A
- **THEN** the effective bucket size is 20 per minute (not the platform default)

#### Scenario: Config change emits audit event
- **WHEN** an operator updates a row in `tenant_rate_limit_config`
- **THEN** a `TENANT_RATE_LIMIT_CONFIG_CHANGED` audit event is emitted with prior and new values
- **AND** the change is visible to the tenant-config admin API

#### Scenario: Config-load failure uses fail-safe default
- **GIVEN** `tenant_rate_limit_config` is temporarily unreadable (e.g., DB blip)
- **WHEN** the rate-limit filter resolves the bucket
- **THEN** a fail-safe default (e.g., platform-wide floor) is used — NEVER fail-open (unbounded)
- **AND** a `fabt_tenant_config_load_failure` metric increments

### Requirement: per-tenant-hikari-connection-budget
The system SHALL apply per-tenant connection budgets via `SET LOCAL statement_timeout` at `@Transactional` entry (per E3, D4, B9). Sub-pool isolation (separate Hikari pools per tenant) is explicitly rejected as overcomplicated at the ~20-tenant ceiling.

#### Scenario: Per-tenant timeout applied on connection borrow
- **GIVEN** tenant A has `statement_timeout_ms=30000` configured
- **WHEN** a request on tenant A enters a `@Transactional` method and borrows a connection
- **THEN** after `SET LOCAL app.tenant_id` the connection executes `SET LOCAL statement_timeout = 30000`
- **AND** queries exceeding 30s are aborted with a clear timeout error

#### Scenario: Tenant tier change alters effective timeout
- **GIVEN** tenant A transitions from "pro" (30s) to "free" (5s) tier
- **WHEN** a subsequent request runs a query that previously took 20s
- **THEN** the query is aborted at 5s with a statement_timeout error
- **AND** the tier change is audited and the tenant-facing docs warn of this behavior

### Requirement: per-tenant-sse-buffer-shard
The system SHALL shard the SSE notification buffer by tenant (per E4) — replace the global `ConcurrentLinkedDeque` in `NotificationService` with `Map<UUID, ConcurrentLinkedDeque>`. Each tenant SHALL have a per-tenant cap (100 events) plus a platform-wide cap for OOM protection.

#### Scenario: Tenant A flood does not drop tenant B events
- **GIVEN** tenant A produces 500 events in a burst while tenant B produces 10
- **WHEN** the buffer processes them
- **THEN** tenant A's events beyond its 100-event cap are dropped (oldest-first) per its own queue
- **AND** tenant B's 10 events remain buffered for its subscribers

#### Scenario: Platform-wide cap triggers OOM guard
- **GIVEN** platform-wide buffered events exceed the platform cap
- **WHEN** the cap is reached
- **THEN** a warning log + metric fire
- **AND** the oldest-first drop policy evicts across tenants fairly

### Requirement: per-tenant-sse-delivery-fairness
The system SHALL deliver buffered SSE events via a round-robin dispatch loop over tenant queues (per E5), not FIFO. A per-tenant SSE connection limit SHALL apply to the `emitters` map in `NotificationService`.

#### Scenario: Round-robin prevents single-tenant starvation
- **GIVEN** tenant A has 500 buffered events and tenant B has 10
- **WHEN** the dispatch loop runs
- **THEN** the loop alternates delivery between tenants (round-robin)
- **AND** tenant B's 10 events are delivered within seconds, not blocked behind tenant A's backlog

#### Scenario: Per-tenant connection cap enforced
- **GIVEN** tenant A reaches its per-tenant SSE connection cap
- **WHEN** a 101st subscriber connects
- **THEN** the new connection is refused with an explicit error
- **AND** existing tenant-A subscribers and other tenants are unaffected

### Requirement: background-worker-fair-queue-dispatch
The system SHALL implement fair-queue dispatch in background workers (per E6) — `HmisPushService`, `WebhookDeliveryService`, `EmailService`, future notifications workers — using per-tenant inner queues + round-robin dispatch, so a single tenant's backlog cannot starve others.

#### Scenario: HMIS push round-robins across tenants
- **GIVEN** tenant A has 1000 queued outbox rows and tenant B has 5
- **WHEN** the HMIS push worker dispatch loop runs
- **THEN** it alternates between tenants A and B (round-robin)
- **AND** tenant B's 5 rows complete within the same window as the first 5 of tenant A

#### Scenario: Webhook delivery fair under load
- **GIVEN** tenant A generates 100 webhook events in a burst while tenant B generates 2
- **WHEN** `WebhookDeliveryService` dispatches
- **THEN** tenant B's 2 events are delivered within the average-per-event latency budget
- **AND** tenant A's events do not monopolize the worker pool

### Requirement: virtual-thread-carrier-starvation-guard
The system SHALL maintain an ArchUnit / forbidden-APIs rule (per E7) forbidding `synchronized` blocks in tenant-dispatched virtual-thread paths. `ReentrantLock` is mandatory to avoid pinned carrier threads that starve other tenants.

#### Scenario: Synchronized in virtual-thread path fails build
- **GIVEN** a class in `org.fabt.*.worker` adds a `synchronized` block in a method reachable from a virtual-thread dispatcher
- **WHEN** the forbidden-APIs / ArchUnit rule runs
- **THEN** the build fails with a message identifying the offending method and referencing `feedback_transactional_rls_scoped_value_ordering.md`

#### Scenario: ReentrantLock is accepted
- **GIVEN** the same method uses `ReentrantLock` instead
- **WHEN** the rule runs
- **THEN** the build passes

### Requirement: per-tenant-scheduled-task-metrics
The system SHALL emit per-tenant invocation and duration counters for `ReservationExpiryService`, `ReferralTokenPurgeService`, `AccessCodeCleanupScheduler`, `HmisPushScheduler`, and `SurgeExpiryService` (per E8) so that one tenant's workload cannot silently starve the batch window.

#### Scenario: Per-tenant reservation-expiry metric emitted
- **WHEN** `ReservationExpiryService` processes tenant A's expiring holds
- **THEN** `fabt_scheduled_task_invocations{task="reservation_expiry",tenant_id="<tenantA>"}` increments
- **AND** `fabt_scheduled_task_duration_seconds{task="reservation_expiry",tenant_id="<tenantA>"}` records the histogram

#### Scenario: Grafana panel exposes starvation signal
- **GIVEN** the per-tenant scheduled-task panel is provisioned
- **WHEN** tenant A's duration exceeds a configurable threshold
- **THEN** the panel highlights the tenant and firing alert rule notifies the on-call
- **AND** other tenants' durations are visible for comparison
