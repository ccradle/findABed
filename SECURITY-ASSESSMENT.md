# FABT Security Assessment — Unanswered Questions, Concerns & Testing Recommendations

**Author:** Marcus Webb (Penetration Tester / Application Security Engineer)
**Date:** March 2026
**Scope:** Static review of public repository — `finding-a-bed-tonight` v0.14.1
**Status:** Pre-penetration test — findings from code review only, not active testing
**Commit to:** `findABed/SECURITY-ASSESSMENT.md`

---

## Context and Methodology

This assessment is based on static review of the public repository:
SecurityConfig.java, JwtAuthenticationFilter.java, application.yml,
application-standard.yml, init-app-user.sql, docker-compose.yml,
nginx.conf, Dockerfile.backend, DV-OPAQUE-REFERRAL.md, the README,
and the weekly activity reports.

**This is not a penetration test.** It is a code review and threat model
assessment. Active testing against a running instance has not been
performed. Every item marked "unverified" requires hands-on testing
to confirm or dismiss.

**Threat model priority:** This platform handles domestic violence shelter
data. The highest-consequence failure is disclosure of a DV shelter's
location or existence to an unauthorized party — including an abuser.
Every finding is evaluated through that lens first.

---

## Section 1 — Unanswered Questions

These are questions I cannot answer from static review alone.
They require either reading additional source files or active testing.

---

### 1.1 JWT Empty-Secret Behavior

**Question:** What happens at startup if `FABT_JWT_SECRET` is not set?

**Context:** `application.yml` shows:
```yaml
resourceserver:
  jwt:
    jwk-set-uri: ${FABT_JWKS_URI:}
```
And `JwtService` (not yet reviewed) uses `${FABT_JWT_SECRET:}` — empty
string as the default. Spring Security's `NimbusJwtDecoder` throws
`IllegalArgumentException` on an empty secret at bean creation time,
which means the application should fail to start. Alex Chen confirmed
this behavior.

**Why it's still open:** "Should fail" based on Nimbus internals is
different from "is guaranteed to fail" based on an explicit application
assertion. If Nimbus behavior changes in a future version, or if a
different JWT decoder is used, the guarantee disappears silently.

**Files needed:** `JwtService.java`, `JwtDecoderConfig.java`

**Risk if wrong:** An application that starts with an empty JWT secret
either accepts all tokens (catastrophic) or rejects all tokens (DoS).
Neither is acceptable.

**Recommended test:**
```bash
# Start backend with no JWT secret — must refuse to start
docker run --rm \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://... \
  -e FABT_JWT_SECRET="" \
  fabt-backend:latest
# Expected: application exits with non-zero code and clear error message
# Failure: application starts successfully
```

---

### 1.2 Multi-Tenant Data Isolation Under Virtual Threads

**Question:** Can a request from Tenant A ever read Tenant B's data
under the Java 25 / virtual threads implementation?

**Context:** `TenantContext` was migrated from `ThreadLocal` to
`ScopedValue` in the Java 25 migration. `ScopedValue` is bound for
the duration of a `ScopedValue.where(...).run(...)` block and does
not leak across virtual thread boundaries the way `ThreadLocal` can
under thread pool reuse. This is architecturally safer.

**Why it's still open:** I have not reviewed `RlsDataSourceConfig.java`
(the class that sets `app.current_tenant_id` on every JDBC connection)
or `TenantContext.java` post-migration. The binding scope of the
ScopedValue relative to the JDBC connection lifecycle is the specific
question. If a connection is obtained before the ScopedValue is bound,
or returned to the pool after the scope closes with tenant state still
set on the connection, cross-tenant leakage is possible.

**Files needed:** `RlsDataSourceConfig.java`, `TenantContext.java`
(post-Java 25 migration), `VirtualThreadConfig.java`

