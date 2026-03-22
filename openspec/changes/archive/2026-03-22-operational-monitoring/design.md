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
- Observability test coverage (unit, integration, Karate BDD) following portfolio-test-automation patterns
- Developer tooling (`dev-start.sh --observability` flag for optional monitoring stack)

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
| `fabt.temperature.surge.gap` | Gauge | `tenant` | 1 if temp below threshold with no active surge, 0 otherwise |

### D2: OpenTelemetry tracing — optional, runtime-toggled

Add `micrometer-tracing-bridge-otel` + `opentelemetry-exporter-otlp` dependencies. Configure OTLP endpoint in `application.yml` with a default of `http://localhost:4318/v1/traces` (no-op if nothing is listening).

Runtime toggle: tenant config JSONB field `observability.tracing_enabled` (default `false`). When disabled, sampling probability is 0.0. When enabled, 1.0 (sample everything — appropriate for pilot scale).

### D3: Prometheus endpoint — secured, runtime-toggled

The `/actuator/prometheus` endpoint is already exposed but remains behind `anyRequest().authenticated()` — it is NOT `permitAll()`. This is intentional: FABT handles DV shelter data and must not expose business metrics publicly (OWASP A01, Prometheus security model).

**Dev/local:** When `--observability` is used, `dev-start.sh` starts the backend with `management.server.port=9090`. This runs actuator endpoints on a separate port accessible to the Prometheus container without JWT auth, while the application API on `:8080` stays fully secured. The `prometheus.yml` scrape config targets `host.docker.internal:9090`. Integration tests continue to use auth headers against `:8080`.
**Production:** Use `management.server.port` on a separate port bound to `127.0.0.1` with firewall rules restricting access to the monitoring stack. This provides network-level isolation without weakening application-level security.

Add tenant config JSONB field `observability.prometheus_enabled` (default `true` — it's low-cost and useful even without an external Prometheus).

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
- `@Scheduled` with configurable interval (default: every 60 minutes, configurable via tenant config `monitor_temperature_interval_minutes`)
- Default NOAA station: Raleigh-Durham (KRDU), coordinates 35.8776°N, 78.7875°W — configurable via env vars `FABT_NOAA_STATION`, `FABT_NOAA_LAT`, `FABT_NOAA_LON`
- Temperature threshold: configurable via tenant config `temperature_threshold_f` (default: 32°F). Exposed in Admin UI
- If below threshold and no active surge, logs WARNING and publishes `fabt.temperature.surge.gap` gauge (1=gap detected, 0=no gap)
- Caches latest temperature reading and gap state for UI display via a new API endpoint
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
- Docker Compose `profiles: [observability]` for Prometheus + Grafana + Jaeger + OTel Collector — not started by default

**Grafana volume wiring** (portfolio Lesson 10): Creating dashboard JSON files alone is insufficient — they must be explicitly mounted into the Grafana container. The Grafana service in `docker-compose.yml` must include:
```yaml
grafana:
  volumes:
    - ./grafana/dashboards:/var/lib/grafana/dashboards
    - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards
    - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
```
This is a separate task from dashboard creation to avoid the wiring gap that burned the payments-kafka-streams project.

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
    "monitor_temperature_interval_minutes": 60,
    "temperature_threshold_f": 32
  }
}
```

Read at startup and on a refresh interval. Changes take effect without restart.

### D8: Observability testing strategy

Three tiers of testing, following patterns proven in portfolio-test-automation:

**Tier 1 — Unit tests (always run):**
- Test `ObservabilityMetrics` gauge/counter registration using `SimpleMeterRegistry` (no Spring context)
- Test `OperationalMonitorService` logic: stale shelter detection, DV canary assertion, temperature/surge gap detection — mock repositories and external APIs

**Tier 2 — Integration tests (always run, `@AutoConfigureObservability`):**
- Test `/actuator/prometheus` endpoint exposes custom metrics after triggering domain operations
- **Critical**: every test class asserting on `/actuator/prometheus` MUST carry `@AutoConfigureObservability` — without it, Spring Boot test auto-config disables PrometheusMeterRegistry and the endpoint returns 404 (portfolio Lesson 40)
- Prometheus smoke tests must assert on `jvm_memory_used_bytes` (always present at JVM startup), NOT custom counters that haven't fired yet (portfolio Lesson 23: Micrometer counters are lazily registered)
- Test custom counter increments by triggering a domain operation first, then asserting the counter value

**Tier 3 — Karate `@observability`-tagged features (optional, require observability stack):**
- **Metrics polling**: Helper feature fetches `/actuator/prometheus`, JS `parseCounter` function extracts specific metric values, baseline + polling loop pattern (up to 30s timeout)
- **Trace verification**: Poll Jaeger REST API (`GET /api/traces?service=finding-a-bed-tonight&limit=20`), assert by `processes[key].serviceName` (NOT operationName — portfolio Lesson 28), 30s polling timeout
- **Grafana dashboard presence**: `GET /api/health` (assert 200), `GET /api/search?query=FABT` with Basic auth (assert dashboard found) — no JSON schema validation needed (portfolio pattern)
- Tagged with `@observability` so they can be skipped in environments without the monitoring stack: `mvn test -Dkarate.options="--tags ~@observability"`
- Helper features (e.g., `get-prometheus.feature`, `get-traces.feature`) tagged with `@ignore` to prevent standalone execution by KarateRunner (portfolio Lesson 32)

### D9: dev-start.sh observability flag

Extend `dev-start.sh` with an `--observability` flag to optionally start the full monitoring stack:

```bash
./dev-start.sh                        # Current behavior (postgres + backend + frontend)
./dev-start.sh backend                # Current behavior (postgres + backend only)
./dev-start.sh --observability        # Full stack + Prometheus + Grafana + Jaeger + OTel Collector
./dev-start.sh backend --observability # Backend + observability (no frontend)
./dev-start.sh stop                   # Stops everything including observability containers
```

When `--observability` is passed:
- Start docker compose with `--profile observability` in addition to default services
- Start the backend with `-Dmanagement.server.port=9090` so Prometheus can scrape without JWT auth
- Wait for Grafana health (`GET http://localhost:3000/api/health`) before reporting ready
- Add Grafana (`:3000`), Jaeger (`:16686`), and Prometheus (`:9090`) URLs to the "Stack is running!" output
- The `stop` command must also tear down observability containers

