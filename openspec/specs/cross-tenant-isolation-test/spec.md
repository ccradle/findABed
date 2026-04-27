## cross-tenant-isolation-test

Concurrent virtual thread multi-tenant data isolation verification.

### Requirement: concurrent-virtual-thread-isolation
The project SHALL maintain a concurrent multi-tenant data isolation test that uses genuine virtual-thread concurrency (not sequential execution) to verify no Tenant A data can appear in any Tenant B API response under load. The test SHALL fire at least 50 requests per tenant simultaneously, cover `/api/v1/shelters` (list + direct-object-reference), cover the bed search endpoint (`/api/v1/queries/beds`) for DV shelter isolation under `dvAccess` variance, and run in CI on every PR that touches `TenantContext`, `RlsDataSourceConfig`, or authentication filters. The test class SHALL be named `CrossTenantIsolationTest`.

#### Scenario: Concurrent shelter list isolation
- **GIVEN** Tenant A has shelters `["Safe Haven A1", "Safe Haven A2"]` and Tenant B has shelters `["Harbor House B1"]`
- **WHEN** 50 concurrent requests from Tenant A AND 50 concurrent requests from Tenant B hit GET `/api/v1/shelters`
- **THEN** no Tenant A response contains "Harbor House B1"
- **AND** no Tenant B response contains "Safe Haven A1" or "Safe Haven A2"

#### Scenario: Direct object reference returns 404 across tenants
- **GIVEN** a shelter in Tenant A with ID `{shelterAId}`
- **WHEN** a Tenant B user sends GET `/api/v1/shelters/{shelterAId}`
- **THEN** the response is 404 Not Found (not 403 — do not confirm existence)

#### Scenario: DV shelter isolation under concurrent load
- **GIVEN** Tenant A has a DV shelter and 50 concurrent bed search requests arrive from Tenant A with `dvAccess=false`
- **WHEN** the requests execute
- **THEN** no response contains the DV shelter's id or name

#### Scenario: Connection pool does not leak dvAccess across requests
- **GIVEN** a request with `dvAccess=true` completes and returns its connection to the pool
- **WHEN** the next request on that connection has `dvAccess=false`
- **THEN** the second request does NOT see DV shelters
- **AND** this is verified over at least 100 sequential iterations on the same pool

#### Scenario: Test runs in CI on every touching PR
- **WHEN** a PR modifies `TenantContext`, `RlsDataSourceConfig`, or any class in `org.fabt.shared.auth`
- **THEN** `CrossTenantIsolationTest` runs as part of the required CI check set
- **AND** the build fails if the test class does not exist or is renamed

### Requirement: parameterized-cross-tenant-fixture
The project SHALL maintain a parameterized JUnit 5 integration test `CrossTenantIsolationParameterizedTest` that exercises every tenant-owned state-mutating endpoint against a cross-tenant UUID and asserts 404. The fixture SHALL use `@ParameterizedTest` with `@MethodSource` yielding one row per `(endpoint path, HTTP verb, caller role, path-variable UUID supplier)` tuple. Every new tenant-owned endpoint SHALL add a row to the fixture as a PR-checklist requirement.

#### Scenario: Fixture covers every current tenant-owned endpoint
- **GIVEN** the set of tenant-owned state-mutating endpoints at the end of this change (multi-tenancy, shelter, reservation, referral, subscription, api-key, oauth2-provider, totp-admin, access-code, notification, escalation-policy as applicable)
- **WHEN** the test class runs
- **THEN** each endpoint has at least one row asserting "Tenant A actor + Tenant B UUID → 404"
- **AND** each row verifies Tenant B's state is unchanged after the failed attempt

#### Scenario: New tenanted endpoint missing a row fails review
- **WHEN** a PR adds a new state-mutating endpoint owned by a tenant (e.g. `POST /api/v1/intake-forms`)
- **AND** the PR does not add a row to `CrossTenantIsolationParameterizedTest`
- **THEN** PR review rejects the change citing the fixture-row requirement
- **AND** the review comment links to this spec as the source of the requirement

#### Scenario: Fixture uses TestAuthHelper primary + secondary tenant setup
- **GIVEN** the fixture needs two populated tenants with users + resources
- **WHEN** the fixture initializes
- **THEN** it uses `TestAuthHelper.setupSecondaryTenant`, `TestAuthHelper.createUserInTenant`, and `TestAuthHelper.setupUserWithDvAccessInTenant` to establish the two-tenant world
- **AND** the fixture does NOT use raw SQL INSERTs for tenant-owned entities (to avoid schema-drift breakage)

