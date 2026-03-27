## Overview

Implement findings from the Marcus Webb AI persona security assessment (SECURITY-ASSESSMENT.md) to harden the platform before city IT evaluation and pilot deployment. Five new capabilities and two modified capabilities, focused on authentication safety, multi-tenant isolation verification, infrastructure headers, and active security scanning.

## Design Decisions

### JWT Startup Validation

Add `@PostConstruct` to `JwtService` that asserts:
1. `fabt.jwt.secret` is not null, blank, or the hardcoded dev default (`"default-dev-secret-change-in-production"`)
2. Secret length is >= 32 characters (256 bits minimum for HS256)
3. Application fails to start with `IllegalStateException` and actionable error message

This replaces implicit reliance on Nimbus throwing on empty secret with an explicit, version-independent guarantee.

### Universal Exception Handler

Add `@ExceptionHandler(Exception.class)` to `GlobalExceptionHandler` as a catch-all after the 5 existing specific handlers. Returns the existing `ErrorResponse` format with a generic message ("An unexpected error occurred") and logs the full exception server-side. No stack traces, class names, or Spring Boot version info in the response body.

Verify that `/error` endpoint (Spring's `BasicErrorController`) also suppresses detail:
```yaml
server:
  error:
    include-stacktrace: never
    include-message: never
    include-binding-errors: never
```

### Security Headers (nginx)

Defense-in-depth: add headers in both nginx and Spring so they're present regardless of deployment topology.

**nginx layer** (`infra/nginx/nginx.conf` server block):
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(), microphone=(), camera=()`

**Spring layer** (new `SecurityHeadersFilter` WebFilter):
Same 4 headers, applied at the application level. Ensures headers are present in dev (no nginx), direct backend access, and any deployment where nginx is bypassed or misconfigured. Duplicates are harmless for these single-value headers.

CSP is intentionally deferred — requires analysis of React PWA asset loading, service worker registration, and Recharts inline styles. A misconfigured CSP will break offline functionality (Darius's worst case).

### Auth Rate Limiting

Use `bucket4j-spring-boot-starter` (v0.14.0+, Spring Boot 4.0 compatible) for per-IP rate limiting on `/api/v1/auth/login` and `/api/v1/auth/refresh`:
- 10 attempts per 15-minute window per IP
- Return `429 Too Many Requests` with `Retry-After` header (built into bucket4j starter)
- Log rate-limited attempts at WARN level
- Per-IP keying via `cache-key` Spring Expression Language — no manual registry or eviction needed

bucket4j handles per-key token buckets, HTTP filter integration, and response headers out of the box. Resilience4J stays for circuit breakers (NOAA API, webhooks) — the two libraries serve complementary purposes. Configuration is YAML-driven, not code-driven.

### Cross-Tenant Isolation Test

New `CrossTenantIsolationTest.java` in the test suite:
1. Create two tenants (A and B) with distinct shelters
2. Fire 50 concurrent requests from each tenant using `Executors.newVirtualThreadPerTaskExecutor()`
3. Assert: no Tenant A shelter ID or name appears in any Tenant B response, and vice versa
4. Test both `/api/v1/shelters` (list) and `/api/v1/shelters/{id}` (direct object reference)
5. Verify direct access to Tenant A's shelter by Tenant B returns 404 (not 403 — don't confirm existence)

### Connection Pool dvAccess Reset Test

New test in `DvAccessRlsTest` or a dedicated class:
1. Make a request with `dvAccess=true` (admin accessing DV shelter)
2. Immediately make a request with `dvAccess=false` (outreach worker)
3. Assert: second request does not see DV shelters (verifies `applyRlsContext()` overwrites stale state)
4. Run this 100 times in a tight loop to catch race conditions

### OWASP ZAP Scan

Run ZAP in Docker against the running demo environment:
```bash
docker run -t owasp/zap2docker-stable zap-full-scan.py -t https://DEMO_URL -r zap-report.html
```
Document all HIGH/CRITICAL findings as issues. Document MEDIUM findings with justification. Store the baseline report in `docs/security/zap-baseline-v0.14.1.html`.

### Swagger Prod Disable Verification

Verify `application-prod.yml` disables Swagger (it already does per code review). Add an integration test that boots with `prod` profile active and asserts `/api/v1/docs` returns 404.

## File Changes

| File | Change |
|------|--------|
| `JwtService.java` | Add `@PostConstruct` validation |
| `GlobalExceptionHandler.java` | Add universal `@ExceptionHandler(Exception.class)` |
| `application.yml` | Add `server.error.include-*: never` properties |
| `infra/nginx/nginx.conf` | Add 4 security headers |
| `pom.xml` | Add `bucket4j-spring-boot-starter`, `spring-boot-starter-cache`, `caffeine-jcache`, `javax.cache` |
| `application.yml` | Add bucket4j rate limit filter config (YAML-driven, no custom Java filter) |
| `application.conf` | Caffeine JCache HOCON config for rate-limit-login cache |
| `application-lite.yml` | Disable bucket4j in dev/lite profile (Karate e2e compatibility) |
| New: `RateLimitLoggingFilter.java` | WARN-level logging of rate-limited requests with client IP (bucket4j has no built-in logging) |
| New: `CrossTenantIsolationTest.java` | Concurrent multi-tenant isolation verification |
| New: `ConnectionPoolDvAccessResetTest.java` | dvAccess stale context verification |
| New: `SecurityStartupTest.java` | JWT secret validation startup test |
| New: `ErrorResponseLeakageTest.java` | Stack trace suppression verification |
| `docs/security/` | ZAP scan baseline report |

## Risks

- **Rate limiting false positives**: Shared IP (corporate NAT, shelter with 5 coordinators) could hit the limit. Mitigate with a generous window (10 per 15min) and clear `Retry-After` header.
- **CSP deferred**: Intentional — a broken CSP breaks Darius's offline flow. Will be a separate change with PWA testing.
- **ZAP scan scope**: Active scan may trigger rate limiting we just added. Run ZAP before enabling rate limiting, or whitelist ZAP's IP.
