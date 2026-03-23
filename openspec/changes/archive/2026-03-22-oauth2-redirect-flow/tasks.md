## 1. Dynamic Client Registration

- [x] 1.1 Create `DynamicClientRegistrationRepository` implementing `ClientRegistrationRepository`: loads from `TenantOAuth2ProviderService`, decrypts client_secret, builds `ClientRegistration` with OIDC discovery from issuer_uri. Cache with 5-minute TTL.
- [x] 1.2 Registration ID format: `{slug}-{providerName}` (e.g., `dev-coc-google`) — matches existing PublicOAuth2ProviderController URL format
- [x] 1.3 Wire `DynamicClientRegistrationRepository` into `SecurityConfig` as the OAuth2 client registration source

## 2. OAuth2 Authorization Flow

- [x] 2.1 Configure Spring Security OAuth2 Client in `SecurityConfig`: authorization code grant with PKCE (S256). Verify `web.ignoring()` for static resources still works with oauth2ResourceServer (portfolio Lesson 58)
- [x] 2.2 Create custom authorization request resolver that maps `/oauth2/authorization/{slug}-{providerName}` to the dynamic registration ID (matches existing PublicOAuth2ProviderController loginUrl format)
- [x] 2.3 Create custom redirect URI template: `/oauth2/callback/{slug}-{providerName}`
- [x] 2.4 Create `OAuth2LoginSuccessHandler`: extract OAuth2 user info (sub, email, name), resolve or auto-provision FABT user, issue FABT JWT, redirect to frontend with token

## 3. Closed Registration (Link-or-Reject)

- [x] 3.1 Update `OAuth2AccountLinkService.linkOrReject()` — already implements link-or-reject with correct error message: on first OAuth2 login, check for existing user by email → link if found, reject with clear error message if not ("No account found for this email. Contact your CoC administrator to be added.")
- [x] 3.2 Handle edge case: email not provided by IdP (some Microsoft configs) — require email scope, fail gracefully with error message
- [x] 3.3 Create user_oauth2_link on successful linking — existing OAuth2AccountLinkService handles this (existing behavior — verify it works end-to-end)
- [x] 3.4 Frontend: display rejection error message clearly on login page (not a generic 401)

## 4. Frontend

- [x] 4.1 Update `LoginPage.tsx`: fetch public providers via existing API, render branded SSO buttons (Google blue, Microsoft dark) below the email/password form
- [x] 4.2 SSO button click: redirect to `/oauth2/authorize/{tenantSlug}/{providerName}`
- [x] 4.3 Handle callback: parse JWT from redirect URL params, store in localStorage, redirect to role-appropriate page
- [x] 4.4 Add i18n keys for SSO buttons (en.json + es.json): "Sign in with Google", "Sign in with Microsoft", "or sign in with email"

## 5. Keycloak Dev Profile

- [x] 5.1 Add Keycloak 24 service to `docker-compose.yml` under `profiles: [oauth2]` — port 8180:8080, `start-dev --import-realm`, realm-aware healthcheck (portfolio Lesson 54: use OIDC discovery endpoint, NOT TCP check), `start_period: 30s`
- [x] 5.2 Set `KC_HOSTNAME_URL: http://keycloak:8080` in docker-compose environment (portfolio Lesson 61: fixes token `iss` claim across networks)
- [x] 5.3 Create realm import JSON (`infra/keycloak/fabt-dev-realm.json`): realm `fabt-dev`, `accessTokenLifespan: 300`, `ssoSessionMaxLifespan: 1800`
- [x] 5.4 Add public PKCE client to realm: `clientId: fabt-ui`, `publicClient: true`, `standardFlowEnabled: true`, `directAccessGrantsEnabled: false`, `pkce.code.challenge.method: S256`, redirect URIs for localhost:5173
- [x] 5.5 Add confidential service client to realm: `clientId: fabt-service`, `serviceAccountsEnabled: true`, `secret: TO_BE_ROTATED` — for backend tests and Karate
- [x] 5.6 Add test users to realm matching seed data (admin, cocadmin, outreach) with appropriate roles
- [x] 5.7 Update seed `tenant_oauth2_provider` record: set issuer_uri to Keycloak localhost URL, enable the provider

## 5b. JWKS Circuit Breaker + Warmup

