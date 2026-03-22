## Context

The auth module already has: `TenantOAuth2Provider` entity (client_id, client_secret_encrypted, issuer_uri), `UserOAuth2Link` entity (provider_name, external_subject_id), provider CRUD API, account linking API, and a public endpoint listing enabled providers per tenant. What's missing is the Spring Security OAuth2 Client configuration that actually performs the browser redirect.

The Raleigh pilot needs Google Workspace and Microsoft Entra ID (Azure AD) support. Both use standard OpenID Connect with the authorization code grant.

## Goals / Non-Goals

**Goals:**
- Browser redirect OAuth2 login (authorization code + PKCE)
- Dynamic client registration from database (not static application.yml)
- Google and Microsoft provider support
- Auto-provisioning of users on first OAuth2 login
- Keycloak for local development and testing
- Frontend SSO buttons on login page

**Non-Goals:**
- SAML (not needed for Google/Microsoft OIDC)
- Social login (Facebook, GitHub) — only organizational IdPs
- Custom OAuth2 scopes beyond openid/profile/email
- Token exchange or on-behalf-of flows

## Decisions

### D1: Dynamic ClientRegistrationRepository from database

Spring Security's `ClientRegistrationRepository` is normally static (application.yml). We need dynamic per-tenant registration loading from `tenant_oauth2_provider` table.

Implement `DynamicClientRegistrationRepository` that:
1. On `findByRegistrationId(registrationId)`, parses `registrationId` as `{tenantSlug}_{providerName}`
2. Loads the `TenantOAuth2Provider` from the database
3. Decrypts `client_secret_encrypted`
4. Builds a `ClientRegistration` with the provider's `issuer_uri`, `client_id`, `client_secret`
5. Uses OIDC discovery (`.well-known/openid-configuration`) to resolve authorization/token/userinfo endpoints

Cache registrations for 5 minutes (providers don't change often).

### D2: Authorization flow with tenant context

The OAuth2 flow must carry tenant context through the redirect:

1. User clicks "Login with Google" on the login page for tenant `dev-coc`
2. Frontend redirects to `/oauth2/authorize/dev-coc/google`
3. Backend resolves tenant + provider, builds authorization URL
4. User authenticates at Google
5. Google redirects back to `/oauth2/callback/{tenantSlug}/{providerName}`
6. Backend exchanges code for tokens, extracts `sub` + `email`
7. Backend looks up or auto-provisions user, issues FABT JWT
8. Frontend receives JWT and redirects to role-appropriate page

### D3: Auto-provisioning on first OAuth2 login

When a user authenticates via OAuth2 for the first time (no existing `user_oauth2_link`):
1. Check if a user with that email exists in the tenant → link if found
2. If no user exists, create one with default role `OUTREACH_WORKER` and `dvAccess=false`
3. Create the `user_oauth2_link` record
4. Issue JWT as normal

CoC admins can later upgrade the user's role via the admin panel.

### D4: Frontend SSO buttons

The login page already calls `GET /api/v1/tenants/{slug}/oauth2-providers/public` to get enabled providers. Add buttons for each:
- Google: branded "Sign in with Google" button
- Microsoft: branded "Sign in with Microsoft" button
- Click → redirect to `/oauth2/authorize/{tenantSlug}/{providerName}`

### D5: Keycloak for local dev/test

Add Keycloak to docker-compose (profile: `oauth2`) with:
- Pre-imported realm (`fabt-dev`) with test users
- Client registration matching the seed `tenant_oauth2_provider` record
- Accessible at `http://localhost:8180`

### D6: PKCE (Proof Key for Code Exchange)

All OAuth2 flows use PKCE (S256) — this is mandatory for public clients and best practice for confidential clients. Spring Security OAuth2 Client supports PKCE out of the box.
