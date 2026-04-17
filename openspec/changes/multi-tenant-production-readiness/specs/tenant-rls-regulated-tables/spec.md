## ADDED Requirements

### Requirement: postgres-16-5-minimum-version
The system SHALL require PostgreSQL ≥ 16.5 (per B1) to mitigate CVE-2024-10976 (RLS policies evaluated below subqueries retained old role context under `SET ROLE`). The runbook SHALL document the version floor and a CI check SHALL reject connections to a database below the floor.

#### Scenario: Startup fails against Postgres below 16.5
- **GIVEN** the application is configured to connect to a Postgres 16.4 instance
- **WHEN** the application starts and the version check runs
- **THEN** startup fails with a non-zero exit code and an error identifying the minimum-version requirement
- **AND** the CVE-2024-10976 reference is included in the error message

#### Scenario: Runbook documents 16.5 floor
- **GIVEN** `docs/oracle-update-notes-*.md` is reviewed
- **WHEN** an operator reads the Postgres version section
- **THEN** the minimum version is documented as 16.5 with the CVE reference

### Requirement: tenant-rls-on-regulated-tables
The system SHALL enable tenant-scoped Row Level Security policies on regulated tables (per B2, D14 carve-out): `audit_events`, `hmis_audit_log`, `password_reset_token`, `one_time_access_code`, `totp_recovery`, `hmis_outbox`. Policies SHALL use `USING (tenant_id::text = fabt_current_tenant_id())` where `fabt_current_tenant_id` is a `STABLE LEAKPROOF` SQL function wrapping `current_setting('app.tenant_id', true)`.

#### Scenario: Cross-tenant SELECT on audit_events returns zero rows
- **GIVEN** tenant A has 100 rows in `audit_events` and tenant B has 50 rows
- **WHEN** a connection with `app.tenant_id=<tenantB-uuid>` runs `SELECT COUNT(*) FROM audit_events`
- **THEN** the result is 50
- **AND** the 100 tenant A rows are invisible via RLS filtering

#### Scenario: RLS applies to hmis_outbox
- **GIVEN** tenant A has 10 outbox rows and tenant B has 0
- **WHEN** a connection for tenant B reads `hmis_outbox`
- **THEN** the result is empty
- **AND** the HMIS push worker for tenant B processes only its own outbox

#### Scenario: LEAKPROOF function does not disable index scans
- **GIVEN** `audit_events` has index `(tenant_id, created_at)` and the RLS policy wraps `fabt_current_tenant_id()`
- **WHEN** `EXPLAIN SELECT * FROM audit_events WHERE created_at > now() - interval '1 day'` runs
- **THEN** the plan is Index Scan on `(tenant_id, created_at)`, not Seq Scan
- **AND** the LEAKPROOF tag prevents the planner from disabling the index

### Requirement: force-row-level-security
The system SHALL apply `FORCE ROW LEVEL SECURITY` (per B3) on every regulated table, preventing owner bypass during admin sessions and Flyway migrations.

#### Scenario: Owner cannot bypass RLS via force flag
- **GIVEN** `audit_events` has `FORCE ROW LEVEL SECURITY` enabled
- **WHEN** a session connected as `fabt` (owner) without `app.tenant_id` set runs `SELECT * FROM audit_events`
- **THEN** the RLS policy evaluates, and the query returns zero rows (no tenant context)
- **AND** the owner role does not silently see cross-tenant data

#### Scenario: Migration must set tenant context or SET row_security=off
- **GIVEN** a Flyway migration needs to UPDATE an audit_events row
- **WHEN** the migration runs without setting `app.tenant_id` or `row_security=off`
- **THEN** the UPDATE matches zero rows and the migration fails with a clear error
- **AND** the L3 `@tenant-safe` / `@tenant-destructive` tag is required on the migration header

### Requirement: rls-index-coverage-with-explain-regression
The system SHALL maintain `(tenant_id, ...)` indexes on every RLS-protected table (per B4) and CI SHALL include an EXPLAIN regression test that asserts Index Scan for the canonical query per table.

#### Scenario: V69 creates tenant_id-prefixed indexes
- **WHEN** Flyway migration V69 runs
- **THEN** each RLS-protected table has an index beginning with `(tenant_id, ...)`
- **AND** `psql \d+ <table>` output lists the new index

#### Scenario: EXPLAIN regression asserts Index Scan
- **GIVEN** the canonical query for each RLS-protected table is documented in `docs/security/rls-index-coverage.md`
- **WHEN** the `RlsIndexRegressionTest` integration test runs
- **THEN** each query's EXPLAIN plan begins with `Index Scan` or `Bitmap Index Scan`
- **AND** a regression to Seq Scan fails the test

