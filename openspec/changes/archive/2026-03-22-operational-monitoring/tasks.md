## 1. Dependencies + Configuration

- [x] 1.1 Add Maven dependencies: `micrometer-tracing-bridge-otel`, `opentelemetry-exporter-otlp`, `resilience4j-spring-boot3`, `resilience4j-micrometer`
- [x] 1.2 Configure OTel tracing in `application.yml`: OTLP endpoint (default localhost:4318), sampling probability (default 0.0 = disabled)
- [x] 1.3 Configure Resilience4J circuit breakers in `application.yml`: `noaa-api` (for temperature monitor), `webhook-delivery` (for subscription module)
- [x] 1.4 Add observability config schema to tenant config JSONB: `observability.prometheus_enabled`, `observability.tracing_enabled`, `observability.tracing_endpoint`, monitor interval overrides

## 2. Custom Micrometer Metrics

- [x] 2.1 Create `ObservabilityMetrics` component: inject `MeterRegistry`, define all gauges (surge active, stale shelter count, DV canary pass)
- [x] 2.2 Instrument `BedSearchService.search()`: counter `fabt.bed.search.count` (tag: populationType) + timer `fabt.bed.search.duration`
- [x] 2.3 Instrument `AvailabilityService.createSnapshot()`: counter `fabt.availability.update.count` (tags: shelterId, actor)
- [x] 2.4 Instrument `ReservationService`: counter `fabt.reservation.count` (tag: status) on each state transition
- [x] 2.5 Instrument `SurgeEventService`: gauge `fabt.surge.active` (1 if active, 0 if not)
- [x] 2.6 Instrument webhook delivery in `SubscriptionService`: counter `fabt.webhook.delivery.count` (tags: event_type, status) + timer `fabt.webhook.delivery.duration`

## 3. Operational Monitors (@Scheduled)

- [x] 3.1 Create `OperationalMonitorService`: @Scheduled stale shelter detection (query shelters with no snapshot in 8+ hours), publish `fabt.shelter.stale.count` gauge, log WARNING per stale shelter
- [x] 3.2 Add DV canary monitor: @Scheduled query bed search as non-DV context, publish `fabt.dv.canary.pass` gauge (1=pass, 0=fail), log CRITICAL on failure
- [x] 3.3 Add temperature/surge gap monitor: @Scheduled query NOAA API (Resilience4J circuit breaker), check for active surge, log WARNING on mismatch. Configure pilot city coordinates in application.yml.

## 4. Runtime Configuration

- [x] 4.1 Create `ObservabilityConfigService`: reads observability settings from tenant config JSONB, caches with refresh interval, provides `isTracingEnabled()`, `isPrometheusEnabled()`, `getMonitorIntervals()`
- [x] 4.2 Wire tracing sampling probability to `ObservabilityConfigService` — when tracing toggled on, set probability to 1.0; when off, 0.0
- [x] 4.3 Add admin API endpoint or extend tenant config API to update observability settings at runtime

## 5. Optional Grafana + Docker Compose

