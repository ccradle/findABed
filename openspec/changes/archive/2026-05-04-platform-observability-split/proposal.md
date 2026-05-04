## Why

Diagnostic work for the dv-policy-tenant-flag warroom round 3 surfaced two
classes of problems with the existing /admin Observability tab:

1. **The endpoint is broken for its current UI surface.** G-4.4 migrated
   `PUT /api/v1/tenants/{id}/observability` from COC_ADMIN to PLATFORM_OPERATOR
   + `@PlatformAdminOnly` (X-Platform-Justification header required). The
   ObservabilityTab in /admin still exists for COC_ADMIN users, calls
   `api.put` with no justification header, and reliably 400s on every save.
   "Saved" toast never renders. Tests `observability.spec.ts:42` +
   `observability.spec.ts:83` failed for this reason — currently marked
   `test.fixme` pending this change.
2. **Three of the seven config fields are orphaned.** The "monitor interval"
   fields (`monitor_stale_interval_minutes`, `monitor_dv_canary_interval_minutes`,
   `monitor_temperature_interval_minutes`) are stored in `tenant.config` but
   the `OperationalMonitorService` reads `@Scheduled(fixedRate=300_000)` etc.
   as JVM-level literals — config writes are accepted but never affect
   runtime. Operators can be misled into thinking a cadence change took
   effect when it didn't.

Field-by-field audit:

- `temperature_threshold_f`: **tenant-specific** (per-CoC geographic surge
  threshold; Asheville's 32°F vs Wilmington's 38°F).
- `prometheus_enabled` / `tracing_enabled` / `tracing_endpoint`: **tenant-agnostic**
  (JVM-level Prometheus scrape, OTel exporter wiring). Currently per-tenant
  in the data model but JVM-level in actual effect — the inconsistency is a
  real bug.
- 3 monitor intervals: **tenant-agnostic** (NOAA rate-limit, security SLO
  cadence, scheduler infrastructure). Even if wired, they belong at the
  platform tier per the warroom analysis (2026-05-02).

## What Changes

- **NEW** `PUT /api/v1/tenants/{id}/temperature-threshold` (COC_ADMIN-scoped,
  no platform-justification header) for the one tenant-specific field.
- **NEW** `platform_config` storage (table or `@ConfigurationProperties` bean
  reading from `application.yml` + JSONB override) for tenant-agnostic
  observability settings.
- **NEW** `PUT /api/v1/platform/observability` (PLATFORM_OPERATOR + `@PlatformAdminOnly`
  + justification header) that writes the platform-level config. Replaces
  the per-tenant `PUT /api/v1/tenants/{id}/observability` for the 6
  platform-wide fields.
- **WIRED** `OperationalMonitorService` reads its 3 monitor interval values
  from `PlatformConfigService` instead of `@Scheduled` literals. Implementation
  follows the existing `BatchJobScheduler` precedent (`TaskScheduler` +
  dynamic `ScheduledFuture` re-registration), so platform-operator changes
  take effect within the next cycle without restart.
- **WIRED** `prometheus_enabled` / `tracing_enabled` / `tracing_endpoint` reads
  migrate from per-tenant `ObservabilityConfigService` to platform-level
  `PlatformConfigService`.
- **MOVED** `temperature_threshold_f` UI from `/admin#observability` to
  `/admin#surge` (operator suggestion 2026-05-02 — surge thresholds belong
  alongside surge activation controls).
- **MOVED** all 6 platform-wide config fields onto the existing Platform
  Operator Dashboard as PlatformAction cards.
- **REMOVED** the ObservabilityTab from `/admin` once both above migrations
  land (no remaining tab content).
- **DEPRECATED** `tenant.config.observability.{prometheus_enabled, tracing_enabled,
  tracing_endpoint, monitor_*_interval_minutes}` reads. Kept in the JSONB
  for backward-read so old config doesn't crash startup, but writes are
  rejected at the API boundary. Remove the JSONB columns in a follow-up
  v0.58+ once observed-zero-reads in prod for one full release.
- **BREAKING (operator-facing)**: COC_ADMINs lose write access to the 6
  platform-wide fields. They never reliably had write access (G-4.4 broke
  it), but the UI was visible. Now the UI is hidden + the endpoint stays
  PLATFORM_OPERATOR-only.

## Capabilities

### New Capabilities
- `platform-observability`: Platform-level observability configuration —
  Prometheus metrics on/off, OpenTelemetry tracing on/off + endpoint, and the
  three monitor cadences (stale-shelter, DV canary, temperature). All
  read by the JVM/scheduler at runtime. Writes are PLATFORM_OPERATOR +
  `@PlatformAdminOnly` + justification header. Storage: new `platform_config`
  table (single row) or `@ConfigurationProperties` reading
  `application.yml` overrides — design.md Decision D1 picks one.

