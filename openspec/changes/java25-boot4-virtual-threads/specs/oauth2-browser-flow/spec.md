## MODIFIED Requirements

### Requirement: oauth2-authorization-code-flow
The system SHALL support browser-based OAuth2 login via the authorization code grant with PKCE. Tenant-specific provider configuration is loaded dynamically from the database. Supported providers: Google (OpenID Connect) and Microsoft Entra ID (OpenID Connect). The OAuth2 callback handler SHALL execute on a virtual thread so that blocking HTTP calls to the IdP (token exchange, userinfo fetch) do not occupy a platform thread.

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

#### Scenario: OAuth2 callback does not block platform threads
- **WHEN** the OAuth2 callback handler executes the token exchange (blocking HTTP POST to IdP) and userinfo fetch (blocking HTTP GET to IdP)
- **THEN** the callback runs on a virtual thread provided by Tomcat's virtual thread executor
- **AND** the platform carrier thread is released during each blocking HTTP call
- **AND** concurrent OAuth2 logins do not exhaust the platform thread pool
