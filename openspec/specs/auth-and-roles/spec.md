## ADDED Requirements

### Requirement: user-authentication
The system SHALL authenticate users via username/password and issue JWTs for subsequent requests.

#### Scenario: Successful login
- **WHEN** a user sends POST `/api/v1/auth/login` with valid credentials
- **THEN** the system returns 200 with an access token (JWT) and a refresh token
- **AND** the JWT contains `userId`, `tenantId`, `roles[]`, and `dvAccess` claims

#### Scenario: Failed login
- **WHEN** a user sends POST `/api/v1/auth/login` with invalid credentials
- **THEN** the system returns 401 Unauthorized with a generic error message (no indication of whether username or password was wrong)

#### Scenario: Token refresh
- **WHEN** a user sends POST `/api/v1/auth/refresh` with a valid refresh token
- **THEN** the system returns 200 with a new access token
- **AND** the previous access token is no longer required

#### Scenario: Expired token rejected
- **WHEN** a request includes a JWT whose `exp` claim is in the past
- **THEN** the system returns 401 Unauthorized

#### Scenario: Login page displays SSO buttons when providers configured
- **WHEN** the login page loads for a tenant with OAuth2 providers enabled
- **THEN** branded "Sign in with Google" and/or "Sign in with Microsoft" buttons appear below the email/password form
- **AND** the buttons are loaded dynamically from `GET /api/v1/tenants/{slug}/oauth2-providers/public`

#### Scenario: Login page shows email-only when no providers
- **WHEN** the login page loads for a tenant with no OAuth2 providers enabled
- **THEN** only the email/password form is shown (no SSO section)

### Requirement: user-provisioning
The system SHALL support linking OAuth2 identities to pre-provisioned user accounts (closed registration). No auto-provisioning — prevents unauthorized access to shelter data.

#### Scenario: Link OAuth2 to existing pre-provisioned account
- **WHEN** a user authenticates via OAuth2 and an account with their email already exists in the tenant
- **THEN** the OAuth2 identity is linked to the existing account
- **AND** the existing user's roles and dvAccess are preserved
- **AND** a FABT JWT is issued

#### Scenario: Reject OAuth2 login when no account exists
- **WHEN** a user authenticates via OAuth2 and no account exists with their email in the tenant
- **THEN** the system returns a clear error: "No account found for this email. Contact your CoC administrator to be added."
- **AND** no user account or link is created

### Requirement: oauth2-provider-admin-ui
The AdminPanel SHALL include an "OAuth2 Providers" tab (PLATFORM_ADMIN only) for managing identity provider configurations. Client secrets are write-once and never displayed after creation (RFC 9700). Provider type presets auto-fill issuer URIs. Connection testing validates the OIDC discovery endpoint before saving.

#### Scenario: Admin adds a Google provider
- **WHEN** a PLATFORM_ADMIN selects "Google" from the provider type dropdown
- **THEN** the issuer URI auto-fills to `https://accounts.google.com`
- **AND** after entering client ID and secret and saving, the provider appears in the list

#### Scenario: Client secret is never displayed after creation
- **WHEN** a provider is saved with a client secret
- **THEN** the secret is stored but never returned in GET responses

#### Scenario: Test connection validates issuer URI
- **WHEN** the admin clicks "Test Connection" with a valid issuer URI
- **THEN** the system calls the OIDC discovery endpoint and reports success

#### Scenario: Delete provider shows confirmation
- **WHEN** the admin clicks delete on a provider
- **THEN** a confirmation dialog warns that SSO login via that provider will stop working

### Requirement: role-based-access-control
The system SHALL enforce role-based access control with four roles: PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER.

#### Scenario: Platform admin access
- **WHEN** a user with PLATFORM_ADMIN role accesses any endpoint
- **THEN** the system grants access (platform admin has unrestricted access)

#### Scenario: CoC admin manages tenant users
- **WHEN** a user with COC_ADMIN role sends POST `/api/v1/users` within their tenant
- **THEN** the system creates the user with `dvAccess=false` by default and returns 201
- **AND** only a COC_ADMIN or PLATFORM_ADMIN can subsequently set `dvAccess=true` via PUT `/api/v1/users/{id}`

#### Scenario: Coordinator restricted to shelter operations
- **WHEN** a user with COORDINATOR role sends GET `/api/v1/shelters/{id}` for a shelter they are assigned to
- **THEN** the system returns the shelter data
- **AND** the coordinator cannot access admin endpoints (returns 403)

#### Scenario: Outreach worker query access
- **WHEN** a user with OUTREACH_WORKER role sends GET `/api/v1/shelters`
- **THEN** the system returns the shelter list (filtered by tenant)
- **AND** the outreach worker cannot modify shelter profiles (returns 403)

### Requirement: api-key-authentication
The system SHALL support long-lived API keys as an alternative authentication method, configurable per tenant.

#### Scenario: Shelter-scoped API key authentication
- **WHEN** a request includes header `X-API-Key: <valid-key>` where the key is scoped to a specific shelter
- **THEN** the system resolves the key to a tenant, shelter, and implicit role (COORDINATOR)
- **AND** the request proceeds with that security context

#### Scenario: Org-level API key authentication
- **WHEN** a request includes header `X-API-Key: <valid-key>` where the key has no shelter_id (org-level)
- **THEN** the system resolves the key to a tenant with implicit role (COC_ADMIN) and no shelter restriction
- **AND** the request proceeds with tenant-wide access for the implied role