**Risk if wrong:** Tenant A's data visible to Tenant B. In a multi-CoC
deployment, this means one CoC's shelter and user data is readable by
another CoC's users. For a DV shelter in that dataset, the consequence
is location disclosure.

**Recommended test (must be written):**
```java
@Test
void concurrentRequestsFromDifferentTenants_doNotLeakData() {
    // Create two tenants with separate shelters
    // Fire 100 concurrent requests — 50 from Tenant A, 50 from Tenant B
    // Each request reads /api/v1/shelters
    // Assert: no Tenant A shelter ever appears in a Tenant B response
    // Assert: no Tenant B shelter ever appears in a Tenant A response
    // This test must use genuine concurrency — not sequential execution
}
```

This test does not currently exist. It should be a named integration
test in `CrossTenantIsolationTest.java` and should run in CI on every
PR that touches `TenantContext`, `RlsDataSourceConfig`, or any auth filter.

---

### 1.3 Exception Handling — Fails Open or Fails Closed?

**Question:** When `JwtAuthenticationFilter` catches an exception from
`jwtService.validateToken()`, does it fail open (continue the filter
chain unauthenticated) or fail closed (return 401 immediately)?

**Context:** The filter code shows:
```java
} catch (Exception e) {
    SecurityContextHolder.clearContext();
}
filterChain.doFilter(request, response);
```

The `filterChain.doFilter()` call is **outside** the try/catch block.
This means on any exception — expired token, malformed token, wrong
signature, network error fetching JWKS — the filter clears the security
context and continues the chain. The downstream `anyRequest().authenticated()`
rule will then reject unauthenticated requests with 401.

**Why it's still open:** This is fail-open by design at the filter level,
rely-on-downstream for the actual rejection. That's the standard Spring
Security pattern and it's correct — but I want to verify that no endpoint
in `SecurityConfig` has `permitAll()` that could be reached by a request
with a cleared security context and a deliberately malformed JWT.

**Specific concern:** The `/error` endpoint has `permitAll()`:
```java
.requestMatchers("/error").permitAll()
```
If a malformed JWT causes an exception that routes through `/error`,
does that path expose any sensitive information?

**Files needed:** Full `SecurityConfig.java` review of all `permitAll()`
paths, `GlobalExceptionHandler.java`

---

### 1.4 JWKS Circuit Breaker Behavior

**Question:** When the JWKS endpoint circuit breaker is open (Keycloak
or IdP is unreachable), what happens to JWT validation for existing
sessions?

**Context:** `application.yml` configures a `fabt-jwks-endpoint` circuit
breaker with Resilience4J. The JWKS warmup retry is configured with
30 attempts at 2-second intervals. When the circuit is open, `NimbusJwtDecoder`
cannot validate tokens that require JWKS lookup.

**Why it's open:** In a deployment using only local JWT (no OAuth2/OIDC),
JWKS validation may not apply — local JWTs are validated with the symmetric
`FABT_JWT_SECRET`. But in a deployment with OAuth2 providers configured,
an IdP outage means all SSO users are locked out. The question is whether
this degrades gracefully (SSO users locked out, password users continue)
or catastrophically (all users locked out).

**Risk:** During a White Flag surge event, an IdP outage that locks out
all coordinator and outreach worker accounts is operationally catastrophic.

---

### 1.5 API Key Entropy and Storage

**Question:** How are API keys generated, hashed, and stored?

**Context:** The README mentions API keys are SHA-256 hashed. The
`ApiKeyService` is listed in the project structure. I have not reviewed
the actual implementation.

**Specific questions:**
- What is the entropy of a generated API key? (Must be at minimum 128 bits)
- Is the raw key ever logged? (Must never be logged after creation)
- Is the hash salted? (SHA-256 without salt is vulnerable to rainbow table
  attacks on low-entropy keys)
- What is the comparison method? (Must be constant-time to prevent timing attacks)

**Files needed:** `ApiKeyService.java`, `ApiKey.java`

---

