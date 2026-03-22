## Context

The portfolio standard (customer-events-pipeline, telecom-flink-cep) uses Micrometer custom metrics + OpenTelemetry tracing + Prometheus endpoint + optional Grafana dashboards. FABT must match this pattern while being deployable on Oracle Cloud Always Free tier (single ARM VM, no managed monitoring services). All observability features must be runtime-configurable via tenant config JSONB — no restart required to enable/disable.

## Goals / Non-Goals

**Goals:**
- Custom Micrometer metrics matching portfolio naming convention (`fabt.{domain}.{action}`)
- OpenTelemetry tracing with OTLP exporter (toggle via tenant config)
- Prometheus endpoint (toggle via tenant config)
- In-app operational monitors (stale data, DV canary, temp/surge gap) as @Scheduled tasks
- Resilience4J circuit breaker metrics for external API calls
- Optional Grafana dashboards (example JSON, not required)
- Operational runbook

**Non-Goals:**
- Cloud-specific monitoring (AWS CloudWatch, Lambda, SNS, GCP Stackdriver)
- Mandatory external dependencies (Prometheus, Grafana, Jaeger must be optional)
- Real-time alerting infrastructure (email/Slack/PagerDuty integration — future work)
- Custom health indicators (Spring Actuator health is sufficient)

## Decisions

### D1: Custom metrics via MeterRegistry injection

Follow the customer-events-pipeline pattern: inject `MeterRegistry` and create counters/timers/gauges in service classes.

**Metrics to instrument:**

| Metric | Type | Tags | Description |
|--------|------|------|-------------|
| `fabt.bed.search.count` | Counter | `populationType`, `tenant` | Bed search queries |
| `fabt.bed.search.duration` | Timer | `populationType` | Bed search latency |
| `fabt.availability.update.count` | Counter | `shelterId`, `actor` | Availability snapshots created |
| `fabt.reservation.count` | Counter | `status`, `tenant` | Reservation state transitions |
| `fabt.surge.active` | Gauge | `tenant` | 1 if surge active, 0 if not |
| `fabt.shelter.stale.count` | Gauge | `tenant` | Shelters with no update in 8+ hours |
| `fabt.dv.canary.pass` | Gauge | `tenant` | 1 if DV canary passes, 0 if fails |
| `fabt.webhook.delivery.count` | Counter | `event_type`, `status` | Webhook delivery attempts |
| `fabt.webhook.delivery.duration` | Timer | `event_type` | Webhook delivery latency |

### D2: OpenTelemetry tracing — optional, runtime-toggled

Add `micrometer-tracing-bridge-otel` + `opentelemetry-exporter-otlp` dependencies. Configure OTLP endpoint in `application.yml` with a default of `http://localhost:4318/v1/traces` (no-op if nothing is listening).

Runtime toggle: tenant config JSONB field `observability.tracing_enabled` (default `false`). When disabled, sampling probability is 0.0. When enabled, 1.0 (sample everything — appropriate for pilot scale).

### D3: Prometheus endpoint — optional, runtime-toggled

The `/actuator/prometheus` endpoint is already exposed. Add tenant config JSONB field `observability.prometheus_enabled` (default `true` — it's low-cost and useful even without an external Prometheus).

### D4: Operational monitors as @Scheduled Spring tasks

Three monitors run inside the application JVM — no external Lambda or CloudWatch:

**Monitor 1 — Stale shelter detection:**
- `@Scheduled(fixedRate = 300_000)` (every 5 minutes)
- Query: shelters with no availability snapshot in 8+ hours
- Publishes `fabt.shelter.stale.count` gauge
- Logs WARNING-level structured JSON for each stale shelter

**Monitor 2 — DV canary:**
- `@Scheduled(fixedRate = 900_000)` (every 15 minutes)
- Calls own API as a non-DV user, asserts zero DV shelters in results
- Publishes `fabt.dv.canary.pass` gauge (1=pass, 0=fail)
- Logs CRITICAL-level structured JSON on failure

**Monitor 3 — Temperature/surge gap:**
- `@Scheduled(fixedRate = 3600_000)` (every hour)
- Checks NOAA API for pilot city temperature
- If below 32°F and no active surge, logs WARNING
- Uses Resilience4J circuit breaker for NOAA API calls

### D5: Resilience4J for external API calls

Add `resilience4j-spring-boot3` + `resilience4j-micrometer` dependencies. Configure circuit breakers for:
- NOAA API (temperature monitor)
- Webhook delivery (add metrics bridge to existing subscription module)

Circuit breaker metrics auto-publish to Micrometer via the `resilience4j-micrometer` bridge.

### D6: Optional Grafana dashboards

Provide example dashboards in `grafana/provisioning/dashboards/` — matching telecom-flink-cep pattern:
- `fabt-operations.json`: Bed search rate, availability update rate, reservation lifecycle, stale shelter gauge, DV canary status
- Prometheus datasource config in `grafana/provisioning/datasources/`
- Docker Compose `profiles: [observability]` for Prometheus + Grafana + Jaeger — not started by default

### D7: Runtime configuration via tenant config JSONB

Observability settings stored in tenant `config` JSONB alongside `hold_duration_minutes`:

```json
{
  "hold_duration_minutes": 45,
  "observability": {
    "prometheus_enabled": true,
    "tracing_enabled": false,
    "tracing_endpoint": "http://localhost:4318/v1/traces",
    "monitor_stale_interval_minutes": 5,
    "monitor_dv_canary_interval_minutes": 15,
    "monitor_temperature_interval_minutes": 60
  }
}
```

Read at startup and on a refresh interval. Changes take effect without restart.
