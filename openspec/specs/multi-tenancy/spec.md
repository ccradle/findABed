## ADDED Requirements

### Requirement: tenant-provisioning
The system SHALL allow a platform admin to create a new tenant with a name, slug, and configuration. Each tenant represents a Continuum of Care (CoC) or equivalent administrative boundary.

#### Scenario: Create a new tenant
- **WHEN** a platform admin sends POST `/api/v1/tenants` with name "Wake County CoC" and slug "wake-county"
- **THEN** the system creates a tenant record with a generated UUID, the provided name and slug, default configuration, and returns 201 with the tenant resource
- **AND** the tenant is immediately available for user and shelter creation

#### Scenario: Reject duplicate tenant slug
- **WHEN** a platform admin sends POST `/api/v1/tenants` with a slug that already exists
- **THEN** the system returns 409 Conflict with an error message identifying the duplicate slug

#### Scenario: Update tenant configuration
- **WHEN** a CoC admin sends PUT `/api/v1/tenants/{id}/config` with updated configuration (e.g., enabled auth methods, default locale)
- **THEN** the system updates the tenant configuration and returns 200 with the updated resource

### Requirement: tenant-isolation
The system SHALL enforce tenant isolation such that no API request can read or modify data belonging to a different tenant.

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

### Requirement: tenant-configuration
The system SHALL support per-tenant configuration that governs platform behavior for that tenant.

#### Scenario: Configurable tenant settings
- **WHEN** a tenant's configuration sets `api_key_auth_enabled` to false
- **THEN** API key authentication is disabled for that tenant and all API key requests return 401

#### Scenario: Default configuration on creation
- **WHEN** a new tenant is created without explicit configuration
- **THEN** the system applies default values: `api_key_auth_enabled=true`, `default_locale=en`
