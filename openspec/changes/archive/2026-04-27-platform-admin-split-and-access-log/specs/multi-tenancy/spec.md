## MODIFIED Requirements

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

## ADDED Requirements

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
