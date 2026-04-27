## ADDED Requirements

### Requirement: tenant-provisioning
The system SHALL allow a `PLATFORM_OPERATOR` (gated additionally by `@PlatformAdminOnly`) to create a new tenant with a name, slug, and configuration. Each tenant represents a Continuum of Care (CoC) or equivalent administrative boundary. (Previously: "platform admin" via `PLATFORM_ADMIN`. Tenant creation is genuinely platform-scoped — it changes the platform's tenant inventory, not any single tenant's state — and now requires the audited unseal channel.)

#### Scenario: Create a new tenant
- **WHEN** a `PLATFORM_OPERATOR` sends POST `/api/v1/tenants` with name "Wake County CoC" and slug "wake-county" with header `X-Platform-Justification: New CoC onboarding per board approval 2026-Q3`
- **THEN** the system creates a tenant record with a generated UUID, the provided name and slug, default configuration, and returns 201 with the tenant resource
- **AND** the tenant is immediately available for user and shelter creation
- **AND** a row is written to `platform_admin_access_log` with `action = PLATFORM_TENANT_CREATED` and the justification text
- **AND** a chained row is written to `audit_events` with `tenant_id = <new tenant's id>`, `action = PLATFORM_TENANT_CREATED`, and is the FIRST row in the new tenant's chain

#### Scenario: COC_ADMIN cannot create tenants
- **WHEN** a `COC_ADMIN` sends POST `/api/v1/tenants`
- **THEN** the system returns HTTP 403 Forbidden
- **AND** no row is written to either log table

#### Scenario: PLATFORM_OPERATOR without justification header rejected
- **WHEN** a `PLATFORM_OPERATOR` sends POST `/api/v1/tenants` without `X-Platform-Justification` header
- **THEN** the system returns HTTP 400 Bad Request with `{"error":"justification_required"}`

#### Scenario: Reject duplicate tenant slug
- **WHEN** a `PLATFORM_OPERATOR` sends POST `/api/v1/tenants` with a slug that already exists
- **THEN** the system returns 409 Conflict with an error message identifying the duplicate slug
- **AND** an `audit_events` row is still written under SYSTEM_TENANT_ID for the FAILED attempt (using the existing Phase F-3 attempt-audit pattern)

#### Scenario: Update tenant configuration
- **WHEN** a `COC_ADMIN` sends PUT `/api/v1/tenants/{id}/config` with updated configuration (e.g., enabled auth methods, default locale)
- **THEN** the system updates the tenant configuration and returns 200 with the updated resource
- **AND** the operation is gated on COC_ADMIN, NOT PLATFORM_OPERATOR (tenant config is tenant-scoped)

### Requirement: tenant-isolation
The system SHALL enforce tenant isolation such that no API request can read or modify data belonging to a different tenant.

The canonical enforcement layer is the service layer: tenant-owned repositories SHALL expose `findByIdAndTenantId(UUID id, UUID tenantId)` (or equivalent multi-key variants), and services SHALL look up resources through a private `findByIdOrThrow(UUID)` helper that pulls `tenantId` from `TenantContext` and throws `NoSuchElementException` on mismatch. Cross-tenant access SHALL return 404 Not Found (not 403, not 200) regardless of whether the target UUID exists in another tenant. RLS policies on tenant-owned tables SHALL NOT be relied on as the sole tenant guard; RLS is defense-in-depth for orthogonal concerns (e.g., `dv_access`).

#### Scenario: Query scoped to tenant
- **WHEN** an authenticated user in tenant A sends GET `/api/v1/shelters`
- **THEN** the system returns only shelters belonging to tenant A
- **AND** no shelters from any other tenant are included in the response

#### Scenario: Cross-tenant write rejected
- **WHEN** an authenticated user in tenant A sends PUT `/api/v1/shelters/{id}` where the shelter belongs to tenant B
- **THEN** the system returns 404 Not Found (not 403, to avoid confirming the resource exists in another tenant)

#### Scenario: Tenant context required
- **WHEN** a request arrives without a resolvable tenant context (no valid JWT or API key)
- **THEN** the system returns 401 Unauthorized before any data query executes

