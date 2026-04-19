## ADDED Requirements

### Requirement: tenant-scoped-cache-service
The system SHALL provide a `TenantScopedCacheService` wrapper (per C1) that prepends `TenantContext.getTenantId()` to every cache key and throws `IllegalStateException` if no tenant context is bound (fail-fast). All application cache access for tenant-owned data SHALL route through this wrapper.

The wrapper SHALL be published as a **distinct Spring bean** named `tenantScopedCacheService` (dependency-injected where callers want tenant scoping), NOT as `@Primary` over the existing `CacheService` bean. This is deliberate: the existing `CacheService` bean remains available for annotated-unscoped callers, and `@Primary` would silently double-prefix call sites that already manually embed `tenantId` in the key (producing stale `<tenant>:<tenant>:key` entries). Migration acceptance criteria: every converted call site SHALL strip any caller-side tenant prefix when routing through the wrapper.

The prefix separator SHALL be `|` (pipe), NOT `:` (colon). This is deliberate per Phase C warroom D-4.1-9: existing composite call-site keys in `AnalyticsService` (and similar) use colon as a separator (e.g. `tenantId + ":" + from + ":" + to`). Using `|` between the tenant prefix and the caller's logical key produces unambiguous `<tenantA-uuid>|<from>:<to>` effective keys that are visually debuggable and cannot collide with the caller's internal structure.

`IllegalStateException` messages propagated from the wrapper to HTTP response bodies SHALL NOT contain tenant UUIDs or cache values; they SHALL contain only short action tags (`CROSS_TENANT_CACHE_READ`, `MALFORMED_CACHE_ENTRY`, `TENANT_CONTEXT_UNBOUND`). UUIDs and details SHALL be persisted to `audit_events` rows + structured logs only.

#### Scenario: Tenant-scoped put and get succeed within the same tenant
- **GIVEN** a request is bound to tenant A via `TenantContext`
- **WHEN** `TenantScopedCacheService.put("shelters:active", value)` runs, then `get("shelters:active")` runs
- **THEN** the effective cache key is `<tenantA-uuid>|shelters:active`
- **AND** the value is returned on get

#### Scenario: Cross-tenant read returns miss
- **GIVEN** tenant A has written key `shelters:active` to its scoped cache
- **WHEN** a new request bound to tenant B calls `TenantScopedCacheService.get("shelters:active")`
- **THEN** the effective key resolves to `<tenantB-uuid>|shelters:active`
- **AND** the lookup returns a cache miss — tenant A's entry is invisible

#### Scenario: Missing tenant context fails fast
- **WHEN** `TenantScopedCacheService.get("shelters:active")` is called with no `TenantContext` bound
- **THEN** the call throws `IllegalStateException` tagged `TENANT_CONTEXT_UNBOUND` (exception message carries the tag only; no UUIDs)
- **AND** no cache lookup is performed

#### Scenario: Null value on put is rejected at runtime
- **WHEN** `TenantScopedCacheService.put(cacheName, key, null, ttl)` is called
- **THEN** the call throws `IllegalArgumentException` immediately (belt-and-suspenders with the Family C ArchUnit rule on `put(…, null, …)`)
- **AND** no cache write occurs

### Requirement: tenant-scoped-cache-value-verification
The wrapper SHALL embed the writer's `TenantContext.getTenantId()` inside the stored cache value via a `TenantScopedValue<T>(UUID tenantId, T value)` record envelope on every `put`, and SHALL verify on every `get` that the envelope's `tenantId` matches the reader's current `TenantContext.getTenantId()`. Mismatches SHALL throw `IllegalStateException` tagged `CROSS_TENANT_CACHE_READ`.

This defends against wrong-tenant-context-on-write — the leading 2025-2026 cache-leak pattern per Redis Inc. Feb 2026 and OWASP ASVS 5.0 (May 2025). Key-prefix alone defends the read side; value-stamp-and-verify defends the write side. Both layers must fail in the same direction for a leak.

The cross-tenant-read audit row SHALL be persisted via a `@Transactional(propagation = REQUIRES_NEW)` helper (e.g., `AuditEventPersister.persist`) so the audit row commits independently of the caller's transaction fate. An attacker who triggers a cross-tenant read followed by a rollback SHALL NOT erase the audit evidence.

