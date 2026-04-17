## ADDED Requirements

### Requirement: tenant-scoped-spi
The system SHALL provide a `TenantScoped<T>` SPI (per L1, D7) as the uniform per-tenant resource accessor. The interface SHALL expose `T forTenant(UUID tenantId)` and `T forCurrent()`. Implementations SHALL include `TenantScoped<SigningKey>`, `TenantScoped<SecretKey>` (DEK), `TenantScoped<Cache<K,V>>`, `TenantScoped<Bucket>` (rate-limit), `TenantScoped<Duration>` (statement_timeout), and `TenantScoped<Tags>` (metrics).

#### Scenario: forCurrent resolves from TenantContext
- **GIVEN** a request bound to tenant A via `TenantContext`
- **WHEN** a caller invokes `tenantScopedSigningKey.forCurrent()`
- **THEN** the returned signing key is derived for tenant A
- **AND** no tenant UUID parameter was required from the caller

#### Scenario: forTenant works outside a request context
- **GIVEN** a scheduled job running outside a request (system context)
- **WHEN** it calls `tenantScopedCache.forTenant(<tenantA>)`
- **THEN** the returned cache is scoped to tenant A
- **AND** no `TenantContext` binding is required to resolve the resource

#### Scenario: forCurrent without context fails fast
- **WHEN** `forCurrent()` is invoked with no bound `TenantContext`
- **THEN** the call throws `IllegalStateException` with a message identifying the missing context
- **AND** no resource is returned

### Requirement: tenant-module-boundary-archunit
The project SHALL maintain an ArchUnit rule (per L2, Family F) preventing other modules from reading the `tenant` table directly. All tenant metadata access SHALL route through `TenantService` or `TenantLifecycleService`. This reinforces the modular-monolith pattern from `feedback_modular_monolith.md`.

#### Scenario: Direct repository access from unrelated module fails build
- **GIVEN** a class in `org.fabt.shelter.*` adds a direct `TenantRepository` field
- **WHEN** the Family F ArchUnit rule runs
- **THEN** the build fails with a message naming the offending class and requiring use of `TenantService` / `TenantLifecycleService`

#### Scenario: Access through TenantService passes
- **GIVEN** a class in `org.fabt.shelter.*` injects `TenantService` and reads metadata via its API
- **WHEN** the Family F rule runs
- **THEN** the build passes
- **AND** the boundary is preserved

### Requirement: tenant-destructive-migration-review-gate
The project SHALL require (per L3) every Flyway migration to include either `@tenant-safe` or `@tenant-destructive: <justification>` in the header comment. CI SHALL reject migrations without the annotation.

#### Scenario: Migration without annotation fails CI
- **GIVEN** a PR adds `V77__example.sql` without either annotation in the header
- **WHEN** CI's migration-guard test runs
- **THEN** the build fails with a message requiring the annotation

#### Scenario: @tenant-safe migration passes
- **GIVEN** a migration header starts with `-- @tenant-safe`
- **WHEN** the CI check runs
- **THEN** the migration passes the gate
- **AND** the annotation is preserved as git-tracked documentation

#### Scenario: @tenant-destructive with justification passes
- **GIVEN** a migration header has `-- @tenant-destructive: drops legacy coordinator_assignment column; reviewed by Elena 2026-04-20`
- **WHEN** the CI check runs
- **THEN** the migration passes the gate with the justification captured

### Requirement: typed-per-tenant-feature-flags
The system SHALL maintain a `tenant_feature_flag` table (per L4) — not a JSON blob — with strongly-typed config read via `FeatureFlagService.isEnabled(tenantId, flag)`. Canary rollout per tenant SHALL be supported.

#### Scenario: Flag enabled for one tenant, disabled for another
- **GIVEN** `tenant_feature_flag` contains `(tenantA, 'new_search_ui', true)` and `(tenantB, 'new_search_ui', false)`
- **WHEN** a request for tenant A calls `isEnabled(tenantA, 'new_search_ui')`
- **THEN** it returns `true`
- **AND** the same call for tenant B returns `false`

#### Scenario: Missing flag row returns documented default
- **GIVEN** tenant C has no row for flag `new_search_ui`
- **WHEN** `isEnabled(tenantC, 'new_search_ui')` runs
- **THEN** the documented default (false, fail-safe) is returned

#### Scenario: Flag change emits audit event
- **WHEN** an admin flips `new_search_ui` for a tenant
- **THEN** a `TENANT_FEATURE_FLAG_CHANGED` audit event is emitted with old and new values

### Requirement: typed-per-tenant-config
The system SHALL replace `tenant.config` JSONB (per L5) with typed columns or typed sub-tables covering hold_duration, surge_threshold, rate_limit_overrides, webhook_allowlist, statement_timeout, work_mem, key_rotation_cadence, api_key_auth_enabled, default_locale, oncall_email, and data_residency_region.

