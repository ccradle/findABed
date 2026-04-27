## ADDED Requirements

### Requirement: COC_ADMIN of tenant A cannot reach tenant B
The `CrossTenantIsolationTest` family SHALL include scenarios verifying that a `COC_ADMIN` of tenant A cannot read, write, or modify any resource belonging to tenant B, even by direct UUID address. (Implicit before — `PLATFORM_ADMIN` was tenant-bound by JWT cryptographic boundary; this requirement makes the new explicit `COC_ADMIN` role's tenant boundary an explicit test target.)

#### Scenario: COC_ADMIN of A reads shelter in B by UUID
- **WHEN** a `COC_ADMIN` JWT for tenant A presents GET `/api/v1/shelters/{shelter-id-in-B}`
- **THEN** the response is HTTP 404 Not Found (not 403 — no information disclosure on cross-tenant queries)
- **AND** an `audit_events` row is written under tenant A's chain with `action = CROSS_TENANT_ACCESS_DENIED`

#### Scenario: COC_ADMIN of A updates user in B by UUID
- **WHEN** a `COC_ADMIN` JWT for tenant A presents PUT `/api/v1/users/{user-id-in-B}`
- **THEN** the response is HTTP 404 Not Found
- **AND** the user record in B is unchanged

#### Scenario: COC_ADMIN of A creates referral targeting shelter in B
- **WHEN** a `COC_ADMIN` JWT for tenant A presents POST `/api/v1/dv-referrals` with `shelterId` belonging to B
- **THEN** the response is HTTP 404 Not Found
- **AND** no referral row is created in either tenant

### Requirement: PLATFORM_OPERATOR action lands in target tenant's audit chain
The `CrossTenantIsolationTest` family SHALL include scenarios verifying that `@PlatformAdminOnly` actions affecting a specific tenant T are recorded in T's `audit_events` chain (not SYSTEM_TENANT_ID), and that the chain hash advances correctly.

#### Scenario: TenantLifecycleController.suspend(T) lands in T's chain
- **WHEN** a `PLATFORM_OPERATOR` invokes `POST /api/v1/admin/tenants/{T}/suspend` with valid justification
- **THEN** an `audit_events` row is INSERTed with `tenant_id = T`, `action = PLATFORM_TENANT_SUSPENDED`
- **AND** `tenant_audit_chain_head.last_hash` for T advances to the new row's `row_hash`
- **AND** the AuditChainVerifier walks T's chain successfully (zero drift) on the next run

#### Scenario: BatchJobController.run does NOT land in any tenant's chain
- **WHEN** a `PLATFORM_OPERATOR` invokes `POST /api/v1/batch/jobs/auditChainVerifier/run`
- **THEN** an `audit_events` row is INSERTed with `tenant_id = SYSTEM_TENANT_ID`, `action = PLATFORM_BATCH_JOB_TRIGGERED`
- **AND** the row's `prev_hash IS NULL` and `row_hash IS NULL` (consistent with the SYSTEM_TENANT_ID skip rule from Phase G-1)
- **AND** no `tenant_audit_chain_head` row's hash advances

### Requirement: Platform JWT cannot impersonate a tenant context
The `CrossTenantIsolationTest` family SHALL include scenarios verifying that a platform JWT (iss="fabt-platform", no `tenantId` claim) cannot be used to access tenant-scoped endpoints that require a tenant context.

#### Scenario: Platform JWT denied at tenant-scoped query
- **WHEN** a platform JWT is presented to `GET /api/v1/users` (which lists users in the caller's tenant)
- **THEN** the response is HTTP 401 Unauthorized
- **AND** the error message indicates the JWT lacks a tenant context (no information disclosure beyond that)

#### Scenario: Platform JWT cannot forge tenantId via X-FABT-Tenant header
- **WHEN** a platform JWT is presented with `X-FABT-Tenant: <some-tenant-uuid>` header
- **THEN** the request is still rejected with HTTP 401
- **AND** the header is NOT used to synthesize a tenant context (header trust is rejected for platform JWTs)