#### Scenario: API key disabled for tenant
- **WHEN** a tenant's configuration has `api_key_auth_enabled=false` and a request uses an API key for that tenant
- **THEN** the system returns 401 Unauthorized with a message indicating API key auth is disabled

#### Scenario: API key creation
- **WHEN** a CoC admin sends POST `/api/v1/api-keys` with a shelter ID and optional label
- **THEN** the system generates a key, stores its hash, and returns the plaintext key exactly once
- **AND** subsequent GET requests for the key show only the last 4 characters

#### Scenario: API key rotation
- **WHEN** a CoC admin sends POST `/api/v1/api-keys/{id}/rotate`
- **THEN** the system generates a new key, invalidates the old one, and returns the new plaintext key exactly once

### Requirement: oauth2-social-login
The system SHALL support OAuth2/OIDC social login (Google, Microsoft, and other configurable providers) for users who have been pre-created by a CoC admin. OAuth2 login links to existing accounts by email match and issues the same JWT as password-based login.

#### Scenario: OAuth2 login redirect
- **WHEN** a user clicks "Login with Google" on the login page
- **THEN** the system redirects to Google's OAuth2 authorization endpoint with the appropriate client ID, redirect URI, and scopes (openid, email, profile)

#### Scenario: Successful OAuth2 callback with pre-created account
- **WHEN** Google redirects back with a valid authorization code and the email from the ID token matches a pre-created user in the system
- **THEN** the system links the OAuth2 identity to the existing user, issues a JWT with the same claims (userId, tenantId, roles[], dvAccess) as a password login, and redirects to the user's role-appropriate landing page

#### Scenario: OAuth2 callback with no matching account
- **WHEN** Google redirects back with a valid authorization code but the email does not match any pre-created user
- **THEN** the system returns an error page: "No account found for this email. Contact your CoC administrator to be added."
- **AND** no user account is auto-provisioned

#### Scenario: OAuth2 provider configured per tenant
- **WHEN** a CoC admin enables Google OAuth2 for their tenant via POST `/api/v1/tenants/{id}/oauth2-providers` with provider name, client ID, client secret, and issuer URI
- **THEN** the login page for that tenant displays the "Login with Google" button
- **AND** tenants without configured providers show only the username/password login

#### Scenario: Multiple OAuth2 providers
- **WHEN** a tenant has both Google and Microsoft OAuth2 configured
- **THEN** the login page displays both "Login with Google" and "Login with Microsoft" buttons
- **AND** either provider can link to the same pre-created user account by email

#### Scenario: OAuth2 login issues identical JWT
- **WHEN** a user logs in via OAuth2
- **THEN** the issued JWT is structurally identical to a password-based JWT (same claims, same expiry)
- **AND** downstream API authorization does not distinguish between authentication methods

### Requirement: dv-access-control
The system SHALL enforce DV shelter data access at the PostgreSQL Row Level Security layer, gated by a `dvAccess` claim.

#### Scenario: User with DV access sees DV shelters
- **WHEN** an authenticated user with `dvAccess=true` queries shelters
- **THEN** the response includes both DV and non-DV shelters

#### Scenario: User without DV access cannot see DV shelters
- **WHEN** an authenticated user with `dvAccess=false` queries shelters
- **THEN** the response excludes all shelters where `dv_shelter=true`
- **AND** this filtering is enforced by PostgreSQL RLS, not application code

#### Scenario: DV access flag set in database session
- **WHEN** a request is processed with `dvAccess=true`
- **THEN** the system executes `SET LOCAL app.dv_access = 'true'` before any data query
- **AND** the setting is automatically cleared on transaction commit or rollback

### Requirement: error-response-security
The system SHALL suppress all implementation details from error responses and audit all permitAll() paths.

- REQ-AUTH-ERR-1: `GlobalExceptionHandler` MUST include a catch-all `@ExceptionHandler(Exception.class)` that returns structured `ErrorResponse` with generic message
- REQ-AUTH-ERR-2: No exception response MUST contain Java class names, stack traces, or Spring Boot version information
- REQ-AUTH-ERR-3: `server.error.include-stacktrace` MUST be set to `never` in all profiles
- REQ-AUTH-ERR-4: `server.error.include-message` MUST be set to `never` in all profiles
- REQ-AUTH-ERR-5: Unhandled exceptions MUST be logged at ERROR level server-side with full stack trace
- REQ-AUTH-ERR-6: The `/error` fallback endpoint MUST NOT expose implementation details
- REQ-AUTH-PERMIT-1: Every `permitAll()` path in SecurityConfig MUST be documented with justification and verified to not disclose sensitive information when accessed with a cleared security context

#### Scenario: Unhandled exception returns generic error
- **WHEN** an endpoint throws an unexpected NullPointerException
- **THEN** the status is 500
- **AND** the body contains "An unexpected error occurred"
- **AND** the body does not contain "NullPointerException" or "at org.fabt" or "at java."

#### Scenario: Malformed JSON does not expose stack trace
- **WHEN** a client POSTs invalid JSON to /api/v1/auth/login
- **THEN** the body does not contain "Exception" or "stack"

#### Scenario: Swagger disabled in prod profile
- **WHEN** the application is running with the prod profile active
- **THEN** GET /api/v1/docs returns 404