#### Scenario: Cross-tenant read returns 404 via repository guard
- **WHEN** an authenticated admin in tenant A sends GET `/api/v1/api-keys/{id}` where the API key belongs to tenant B
- **AND** the repository lookup goes through `findByIdAndTenantId(id, tenantContext.getTenantId())`
- **THEN** the repository returns an empty `Optional`
- **AND** the service throws `NoSuchElementException`
- **AND** the HTTP response is 404 Not Found

#### Scenario: Cross-tenant mutation leaves target tenant unchanged
- **WHEN** an authenticated admin in tenant A sends DELETE `/api/v1/subscriptions/{id}` where the subscription belongs to tenant B
- **THEN** the system returns 404 Not Found
- **AND** the subscription in tenant B remains unchanged (status, updated_at, all fields identical to pre-request state)
- **AND** no audit event is emitted in tenant B for the failed attempt

#### Scenario: Cross-tenant OAuth2 provider mutation blocked
- **WHEN** an authenticated CoC admin in tenant A sends PATCH `/api/v1/oauth2-providers/{id}` where the provider belongs to tenant B
- **THEN** the system returns 404 Not Found
- **AND** tenant B's OAuth2 provider configuration (issuerUri, clientId, clientSecret) remains unchanged
- **AND** no OIDC login flow in tenant B is affected

#### Scenario: Cross-tenant write via URL path rejected (URL-path-sink class, D11)
- **GIVEN** an authenticated CoC admin in tenant A sends POST `/api/v1/tenants/{tenantB-uuid}/oauth2-providers` with a request body containing an attacker-controlled `issuerUri`
- **WHEN** the controller validates the URL path `{tenantId}` against `TenantContext.getTenantId()`
- **THEN** the path value does NOT match the caller's JWT tenant
- **AND** the controller throws `NoSuchElementException` → HTTP 404 Not Found (not 403, not 201)
- **AND** zero rows are inserted into `tenant_oauth2_provider` (neither in Tenant A nor Tenant B)
- **AND** no downstream audit events are emitted in either tenant as a consequence of the failed attempt

#### Scenario: Service accepts `tenantId` parameter is forbidden for tenant-owned writes (D11 enforcement)
- **GIVEN** a service method in `org.fabt.*.service` accepts `UUID tenantId` as a parameter AND calls `repository.save(entity)` on a tenant-owned entity
- **AND** the method does not carry `@TenantUnscoped("justification")`
- **WHEN** the Phase 3 ArchUnit rule runs
- **THEN** the build fails with a message identifying the offending method and the two acceptable remediations: (a) drop the `tenantId` parameter and source from `TenantContext.getTenantId()` internally, or (b) add `@TenantUnscoped("...")` with a non-empty justification

#### Scenario: Cross-tenant admin 2FA disable blocked
- **WHEN** an authenticated CoC admin in tenant A sends POST `/api/v1/users/{id}/totp/disable` where the user belongs to tenant B
- **THEN** the system returns 404 Not Found
- **AND** tenant B's user retains 2FA enrollment and recovery codes

#### Scenario: Cross-tenant access-code generation does not create VAWA audit entry
- **GIVEN** an authenticated CoC admin in tenant A (dv_access=true) sends POST `/api/v1/access-codes` with a `targetUserId` belonging to tenant B (who may be a DV advocate)
- **WHEN** the controller's `userService.getUser(targetUserId)` executes with `TenantContext` scoped to tenant A
- **THEN** the service throws `NoSuchElementException` → HTTP 404 Not Found
- **AND** the `audit_events` table SHALL NOT contain any new row with `event_type IN ('ACCESS_CODE_GENERATED', 'ACCESS_CODE_GENERATED_FOR_PROTECTED_USER')` referencing tenant B's user
- **AND** the `one_time_access_code` table SHALL NOT contain any new row referencing tenant B's user
- **AND** no downstream `hmis_outbox` delivery SHALL be queued for tenant B as a consequence of the failed attempt
- **AND** VAWA 34 U.S.C. 12291(b)(2) alignment is preserved — tenant B's protected-user records are neither read, written, nor audit-logged by tenant A's admin

### Requirement: tenant-guard-enforcement
The system SHALL mechanically prevent service-layer and controller-layer code from bypassing the tenant guard by calling `findById(UUID)` or `existsById(UUID)` on a tenant-owned repository without either routing through a `findByIdAndTenantId` variant or carrying an explicit `@TenantUnscoped("<justification>")` annotation. Enforcement SHALL be a build-failing ArchUnit rule from day one (not advisory).

