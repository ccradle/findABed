## ADDED Requirements

### Requirement: cache-bleed-reflection-fixture
The project SHALL maintain a reflection-driven cache-bleed test fixture (per J2, C5) that discovers every `@Cacheable`-annotated method and every `TieredCacheService.get` / `put` call site, and for each generates a parameterized assertion that tenant B cannot read tenant A's cached value.

#### Scenario: Fixture enumerates all cache call sites
- **WHEN** `CacheBleedReflectionTest` runs
- **THEN** it reflects over the classpath and produces one test row per call site
- **AND** zero call sites are excluded (every site is covered)

#### Scenario: Cross-tenant read yields miss for every site
- **WHEN** each test row runs (tenant A writes key k, tenant B reads k)
- **THEN** tenant B's read is a cache miss
- **AND** any call site where cross-tenant read returns a value fails the test

#### Scenario: New @Cacheable method auto-enrolled
- **WHEN** a PR adds `@Cacheable` to a new method
- **THEN** the reflection fixture discovers it on the next build without code changes to the fixture
- **AND** the test asserts cross-tenant isolation for the new site

### Requirement: sse-replay-cross-tenant-test
The project SHALL maintain an SSE replay cross-tenant test (per J3) with a 2-tenant setup: both tenants disconnect with events buffered, both reconnect with `Last-Event-ID`, and each tenant's replay contains ZERO events from the other.

#### Scenario: Replay isolates tenant A from tenant B events
- **GIVEN** tenant A and tenant B each have 10 buffered events
- **WHEN** both tenants disconnect and reconnect with `Last-Event-ID`
- **THEN** tenant A receives only its own 10 events
- **AND** tenant B receives only its own 10 events
- **AND** no cross-tenant event appears in either replay

#### Scenario: Sequence ID collision does not cross tenants
- **GIVEN** tenant A's event id=5 and tenant B's event id=5 exist
- **WHEN** each tenant replays with `Last-Event-ID=4`
- **THEN** each tenant's replay begins at its own id=5 (not the other tenant's)

### Requirement: per-tenant-jwt-key-rotation-test
The project SHALL maintain a JWT rotation test (per J4) that signs under key-generation 1, bumps to 2, asserts the old token is rejected on validate, the new token is accepted, and that cross-tenant-key-confusion is rejected (tenant A token signed with tenant A key but claiming tenant B in body).

#### Scenario: Old-generation token rejected after bump
- **GIVEN** tenant A has `jwt_key_generation=1` and a JWT issued under generation 1
- **WHEN** `jwt_key_generation` is bumped to 2 and the old token is presented
- **THEN** validation fails with 401
- **AND** the kid resolution path reveals the mismatch

#### Scenario: New-generation token accepted
- **WHEN** a new JWT is issued under generation 2 and presented
- **THEN** validation succeeds
- **AND** the request proceeds for tenant A

#### Scenario: Cross-tenant claim + kid mismatch rejected
- **GIVEN** a JWT signed with tenant A's key but carrying `tenantId=<tenantB>` in body
- **WHEN** validation runs
- **THEN** the A7 claim-kid cross-check fails with 401
- **AND** an audit event `JWT_CLAIM_KID_MISMATCH` is emitted

### Requirement: url-path-sink-full-coverage
The project SHALL extend `TenantPredicateCoverageTest` (per J5, D1) to cover every write-path controller with path variables — not only the v0.40 audit subset. A regression guard SHALL require new controllers to add a fixture row.

#### Scenario: Every write-path controller covered
- **GIVEN** the set of all POST / PUT / PATCH / DELETE controllers with `{id}` or `{tenantId}` path variables
- **WHEN** the fixture runs
- **THEN** each controller has at least one row asserting "tenant A actor + tenant B path variable → 404"

#### Scenario: New controller missing row fails CI
- **GIVEN** a PR adds a new write-path controller with a path variable
- **WHEN** the fixture discovery runs
- **THEN** the build fails with a message naming the uncovered controller
- **AND** the remediation is to add a fixture row

### Requirement: tenant-lifecycle-tests
The project SHALL maintain tenant-lifecycle integration tests (per J6) covering: create → provision users → suspend → 401 on all APIs → offboard → data preserved + no login → archived → reactivate blocked → delete → crypto-shred verified (DEK unrecoverable, encrypted columns undecryptable).

#### Scenario: End-to-end lifecycle test passes
- **WHEN** the test runs the full lifecycle
- **THEN** each state transition has the expected effect (per F1–F8)
- **AND** the final crypto-shred assertion confirms the DEK row is deleted and decrypt fails