### 1.6 DV Referral Token Entropy and Purge Verification

**Question:** What is the entropy of `referral_token` values, and is
the 24-hour hard-delete purge verifiable?

**Context:** The DV-OPAQUE-REFERRAL.md describes zero-PII tokens with
24-hour hard-delete. This is the right design. I want to verify:
- Token values are cryptographically random (not sequential UUIDs)
- The purge scheduler runs reliably and cannot be delayed indefinitely
- Deleted tokens leave no recoverable trace in WAL or backup logs

**Risk:** If tokens are predictable, an attacker could enumerate valid
referral tokens and observe acceptance/rejection patterns to infer DV
shelter capacity. If purge fails silently, tokens accumulate beyond their
stated 24-hour lifetime.

**Files needed:** `ReferralTokenService.java`, `ReferralTokenPurgeService.java`

---

## Section 2 — Confirmed Concerns (Require Action)

These items are confirmed gaps from static review. No active testing
required to validate them — the gap is visible in the code.

---

### 2.1 Missing Security Headers on nginx

**Severity:** Medium (will appear in all automated security scans)
**Status:** Confirmed gap — `nginx.conf` does not set these headers

The following security headers are missing from `nginx.conf`:

| Header | Value | Purpose |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | Prevents MIME type sniffing |
| `X-Frame-Options` | `DENY` | Prevents clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Controls referrer leakage |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` | Disables unused browser APIs |

HSTS (`Strict-Transport-Security`) is added by Certbot's nginx plugin
and does not need to be added manually.

`Content-Security-Policy` requires careful analysis of the React PWA's
asset loading before it can be set correctly — do not add a restrictive
CSP without testing it against the running frontend. A misconfigured CSP
will break the service worker and the offline functionality.

**Recommended fix for `nginx.conf`:**
```nginx
# Add to the server block, before location blocks
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

**Why this matters for city adoption:** Any automated security scan
(OWASP ZAP, Qualys, Nessus) will flag missing security headers as
findings. A city IT officer reviewing the scan results will see them.
Better to fix them before that conversation than to explain them during it.

---

### 2.2 No Rate Limiting on Authentication Endpoints

**Severity:** Medium (not blocking for demo — blocking for pilot with real accounts)
**Status:** Confirmed gap — no rate limiting visible in SecurityConfig.java

`/api/v1/auth/login` and `/api/v1/auth/refresh` accept unlimited requests
from any IP. An attacker can attempt unlimited password combinations against
any known email address.

**Risk context:** The platform uses a closed-registration model — user
accounts must be pre-provisioned by a CoC admin. Known email addresses
are limited to organizational accounts (shelter coordinators, outreach workers).
This reduces the attack surface compared to an open-registration system,
but does not eliminate it.

**Recommended implementation:**
```java
// Option A: Spring's built-in bucket4j integration (preferred)
// pom.xml: add bucket4j-spring-boot-starter
// application.yml:
bucket4j:
  filters:
    - cache-name: login-rate-limit
      url: /api/v1/auth/login
      rate-limits:
        - bandwidths:
            - capacity: 5
              time: 1
              unit: minutes

// Option B: Redis-backed counter (already have Redis in Standard tier)
// Simple: count login attempts per IP per 15min window in Redis
// Block for 15 minutes after 10 failed attempts
```

**Timeline:** Not required for demo. Required before pilot deployment
with real organizational accounts. Add to pre-demo checklist Tier 2.

---

### 2.3 Swagger UI Exposure on Demo Environment

**Severity:** Low (information disclosure, not a vulnerability)
**Status:** Confirmed — intentional per v0.14.1 addendum, but needs
documentation and a path to disable for production deployments

The Swagger UI at `/api/v1/docs` is accessible without authentication.
This exposes:
- Full API surface including DV referral endpoint signatures
- Request/response schemas
- Available query parameters and filters

