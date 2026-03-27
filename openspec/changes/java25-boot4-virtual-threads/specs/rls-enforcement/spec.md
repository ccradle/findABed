## MODIFIED Requirements

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
