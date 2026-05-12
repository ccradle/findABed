## contact-info-api

Backend API surface that exposes the project's platform-wide contact email and per-tenant overrides, with auth-aware response shape, edge-cacheability split by auth state, and rate limiting. Backs the static-site footer + audience CTA JS-injection pattern so the literal address never appears in git-tracked content.

### Requirements

### Requirement: Platform contact email sourced from environment variable

The backend SHALL read the platform-wide contact email from a single Spring property `fabt.platform.contact-email`, populated from the environment variable `FABT_PLATFORM_CONTACT_EMAIL`. The committed `application.yml` MUST default the property to an empty string. The literal address MUST NOT appear in any git-tracked file (same posture as `feedback_no_ip_in_repo`). On prod, the value is set in `~/fabt-secrets/.env.prod`; on dev, the operator sets it in their local environment.

#### Scenario: Empty config resolves to empty platform email

- **GIVEN** `FABT_PLATFORM_CONTACT_EMAIL` is unset (or set to empty string)
- **WHEN** any caller hits `GET /api/v1/public/contact-info`
- **THEN** the response body has `platform.email` equal to empty string
- **AND** no exception is raised at backend startup

#### Scenario: Configured value flows through to public response

- **GIVEN** `FABT_PLATFORM_CONTACT_EMAIL=info@example.org` is set in the active environment
- **WHEN** an unauthenticated caller hits `GET /api/v1/public/contact-info`
- **THEN** the response body has `platform.email` equal to `info@example.org`

#### Scenario: Backend startup logs config presence without echoing the literal

- **GIVEN** the platform contact email is configured at startup
- **WHEN** the backend starts and resolves the property
- **THEN** an INFO log line confirms presence of the config (e.g., "platform contact email configured: present")
- **AND** the log line does NOT echo the literal address

### Requirement: Per-tenant contact email stored in tenant.config JSONB, written via dedicated PATCH endpoint

Per-tenant contact email overrides SHALL live under the existing `tenant.config` JSONB column at the key path `contact.email`. No new column or table is introduced. Empty string or absent key resolves to "inherit platform email"; a non-empty string is the per-tenant override.

The write path SHALL be a **dedicated** endpoint `PATCH /api/v1/admin/tenants/{tenantId}/contact-email`, mirroring the existing `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration` pattern (see `ReservationSettings.tsx` + the corresponding backend controller). The generic `PUT /api/v1/tenants/{tenantId}/config` endpoint MAY also accept the key for forward-compatibility, but the documented and UI-driven write path is the dedicated PATCH.

The dedicated endpoint SHALL bind a typed Java record `ContactEmailRequest(@Email @Size(max = 254) String email)` and rely on Spring's `@Valid` cascade for validation. Reusing `jakarta.validation.constraints.@Email` keeps consistency with `User.email`, `LoginRequest.email`, etc.; `@Size(max = 254)` enforces RFC 5321's address length limit and defends against multi-KB strings entering the JSONB blob.

#### Scenario: Empty per-tenant value inherits platform

- **GIVEN** `tenant.config.contact.email` is empty (or the key is absent) for a given tenant
- **AND** `FABT_PLATFORM_CONTACT_EMAIL=info@example.org` is set
- **WHEN** an authenticated caller in that tenant context hits `GET /api/v1/public/contact-info`
- **THEN** the response has `platform.email = "info@example.org"` and `tenant.email = null`
- **AND** the frontend's resolution rule (`tenant.email ?? platform.email`) yields the platform address

#### Scenario: Non-empty per-tenant value overrides platform

- **GIVEN** `tenant.config.contact.email` is `"coc-admin@some-tenant.org"` for a given tenant
- **WHEN** an authenticated caller in that tenant context hits `GET /api/v1/public/contact-info`
- **THEN** the response has `tenant.email = "coc-admin@some-tenant.org"`
- **AND** the frontend's resolution rule yields the tenant-specific address

#### Scenario: Dedicated PATCH endpoint validates email format via typed record