- [x] 5b.1 Add Resilience4J circuit breaker `fabt-jwks-endpoint` in `application.yml`: `automatic-transition-from-open-to-half-open-enabled: true`, `ignore-exceptions: [JwtException]` (portfolio Lesson 37 — don't count validation errors as infra failures)
- [x] 5b.2 Create `JwtDecoderConfig` with circuit-breaker-wrapped `NimbusJwtDecoder`: infrastructure failures trip breaker, JWT validation errors pass through (pattern from telecom-event-simulator `KeycloakSecurityConfig.java`)
- [x] 5b.3 Add `@EventListener(ApplicationReadyEvent.class)` JWKS warmup: decode minimal JWS via actual decoder, retry 30 attempts × 2s, distinguish fetch errors from validation errors (portfolio Lesson 52 — RestTemplate warmup does NOT work)
- [x] 5b.4 Add Retry config `jwks-warmup` in `application.yml`: 30 attempts, 2s wait

## 6. Testing

- [x] 6.1 Integration test: DynamicClientRegistrationRepository resolves provider from database, caches for 5 min
- [x] 6.2 Integration test: OAuth2AccountLinkService rejects login when no user exists — returns clear error message, no account created
- [x] 6.3 Integration test: OAuth2AccountLinkService links existing user by email on first OAuth2 login (preserves roles, creates user_oauth2_link)
- [x] 6.4 Integration test: disabled provider returns error (not redirect)
- [x] 6.5 Integration test: JWKS warmup succeeds and circuit breaker stays CLOSED after startup
- [x] 6.6 Integration test: verify `web.ignoring()` still works for static resources with oauth2ResourceServer active
- [x] 6.7 Karate E2E: public provider endpoint returns enabled providers for tenant
- [x] 6.8 Karate E2E: add `get-keycloak-token.feature` helper (@ignore) — client_credentials grant to fabt-service client. Use `karate.call()` not `callSingle()` (portfolio Lesson 42/51: tokens expire in 5 min)
- [x] 6.9 Playwright E2E: login page shows SSO buttons when providers are configured
- [x] 6.10 Playwright E2E: login page shows only email/password when no providers configured

## 7. dev-start.sh --oauth2 Flag

- [x] 7.1 Add `--oauth2` flag parsing to `dev-start.sh`: detect flag in any argument position, set `OAUTH2=true` (combinable with `--observability`)
- [x] 7.2 When `--oauth2` is set, start docker compose with `--profile oauth2` in addition to default services
- [x] 7.3 Wait for Keycloak realm-aware healthcheck before reporting ready (portfolio Lesson 54 — NOT TCP port check)
- [x] 7.4 Add Keycloak (`:8180`) URL to "Stack is running!" output when `--oauth2` is active
- [x] 7.5 Update `stop` command to tear down Keycloak container

## 8. Documentation

- [x] 8.1 Update code repo README: OAuth2 setup guide (Google Cloud Console, Microsoft Entra admin center), `--oauth2` flag usage
- [x] 8.2 Update code repo README: add "Completed: OAuth2 Redirect Flow" to Project Status section
- [x] 8.3 Update code repo README: REST API Reference — document OAuth2 authorize and callback endpoints
- [x] 8.4 Update code repo README: project structure — new files (DynamicClientRegistrationRepository, OAuth2LoginSuccessHandler, etc.)
- [x] 8.5 Update `docs/runbook.md`: add OAuth2 troubleshooting section (JWKS circuit breaker race condition, Keycloak healthcheck, token expiry, "all endpoints return 401" diagnosis)
- [x] 8.6 Update `docs/architecture.drawio`: add Keycloak as external IdP with dashed arrow from backend, add to legend
- [x] 8.7 Confirm `docs/schema.dbml` — no changes needed (V10 tables already documented)
- [x] 8.8 Confirm `docs/asyncapi.yaml` — no new domain events (user provisioning is synchronous, not event-driven)
- [x] 8.9 Update docs repo README: move oauth2-redirect-flow from Active to Archived after implementation

## 9. Demo Screenshots

- [x] 9.1 Regenerate demo screenshots: login page now shows SSO buttons (01-login.png will change)
- [x] 9.2 Capture new screenshot: OAuth2 callback success (user auto-provisioned)
- [x] 9.3 Update `demo/index.html` captions for login screenshot to mention SSO buttons
- [x] 9.4 Run `./demo/capture.sh` to regenerate all screenshots

## 10. Admin UI — OAuth2 Provider Management Tab

- [x] 10.1 Add `'oauth2Providers'` to `TabKey` type and `TABS` array in `AdminPanel.tsx` (after Observability tab). Restrict visibility to PLATFORM_ADMIN role check
- [x] 10.2 Add i18n message keys for OAuth2 Providers tab (EN + ES): tab label, form labels, buttons, success/error messages, delete confirmation
- [x] 10.3 Create `OAuth2ProvidersTab` component: on mount, `GET /api/v1/tenants/{id}/oauth2-providers` to load provider list (name, enabled, issuerUri, createdAt — no secret)
- [x] 10.4 Render provider list table: provider name, status toggle (enabled/disabled), issuer URI, created date, edit/delete buttons
- [x] 10.5 Create "Add Provider" form: provider type dropdown (Google, Microsoft, Keycloak, Custom) with auto-fill issuer URI per type
- [x] 10.6 Add client ID text input and client secret password input (masked). Show-once pattern: after save, secret is never displayed again
- [x] 10.7 Add "Test Connection" button: `GET {issuerUri}/.well-known/openid-configuration` via a backend proxy endpoint to validate reachability. Show success/failure before saving
- [x] 10.8 Add Save button: `POST /api/v1/tenants/{id}/oauth2-providers` with provider config. Show success message on create
- [x] 10.9 Add Edit mode: update client ID, issuer URI, enable/disable via `PUT /api/v1/tenants/{id}/oauth2-providers/{providerId}`. Client secret field is blank (keep existing) unless re-entered
- [x] 10.10 Add Delete with confirmation dialog: "This will prevent all users from logging in via {providerName}. Existing linked accounts will remain but SSO login will stop working."
- [x] 10.11 Create backend endpoint for OIDC discovery test: `GET /api/v1/oauth2/test-connection?issuerUri={uri}` — fetches `.well-known/openid-configuration` and returns success/failure. PLATFORM_ADMIN only
- [x] 10.12 Disable keycloak seed record by default (`enabled: false`). Only enable when `--oauth2` flag is used (update dev-start.sh to run SQL toggle after seed data load)
- [x] 10.13 Playwright test: admin navigates to OAuth2 Providers tab, sees provider list
- [x] 10.14 Playwright test: admin adds a provider with test connection validation
- [x] 10.15 Regenerate demo screenshots to capture OAuth2 Providers tab
