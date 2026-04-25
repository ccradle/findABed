## MODIFIED Requirements

### Requirement: role-based-access-control
The system SHALL enforce role-based access control with FIVE roles: `COC_ADMIN`, `COORDINATOR`, `OUTREACH_WORKER`, `PLATFORM_OPERATOR`, and `PLATFORM_ADMIN` (deprecated). The deprecated `PLATFORM_ADMIN` value remains in the enum during a one-release deprecation window for backward compatibility but SHALL NOT be assigned to any new user. New code SHALL use `COC_ADMIN` for tenant-scoped admin authorization and `PLATFORM_OPERATOR` (gated additionally by `@PlatformAdminOnly`) for platform-scoped authorization.

#### Scenario: PLATFORM_ADMIN deprecated
- **WHEN** a developer attempts to assign `PLATFORM_ADMIN` to a new `app_user.roles` array via any application code path
- **THEN** the operation succeeds (backward compatibility) BUT a `WARN` is logged with category `deprecation.platform_admin_assignment`
- **AND** an ArchUnit test fails the build if any new `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` annotation is added to source after this change

#### Scenario: COC_ADMIN manages tenant users
- **WHEN** a user with `COC_ADMIN` role sends POST `/api/v1/users` within their tenant
- **THEN** the system creates the user with `dvAccess=false` by default and returns 201
- **AND** only a `COC_ADMIN` can subsequently set `dvAccess=true` via PUT `/api/v1/users/{id}`

#### Scenario: PLATFORM_OPERATOR access requires platform JWT
- **WHEN** a request bears a JWT with role `PLATFORM_OPERATOR`
- **THEN** the JWT MUST have `iss="fabt-platform"` and NO `tenantId` claim
- **AND** validation routes through the platform-key JwtDecoder, NOT the tenant-key JwtDecoder

#### Scenario: COC_ADMIN of tenant A cannot access tenant B
- **WHEN** a `COC_ADMIN` of tenant A presents their JWT to any tenant-scoped endpoint targeting tenant B
- **THEN** the JWT validation rejects the token with `CrossTenantJwtException` (kid resolves to tenant A; cross-check against URL/path tenant fails)
- **AND** the response is HTTP 401

#### Scenario: Coordinator restricted to shelter operations
- **WHEN** a user with `COORDINATOR` role sends GET `/api/v1/shelters/{id}` for a shelter they are assigned to
- **THEN** the system returns the shelter data
- **AND** the coordinator cannot access admin endpoints (returns 403)

#### Scenario: Outreach worker query access
- **WHEN** a user with `OUTREACH_WORKER` role sends GET `/api/v1/shelters`
- **THEN** the system returns shelters within their tenant scope (DV shelters redacted unless dvAccess=true)

#### Scenario: Backward-compat for in-flight PLATFORM_ADMIN JWTs (tenant-scoped endpoints)
- **WHEN** a JWT bearing the deprecated `PLATFORM_ADMIN` role accesses a tenant-scoped endpoint after the deploy window
- **THEN** the request succeeds for one release window (because COC_ADMIN backfill in V87 added COC_ADMIN to the same user record)
- **AND** the deprecation cleanup release REMOVES the `PLATFORM_ADMIN` enum value entirely

#### Scenario: PLATFORM_ADMIN JWT cannot reach platform-scoped endpoints after deploy
- **WHEN** a JWT bearing only `PLATFORM_ADMIN` (no `PLATFORM_OPERATOR`) accesses an endpoint annotated `@PlatformAdminOnly`
- **THEN** the response is HTTP 403 Forbidden
- **AND** no audit row is written

### Requirement: oauth2-provider-admin-ui
The AdminPanel SHALL include an "OAuth2 Providers" tab (`COC_ADMIN` only) for managing identity provider configurations. Client secrets are write-once and never displayed after creation (RFC 9700). Provider type presets auto-fill issuer URIs. Connection testing validates the OIDC discovery endpoint before saving.

#### Scenario: Admin adds a Google provider
- **WHEN** a `COC_ADMIN` selects "Google" from the provider type dropdown
- **THEN** the issuer URI auto-fills to `https://accounts.google.com`
- **AND** after entering client ID and secret and saving, the provider appears in the list

#### Scenario: Client secret is never displayed after creation
- **WHEN** a provider is saved with a client secret
- **THEN** the secret is stored but never returned in GET responses

#### Scenario: Test connection validates issuer URI
- **WHEN** a `COC_ADMIN` clicks "Test Connection" on a provider configuration
- **THEN** the system validates the OIDC discovery endpoint and returns success/failure feedback before allowing save

## ADDED Requirements

### Requirement: Iss-routed JwtDecoder dispatch
The `SecurityConfig` SHALL register a JwtDecoder that routes by the `iss` claim: `iss="fabt-tenant"` resolves kid via `jwt_key_generation` (tenant key); `iss="fabt-platform"` resolves kid via `platform_key_material` (platform key); any other `iss` value SHALL be rejected.

#### Scenario: Platform JWT routes to platform validator
- **WHEN** a JWT with `iss="fabt-platform"` is presented
- **THEN** kid is resolved via `platform_key_material` only
- **AND** signature is verified against the platform key

#### Scenario: Tenant JWT routes to tenant validator
- **WHEN** a JWT with `iss="fabt-tenant"` is presented
- **THEN** kid is resolved via `jwt_key_generation` only
- **AND** signature is verified against the per-tenant DEK-derived key

#### Scenario: Unknown iss rejected
- **WHEN** a JWT with `iss="fabt-other"` (or missing iss) is presented
- **THEN** validation fails immediately with HTTP 401
- **AND** no kid lookup is performed
