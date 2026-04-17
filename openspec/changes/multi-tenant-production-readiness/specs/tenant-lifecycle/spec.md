## ADDED Requirements

### Requirement: tenant-state-enum-fsm
The system SHALL model tenant lifecycle via a `TenantState` enum (per F1, D8) with values `ACTIVE`, `SUSPENDED`, `OFFBOARDING`, `ARCHIVED`, `DELETED`. Allowed transitions SHALL be enforced by `TenantLifecycleService`, and a state-machine test SHALL assert that disallowed transitions throw.

#### Scenario: Valid transition ACTIVE → SUSPENDED
- **GIVEN** tenant A is in state `ACTIVE`
- **WHEN** an operator invokes `TenantLifecycleService.suspend(tenantA)`
- **THEN** the tenant state transitions to `SUSPENDED`
- **AND** the state change is audit-logged with actor, prior state, and new state

#### Scenario: Disallowed transition DELETED → ACTIVE throws
- **GIVEN** tenant A is in state `DELETED`
- **WHEN** any code path attempts to transition tenant A back to `ACTIVE`
- **THEN** `TenantLifecycleService` throws an `IllegalStateException`
- **AND** the tenant state remains `DELETED`

#### Scenario: ARCHIVED cannot revert to ACTIVE
- **GIVEN** tenant A is in state `ARCHIVED`
- **WHEN** an operator attempts to "reactivate" the tenant
- **THEN** the call is rejected with `IllegalStateException`
- **AND** the operator guidance points to the "new tenant create" procedure instead

### Requirement: state-aware-repository-pattern
The system SHALL expose `findByIdAndActiveTenantId` (per F2) as a state-aware variant used at service-layer boundaries for tenant-owned repositories. An inactive tenant (`SUSPENDED`, `OFFBOARDING`, `ARCHIVED`, `DELETED`) SHALL return the same 404 response as "does not exist" (D3 existence-leak consistency). Repository-layer `findByIdAndTenantId` SHALL be preserved for internal use.

#### Scenario: Request to suspended tenant returns 404
- **GIVEN** tenant A is `SUSPENDED`
- **WHEN** a user's JWT (still unexpired) hits GET `/api/v1/shelters`
- **THEN** the service layer routes through `findByIdAndActiveTenantId` and returns 404
- **AND** the JWT is also rejected per A2 revocation (both paths converge on 404/401)

#### Scenario: Request to active tenant returns 200
- **GIVEN** tenant A is `ACTIVE`
- **WHEN** a user hits GET `/api/v1/shelters`
- **THEN** the service returns 200 with the tenant's shelters

#### Scenario: Offboarding tenant returns 404 on writes, 200 on reads
- **GIVEN** tenant A is `OFFBOARDING`
- **WHEN** a write request (POST / PUT / DELETE) arrives
- **THEN** the service returns 404 (consistent with existence-leak D3)
- **AND** read requests continue to succeed to permit export

### Requirement: tenant-create-workflow
The system SHALL provide a `TenantLifecycleService.create` atomic workflow (per F3) that inserts the tenant row, derives per-tenant JWT key + DEK, applies default typed config, bootstraps a `TENANT_CREATED` audit event, and verifies RLS predicates with a post-create test query. The workflow SHALL be idempotent with rollback on partial failure.

#### Scenario: Full create workflow succeeds atomically
- **GIVEN** a platform admin calls `TenantLifecycleService.create(name, slug)`
- **WHEN** the workflow runs
- **THEN** a tenant row is inserted with state `ACTIVE`
- **AND** per-tenant JWT key material is derived (A1) and `kid_to_tenant_key` is populated
- **AND** per-tenant DEK material is registered (A3)
- **AND** default typed config is applied (L5)
- **AND** a `TENANT_CREATED` audit event is appended
- **AND** a post-create verification query under the new tenant's context returns the expected bootstrap row

#### Scenario: Partial failure rolls back
- **GIVEN** the create workflow fails at DEK derivation
- **WHEN** the transaction aborts
- **THEN** the tenant row is not committed
- **AND** no partial artifacts (JWT key, config row, audit event) remain in the database

#### Scenario: Repeated create with same slug is idempotent
- **GIVEN** a tenant with slug `asheville-coc` already exists
- **WHEN** `create` is called again with the same slug
- **THEN** the call is a no-op (returns the existing tenant) without creating duplicate key material or config rows

### Requirement: tenant-suspend-workflow
The system SHALL provide a `TenantLifecycleService.suspend` atomic 5-action quarantine (per F4, K1): (a) bump `jwt_key_generation`, (b) disable all API keys, (c) stop worker dispatch, (d) set `state=SUSPENDED`, (e) append audit event. Writes SHALL return 503 while suspended; reads SHALL be preserved for forensic inspection.

#### Scenario: Suspend invalidates JWTs, disables API keys, stops workers
- **GIVEN** tenant A is `ACTIVE` with 50 active JWTs, 3 API keys, and a running HMIS push worker
- **WHEN** an operator calls `suspend(tenantA, justification)`
- **THEN** `jwt_key_generation` for tenant A is bumped (A2)
- **AND** all API keys for tenant A are marked disabled
- **AND** worker dispatch for tenant A is paused
- **AND** tenant state is `SUSPENDED`
- **AND** a `TENANT_SUSPENDED` audit event is appended with the justification

#### Scenario: Write to suspended tenant returns 503
- **GIVEN** tenant A is `SUSPENDED`
- **WHEN** a privileged caller (e.g., platform admin impersonation) issues a write against tenant A
- **THEN** the response is 503 Service Unavailable with a clear suspend-state message
- **AND** no row is mutated