### D10: Admin UI observability tab

Add an "Observability" tab to the existing `AdminPanel.tsx` tab bar (alongside users, shelters, apiKeys, imports, subscriptions, surge). The tab provides:

**Configuration section:**
- **Prometheus toggle** — on/off switch, calls `PUT /api/v1/tenants/{id}/observability`
- **Tracing toggle** — on/off switch
- **Tracing endpoint** — text input (default: `http://localhost:4318/v1/traces`)
- **Monitor intervals** — numeric inputs for stale shelter (min), DV canary (min), temperature (min)
- **Temperature threshold** — numeric input in °F (default: 32). Label: "Surge activation threshold"
- **Save button** — PUTs the full observability config object
- **Current status display** — shows current config values on load via `GET /api/v1/tenants/{id}/observability`

**Temperature/surge status section (live display):**
- **Current temperature** — fetched from a new backend endpoint `GET /api/v1/monitoring/temperature` that returns cached NOAA reading, station ID, and timestamp
- **Station info** — display the NOAA station ID (e.g., "KRDU — Raleigh-Durham")
- **Threshold indicator** — visual warning banner (amber/red) when current temperature is below the configured threshold AND no active surge. Green when no gap. Shows text like "28°F — Below threshold (32°F). No active surge. Consider activating surge mode."

**Backend API additions for temperature display:**
- `GET /api/v1/monitoring/temperature` — returns `{ temperatureF, stationId, threshold, surgeActive, gapDetected, lastChecked }`. Reads from cached state in `OperationalMonitorService` (no extra NOAA call). Requires authenticated user (any role).

Follows the existing AdminPanel patterns: uses `api.get()`/`api.put()`, `FormattedMessage` for i18n, inline styles matching other tabs. Requires PLATFORM_ADMIN role for config changes (inherited from AdminPanel's route guard). Temperature display is read-only and available to all authenticated admins.