#### Scenario: Reactivate from ARCHIVED blocked
- **WHEN** the test attempts to transition from ARCHIVED back to ACTIVE
- **THEN** the attempt fails with IllegalStateException per D8

### Requirement: breach-simulation-15-vectors
The project SHALL maintain breach simulation tests (per J7) seeding a DV referral in tenant A and attempting cross-tenant read via 15+ attack vectors: path parameter, query parameter, header, body, cached value, SSE replay, audit event read, webhook payload, HMIS outbox, rate-limit bucket enumeration, prometheus scrape, log grep, timing, DNS rebinding, host-header injection, cache-bleed. Every attempt SHALL fail.

#### Scenario: Each vector returns the expected defense outcome
- **WHEN** the breach-simulation test iterates through the 15+ vectors
- **THEN** each attempt fails (404, 401, block, or miss as appropriate per vector)
- **AND** no tenant B observer can see tenant A's DV referral data

#### Scenario: Metric emitted per blocked attempt
- **WHEN** each simulated vector completes
- **THEN** a `fabt_breach_simulation_vector_result{vector=<name>,outcome=<blocked|leaked>}` metric increments
- **AND** any `outcome=leaked` row fails the CI build

### Requirement: noisy-neighbor-gatling
The project SHALL maintain `NoisyNeighborSimulation` Gatling scenario (per J18) with two concurrent tenant simulations: tenant A at 3x normal load; tenant B p95 degrades ≤ 20%. The SLO SHALL be quantified per tenant and enforced.

#### Scenario: Noisy-neighbor SLO holds
- **GIVEN** the Gatling scenario runs both tenants concurrently
- **WHEN** tenant A generates 3x normal load
- **THEN** tenant B p95 latency degrades by at most 20%
- **AND** the test fails if degradation exceeds the SLO

#### Scenario: Per-tenant error budget tracked
- **WHEN** the scenario completes
- **THEN** per-tenant error counts and latency percentiles are reported
- **AND** regressions against historical baselines fail CI

### Requirement: superuser-bypass-ci-guard
The project SHALL enforce a superuser-bypass CI guard (per J17) — `SELECT current_user` assertion in the test harness MUST return `fabt_app`. Any test running as the DB owner (`fabt`) SHALL fail the build.

#### Scenario: Test running as fabt_app passes guard
- **GIVEN** the integration test harness borrows a connection
- **WHEN** the guard runs `SELECT current_user`
- **THEN** the result is `fabt_app` and the guard passes

#### Scenario: Test running as fabt (owner) fails guard
- **GIVEN** a misconfigured test harness connects as `fabt`
- **WHEN** the guard runs
- **THEN** the build fails with an explicit message citing `feedback_rls_hides_dv_data.md`
- **AND** the test run is aborted before the RLS assertions can silently succeed

### Requirement: playwright-cross-tenant-cache-bleed
The project SHALL include a Playwright cross-tenant cache-bleed test (per J8) that logs in as tenant A, populates DOM / Service Worker / IndexedDB cache, logs out, logs in as tenant B, and asserts tenant A's data is not visible anywhere in the browser.

#### Scenario: Service Worker does not serve tenant A data to tenant B
- **GIVEN** tenant A's session populated the Service Worker cache
- **WHEN** the user logs in as tenant B in the same browser
- **THEN** no tenant A resource is served from the Service Worker
- **AND** the test asserts DOM, Service Worker, and IndexedDB are clear of tenant A data

#### Scenario: Logout clears tenant state
- **WHEN** the logout flow runs
- **THEN** tenant-scoped caches are cleared (DOM stores, IndexedDB entries with tenant A prefix)
- **AND** the subsequent tenant B session begins with no tenant A remnants

### Requirement: multi-tenant-concurrent-at-scale
The project SHALL maintain a multi-tenant concurrent-at-scale test (per J12) with 20 tenants × 50 concurrent requests. Zero cross-tenant leak SHALL occur and per-tenant p95 SHALL stay within the documented SLO.

#### Scenario: 20 tenants × 50 concurrent requests isolated
- **WHEN** the test harness fires 20 × 50 = 1000 concurrent requests
- **THEN** no tenant's response contains data from any other tenant
- **AND** per-tenant p95 latency is within the SLO