`IllegalStateException` messages propagated from the wrapper SHALL contain only the action tag `CROSS_TENANT_CACHE_READ` — never tenant UUIDs, key values, or cached payload fragments.

#### Scenario: Cross-tenant write-then-read throws
- **GIVEN** a writer bound to tenant A calls `put("shelters:active", value)` — envelope stamped with tenantA
- **WHEN** a reader bound to tenant B directly reads the tenantA-prefixed key via raw `CacheService` (bypassing the wrapper's prefix) OR the wrapper's prefix computation produces the same underlying cache key due to a future bug
- **THEN** the wrapper's envelope verification rejects the read with `IllegalStateException` tagged `CROSS_TENANT_CACHE_READ`
- **AND** `fabt.cache.get{cache,tenant,result=cross_tenant_reject}` Micrometer counter is incremented
- **AND** an `audit_events` row with action `CROSS_TENANT_CACHE_READ` is persisted

#### Scenario: Cross-tenant-read audit survives caller rollback
- **GIVEN** a request bound to tenant B triggers a cross-tenant cache read inside a `@Transactional` method
- **WHEN** the wrapper detects the mismatch and throws `IllegalStateException` — caller's transaction rolls back
- **THEN** the `audit_events` row persisted via `REQUIRES_NEW` remains committed after the caller's rollback
- **AND** the audit row is visible to subsequent platform-admin queries

#### Scenario: Malformed cache entry (pre-migration raw write) throws
- **GIVEN** a caller bypasses the wrapper and writes a non-`TenantScopedValue` payload directly via raw `CacheService.put`
- **WHEN** a wrapper `get` encounters that entry
- **THEN** the wrapper throws `IllegalStateException` tagged `MALFORMED_CACHE_ENTRY` (exception message carries tag only; no UUIDs or payload)
- **AND** a Micrometer counter signals the malformed read for operator alerting

#### Scenario: Exception message does not leak tenant UUIDs
- **GIVEN** a `CROSS_TENANT_CACHE_READ` exception propagates to the HTTP response via `GlobalExceptionHandler`
- **WHEN** the response body is serialised
- **THEN** the response body contains only the action tag `CROSS_TENANT_CACHE_READ` — never the expected or observed tenant UUID, key, or cached value

### Requirement: archunit-family-c-cache-coverage
The project SHALL maintain an ArchUnit Family C rule (per C2) that fails the build when any class in `*.service`, `*.api`, `*.security`, `*.auth.*` (or their subpackages) calls `CacheService.get` / `CacheService.put` / `TieredCacheService.get` / `TieredCacheService.put` or constructs `Caffeine.newBuilder()` directly without routing through `TenantScopedCacheService` OR carrying a `@TenantUnscopedCache("<justification>")` annotation with a non-empty justification.

The rule SHALL additionally block Spring `@Cacheable` / `@CacheEvict` / `@CachePut` annotations in all application classes. FABT uses zero Spring-cache-abstraction annotations today; blocking them proactively prevents a parallel caching pattern from emerging.

The `@TenantUnscopedCache` annotation justification SHALL be a non-empty string. A PR-template checkbox + CODEOWNERS auto-request SHALL fire on any new `@TenantUnscopedCache` introduction so the trade-off is reviewed at the point of declaration.

The full inventory of existing Caffeine cache fields covered by this rule (as of Phase C kickoff) is:

| File | Field / usage | Treatment |
|---|---|---|
| `shared/cache/TieredCacheService.java` | L1 cache map | Internal to wrapper; exempt |
| `shared/cache/CaffeineCacheService.java` | L1 cache map | Internal to wrapper; exempt |
| `auth/service/JwtService.java:claimsCache` | JWT claims by token hash | `@TenantUnscopedCache` (token hash is globally unique) |
| `notification/service/EscalationPolicyService.java:policyById` | policy by UUID, batch path | `@TenantUnscopedCache` (batch job cross-tenant snapshot resolution) |
| `notification/service/EscalationPolicyService.java:currentPolicyByTenant` | current policy per `(tenantId, eventType)` | `@TenantUnscopedCache` (key already carries tenantId structurally) |
| `shared/security/ApiKeyAuthenticationFilter.java:rateLimitBuckets` | Bucket4j per-API-key buckets | `@TenantUnscopedCache` (platform-admin API keys may be cross-tenant) |
| `auth/api/AuthController.java:mfaAttempts` | mfa-token JTI attempt counter | `@TenantUnscopedCache` (JTI is globally unique) |
| `auth/api/AuthController.java:mfaBlocklist` | mfa-token single-use blocklist | `@TenantUnscopedCache` (JTI is globally unique) |
| `auth/service/DynamicClientRegistrationSource.java:cache` | OAuth2 `ClientRegistration` per `{slug}-{provider}` | `@TenantUnscopedCache` (pre-auth; key carries tenant slug structurally) |
| `shared/security/KidRegistryService.java:tenantToActiveKidCache` | `tenantId → activeKid` | `@TenantUnscopedCache` (key IS tenantId; structurally isolated) |
| `shared/security/KidRegistryService.java:kidToResolutionCache` | `kid → (tenantId, keyGen)` | `@TenantUnscopedCache` (kid is platform-unique lookup) |
| `shared/security/RevokedKidCache.java:cache` | `kid → revoked?` | `@TenantUnscopedCache` (kid is platform-unique) |

New Caffeine fields introduced after Phase C land SHALL either (a) route through `TenantScopedCacheService` OR (b) carry `@TenantUnscopedCache` with a justification reviewed at the PR-template gate.

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

#### Scenario: Rule covers all 10 application-layer Caffeine fields
- **WHEN** the Family C rule scans the codebase
- **THEN** the 10 application-layer fields listed in the inventory table (JwtService, both EscalationPolicyService fields, ApiKeyAuthenticationFilter, both AuthController MFA fields, DynamicClientRegistrationSource, both KidRegistryService fields, RevokedKidCache) are each either routed through `TenantScopedCacheService` or annotated with a non-empty `@TenantUnscopedCache` justification
- **AND** scanning classes in `*.service`, `*.api`, `*.security`, `*.auth.*` surfaces new unannotated Caffeine fields introduced after Phase C lands

#### Scenario: Spring @Cacheable is blocked outright
- **GIVEN** a new service method is annotated `@Cacheable("foo")`
- **WHEN** the Family C rule runs
- **THEN** the build fails with a message directing the author to use `TenantScopedCacheService` or annotate with `@TenantUnscopedCache`

### Requirement: escalation-policy-service-cache-split
The system SHALL split `EscalationPolicyService`'s cache surface (per C3 LATENT fix) so that request-path callers use a tenant-composite-keyed cache while the batch-job path retains an unscoped-by-design cache for cross-tenant snapshot resolution.

Why the split (not a single composite key as originally drafted): `EscalationPolicyService.findByIdForBatch(UUID)` is called from `ReferralEscalationJobConfig` — a scheduled job that resolves policies across tenants in a single pass. The batch has no `TenantContext` and cannot manufacture one without breaking the snapshot semantics. A pure-composite rekey would break this path; two caches decouple request-path isolation from batch-path needs.

#### Scenario: Request-path callers hit the composite-keyed cache
- **GIVEN** a request bound to tenant A calls `policyByTenantAndId(p1)` (new method)
- **WHEN** the method runs
- **THEN** the effective cache key is `CacheKey(tenantA, p1)`
- **AND** a later request bound to tenant B asking for the same `p1` resolves to `CacheKey(tenantB, p1)` — different cache entry, no cross-tenant confusion

#### Scenario: Batch-path caller retains the UUID-keyed cache
- **GIVEN** the scheduled `ReferralEscalationJob` calls `findByIdForBatch(UUID)`
- **WHEN** the method runs
- **THEN** the effective cache key is the raw UUID (legacy `policyById` field)
- **AND** the field carries `@TenantUnscopedCache("batch job cross-tenant snapshot resolution")` so Family C rules accept it
- **AND** the batch path never appears on request surfaces (enforced by ArchUnit: `findByIdForBatch` may only be called from `@Scheduled` methods)

#### Scenario: Request-path ArchUnit rule rejects `findByIdForBatch`
- **GIVEN** a controller adds a call to `EscalationPolicyService.findByIdForBatch(uuid)`
- **WHEN** Family C rule runs
- **THEN** the build fails because `findByIdForBatch` is reserved for `@Scheduled` callers
- **AND** the author is directed to `policyByTenantAndId(p1)` instead

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

### Requirement: tenant-scoped-cache-invalidate-tenant
The system SHALL expose a `TenantScopedCacheService.invalidateTenant(UUID tenantId)` method that evicts every cache entry whose key begins with the given tenant's prefix, across every registered cache name. Called at tenant suspend / hard-delete (Phase F F4) and on demand by the platform-admin API.

The wrapper SHALL maintain an authoritative registry of cache names populated at `@PostConstruct` from `CacheNames.class` reflection — NOT lazily on first `put`. A lazy registry would silently no-op after JVM restart for tenants that haven't yet been written to, turning a 3am tenant-suspension-FSM page into "invalidation succeeded" with an empty iteration set. Eager seeding converts this failure mode into a bootstrap-time error: if `CacheNames` is empty or unreadable, the wrapper fails to start. The wrapper SHALL additionally expose a `fabt.cache.registered_cache_names` Micrometer gauge + an INFO-level startup log naming each seeded cache so operators can verify at a glance.

The `invalidateTenant` method SHALL be idempotent: a failed SCAN/UNLINK pass (network blip, Redis restart mid-batch, SIGTERM mid-iteration, backend crash) SHALL be safe to retry. Partial completion SHALL be reflected in the emitted audit row's per-cache eviction counts. The tenant-lifecycle FSM re-invokes `invalidateTenant` on state-transition replay (Phase F F4) — operators SHALL NOT have to reason about whether the last call finished.

#### Scenario: Suspending a tenant clears its cache entries
- **GIVEN** tenant A has 3 entries across 2 cache names
- **WHEN** `invalidateTenant(tenantA-uuid)` runs
- **THEN** subsequent `get()` calls under tenant A return cache miss for all 3 keys
- **AND** tenant B's entries in the same cache names are untouched

#### Scenario: invalidateTenant emits an audit row
- **GIVEN** `invalidateTenant(tenantA-uuid)` is called via the platform-admin API
- **WHEN** the call completes
- **THEN** an `audit_events` row is written with action `TENANT_CACHE_INVALIDATED` and the tenant_id + per-cache eviction counts in the details column

#### Scenario: Registry is seeded eagerly at startup, not lazily on first put
- **GIVEN** the wrapper has just started and no `put` has been called yet
- **WHEN** `invalidateTenant(tenantA-uuid)` runs for a tenant that has not yet written any entry
- **THEN** the wrapper iterates every `CacheNames` constant (not an empty set)
- **AND** returns zero evictions per cache without NPE
- **AND** emits an audit row recording the zero-eviction state so operator tooling can distinguish "successfully ran against an empty state" from "no-op because registry was empty"

#### Scenario: invalidateTenant is idempotent
- **WHEN** `invalidateTenant(tenantA-uuid)` is called twice in succession
- **THEN** the first call evicts N entries and emits an audit row with eviction count N
- **AND** the second call evicts 0 entries and emits an audit row with eviction count 0
- **AND** neither call throws

### Requirement: cache-service-evict-all-by-prefix
The `CacheService` interface SHALL expose `long evictAllByPrefix(String cacheName, String prefix)` returning the count of entries evicted. Both `CaffeineCacheService` and `TieredCacheService` SHALL implement it; the Redis L2 path (future) MUST use `SCAN MATCH <prefix>*` + `UNLINK` per batch, never `KEYS` or `DEL` (both are main-thread-blocking on large key counts per Redis Inc. guidance).

The Caffeine implementation SHALL filter `cache.asMap().keySet()` by prefix and invalidate each match. The Redis implementation (when wired per ADR shape 2 or 3) SHALL use `SCAN 0 MATCH "<prefix>*" COUNT 1000` iteratively with `UNLINK` per batch.

This API exists to support `TenantScopedCacheService.invalidateTenant` without either breaking the `CacheService` abstraction (reflection into the delegate would couple the wrapper to Caffeine) or duplicating per-tenant keyset state in the wrapper (stateful duplication breaks on JVM restart).

#### Scenario: Prefix-filter evicts only matching keys
- **GIVEN** a cache named `shelter-profile` contains keys `tenantA|s1`, `tenantA|s2`, `tenantB|s1`
- **WHEN** `evictAllByPrefix("shelter-profile", "tenantA|")` runs
- **THEN** the return value is `2`
- **AND** subsequent `get("shelter-profile", "tenantA|s1")` and `get("shelter-profile", "tenantA|s2")` return empty
- **AND** `get("shelter-profile", "tenantB|s1")` still hits

#### Scenario: Prefix-filter on empty cache returns 0
- **GIVEN** a cache name that has never been written to
- **WHEN** `evictAllByPrefix(cacheName, "tenantA|")` runs
- **THEN** the return value is `0` and no exception is thrown

### Requirement: tenant-scoped-cache-observability
The wrapper SHALL emit Micrometer counters `fabt.cache.get{cache,tenant,result}` and `fabt.cache.put{cache,tenant}` on every get/put operation. The `result` tag SHALL be one of `hit`, `miss`, `cross_tenant_reject`, `malformed_entry`. The `tenant` tag SHALL match the G4 OTel baggage key (`tenant`, NOT `tenant_id`).

Cardinality budget: ~N_tenants × N_caches × N_results × N_ops series. At 100 pooled tenants × 11 registered caches × 4 result values × 2 operations = ~8800 time-series maximum. Acceptable within Prometheus's practical per-metric-family ceiling; reviewable as tenant count grows past 500.

#### Scenario: Hit increments the hit counter with tenant tag
- **GIVEN** tenant A's request reads a cached key that exists under tenant A's envelope
- **WHEN** `get` runs
- **THEN** `fabt.cache.get{cache=<name>,tenant=<tenantA-uuid>,result=hit}` increments by 1

#### Scenario: Miss increments the miss counter
- **GIVEN** tenant A's request reads a key that does not exist
- **WHEN** `get` runs
- **THEN** `fabt.cache.get{cache=<name>,tenant=<tenantA-uuid>,result=miss}` increments by 1

#### Scenario: Cross-tenant read increments the reject counter
- **GIVEN** tenant B's request reads a key whose envelope is stamped tenant A
- **WHEN** `get` throws `CROSS_TENANT_CACHE_READ`
- **THEN** `fabt.cache.get{cache=<name>,tenant=<tenantB-uuid>,result=cross_tenant_reject}` increments by 1

### Requirement: reflection-cache-bleed-fixture
The project SHALL maintain a reflection-driven cache-bleed test fixture (per C5) that discovers every `@Cacheable`-annotated method and every `CacheService.get` / `TieredCacheService.get` call site, and for each site generates a parameterized test asserting `tenantA.write(k); tenantA.read(k)` returns a HIT (precondition), then `tenantB.read(k)` returns a cache miss (isolation assertion).

The fixture SHALL assert `discoveredSites.size() >= EXPECTED_MIN_SITES` (pinned to the concrete value at Phase C kickoff) and fail if reflection classloader misconfiguration produces a silent-empty discovery. This guards against the Reflections-library failure mode where an empty result masks itself as "no violations" (see `feedback_never_skip_silently.md`).

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
FABT uses zero 404/negative cache entries today (verified at Phase C kickoff). This requirement therefore ships as a **guardrail**, not a feature implementation: Family C ArchUnit SHALL reject `cacheService.put(…, null, …)` and `cacheService.put(…, Optional.empty(), …)` call sites outright. If a future path needs negative caching, it MUST route through a `TenantScopedCacheService.putNegative(String key)` method that applies the tenant prefix plus a `:404:` marker, keeping the negative entry tenant-scoped by construction. This prevents tenant A's 404 from ever masking tenant B's later create.

#### Scenario: Tenant A 404 does not mask tenant B create
- **GIVEN** tenant A queries for resource `r1` and receives 404, which is cached as a negative entry
- **WHEN** tenant B subsequently creates resource `r1` in its own tenant scope
- **THEN** tenant B's read of `r1` is a cache miss (not served by tenant A's negative entry)
- **AND** tenant B's read proceeds to the DB and returns the created resource

#### Scenario: Negative entry evicted on same-tenant write
- **GIVEN** tenant A has a negative cache entry for resource `r1`
- **WHEN** tenant A creates `r1` in its own tenant
- **THEN** the negative entry is evicted and subsequent read returns the created resource