**This is not a vulnerability** — the API endpoints themselves require
authentication. But it will appear as an "information disclosure" finding
in any automated security scan, and a city IT officer will ask whether
it is intentional.

**Recommended actions:**

For the demo environment: document in the runbook that Swagger is
intentionally accessible (for evaluators to review the API).

For city-facing or production deployments:
```yaml
# application-prod.yml
springdoc:
  api-docs:
    enabled: false
  swagger-ui:
    enabled: false
```

Or add a `prod` Spring profile that disables Swagger, and document
that this profile should be active in any deployment beyond the demo.

---

### 2.4 No Explicit JWT Secret Startup Validation

**Severity:** Low (Alex confirmed Nimbus throws on empty secret —
but the guarantee is implicit, not explicit)
**Status:** Confirmed gap — no `@PostConstruct` or startup check

**Recommended fix:**
```java
// In JwtService.java or a dedicated SecurityStartupValidator.java
@PostConstruct
public void validateJwtSecret() {
    if (jwtSecret == null || jwtSecret.isBlank()) {
        throw new IllegalStateException(
            "FABT_JWT_SECRET must be set. " +
            "Generate with: openssl rand -base64 64");
    }
    if (jwtSecret.length() < 32) {
        throw new IllegalStateException(
            "FABT_JWT_SECRET is too short. " +
            "Minimum 32 characters (256 bits). " +
            "Generate with: openssl rand -base64 64");
    }
}
```

This makes the startup failure explicit, fast, and with a clear error
message that tells the operator exactly how to fix it.

---

## Section 3 — Testing Recommendations

Organized by category. Items marked **[MUST]** are required before
any city IT engagement. Items marked **[SHOULD]** are required before
pilot. Items marked **[CONSIDER]** are best practice additions.

---

### 3.1 Authentication and Authorization Tests

**[MUST] Empty JWT secret startup test**
```bash
# Test: application refuses to start with empty secret
docker run --rm -e FABT_JWT_SECRET="" fabt-backend:latest
# Assert: exit code != 0, error message mentions FABT_JWT_SECRET
```

**[MUST] Expired token rejection**
```java
@Test
void expiredToken_returns401() {
    String expiredToken = generateTokenWithExpiry(Instant.now().minusSeconds(1));
    mockMvc.perform(get("/api/v1/shelters")
        .header("Authorization", "Bearer " + expiredToken))
        .andExpect(status().isUnauthorized());
}
```

**[MUST] Tampered token rejection**
```java
@Test
void tamperedToken_returns401() {
    String validToken = loginAsOutreachWorker();
    String tamperedToken = validToken.substring(0, validToken.length() - 5) + "XXXXX";
    mockMvc.perform(get("/api/v1/shelters")
        .header("Authorization", "Bearer " + tamperedToken))
        .andExpect(status().isUnauthorized());
}
```

**[MUST] Wrong-role access rejection**
```java
@Test
void outreachWorker_cannotAccessTenantManagement() {
    String token = loginAsOutreachWorker();
    mockMvc.perform(get("/api/v1/tenants")
        .header("Authorization", "Bearer " + token))
        .andExpect(status().isForbidden());
}

@Test
void coordinator_cannotActivateSurge() {
    String token = loginAsCoordinator();
    mockMvc.perform(post("/api/v1/surge-events")
        .header("Authorization", "Bearer " + token)
        .contentType(MediaType.APPLICATION_JSON)
        .content("{}"))
        .andExpect(status().isForbidden());
}
```

**[MUST] No stack traces in error responses**
```java
@Test
void malformedRequest_doesNotExposeStackTrace() {
    String response = mockMvc.perform(post("/api/v1/auth/login")
        .contentType(MediaType.APPLICATION_JSON)
        .content("not valid json {{{"))
        .andReturn().getResponse().getContentAsString();

    assertThat(response).doesNotContain("at org.fabt");
    assertThat(response).doesNotContain("at java.");
    assertThat(response).doesNotContain("Exception");
    assertThat(response).doesNotContain("stack");
}
```

