## MODIFIED Requirements

### Requirement: user-authentication
#### Scenario: Login page displays SSO buttons when providers configured
- **WHEN** the login page loads for a tenant with OAuth2 providers enabled
- **THEN** branded "Sign in with Google" and/or "Sign in with Microsoft" buttons appear below the email/password form
- **AND** the buttons are loaded dynamically from `GET /api/v1/tenants/{slug}/oauth2-providers/public`

#### Scenario: Login page shows email-only when no providers
- **WHEN** the login page loads for a tenant with no OAuth2 providers enabled
- **THEN** only the email/password form is shown (no SSO section)

### Requirement: user-provisioning
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
- **AND** the "Sign in with Google" button appears on the login page for that tenant

#### Scenario: Client secret is never displayed after creation
- **WHEN** a provider is saved with a client secret
- **THEN** the secret is stored but never returned in GET responses
- **AND** the provider list shows provider name, status, issuer URI — no secret

#### Scenario: Test connection validates issuer URI
- **WHEN** the admin clicks "Test Connection" with a valid issuer URI
- **THEN** the system calls the OIDC discovery endpoint and reports success
- **WHEN** the issuer URI is invalid or unreachable
- **THEN** the system reports the connection failure before saving

#### Scenario: Delete provider shows confirmation
- **WHEN** the admin clicks delete on a provider
- **THEN** a confirmation dialog warns that SSO login via that provider will stop working
