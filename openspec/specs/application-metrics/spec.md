## Purpose

Custom Micrometer metrics for domain operations, runtime-configurable via tenant config JSONB.

## Requirements

### Requirement: domain-metrics
The system SHALL publish custom Micrometer metrics for domain operations using the naming convention `fabt.{domain}.{action}` with appropriate tags. Metrics are automatically exposed via /actuator/prometheus when enabled.

#### Scenario: Bed search metrics published
- **WHEN** an outreach worker executes a bed search
- **THEN** `fabt.bed.search.count` counter increments with `populationType` tag
- **AND** `fabt.bed.search.duration` timer records the query latency

#### Scenario: Availability update metrics published
- **WHEN** a coordinator submits an availability update
- **THEN** `fabt.availability.update.count` counter increments with `shelterId` and `actor` tags

#### Scenario: Reservation metrics published
- **WHEN** a reservation state transition occurs (create, confirm, cancel, expire)
- **THEN** `fabt.reservation.count` counter increments with `status` tag

### Requirement: runtime-observable-config
The system SHALL allow observability features (Prometheus endpoint, OTel tracing, monitor intervals) to be toggled at runtime via tenant config JSONB without application restart.

#### Scenario: Toggle Prometheus endpoint
- **WHEN** an admin sets `observability.prometheus_enabled` to false in tenant config
- **THEN** the /actuator/prometheus endpoint stops exposing metrics

#### Scenario: Toggle OTel tracing
- **WHEN** an admin sets `observability.tracing_enabled` to true in tenant config
- **THEN** OpenTelemetry spans are generated for API requests and exported to the configured OTLP endpoint
