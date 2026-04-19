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

- **Negative-cache helper signature:** `putNegative(String key)` vs.
  `putNegative(String key, Duration ttl)` — decide when first caller
  appears. Zero callers today.
- **Redis ACL syntax:** the ADR (task 4.0) documents the POSTURE
  (single-tenant default, ACL-per-tenant for regulated), not the syntax.
  Actual Redis deployment is out of scope for Phase C.

## Task 4.1 warroom resolutions (2026-04-19 PM)

Skeleton-review warroom (Alex + Marcus + Sam + Riley + Jordan + Elena)
closed six remaining implementation decisions. All captured as additive
spec scenarios; no decisions above were reversed.

### D-C-8 — Eager registry seed, NOT lazy-on-first-put

**Decision:** `TenantScopedCacheService.registeredCacheNames` is seeded
at `@PostConstruct` from `CacheNames.class` reflection. The previously-
considered "populate on first put" pattern was a correctness bug: after
a JVM restart, `invalidateTenant(UUID)` for a tenant not yet written
would iterate an empty set and return 0 evictions silently — turning
the Phase F tenant-suspension FSM page at 3am into a false "succeeded"
signal.

**Observability:** wrapper also publishes `fabt.cache.registered_cache_names`
gauge + an INFO-level startup log enumerating each seeded name so
operators can verify on boot.

**Raised by:** Alex (architecture) + Jordan (SRE) independently during
skeleton review.

### D-C-9 — Cross-tenant-read audit uses REQUIRES_NEW

**Decision:** `CROSS_TENANT_CACHE_READ` audit rows are persisted via
`AuditEventPersister` injected directly (not via
`ApplicationEventPublisher`), wrapped in a small helper method with
`@Transactional(propagation = REQUIRES_NEW)`. This diverges from the
codebase's usual event-bus audit pattern.

**Why the divergence is justified:** the existing `AuditEventService`
`@EventListener` pattern is synchronous so the audit INSERT joins the
caller's transaction (documented at `AuditEventService.java:45-49`).
For normal audits that is a feature — an action that rolls back
shouldn't audit as having happened. For `CROSS_TENANT_CACHE_READ` it
is an anti-feature: an attacker who triggers a cross-tenant read in a
transactional endpoint and relies on the subsequent ISE to roll the
caller's tx back would erase the one audit signal proving the attempt
happened. REQUIRES_NEW cuts the audit loose so it survives caller
rollback.

**Normal audits** (`TENANT_CACHE_INVALIDATED` for `invalidateTenant`
calls) continue to use the event-bus pattern — they are operator-
initiated, not attacker-triggered, and the normal rollback-coupling
semantics are correct.

**Raised by:** Marcus (security) during skeleton review.

### D-C-10 — Prefix separator is `|`, not `:`

**Decision:** the tenant-prefix separator is `|` (pipe). Existing
call sites in `AnalyticsService` (lines 66, 94, 125) already use `:`
as an internal composite-key separator: `tenantId + ":" + from +
":" + to`. Colon would produce visually-confusing debug output like
`tenantA:tenantA:2026-04-01:2026-04-15`. Pipe produces
`tenantA|tenantA:2026-04-01:2026-04-15` — still shows the redundant
duplicate (flagged for task 4.b migration to strip), but unambiguous
at separator boundaries.

**Raised by:** Alex (architecture) during skeleton review.

### D-C-11 — IllegalStateException messages never carry UUIDs

**Decision:** all `IllegalStateException` and `IllegalArgumentException`
messages produced by the wrapper MUST use short action tags only
(`TENANT_CONTEXT_UNBOUND`, `CROSS_TENANT_CACHE_READ`,
`MALFORMED_CACHE_ENTRY`). UUIDs, keys, and payload fragments go to
audit rows and structured logs, never to exception messages.

**Why:** exceptions propagate through `GlobalExceptionHandler` into
HTTP response bodies. A leaky exception message turns an isolation
fault into an information disclosure. OWASP ASVS 5.0 §7.4.1 (error
handling) explicitly calls this out.

**Raised by:** Marcus (security) during skeleton review.

### D-C-12 — `CacheService.evictAllByPrefix` is the right API extension

**Decision:** extend `CacheService` with
`long evictAllByPrefix(String cacheName, String prefix)`. Caffeine
implementation filters `cache.asMap().keySet()` by prefix; future
Redis L2 implementation uses `SCAN MATCH <prefix>* COUNT 1000` + `UNLINK`
per batch.

**Why not alternatives:** (a) duplicating per-(tenant, cacheName)
keyset state inside the wrapper breaks on JVM restart + creates a
stateful wrapper that must be kept consistent with the underlying
cache; (b) reflecting into the Caffeine delegate couples the wrapper
to the impl detail, breaking the `CacheService` abstraction. The
interface extension is clean, Redis-ready per ADR shape 2, and makes
the wrapper stateless with respect to the underlying cache.

**Raised by:** Alex (architecture) during skeleton review.

### D-C-13 — Value stamp-and-verify is a write-side defence, separate from prefix

**Decision:** the `TenantScopedValue<T>(UUID tenantId, T value)`
envelope + on-read verification is a **second** isolation control,
not a replacement for the key prefix. Prefix defends the read side
(reader cannot guess another tenant's keys). Stamp-and-verify defends
the write side (a caller with wrong `TenantContext` bound can't
silently poison another tenant's keyspace). Both must fail for a
leak.

**Why it's load-bearing:** per Redis Inc.'s Feb 2026 multi-tenant-SaaS
post-mortem survey + OWASP ASVS 5.0 (May 2025), wrong-tenant-context-
on-write is the leading 2025-2026 cache-leak pattern, outranking
prefix-collision. Specifically names async-continuation context drift
and scheduled-job-forgot-to-bind as the failure modes we are
defending against.

**Raised by:** external-standards review during ADR amendment pass
(task 4.0b); pinned as decision here for cross-reference from spec.

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
