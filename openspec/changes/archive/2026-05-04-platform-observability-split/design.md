## Context

The /admin#observability tab was originally written when the
observability config was COC_ADMIN-scoped. G-4.4 (2026-04) migrated the
endpoint to PLATFORM_OPERATOR + `@PlatformAdminOnly` without migrating
the UI. The COC_ADMIN-facing tab now reliably 400s on save (no
X-Platform-Justification header). Two Playwright tests are stuck on
`test.fixme` because of this.

A separate diagnostic surfaced that 3 of the 7 config fields
(monitor_*_interval_minutes) are stored in JSONB but **never read at
runtime** — `OperationalMonitorService` uses `@Scheduled(fixedRate=...)`
literals. The tab silently lies: writes are accepted and persisted,
but cadence never changes.

Field-tier audit (warroom 2026-05-02):
- `temperature_threshold_f` — per-tenant, geographic, used by
  `OperationalMonitorService.checkTemperatureSurgeGap` line 171.
- `prometheus_enabled`, `tracing_enabled`, `tracing_endpoint` — JVM-level
  effects regardless of which tenant wrote them; tenant-scoping is
  cosmetic.
- `monitor_stale_interval_minutes`, `monitor_dv_canary_interval_minutes`,
  `monitor_temperature_interval_minutes` — cadence concerns belong at
  the platform tier (NOAA rate-limits, security SLO, scheduler
  infrastructure).

**Constraints:**
- `BatchJobScheduler` (existing) already implements dynamic
  `@Scheduled` replacement via `SchedulingConfigurer` + `TaskScheduler` —
  precedent for the OperationalMonitor refactor.
- `tenant.config` JSONB keys cannot be dropped immediately (live tenants
  in prod still write to them via cached old frontend bundles in some
  CDNs / browser caches). Backward-read is required for one full release.
- Platform-operator surface (`PlatformDashboard.tsx` +
  `platformActions.ts`) is config-driven; adding 6 new action cards is
  mechanical, but the `ActionCategory` enum needs a new `'observability'`
  value.

**Stakeholders:**
- COC admins lose visibility of fields they never could write anyway
  (post-G-4.4). Net positive — fewer broken UIs.
- Platform operators gain a coherent surface for the 6 platform-wide
  knobs.
- v0.55 release engineering — this change can ship in its own bundle
  (does not gate dv-policy-tenant-flag deploy).

## Goals / Non-Goals

**Goals:**
- The 3 monitor-interval fields actually take effect when written
  (proves the wiring; closes the silent-lies bug).
- COC admins manage `temperature_threshold_f` from the Surge tab
  (operator-natural location — surge thresholds belong with surge controls).
- Platform operators manage the 6 platform-wide fields from the
  existing Platform Dashboard (no new top-level UI).
- `observability.spec.ts:42, :83` move from `test.fixme` to passing.
- Audit trail captures every platform-config write with operator + before/after.

**Non-Goals:**
- Migrate every per-tenant `tenant.config` JSONB key to a platform table
  (only the 6 obsoleted ones; `dv_policy_enabled`, `hold_duration_minutes`,
  `features.reentryMode`, etc. stay where they are).
- Remove the per-tenant `tenant.config.observability` JSONB
  immediately. Backward-read for one release; column drop in v0.58+.
- Build a separate platform-observability frontend page. Action cards
  on the existing PlatformDashboard.tsx are sufficient.
- Rate-limit the new endpoints (Bucket4j is per-IP at filter level,
  not per-endpoint; consistent with the pre-existing posture for
  observability writes).
- Native-speaker i18n for the new Surge UI strings (AI-synthetic ES is
  acceptable, Maria reviews at the pre-deploy gate; pattern matches
  dv-policy-tenant-flag §8.2).

## Decisions

### D1 — Storage for platform-wide config

**Chosen:** New `platform_config` table, single row, JSONB column.

**Schema:**
```sql
CREATE TABLE platform_config (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config      JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by  UUID,  -- nullable; null on initial seed row
    CONSTRAINT platform_config_singleton CHECK (id = '00000000-0000-0000-0000-000000000001')
);
INSERT INTO platform_config (id, config) VALUES
    ('00000000-0000-0000-0000-000000000001', '{
        "prometheus_enabled": true,
        "tracing_enabled": false,
        "tracing_endpoint": "http://localhost:4318/v1/traces",
        "monitor_stale_interval_minutes": 5,
        "monitor_dv_canary_interval_minutes": 15,
        "monitor_temperature_interval_minutes": 60
    }'::jsonb);
```

The CHECK constraint enforces single-row semantics — no need for an
"environment" column, no risk of rows-per-env drift on deploy. Reads
are `SELECT config FROM platform_config WHERE id = '00...001'`.

