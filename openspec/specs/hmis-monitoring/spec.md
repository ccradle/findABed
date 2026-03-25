# Capability: hmis-monitoring

## Purpose
Provides operational monitoring for the HMIS bridge via Grafana dashboards and Prometheus metrics, available when the observability stack is active.

## Requirements

### Requirement: hmis-grafana-dashboard
The system SHALL provide a Grafana dashboard for HMIS bridge operational monitoring. Available only when the observability stack is active.

#### Scenario: Dashboard shows push rate per vendor
- **WHEN** an operator views the HMIS Bridge Grafana dashboard
- **THEN** they see push rate per vendor over time

#### Scenario: Dashboard shows failure rate and dead letter count
- **WHEN** pushes have failed
- **THEN** the dashboard shows failure rate and current dead letter queue size

#### Scenario: Dashboard shows circuit breaker state
- **WHEN** a vendor circuit breaker is open
- **THEN** the dashboard shows OPEN state for that vendor

#### Scenario: Dashboard not available without observability stack
- **WHEN** the system runs without --observability
- **THEN** the Grafana dashboard is not provisioned (Grafana not running)

### Requirement: hmis-prometheus-metrics
The system SHALL emit Micrometer metrics for HMIS bridge operations.

#### Scenario: Push counter increments on each push attempt
- **WHEN** a push is attempted
- **THEN** `fabt_hmis_push_total{vendor=...}` counter increments

#### Scenario: Push duration recorded
- **WHEN** a push completes (success or failure)
- **THEN** `fabt_hmis_push_duration_seconds{vendor=...}` timer records the duration

#### Scenario: Dead letter gauge reflects current count
- **WHEN** dead letter entries exist
- **THEN** `fabt_hmis_dead_letter_count` gauge reflects the current count