### Requirement: pg-policies-snapshot-artifact
The project SHALL maintain `docs/security/pg-policies-snapshot.md` as the git-tracked `pg_policies` snapshot (per B5). CI SHALL diff the live-DB `SELECT * FROM pg_policies` output against the git copy on every PR and fail if drift is detected.

#### Scenario: Snapshot matches live DB post-migration
- **GIVEN** the applied migrations are in sync with the snapshot
- **WHEN** CI runs `pg_policies_snapshot_diff.sh` against the test database
- **THEN** the diff is empty
- **AND** the CI check passes

#### Scenario: Drift fails CI
- **GIVEN** a PR modifies an RLS policy but does not update the snapshot
- **WHEN** CI runs the diff
- **THEN** the check fails with a diff output identifying the drifted policy
- **AND** the PR is rejected until the snapshot is regenerated

### Requirement: security-definer-governance
The system SHALL enforce governance (per B6) over SQL `SECURITY DEFINER` functions: any Flyway migration introducing one SHALL fail CI unless the migration header includes `@security-definer-exception: <justification>` with a non-empty justification.

#### Scenario: Migration adding SECURITY DEFINER without annotation fails
- **GIVEN** a PR adds a Flyway migration containing `CREATE FUNCTION ... SECURITY DEFINER`
- **AND** the migration header does not include `@security-definer-exception:`
- **WHEN** the CI migration-guard test runs
- **THEN** the build fails with a message naming the offending function and the required annotation

#### Scenario: Annotated exception is accepted
- **GIVEN** the migration header includes `@security-definer-exception: fabt_current_tenant_id wrapper for LEAKPROOF RLS — reviewed by Elena on 2026-04-17`
- **WHEN** the CI migration-guard test runs
- **THEN** the migration is accepted and the justification is logged

### Requirement: pgaudit-extension-enabled
The system SHALL enable the pgaudit extension (per B7) to capture per-query DB-layer audit log entries that include `app.tenant_id` for HIPAA-BAA-class forensic audit.

#### Scenario: pgaudit logs include tenant context
- **GIVEN** pgaudit is enabled via migration V72 or documented manual step
- **WHEN** a DML query runs with `app.tenant_id=<uuid>` bound
- **THEN** the pgaudit log entry includes the tenant UUID alongside the SQL statement and actor role
- **AND** the log format is documented in `docs/security/pgaudit-format.md`

#### Scenario: Log rotation policy documented
- **GIVEN** pgaudit is emitting audit entries to disk
- **WHEN** an operator reads the log-rotation policy
- **THEN** retention per tenant tier (standard / regulated) is documented in the runbook

### Requirement: audit-table-list-partitioning
The system SHALL list-partition `audit_events` and `hmis_audit_log` by `tenant_id` (per B8, D13) to enable per-tenant backup, per-tenant VACUUM attribution, and per-tenant retention windows.

#### Scenario: V70 creates list partitions
- **WHEN** Flyway migration V70 runs
- **THEN** `audit_events` and `hmis_audit_log` are list-partitioned by `tenant_id`
- **AND** `psql \d+ audit_events` shows the partition hierarchy

#### Scenario: Per-tenant backup via partition export
- **GIVEN** an operator runs `pg_dump` with the per-tenant partition name
- **WHEN** the export completes
- **THEN** the dump contains only the target tenant's audit rows
- **AND** the operation does not scan or lock other tenants' partitions

#### Scenario: Partition creation on tenant-create
- **GIVEN** `TenantLifecycleService.create` adds a new tenant
- **WHEN** the create workflow runs
- **THEN** a new list partition for the tenant is created atomically via the Flyway-tracked partition-add function
- **AND** subsequent audit writes for the tenant land in the new partition

### Requirement: per-tenant-statement-timeout-work-mem
The system SHALL set `SET LOCAL statement_timeout = :tenant_timeout_ms` and `SET LOCAL work_mem = :tenant_work_mem` on every `@Transactional` entry AFTER `app.tenant_id` is set (per B9, D4). Values SHALL be sourced from `tenant_rate_limit_config` per tier, with fail-safe defaults if the config load fails.

