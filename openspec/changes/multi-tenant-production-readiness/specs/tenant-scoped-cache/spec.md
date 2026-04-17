## ADDED Requirements

### Requirement: tenant-scoped-cache-service
The system SHALL provide a `TenantScopedCacheService` wrapper (per C1) that prepends `TenantContext.getTenantId()` to every cache key and throws `IllegalStateException` if no tenant context is bound (fail-fast). All application cache access for tenant-owned data SHALL route through this wrapper.

#### Scenario: Tenant-scoped put and get succeed within the same tenant
- **GIVEN** a request is bound to tenant A via `TenantContext`
- **WHEN** `TenantScopedCacheService.put("shelters:active", value)` runs, then `get("shelters:active")` runs
- **THEN** the effective cache key is `<tenantA-uuid>:shelters:active`
- **AND** the value is returned on get

#### Scenario: Cross-tenant read returns miss
- **GIVEN** tenant A has written key `shelters:active` to its scoped cache
- **WHEN** a new request bound to tenant B calls `TenantScopedCacheService.get("shelters:active")`
- **THEN** the effective key resolves to `<tenantB-uuid>:shelters:active`
- **AND** the lookup returns a cache miss — tenant A's entry is invisible

#### Scenario: Missing tenant context fails fast
- **WHEN** `TenantScopedCacheService.get("shelters:active")` is called with no `TenantContext` bound
- **THEN** the call throws `IllegalStateException` with a message identifying the missing tenant context
- **AND** no cache lookup is performed

### Requirement: archunit-family-c-cache-coverage
The project SHALL maintain an ArchUnit Family C rule (per C2) that fails the build when any class in `*.service` or `*.api` calls `TieredCacheService.get` / `TieredCacheService.put` or constructs `Caffeine.newBuilder()` directly without routing through `TenantScopedCacheService` OR carrying a `@TenantUnscopedCache("<justification>")` annotation with a non-empty justification.

#### Scenario: Bare Caffeine.newBuilder fails the build
- **GIVEN** a new service class adds `private final Cache<UUID, Foo> cache = Caffeine.newBuilder().build();`
- **WHEN** the Family C ArchUnit rule runs
- **THEN** the build fails with a message naming the offending class, the line, and the two acceptable remediations

#### Scenario: @TenantUnscopedCache with justification passes
- **GIVEN** a service field annotated `@TenantUnscopedCache("cross-tenant platform-admin cache; never serves request paths")`
- **WHEN** the Family C rule runs
- **THEN** the annotated field is allowed
- **AND** the rule logs the justification for the annotated use

#### Scenario: Empty @TenantUnscopedCache justification rejected
- **GIVEN** `@TenantUnscopedCache("")` on a cache field
- **WHEN** the Family C rule runs
- **THEN** the build fails with a message requiring a non-empty justification

#### Scenario: Rule covers JwtService, EscalationPolicyService, ApiKeyAuthenticationFilter
- **WHEN** the Family C rule scans the codebase
- **THEN** `JwtService.claimsCache`, `EscalationPolicyService.policyById`, and `ApiKeyAuthenticationFilter.rateLimitBuckets` are each either routed through `TenantScopedCacheService` or annotated with a non-empty justification

### Requirement: escalation-policy-service-composite-key
The system SHALL key `EscalationPolicyService.policyById` by the composite `CacheKey(tenantId, policyId)` (per C3 LATENT fix) rather than by UUID alone, preventing cross-tenant leak if policies ever become shared across tenants.

#### Scenario: Composite key isolates tenant entries
- **GIVEN** tenant A has policy `p1` and tenant B has a different policy with the same UUID (hypothetical future state)
- **WHEN** tenant A loads policy via `policyById`
- **THEN** the cache key is `(tenantA, p1)`
- **AND** tenant B's subsequent load resolves to `(tenantB, p1)` — different cache entry, no cross-tenant confusion

#### Scenario: Legacy UUID-only key is removed
- **GIVEN** prior code used `Cache<UUID, EscalationPolicy>`
- **WHEN** this change lands
- **THEN** the field type is `Cache<CacheKey, EscalationPolicy>` where `CacheKey` contains `(tenantId, policyId)`
- **AND** no call site passes a bare UUID

### Requirement: redis-pooling-adr
The project SHALL publish an ADR (per C4, D6) documenting the Redis deployment posture: single-tenant Redis is the default; regulated-tier deployments include their own silo'd Redis; pooled-multi-tenant Redis is not supported without Redis ACL-per-tenant or per-tenant logical DBs.

#### Scenario: ADR file exists and documents the decision
- **GIVEN** `docs/architecture/redis-pooling-adr.md` is published
- **WHEN** an operator opens it
- **THEN** it states the decision (single-tenant Redis default) and lists rejected alternatives (shared Redis + ACL, shared Redis + logical DB per tenant)
- **AND** it references `project_standard_tier_untested.md` as the prior stance being codified

#### Scenario: Standard-tier pooled deploy flushes Redis on tenant shutdown
- **GIVEN** the standard tier uses Caffeine L1 and optional single-tenant Redis
- **WHEN** a tenant is suspended
- **THEN** the tenant's Caffeine entries are invalidated via `TenantScopedCacheService`
- **AND** any Redis keys are flushed per the ADR procedure

### Requirement: reflection-cache-bleed-fixture
The project SHALL maintain a reflection-driven cache-bleed test fixture (per C5) that discovers every `@Cacheable`-annotated method and every `TieredCacheService.get` call site, and for each site generates a parameterized test asserting `tenantA.write(k); tenantB.read(k)` returns a cache miss.

#### Scenario: Fixture enumerates all cache call sites
- **WHEN** the `CacheBleedReflectionTest` runs
- **THEN** it reflects over the classpath and identifies every `@Cacheable` method + every `TieredCacheService.get` / `put` call
- **AND** it produces one test row per call site

#### Scenario: Cross-tenant read yields miss on every call site
- **GIVEN** the fixture generates a test per call site
- **WHEN** each test runs (tenant A writes key k, tenant B reads k)
- **THEN** every test asserts that tenant B's read is a cache miss
- **AND** any call site that fails the assertion fails the build

#### Scenario: New @Cacheable method auto-enrolled
- **WHEN** a PR adds `@Cacheable` to a new service method
- **THEN** the reflection fixture discovers it on the next build
- **AND** the test generates a cross-tenant assertion with no additional developer effort

### Requirement: negative-cache-tenant-scoping
The system SHALL tenant-scope negative cache entries (per C6) — every 404 / null cache entry is stored under the tenant-prefixed key. This prevents tenant A's 404 from masking tenant B's later create.

#### Scenario: Tenant A 404 does not mask tenant B create
- **GIVEN** tenant A queries for resource `r1` and receives 404, which is cached as a negative entry
- **WHEN** tenant B subsequently creates resource `r1` in its own tenant scope
- **THEN** tenant B's read of `r1` is a cache miss (not served by tenant A's negative entry)
- **AND** tenant B's read proceeds to the DB and returns the created resource

#### Scenario: Negative entry evicted on same-tenant write
- **GIVEN** tenant A has a negative cache entry for resource `r1`
- **WHEN** tenant A creates `r1` in its own tenant
- **THEN** the negative entry is evicted and subsequent read returns the created resource
