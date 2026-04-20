## ADDED Requirements

### Requirement: otel-baggage-tenant-id
The system SHALL propagate `fabt.tenant.id=<uuid>` as W3C `baggage` on every outgoing span (per G4) and attach `fabt.tenant.id` as a span resource attribute for Jaeger / Tempo filtering. No formal OpenTelemetry semantic convention exists for tenancy in 2026; the `fabt.*` namespace is used as the documented custom attribute.

#### Scenario: Span carries tenant baggage
- **WHEN** a request for tenant A produces a span
- **THEN** the span has `baggage: fabt.tenant.id=<tenantA-uuid>` on the OTel context
- **AND** the span resource attribute `fabt.tenant.id` is set to the same UUID

#### Scenario: Baggage propagates across virtual threads
- **GIVEN** a request on tenant A spawns child virtual threads
- **WHEN** child spans are emitted
- **THEN** each child span inherits the `fabt.tenant.id` baggage
- **AND** Jaeger trace view filters by tenant id correctly

#### Scenario: Tempo/Jaeger filter by tenant works
- **WHEN** an operator filters traces by `fabt.tenant.id=<tenantA>`
- **THEN** only tenant A's spans are returned
- **AND** traces from other tenants are not visible in the filtered view

### Requirement: per-tenant-grafana-alert-routing
The system SHALL route Grafana/Alertmanager alerts with a `tenant_id` label (per G5) to `tenant.oncall_email` (new column on `tenant`). Platform-wide on-call SHALL receive platform-scoped alerts; tenant on-call SHALL receive tenant-scoped alerts.

#### Scenario: Tenant-scoped alert routes to tenant on-call
- **GIVEN** tenant A has `oncall_email=oncall@tenantA.org` in the tenant table
- **WHEN** an alert fires with `tenant_id=<tenantA>` label
- **THEN** Alertmanager routes the notification to `oncall@tenantA.org`
- **AND** platform on-call does NOT receive the tenant-scoped alert

#### Scenario: Platform alert goes to platform on-call
- **GIVEN** an alert fires without a `tenant_id` label (e.g., node-level)
- **WHEN** routing evaluates
- **THEN** the alert routes to platform on-call only
- **AND** no tenant on-call is paged

#### Scenario: Alert label source is the metric
- **GIVEN** a metric `fabt_reservation_expiry_failures{tenant_id="<tenantA>"}` fires above threshold
- **WHEN** the alert evaluates
- **THEN** the tenant_id label is carried into the Alertmanager notification payload
- **AND** the routing tree dispatches to tenant A's channel

### Requirement: per-tenant-metric-cardinality-budget
The system SHALL document (per G6) a per-high-cardinality-metric cardinality budget. Metrics exceeding the budget SHALL have the `tenant_id` tag removed; per-tenant views SHALL use Grafana template variable `$tenant` instead.

#### Scenario: Budget documented per metric
- **GIVEN** `docs/observability/cardinality-budget.md` is published
- **WHEN** an operator reads it
- **THEN** each high-cardinality metric (e.g., `http_server_requests_seconds`) has a documented budget
- **AND** the document lists which metrics drop the `tenant_id` tag to stay within budget

#### Scenario: Over-budget metric drops tenant tag
- **GIVEN** `http_server_requests_seconds` × `tenant_id` × 15 histogram buckets × N tenants would exceed the budget
- **WHEN** the metric is emitted
- **THEN** the `tenant_id` tag is omitted
- **AND** per-tenant views are provided via `$tenant` template variable with label_values queries

#### Scenario: New high-cardinality metric added requires budget review
- **WHEN** a PR adds a new histogram metric with tenant_id
- **THEN** the PR checklist requires a cardinality-budget review
- **AND** the docs are updated with the new metric's budget

### Requirement: per-tenant-log-retention-policy
The system SHALL document (per G7) a per-tenant-class log retention policy: HIPAA tier = 6 years; VAWA tier = per OVW guidance; standard tier = 1 year. Retention SHALL be implemented via Loki retention rules when adopted, or via equivalent external log-store mechanism.

#### Scenario: Retention policy documented per tier
- **GIVEN** `docs/legal/log-retention-policy.md` is published
- **WHEN** an operator reads it
- **THEN** each tier's retention window is documented with source citation (HIPAA §164.316(b)(2) for 6 years, etc.)

#### Scenario: Retention enforced by Loki rule when adopted
- **GIVEN** Loki is the active log store
- **WHEN** a tenant A log line older than 1 year exists for a standard-tier tenant
- **THEN** the Loki retention rule purges the line
- **AND** HIPAA-tier logs persist for their full 6-year window per a separate rule

#### Scenario: Regulated tier retention enforced on silo'd store
- **GIVEN** a regulated-tier tenant is deployed in silo mode with its own log store
- **WHEN** retention rules apply to that silo
- **THEN** the tier's documented retention is honored independently of standard-tier rules

### Requirement: reverse-proxy-scope-orgid-enforcement
The system SHALL rewrite any `X-Scope-OrgID` / `X-Tenant-Id` header at the reverse proxy (per G8, D3) when Loki / Mimir adopt tenant-isolated storage. The nginx layer SHALL use `proxy_set_header` to REPLACE the client-supplied value with the authenticated JWT's `tenantId` — client-supplied values SHALL NOT reach Loki/Mimir.