### Modified Capabilities
- `dv-policy-tenant-flag`: No requirement change, but the StructuredErrorException +
  ErrorCodes pattern introduced there is reused for the new endpoints'
  validation errors (e.g., negative interval, threshold outside -50..150°F).
  No delta spec needed — pattern reuse only.
- `observability` (if a spec exists for it; check
  `openspec/specs/observability/spec.md`): the per-tenant
  `tenant.config.observability.{prometheus_enabled, tracing_enabled,
  tracing_endpoint, monitor_*_interval_minutes}` requirements move to
  `platform-observability`. The remaining tenant-specific
  `temperature_threshold_f` requirement stays. Delta spec captures the
  scope removal.

## Impact

**Backend code:**
- `org.fabt.observability.OperationalMonitorService` — switch from `@Scheduled`
  literal rates to `SchedulingConfigurer` + `TaskScheduler` (mirrors
  `org.fabt.analytics.config.BatchJobScheduler`).
- `org.fabt.observability.ObservabilityConfigService` — strip the 6
  platform-wide fields; keep only `temperature_threshold_f` and `noaaStationId`.
  Either delete the class entirely once `noaaStationId` finds another home,
  or rename to `TenantSurgeConfigService`.
- `org.fabt.observability.api.MonitoringController` — unchanged
  (already CoC-readable).
- `org.fabt.tenant.api.TenantController` — remove the
  `PUT /{id}/observability` method (callers move to the platform endpoint).
  Keep the `GET /{id}/observability` for the temperature-threshold read
  side, OR replace with `GET /{id}/temperature-threshold`.
- `org.fabt.tenant.api.TemperatureThresholdController` (NEW) — single PUT for
  the tenant-specific threshold.
- `org.fabt.platform.api.PlatformObservabilityController` (NEW) — `GET` +
  `PUT` for the 6 platform-wide fields.
- Backend audit: new `PLATFORM_OBSERVABILITY_UPDATED` AuditEventType +
  emission on the platform PUT.

**Backend storage:**
- New Flyway migration (V98 next free) for `platform_config` table OR a
  spring-properties-only approach. Decision D1 in design.md.
- Drop columns in v0.58+ (separate change) for the 6 obsoleted JSONB keys.

**Frontend code:**
- `frontend/src/pages/admin/tabs/ObservabilityTab.tsx` — DELETE (or gut
  to platform-operator-only banner with link to platform dashboard).
- `frontend/src/pages/admin/AdminPanel.tsx` — remove `'observability'`
  entry from `TABS` + `TAB_COMPONENTS`.
- `frontend/src/pages/admin/tabs/SurgeTab.tsx` — embed the new
  `SurgeTemperatureSettings` component (read+write threshold + read-only
  status banner from `MonitoringController`).
- `frontend/src/pages/admin/components/SurgeTemperatureSettings.tsx` (NEW)
  — mirrors the DvPolicySettings pattern (no-optimistic-update,
  parseDvPolicyError-style structured-error handling).
- `frontend/src/pages/platform/platformActions.ts` — add 6 PlatformAction
  cards under a new `'observability'` category for the platform fields.
  This may grow the PlatformDashboard categorization beyond the existing
  `'lifecycle' | 'operator' | 'system'` enum — add `'observability'`.

**Tests:**
- New IT for `PUT /api/v1/platform/observability` + `PUT /api/v1/tenants/{id}/temperature-threshold`.
- New IT verifying `OperationalMonitorService` actually reads the
  configured intervals (proves the wiring isn't ignored — tests for the
  bug we're fixing).
- New Vitest for `SurgeTemperatureSettings` (extracted helper +
  parseTemperatureError pattern from dv-policy-tenant-flag).
- Re-target `e2e/playwright/tests/observability.spec.ts:42, :83` from
  `test.fixme` to active — point at SurgeTab + the new endpoint.
- New Playwright spec for the platform-observability action cards on the
  Platform Operator Dashboard.

**Operator-facing:**
- Runbook update: "where do I configure tracing?" Answer: Platform Operator
  Dashboard, requires platform login + justification.
- CHANGELOG entry: BREAKING for operators who remember the old `/admin`
  Observability tab existed (it never worked post-G-4.4, but documenting
  the disappearance is honest).

**Deployment:**
- Forward-only Flyway migration if D1 picks the table approach. No
  rollback risk for the tenant.config keys (kept for backward-read).
- Service rollback (revert backend deploy) is fully safe — old code
  reads from per-tenant config which still exists.
