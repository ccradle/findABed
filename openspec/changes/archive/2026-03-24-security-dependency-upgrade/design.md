## Context

Security scan report (SECURITY-SCAN-REPORT-2026-03-22.md) identified 23 CVEs. The most critical (CVE-2025-31651, CVSS 9.8) allows URL pattern bypass — directly relevant because FABT's DV shelter protection relies on SecurityConfig URL matchers. All work happens on a feature branch and is merged via PR only after the full test suite passes.

## Goals / Non-Goals

**Goals:**
- Resolve all 3 critical and 10 high CVEs
- Resolve the 2 medium Swagger UI XSS CVEs
- Resolve the 1 medium PostgreSQL driver CVE
- Suppress 6 non-applicable CVEs with documented rationale
- Restrict Swagger UI to development profiles only
- Verify Terraform TLS policy
- Zero test regressions

**Non-Goals:**
- Spring Boot 3.5.x or 4.x migration (separate future change — requires Java 21→23 assessment)
- Application code refactoring
- New features

## Decisions

### D1: Branch strategy

All changes on branch `security/dependency-upgrade` in the code repo (finding-a-bed-tonight). The docs repo (findABed) continues on main since OpenSpec artifacts aren't deployed code.

Branch workflow:
1. Create branch from main
2. Make all dependency changes
3. Run full test suite (backend, Playwright, Karate, Gatling)
4. Fix any test regressions from the upgrade
5. Create PR to main
6. Merge after CI passes

### D2: Spring Boot 3.4.4 → 3.4.13

Single pom.xml change. Spring Boot BOM manages Tomcat, so this automatically bumps:
- `tomcat-embed-core` to 10.1.x (patched)
- Likely bumps `commons-lang3`, `kotlin-stdlib`, and `postgresql` driver

Check the release notes for 3.4.5–3.4.13 for any breaking changes or deprecations before upgrading.

### D3: springdoc-openapi 2.8.6 → 2.9.0+

Update the `<springdoc.version>` property in pom.xml. Verify that 2.9.0 bundles DOMPurify >= 3.3.2 (resolves CVE-2025-15599 and CVE-2026-0540).

### D4: Swagger UI production restriction

Create `application-prod.yml` (or add to existing profiles) to disable Swagger UI:
```yaml
springdoc:
  api-docs:
    enabled: false
  swagger-ui:
    enabled: false
```

Update `SecurityConfig.java` to conditionally permit Swagger paths. When springdoc is disabled, the paths return 404 anyway, but removing the permitAll rules is defense-in-depth.

### D5: PostgreSQL driver override

If the Spring Boot 3.4.13 BOM doesn't bump postgresql to 42.7.7+, add an explicit property:
```xml
<postgresql.version>42.7.7</postgresql.version>
```

### D6: OWASP suppressions

Add suppressions to `owasp-suppressions.xml` for 6 CVEs that don't apply:
- CVE-2025-68161 (log4j Socket Appender — not used, SLF4J/Logback is backend)
- CVE-2020-29582 (kotlin-stdlib temp files — transitive dep, not called from Java)
- CVE-2025-49124 (Tomcat Windows installer — not applicable to embedded Tomcat)
- CVE-2026-24734 (Tomcat Native OCSP — Tomcat Native not used)
- CVE-2025-46701 (Tomcat CGI servlet — not used in Spring Boot)
- CVE-2025-55668 (Tomcat rewrite valve — not configured)

Each suppression must include:
- CVE ID
- Rationale explaining why it doesn't apply
- Review date for future re-evaluation

### D7: Terraform TLS policy

Verify `infra/terraform/modules/app/main.tf` line 213 has:
```hcl
ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
```
If missing or using an older policy, update it.
