## 1. Dynamic Client Registration

- [ ] 1.1 Create `DynamicClientRegistrationRepository` implementing `ClientRegistrationRepository`: loads from `TenantOAuth2ProviderService`, decrypts client_secret, builds `ClientRegistration` with OIDC discovery from issuer_uri. Cache with 5-minute TTL.
- [ ] 1.2 Registration ID format: `{tenantSlug}_{providerName}` (e.g., `dev-coc_google`)
- [ ] 1.3 Wire `DynamicClientRegistrationRepository` into `SecurityConfig` as the OAuth2 client registration source

## 2. OAuth2 Authorization Flow

- [ ] 2.1 Configure Spring Security OAuth2 Client in `SecurityConfig`: authorization code grant with PKCE (S256)
- [ ] 2.2 Create custom authorization request resolver that maps `/oauth2/authorize/{tenantSlug}/{providerName}` to the dynamic registration ID
- [ ] 2.3 Create custom redirect URI template: `/oauth2/callback/{tenantSlug}/{providerName}`
- [ ] 2.4 Create `OAuth2LoginSuccessHandler`: extract OAuth2 user info (sub, email, name), resolve or auto-provision FABT user, issue FABT JWT, redirect to frontend with token

## 3. Auto-Provisioning

- [ ] 3.1 Create `OAuth2UserAutoProvisionService`: on first OAuth2 login, check for existing user by email → link if found, create with OUTREACH_WORKER role if not
- [ ] 3.2 Handle edge case: email not provided by IdP (some Microsoft configs) — require email scope, fail gracefully with error message
- [ ] 3.3 Create user_oauth2_link on successful provisioning/linking

## 4. Frontend

- [ ] 4.1 Update `LoginPage.tsx`: fetch public providers via existing API, render branded SSO buttons (Google blue, Microsoft dark) below the email/password form
- [ ] 4.2 SSO button click: redirect to `/oauth2/authorize/{tenantSlug}/{providerName}`
- [ ] 4.3 Handle callback: parse JWT from redirect URL params, store in localStorage, redirect to role-appropriate page
- [ ] 4.4 Add i18n keys for SSO buttons (en.json + es.json): "Sign in with Google", "Sign in with Microsoft", "or sign in with email"

## 5. Keycloak Dev Profile

- [ ] 5.1 Add Keycloak service to `docker-compose.yml` under `profiles: [oauth2]` — Keycloak 24, port 8180
- [ ] 5.2 Create realm import JSON (`infra/keycloak/fabt-dev-realm.json`): realm `fabt-dev`, client `fabt-app`, test users matching seed data
- [ ] 5.3 Update seed `tenant_oauth2_provider` record: set issuer_uri to Keycloak localhost URL, enable the provider
- [ ] 5.4 Document in README: `docker compose --profile oauth2 up` to start with Keycloak

## 6. Testing

- [ ] 6.1 Integration test: DynamicClientRegistrationRepository resolves provider from database
- [ ] 6.2 Integration test: OAuth2UserAutoProvisionService creates new user on first login
- [ ] 6.3 Integration test: OAuth2UserAutoProvisionService links existing user by email
- [ ] 6.4 Integration test: disabled provider returns error (not redirect)
- [ ] 6.5 Karate E2E: public provider endpoint returns enabled providers for tenant
- [ ] 6.6 Playwright E2E: login page shows SSO buttons when providers are configured

## 7. Documentation

- [ ] 7.1 Update README: OAuth2 setup guide (Google Cloud Console, Microsoft Entra admin center)
- [ ] 7.2 Update docs/schema.dbml if any schema changes
- [ ] 7.3 Add `"iam"` to RDS CloudWatch log exports in Terraform (ACTION-5 from SRE review)
