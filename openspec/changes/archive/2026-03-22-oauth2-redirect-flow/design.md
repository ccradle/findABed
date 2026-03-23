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
1. On `findByRegistrationId(registrationId)`, parses `registrationId` as `{slug}-{providerName}` (hyphen separator — matches existing `PublicOAuth2ProviderController` URL format)
2. Loads the `TenantOAuth2Provider` from the database
3. Decrypts `client_secret_encrypted`
4. Builds a `ClientRegistration` with the provider's `issuer_uri`, `client_id`, `client_secret`
5. Uses OIDC discovery (`.well-known/openid-configuration`) to resolve authorization/token/userinfo endpoints

Cache registrations for 5 minutes (providers don't change often).

**Static resources** (portfolio Lesson 58): FABT already uses `WebSecurityCustomizer` with `web.ignoring()` for static resources (`/`, `/index.html`, `/assets/**`). This must be preserved when adding `oauth2ResourceServer` — `permitAll()` does NOT work for static resources when `BearerTokenAuthenticationFilter` is in the chain.

### D2: Authorization flow with tenant context

The OAuth2 flow must carry tenant context through the redirect:

1. User clicks "Login with Google" on the login page for tenant `dev-coc`
2. Frontend redirects to `/oauth2/authorize/dev-coc/google`
3. Backend resolves tenant + provider, builds authorization URL
4. User authenticates at Google
5. Google redirects back to `/oauth2/callback/{slug}-{providerName}`
6. Backend exchanges code for tokens, extracts `sub` + `email`
7. Backend looks up or auto-provisions user, issues FABT JWT
8. Frontend receives JWT and redirects to role-appropriate page

### D3: Closed registration — link-or-reject (no auto-provisioning)

**No auto-provisioning.** When a user authenticates via OAuth2 for the first time (no existing `user_oauth2_link`):
1. Check if a user with that email exists in the tenant → link if found, issue JWT
2. If no user exists, **reject with a clear error message**: "No account found for this email. Contact your CoC administrator to be added."
3. Do NOT create user accounts automatically — this is a closed registration model

**Why not auto-provision:** With auto-provisioning, anyone with a Google account could sign into any tenant and get an OUTREACH_WORKER account. This exposes shelter availability data, allows creating reservations (holding beds from people who need them), and bypasses the CoC admin's control over who accesses the system. The real-world onboarding flow (shelter-onboarding-workflow.docx) requires the CoC admin to register users during the 7-day onboarding process.

**User journey:** CoC admin creates user account (email, role, dvAccess) via Admin Panel → user clicks "Login with Google" → system matches by email → creates `user_oauth2_link` → issues JWT. Subsequent logins resolve via the link directly.

The existing `OAuth2AccountLinkService.linkOrReject()` already implements this pattern.

### D4: Frontend SSO buttons

The login page already calls `GET /api/v1/tenants/{slug}/oauth2-providers/public` to get enabled providers. Add buttons for each:
- Google: branded "Sign in with Google" button
- Microsoft: branded "Sign in with Microsoft" button
- Click → redirect to `/oauth2/authorization/{slug}-{providerName}`

**Note:** FABT does NOT use `keycloak-js` library (unlike telecom-event-simulator). FABT supports multiple IdPs (Google, Microsoft, Keycloak) dynamically per tenant — the redirect flow is provider-agnostic. The existing `api.ts` 401 recovery + token refresh pattern (from operational-monitoring auth fixture fix) handles token expiry.

**No hardcoded URLs** (portfolio Lesson 35): OAuth2 redirect URLs are resolved from the database, not from `.env` or `application.yml`.

### D5: Keycloak for local dev/test

Add Keycloak to docker-compose (profile: `oauth2`) with:
- Pre-imported realm (`fabt-dev`) with test users
- Client registration matching the seed `tenant_oauth2_provider` record
- Accessible at `http://localhost:8180`

**Keycloak healthcheck** (portfolio Lesson 54): Keycloak 24 UBI9-micro has no `curl` or `wget`. Use raw bash `/dev/tcp` with HTTP GET to OIDC discovery endpoint — not a TCP port check, which passes before realm import completes:
```yaml
healthcheck:
  test: ["CMD-SHELL", "exec 3<>/dev/tcp/localhost/8080 && printf 'GET /realms/fabt-dev/.well-known/openid-configuration HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3 && timeout 2 cat <&3 | grep -q '200'"]
```

**JWKS warmup** (portfolio Lesson 37/52): On cold Docker Compose start, Keycloak's TCP port opens before realm import finishes. If the backend fetches JWKS before the realm exists, the Resilience4J circuit breaker opens permanently and all authenticated endpoints return 401. Warm the JWKS through the actual `NimbusJwtDecoder` (not a standalone RestTemplate) — the decode fails (bad signature), but the JWK set gets cached. Implementation pattern from telecom-event-simulator `KeycloakSecurityConfig.java`:
- `@EventListener(ApplicationReadyEvent.class)` warmup with minimal JWS compact serialization
- Retry 30 attempts × 2s wait (60s total)
- Distinguish fetch errors (retry) from JWT validation errors (success — cache is warm)

**JWKS circuit breaker config:**
```yaml
resilience4j:
  circuitbreaker:
    instances:
      fabt-jwks-endpoint:
        automatic-transition-from-open-to-half-open-enabled: true  # KEY — allows recovery
        ignore-exceptions:
          - org.springframework.security.oauth2.jwt.JwtException  # Don't count validation errors
```

**KC_HOSTNAME_URL** (portfolio Lesson 61): Set `KC_HOSTNAME_URL: http://keycloak:8080` in docker-compose. Without this, Keycloak issues tokens with dynamic issuer (matches request hostname). Tests from localhost get `iss:localhost:8180` while the backend expects `iss:keycloak:8080` — token validation fails silently.

### D5b: Keycloak realm configuration

Realm import JSON (`infra/keycloak/fabt-dev-realm.json`) based on the telecom-event-simulator pattern:

**Public PKCE client (React frontend):**
- `clientId: "fabt-ui"`, `publicClient: true`, `standardFlowEnabled: true`
- `directAccessGrantsEnabled: false` (security best practice — no password grant from browser)
- `pkce.code.challenge.method: S256`
- `redirectUris: ["http://localhost:5173/*"]`
- `webOrigins: ["http://localhost:5173"]`
- Default scopes: `openid`, `profile`, `email`

**Confidential service client (backend-to-backend, testing):**
- `clientId: "fabt-service"`, `publicClient: false`, `serviceAccountsEnabled: true`
- `secret: "TO_BE_ROTATED"` — rotate before any production use

**Token lifespans:**
- `accessTokenLifespan: 300` (5 minutes — matches Keycloak default)
- `ssoSessionMaxLifespan: 1800` (30 minutes)

### D6: PKCE (Proof Key for Code Exchange)

All OAuth2 flows use PKCE (S256) — this is mandatory for public clients and best practice for confidential clients. Spring Security OAuth2 Client supports PKCE out of the box.

### D7: dev-start.sh --oauth2 flag

Extend `dev-start.sh` with `--oauth2` flag (combinable with `--observability`):

```bash
./dev-start.sh --oauth2                # Standard stack + Keycloak
./dev-start.sh --oauth2 --observability # Standard + Keycloak + monitoring
```

When `--oauth2` is passed:
- Start docker compose with `--profile oauth2` in addition to default services
- Wait for Keycloak realm-aware healthcheck before reporting ready
- Add Keycloak URL (`:8180`) to "Stack is running!" output
- Stop command tears down Keycloak container

### D8: Token refresh and 401 recovery

**Keycloak access tokens expire in 5 minutes by default** (portfolio Lesson 33). The frontend must handle token refresh:
- Call refresh token endpoint before API calls if token is near expiry
- On 401, attempt refresh + retry once, then redirect to login (already implemented in `api.ts`)
- The Playwright auth fixture already checks JWT expiry (fixed during operational-monitoring)

**Karate tests** (portfolio Lesson 42): Use `karate.call()` (not `callSingle()`) for token acquisition so each feature gets a fresh token. With sequential test execution, suites can exceed 5 minutes and a cached token expires mid-run.

### D9: Admin UI — OAuth2 Provider Management Tab

Add an "OAuth2 Providers" tab to the AdminPanel for managing identity provider configurations. Follows the existing tab pattern and the API key "show-once" security model.

**Access control:** PLATFORM_ADMIN only (not COC_ADMIN — IdP configuration is a platform-level security concern).

**Provider list view:**
- Table: provider name, status (enabled/disabled toggle), issuer URI, created date
- Client secret is **never displayed** after creation (RFC 9700: write-once sensitive credentials)
- Edit and delete buttons per row

**Add provider form:**
- **Provider type dropdown**: Google, Microsoft, Keycloak, Custom
  - Google: auto-fills issuer URI (`https://accounts.google.com`)
  - Microsoft: prompts for tenant ID, auto-fills issuer URI (`https://login.microsoftonline.com/{tenantId}/v2.0`)
  - Keycloak: prompts for realm URL, auto-fills issuer URI
  - Custom: all fields manual
- **Client ID**: text input
- **Client Secret**: password input (masked, shown once on creation like API keys)
- **Issuer URI**: text input (auto-filled by provider type, editable)
- **Test Connection** button: calls OIDC discovery endpoint (`.well-known/openid-configuration`) to validate issuer URI before saving
- **Save** button

**Edit provider:**
- Can update: client ID, issuer URI, enabled/disabled
- Changing client secret requires re-entering it (new password field, blank = keep existing)
- Cannot change provider name (unique per tenant)

**Delete provider:**
- Confirmation dialog: "This will prevent all users from logging in via {providerName}. Existing linked accounts will remain but SSO login will stop working."

**Security model:**
- Client secrets are transmitted over HTTPS only
- Secrets are stored encrypted (TODO: Vault/KMS — currently plaintext with migration path)
- No secret is ever returned by the GET endpoint (existing `OAuth2ProviderResponse` already excludes it)
- Follows the same pattern as API key management — the existing `OAuth2ProviderController` already handles CRUD
