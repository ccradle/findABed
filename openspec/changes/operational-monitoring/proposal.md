## Why

The platform has basic observability (structured logging, health probes) but lacks domain-specific metrics, distributed tracing, and operational monitors for failure modes that shelter coordinators won't report and outreach workers won't notice. The first deployment target is Oracle Cloud Always Free tier (single ARM VM) — monitoring must be cloud-agnostic, self-contained within the application, and optionally extensible with Prometheus, Grafana, OTel Collector, and Jaeger when available.

Additionally, the portfolio standard (customer-events-pipeline, telecom-flink-cep) establishes Micrometer custom metrics + OpenTelemetry tracing as baseline observability. FABT must match this standard.

## What Changes

- **Custom Micrometer metrics**: Domain-specific counters, timers, and gauges for bed search, availability updates, reservations, surge events, and DV canary checks
- **OpenTelemetry tracing**: Distributed trace spans on API endpoints, configurable via tenant config (runtime toggle)
- **Prometheus endpoint**: `/actuator/prometheus` gated behind tenant config toggle (runtime enable/disable)
- **Operational monitors as @Scheduled tasks**: Stale shelter detection, DV canary check, temperature/surge gap alert — all run inside the application (no external Lambda/CloudWatch), results published as Micrometer metrics and logged as structured JSON
- **Resilience4J integration**: Circuit breaker metrics published to Micrometer for external API calls (NOAA, webhook delivery)
- **Grafana dashboard examples**: Provisioned JSON dashboards in `grafana/` directory — optional, not required for deployment
- **Operational runbook**: `docs/runbook.md` covering all monitor types and response procedures

## Capabilities

### New Capabilities

- `application-metrics`: Custom Micrometer counters/timers/gauges for domain operations
- `distributed-tracing`: OpenTelemetry span instrumentation with runtime toggle
- `operational-monitors`: In-app scheduled monitors (stale data, DV canary, temp/surge gap)
- `grafana-dashboards`: Optional provisioned dashboards for Prometheus + PostgreSQL

### Modified Capabilities

- `observability`: Extended with custom metrics, OTel tracing, Resilience4J metric bridge
- `deployment-profiles`: Observability features configurable via tenant config JSONB (runtime)

## Impact

- **New files**: `ObservabilityMetrics.java` (custom metrics), `OperationalMonitorService.java` (scheduled monitors), `grafana/` directory with example dashboards, `docs/runbook.md`
- **Modified files**: `pom.xml` (OTel + Resilience4J deps), `application.yml` (tracing config), `docker-compose.yml` (optional Prometheus/Grafana/Jaeger services), tenant config schema
- **No cloud-specific resources**: No Lambda, CloudWatch, SNS, or S3. Everything runs inside the application JVM.
- **Runtime configurable**: Prometheus endpoint, OTel tracing, and monitor intervals toggled via tenant config JSONB + admin API
