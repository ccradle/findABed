## Why

The platform currently uses email/password authentication only. For the Raleigh pilot, social workers and shelter coordinators need "Login with Google" and "Login with Microsoft" — they use their existing organizational accounts and will not adopt a system that requires a separate password. The OAuth2 provider management infrastructure exists (tenant CRUD for providers, user-provider linking, encrypted client secrets) but the actual browser redirect/callback flow is not implemented. Without this, every pilot user must be manually provisioned with a password.

## What Changes

- Implement Spring Security OAuth2 Client redirect flow: authorization code grant with PKCE
- Dynamic `ClientRegistrationRepository` that loads provider config from the database (per-tenant, per-provider)
- Browser redirect: `/oauth2/authorize/{tenantSlug}/{providerName}` → IdP login → callback → JWT issued
- Closed registration: first-time OAuth2 login links to existing pre-provisioned account by email (admin must create user first — no auto-provisioning to prevent unauthorized access)
- Frontend login page: "Login with Google" and "Login with Microsoft" buttons (loaded from public provider endpoint)
- Admin UI OAuth2 provider management tab: add/edit/delete providers with write-once client secret (never displayed after creation), issuer URI validation, provider type presets (Google/Microsoft/Keycloak/Custom). Restricted to PLATFORM_ADMIN only
- Keycloak dev profile for local development and testing (`docker compose --profile oauth2`)
- `dev-start.sh --oauth2` flag to start Keycloak alongside the dev stack
- Updated runbook with OAuth2 troubleshooting (JWKS, Keycloak healthcheck, token refresh)
- Demo screenshots regenerated (login page with SSO buttons)

## Capabilities

### New Capabilities

- `oauth2-browser-flow`: Authorization code grant with PKCE, dynamic client registration, auto-provisioning

### Modified Capabilities

- `auth-and-roles`: Login page gains SSO buttons, user auto-provisioning on first OAuth2 login
- `deployment-profiles`: Keycloak added to docker-compose for dev/test
- `demo-capture`: Login page screenshot updated with SSO buttons

## Impact

- **Modified files**: `SecurityConfig.java` (OAuth2 client config), `application.yml` (OAuth2 client properties), `docker-compose.yml` (Keycloak service), `dev-start.sh` (`--oauth2` flag), `LoginPage.tsx` (SSO buttons), `AdminPanel.tsx` (OAuth2 Providers tab), `docs/runbook.md` (OAuth2 section), `docs/architecture.drawio` (Keycloak), `demo/index.html` (updated login screenshot)
- **New files**: `DynamicClientRegistrationRepository.java`, `OAuth2LoginSuccessHandler.java`, `OAuth2UserAutoProvisionService.java`, `infra/keycloak/fabt-dev-realm.json`
- **Database changes**: None (existing V10 tables `tenant_oauth2_provider` and `user_oauth2_link` are sufficient)
- **Frontend changes**: Login page SSO buttons, callback handling, i18n (EN/ES)