#### Scenario: Client-supplied X-Scope-OrgID is overwritten
- **GIVEN** a user in tenant A sends a request with header `X-Scope-OrgID: <tenantB>`
- **WHEN** nginx processes the request
- **THEN** nginx replaces `X-Scope-OrgID` with the JWT-resolved `<tenantA>`
- **AND** the Loki/Mimir backend sees only the authenticated tenant ID

#### Scenario: Missing header is synthesized from JWT
- **GIVEN** a request arrives with no `X-Scope-OrgID` header
- **WHEN** nginx processes it
- **THEN** nginx adds `X-Scope-OrgID: <authenticated-tenant>` based on the JWT claim
- **AND** the backend consistently receives a tenant-bound header

#### Scenario: Unauthenticated request gets no tenant header
- **WHEN** an unauthenticated request reaches nginx
- **THEN** nginx strips any client-supplied `X-Scope-OrgID` header
- **AND** no tenant binding leaks through to downstream log stores

### Requirement: per-tenant-observability-read-access-regulated-tier
The system SHALL (regulated tier only, per G9) restrict tenant admins to read their own metrics/logs/traces via Grafana Organizations + Loki / Mimir `auth_enabled`. Standard tier SHALL remain operator-only observability.

#### Scenario: Regulated tenant admin sees only own data
- **GIVEN** a regulated-tier tenant R has a tenant admin with Grafana Organization R
- **WHEN** the admin opens a dashboard
- **THEN** only tenant R's metrics/logs/traces render
- **AND** no cross-tenant data appears in any panel

#### Scenario: Standard tier admin has no observability access
- **GIVEN** a standard-tier tenant S with no Grafana org
- **WHEN** the standard tier tenant admin logs in
- **THEN** no observability UI is exposed to them
- **AND** observability remains operator-only for standard tier

#### Scenario: Misconfigured org isolation fails CI
- **GIVEN** a regulated-tier Grafana org is provisioned
- **WHEN** the CI isolation test runs (simulate cross-org query)
- **THEN** the test asserts the org cannot see another tenant's data
- **AND** a misconfiguration fails the build

### Requirement: per-tenant-weather-station
The system SHALL resolve the NOAA weather station used for the surge-trigger temperature monitor per tenant. The `tenant.config` JSONB `observability` block SHALL support an optional `noaa_station_id` field; `OperationalMonitorService` SHALL fan out per tenant and call `NoaaClient.getCurrentTemperatureFahrenheit(stationId)` with that tenant's station; multiple tenants sharing a station SHALL share a single upstream fetch per monitor cycle. If `noaa_station_id` is absent or blank, the system SHALL fall back to the global `fabt.monitoring.noaa.station-id` property (default `KRDU`). The `/api/v1/monitoring/temperature` endpoint SHALL return the caller's tenant-scoped cached `TemperatureStatus` (including the actual station id used), not a global singleton.

This requirement captures **Option A** — the minimum-viable per-tenant station lookup. Option B (first-class typed `tenant.noaa_station_id` column + admin UI field + Flyway migration) and Option C (per-shelter or multi-station per tenant for large geographies) are out of scope for this change; they are tracked for a later phase pending warroom review + best-practices research (task 14.w-longterm).

#### Scenario: Tenant-specific station is queried
- **GIVEN** tenant A's `tenant.config.observability.noaa_station_id = "KAVL"`
- **WHEN** the hourly `checkTemperatureSurgeGap` monitor runs
- **THEN** `NoaaClient.getCurrentTemperatureFahrenheit("KAVL")` is invoked for tenant A
- **AND** the cached `TemperatureStatus` for tenant A has `stationId = "KAVL"`
- **AND** the global default station `KRDU` is NOT queried on behalf of tenant A

#### Scenario: Missing station falls back to global default
- **GIVEN** tenant B has no `noaa_station_id` in its config
- **WHEN** the monitor runs for tenant B
- **THEN** the global default (e.g., `KRDU`) is used
- **AND** the cached status reports `stationId = "KRDU"`

#### Scenario: Shared station fetches once per cycle
- **GIVEN** two tenants both have `noaa_station_id = "KAVL"`
- **WHEN** the monitor runs
- **THEN** `NoaaClient.getCurrentTemperatureFahrenheit("KAVL")` is invoked exactly once
- **AND** both tenants receive the same temperature reading for that cycle

#### Scenario: Temperature endpoint is tenant-scoped
- **GIVEN** tenant A is cached at 38°F/KAVL and tenant B is cached at 28°F/KEWN
- **WHEN** a user authenticated to tenant A calls `GET /api/v1/monitoring/temperature`
- **THEN** the response reports tenant A's reading (38°F, KAVL)
- **AND** tenant B's reading does not leak into the response

#### Scenario: NOAA failure for one station does not affect other tenants
- **GIVEN** tenant A uses KAVL (healthy) and tenant B uses a station returning null
- **WHEN** the monitor runs
- **THEN** tenant A's `TemperatureStatus` is cached successfully
- **AND** tenant B's per-tenant work is skipped without throwing, leaving the prior cached status (if any) intact
