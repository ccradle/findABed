## Purpose

Browser-based OAuth2 login via authorization code grant with PKCE. Dynamic per-tenant provider loading, closed registration (link-or-reject), branded SSO buttons on login page.

## Requirements

### Requirement: oauth2-authorization-code-flow
The system SHALL support browser-based OAuth2 login via the authorization code grant with PKCE. Tenant-specific provider configuration is loaded dynamically from the database. Supported providers: Google (OpenID Connect) and Microsoft Entra ID (OpenID Connect).

#### Scenario: Login with Google
- **WHEN** a user clicks "Sign in with Google" on the login page for tenant "dev-coc"
- **THEN** the browser redirects to Google's authorization endpoint with client_id, redirect_uri, PKCE code_challenge, and scope=openid+profile+email
- **AND** after Google authentication, the callback exchanges the code for tokens
- **AND** the system issues a FABT JWT and redirects to the role-appropriate page

#### Scenario: Login with Microsoft
- **WHEN** a user clicks "Sign in with Microsoft" on the login page
- **THEN** the flow is identical to Google but uses Microsoft's OIDC endpoints resolved from the tenant's provider issuer_uri

#### Scenario: Invalid or disabled provider returns error
- **WHEN** a user attempts OAuth2 login with a provider that is disabled or does not exist for the tenant
- **THEN** the system returns an error and does not redirect to any IdP

### Requirement: oauth2-closed-registration
The system SHALL use a closed registration model for OAuth2 login. If a user with the same email exists in the tenant, the OAuth2 identity is linked to the existing account. If no user exists, the login is rejected with a clear error message directing the user to contact their CoC administrator. The system SHALL NOT auto-provision user accounts — this prevents unauthorized access to shelter data.

#### Scenario: First-time OAuth2 login with pre-provisioned account
- **WHEN** a user authenticates via Google for the first time and an account with their email exists in the tenant
- **THEN** the system links the Google subject ID to the existing account
- **AND** the existing user's roles and dvAccess are preserved
- **AND** a FABT JWT is issued

#### Scenario: First-time OAuth2 login without account is rejected
- **WHEN** a user authenticates via Google for the first time and no account exists with their email
- **THEN** the system returns an error: "No account found for this email. Contact your CoC administrator to be added."
- **AND** no user account is created
- **AND** no user_oauth2_link record is created

#### Scenario: Subsequent OAuth2 logins use existing link
- **WHEN** a user authenticates via Google and a user_oauth2_link already exists
- **THEN** the system resolves the user via the link and issues a JWT without querying by email

### Requirement: dynamic-client-registration
The system SHALL load OAuth2 client registrations dynamically from the tenant_oauth2_provider database table, not from static application.yml configuration. Provider endpoints are resolved via OIDC discovery (/.well-known/openid-configuration) from the provider's issuer_uri.

#### Scenario: Provider added at runtime is immediately available
- **WHEN** a CoC admin adds a Google OAuth2 provider via the admin API
- **THEN** the "Sign in with Google" button appears on the login page
- **AND** the OAuth2 flow works without application restart

### Requirement: frontend-sso-buttons
The login page SHALL display branded SSO buttons for each enabled OAuth2 provider. Buttons are loaded dynamically from the public provider endpoint.

#### Scenario: Login page shows provider buttons
- **WHEN** the login page loads for a tenant with Google and Microsoft providers enabled
- **THEN** "Sign in with Google" and "Sign in with Microsoft" buttons are displayed
- **AND** clicking a button initiates the OAuth2 redirect flow

#### Scenario: No SSO buttons when no providers configured
- **WHEN** the login page loads for a tenant with no OAuth2 providers
- **THEN** only the email/password form is shown