**Alternatives considered:**
- `@ConfigurationProperties` reading `application.yml` only. **Rejected**
  — runtime changes would require a redeploy, defeating the goal of
  platform-operator-managed cadences.
- Reuse `tenant.config` with a magic "platform tenant" UUID. **Rejected**
  — pollutes the tenant table, breaks RLS expectations (every other
  query iterates real tenants), and Sam's runbook would have to
  document a phantom row.
- Spring Cloud Config Server. **Rejected** — out-of-process dependency
  for one row of config; massive over-engineering.

The CHECK-constrained singleton matches the simplicity of the "one row,
JSONB" pattern already used elsewhere in the codebase (e.g., the
`surge_event` active-row pattern).

### D2 — Dynamic `@Scheduled` for monitor intervals

**Chosen:** `SchedulingConfigurer` + `TaskScheduler` + `ScheduledFuture`
re-registration, mirroring `org.fabt.analytics.config.BatchJobScheduler`.

`OperationalMonitorService` becomes:
```java
@Configuration
public class OperationalMonitorService implements SchedulingConfigurer {
    private final Map<String, ScheduledFuture<?>> scheduled = new ConcurrentHashMap<>();
    private TaskScheduler taskScheduler;

    @Override
    public void configureTasks(ScheduledTaskRegistrar registrar) {
        this.taskScheduler = registrar.getScheduler();
        scheduleAll();  // initial registration from PlatformConfigService
    }

    public void rescheduleFromConfig() {
        // called by PlatformObservabilityController.update on successful PUT
    }

    private void scheduleAll() {
        var cfg = platformConfigService.get();
        scheduled.computeIfAbsent("stale", k -> taskScheduler.scheduleAtFixedRate(
            () -> checkStaleShelters(),
            Duration.ofMinutes(cfg.monitorStaleIntervalMinutes())));
        // ... same pattern for dv-canary + temperature
    }
}
```

**Alternatives considered:**
- "Check elapsed time" pattern: keep `@Scheduled(fixedRate=60_000)` and
  branch on `lastRunMs - now > intervalMs` inside the body. **Rejected** —
  fights Spring's scheduler model, makes test-time assertions brittle
  (every test would need to wait minimum 1 min for the body to even fire),
  and has worse performance (60× more no-op invocations per hour).
- `@Scheduled(fixedRateString = "${fabt.monitor.stale.interval-ms}")`.
  **Rejected** — reads from Spring property at startup, not runtime;
  changes require restart.
- A separate thread pool per monitor with sleep loops. **Rejected** —
  bypasses Spring's scheduler instrumentation (Micrometer task metrics,
  graceful shutdown, observability tags).

`BatchJobScheduler` precedent makes this the lowest-risk path — same
pattern that's been in production since v0.42 for the analytics jobs.

### D3 — Backward-read of obsoleted per-tenant fields

**Chosen:** `ObservabilityConfigService` keeps reading the 6 platform-wide
fields from `tenant.config` for one release. The `PUT /api/v1/tenants/{id}/observability`
endpoint is **removed**, so no new writes. Old written values stay
visible to GETs for one release (allows operators to verify the data
migration before dropping the columns).

In v0.58+ a separate change drops the JSONB keys from `tenant.config`
once `mvn test` + prod observation confirms zero reads of the old
locations.

**Alternatives considered:**
- Drop the JSONB keys immediately. **Rejected** — risk of breaking
  startup if any prod tenant has malformed JSONB in the obsoleted keys
  (defense-in-depth: read carefully, ignore errors, log).
- Migrate the values to `platform_config` once at deploy time. **Rejected** —
  conflicts: which tenant's `tracing_endpoint` wins if 3 tenants have
  3 different values? In prod (3 demo tenants), they all match by
  inspection, but the principle of least surprise says don't auto-merge.
  Platform operator sets the canonical value via the new endpoint
  post-deploy.

### D4 — Validation bounds + StructuredErrorException reuse

**Chosen:** Reuse the StructuredErrorException + ErrorCodes registry
introduced by dv-policy-tenant-flag §6.1. New error codes:
- `platform.observability.intervalOutOfRange` (interval ≤ 0 or > 1440)
- `tenant.surgeThreshold.outOfRange` (threshold < -50 or > 150°F)

Bounds:
- monitor intervals: 1..1440 minutes (cap at 24h to prevent operator
  typos that would silently disable monitoring)
- temperature_threshold_f: -50..150 (covers extreme weather; protects
  against literal-zero typo that would always trigger surge)

The frontend uses `parseTemperatureError` / `parseObservabilityError`
extracted helpers (mirrors `parseDvPolicyError` from dv-policy-tenant-flag
for codebase-no-RTL Vitest coverage).

### D5 — Audit emission

**Chosen:** New `PLATFORM_OBSERVABILITY_UPDATED` AuditEventType. Details
payload:
```json
{
  "field": "monitor_stale_interval_minutes",
  "old_value": 5,
  "new_value": 10,
  "value_changed": true,
  "outcome": "applied"
}
```

