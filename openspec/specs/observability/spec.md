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

### Requirement: data-age-tracking
The system SHALL track and expose the age of data to callers so that stale data is identifiable. Applies to shelter list and shelter detail endpoints — these are the responses where data freshness matters for outreach workers making real-time decisions.

#### Scenario: API response includes data age
- **WHEN** a GET `/api/v1/shelters` or GET `/api/v1/shelters/{id}` response is returned
- **THEN** the response includes a `data_age_seconds` field calculated from the most recent `updated_at` or `snapshot_ts` timestamp in the returned data

#### Scenario: Data age in cache responses
- **WHEN** a shelter response is served from cache
- **THEN** `data_age_seconds` reflects the time since the original data was fetched, not the time since it was cached

#### Scenario: Data freshness enum included
- **WHEN** a GET `/api/v1/shelters` or GET `/api/v1/shelters/{id}` response is returned
- **THEN** the response includes a `data_freshness` field derived from `data_age_seconds`: FRESH (< 7200s), AGING (7200-28800s), STALE (> 28800s), UNKNOWN (no snapshot)