#### Scenario: Un-suspend restores service
- **GIVEN** tenant A is `SUSPENDED` and an operator calls `unsuspend(tenantA)`
- **WHEN** the transition runs
- **THEN** state returns to `ACTIVE`
- **AND** a new JWT issuance path works (key_generation now incremented vs pre-suspend)
- **AND** API keys require re-enablement per operator procedure

### Requirement: tenant-offboard-with-json-export
The system SHALL provide a `TenantLifecycleService.offboard` workflow (per F5) that produces a schema'd JSON export of all tenant data classes (shelters, beds, users, referrals, audit events, HMIS history, config) and transitions the tenant to `OFFBOARDING` then `ARCHIVED` when the export completes. Delivery SHALL meet the 30-day window required by GDPR Article 20 + EU Data Act.

#### Scenario: Offboard produces structured export
- **WHEN** an operator calls `offboard(tenantA)`
- **THEN** the export job runs and produces a JSON file with documented schema covering every data class
- **AND** the file is delivered to the tenant's designated export destination (file path or signed URL)
- **AND** the tenant transitions through `OFFBOARDING` to `ARCHIVED` on export completion

#### Scenario: Export schema is stable
- **GIVEN** the export schema is documented in `docs/legal/tenant-export-schema.md`
- **WHEN** a new tenant-owned table is added
- **THEN** the export schema doc is updated in the same PR
- **AND** a schema-stability CI test asserts backward compatibility of field names

#### Scenario: Read traffic preserved during OFFBOARDING
- **GIVEN** tenant A is `OFFBOARDING`
- **WHEN** a platform admin reads tenant A's data during the export
- **THEN** reads succeed so that export and inspection proceed
- **AND** writes are blocked with 404 per F2

### Requirement: tenant-hard-delete-crypto-shred
The system SHALL provide a `TenantLifecycleService.hardDelete` workflow (per F6, D11) that cascades primary data by `tenant_id`, destroys the per-tenant DEK (crypto-shred — ciphertexts computationally unrecoverable from live DB, backups, and replicas), and documents audit-log retention resolution (HIPAA 6-year vs GDPR erasure). This SHALL satisfy GDPR Article 17 + EDPB Feb 2026 erasure-in-backups compliance.

#### Scenario: Hard-delete destroys DEK
- **GIVEN** tenant A is `ARCHIVED` and the retention window has elapsed
- **WHEN** an operator calls `hardDelete(tenantA, justification)`
- **THEN** the tenant's `tenant_key_material` row is deleted
- **AND** subsequent attempts to decrypt any ciphertext with `kid=(tenantA, ...)` fail (AEAD tag mismatch or key-not-found)

#### Scenario: Cascade deletes primary data
- **WHEN** `hardDelete` proceeds
- **THEN** every tenant-owned table has its rows for tenant A cascade-deleted via FK
- **AND** a post-delete verification query shows zero rows remain for tenant A in primary tables

#### Scenario: Crypto-shred irreversible even from PITR
- **GIVEN** tenant A has been hard-deleted
- **WHEN** an operator restores a pre-delete PITR snapshot in a test environment
- **THEN** the restored ciphertexts are still undecryptable because the master KEK-derived DEK can no longer be reconstructed (the HKDF input row is gone)
- **AND** the boundary is documented in `docs/security/crypto-shred-posture.md`

#### Scenario: TENANT_HARD_DELETED audit event
- **WHEN** `hardDelete` completes
- **THEN** a `TENANT_HARD_DELETED` audit event is written to the platform-level audit log with actor, justification, and shredded tenant UUID
- **AND** the tenant's per-tenant audit chain is severed (D9 expected behavior)

### Requirement: data-residency-region-tag
The system SHALL expose a `data_residency_region` column on the `tenant` table (per F7) carrying the jurisdictional tag for the tenant (standard: `us-any`; regulated: `us-<region>` or `silo`). Controls that depend on residency SHALL be set today as informational and enforced when a federal or EU tenant onboards.

#### Scenario: Column exists and is populated at create
- **WHEN** a new tenant is created
- **THEN** `data_residency_region` is set per the create request (default `us-any` if unspecified)
- **AND** the field is visible via `GET /api/v1/tenants/{id}`

#### Scenario: Residency tag informs export path
- **GIVEN** tenant E is tagged `eu-west`
- **WHEN** the offboard export runs
- **THEN** the export path documents the residency tag and flags any cross-region storage step for review
- **AND** the residency tag is included in the export manifest

### Requirement: lifecycle-audit-events
The system SHALL emit a `platform_admin_access_log` + `audit_events` row for every tenant state transition (per F8) containing actor, target tenant, prior state, new state, and a justification string.

#### Scenario: Suspend emits both audit and platform-admin entries
- **WHEN** an operator suspends tenant A
- **THEN** an `audit_events` row with event_type `TENANT_SUSPENDED` is written in tenant A's audit partition
- **AND** a `platform_admin_access_log` row captures the operator action with justification

#### Scenario: Missing justification rejects the state transition
- **WHEN** an operator calls `suspend(tenantA, "")` with an empty justification
- **THEN** the call is rejected with `IllegalArgumentException`
- **AND** no state transition or audit event occurs

#### Scenario: Audit chain preserved through state changes
- **WHEN** a state transition occurs on tenant A
- **THEN** the resulting audit_events row participates in the per-tenant hash chain (G1)
- **AND** the chain head is updated atomically with the state change
