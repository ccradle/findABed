## ADDED Requirements

### Requirement: per-tenant-audit-hash-chain
The system SHALL compute `row_hash = SHA256(prev_tenant_hash || canonical_json(row))` for every `audit_events` row (per G1, D9) and store the per-tenant chain head in `tenant_audit_chain_head(tenant_id, last_hash, last_row_id)`. A weekly cron SHALL write `(tenant_id, last_hash, timestamp)` to an external append-only store (S3 Object Lock or equivalent WORM) as tamper evidence.

#### Scenario: Audit row computes row_hash on insert
- **GIVEN** tenant A has `tenant_audit_chain_head.last_hash=H_prev`
- **WHEN** a new `audit_events` row is inserted for tenant A
- **THEN** the row's `row_hash = SHA256(H_prev || canonical_json(row))`
- **AND** `tenant_audit_chain_head.last_hash` updates to the new row_hash atomically with the insert

#### Scenario: Tampering breaks the chain
- **GIVEN** an attacker with DB write access modifies an older audit_events row
- **WHEN** the chain-verify scheduled job recomputes `row_hash` from the attacker-modified row forward
- **THEN** the recomputed hash diverges from the stored `row_hash`
- **AND** a `fabt_audit_chain_integrity_failed` metric fires + high-severity alert

#### Scenario: Weekly external anchor written
- **WHEN** the weekly anchor cron runs
- **THEN** the tuple `(tenant_id, last_hash, timestamp)` is written to the S3 Object Lock bucket (or documented WORM equivalent)
- **AND** the write is immutable (WORM retention applied)

#### Scenario: Anchor severed on crypto-shred is expected
- **GIVEN** tenant A has been hard-deleted (F6) and its chain is un-verifiable post-shred
- **WHEN** the verify job runs
- **THEN** the un-verifiable state is documented behavior (D9/D11)
- **AND** the last pre-shred anchor is the final integrity proof, referenced in the runbook

### Requirement: audit-table-insert-only-for-fabt-app
The system SHALL apply `REVOKE UPDATE, DELETE FROM fabt_app` on `audit_events`, `hmis_audit_log`, and `platform_admin_access_log` (per G2) making these tables INSERT-only for the application role. Any code path attempting UPDATE or DELETE on these tables SHALL fail with a permission error.

#### Scenario: V71 revokes UPDATE + DELETE from fabt_app
- **WHEN** Flyway migration V71 runs
- **THEN** `fabt_app` can INSERT into audit tables but UPDATE / DELETE fail with a permissions error
- **AND** `\dp audit_events` reflects the revoked grants

#### Scenario: Attempted UPDATE fails in production
- **GIVEN** the application runs as `fabt_app`
- **WHEN** a hypothetical buggy code path attempts `UPDATE audit_events SET ... WHERE id = ...`
- **THEN** the query fails with a PostgreSQL permission-denied error
- **AND** the attempt is captured by pgaudit

#### Scenario: Flyway migration path remains unblocked
- **GIVEN** a future Flyway migration legitimately alters schema on an audit table
- **WHEN** it runs as the `fabt` owner
- **THEN** the owner role retains DDL permissions (owner is not fabt_app)
- **AND** `FORCE RLS` still applies (B3)

### Requirement: platform-admin-access-log
The system SHALL maintain a `platform_admin_access_log` table (per G3) capturing `(admin_user_id, tenant_id, resource, justification, timestamp)` for every platform-admin read of tenant-owned data. Capture SHALL be annotation-driven on `@PlatformAdminOnly` methods. This supports the VAWA Comparable Database audit requirement (H4).

#### Scenario: Platform admin read logs to table
- **GIVEN** a method is annotated `@PlatformAdminOnly`
- **WHEN** a platform admin invokes the method with a non-empty justification
- **THEN** a `platform_admin_access_log` row is inserted with admin UUID, target tenant, resource path, justification, and timestamp
- **AND** the method proceeds

#### Scenario: Missing justification rejects the call
- **WHEN** a platform admin invokes a `@PlatformAdminOnly` method without a justification string
- **THEN** the call is rejected with 400 Bad Request
- **AND** no log row is written

#### Scenario: Non-admin cannot reach @PlatformAdminOnly method
- **GIVEN** a CoC admin (not platform admin) has a valid JWT
- **WHEN** the caller invokes the `@PlatformAdminOnly` method
- **THEN** the request is rejected with 403 Forbidden
- **AND** no access log row is written (no admin reached the method)

#### Scenario: Access log is INSERT-only
- **GIVEN** `platform_admin_access_log` is subject to the INSERT-only revoke (G2)
- **WHEN** a code path attempts UPDATE
- **THEN** the attempt fails with a permission error
- **AND** the tamper-evident posture is preserved across platform admin activity