---

### 3.2 Multi-Tenant Isolation Tests

**[MUST] Cross-tenant shelter isolation**
```java
@Test
@DisplayName("Tenant A shelters never visible to Tenant B users")
void crossTenantShelterIsolation() throws InterruptedException {
    // Create Tenant A with 3 shelters
    UUID tenantAId = createTenant("tenant-a");
    String shelterAName = "Tenant A Only Shelter";
    createShelter(tenantAId, shelterAName);

    // Create Tenant B with separate shelters
    UUID tenantBId = createTenant("tenant-b");
    String tokenB = loginAsCocAdmin(tenantBId);

    // Tenant B must not see Tenant A's shelters
    String response = mockMvc.perform(get("/api/v1/shelters")
        .header("Authorization", "Bearer " + tokenB))
        .andReturn().getResponse().getContentAsString();

    assertThat(response).doesNotContain(shelterAName);
}
```

**[MUST] Concurrent cross-tenant isolation (virtual threads)**
```java
@Test
@DisplayName("Concurrent requests from different tenants do not cross-contaminate")
void concurrentCrossTenantIsolation() throws Exception {
    int requestsPerTenant = 50;
    ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    List<Future<String>> results = new ArrayList<>();

    // Fire 100 concurrent requests — 50 Tenant A, 50 Tenant B
    for (int i = 0; i < requestsPerTenant; i++) {
        results.add(executor.submit(() -> getSheltersAsTenant(tenantAToken)));
        results.add(executor.submit(() -> getSheltersAsTenant(tenantBToken)));
    }

    executor.shutdown();
    executor.awaitTermination(30, TimeUnit.SECONDS);

    // Verify no cross-contamination in any response
    for (Future<String> result : results) {
        String response = result.get();
        if (response.contains(tenantAIdentifier)) {
            assertThat(response).doesNotContain(tenantBIdentifier);
        }
        if (response.contains(tenantBIdentifier)) {
            assertThat(response).doesNotContain(tenantAIdentifier);
        }
    }
}
```

**[MUST] Direct object reference — tenant isolation on shelter by ID**
```java
@Test
void tenantB_cannotAccessTenantA_shelterById() {
    UUID shelterA = createShelterForTenantA();
    String tokenB = loginAsTenantB();

    mockMvc.perform(get("/api/v1/shelters/" + shelterA)
        .header("Authorization", "Bearer " + tokenB))
        .andExpect(status().isNotFound()); // 404, not 403 — don't confirm existence
}
```

---

### 3.3 DV Shelter Protection Tests

**[MUST] DV shelter invisible to outreach worker — bed search**
```java
@Test
void dvShelter_notInBedSearchResults_forOutreachWorker() {
    String token = loginAsOutreachWorker(); // dvAccess = false
    String response = searchBeds(token, "SINGLE_ADULT");
    assertThat(response).doesNotContain(DV_SHELTER_NAME);
    assertThat(response).doesNotContain(DV_SHELTER_ID.toString());
}
```

**[MUST] DV shelter invisible to outreach worker — shelter list**
```java
@Test
void dvShelter_notInShelterList_forOutreachWorker() {
    String token = loginAsOutreachWorker();
    String response = mockMvc.perform(get("/api/v1/shelters")
        .header("Authorization", "Bearer " + token))
        .andReturn().getResponse().getContentAsString();
    assertThat(response).doesNotContain(DV_SHELTER_ID.toString());
}
```

**[MUST] DV shelter returns 404 (not 403) for outreach worker direct access**
```java
@Test
void dvShelter_returns404_notForbidden_forOutreachWorker() {
    // 403 confirms existence. 404 does not.
    String token = loginAsOutreachWorker();
    mockMvc.perform(get("/api/v1/shelters/" + DV_SHELTER_ID)
        .header("Authorization", "Bearer " + token))
        .andExpect(status().isNotFound());
}
```