#### Scenario: Failure mode reports offending tenant pair
- **GIVEN** a future regression causes tenant X to see tenant Y's data in 1 of 1000 requests
- **WHEN** the test fails
- **THEN** the failure message identifies the offending tenant pair and resource type

### Requirement: file-path-tenant-isolation-harness
The project SHALL maintain a file-path tenant-isolation test harness (per J13) that generates a test for every file-write code path and fails CI if a new write path does not include `tenant_id` in filename or path.

#### Scenario: No file-write paths today — harness is regression infrastructure
- **GIVEN** the codebase currently has no file-write paths
- **WHEN** the harness scans
- **THEN** it reports "zero file-write paths; harness ready for future additions"

#### Scenario: New file-write path without tenant_id fails CI
- **GIVEN** a PR adds a file-write path at `/tmp/output/<id>.json` (no tenant_id)
- **WHEN** the harness scans
- **THEN** the build fails with a message requiring tenant_id in the path

### Requirement: flyway-migration-rollback-test
The project SHALL maintain a Flyway migration rollback test (per J14) — drop each D14 tenant-RLS policy, re-add, assert identical state. This rehearses the rollback plan.

#### Scenario: Drop + re-add yields identical pg_policies state
- **GIVEN** the V66 D14 policies are applied
- **WHEN** the test drops each policy then re-adds via the documented rollback/forward script
- **THEN** the resulting `pg_policies` output matches the original snapshot

#### Scenario: Partial rollback fails the test
- **GIVEN** the rollback-then-re-add leaves a policy drifted
- **WHEN** the test compares post-re-add state to the snapshot
- **THEN** the test fails with the drift identified

### Requirement: archunit-rule-negative-tests
The project SHALL maintain ArchUnit rule negative tests (per J15) — intentional violations for every new Family C / D / E rule — that assert the rule fires as expected.

#### Scenario: Synthetic violation triggers Family C rule
- **GIVEN** a test fixture class deliberately calls bare `Caffeine.newBuilder()` without annotation
- **WHEN** the Family C rule runs against the fixture
- **THEN** the rule reports a violation against the fixture class

#### Scenario: Rule suppression regression detected
- **GIVEN** a developer disables the rule
- **WHEN** the negative test runs
- **THEN** the test fails because the deliberate violation is no longer caught
- **AND** the suppression is flagged for review

### Requirement: person-in-crisis-comment-rule
The project SHALL enforce (per J16, via PR review checklist) that every new tenant-isolation test carries a "What happens to the person in crisis if this test is missing?" comment. This is Riley's rule.

#### Scenario: New tenant-isolation test has the comment
- **WHEN** a PR adds a new tenant-isolation test
- **THEN** the test file includes the "person in crisis" comment describing the real-world failure mode

#### Scenario: Missing comment flagged in PR review
- **GIVEN** a PR adds a tenant-isolation test without the comment
- **WHEN** review runs
- **THEN** the reviewer requests the addition per the checklist

### Requirement: dv-canary-multi-tenant-extension
The project SHALL extend the DV canary test (per J11) to a pooled-instance multi-tenant variant: tenant A has a DV shelter; tenant B has no `dvAccess`; tenant B SHALL NOT see tenant A's DV shelter in any surface (search, audit, HMIS, cache, SSE replay, prometheus).

#### Scenario: Tenant B cannot see tenant A DV shelter in search
- **WHEN** tenant B's user runs a bed search
- **THEN** tenant A's DV shelter does not appear in results

#### Scenario: Tenant B prometheus scrape shows no tenant A metrics
- **GIVEN** tenant B has no observability read access (standard tier)
- **WHEN** tenant B attempts to scrape /actuator/prometheus
- **THEN** the scrape is rejected per I3

### Requirement: pre-production-external-pentest
The project SHALL engage (per J20) a pre-production external pentest against the OWASP Cloud Tenant Isolation checklist before the first pooled-tenant pilot. If external vendor is not feasible due to budget, a self-audit against the same checklist SHALL be documented with evidence.

#### Scenario: External pentest documented in artifact
- **GIVEN** the pentest is completed
- **WHEN** the artifact is reviewed
- **THEN** it covers every OWASP Cloud Tenant Isolation checklist item
- **AND** findings are tracked to closure with linked remediation commits

#### Scenario: Self-audit substituted when budget-constrained
- **GIVEN** no external vendor is engaged
- **WHEN** the self-audit runs
- **THEN** `docs/security/tenant-isolation-self-audit.md` is published with evidence per checklist item
- **AND** Marcus reviews and signs off
