## ADDED Requirements

### Requirement: tenant-rls-on-regulated-tables
The system SHALL enable tenant-scoped RLS (per B2, D14 carve-out) on `audit_events`, `hmis_audit_log`, `password_reset_token`, `one_time_access_code`, `totp_recovery`, and `hmis_outbox`. Policies SHALL use `USING (tenant_id::text = fabt_current_tenant_id())`.

#### Scenario: audit_events cross-tenant SELECT returns zero rows
- **GIVEN** tenant A has N rows in `audit_events` and tenant B has M rows
- **WHEN** a session with `app.tenant_id=<tenantB>` runs `SELECT COUNT(*) FROM audit_events`
- **THEN** the result is M (not N+M)
- **AND** the RLS policy filters out tenant A rows

#### Scenario: hmis_outbox RLS enforced
- **GIVEN** tenant A has queued HMIS outbox rows
- **WHEN** tenant B's background worker reads hmis_outbox
- **THEN** the result is empty for tenant B
- **AND** tenant B's worker never sees tenant A's queued push payloads

#### Scenario: Missing app.tenant_id yields zero rows
- **WHEN** a session has no `app.tenant_id` bound
- **THEN** `fabt_current_tenant_id()` returns `NULL` and the policy evaluates to FALSE
- **AND** cross-tenant data is invisible (fail-closed)

### Requirement: leakproof-tenant-id-function
The system SHALL define `fabt_current_tenant_id()` (per B2, V67) as a `STABLE LEAKPROOF` SQL function wrapping `current_setting('app.tenant_id', true)`. LEAKPROOF SHALL prevent the planner from disabling index scans and SHALL prevent error-message side-channel leaks.

#### Scenario: Function marked STABLE LEAKPROOF in pg_proc
- **GIVEN** V67 defined `fabt_current_tenant_id()`
- **WHEN** `\df+ fabt_current_tenant_id` is inspected
- **THEN** the volatility is STABLE and leakproof flag is true
- **AND** the wrapper returns the session-bound tenant UUID (or NULL if unbound)

#### Scenario: Index scan preserved with LEAKPROOF wrap
- **GIVEN** `audit_events` has an index `(tenant_id, created_at)` and the RLS policy wraps `fabt_current_tenant_id()`
- **WHEN** `EXPLAIN SELECT * FROM audit_events WHERE created_at > now() - interval '1 day'` runs
- **THEN** the plan uses Index Scan (not Seq Scan)
- **AND** a regression to Seq Scan is caught by the RLS index regression test

### Requirement: force-row-level-security
The system SHALL apply `FORCE ROW LEVEL SECURITY` on every regulated table (per B3, V68). Owner bypass during admin sessions and Flyway migrations SHALL be prevented.

#### Scenario: Owner role cannot bypass RLS without context
- **GIVEN** `audit_events` has `FORCE ROW LEVEL SECURITY` enabled
- **WHEN** a session connected as `fabt` (owner) without `app.tenant_id` runs `SELECT * FROM audit_events`
- **THEN** the result is zero rows
- **AND** the migration must explicitly set `app.tenant_id` or `SET LOCAL row_security=off` (superuser-only)

#### Scenario: Migration with @tenant-destructive passes after explicit context
- **GIVEN** a migration needs to UPDATE an audit_events row
- **WHEN** the migration header carries `@tenant-destructive: <justification>` and the migration explicitly sets context
- **THEN** the migration runs successfully
- **AND** the justification is reviewed per L3 PR gate

### Requirement: pgaudit-db-layer-audit
The system SHALL enable the pgaudit extension (per B7) via V72. Audit entries SHALL include `app.tenant_id` as a per-query field, complementing the application-layer `audit_events` and enabling HIPAA-BAA forensic review.

#### Scenario: pgaudit entry includes tenant id
- **GIVEN** pgaudit is enabled and a DML query runs with `app.tenant_id=<tenantA>` set
- **WHEN** the pgaudit log entry is written
- **THEN** the entry includes the tenant UUID alongside the query statement
- **AND** the entry includes the actor role (fabt_app) and timestamp

#### Scenario: pgaudit format documented
- **GIVEN** `docs/security/pgaudit-format.md` is published
- **WHEN** an operator reads it
- **THEN** the entry shape (timestamp, role, tenant_id, statement, object) is documented
- **AND** log-rotation policy is described

### Requirement: per-role-statement-timeout
The system SHALL apply per-tenant `statement_timeout` and `work_mem` via `SET LOCAL` on every `@Transactional` entry AFTER `app.tenant_id` is bound (per B9, D4). Values SHALL be sourced from `tenant_rate_limit_config` per tier with fail-safe defaults.

#### Scenario: Per-tenant timeout bound on transactional entry
- **GIVEN** tenant A has `statement_timeout_ms=30000` in config
- **WHEN** a `@Transactional` method enters and the connection has `app.tenant_id` set
- **THEN** `SET LOCAL statement_timeout = 30000` is executed
- **AND** queries exceeding 30s are aborted with a statement_timeout error

#### Scenario: Config load failure fails safe
- **GIVEN** `tenant_rate_limit_config` is unreachable momentarily
- **WHEN** the `@Transactional` entry runs
- **THEN** the fail-safe default (e.g., 10s) is applied
- **AND** a warning metric fires

### Requirement: security-definer-governance
The system SHALL reject (per B6) any Flyway migration introducing a `SECURITY DEFINER` function unless the migration header includes `@security-definer-exception: <justification>`.

#### Scenario: Unannotated SECURITY DEFINER fails CI
- **GIVEN** a migration defines a function with `SECURITY DEFINER` without the annotation
- **WHEN** the migration-guard CI check runs
- **THEN** the build fails with a message naming the function and the required annotation

#### Scenario: Annotated exception accepted
- **GIVEN** the migration header includes a non-empty `@security-definer-exception` justification
- **WHEN** the CI check runs
- **THEN** the migration is accepted and the justification is captured in the audit trail for subsequent security review

### Requirement: pg-policies-snapshot-artifact
The project SHALL maintain `docs/security/pg-policies-snapshot.md` (per B5) as the git-tracked `pg_policies` snapshot. CI SHALL diff the live-DB snapshot against the git copy on every PR; drift SHALL fail the build.

#### Scenario: Snapshot matches live DB
- **GIVEN** the snapshot is up to date with applied migrations
- **WHEN** CI diffs `SELECT * FROM pg_policies` against the git copy
- **THEN** the diff is empty and CI passes

#### Scenario: Drift fails CI
- **GIVEN** a PR adds an RLS policy but does not update the snapshot
- **WHEN** CI runs the diff
- **THEN** the check fails with the drift identified
- **AND** the PR is rejected until the snapshot is regenerated
