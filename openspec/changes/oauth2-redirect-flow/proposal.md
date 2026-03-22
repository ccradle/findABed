## Why

The platform currently uses email/password authentication only. For the Raleigh pilot, social workers and shelter coordinators need "Login with Google" and "Login with Microsoft" — they use their existing organizational accounts and will not adopt a system that requires a separate password. The OAuth2 provider management infrastructure exists (tenant CRUD for providers, user-provider linking, encrypted client secrets) but the actual browser redirect/callback flow is not implemented. Without this, every pilot user must be manually provisioned with a password.

## What Changes

- Implement Spring Security OAuth2 Client redirect flow: authorization code grant with PKCE
- Dynamic `ClientRegistrationRepository` that loads provider config from the database (per-tenant, per-provider)
- Browser redirect: `/oauth2/authorize/{tenantSlug}/{providerName}` → IdP login → callback → JWT issued
- Auto-provisioning: first-time OAuth2 login creates a user account and links it (no admin intervention)
- Frontend login page: "Login with Google" and "Login with Microsoft" buttons (loaded from public provider endpoint)
- Keycloak dev profile for local development and testing
- Add `"iam"` to RDS CloudWatch log exports (per SRE recommendation ACTION-5)

## Capabilities

### New Capabilities

- `oauth2-browser-flow`: Authorization code grant with PKCE, dynamic client registration, auto-provisioning

### Modified Capabilities

- `auth-and-roles`: Login page gains SSO buttons, user auto-provisioning on first OAuth2 login
- `deployment-profiles`: Keycloak added to docker-compose for dev/test

## Impact

- **Modified files**: `SecurityConfig.java` (OAuth2 client config), `application.yml` (OAuth2 client properties), `docker-compose.yml` (Keycloak service), frontend `LoginPage.tsx` (SSO buttons)
- **New files**: `DynamicClientRegistrationRepository.java`, `OAuth2LoginSuccessHandler.java`, `OAuth2UserAutoProvisionService.java`, Keycloak realm import JSON
- **Database changes**: None (existing tables `tenant_oauth2_provider` and `user_oauth2_link` are sufficient)
- **Frontend changes**: Login page SSO buttons, callback handling