**[MUST] DV shelter visible to dvAccess=true users**
```java
@Test
void dvShelter_visibleToAdmin_withDvAccess() {
    String token = loginAsAdminWithDvAccess();
    String response = searchBeds(token, "DV_SURVIVOR");
    assertThat(response).contains(DV_SHELTER_ID.toString());
}
```

**[MUST] DV canary runs in CI and blocks deployment on failure**
```yaml
# .github/workflows/ci.yml — verify this job exists and blocks merge
- name: DV Access Control Canary
  run: |
    mvn test -Dtest=DvAccessRlsTest
  # This job must be in required status checks for main branch protection
```

**[SHOULD] DV small-cell suppression in HMIS output**
```java
@Test
void hmisTransformer_suppressesDvCount_whenBelowThreshold() {
    // Set up one DV shelter with 2 occupied beds (below n=11 threshold)
    // Generate HMIS export
    // Assert: DV aggregate count is suppressed (null or 0), not 2
}

@Test
void hmisTransformer_includesDvCount_whenAboveThreshold() {
    // Set up DV shelters with 15 total occupied beds
    // Generate HMIS export
    // Assert: DV aggregate count is present and correct
}
```

---

### 3.4 API Key Security Tests

**[SHOULD] API key is hashed in storage**
```java
@Test
void apiKey_storedAsHash_notPlaintext() {
    String plainKey = createApiKey();
    ApiKey stored = apiKeyRepository.findBySuffix(
        plainKey.substring(plainKey.length() - 8));
    assertThat(stored.getKeyHash()).doesNotContain(plainKey);
    assertThat(stored.getKeyHash()).hasSize(64); // SHA-256 hex
}
```

**[SHOULD] API key comparison is constant-time**
```java
@Test
void apiKeyValidation_isConstantTime() {
    // This is hard to test directly — verify MessageDigest.isEqual()
    // or a dedicated constant-time comparison is used in ApiKeyService
    // Review ApiKeyService.java for timing-safe comparison
}
```

**[SHOULD] Rotated API key — old key rejected immediately**
```java
@Test
void rotatedApiKey_oldKey_rejectedImmediately() {
    String oldKey = createApiKey();
    rotateApiKey(oldKey);
    mockMvc.perform(get("/api/v1/shelters")
        .header("X-API-Key", oldKey))
        .andExpect(status().isUnauthorized());
}
```

---

### 3.5 DV Referral Token Tests

**[MUST] Referral tokens are not predictable**
```java
@Test
void referralTokens_areCryptographicallyRandom() {
    Set<String> tokens = new HashSet<>();
    for (int i = 0; i < 100; i++) {
        tokens.add(createReferralToken());
    }
    // All 100 tokens must be unique
    assertThat(tokens).hasSize(100);
    // Each token must have sufficient entropy (verify format/length)
    tokens.forEach(t -> assertThat(t.length()).isGreaterThanOrEqualTo(32));
}
```

**[MUST] Purge scheduler runs and removes expired tokens**
```java
@Test
void referralTokenPurge_removesExpiredTokens() {
    // Create a token with past expiry
    String tokenId = createExpiredReferralToken();
    // Trigger purge manually
    referralTokenPurgeService.purgeExpired();
    // Token must not exist in any table
    assertThat(referralTokenRepository.findById(tokenId)).isEmpty();
}
```

**[MUST] Accessing a purged token returns 404**
```java
@Test
void purgedReferralToken_returns404() {
    String token = createAndPurgeReferralToken();
    mockMvc.perform(get("/api/v1/dv-referrals/" + token)
        .header("Authorization", "Bearer " + dvAdminToken))
        .andExpect(status().isNotFound());
}
```

---

### 3.6 Active Testing Recommendations (Penetration Test)

