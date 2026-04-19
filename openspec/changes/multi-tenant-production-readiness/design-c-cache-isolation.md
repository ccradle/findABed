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

## Task 4.b warroom resolutions (2026-04-19 PM)

Plan-review warroom (Alex + Marcus + Sam + Riley + Jordan + Casey + Elena)
for the 9-site migration that drains `PENDING_MIGRATION_SITES`. All six
decisions are additive — no prior D-C-* decision is reversed.

### D-4.b-1 — Single PR, not staged

**Decision:** all 9 call sites migrate in one PR. Rejected alternatives:
two-wave (Analytics first, then BedSearch+Availability+Shelter) and three-
wave (one per module).

**Why:** Alex coupling finding — `BedSearchService.doSearch` and
`AvailabilityService.createSnapshot` share `CacheNames.SHELTER_AVAILABILITY`.
A staged migration would leave a writer on the old envelope format while a
reader expects the new one (or vice-versa), which the wrapper's
`MALFORMED_CACHE_ENTRY` guard fires on. Debugging that in prod under load is
strictly worse than one atomic PR. Migration code is mechanical; the PR is
reviewable by file-diff grouping (6 × Analytics method × same refactor, 2 ×
AvailabilityService + ShelterService evict-path, 1 × BedSearch).

**Raised by:** Alex (architecture).

### D-4.b-2 — `"latest"` constant for empty-key migrations

**Decision:** five sites produce an empty logical key after the caller-
side tenant prefix strip — they all migrate to a literal `"latest"`
constant as the logical key passed to the wrapper.

The five sites are:

1. `AvailabilityService.createSnapshot` — original key was `""` (stores a
   per-tenant "current-snapshot" pointer)
2. `ShelterService.evictTenantShelterCaches` — original key was `""`
   (targets the whole tenant's shelter listing)
3. `AnalyticsService.getDvSummary` — original key was `tenantId.toString()`
   (whole key was tenant discriminator; strips to empty)
4. `AnalyticsService.getGeographic` — same pattern, tenant-singleton cache
5. `AnalyticsService.getHmisHealth` — same pattern, tenant-singleton cache

**Why not alternatives:** (a) passing `""` produces `<tenant>|` keys that
Grafana + pg_stat_statements truncate into confusing `<tenant>|` orphans
because most cache-key dashboards filter on a minimum length; (b) adding a
`putCurrent(cacheName)` / `getCurrent(cacheName)` method pair to the
wrapper bloats the API surface for five callers; (c) compat shim for
existing code is unnecessary — none of the five paths have external
callers beyond their own service-layer wrappers (grep-verified).

**Post-warroom ratification 2026-04-19 night:** initial warroom wording
named only sites 1 + 2. During implementation of the AnalyticsService
slice, the author observed that sites 3-5 share the exact same post-
strip-empty-key shape (whole caller-side key was `tenantId.toString()`,
the wrapper's prefix now supplies the tenant discriminator, nothing else
remains). Alex ratified the extension to all 5 sites in the 4.b slice-1
review; rationale and forbidden-alternatives reasoning apply uniformly.

**Raised by:** Sam (performance observability review); extension
ratified by Alex (architecture) during 4.b slice-1 warroom.

### D-4.b-3 — Keep 2 explicit evicts in ShelterService (reject
`invalidateTenant` refactor)

**Decision:** `ShelterService.evictTenantShelterCaches` continues to call
two explicit `evictAllByPrefix` invocations against
`SHELTER_PROFILE` + `SHELTER_AVAILABILITY` — NOT a single
`TenantScopedCacheService.invalidateTenant(tenantId)` call.

**Why not the refactor:** Alex blocker — `invalidateTenant` iterates all
11 registered cache names. Calling it from a shelter-specific code path
evicts 9 unrelated caches (JWT claims, escalation policies, MFA tokens,
etc.) which:

1. Amplifies the evict cost 5.5× (2 → 11 caches)
2. Spams the `TENANT_CACHE_INVALIDATED` audit log with rows whose
   `details.trigger = "shelter update"` — confuses incident forensics
   since the audit surface currently reserves `TENANT_CACHE_INVALIDATED`
   for tenant-lifecycle FSM actions (Phase F F4: suspend / hard-delete)
3. Semantic pollution — a shelter edit should not walk the same code path
   as a tenant suspension

`invalidateTenant` stays reserved for Phase F lifecycle paths. The
`ShelterService.evictTenantShelterCaches` method keeps explicit evicts and
lists the 2 cache names in a Javadoc so the next engineer sees the
constraint.

