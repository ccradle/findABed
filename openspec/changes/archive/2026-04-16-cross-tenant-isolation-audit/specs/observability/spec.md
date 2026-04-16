## ADDED Requirements

### Requirement: cross-tenant-404-counter
The system SHALL emit a Micrometer counter `fabt.security.cross_tenant_404s` each time `GlobalExceptionHandler` returns HTTP 404 for a request against a tenant-owned resource endpoint. The counter SHALL be tagged by `resource_type` (e.g., `shelter`, `api_key`, `oauth2_provider`, `subscription`, `totp`, `access_code`, `referral`). The counter MUST NOT attempt to distinguish "valid UUID in another tenant" from "UUID does not exist anywhere" — doing so would require a cross-tenant lookup, defeating isolation. The counter is intended for spike detection, not per-event attribution; attribution belongs to audit logs.

#### Scenario: Counter increments on cross-tenant 404
- **GIVEN** a Tenant A admin sends GET `/api/v1/api-keys/{tenantB-uuid}`
- **WHEN** the service returns 404 via the standard `findByIdAndTenantId` → `NoSuchElementException` path
- **AND** `GlobalExceptionHandler` maps the exception to HTTP 404
- **THEN** `fabt.security.cross_tenant_404s{resource_type="api_key"}` increments by 1

#### Scenario: Counter increments on 404 for nonexistent UUID
- **GIVEN** a Tenant A admin sends GET `/api/v1/api-keys/00000000-0000-0000-0000-000000000000`
- **WHEN** the service returns 404 because the UUID exists nowhere
- **THEN** `fabt.security.cross_tenant_404s{resource_type="api_key"}` increments by 1
- **AND** the counter emission is identical to the cross-tenant case (the handler cannot and does not distinguish)

#### Scenario: Counter does not increment on 200 or on unrelated 404s
- **GIVEN** a Tenant A admin sends GET `/api/v1/api-keys/{tenantA-uuid}` and the API key exists in tenant A
- **WHEN** the service returns 200
- **THEN** `fabt.security.cross_tenant_404s` does NOT increment
- **AND** 404s against non-tenant-owned endpoints (e.g., a typo in the path itself like `/api/v1/nonexistent`) do not increment the counter

### Requirement: cross-tenant-404-grafana-panel
The Grafana dashboard SHALL include a panel visualizing the rate of `fabt.security.cross_tenant_404s` per minute, stacked by `resource_type`. The panel SHALL carry a note describing the threshold-based alert guidance (spike-vs-baseline, not absolute rate) so operators know how to interpret the series.

#### Scenario: Panel renders after deploy
- **GIVEN** the v0.XX deploy lands and at least one 404 has fired against a tenant-owned endpoint post-deploy
- **WHEN** an operator opens the FABT security dashboard in Grafana
- **THEN** the "Cross-tenant 404s per minute (by resource)" panel renders with at least one data point
- **AND** the panel description text explains that absolute rate is not actionable; a 5× spike from baseline is the alert criterion

#### Scenario: Panel documents threshold guidance
- **WHEN** an operator reads the panel description
- **THEN** they see plain-language guidance: "Spikes in this counter can indicate UUID-probing attacks against tenant isolation. A sustained 5× spike from the weekly baseline is the alert threshold. A flat baseline of 1-5 per hour is normal (user typos, race conditions during resource expiry)."