These require a running instance. Run them against the demo environment
before any city IT engagement.

**[MUST] OWASP ZAP active scan**
```bash
# Run OWASP ZAP in active scan mode against the demo URL
# This replicates what a city IT officer's security team will run

docker run -t owasp/zap2docker-stable zap-full-scan.py \
  -t https://YOUR_DOMAIN \
  -r zap-report.html \
  -I   # Don't fail on warnings, only failures

# Review the report before any city IT engagement
# Fix all HIGH and CRITICAL findings
# Document MEDIUM findings with justification
```

**[MUST] Authenticated scan — outreach worker role**
```bash
# ZAP authenticated scan as outreach worker
# This verifies that authenticated endpoints don't have injection vulnerabilities
# Focus on: /api/v1/queries/beds (POST with JSON body)
#           /api/v1/reservations (POST)
#           /api/v1/shelters (GET with query params)
```

**[SHOULD] Authorization bypass attempts**
```bash
# Attempt to access admin endpoints with outreach worker token
# Attempt to access another tenant's resources with valid token
# Attempt IDOR (Insecure Direct Object Reference) on reservation IDs
# Attempt to modify a reservation created by a different user

# Example:
TOKEN=$(login_as outreach@dev.fabt.org)
# Try to access admin endpoint
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  https://YOUR_DOMAIN/api/v1/tenants
# Expected: 403. Any other response is a finding.
```

**[SHOULD] SQL injection via search parameters**
```bash
# Test bed search endpoint with SQL injection payloads
curl -s -X POST https://YOUR_DOMAIN/api/v1/queries/beds \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"populationType": "SINGLE_ADULT'\'' OR 1=1 --", "limit": 5}'
# Expected: 400 (validation error) or empty results
# Failure: returns unexpected data or 500 with stack trace
```

**[SHOULD] Security header verification**
```bash
# Verify security headers are present after nginx fix
curl -sI https://YOUR_DOMAIN | grep -E \
  "Strict-Transport|X-Content-Type|X-Frame|Referrer-Policy|Content-Security"
```

**[CONSIDER] JWT algorithm confusion attack**
```bash
# Attempt to use 'none' algorithm JWT
# Attempt RS256/HS256 algorithm confusion if JWKS is configured
# This is only relevant if OAuth2 providers are configured
```

---

### 3.7 Operational Security Checks

**[MUST] Management port not publicly accessible**
```bash
# From outside the VM — must be refused
curl -s --connect-timeout 5 \
  http://YOUR_IP:9091/actuator/prometheus
# Expected: connection refused or timeout
# Failure: returns Prometheus metrics — stop everything and fix
```

**[MUST] Database port not publicly accessible**
```bash
# From outside the VM — must be refused
nc -zv YOUR_IP 5432
# Expected: connection refused
```

**[MUST] Redis port not publicly accessible**
```bash
nc -zv YOUR_IP 6379
# Expected: connection refused
```

**[MUST] No plaintext secrets in environment**
```bash
# On the VM — verify secrets are set
docker exec fabt-backend env | grep -E "JWT|PASSWORD|SECRET"
# Verify values are present (not empty) but do NOT log or share the output
# The test is that the variables exist and are non-empty, not their values
```

**[SHOULD] Verify Docker containers run as non-root**
```bash
docker exec fabt-backend whoami
# Expected: fabt (non-root user defined in Dockerfile)

docker exec fabt-frontend whoami
# Expected: nginx or similar non-root user
```

---

## Section 4 — Risk Register

Summary of all items with severity, status, and action required.

