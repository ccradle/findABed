## 1. Dependencies + Configuration

- [ ] 1.1 Add Maven dependencies: `micrometer-tracing-bridge-otel`, `opentelemetry-exporter-otlp`, `resilience4j-spring-boot3`, `resilience4j-micrometer`
- [ ] 1.2 Configure OTel tracing in `application.yml`: OTLP endpoint (default localhost:4318), sampling probability (default 0.0 = disabled)
- [ ] 1.3 Configure Resilience4J circuit breakers in `application.yml`: `noaa-api` (for temperature monitor), `webhook-delivery` (for subscription module)
- [ ] 1.4 Add observability config schema to tenant config JSONB: `observability.prometheus_enabled`, `observability.tracing_enabled`, `observability.tracing_endpoint`, monitor interval overrides

## 2. Custom Micrometer Metrics

- [ ] 2.1 Create `ObservabilityMetrics` component: inject `MeterRegistry`, define all gauges (surge active, stale shelter count, DV canary pass)
- [ ] 2.2 Instrument `BedSearchService.search()`: counter `fabt.bed.search.count` (tag: populationType) + timer `fabt.bed.search.duration`
- [ ] 2.3 Instrument `AvailabilityService.createSnapshot()`: counter `fabt.availability.update.count` (tags: shelterId, actor)
- [ ] 2.4 Instrument `ReservationService`: counter `fabt.reservation.count` (tag: status) on each state transition
- [ ] 2.5 Instrument `SurgeEventService`: gauge `fabt.surge.active` (1 if active, 0 if not)
- [ ] 2.6 Instrument webhook delivery in `SubscriptionService`: counter `fabt.webhook.delivery.count` (tags: event_type, status) + timer `fabt.webhook.delivery.duration`

## 3. Operational Monitors (@Scheduled)

- [ ] 3.1 Create `OperationalMonitorService`: @Scheduled stale shelter detection (query shelters with no snapshot in 8+ hours), publish `fabt.shelter.stale.count` gauge, log WARNING per stale shelter
- [ ] 3.2 Add DV canary monitor: @Scheduled query bed search as non-DV context, publish `fabt.dv.canary.pass` gauge (1=pass, 0=fail), log CRITICAL on failure
- [ ] 3.3 Add temperature/surge gap monitor: @Scheduled query NOAA API (Resilience4J circuit breaker), check for active surge, log WARNING on mismatch. Configure pilot city coordinates in application.yml.

## 4. Runtime Configuration

- [ ] 4.1 Create `ObservabilityConfigService`: reads observability settings from tenant config JSONB, caches with refresh interval, provides `isTracingEnabled()`, `isPrometheusEnabled()`, `getMonitorIntervals()`
- [ ] 4.2 Wire tracing sampling probability to `ObservabilityConfigService` — when tracing toggled on, set probability to 1.0; when off, 0.0
- [ ] 4.3 Add admin API endpoint or extend tenant config API to update observability settings at runtime

## 5. Optional Grafana + Docker Compose

- [ ] 5.1 Create `grafana/provisioning/datasources/fabt-datasources.yaml`: Prometheus datasource (http://prometheus:9090)
- [ ] 5.2 Create `grafana/provisioning/dashboards/fabt-operations.json`: bed search rate, availability updates, reservation lifecycle, stale shelter gauge, DV canary status, surge active indicator
- [ ] 5.3 Add Prometheus + Grafana + Jaeger + OTel Collector to `docker-compose.yml` under `profiles: [observability]` — not started by default
- [ ] 5.4 Create `prometheus.yml` scrape config targeting backend at :8080/actuator/prometheus

## 6. Documentation

- [ ] 6.1 Create `docs/runbook.md`: operational runbook covering all three monitors (stale data, DV canary, temperature/surge gap) — investigation steps, escalation paths, resolution actions
- [ ] 6.2 Update README with observability section: how to enable metrics, tracing, Grafana; docker compose --profile observability
