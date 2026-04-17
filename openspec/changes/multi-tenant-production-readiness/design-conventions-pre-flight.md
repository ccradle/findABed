# Implementation pre-flight: project-wide conventions to check before adding files

**Status:** PROCESS APPENDIX (not a design decision; meta-doc).
**Origin:** post-A4 warroom retrospective 2026-04-17. Two convention
violations caught in CI rather than at design time during Phase A:

| When | Convention | Where caught |
|---|---|---|
| A4.1 (early) | `*IT.java` vs `*IntegrationTest.java` (Surefire default include patterns) | Warroom audit pre-push (only because we explicitly asked) |
| A4.3 → CI | `controllers_should_be_in_api_packages` ArchUnit rule | First CI run on PR #129 |

Each cost a CI cycle that could have been avoided by sweeping the
project's implicit conventions before code lands.

## The checklist

When the implementation plan in any future Phase X design doc adds a
new file of one of the kinds below, do this pre-flight first:

### 1. Adding a `@RestController`?
- [ ] Verify the package matches `..api..`. The
      `org.fabt.ArchitectureTest.controllers_should_be_in_api_packages`
      ArchUnit rule fails the build otherwise.
- [ ] Confirm `@PreAuthorize` is present and correctly gated. Check
      `org.fabt.ArchitectureTest` for any role-related rules.
- [ ] Run `grep -rln "@RestController" src/main/java/org/fabt/<module>/api/`
      to confirm the package convention for the relevant module.

### 2. Adding a test class?
- [ ] Class name MUST end in `Test` or `IntegrationTest`. Surefire's
      default include patterns are `**/Test*.java`, `**/*Test.java`,
      `**/*Tests.java`, `**/*TestCase.java`. **`*IT.java` is NOT in the
      default pattern** — would silently skip on `mvn test`.
- [ ] If the test class name's package doesn't match the production
      class's package, double-check via the `ls` of both `src/main` +
      `src/test` paths to avoid orphan-test confusion.

### 3. Adding a Flyway migration?
- [ ] Sanity-check Flyway version-number ordering against existing
      migrations: `ls src/main/resources/db/migration/V*.sql | tail -3`.
      Versions must be strictly increasing in the order Flyway will
      apply them across all phases.
- [ ] If the migration creates a new table, verify `fabt_app` role has
      the needed grants (typically `INSERT`, `UPDATE`, `SELECT`,
      `DELETE`). Postgres `\dp <table_name>` shows the grant matrix.
      The Phase B RLS rollout (task 3.4) is the formal grant audit;
      until then, manually verify on demo + prod schemas.
- [ ] Idempotent? `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ADD
      COLUMN IF NOT EXISTS`, `ON CONFLICT DO NOTHING` (or `DO UPDATE`)
      where partial-apply recovery matters.

### 4. Adding a `@Service` or `@Component`?
- [ ] Package must be reachable by Spring's component scan
      (`org.fabt.**` is). New module-root packages would need explicit
      `@ComponentScan` registration — check
      `org.fabt.Application` annotations.
- [ ] If the service has `@Transactional` methods that publish
      `ApplicationEvents` (e.g., audit events): the event listener
      runs inside the same transaction by default
      (`AuditEventService` is synchronous). Confirm the listener's
      `INSERT` joins the rotation tx so a rollback rolls audit too.
- [ ] If the constructor reads env vars: prod-profile fail-fast on
      missing/invalid values. Mirror the `MasterKekProvider` pattern.

### 5. Adding a new env var?
- [ ] `@PostConstruct` validation method.
- [ ] Prod-profile fail-fast for missing/blank.
- [ ] Non-prod fallback (committed dev value, or sensible default)
      so dev/CI don't need env-var churn.
- [ ] Document in `docs/runbook.md` "Required Environment Variables"
      table.
- [ ] Update Oracle deploy notes for the next release.

### 6. Adding a new `@ExceptionHandler`?
- [ ] If the handler publishes audit events: inject
      `ApplicationEventPublisher` via constructor.
- [ ] Map to the correct HTTP status — D3 envelope contract for
      `not_found`, `cross_tenant`, `access_denied`, etc.
- [ ] Increment a `Counter` for observability.
- [ ] Unit test the handler directly (don't rely on transitive IT
      coverage — each exception type deserves at least one focused
      unit test).

### 7. Adding cross-package imports?
- [ ] Check for circular dependencies. `shared.*` is the safe-to-
      depend-on namespace; module packages should not depend on each
      other.
- [ ] If a controller in `module-X.api` consumes a service from
      `shared.security`, that's fine. The reverse (a `shared.*`
      service consuming a `module-X.*` type) is a smell.

### 8. Adding new HTTP endpoints (any verb)?
- [ ] URL pattern matches `/api/v1/<module>/<resource>` convention.
- [ ] OpenAPI annotations (`@Operation`, `@Parameter`) for documentation.
- [ ] If admin-only: `@PreAuthorize("hasRole('PLATFORM_ADMIN')")`.
- [ ] Per-tenant rate-limit consideration (Phase E task 6.1 will
      provide the per-tenant rate-limit-config table; until then,
      document the absence + acceptable interim).

## How to use this checklist

For each implementation plan step in a future design doc, write a
1-line annotation: "pre-flight: items 1, 2, 4". Then before pushing,
walk through those items. ~5 minutes per checkpoint; ~25 minutes per
design doc; saves multiple CI cycles per PR.

If a new convention is added to the project (new ArchUnit rule, new
Surefire config, etc.), append it here so future warroom design docs
reference the up-to-date list.

## Items NOT covered (intentionally)

- Code style (lint, formatting) — the build catches these.
- Test coverage targets — covered by the warroom-driven test design
  for each design doc.
- Performance SLOs — covered per-design-decision in the relevant
  design doc.

This checklist is specifically for "things the project enforces that
weren't obvious from a fresh read of the codebase." If you find
yourself debugging a CI failure that boils down to "I didn't know
the project required X," append X here.
