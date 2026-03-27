## Why

A static security review using the Marcus Webb AI persona (AppSec, defined in PERSONAS.md) identified 12 findings against v0.14.1 that will surface in any city IT security scan before pilot adoption. Four are HIGH severity: JWT secret startup validation, cross-tenant isolation under virtual threads (untested), referral token lifecycle gaps, and no OWASP ZAP scan run. These must be resolved before the first city IT engagement (Teresa Nguyen's evaluation). The DV threat model — disclosure of a survivor's location — makes every auth and multi-tenant finding a safety issue, not just a compliance checkbox.

## What Changes

- Add `@PostConstruct` JWT secret startup validation — fail fast on missing/weak secret
- Add universal `@ExceptionHandler(Exception.class)` catch-all — prevent stack trace leakage
- Add `CrossTenantIsolationTest` — concurrent virtual thread isolation verification
- Add connection pool dvAccess reset verification test
- Add 4 security headers to `nginx.conf` (X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy)
- Add rate limiting on `/api/v1/auth/login` and `/api/v1/auth/refresh` endpoints
- Disable Swagger UI in `application-prod.yml` (verify existing config is active)
- Run OWASP ZAP active scan against demo environment and document results
- Review and verify all `permitAll()` paths in SecurityConfig for information disclosure

## Capabilities

### New Capabilities
- `jwt-startup-validation`: Explicit startup assertion for JWT secret presence, strength, and non-default value
- `security-headers`: nginx security headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy)
- `auth-rate-limiting`: Brute force protection on authentication endpoints using bucket4j or Redis counter
- `cross-tenant-isolation-test`: Concurrent virtual thread multi-tenant isolation verification test suite
- `security-scan-baseline`: OWASP ZAP scan against demo environment with documented baseline

### Modified Capabilities
- `auth-and-roles`: Universal exception handler catch-all to prevent stack trace leakage on unhandled exceptions
- `rls-enforcement`: Connection pool dvAccess reset verification test; verify stale context cannot persist across requests

## Impact

- **Backend**: JwtService, GlobalExceptionHandler, SecurityConfig, new test classes
- **Infrastructure**: nginx.conf, application-prod.yml verification
- **CI**: OWASP ZAP scan step (optional gate or report-only)
- **Dependencies**: bucket4j-spring-boot-starter (new, for rate limiting) or Redis-backed counter
- **Testing**: 4+ new integration test classes, OWASP ZAP report artifact
- **DV safety**: Cross-tenant test directly validates DV shelter isolation under concurrent load