#### Scenario: Service calls bare findById — build fails
- **GIVEN** a service class in `org.fabt.foo.service` adds a method `public Foo getFoo(UUID id) { return fooRepository.findById(id).orElseThrow(); }`
- **WHEN** the test build runs
- **THEN** the ArchUnit test `TenantGuardArchitectureTest` fails with a message naming the offending class, method, and line
- **AND** the failure message points to the `findByIdAndTenantId` pattern as the remediation

#### Scenario: Service calls bare existsById — build fails
- **GIVEN** a service class adds `if (fooRepository.existsById(id)) { ... }` without a tenant predicate
- **WHEN** the test build runs
- **THEN** the ArchUnit rule fails identically to the `findById` case, because `existsById` has the same defect shape

#### Scenario: @TenantUnscoped with justification is accepted
- **GIVEN** a service method carries `@TenantUnscoped("system-scheduled reservation expiry needs platform-wide visibility; tenant context is set from the fetched row")`
- **WHEN** the test build runs
- **THEN** the ArchUnit rule accepts the call
- **AND** no other service method is allowed to call the same repository method without its own annotation or routing through a tenant-scoped variant

#### Scenario: Empty @TenantUnscoped justification rejected
- **GIVEN** a developer adds `@TenantUnscoped("")` (empty string)
- **WHEN** the test build runs
- **THEN** the ArchUnit rule fails with a message requiring a non-empty justification

#### Scenario: Batch-snapshot method rename is enforced
- **GIVEN** `EscalationPolicyService.findByIdForBatch(UUID)` is the renamed batch-callable variant
- **WHEN** a class outside `org.fabt.referral.batch.*` attempts to call `findByIdForBatch`
- **THEN** a secondary ArchUnit rule fails the build, scoping the method to the batch package only

#### Scenario: Webhook-internal methods are restricted to WebhookDeliveryService
- **GIVEN** `SubscriptionService.markFailingInternal`, `.deactivateInternal`, `.recordDeliveryInternal` are the renamed internal variants
- **WHEN** any class other than `WebhookDeliveryService` attempts to call these methods
- **THEN** a secondary ArchUnit rule fails the build

### Requirement: tenant-configuration
The system SHALL support per-tenant configuration that governs platform behavior for that tenant.

#### Scenario: Configurable tenant settings
- **WHEN** a tenant's configuration sets `api_key_auth_enabled` to false
- **THEN** API key authentication is disabled for that tenant and all API key requests return 401

#### Scenario: Default configuration on creation
- **WHEN** a new tenant is created without explicit configuration
- **THEN** the system applies default values: `api_key_auth_enabled=true`, `default_locale=en`

### Requirement: Cross-tenant cross-check accommodates platform JWTs
The Phase A4 D25 cross-tenant cross-check at `JwtService` SHALL be extended so that JWTs with `iss = "fabt-platform"` and NO `tenantId` claim do NOT trigger `CrossTenantJwtException`. Instead, those JWTs route through the platform-key resolver (`platform_key_material`) and are admitted to platform-only endpoints (gated separately by `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` + `@PlatformAdminOnly`).

#### Scenario: Platform JWT bypasses tenant cross-check
- **WHEN** a JWT with `iss="fabt-platform"` (no `tenantId` claim) is presented
- **THEN** the cross-tenant cross-check at `JwtService.java:409-424` is NOT applied
- **AND** the JWT is validated against `platform_key_material` instead of `jwt_key_generation`

#### Scenario: Tenant JWT with platform-shaped claims rejected
- **WHEN** a JWT with `iss="fabt-tenant"` but missing `tenantId` claim is presented
- **THEN** validation fails with HTTP 401 (existing behavior; we did not loosen this check)

#### Scenario: Platform JWT presented to tenant-scoped endpoint
- **WHEN** a JWT with `iss="fabt-platform"` is presented to a tenant-scoped endpoint (e.g., GET `/api/v1/users` which requires a tenant context)
- **THEN** the request is rejected with HTTP 401 because the platform JWT has no `tenantId` claim and the endpoint requires one
- **AND** the request is NOT routed to a "platform sees all tenants" code path (no such code path exists)