For `temperature_threshold_f` writes (the per-tenant path), reuse the
existing `TENANT_CONFIG_UPDATED` event type with `config_key:
"temperature_threshold_f"` (mirrors the dv-policy-tenant-flag pattern).
Adds `value_changed` boolean (warroom round 3 M3 lessons applied —
audit-replay tooling can filter idempotent re-sets).

### D6 — Frontend extraction pattern

**Chosen:** `SurgeTemperatureSettings` follows the DvPolicySettings
pattern exactly:
- Pure-helper extraction for Vitest coverage (`parseTemperatureError`)
- No-optimistic-update on write
- Modal-with-Escape + auto-focus-on-open (warroom round 3 H1+H2 lessons)
- data-testid on every interactive element

The 6 PlatformAction cards on `PlatformDashboard.tsx` follow the existing
pattern in `platformActions.ts` (config-driven, one entry per
field, no per-action React component).

## Risks / Trade-offs

- **Risk**: `OperationalMonitorService` refactor races with monitor
  invocations during the swap → orphaned `ScheduledFuture` keeps firing
  with old interval. → **Mitigation**: `rescheduleFromConfig()` calls
  `future.cancel(false)` (don't interrupt running task) before
  registering the new one. Test: IT that calls reschedule mid-flight
  and verifies new cadence.
- **Risk**: Platform operator types `monitor_temperature_interval_minutes:
  1` → 1440 NOAA fetches per day, exceeds API rate limit. → **Mitigation**:
  D4 bounds check rejects intervals < 1 minute. Document NOAA's
  recommended cadence in the platform action card description.
- **Risk**: Backward-read crosses a stale frontend cache → 6 obsoleted
  per-tenant writes go through the now-removed endpoint → 404 → user
  confusion. → **Mitigation**: 404 carries a structured message
  pointing to the platform dashboard. v0.58+ drops the JSONB keys; we
  accept the one-release awkwardness.
- **Trade-off**: New table + new controller + new service + UI surgery
  is a lot of moving parts for what looks like "make a save button work".
  Smaller fix would be to change the endpoint annotation back to
  COC_ADMIN. → **Why we chose the larger fix**: the COC_ADMIN-everywhere
  approach restores the silent-lies bug (3 fields stored but never read)
  and re-creates the per-tenant-cosmetic-but-actually-platform
  inconsistency. The bigger refactor is correct, not just bigger.
- **Trade-off**: Two new endpoints + two write surfaces means platform
  operators need to know "where do I configure X". → **Mitigation**:
  runbook section + the platform action card descriptions are the
  source of truth.

## Migration Plan

**Order of deploy (single bundle):**
1. Flyway V98 — `platform_config` table + initial-row seed.
2. Backend: new `PlatformObservabilityController`, new
   `TemperatureThresholdController`, refactored
   `OperationalMonitorService` reading from `PlatformConfigService`,
   removed `PUT /api/v1/tenants/{id}/observability`.
3. Frontend: new `SurgeTemperatureSettings` component, new platform
   action cards, removed `/admin#observability` tab.
4. Tests flip from `test.fixme` to active.

**Backward-compat:**
- Old written `tenant.config.observability.{prometheus_enabled, ...}` values
  remain readable (D3) but unreferenced. Platform operator confirms
  via dashboard that the platform-wide settings match expectations
  before any deploy verification gate clears.
- Service rollback (revert backend deploy) is fully safe — old code
  reads from per-tenant config which still exists.

## Open Questions

- **Q1 (Sam, runbook)**: Does v0.58+ JSONB-drop migration need to
  capture the existing per-tenant values into `platform_config` first,
  or is the runbook step "platform operator manually applies values via
  dashboard" sufficient? Current proposal: manual; Sam to confirm.
- **Q2 (Tomás, architecture)**: With this change there are now 3 patterns
  for "platform-wide singleton config" (`platform_user`, `platform_config`,
  the singleton row pattern). Worth extracting? Current proposal: defer
  to a v0.59+ ADR — premature abstraction over 3 instances.
- **Q3 (Marcus, security)**: PLATFORM_OPERATOR can self-disable
  prometheus + tracing, blinding the platform's own observability. Is
  that the intended threat model? Current proposal: yes — platform
  operator IS the platform's authority over its own observability.
  Audit trail captures the disablement so SOC can reconstruct.
- **Q4 (Riley, testing)**: Should the IT for "interval-actually-takes-effect"
  use a real time delay (slow test) or mock `TaskScheduler` (faster
  but less realistic)? Current proposal: mock `TaskScheduler` for
  the wiring assertion + a separate slower IT that runs the cycle
  once with a 1-minute interval to prove end-to-end. Two-tier coverage.