- **GIVEN** an authenticated COC_ADMIN issues `PATCH /api/v1/admin/tenants/{tenantId}/contact-email` with body `{"email": "not-an-email"}`
- **WHEN** Spring binds the request body to `ContactEmailRequest`
- **THEN** the `@Email` constraint on the typed record field fails the `@Valid` cascade
- **AND** the response is 400 Bad Request with a Bean Validation error detail
- **AND** the existing `tenant.config.contact.email` value (if any) is unchanged

#### Scenario: Dedicated PATCH endpoint enforces RFC 5321 length

- **GIVEN** an authenticated COC_ADMIN issues PATCH with body `{"email": "<256-character valid-format string>@x.org"}`
- **WHEN** Spring binds the request body
- **THEN** the `@Size(max = 254)` constraint fails
- **AND** the response is 400 Bad Request

#### Scenario: Empty string clears the per-tenant override

- **GIVEN** `tenant.config.contact.email` is currently `"coc-admin@some-tenant.org"`
- **WHEN** an authenticated COC_ADMIN issues PATCH with body `{"email": ""}`
- **THEN** the response is 200
- **AND** `tenant.config.contact.email` is removed (or empty string), so subsequent reads inherit the platform value

#### Scenario: Cross-tenant write is forbidden

- **GIVEN** an authenticated COC_ADMIN scoped to tenant `dev-coc-east`
- **WHEN** that admin issues PATCH against the path `tenants/{dev-coc-west-uuid}/contact-email`
- **THEN** the response is 403 Forbidden
- **AND** tenant `dev-coc-west`'s config is unchanged

#### Scenario: Write emits TENANT_CONFIG_UPDATED audit event

- **GIVEN** an authenticated COC_ADMIN successfully PATCHes a new contact email
- **WHEN** the PATCH returns 200
- **THEN** a `TENANT_CONFIG_UPDATED` audit row is persisted (consistent with the existing slice-2D audit infrastructure)
- **AND** the audit payload records old value (or null) and new value for the `contact.email` key

### Requirement: DV-policy tenants forbidden from setting per-tenant contact email

For tenants where `tenant.dv_policy_enabled = true`, the per-tenant contact email field MUST inherit from the platform. The dedicated PATCH endpoint MUST reject any non-empty write attempt with a 400 response and a structured error code that the frontend can localize to "DV-policy tenants inherit platform contact." The decision is policy-driven: DV shelter operators hold their direct contact lines closely to avoid traffickers/abusers, and centralized-platform inheritance is the lower-blast-radius default for that population.

Empty-string PATCH (clearing) MUST still succeed on a DV-policy tenant — operators must always be able to revert to platform inheritance.

#### Scenario: Non-empty PATCH on DV-policy tenant rejected

- **GIVEN** tenant `dv-coc-anywhere` has `dv_policy_enabled = true`
- **WHEN** an authenticated COC_ADMIN of that tenant issues PATCH with body `{"email": "shelter-staffer@dv-coc.org"}`
- **THEN** the response is 400 Bad Request with error code `tenant.contactEmail.dvPolicyForbidden`
- **AND** `tenant.config.contact.email` is unchanged

#### Scenario: Empty PATCH on DV-policy tenant accepted (clearing always allowed)

- **GIVEN** tenant `dv-coc-anywhere` has `dv_policy_enabled = true` AND `tenant.config.contact.email = "legacy-value@x.org"` (e.g., from a pre-policy state)
- **WHEN** an authenticated COC_ADMIN issues PATCH with body `{"email": ""}`
- **THEN** the response is 200
- **AND** the `contact.email` key is cleared

### Requirement: Public contact-info endpoint with auth-aware response

The backend SHALL expose `GET /api/v1/public/contact-info` as a public, unauthenticated endpoint under the same security posture as other `/api/v1/public/*` routes (SecurityConfig URL rule; no `@PreAuthorize` annotation on the controller method). The response shape varies by authentication state:

- **Unauthenticated:** `{ "platform": { "email": "<value>" }, "tenant": null }`
- **Authenticated (any tenant role):** `{ "platform": { "email": "<value>" }, "tenant": { "slug": "<tenant-slug>", "email": "<value-or-null>" } }`

When authenticated, the `tenant` block MUST always be returned (with `email: null` when no per-tenant override is set), so the frontend can resolve in a single fetch.

#### Scenario: Unauthenticated caller sees only platform block