#### Scenario: Typed columns replace JSON blob
- **WHEN** the migration introducing typed config runs
- **THEN** each listed concern is a separate column or sub-table with typed schema
- **AND** the legacy `config` JSONB is deprecated with a migration to move values to typed columns

#### Scenario: Typed read via TenantConfigService
- **GIVEN** `TenantConfigService.getHoldDuration(tenantA)` is invoked
- **WHEN** the query runs
- **THEN** the return type is `Duration` (strongly typed, not `String`)
- **AND** missing values produce a documented default

#### Scenario: Typed write validates schema
- **WHEN** an admin writes `work_mem` via the typed API
- **THEN** the service validates the value is an integer in the allowed range
- **AND** rejects invalid values at the API boundary (not at the DB)

### Requirement: per-tenant-canary-deployment
The system SHALL support per-tenant canary deployment (per L6) via feature-flag-gated new-code paths. One tenant SHALL be able to run "next" while others stay on "current."

#### Scenario: Canary tenant runs next code path
- **GIVEN** tenant C has the canary flag enabled and tenant A does not
- **WHEN** both tenants hit a code path gated by the flag
- **THEN** tenant C executes the "next" branch
- **AND** tenant A executes the "current" branch

#### Scenario: Canary rollback is a single flag flip
- **GIVEN** the canary exposes a bug
- **WHEN** the operator flips the flag off for tenant C
- **THEN** tenant C's next request uses the "current" branch again
- **AND** the rollback is audit-logged

### Requirement: stage-environment-with-synthetic-tenants
The project SHALL operate `stage.findabed.org` (per L7) as a pooled 3-tenant environment. The demo (`findabed.org`) SHALL remain the 2-tenant reference (per M1). Any pool-readiness test SHALL run against stage before pilot rollout.

#### Scenario: Stage hosts 3 synthetic tenants
- **GIVEN** `stage.findabed.org` is provisioned
- **WHEN** an operator logs in
- **THEN** three distinct synthetic tenants are visible for cross-tenant testing
- **AND** each tenant has a full user + shelter + referral matrix

#### Scenario: Pool-readiness tests run against stage
- **GIVEN** the pool-readiness Playwright + Gatling suite
- **WHEN** a release candidate is validated
- **THEN** the suite runs against stage before pilot deploy
- **AND** failures block the pilot deploy

### Requirement: per-tenant-dr-drill
The project SHALL run quarterly per-tenant DR drills (per L8) proving "Tenant X corrupted; restore just X." The drill SHALL be scripted with a verification checklist in `docs/runbook.md`.

#### Scenario: Drill script restores a single tenant from backup
- **GIVEN** the drill is scheduled quarterly
- **WHEN** an operator runs the scripted DR drill
- **THEN** a synthetic tenant is "corrupted" (test-only destructive change) and restored from partition-level backup
- **AND** the checklist items all pass (tenant-scoped restore, other tenants untouched, verify query green)

#### Scenario: Drill failure triggers runbook update
- **WHEN** a drill step fails
- **THEN** the runbook is updated before the next drill cycle
- **AND** the failure + remediation is audit-logged

### Requirement: per-tenant-cost-allocation
The project SHALL report (per L9) per-tenant cost attribution quarterly covering DB storage (per-tenant partition size after B8), CPU via OTel per-tenant baggage (G4), and webhook outbound bytes.

#### Scenario: Quarterly report enumerates per-tenant costs
- **GIVEN** the quarterly cost allocation script is published
- **WHEN** an operator runs it
- **THEN** the report lists each tenant's DB size, CPU consumption, and egress bytes
- **AND** the totals reconcile to the platform-wide infrastructure cost

#### Scenario: Cost report uses OTel baggage for CPU attribution
- **WHEN** CPU attribution is computed
- **THEN** it reads span durations filtered by `fabt.tenant.id`
- **AND** sums across tenants to validate total coverage

### Requirement: rotation-runbooks-developer-surface
The project SHALL maintain developer-surface rotation runbooks (per L10) for per-tenant DEK, per-tenant JWT key, and master KEK rotations. Each runbook SHALL document the zero-downtime procedure and RTO.

#### Scenario: Developer-surface runbook complements security runbook
- **GIVEN** `docs/security/runbooks/` holds the operator runbooks
- **AND** `docs/development/rotation-procedures.md` is the developer reference
- **WHEN** a developer implements a rotation-adjacent feature
- **THEN** the developer doc points to the relevant operator procedure
- **AND** no runbook knowledge is duplicated (single source of truth, cross-linked)

#### Scenario: Each rotation documents zero-downtime procedure
- **WHEN** a developer reads any of the three rotation runbooks
- **THEN** the dual-key-accept grace window and RTO are described
- **AND** the runbooks reference the grace-window tests that validate zero-downtime