#### Scenario: Tenant A statement_timeout applied on connection borrow
- **GIVEN** tenant A is on the "standard" tier with `statement_timeout_ms=30000`
- **WHEN** a tenant A request begins a `@Transactional` method
- **THEN** `SET LOCAL statement_timeout = 30000` is executed after `SET LOCAL app.tenant_id = <tenantA>`
- **AND** the subsequent queries are capped at 30 seconds

#### Scenario: Config-load failure uses fail-safe default
- **GIVEN** `tenant_rate_limit_config` is temporarily unreachable
- **WHEN** a `@Transactional` entry tries to load the tenant timeout
- **THEN** the fail-safe default (e.g., 10 seconds) is applied instead of failing open
- **AND** a metric `fabt_tenant_config_load_failure` increments

#### Scenario: Regulated-tier tenant has higher work_mem
- **GIVEN** tenant R is regulated-tier with `work_mem_mb=64`
- **WHEN** tenant R runs a reporting query
- **THEN** `SET LOCAL work_mem = '64MB'` is applied for the query
- **AND** tenant R's analytic queries run within the tier-specific budget

### Requirement: backup-and-pitr-posture-documented
The project SHALL document (per B10) the v1 posture for logical replication, per-tenant `pg_dump`, and PITR: no logical replication in use; per-tenant backup via `pg_dump --where="tenant_id = '<uuid>'"` with a policy-strip step; PITR restores the whole cluster only (per-tenant rollback documented as unavailable).

#### Scenario: Per-tenant pg_dump documented
- **GIVEN** `docs/security/backup-posture.md` is published
- **WHEN** an operator reads it
- **THEN** the document describes the `pg_dump --where` pattern plus the explicit policy-strip step for RLS-protected tables
- **AND** it warns that export must be reviewed for policy leaks before release

#### Scenario: PITR boundary documented
- **WHEN** the same document is read
- **THEN** the PITR section states explicitly that per-tenant rollback is not supported; cluster-wide rollback restores all tenants
- **AND** the mitigation (partition-level export from the restored cluster) is described

### Requirement: set-local-transactional-ordering-archunit
The project SHALL maintain an ArchUnit rule (per B11) asserting that `@Transactional` tenant-scoped methods do not call `TenantContext.runWithContext()` inside the transaction. Tenant context SHALL be bound before the `@Transactional` boundary.

#### Scenario: Nested runWithContext inside @Transactional fails build
- **GIVEN** a service method annotated `@Transactional` contains `TenantContext.runWithContext(...)` in its body
- **WHEN** the ArchUnit rule runs
- **THEN** the build fails with a message identifying the offending method and pointing to `feedback_transactional_rls_scoped_value_ordering.md`

#### Scenario: Tenant context bound in filter passes
- **GIVEN** `JwtAuthenticationFilter` binds `ScopedValue.where(TENANT_KEY, context).run(...)` around the filter chain
- **AND** a `@Transactional` method reads the already-bound context
- **WHEN** the ArchUnit rule runs
- **THEN** the build passes

### Requirement: connection-pool-partial-failure-test
The project SHALL include a connection-pool partial-failure integration test (per B12) that injects a `SET ROLE` failure mid-connection-setup and asserts the connection is removed from the pool rather than returned in a mutated state.

#### Scenario: Injected SET ROLE failure drops the connection
- **GIVEN** a test harness that causes `SET ROLE fabt_app` to fail after `SET LOCAL app.tenant_id` has succeeded
- **WHEN** the connection-borrow routine runs
- **THEN** the connection is closed and removed from the pool (not returned)
- **AND** subsequent borrows from the pool do not serve a mutated connection

#### Scenario: Metric emitted on injected failure
- **WHEN** the partial-failure path fires
- **THEN** `fabt_rls_pool_partial_failure` counter increments
- **AND** a warning log entry identifies the connection replaced

### Requirement: testcontainers-prod-rls-parity
The system SHALL assert in integration tests (per B13) that `current_user` post-connection-borrow is `fabt_app` (NOT `fabt`). A connection running as the `fabt` owner silently bypasses RLS and yields false confidence.

#### Scenario: Integration test asserts fabt_app role
- **GIVEN** a Testcontainers-backed integration test acquires a JDBC connection from the pool
- **WHEN** the test runs `SELECT current_user`
- **THEN** the result is `fabt_app`
- **AND** the assertion fails the build if the result is `fabt` or any superuser

#### Scenario: DV canary test runs as fabt_app
- **WHEN** the DV canary integration test (RLS hides DV data from non-dvAccess users) runs
- **THEN** the current_user check passes before the DV visibility assertion
- **AND** a regression to owner-role connection triggers the guard rather than silently passing