- **WHEN** a caller without a JWT hits `GET /api/v1/public/contact-info`
- **THEN** the response status is 200
- **AND** the response body has `platform.email` set
- **AND** the response body has `tenant: null`

#### Scenario: Authenticated caller sees platform + tenant blocks

- **GIVEN** an authenticated user with a tenant-scoped JWT
- **WHEN** the user hits `GET /api/v1/public/contact-info`
- **THEN** the response status is 200
- **AND** the response body has both `platform.email` set and `tenant` populated with `slug` and `email` (the latter possibly null)

#### Scenario: Tenant block reveals only the caller's own tenant

- **GIVEN** an authenticated user in tenant `dev-coc-east`
- **WHEN** the user hits `GET /api/v1/public/contact-info`
- **THEN** `tenant.slug` equals `dev-coc-east`
- **AND** the response body contains no information about any other tenant
- **AND** an integration test asserts that the returned `tenant.slug` is exactly the caller's tenant claim from the JWT
- **AND** a paired test with a `dev-coc-west` JWT confirms `tenant.slug = dev-coc-west` and no `dev-coc-east` data leaks

### Requirement: Cache headers split by authentication state

The contact-info endpoint SHALL set cache headers consistent with the privacy of the response body:

- **Unauthenticated 200:** `Cache-Control: public, max-age=3600`. The body is identical for all unauthed callers and is safe to cache at any shared cache layer (Cloudflare, browser, intermediary proxies).
- **Authenticated 200:** `Cache-Control: private, max-age=3600` AND `Vary: Authorization`. The body varies by tenant (`tenant.slug` + `tenant.email`); shared caches MUST NOT serve a cached body to a different requester. `private` keeps the response out of shared caches; `Vary: Authorization` is belt-and-suspenders for any downstream that respects it.

The endpoint SHALL emit a strong ETag derived from a cheap hash (e.g., SHA-256 truncated to 16 hex chars) of the canonical JSON response body — never via an additional database read per request. The endpoint MUST honor `If-None-Match` with a 304 Not Modified response when the ETag matches.

#### Scenario: Unauthenticated successful response is publicly cacheable

- **WHEN** an unauthenticated caller hits `GET /api/v1/public/contact-info` and receives a 200
- **THEN** the response has `Cache-Control: public, max-age=3600`
- **AND** the response has a non-empty `ETag` header
- **AND** the response does NOT carry a `Vary: Authorization` header (unnecessary for public-cached responses)

#### Scenario: Authenticated successful response is private + auth-varying

- **WHEN** an authenticated caller hits `GET /api/v1/public/contact-info` with a valid JWT and receives a 200
- **THEN** the response has `Cache-Control: private, max-age=3600`
- **AND** the response has `Vary: Authorization`
- **AND** the response has a non-empty `ETag` header

#### Scenario: ETag for unauthed and authed responses differ

- **GIVEN** the platform email is configured and a tenant has `contact.email` set
- **WHEN** an unauthed caller and an authed caller (in that tenant) both fetch the endpoint
- **THEN** the two responses return distinct ETag values (because the response bodies differ)

#### Scenario: Conditional GET with matching ETag returns 304

- **GIVEN** a prior GET returned ETag `"abc123"`
- **WHEN** the caller re-issues the GET with `If-None-Match: "abc123"` and the underlying config is unchanged
- **THEN** the response status is 304
- **AND** no body is returned

### Requirement: Per-IP rate limit on the public contact-info endpoint

The public contact-info endpoint SHALL be rate-limited per-IP via the existing Bucket4j integration. The default budget MUST be at least as restrictive as the budget applied to comparable `/api/v1/public/*` endpoints; the recommended starting point is **60 req/min/IP**, tunable via the property family `fabt.bucket4j.public.contact-info.*`. The 1-hour Cloudflare edge cache for unauthed responses absorbs the overwhelming majority of legitimate traffic; the rate limit covers the uncached-first-hit-per-cache-key path and any authed traffic.

#### Scenario: Bucket exhaustion returns 429

- **GIVEN** a single IP has exceeded its per-minute budget
- **WHEN** the next request from that IP arrives
- **THEN** the response status is 429 Too Many Requests
- **AND** a `Retry-After` header is set consistent with the existing Bucket4j response shape
