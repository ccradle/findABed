## Purpose

OpenTelemetry distributed tracing with runtime toggle via tenant config, Resilience4J circuit breaker metrics for external APIs.

## Requirements

### Requirement: otel-tracing
The system SHALL instrument API endpoints with OpenTelemetry spans via micrometer-tracing-bridge-otel. Tracing is disabled by default and enabled at runtime via tenant config. When enabled, spans are exported to a configurable OTLP endpoint. When disabled, sampling probability is 0.0 (zero overhead).

#### Scenario: Tracing enabled exports spans
- **WHEN** tracing is enabled and an OTLP collector is running
- **THEN** API request spans are exported with service name, operation, duration, and status

#### Scenario: Tracing disabled has zero overhead
- **WHEN** tracing is disabled (default)
- **THEN** no spans are created or exported and no performance impact occurs

### Requirement: resilience4j-metrics
The system SHALL publish Resilience4J circuit breaker metrics to Micrometer via the resilience4j-micrometer bridge for all external API calls (NOAA, webhook delivery).

#### Scenario: Circuit breaker metrics visible in Prometheus
- **WHEN** Prometheus endpoint is enabled and a circuit breaker is configured
- **THEN** metrics like `resilience4j_circuitbreaker_state` and `resilience4j_circuitbreaker_calls_seconds` are exposed
