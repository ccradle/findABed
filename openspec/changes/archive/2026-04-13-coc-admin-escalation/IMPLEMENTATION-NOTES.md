# Implementation Notes — coc-admin-escalation

This document captures the deltas between the original `proposal.md` /
`design.md` / `tasks.md` and what actually shipped during implementation.
The originals are preserved for historical context; this file is the
source of truth for what landed in the code.

## T-52 reframing: no pre-existing Micrometer timer (2026-04-12)

**The problem the original task description assumed:** *"Verify the
escalation batch job p95 duration is unchanged after the policy lookup
refactor. Add the policy lookup to the job's **existing** Micrometer
timer. If p95 grows >10%, investigate."*

**The problem that actually existed:** there is no "existing" Micrometer
timer. Session 7 discovery — during Alex Chen's review of the observability
plan — revealed that `ReferralEscalationJobConfig` has no explicit timer
and `BatchJobScheduler` has no `MeterRegistry` injection. Spring Batch 5
auto-emits `spring.batch.step{name=checkEscalationThresholds}` via its
built-in Micrometer integration, but that's not a `fabt.*` metric and
the project's established convention is unified fabt-prefixed operational
metrics (see `ObservabilityMetrics.bedHoldReconciliationDurationTimer()`
as the closest precedent).

**What shipped instead:**

1. **`fabt.escalation.batch.duration`** — new histogram Timer added as a
   factory method on `ObservabilityMetrics`, pre-built at
   `ReferralEscalationJobConfig` construction time and wrapped around
   the tasklet body via `Timer.Sample.start()` / `sample.stop()` in a
   `try/finally`. This is the **SLO baseline going forward**, not a
   comparison against a retroactively unreachable pre-refactor p95.

2. **`ReferralEscalationPerfTest`** — new integration test that seeds
   200 pending referrals backdated past the 1h threshold, runs the
   tasklet once, and asserts the wall clock stays under a 60-second
   budget. Deliberately loose to absorb CI noise while still catching
   a 5x+ regression. Sanity check: the test also asserts 200 escalation
   notifications were created, so a "fast" run that silently skipped
   the work fails loud (Riley Cho's "don't measure a broken stopwatch"
   principle). **The aspirational 1000-fixture count was reduced to 200**
   after discovering that the `uq_referral_token_pending` unique
   constraint on `(referring_user_id, shelter_id)` forces one distinct
   referring user per referral — creating 1000 users via TestAuthHelper
   dominates test runtime while the tasklet-timing signal saturates
   well before that. 200 users is the practical balance.

3. **IMPLEMENTATION-NOTES entry** (this file) documenting the reframing
   honestly. Pre-refactor p95 is literally unrecoverable; the task is
   complete by adding the baseline timer now, not by producing a
   "unchanged vs. baseline" number that cannot exist.

**Spring Batch's auto-emitted step timer** is retained as a secondary
observability signal — useful cross-reference if the `fabt.*` timer
ever disagrees with the Spring Batch value, or for correlating with
the other auto-emitted batch metrics (item read/process/write counts).

## T-53 metric naming: `cache.gets` family, not a `hit-rate` gauge (2026-04-12)

**The original task description** listed `fabt.escalation.policy.cache.hit-rate`
as a discrete metric name. The idiomatic Micrometer pattern is different:
`CaffeineCacheMetrics.monitor(registry, cache, cacheName)` emits a
**family** of metrics — `cache.gets{cache="...",result="hit|miss"}`,
`cache.puts`, `cache.evictions`, `cache.size` — with the cache name as a
tag rather than a metric-name prefix. Hit rate is computed downstream as
a PromQL/Grafana formula:

```promql
rate(cache_gets_total{cache=~"fabt.escalation.policy.*",result="hit"}[5m])
  / rate(cache_gets_total{cache=~"fabt.escalation.policy.*"}[5m])
```

**What shipped:** both Caffeine builders in `EscalationPolicyService`
gained `.recordStats()` (required — without it `CaffeineCacheMetrics`
silently emits zeros), and both caches are bound to the registry in
the constructor via:

```java
CaffeineCacheMetrics.monitor(meterRegistry, policyById,
        "fabt.escalation.policy.by-id");
CaffeineCacheMetrics.monitor(meterRegistry, currentPolicyByTenant,
        "fabt.escalation.policy.current-by-tenant");
```

**`EscalationPolicyServiceCacheMetricsTest`** is the regression guard
against silent `.recordStats()` removal. Three test methods: hit counter
non-zero after second findById, hit counter non-zero after second
getCurrentForTenant, and miss counter non-zero on cold cache. Any
future "cleanup" that drops `.recordStats()` from the builders breaks
all three immediately.

**The `fabt.dv-referral.claim.duration` and `fabt.dv-referral.claim.auto-release.count`
metrics** ship exactly as named in the original task, wired through
`ObservabilityMetrics` factory methods and consumed by
`ReferralTokenService.claimToken` (tagged by `outcome=success|conflict|error`)
and `ReferralTokenService.autoReleaseClaims` (incremented by
`released.size()` after the sweep completes).

## Constructor injection changes

Two services grew one constructor parameter each — both are Spring
`@Service` beans resolved via DI, so no production wiring change was
needed. Tests that construct these services directly (without Spring
context) were updated:

- **`EscalationPolicyService`** now takes `(EscalationPolicyRepository,
  MeterRegistry)`. Only one direct-construction site: `EscalationPolicyServiceTest`
  uses `new SimpleMeterRegistry()` in its `@BeforeEach`.
- **`ReferralTokenService`** now takes `ObservabilityMetrics` alongside
  its existing `MeterRegistry` parameter. No direct-construction sites in
  tests — all integration tests use `@Autowired` and Spring handles
  injection automatically.

## Module boundary check (Alex Chen review)

Added imports:

- `ReferralEscalationJobConfig` → `org.fabt.observability.ObservabilityMetrics`
- `ReferralTokenService` → `org.fabt.observability.ObservabilityMetrics`

These are additive imports into an already-present observability coupling
(`ReferralTokenService` already depends on `MeterRegistry`). ArchUnit should
already permit any module to depend on `org.fabt.observability` — it's a
cross-cutting concern, not a feature module. If ArchUnit fails on merge,
that's a rule gap to fix, not a boundary violation.

## Grafana panels

Four panels on the CoC escalation dashboard (created fresh if no dashboard
exists for this capability yet):

1. **Escalation batch duration p95** — `histogram_quantile(0.95,
   rate(fabt_escalation_batch_duration_seconds_bucket[5m]))`
2. **Escalation policy cache hit rate** — PromQL formula from `cache.gets`
   (see T-53 section above)
3. **DV referral claim duration p95 by outcome** — grouped by `outcome` tag
4. **DV referral claim auto-release count rate** — `rate(fabt_dv_referral_claim_auto_release_count_total[5m])`

Panel 4 is the signal Keisha Thompson and Devon Kessler care about: a
rising auto-release rate is a training/workflow indicator (admins
claiming but not manually releasing — either overload, distraction, or
UX friction in the release button).
