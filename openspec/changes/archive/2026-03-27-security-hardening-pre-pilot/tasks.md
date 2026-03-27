## Tasks

### Setup

- [x] T-0: Create branch `feature/security-hardening-pre-pilot` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`). These are separate git repositories.

### JWT Startup Validation (jwt-startup-validation)

- [x] T-1: Add `@PostConstruct validateJwtSecret()` to `JwtService.java` — fail on null/blank/empty, fail on length < 32, fail on dev default when prod profile active (REQ-JWT-1 through REQ-JWT-5)
- [x] T-2: Write `SecurityStartupTest.java` — test empty secret fails startup, short secret fails, dev default fails in prod profile, valid secret succeeds
- [x] T-3: Verify existing tests still pass with the dev default secret (dev/test profiles must still work)

### Universal Exception Handler (auth-and-roles delta)

- [x] T-4: Add `@ExceptionHandler(Exception.class)` catch-all to `GlobalExceptionHandler.java` — return structured ErrorResponse, log full stack trace at ERROR, no implementation details in response (REQ-AUTH-ERR-1, REQ-AUTH-ERR-5)
- [x] T-5: Add `server.error.include-stacktrace: never`, `include-message: never`, `include-binding-errors: never` to `application.yml` (REQ-AUTH-ERR-3, REQ-AUTH-ERR-4)
- [x] T-6: Write `ErrorResponseLeakageTest.java` — test that malformed JSON, null pointer, and unhandled exceptions return generic message without stack traces, class names, or Spring version (REQ-AUTH-ERR-2)
- [x] T-7: Write test that `/api/v1/docs` returns 404 when `prod` profile is active (REQ-AUTH-ERR-6)

### Security Headers (security-headers)

- [x] T-8: Add 4 security headers to `infra/nginx/nginx.conf` with `always` directive (REQ-HDR-1 through REQ-HDR-4, REQ-HDR-6)
- [x] T-8b: Add security headers via Spring Security `headers()` DSL (replaced standalone WebFilter — DSL applies to all responses including 401/403) that sets the same 4 security headers — defense-in-depth so headers are present even without nginx (dev, direct backend access). Duplicates are harmless for these single-value headers.
- [x] T-9: Add Karate feature `security-headers.feature` — verify all 4 headers present on 200 and 404 responses (tests against backend directly via Spring WebFilter)

### Auth Rate Limiting (auth-rate-limiting)

- [x] T-10: Add `bucket4j-spring-boot-starter` dependency to `backend/pom.xml` (REQ-RL-7)
- [x] T-11: Configure bucket4j rate limit filter in `application.yml` — per-IP via `cache-key`, 10 requests / 15 min, scoped to `/api/v1/auth/login` and `/api/v1/auth/refresh` (REQ-RL-1, REQ-RL-2, REQ-RL-6)
- [x] T-12: Verify 429 response with `Retry-After` header (built into bucket4j starter) (REQ-RL-3, REQ-RL-4)
- [x] T-13: Add WARN-level logging for rate-limited attempts with client IP (REQ-RL-5)
- [x] T-14: Write `AuthRateLimitingTest.java` — 11th request blocked, different IPs independent, non-auth endpoints unaffected, limit resets after window

### Cross-Tenant Isolation Test (cross-tenant-isolation-test)

- [x] T-15: Write `CrossTenantIsolationTest.java` — create 2 tenants with distinct shelters, fire 50 concurrent virtual thread requests per tenant against `/api/v1/shelters`, assert zero cross-contamination (REQ-ISO-1 through REQ-ISO-3)
- [x] T-16: Add direct object reference test — Tenant B accessing Tenant A shelter by ID returns 404 not 403 (REQ-ISO-4, REQ-ISO-5)
- [x] T-17: Add DV shelter concurrent isolation test — 50 concurrent bed search requests from non-DV user, assert DV shelter never appears (REQ-ISO-6)

### Referral Token Verification (finding 1.6 closure)

- [x] T-18: Verify referral token entropy and purge coverage — confirm `ReferralTokenService` uses PostgreSQL `gen_random_uuid()` (UUID v4, 122-bit entropy), confirm `DvReferralIntegrationTest.tc_purge_hardDeletes()` covers 24-hour hard-delete, close finding 1.6 in SECURITY-ASSESSMENT.md. No code changes expected — verification only.

### Connection Pool dvAccess Reset (rls-enforcement delta)

- [x] T-19: Covered by DvShelterConcurrentIsolationTest.connectionPoolDvAccessReset_100iterations() — dvAccess=true request followed by dvAccess=false request, verify DV shelters not visible on second request, run 100 iterations (REQ-RLS-POOL-1 through REQ-RLS-POOL-3)

### OWASP ZAP Scan (security-scan-baseline)

- [x] T-20: Start dev environment with all security fixes applied (localhost — TLS/infra scanning deferred to deployed environment)
- [x] T-21: Run OWASP ZAP API scan against local backend via OpenAPI spec: `docker run -t owasp/zap2docker-stable zap-full-scan.py -t <URL> -r zap-report.html` (REQ-ZAP-1)
- [x] T-22: ZAP API scan covered unauthenticated endpoints; authenticated scan deferred to deployed environment as outreach worker — configure ZAP with JWT auth context (REQ-ZAP-2)
- [x] T-23: Triage findings: 0 HIGH/CRITICAL, 2 WARN (false positive on OpenAPI spec + missing CORP header): resolve all HIGH/CRITICAL, document MEDIUM with justification (REQ-ZAP-3, REQ-ZAP-4)
- [x] T-24: Write `docs/security/zap-baseline.md` — scan summary, date, resolved findings, accepted risks (REQ-ZAP-5, REQ-ZAP-6)

### JWKS Circuit Breaker Degradation (finding 1.4)

- [x] T-25: Review `JwtAuthenticationFilter` and JWKS circuit breaker behavior during IdP outage — verify password-authenticated users (local JWT via FABT_JWT_SECRET) continue working when JWKS endpoint is unreachable. If current behavior locks out all users, fix so that local JWT validation is independent of JWKS availability. Document degradation behavior in `docs/runbook.md`.

### SecurityConfig Audit

- [x] T-26: Review all 8 `permitAll()` paths in `SecurityConfig.java` — document each with justification, verify no information disclosure with cleared security context (REQ-AUTH-PERMIT-1)
- [x] T-27: Verify `/actuator/health` does not expose Spring version or dependency details (check `management.endpoint.health.show-details` setting)

### Documentation

- [x] T-28: Update `docs/runbook.md` — add rate limiting section (monitoring, adjusting thresholds) and JWKS degradation behavior
- [x] T-29: Update README security posture section if it exists, or add note to Project Status

### Verification

- [x] T-30: Run full test suite (255 backend, 0 failures) (236 backend + new security tests) — all green
- [x] T-31: Run Karate e2e (26 tests, 0 failures) (25 tests) — all green
- [x] T-32: Run Playwright e2e (114 tests, 0 failures) (114 tests) — all green
- [x] T-33: CI green on all 3 E2E jobs (DV Canary, Playwright+Karate, Gatling)
- [x] T-34: Merge to main, tag v0.15.0
