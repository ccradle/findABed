## ADDED Requirements

### Requirement: otel-baggage-tenant-id-propagation
The system SHALL propagate `fabt.tenant.id` (per G4) as W3C `baggage` and as a span resource attribute on every span. The `fabt.*` namespace is used as the documented custom attribute because no formal OpenTelemetry semantic convention exists for tenancy in 2026.

#### Scenario: Baggage set on tenant request
- **WHEN** a request for tenant A produces a span
- **THEN** the span has `baggage: fabt.tenant.id=<tenantA-uuid>` on the OTel context
- **AND** the span resource attribute `fabt.tenant.id` equals the same UUID

#### Scenario: Baggage inherited by child virtual threads
- **GIVEN** a parent span for tenant A spawns child virtual threads
- **WHEN** child spans are emitted
- **THEN** each child span inherits the `fabt.tenant.id` baggage
- **AND** the inheritance is verified in the OTel integration test

#### Scenario: Jaeger filter by tenant works
- **WHEN** an operator filters traces by `fabt.tenant.id=<tenantA>`
- **THEN** only tenant A's spans are returned
- **AND** no spans from other tenants leak into the filtered view

### Requirement: per-tenant-grafana-alert-routing
The system SHALL route alerts with `tenant_id` label (per G5) to `tenant.oncall_email`. Platform-wide on-call SHALL receive platform-scoped alerts; tenant on-call SHALL receive tenant-scoped alerts.

#### Scenario: Tenant-scoped alert routes to tenant
- **GIVEN** tenant A has `oncall_email=oncall@tenantA.org`
- **WHEN** a metric with `tenant_id=<tenantA>` fires an alert
- **THEN** Alertmanager delivers the notification to `oncall@tenantA.org`
- **AND** platform on-call does not receive this alert

#### Scenario: Platform-wide alert unaffected
- **GIVEN** an alert with no `tenant_id` label (e.g., node-level CPU)
- **WHEN** routing evaluates
- **THEN** the platform on-call receives the alert
- **AND** no tenant on-call is paged

### Requirement: per-tenant-metric-cardinality-budget
The system SHALL document (per G6) a per-high-cardinality-metric cardinality budget. Metrics exceeding the budget SHALL have `tenant_id` tag removed; per-tenant views SHALL use the Grafana template variable `$tenant`.

#### Scenario: Budget documented at docs/observability/cardinality-budget.md
- **WHEN** an operator reads the budget document
- **THEN** each high-cardinality metric has a documented budget (e.g., `http_server_requests_seconds` budget based on N tenants × histogram buckets)
- **AND** metrics that exceed the budget are listed with tenant_id tag omitted

#### Scenario: Over-budget metric drops tenant tag
- **GIVEN** `http_server_requests_seconds` would exceed its budget with tenant_id
- **WHEN** the metric is emitted
- **THEN** the `tenant_id` tag is omitted from the metric series
- **AND** per-tenant views are provided via `$tenant` template variable with `label_values` queries

#### Scenario: New high-cardinality metric added requires budget review
- **WHEN** a PR adds a new histogram metric with a tenant_id tag
- **THEN** the PR checklist requires a cardinality-budget entry
- **AND** missing the entry blocks merge

### Requirement: per-tenant-log-retention
The system SHALL document and enforce (per G7) per-tenant-class log retention: HIPAA tier = 6 years; VAWA tier = per OVW guidance; standard tier = 1 year. Enforcement uses Loki retention rules when adopted, or equivalent external log-store mechanism.

#### Scenario: Retention policy documented
- **GIVEN** `docs/legal/log-retention-policy.md` is published
- **WHEN** an operator reads it
- **THEN** each tier's retention window is documented with source citation

#### Scenario: Loki retention rule enforces standard tier
- **GIVEN** Loki is the active log store
- **WHEN** a standard-tier tenant's log line ages past 1 year
- **THEN** the Loki retention rule purges the line
- **AND** HIPAA-tier tenant lines persist for their full 6-year window

#### Scenario: Regulated-tier silo retention independent
- **GIVEN** a regulated-tier tenant is deployed in silo mode with its own log store
- **WHEN** retention rules apply to the silo
- **THEN** the tier's documented retention holds independently of standard-tier rules

### Requirement: reverse-proxy-scope-orgid-enforcement
The system SHALL (when Loki / Mimir is adopted, per G8, D3) rewrite any client-supplied `X-Scope-OrgID` / `X-Tenant-Id` header at the nginx reverse proxy. The authenticated JWT's `tenantId` claim SHALL replace the client value; client-supplied headers SHALL NOT reach downstream log / metric stores.

#### Scenario: Client-supplied header replaced by JWT-derived value
- **GIVEN** a user in tenant A sends a request with `X-Scope-OrgID: <tenantB>`
- **WHEN** nginx processes the request
- **THEN** the header is rewritten to `X-Scope-OrgID: <tenantA>` based on the JWT claim
- **AND** downstream Loki / Mimir sees only the authenticated tenant value

#### Scenario: Missing header synthesized from JWT
- **GIVEN** a request arrives without `X-Scope-OrgID`
- **WHEN** nginx processes it
- **THEN** nginx adds `X-Scope-OrgID: <tenantA>` based on the JWT
- **AND** downstream stores always see a tenant-bound header

#### Scenario: Unauthenticated request has no tenant header
- **GIVEN** an unauthenticated request arrives
- **WHEN** nginx processes it
- **THEN** any client-supplied `X-Scope-OrgID` header is stripped
- **AND** no tenant binding leaks to downstream stores