**Raised by:** Alex (architecture); seconded by Marcus (audit-surface
hygiene).

### D-4.b-4 — BedSearch DB-floor measurement via pg_stat_statements

**Decision:** ship `docs/performance/probe-bedsearch-4b.sql` — a 100-call
pg_stat_statements harness that measures the DB-side floor latency of
`BedAvailabilityRepository.findLatestByTenantId` (the recursive skip-scan
BedSearch issues on cache miss). Harness exercises the SQL directly via
`PREPARE`/`EXECUTE` in psql, NOT through the wrapper. Includes an initial
fingerprint-confirmation step so the aggregate stats can be trusted.

**Why the harness is a floor measurement, not an A/B/C wrapper
comparison:** raised by Sam in the post-commit warroom (2026-04-19
night). The earlier draft framed scenarios as "pre-migration / post-
migration cold / post-migration warm" but the DO-block exercised
raw SQL bypassing Spring — scenarios B and C measured identical paths,
not wrapper effects. Reframed to measure the DB floor only. The wrapper
itself is exercised by `TenantScopedCacheServiceUnitTest`,
`Task4bCacheHitRateTest`, and `Tenant4bMigrationCrossTenantAttackTest` —
three test surfaces covering unit contract, put→get key stability, and
cross-tenant envelope rejection respectively.

**Why BedSearch-only:** Sam scope — BedSearch is the 1k-QPS hot path per
the v0.45.0 production load profile. Analytics endpoints are cold-path
(admin-dashboard refreshes every ~30s), SQL-dominated (95%+ of method
time is aggregation), and the cache is secondary. A DB-floor harness on
6 analytics methods is 600 probe runs for zero additional signal.

**Interpretation:** `mean_exec_time` is the floor BedSearch pays on cache
miss. Compare against prod-observed p95 at `/api/v1/queries/beds`. If
prod p95 sits within 1.2× of `floor × cache-miss-rate`, the wrapper is
doing its job + latency is DB-dominated. If prod p95 >> that envelope,
investigate app-side cost (JDBC, Spring handler) rather than the cache
layer.

**Harness:** `docs/performance/probe-bedsearch-4b.sql` per
`feedback_pgstat_for_index_validation.md` canonical pattern.

**Raised by:** Sam (performance); reframed by Sam during post-commit
warroom review.

### D-4.b-5 — Riley test matrix: 1 parametrized attack × 8 caches + 1
hit-rate sanity × 10 sites

**Decision:** two parametrized integration-test classes:

**a) `Tenant4bMigrationCrossTenantAttackTest`** — 1 test method with
`@MethodSource` producing 8 rows, one per cache name written by a
migrated site:

- `CacheNames.SHELTER_PROFILE`
- `CacheNames.SHELTER_AVAILABILITY`
- `CacheNames.ANALYTICS_UTILIZATION`
- `CacheNames.ANALYTICS_DEMAND`
- `CacheNames.ANALYTICS_CAPACITY`
- `CacheNames.ANALYTICS_DV_SUMMARY`
- `CacheNames.ANALYTICS_GEOGRAPHIC`
- `CacheNames.ANALYTICS_HMIS_HEALTH`

Each row: `TenantContext.callWithContext(TENANT_A, () -> put(cacheName,
"k", v))`, switch to tenant B, raw-`CacheService`-read the tenant-A-
prefixed key (via reflection-access to the delegate bean to bypass the
wrapper's prefix on the read side), assert `CROSS_TENANT_CACHE_READ` is
thrown + `audit_events` row persists (visible under
`TenantContext.callWithContext(TENANT_B, ...)` wrap for the count per
Phase B V69 FORCE RLS). Runs inside a `TransactionTemplate` to verify
REQUIRES_NEW survives rollback.

**b) `PostMigrationCacheHitRateTest`** — 1 test method × 10
`@MethodSource` rows, one per migrated method. Each row: warm cache with
a put under tenant A, assert same-key same-tenant get returns HIT (not
MISS). Catches the regression where migration drift produces different
key strings on `put` vs. `get` paths (e.g., `toString()` drift on
composite keys, accidentally not stripping a caller-side prefix on one
side).

**Why parametrized and not per-method classes:** 18 separate test files
for 18 site-pairs creates noise; the `@MethodSource` pattern documents
the matrix in one place and any future migrated site adds one row, not
one file.

**Raised by:** Riley (QA).

### D-4.b-6 — Three Prometheus alert rules in
`fabt-cross-tenant-security.yml`

**Decision:** `deploy/prometheus/alert-rules/fabt-cross-tenant-security.yml`
gains three new rules (co-located with the v0.39.0 cross-tenant-isolation
rules so operators see them as one family):

