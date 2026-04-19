# Design — Phase C (Cache isolation)

Warroom-validated design notes (2026-04-19). Read alongside
`specs/tenant-scoped-cache/spec.md` and `tasks.md` section 4.

## Why this file exists

Phase C implementation was gated on three BLOCKING design questions the
initial spec did not answer clearly. The warroom (Alex + Marcus + Jordan +
Sam) resolved all three; this file captures the rationale so a future
reviewer can see WHY the spec reads as it does without having to
re-derive.

## Decision log

### D-C-1 — Bean strategy: new bean, NOT `@Primary`

**Decision:** `TenantScopedCacheService` is a **distinct Spring bean**
named `tenantScopedCacheService`, injected where callers want tenant
scoping. The existing `CacheService` bean stays available for
annotated-unscoped callers.

**Why not `@Primary`:** the existing 7 call sites in `BedSearchService`,
`AnalyticsService`, and `ShelterService` already manually embed tenantId
in the cache key (e.g., `cacheKey = tenantId + ":" + from + ...`). A
`@Primary` replacement would silently double-prefix these keys —
`<tenant>:<tenant>:key` — so the wrapper would appear to work (no
exception) while actually populating a stale key set. Two-bean model
forces explicit migration per call site, catches double-prefix in code
review.

**Migration acceptance criterion:** every call site migrated from the
raw `CacheService` to `TenantScopedCacheService` MUST strip its caller-
side tenant prefix. Documented as task 4.b; verified in PR review.

### D-C-2 — `EscalationPolicyService` split instead of composite rekey

**Decision:** two caches, not one. `policyById` (UUID-keyed, annotated
unscoped, called only from `findByIdForBatch` reserved for `@Scheduled`)
plus new `policyByTenantAndId` (composite-keyed, request-path only).

**Why not a single composite-key cache (original C3 wording):** the
`ReferralEscalationJob` batch path resolves policies across tenants in
a single pass with no TenantContext bound. A pure-composite rekey would
either (a) break the batch path entirely or (b) require manufacturing
artificial tenant contexts inside the batch — which breaks the snapshot
semantics the batch relies on. Split is cleaner: one cache per access
pattern, Family C ArchUnit rule reserves the unscoped path for `@Scheduled`
callers so request paths can't accidentally use it.

**ArchUnit enforcement:** `findByIdForBatch` may only be called from
`@Scheduled`-annotated methods. Enforced as part of Family C (task 4.4).

### D-C-3 — Family C scope spans `*.service` + `*.api` + `*.security` + `*.auth.*`

**Decision:** the ArchUnit rule scans all four package families.

**Why:** the inventory at Phase C kickoff surfaced 10 application-layer
Caffeine fields (vs. 3 named in the original spec). Seven of those
live OUTSIDE `*.service`:

- `AuthController.mfaAttempts` + `mfaBlocklist` (`*.api`)
- `DynamicClientRegistrationSource.cache` (`*.auth.*`)
- `ApiKeyAuthenticationFilter.rateLimitBuckets` (`*.security`)
- `KidRegistryService.tenantToActiveKidCache` + `kidToResolutionCache` (`*.security`)
- `RevokedKidCache.cache` (`*.security`)

A rule limited to `*.service` would have silently allowed these seven
to drift. Expanded scope is one-line rule edit; full inventory is
pinned in `specs/tenant-scoped-cache/spec.md` table under the Family C
requirement.

### D-C-4 — Block Spring `@Cacheable` outright

**Decision:** Family C rule rejects `@Cacheable`, `@CacheEvict`,
`@CachePut` in all application classes.

**Why:** FABT has zero Spring-cache-abstraction usages today (verified
via grep). Allowing them creates a parallel caching pattern with its
own `CacheManager` + `CacheResolver` seams that would need a second
tenant-scoping story. Cheaper to forbid now (one ArchUnit rule) than
to support both.

### D-C-5 — Negative-cache is a guardrail, not a feature

**Decision:** no `putNegative` or `:404:` namespace needed at Phase C
kickoff; ship an ArchUnit rule that forbids `cacheService.put(…, null, …)`
and `Optional.empty()`-as-value call sites. Provide an unused helper
signature so a future caller has a tenant-scoped-by-construction path
available.

**Why:** FABT caches zero 404s today. The original spec (C6) was
written against a hypothetical. An ArchUnit rule is O(hours) to ship
and prevents the anti-pattern from being introduced; the "full
negative-cache feature" is O(days) and solves no current problem.

### D-C-6 — Observability tagging

**Decision:** emit `fabt.cache.get{cache,tenant,result}` + `fabt.cache.put{cache,tenant}`
Micrometer counters from `TenantScopedCacheService`. Tag name is
`tenant` (not `tenant_id`) to match G4 OTel baggage key `fabt.tenant.id`.

**Cardinality:** at 100 tenants × 10 cache names × 2 results = ~2000
series. Well inside Prometheus's practical cardinality ceiling for a
single metric family. Demo-scale is ~60 series.

### D-C-7 — Reflection silent-empty safeguard

**Decision:** `ReflectionDrivenCacheBleedTest` asserts
`discoveredSites.size() >= EXPECTED_MIN_SITES` and fails if the
Reflections library returns an empty set.

**Why:** prior Sam-pinned failure mode — classloader misconfiguration
causes Reflections to silently return `Set.of()`, which a naive
"iterate and assert" test reads as "no violations" (vacuous true). The
minimum-sites assertion converts the silent failure into a loud one.
EXPECTED_MIN_SITES is pinned to the concrete count at Phase C kickoff
(current inventory: ~7 non-Caffeine call sites + ~10 Caffeine fields =
~17 sites; freeze at the measured value).

## Non-decisions (defer to implementation phase)

- **Exact cache-name registry for `invalidateTenant`:** the wrapper
  needs to enumerate cache names to evict per tenant. Easiest
  implementation: `TenantScopedCacheService` maintains its own
  `Set<String> registeredCacheNames` populated on first `put` per name.
  Alternative: inject `CacheManager` and iterate. Pick at implementation
  time; both satisfy the spec.
- **Negative-cache helper signature:** `putNegative(String key)` vs.
  `putNegative(String key, Duration ttl)` — decide when first caller
  appears. Zero callers today.
- **Redis ACL syntax:** the ADR (task 4.0) documents the POSTURE
  (single-tenant default, ACL-per-tenant for regulated), not the syntax.
  Actual Redis deployment is out of scope for Phase C.

## Deferrals

- Standard-tier Redis deployment is `project_standard_tier_untested.md`
  — still deferred through Phase C. The wrapper works L1-only; L2 Redis
  wiring lands when the first regulated tenant signs up.
- Per-tenant cache statistics on a Grafana dashboard — useful but out
  of scope for Phase C. Metrics emit at task 4.a; dashboard is a Phase G
  (observability) item.

## Phase D interaction check

Phase D (tasks 5.1–5.10) flips URL-path-tenantId → `TenantContext`-sourced
tenantId on controller write paths. No current cache keys on
URL-path-tenantId (verified — all `tenantId.toString()` usages read
from `TenantContext`). Safe to land Phase C before Phase D; no
cache-invalidation gotcha on the transition.

## Phase F interaction check

Phase F (tasks 7.x, tenant lifecycle FSM) suspends / hard-deletes
tenants. `TenantScopedCacheService.invalidateTenant(UUID)` (task 4.1
above) is the hook Phase F suspension calls. Spec scenario "Suspending
a tenant clears its cache entries" covers the contract. No blocking
dependency; Phase F will wire the call when it lands.
