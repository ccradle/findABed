## Why

The 2026-03-22 security scan (OWASP Dependency-Check, SpotBugs, Semgrep, Gitleaks) identified 3 critical, 10 high, and 8 medium CVEs. The most severe (CVE-2025-31651, CVSS 9.8) allows URL pattern bypass of security constraints — directly threatening FABT's DV shelter data protection model which relies on URL-based security matchers in SecurityConfig.java. 13 of 23 CVEs trace to embedded Tomcat 10.1.39 (via Spring Boot 3.4.4) and are resolved by a single Spring Boot upgrade. Spring Boot 3.4.x is at end-of-life for open source support.

## What Changes

- **Spring Boot upgrade**: 3.4.4 → 3.4.13 (resolves 13 Tomcat CVEs including 3 critical)
- **springdoc-openapi upgrade**: 2.8.6 → 2.9.0+ (resolves 2 Swagger UI DOMPurify XSS CVEs)
- **Swagger UI production restriction**: Disable Swagger UI in non-dev profiles (defense in depth)
- **PostgreSQL JDBC driver override**: 42.7.5 → 42.7.7 (resolves 1 medium CVE)
- **OWASP suppression file update**: Add 6 CVE suppressions for non-applicable transitive dependencies
- **Terraform TLS policy verification**: Verify ALB ssl_policy uses TLS 1.2+ minimum
- **All changes on feature branch** `security/dependency-upgrade` — merged to main only after full test suite passes

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `deployment-profiles`: Swagger UI disabled in production profiles

## Impact

- **Modified files**: `pom.xml` (Spring Boot version, springdoc version, postgresql version), `owasp-suppressions.xml` (6 new suppressions), `application.yml` or new `application-prod.yml` (springdoc disabled), `SecurityConfig.java` (conditional Swagger permitAll), `infra/terraform/modules/app/main.tf` (ssl_policy verification)
- **No API changes**: All endpoints remain unchanged
- **No database changes**: No migrations needed
- **Risk**: Spring Boot minor version upgrade may introduce behavioral changes — full regression test required
- **Branch strategy**: All changes on `security/dependency-upgrade` branch, PR to main after tests pass
