## ADDED Requirements

### Requirement: health-endpoints
The system SHALL expose health check endpoints for monitoring and load balancer integration.

#### Scenario: Liveness check
- **WHEN** a request is sent to GET `/actuator/health/liveness`
- **THEN** the system returns 200 if the application is running, 503 if not

#### Scenario: Readiness check
- **WHEN** a request is sent to GET `/actuator/health/readiness`
- **THEN** the system returns 200 only if PostgreSQL is reachable and migrations are complete
- **AND** in Standard/Full tiers, Redis connectivity is also checked

#### Scenario: Deployment tier health
- **WHEN** a request is sent to GET `/actuator/health`
- **THEN** the response includes component health for all tier-relevant infrastructure (db, redis, kafka) with status UP/DOWN

### Requirement: structured-logging
The system SHALL emit structured JSON logs with correlation context.

#### Scenario: Log format
- **WHEN** the application logs any message
- **THEN** the log entry is JSON-formatted with fields: timestamp, level, logger, message, tenantId, userId, traceId, spanId

#### Scenario: Tenant context in logs
- **WHEN** a request is processed for a specific tenant
- **THEN** all log entries for that request include the `tenantId` field

#### Scenario: No PII in logs
- **WHEN** any log entry is written
- **THEN** the entry MUST NOT contain personally identifiable information (names, addresses, phone numbers of people experiencing homelessness)

### Requirement: metrics-collection
The system SHALL expose Micrometer metrics for operational monitoring.

#### Scenario: API latency metrics
- **WHEN** an API request completes
- **THEN** the system records a timer metric with tags: endpoint, method, status, tenantId

#### Scenario: Cache metrics
- **WHEN** a cache operation occurs (hit, miss, eviction)
- **THEN** the system records a counter metric with tags: cache_name, result (hit/miss/eviction)

#### Scenario: Metrics endpoint
- **WHEN** a request is sent to GET `/actuator/prometheus`
- **THEN** the system returns all metrics in Prometheus exposition format

#### Scenario: Metrics endpoint requires authentication
- **WHEN** an unauthenticated request is sent to GET `/actuator/prometheus` on the application port
- **THEN** the system returns 401 Unauthorized (FABT handles DV shelter data — metrics must not be publicly exposed)

#### Scenario: Management port allows unauthenticated scraping
- **WHEN** `management.server.port` is configured (dev --observability mode)
- **THEN** actuator endpoints on the management port are accessible without authentication
- **AND** the application API on the main port remains fully secured

### Requirement: data-age-tracking
The system SHALL track and expose the age of data to callers so that stale data is identifiable. Applies to shelter list, shelter detail, and bed availability query endpoints -- these are the responses where data freshness matters for outreach workers making real-time decisions. When availability snapshots exist, `data_age_seconds` is computed from `bed_availability.snapshot_ts` (the most recent snapshot for the shelter or population type), not from `shelter.updated_at`. The `shelter.updated_at` timestamp reflects profile edits (name, address, constraints), while `snapshot_ts` reflects the actual availability data freshness that outreach workers depend on.

#### Scenario: API response includes data age
- **WHEN** a GET `/api/v1/shelters`, GET `/api/v1/shelters/{id}`, or POST `/api/v1/queries/beds` response is returned
- **THEN** the response includes a `data_age_seconds` field calculated from the most recent `snapshot_ts` in the `bed_availability` table for the relevant shelter(s)
- **AND** if no availability snapshot exists for a shelter, `data_age_seconds` falls back to `shelter.updated_at`

#### Scenario: Data age in cache responses
- **WHEN** a shelter or availability response is served from cache
- **THEN** `data_age_seconds` reflects the time since the original `snapshot_ts`, not the time since the data was cached
- **AND** the value is recomputed on each response (current time minus snapshot_ts) so it increases even while the data is cached

