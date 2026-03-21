## Purpose

JDBC connection interceptor + restricted DB role for PostgreSQL RLS enforcement.

## ADDED Requirements

### Requirement: rls-connection-interceptor
The system SHALL propagate the authenticated user's `dvAccess` flag from `TenantContext` to the PostgreSQL session variable `app.dv_access` on every JDBC connection, enabling Row Level Security policies to filter DV shelter data at the database layer.

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
