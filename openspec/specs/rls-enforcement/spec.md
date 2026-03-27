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