#### Scenario: Data freshness enum included
- **WHEN** a GET `/api/v1/shelters`, GET `/api/v1/shelters/{id}`, or POST `/api/v1/queries/beds` response is returned
- **THEN** the response includes a `data_freshness` field derived from `data_age_seconds`: FRESH (< 7200s), AGING (7200-28800s), STALE (> 28800s), UNKNOWN (no snapshot and no updated_at)

#### Scenario: data_age_seconds from availability snapshot
- **WHEN** Shelter A has a profile `updated_at` of 3 hours ago and a `bed_availability.snapshot_ts` of 30 minutes ago
- **THEN** the `data_age_seconds` for Shelter A is approximately 1800 (30 minutes), not 10800 (3 hours)
- **AND** the `data_freshness` is FRESH because 1800 < 7200
- **AND** when Shelter B has a profile `updated_at` of 1 hour ago but no availability snapshots, `data_age_seconds` is approximately 3600 (1 hour) computed from `updated_at`

### Requirement: cross-tenant-404-counter
The system SHALL emit a Micrometer counter `fabt.security.cross_tenant_404s` each time `GlobalExceptionHandler` returns HTTP 404 for a request against a tenant-owned resource endpoint. The counter SHALL be tagged by `resource_type` (e.g., `shelter`, `api_key`, `oauth2_provider`, `subscription`, `totp`, `access_code`, `referral`). The counter MUST NOT attempt to distinguish "valid UUID in another tenant" from "UUID does not exist anywhere" — doing so would require a cross-tenant lookup, defeating isolation. The counter is intended for spike detection, not per-event attribution; attribution belongs to audit logs.

#### Scenario: Counter increments on cross-tenant 404
- **GIVEN** a Tenant A admin sends GET `/api/v1/api-keys/{tenantB-uuid}`
- **WHEN** the service returns 404 via the standard `findByIdAndTenantId` → `NoSuchElementException` path
- **AND** `GlobalExceptionHandler` maps the exception to HTTP 404
- **THEN** `fabt.security.cross_tenant_404s{resource_type="api_key"}` increments by 1

#### Scenario: Counter increments on 404 for nonexistent UUID
- **GIVEN** a Tenant A admin sends GET `/api/v1/api-keys/00000000-0000-0000-0000-000000000000`
- **WHEN** the service returns 404 because the UUID exists nowhere
- **THEN** `fabt.security.cross_tenant_404s{resource_type="api_key"}` increments by 1
- **AND** the counter emission is identical to the cross-tenant case (the handler cannot and does not distinguish)

#### Scenario: Counter does not increment on 200 or on unrelated 404s
- **GIVEN** a Tenant A admin sends GET `/api/v1/api-keys/{tenantA-uuid}` and the API key exists in tenant A
- **WHEN** the service returns 200
- **THEN** `fabt.security.cross_tenant_404s` does NOT increment
- **AND** 404s against non-tenant-owned endpoints (e.g., a typo in the path itself like `/api/v1/nonexistent`) do not increment the counter

### Requirement: cross-tenant-404-grafana-panel
The Grafana dashboard SHALL include a panel visualizing the rate of `fabt.security.cross_tenant_404s` per minute, stacked by `resource_type`. The panel SHALL carry a note describing the threshold-based alert guidance (spike-vs-baseline, not absolute rate) so operators know how to interpret the series.

#### Scenario: Panel renders after deploy
- **GIVEN** the v0.XX deploy lands and at least one 404 has fired against a tenant-owned endpoint post-deploy
- **WHEN** an operator opens the FABT security dashboard in Grafana
- **THEN** the "Cross-tenant 404s per minute (by resource)" panel renders with at least one data point
- **AND** the panel description text explains that absolute rate is not actionable; a 5× spike from baseline is the alert criterion

#### Scenario: Panel documents threshold guidance
- **WHEN** an operator reads the panel description
- **THEN** they see plain-language guidance: "Spikes in this counter can indicate UUID-probing attacks against tenant isolation. A sustained 5× spike from the weekly baseline is the alert threshold. A flat baseline of 1-5 per hour is normal (user typos, race conditions during resource expiry)."
