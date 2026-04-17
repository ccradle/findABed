## ADDED Requirements

### Requirement: tenant-lifecycle-fsm-integration
The system SHALL integrate the `TenantState` FSM (per F1, D8) into the multi-tenancy capability. Tenant creation SHALL produce `state=ACTIVE`; `TenantLifecycleService` SHALL own transitions; every transition SHALL emit a `platform_admin_access_log` + `audit_events` row (per F8).

#### Scenario: Tenant creation yields ACTIVE state
- **WHEN** a platform admin creates a new tenant
- **THEN** the tenant row has `state=ACTIVE`
- **AND** the TENANT_CREATED audit event records the initial state

#### Scenario: State transitions only via TenantLifecycleService
- **GIVEN** any code path that changes tenant state
- **WHEN** static analysis scans for direct UPDATE to `tenant.state`
- **THEN** only `TenantLifecycleService` performs the update
- **AND** direct updates from other services fail the L2 module-boundary ArchUnit rule

### Requirement: per-tenant-state-aware-repository-pattern
The system SHALL expose `findByIdAndActiveTenantId` (per F2) as the service-layer boundary variant for tenant-owned repositories. Inactive tenant state (`SUSPENDED`, `OFFBOARDING`, `ARCHIVED`, `DELETED`) SHALL return 404 — consistent with D3 existence-leak prevention.

#### Scenario: Suspended tenant request returns 404
- **GIVEN** tenant A is `SUSPENDED`
- **WHEN** a valid JWT for tenant A hits GET `/api/v1/shelters`
- **THEN** the service returns 404 (consistent with cross-tenant 404 semantics)
- **AND** the JWT-revocation path independently rejects the token with 401

#### Scenario: Active tenant request returns normal response
- **WHEN** tenant A is `ACTIVE` and the same request executes
- **THEN** the service returns 200 with tenant A's shelters

#### Scenario: OFFBOARDING tenant permits reads but not writes
- **GIVEN** tenant A is `OFFBOARDING`
- **WHEN** a read arrives
- **THEN** the service returns 200 (export / inspection permitted)
- **AND** a write returns 404

### Requirement: per-tenant-keyed-surfaces
The system SHALL use per-tenant signing keys and DEKs (per A1, A3) at every tenant-surface boundary. JWTs SHALL carry an opaque `kid` resolving to `(tenant_id, key_generation)`; encrypted columns SHALL be prefixed with a tenant-versioned DEK `kid`.

#### Scenario: JWT signing uses tenant-specific key
- **WHEN** tenant A issues a JWT
- **THEN** the JWT's signature is verifiable only with tenant A's HKDF-derived key
- **AND** cross-tenant signature verification fails (per A1, A7)

#### Scenario: Encrypted column decrypts with tenant DEK
- **WHEN** a TOTP secret is read for tenant A
- **THEN** decryption uses the tenant A DEK derived with context `fabt:v1:<tenantA>:totp`
- **AND** attempting decrypt with any other tenant's DEK fails

### Requirement: per-tenant-observability-requirements
The system SHALL emit per-tenant observability signals at the multi-tenancy surface: every span SHALL carry `fabt.tenant.id` baggage (per G4); every log line SHALL include the `tenantId` field; every metric with tenant context SHALL honor the per-metric cardinality budget (per G6).

#### Scenario: Span baggage set on tenant request
- **WHEN** a request for tenant A produces a span
- **THEN** the span baggage includes `fabt.tenant.id=<tenantA-uuid>`
- **AND** the tenant ID is filterable in Jaeger / Tempo

#### Scenario: Log lines carry tenantId field
- **WHEN** any application log line is written during a tenant A request
- **THEN** the JSON log entry includes `"tenantId":"<tenantA-uuid>"`

#### Scenario: High-cardinality metric respects budget
- **WHEN** the `http_server_requests_seconds` histogram is emitted
- **THEN** the tenant_id tag is omitted if it would exceed the documented cardinality budget
- **AND** per-tenant views use the Grafana `$tenant` template variable instead

### Requirement: breach-notification-scope-requirements
The system SHALL persist per-tenant breach notification metadata (per H6) in the `breach_notification_contacts` table, expose the per-tenant `oncall_email` on the tenant row (per G5), and route tenant-scoped alerts to the per-tenant on-call.

#### Scenario: Tenant onboarding populates breach contacts
- **WHEN** a regulated-tier tenant is onboarded via `TenantLifecycleService.create`
- **THEN** at least one row is inserted into `breach_notification_contacts` for the tenant covering legal, technical, and on-call roles
- **AND** the `oncall_email` column on the tenant row is populated

#### Scenario: Alert routed to tenant on-call
- **GIVEN** a breach-indicator metric fires with `tenant_id` label
- **WHEN** Alertmanager evaluates routing
- **THEN** the notification is delivered to the tenant's `oncall_email`
- **AND** platform on-call does not receive the tenant-scoped alert
