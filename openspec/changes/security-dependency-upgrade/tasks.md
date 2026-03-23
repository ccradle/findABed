## 1. Branch Setup

- [x] 1.1 Create branch `security/dependency-upgrade` from main in the code repo (finding-a-bed-tonight)
- [x] 1.2 Switch to the branch: `git checkout security/dependency-upgrade`

## 2. Spring Boot Upgrade (resolves 13 Tomcat CVEs)

- [x] 2.1 Review Spring Boot 3.4.5–3.4.13 release notes for breaking changes or deprecations
- [x] 2.2 Update `pom.xml`: Spring Boot parent version from `3.4.4` to `3.4.13`
- [x] 2.3 Run `mvn compile` — fix any compilation errors from the upgrade
- [x] 2.4 Run full backend test suite (`mvn test`) — fix any test regressions
- [x] 2.5 Verify Tomcat version bumped: check `mvn dependency:tree | grep tomcat` for patched version

## 3. springdoc-openapi Upgrade (resolves 2 XSS CVEs)

- [x] 3.1 Check latest springdoc-openapi version that bundles DOMPurify >= 3.3.2
- [x] 3.2 Update `pom.xml`: `<springdoc.version>` from `2.8.6` to latest stable
- [x] 3.3 Verify Swagger UI still works locally at `/api/v1/docs`

## 4. Swagger UI Production Restriction

- [x] 4.1 Create `application-prod.yml` in `src/main/resources`: disable springdoc api-docs and swagger-ui
- [x] 4.2 Verify Swagger UI is still accessible with default (lite) profile
- [x] 4.3 Verify Swagger UI returns 404 when running with `--spring.profiles.active=prod`

## 5. PostgreSQL Driver Override

- [x] 5.1 Check if Spring Boot 3.4.13 BOM already bumps postgresql to 42.7.7+
- [x] 5.2 If not, add `<postgresql.version>42.7.7</postgresql.version>` to pom.xml properties
- [x] 5.3 Run backend tests to verify no PostgreSQL driver regression

## 6. OWASP Suppressions

- [x] 6.1 Add 6 CVE suppressions to `owasp-suppressions.xml` with rationale and review date for each: CVE-2025-68161, CVE-2020-29582, CVE-2025-49124, CVE-2026-24734, CVE-2025-46701, CVE-2025-55668

## 7. Terraform TLS Policy

- [x] 7.1 Verify `infra/terraform/modules/app/main.tf` has `ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"` on the ALB listener. Update if missing or outdated.

## 8. Full Regression Testing

- [x] 8.1 Run full backend test suite: `mvn test` (expect 152+ tests, 0 failures)
- [x] 8.2 Restart dev stack: `./dev-start.sh stop && ./dev-start.sh`
- [x] 8.3 Run Playwright tests: all 52 tests pass
- [x] 8.4 Run Karate tests: all 32 main tests pass
- [x] 8.5 Run Gatling performance tests: all simulations pass with no degradation
- [x] 8.6 Verify Swagger UI accessible at `/api/v1/docs` (dev profile)
- [x] 8.7 Verify OAuth2 SSO flow still works (type dev-coc, see keycloak button)

## 9. PR and Merge

- [x] 9.1 Commit all changes on `security/dependency-upgrade` branch
- [x] 9.2 Push branch to remote: `git push -u origin security/dependency-upgrade`
- [x] 9.3 Create PR to main via `gh pr create` with security scan summary
- [x] 9.4 Monitor CI on the PR — all jobs must pass
- [x] 9.5 Merge PR to main (squash or merge commit)
- [x] 9.6 Delete the feature branch after merge
- [x] 9.7 Tag the release (v0.9.1 patch)

## 10. Documentation

- [x] 10.1 Update code repo README: note Spring Boot version in badges/tech stack
- [x] 10.2 Move `SECURITY-SCAN-REPORT-2026-03-22.md` to docs/ or add resolution notes
- [x] 10.3 Update docs repo README if needed