### Requirement: architecture-test-for-tenant-guard
The project SHALL maintain an ArchUnit test `TenantGuardArchitectureTest` that fails the build when a service-layer or controller-layer class calls `findById(UUID)` or `existsById(UUID)` on a tenant-owned repository without routing through the `findByIdAndTenantId` pattern or carrying a `@TenantUnscoped("<justification>")` annotation with a non-empty justification. The rule SHALL be strict (build-failing) from day one.

#### Scenario: Bare findById(UUID) in service layer fails build
- **GIVEN** a class in `org.fabt.*.service` calls `someRepository.findById(id).orElseThrow()` on a tenant-owned repository
- **WHEN** the ArchUnit test runs (as part of the test classpath on every build)
- **THEN** the test fails with a message identifying class name, method name, and call site
- **AND** the failure message names the two acceptable remediations: switch to `findByIdAndTenantId` or add `@TenantUnscoped("justification")`

#### Scenario: Bare existsById(UUID) in service layer fails build
- **GIVEN** a class in `org.fabt.*.service` calls `someRepository.existsById(id)` on a tenant-owned repository without a tenant guard
- **WHEN** the ArchUnit test runs
- **THEN** the test fails identically to the `findById` case

#### Scenario: @TenantUnscoped with non-empty justification passes
- **GIVEN** a service method annotated `@TenantUnscoped("system-scheduled reservation expiry needs platform-wide visibility")`
- **WHEN** the ArchUnit test runs
- **THEN** the call is allowed

#### Scenario: @TenantUnscoped with empty justification fails
- **GIVEN** a service method annotated `@TenantUnscoped("")`
- **WHEN** the ArchUnit test runs
- **THEN** the test fails with a message requiring a non-empty justification

#### Scenario: Controller-layer bare findById also covered
- **GIVEN** a class in `org.fabt.*.api` (controller package) calls `someRepository.findById(id)` without a tenant guard
- **WHEN** the ArchUnit test runs
- **THEN** the test fails (controllers are covered the same as services)

### Requirement: e2e-playwright-cross-tenant
The project SHALL include a Playwright end-to-end specification that exercises cross-tenant access against the 5 admin UI surfaces covered by this change (OAuth2 provider config, API key rotation, TOTP admin disable, subscription management, access-code generation). The Playwright spec SHALL run as part of the post-deploy smoke suite. It catches nginx routing, CORS, and JWT-filter regressions that Spring integration tests do not see.

#### Scenario: Playwright spec asserts 404 on each cross-tenant admin action
- **GIVEN** the Playwright fixture logs in as a Tenant A admin and has seeded Tenant B UUIDs
- **WHEN** the spec iterates through the 5 admin surfaces attempting cross-tenant actions
- **THEN** each attempt returns HTTP 404 (observed via the Playwright network log)
- **AND** the UI surfaces a "not found" message (or equivalent per-surface UX), not an error or a stack trace

#### Scenario: Playwright spec runs in post-deploy smoke
- **WHEN** the post-deploy smoke suite executes against a live deploy
- **THEN** the cross-tenant Playwright spec runs as part of that suite
- **AND** total post-deploy smoke runtime increases by no more than 30 seconds

### Requirement: e2e-karate-cross-tenant
The project SHALL include a Karate end-to-end specification that exercises the same 5 admin HTTP endpoints cross-tenant at the API contract level (no browser). The Karate spec complements the Playwright spec by catching handler-level regressions without browser overhead.

#### Scenario: Karate spec asserts 404 on each cross-tenant API call
- **GIVEN** the Karate feature authenticates as a Tenant A admin and references Tenant B UUIDs via test-data setup
- **WHEN** the feature invokes each of the 5 admin endpoints cross-tenant
- **THEN** each response is HTTP 404 with no entity body leakage from Tenant B
- **AND** the response shape matches the standard error envelope (no schema regression)

#### Scenario: Karate spec runs in CI and post-deploy smoke
- **WHEN** the CI E2E job executes on every PR
- **THEN** the Karate cross-tenant feature runs alongside existing Karate features
- **AND** the same feature runs in post-deploy smoke for parity with the Playwright layer

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