1. **CRITICAL** — `sum by (tenant) (rate(fabt_cache_cross_tenant_reject_total[5m])) > 0`
   — ANY cross-tenant cache-read rejection page the on-call. Justified:
   this counter fires only on the wrapper's value-stamp-and-verify
   rejection path, which should be physically impossible under correct
   `TenantContext` discipline. Non-zero = something else is wrong (async
   continuation context drift, scheduled-job-forgot-to-bind, attacker).
2. **WARN** — `sum (rate(fabt_cache_malformed_entry_total[15m])) > 0` —
   a raw-`CacheService.put` wrote a non-envelope payload that a wrapper
   read later fetched. Should be zero once 4.b lands. Non-zero signals
   a caller that bypassed the wrapper on `put`.
3. **WARN** — per-cache hit-rate drop > 50% vs 7-day moving average —
   `(rate(fabt_cache_get_total{result="miss"}[1h]) / rate(fabt_cache_get_total[1h])) > 2 * avg_over_time(...7d)`.
   Catches a migration that landed but broke the key — wrapper is
   working, cache is present, but `put`-key and `get`-key diverged.

**Why the three, not one:** Jordan (SRE) scope — cross-tenant-reject is
a correctness signal (attacker or bug) and pages. Malformed-entry is a
data-discipline signal and warns. Hit-rate drop is a performance signal
and warns. Three levels = three different oncall behaviours.

**Raised by:** Jordan (SRE).

### D-4.b-7 — Release-notes title + Casey legal-scan posture

**Decision:** `v0.47.0` CHANGELOG [Unreleased] entry headline:

> **v0.47.0 — Phase C completes: cache isolation active across all
> application call sites**

Body lists the 4 shipped spec requirements (tenant-scoped-cache-service,
tenant-scoped-cache-value-verification, cache-service-evict-all-by-prefix,
tenant-scoped-cache-observability), notes zero end-user-visible change,
notes the `PENDING_MIGRATION_SITES` allowlist-drain as the release gate.

**Casey legal-scan posture:** avoid "compliant", "guarantees",
"equivalent to", "compliance-ready". Prefer "active", "in place",
"tenant-scoped", "across all call sites" — verifiable statements about
the code, not quasi-legal claims. Per
`feedback_legal_scan_in_comments.md`: the CI legal scan is context-blind
and will flag CHANGELOG entries using any forbidden phrase even if
surrounded by qualifiers.

**Raised by:** Casey (legal review).

### Alex coupling finding — BedSearch + Availability share a cache

`BedSearchService.doSearch` reads from `CacheNames.SHELTER_AVAILABILITY`;
`AvailabilityService.createSnapshot` writes to it. The two live in
different service classes but share one cache namespace. Migrating one
without the other would (under the wrapper) produce
`MALFORMED_CACHE_ENTRY` on every read — reader expects the envelope,
writer still writes raw values.

**Mitigation:** single-PR migration (D-4.b-1). This finding is the
load-bearing reason for D-4.b-1; documented here so a future reviewer
doesn't re-litigate "why not staged" without seeing the coupling.

### Marcus new surface — invalidateTenant registry + prefix-scan risk

`TenantScopedCacheService.invalidateTenant` iterates the 11 eagerly-seeded
cache names and calls `CacheService.evictAllByPrefix` on each. For the
current Caffeine L1 implementation this is safe (filters `keySet()` in
memory). For the future Redis L2 implementation, `SCAN MATCH <prefix>*
COUNT 1000` returns keys with the tenant UUID as the first token — an
attacker with Redis read access could enumerate a tenant's cache
footprint before the `UNLINK` pass completes.

**Mitigation:** documented as an attack surface in the ADR (task 4.0b
§"Cached-value tenant verification"). The on-read verification (D-C-11
envelope check) catches a stolen cache value even if the attacker
reads it directly — they can see WHICH keys exist but cannot USE a read
value without a matching `TenantContext`. Additional physical mitigation
lands when L2 Redis wires up (ADR shape 2 or 3): Redis ACL per-tenant
OR per-tenant logical DB.

**Raised by:** Marcus (security).

### Jordan deployment concern — three alerts require Alertmanager routing

The three new alert rules (D-4.b-6) need routing entries in
`deploy/prometheus/alertmanager.yml`. CRITICAL routes to pagerduty
(existing); WARN routes to `#fabt-oncall-warn` Slack (existing). No new
infrastructure; Jordan confirms the routing table already handles labels
used by these rules.

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