- [x] 5.1 Create `grafana/provisioning/datasources/fabt-datasources.yaml`: Prometheus datasource (http://prometheus:9090)
- [x] 5.2 Create `grafana/provisioning/dashboards/fabt-operations.json`: bed search rate, availability updates, reservation lifecycle, stale shelter gauge, DV canary status, surge active indicator
- [x] 5.3 Add Prometheus + Grafana + Jaeger + OTel Collector to `docker-compose.yml` under `profiles: [observability]` — not started by default
- [x] 5.4 Create `prometheus.yml` scrape config targeting backend at :8080/actuator/prometheus
- [x] 5.5 Wire Grafana volume mounts in `docker-compose.yml`: `./grafana/dashboards` → `/var/lib/grafana/dashboards`, `./grafana/provisioning/dashboards` → `/etc/grafana/provisioning/dashboards`, `./grafana/provisioning/datasources` → `/etc/grafana/provisioning/datasources` (portfolio Lesson 10 — files alone don't load without mount wiring)

## 6. Documentation

- [x] 6.1 Create `docs/runbook.md`: operational runbook covering all three monitors (stale data, DV canary, temperature/surge gap) — investigation steps, escalation paths, resolution actions
- [x] 6.2 Update README with observability section: how to enable metrics, tracing, Grafana; docker compose --profile observability

## 7. Testing — Unit + Integration

- [x] 7.1 Create `ObservabilityMetricsTest`: unit test using `SimpleMeterRegistry` — verify all gauges and counters register correctly without Spring context
- [x] 7.2 Create `OperationalMonitorServiceTest`: unit test stale shelter detection with mocked repository returning shelters with no snapshot in 8+ hours, verify gauge value and WARNING log
- [x] 7.3 Create `OperationalMonitorServiceTest`: unit test DV canary with mocked bed search returning a DV shelter, verify gauge=0 and CRITICAL log
- [x] 7.4 Create `OperationalMonitorServiceTest`: unit test temperature/surge gap with mocked NOAA client returning <32°F and no active surge, verify WARNING log
- [x] 7.5 Create `MetricsIntegrationTest` with `@AutoConfigureObservability`: verify `/actuator/prometheus` returns 200 and contains `jvm_memory_used_bytes` (smoke test — portfolio Lesson 40)
- [x] 7.6 `MetricsIntegrationTest`: trigger bed search via MockMvc, then assert `fabt_bed_search_count_total` appears in `/actuator/prometheus` response (portfolio Lesson 23: counter only appears after first increment)
- [x] 7.7 `MetricsIntegrationTest`: verify Resilience4J circuit breaker metrics (`resilience4j_circuitbreaker_state`) exposed via Prometheus endpoint

## 8. Testing — Karate @observability Features (Optional)

- [x] 8.1 Create `get-prometheus.feature` helper (`@ignore` tag): fetch `/actuator/prometheus`, return raw text. Include JS `parseCounter(text, metricName)` function for extracting metric values
- [x] 8.2 Create `metrics-polling.feature` (`@observability` tag): record baseline counter, trigger domain operation, poll Prometheus endpoint in loop (up to 30s), assert counter incremented
- [x] 8.3 Create `get-traces.feature` helper (`@ignore` tag): fetch traces from Jaeger REST API `GET /api/traces?service=finding-a-bed-tonight&limit=20`
- [x] 8.4 Create `trace-e2e.feature` (`@observability` tag): make API request, poll Jaeger API (up to 30s), assert trace exists with `processes[key].serviceName == 'finding-a-bed-tonight'` (NOT operationName — portfolio Lesson 28)
- [x] 8.5 Create `grafana-health.feature` (`@observability` tag): `GET /api/health` assert 200, `GET /api/search?query=FABT` with Basic auth assert dashboard found
- [x] 8.6 Add `ObservabilityRunner.java` Karate runner for `classpath:karate/observability` with `parallel(1)` — sequential execution required for trace polling
- [x] 8.7 Add `jaegerBaseUrl` and `grafanaBaseUrl` to `karate-config.js` with environment-specific resolution (local: localhost, docker: container names)

## 9. dev-start.sh Observability Flag

- [x] 9.1 Add `--observability` flag parsing to `dev-start.sh`: detect flag in any argument position, set `OBSERVABILITY=true`
- [x] 9.2 When `--observability` is set, start docker compose with `--profile observability` in addition to default services
- [x] 9.3 When `--observability` is set, wait for Grafana health (`GET http://localhost:3000/api/health`) before reporting stack ready
- [x] 9.4 Add Grafana (`:3000`), Jaeger (`:16686`), Prometheus (`:9090`) URLs to "Stack is running!" output when `--observability` is active
- [x] 9.5 Update `stop` command to tear down observability containers (ensure `docker compose --profile observability down` is used)

## 10. Dev Prometheus Scraping (Management Port)

- [x] 10.1 Update `dev-start.sh`: when `--observability` is set, start backend with `-Dmanagement.server.port=9090` so actuator endpoints run on a separate unauthenticated port
- [x] 10.2 Update `prometheus.yml` scrape target from `host.docker.internal:8080` to `host.docker.internal:9090`
- [x] 10.3 Add `application-observability.yml` profile config: set `management.server.port=9090` as a Spring profile activated by env var, so the management port separation is explicit and documented

## 11. Admin UI — Observability Tab

- [x] 11.1 Add `'observability'` to `TabKey` type and `TABS` array in `AdminPanel.tsx`
- [x] 11.2 Add i18n message key `admin.tab.observability` to English and Spanish message bundles
- [x] 11.3 Create `ObservabilityTab` component: on mount, `GET /api/v1/tenants/{id}/observability` to load current config
- [x] 11.4 Render toggle switches for `prometheus_enabled` and `tracing_enabled` using inline styles matching existing tabs
- [x] 11.5 Render text input for `tracing_endpoint` (default: `http://localhost:4318/v1/traces`)
- [x] 11.6 Render numeric inputs for monitor intervals: stale shelter (min), DV canary (min), temperature (min)
- [x] 11.7 Render numeric input for temperature threshold (°F, default: 32). Label: "Surge activation threshold"
- [x] 11.8 Add Save button: `PUT /api/v1/tenants/{id}/observability` with the full config object, show success/error feedback
- [x] 11.9 Add Playwright test: admin navigates to Observability tab, toggles tracing on, saves, verifies config persists on reload

## 12. Temperature/Surge Gap Enhancements

- [x] 12.1 Change default NOAA station from KORD (Chicago) to KRDU (Raleigh-Durham) in `application.yml` and default coordinates to 35.8776, -78.7875
- [x] 12.2 Update `ObservabilityConfigService` and `ObservabilityConfig` record: add `temperature_threshold_f` field (default: 32), parse from tenant config JSONB
- [x] 12.3 Update `ObservabilityMetrics`: add `fabt.temperature.surge.gap` gauge (AtomicInteger, 1=gap detected, 0=no gap)
- [x] 12.4 Update `OperationalMonitorService.checkTemperatureSurgeGap()`: use configurable threshold from `ObservabilityConfigService` instead of hardcoded 32°F, publish `fabt.temperature.surge.gap` gauge, cache latest temperature reading + gap state in instance fields
- [x] 12.5 Add `TemperatureStatus` record: `temperatureF`, `stationId`, `thresholdF`, `surgeActive`, `gapDetected`, `lastChecked`
- [x] 12.6 Create `GET /api/v1/monitoring/temperature` endpoint in a new `MonitoringController` (authenticated, any role): returns cached `TemperatureStatus` from `OperationalMonitorService` — no extra NOAA call
- [x] 12.7 Update seed data: add `temperature_threshold_f: 32` to observability section of tenant config JSONB
- [x] 12.8 Update `OperationalMonitorServiceTest`: test configurable threshold (mock config returning 40°F threshold, assert gap detected at 35°F)
- [x] 12.9 Update Grafana dashboard `fabt-operations.json`: add "Temperature/Surge Gap" stat panel for `fabt_temperature_surge_gap` gauge (green=0, red=1)
- [x] 12.10 Update `docs/runbook.md`: add temperature threshold configurability and Admin UI reference

## 13. Temperature Status UI Display

- [x] 13.1 Add temperature status section to `ObservabilityTab`: call `GET /api/v1/monitoring/temperature` on mount, display current temp, station ID, threshold, and last checked timestamp
- [x] 13.2 Add warning banner component: amber background when `gapDetected=true`, showing "XX°F — Below threshold (YY°F). No active surge. Consider activating surge mode." Green when no gap.
- [x] 13.3 Add i18n message keys for temperature status labels and warning text (English and Spanish)
- [x] 13.4 Add Playwright test: verify temperature display shows on Observability tab, verify warning banner appears when gap is detected (may require test fixture or mock)
