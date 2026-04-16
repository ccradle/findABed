## MODIFIED Requirements

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

## ADDED Requirements

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
