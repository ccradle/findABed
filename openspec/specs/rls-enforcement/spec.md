## Purpose

JDBC connection interceptor + restricted DB role for PostgreSQL RLS enforcement.

## ADDED Requirements

### Requirement: rls-connection-interceptor
The system SHALL propagate the authenticated user's `tenantId` and `dvAccess` flag from `TenantContext` to the PostgreSQL session variables `app.tenant_id` and `app.dv_access` on every JDBC connection, enabling Row Level Security policies to filter data at the database layer. `TenantContext` SHALL use `ScopedValue` (Java 25, JEP 506) instead of `ThreadLocal` for context storage. The `ScopedValue` is bound in `JwtAuthenticationFilter` via `ScopedValue.where(KEY, context).run(...)` and is automatically inherited by child virtual threads. No manual cleanup (`.remove()`) is needed — scope exit handles cleanup.

#### Scenario: User with dvAccess sees DV shelters
- **WHEN** a user with `dvAccess: true` queries GET `/api/v1/shelters`
- **THEN** the JDBC connection has `app.dv_access = 'true'` set via SET LOCAL
- **AND** DV shelters (`dv_shelter = true`) appear in the results

#### Scenario: User without dvAccess cannot see DV shelters
- **WHEN** a user with `dvAccess: false` queries GET `/api/v1/shelters`
- **THEN** the JDBC connection has `app.dv_access = 'false'` set via SET LOCAL
- **AND** DV shelters are excluded from results by the RLS policy
- **AND** direct GET `/api/v1/shelters/{dvShelterId}` returns 404 (not 403)

#### Scenario: Default dvAccess is false
- **WHEN** no authenticated user context exists (system tasks, Flyway)
- **THEN** `app.dv_access` defaults to false
- **AND** DV shelters are hidden

#### Scenario: Tenant context propagates to virtual threads
- **WHEN** a request handler spawns virtual threads (e.g., fan-out monitoring checks)
- **THEN** each child virtual thread inherits the `ScopedValue`-bound tenant context
- **AND** JDBC connections obtained in child virtual threads have the correct `app.tenant_id` and `app.dv_access` values

#### Scenario: Tenant context is isolated between concurrent requests
- **WHEN** two concurrent requests execute for different tenants on separate virtual threads
- **THEN** each request's `ScopedValue` binding is independent
- **AND** tenant A's context never leaks to tenant B's virtual thread
- **AND** no `ThreadLocal.remove()` cleanup is required — scope exit is automatic

### Requirement: restricted-database-role
The system SHALL connect to PostgreSQL using a restricted `fabt_app` role (NOSUPERUSER) for all runtime queries, while Flyway DDL migrations continue to run as the `fabt` (owner) role. This ensures RLS policies are enforced — PostgreSQL superusers and table owners bypass RLS.

#### Scenario: Application uses restricted role
- **WHEN** the application starts and connects to PostgreSQL
- **THEN** runtime queries execute as `fabt_app` (NOSUPERUSER, DML-only)
- **AND** Flyway migrations execute as `fabt` (owner, DDL permissions)

#### Scenario: Restricted role has DML permissions only
- **WHEN** the `fabt_app` role is created
- **THEN** it has SELECT, INSERT, UPDATE, DELETE on all tables
- **AND** it does NOT have CREATE, DROP, ALTER, or TRUNCATE permissions
- **AND** it is NOT a superuser

#### Scenario: RLS enforced in docker-compose dev environment
- **WHEN** the dev stack starts via `./dev-start.sh`
- **THEN** the PostgreSQL init script creates the `fabt_app` user
- **AND** the application connects as `fabt_app`
- **AND** DV canary tests pass (DV shelters hidden from non-dvAccess users)

### Requirement: connection-pool-dvaccess-reset
The system SHALL correctly reset `app.dv_access` on every pooled connection checkout, preventing stale DV access state from leaking between requests.

- REQ-RLS-POOL-1: `applyRlsContext()` MUST overwrite any stale `app.dv_access` value from a previous request on the same pooled connection
- REQ-RLS-POOL-2: A test MUST verify that a dvAccess=true request followed by a dvAccess=false request on the same connection does not leak DV shelter visibility
- REQ-RLS-POOL-3: The test MUST run the sequence at least 100 times to detect intermittent race conditions

#### Scenario: Pooled connection resets dvAccess between requests
- **WHEN** request 1 executes with dvAccess=true and sees DV shelters
- **AND** request 1 completes and returns its connection to the pool
- **WHEN** request 2 executes with dvAccess=false on the same connection
- **THEN** request 2 does not see DV shelters
- **AND** this holds for 100 consecutive iterations

### Requirement: rls-policy-semantic-accuracy
Every RLS policy comment, Javadoc reference to RLS, and developer-facing documentation SHALL accurately describe what the policy enforces. Policy comments SHALL NOT claim tenant isolation unless the policy's `USING` / `WITH CHECK` clauses actually reference `app.tenant_id`. Where an existing policy comment in an applied migration makes a false claim (Flyway's immutability rule precludes edits to the original migration), a subsequent migration SHALL ship a `COMMENT ON POLICY` correction so `psql \d+` reflects the truth.

#### Scenario: referral_token policy comment correction via V56
- **GIVEN** V21 created policy `dv_referral_token_access` on `referral_token` with `USING (EXISTS (SELECT 1 FROM shelter s WHERE s.id = referral_token.shelter_id))` — enforces shelter existence only, NOT tenant
- **AND** the service layer's v0.39 `findByIdAndTenantId` fix is the actual tenant guard
- **WHEN** migration V56 runs `COMMENT ON POLICY dv_referral_token_access ON referral_token IS 'Enforces dv_access inheritance through the shelter FK join. Does NOT enforce tenant isolation — tenant is enforced at the service layer via findByIdAndTenantId. See openspec/changes/cross-tenant-isolation-audit for rationale.'`
- **THEN** `psql \d+ referral_token` output includes the corrected comment
- **AND** the prior (misleading) comment from V21 is overwritten (Postgres `COMMENT ON` is last-write-wins)

#### Scenario: Javadoc audit removes false RLS claims
- **GIVEN** any `*Service.java` or `*Repository.java` contains a comment asserting "RLS enforces tenant" or equivalent
- **WHEN** the Javadoc audit runs as part of this change
- **THEN** every such comment is either corrected (if the service actually has a tenant guard the comment can point to) or removed (if the comment is historically inaccurate)
- **AND** a short note in `docs/security/rls-coverage.md` references the V21/V56 case as the canonical example of why these comments get audited

### Requirement: rls-coverage-map
The project SHALL maintain an authoritative table-by-table map of RLS coverage at `docs/security/rls-coverage.md`. The map SHALL list every tenant-owned table in the schema, its RLS status (enforced / not enforced), what the policy actually enforces when present (`dv_access`, `shelter_id` membership, etc.), and the corresponding service-layer guard method name. The map SHALL be updated whenever a new tenant-owned table is added to the schema.

#### Scenario: RLS coverage map exists and is complete
- **GIVEN** the full list of tenant-owned tables in the current schema
- **WHEN** `docs/security/rls-coverage.md` is reviewed
- **THEN** every table appears as a row
- **AND** each row names: table name, RLS-enabled flag, policy name if any, what the policy enforces, service-layer guard method, test that pins cross-tenant behavior

#### Scenario: Adding a new tenant-owned table requires updating the map
- **WHEN** a future migration adds a new tenant-owned table (e.g. `intake_form`)
- **THEN** the PR adding the migration includes an update to `docs/security/rls-coverage.md` adding a row for the new table
- **AND** CI or a checklist item flags the PR if the map was not updated