| # | Finding | Severity | Status | Action | Timeline |
|---|---|---|---|---|---|
| 1.1 | JWT empty-secret startup behavior | High | Unverified | Add `@PostConstruct` assertion + test | Before pilot |
| 1.2 | Multi-tenant isolation under virtual threads | High | Unverified | Write `CrossTenantIsolationTest` | Before pilot |
| 1.3 | Filter chain fail-open behavior | Medium | Partially reviewed | Review all `permitAll()` paths | Before city IT |
| 1.4 | JWKS circuit breaker / SSO outage behavior | Medium | Unverified | Review + document degradation behavior | Before pilot |
| 1.5 | API key entropy and constant-time comparison | Medium | Unverified | Review `ApiKeyService.java` | Before pilot |
| 1.6 | DV referral token entropy and purge reliability | High | Unverified | Review + add purge verification test | Before any DV use |
| 2.1 | Missing security headers | Medium | Confirmed gap | Add 4 headers to `nginx.conf` | Before city IT |
| 2.2 | No rate limiting on auth endpoints | Medium | Confirmed gap | Implement for pilot, not demo | Before pilot |
| 2.3 | Swagger UI unauthenticated exposure | Low | Confirmed, intentional | Document + add prod disable profile | Before city IT |
| 2.4 | No explicit JWT secret startup assertion | Low | Confirmed gap | Add `@PostConstruct` check | Before pilot |
| 3.6 | OWASP ZAP active scan not yet run | High | Not started | Run before city IT engagement | Before city IT |
| 3.7 | Operational port exposure not verified | High | Not verified | Run port checks per Section 3.7 | Before demo |

---

## Section 5 — What's Already Good

For the city IT conversation, these are the strengths to lead with:

- **RLS defense-in-depth:** PostgreSQL Row Level Security AND service-layer
  `dvAccess` check on every request. Two independent layers for DV shelter
  protection. Correct pattern, correctly implemented.

- **Restricted database role:** `fabt_app` runs as NOSUPERUSER, NOCREATEDB,
  NOCREATEROLE — DML only. Even if the application is compromised, the
  attacker cannot escalate database privileges or modify schema.

- **OWASP CVE gate:** `failBuildOnCVSS=7` in CI. Dependencies with CVSS ≥ 7
  fail the build. 16 CVEs resolved in the Spring Boot 3.4.13 upgrade.

- **Zero-PII DV referral design:** No client name, DOB, address, or
  identifying information stored at any point in the referral flow.
  24-hour hard delete — nothing to subpoena after 24 hours.

- **Virtual thread / ScopedValue migration:** Architecturally safer than
  `ThreadLocal` for tenant context under high concurrency. The right
  call for a platform that may scale to metro-area CoC deployments.

- **Append-only bed availability:** `bed_availability` table never has
  UPDATE or DELETE. Complete audit trail of every availability change,
  forever. Relevant for any compliance review.

- **Spring Boot 4.0 / Java 25 current:** Dependency chain is current.
  No EOL runtime components.

---

## Next Steps — Recommended Order

1. **Run the Section 3.7 operational security checks** against the demo
   environment immediately after Jordan deploys it. Takes 10 minutes.
   If any port check fails, fix before anyone else has the URL.

2. **Add security headers to `nginx.conf`** (Section 2.1). Jordan can
   add this to the runbook. Takes 5 minutes. High visibility in scans.

3. **Write `CrossTenantIsolationTest`** (Section 1.2). Riley owns this.
   Should be in CI before the first city conversation.

4. **Review `ApiKeyService.java` and `ReferralTokenService.java`**
   (Sections 1.5 and 1.6). Share those files with me and I can answer
   the open questions in Section 1 without needing a running instance.

5. **Run OWASP ZAP** against the demo URL once it's live (Section 3.6).
   Report comes before the city IT engagement, not after.

6. **Add `@PostConstruct` JWT secret assertion** (Section 2.4).
   Small change, high value for operational safety.

---

*FABT Security Assessment — Static Review*
*Marcus Webb · Application Security Engineer*
*March 2026 · v0.14.1*
*Note: This is a code review assessment, not a penetration test report.
Active testing has not been performed. All "unverified" items require
hands-on testing to confirm or dismiss.*
