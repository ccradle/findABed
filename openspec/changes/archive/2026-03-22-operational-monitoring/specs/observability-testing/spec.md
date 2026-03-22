## ADDED Requirements

### Requirement: metrics-unit-tests
The system SHALL include unit tests for `ObservabilityMetrics` that verify gauge and counter registration using `SimpleMeterRegistry` without Spring context, and unit tests for `OperationalMonitorService` that verify stale shelter detection, DV canary logic, and temperature/surge gap detection using mocked repositories and external APIs.

#### Scenario: ObservabilityMetrics registers all gauges and counters
- **WHEN** `ObservabilityMetrics` is instantiated with a `SimpleMeterRegistry`
- **THEN** all expected gauges (`fabt.surge.active`, `fabt.shelter.stale.count`, `fabt.dv.canary.pass`) and counters (`fabt.bed.search.count`, `fabt.availability.update.count`, `fabt.reservation.count`, `fabt.webhook.delivery.count`) are registered

#### Scenario: Stale shelter monitor detects stale shelters
- **WHEN** the stale shelter monitor runs and the repository returns shelters with no snapshot in 8+ hours
- **THEN** the `fabt.shelter.stale.count` gauge reflects the correct count

#### Scenario: DV canary monitor detects DV shelter leak
- **WHEN** the DV canary monitor runs and the bed search returns a DV shelter for a non-DV query
- **THEN** the `fabt.dv.canary.pass` gauge is 0

#### Scenario: Temperature/surge gap monitor detects mismatch
- **WHEN** the temperature monitor runs and NOAA reports below 32F with no active surge
- **THEN** a warning is logged suggesting surge activation

### Requirement: metrics-integration-tests
The system SHALL include integration tests that verify custom Micrometer metrics are exposed via `/actuator/prometheus` after triggering domain operations. Tests MUST use `@AutoConfigureObservability` annotation (portfolio Lesson 40). Prometheus smoke tests MUST assert on `jvm_memory_used_bytes` for startup verification, not custom counters (portfolio Lesson 23: lazy registration).

#### Scenario: Prometheus endpoint exposes JVM metrics at startup
- **WHEN** the application starts and `/actuator/prometheus` is queried
- **THEN** `jvm_memory_used_bytes` is present in the response (always registered at JVM startup)

#### Scenario: Custom counter appears after domain operation
- **WHEN** a bed search is executed and `/actuator/prometheus` is queried
- **THEN** `fabt_bed_search_count_total` appears in the response with the correct tags

#### Scenario: Resilience4J circuit breaker metrics exposed
- **WHEN** Prometheus endpoint is enabled and circuit breakers are configured
- **THEN** `resilience4j_circuitbreaker_state` and `resilience4j_circuitbreaker_calls_seconds` are exposed

### Requirement: observability-karate-features
The system SHALL include Karate BDD features tagged with `@observability` that verify metrics polling, OTel trace export, and Grafana dashboard presence when the observability stack is running. These tests are optional and skippable via `--tags ~@observability`.

#### Scenario: Karate metrics polling verifies counter increment
- **WHEN** a domain operation is triggered and the Prometheus endpoint is polled (up to 30s)
- **THEN** the custom counter value has incremented from the baseline

#### Scenario: Karate trace verification via Jaeger API
- **WHEN** an API request is made with tracing enabled and the Jaeger API is polled (up to 30s)
- **THEN** a trace with `serviceName: 'finding-a-bed-tonight'` appears in the `processes` map

#### Scenario: Karate Grafana dashboard presence check
- **WHEN** Grafana is running and `GET /api/search?query=FABT` is called with Basic auth
- **THEN** the FABT operations dashboard is found in the response

### Requirement: dev-start-observability-flag
The `dev-start.sh` script SHALL accept an `--observability` flag that starts the full monitoring stack (Prometheus, Grafana, Jaeger, OTel Collector) alongside the development stack. The `stop` command SHALL tear down observability containers. The "Stack is running!" output SHALL include Grafana, Jaeger, and Prometheus URLs when the flag is used.

#### Scenario: Start with observability flag
- **WHEN** `./dev-start.sh --observability` is run
- **THEN** Prometheus, Grafana, Jaeger, and OTel Collector containers start alongside the standard stack
- **AND** the backend starts with `management.server.port=9090` for unauthenticated Prometheus scraping
- **AND** Grafana is available at port 3000 with the FABT dashboard pre-loaded
- **AND** the output includes URLs for Grafana, Jaeger, and Prometheus

#### Scenario: Prometheus scrapes metrics via management port
- **WHEN** the stack is running with `--observability`
- **THEN** Prometheus can scrape `host.docker.internal:9090/actuator/prometheus` without authentication
- **AND** the application API on `:8080` remains fully secured

#### Scenario: Stop includes observability containers
- **WHEN** `./dev-start.sh stop` is run after starting with `--observability`
- **THEN** all observability containers are also stopped and removed

#### Scenario: Start without observability flag unchanged
- **WHEN** `./dev-start.sh` is run without the `--observability` flag
- **THEN** behavior is identical to the current script (no observability containers started)

### Requirement: observability-admin-ui
The AdminPanel SHALL include an "Observability" tab accessible to PLATFORM_ADMIN users that displays and allows editing of observability settings (Prometheus toggle, tracing toggle, tracing endpoint, monitor intervals) without requiring API calls.

#### Scenario: Admin views current observability config
- **WHEN** a PLATFORM_ADMIN navigates to the Admin Panel and clicks the "Observability" tab
- **THEN** the current observability settings are displayed (Prometheus enabled, tracing enabled/disabled, endpoint, intervals)

#### Scenario: Admin toggles tracing on
- **WHEN** the admin toggles the tracing switch to ON and clicks Save
- **THEN** `PUT /api/v1/tenants/{id}/observability` is called with `tracing_enabled: true`
- **AND** the UI reflects the updated state

#### Scenario: Admin updates monitor intervals
- **WHEN** the admin changes the stale shelter interval to 10 minutes and clicks Save
- **THEN** the config is persisted and the monitor picks up the new interval within 60 seconds
