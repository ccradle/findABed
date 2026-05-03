# Tasks — platform-observability-split

## 0. Pre-flight

- [ ] 0.1 Branch off main in both repos: `feature/platform-observability-split` (already exists in docs repo). Create matching branch in `finding-a-bed-tonight/`. Per `feedback_branch_correct_repo`.
- [ ] 0.2 Verify the dev backend can be restarted without --fresh (V97 already applied; V98 is additive). Run `./dev-start.sh stop && ./dev-start.sh --nginx` to confirm before edits.
- [ ] 0.3 Read `BatchJobScheduler.java` end-to-end before drafting `OperationalMonitorService` refactor — that's the canonical pattern.

## 1. Backend storage — V98 + PlatformConfigService

- [x] 1.1 Pick the next free Flyway version (V97 ends dv-policy-tenant-flag; V98 next). Migration: `V98__platform_config.sql` per design D1 (singleton table + CHECK + seeded defaults).
- [x] 1.2 Create `org.fabt.platform.config.PlatformConfig` record with the 6 fields.
- [x] 1.3 Create `org.fabt.platform.config.PlatformConfigService` with `get()` + `update(PatchRequest)`. Single-row read; partial-merge update.
- [x] 1.4 IT for V98: seeded defaults present after migration; CHECK constraint rejects second-row INSERT.
- [x] 1.5 Unit tests for `PlatformConfigService`: get returns defaults, update merges, validation throws StructuredErrorException on out-of-range intervals.

## 2. Backend endpoint — PlatformObservabilityController

- [x] 2.1 Create `org.fabt.platform.api.PlatformObservabilityController` with `GET` + `PUT` per spec.
- [x] 2.2 `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` on both methods.
- [x] 2.3 `@PlatformAdminOnly(reason=..., emits=PLATFORM_OBSERVABILITY_UPDATED)` on the PUT.
- [x] 2.4 Validation per design D4 — bounds + structured error codes. New `ErrorCodes.PLATFORM_OBSERVABILITY_INTERVAL_OUT_OF_RANGE` + `PLATFORM_OBSERVABILITY_TRACING_ENDPOINT_MALFORMED`.
- [x] 2.5 Add `PLATFORM_OBSERVABILITY_UPDATED` to `AuditEventType` enum.
- [x] 2.6 Audit emission per design D5: one row per changed field, includes `value_changed`.
- [x] 2.7 Trigger `OperationalMonitorService.rescheduleFromConfig()` on successful update of any monitor interval (the prom/tracing fields don't need reschedule).
- [x] 2.8 IT covering: GET happy-path, PUT happy-path, validation rejection, missing-justification 400, COC_ADMIN forbidden 403, idempotent re-set audit.

## 3. Backend — OperationalMonitorService refactor (D2)

- [x] 3.1 Convert `OperationalMonitorService` to `implements SchedulingConfigurer`, follow `BatchJobScheduler` line-by-line.
- [x] 3.2 Replace `@Scheduled(fixedRate=300_000)` etc. with dynamic `taskScheduler.scheduleAtFixedRate` calls inside `configureTasks()`.
- [x] 3.3 Add `rescheduleFromConfig()` public method — cancel old `ScheduledFuture` (`cancel(false)` non-interrupting) + register new one.
- [x] 3.4 Inject `PlatformConfigService` for cadence reads.
- [x] 3.5 Update existing IT for `OperationalMonitorService` to assert intervals come from `PlatformConfigService` (not hardcoded literals).
- [x] 3.6 New IT: change platform config interval → call rescheduleFromConfig() → assert new `ScheduledFuture` registered with new cadence (mock TaskScheduler per design Q4 tier 1).
- [ ] 3.7 New slow IT (tag with `@Tag("slow")`): integration smoke that sets stale interval to 1 min, waits 70s, verifies the monitor body fired (per design Q4 tier 2). **NOT DONE.** Was previously checked but no `@Tag("slow")` annotation exists in the test tree (only the phrase in a Javadoc comment). §15.3 captures this as an out-of-scope follow-up; tracked there.

## 4. Backend — Prometheus + tracing wiring migration

- [x] 4.1 Find every read of `ObservalityConfigService.tracingEnabled(tenantId)`, `prometheusEnabled(tenantId)`, `tracingEndpoint(tenantId)`. Migrate to `PlatformConfigService.get().tracingEnabled()` etc.
- [ ] 4.2 Strip the per-tenant getter methods from `ObservabilityConfigService`. Rename to `TenantSurgeConfigService` (only `temperature_threshold_f` + `noaaStationId` remain) — or document why we keep the original name. **NOT DONE.** The `ObservabilityConfig` record still declares + parses `prometheusEnabled`, `tracingEnabled`, `tracingEndpoint`, `monitorStaleIntervalMinutes`, `monitorDvCanaryIntervalMinutes`, `monitorTemperatureIntervalMinutes`. Callers can still reach them via `getConfig(tenantId).tracingEnabled()` etc. Will be redone in this pass.
- [ ] 4.3 Update OTel exporter wiring to honor the platform-level `tracingEnabled` flag at runtime (toggle exporter on/off without restart, mirroring how the Spring profile-based wiring currently works). **Deferred:** Spring Boot starter does not natively support runtime toggle (web search confirmed). Requires custom `SpanExporter` wrapper.
- [ ] 4.4 Verify Prometheus metrics endpoint respects platform-level `prometheus_enabled`. Currently tested per-tenant; update test to platform-level.
- [ ] 4.5 IT: toggle tracing_enabled via PUT → assert next OTel span IS / IS NOT exported (use `InMemorySpanExporter`).

## 5. Backend — temperature-threshold split

- [x] 5.1 Create `org.fabt.tenant.api.TemperatureThresholdController` with `PUT /api/v1/tenants/{id}/temperature-threshold` (COC_ADMIN scope, no platform-justification header).
- [x] 5.2 Validation: -50 ≤ threshold ≤ 150, structured error code `tenant.surgeThreshold.outOfRange`.
- [ ] 5.3 Audit emission: `TENANT_CONFIG_UPDATED` with `config_key: "temperature_threshold_f"` (mirrors dv-policy-tenant-flag pattern). **NOT DONE.** TemperatureThresholdController.update() shipped without an `eventPublisher.publishEvent(...)` call; lines 105-109 carry an in-progress comment instead. Spec REQUIREMENT explicitly mandates the audit. Will be added in this pass.
- [ ] 5.4 IT: COC_ADMIN happy path, validation rejection, COORDINATOR forbidden, OUTREACH forbidden, cross-tenant probe 404 (TenantPathGuard) with audit. **PARTIAL.** Existing test only covers 4 scenarios (default GET, PUT happy, range rejection, cross-tenant 404). Missing COORDINATOR forbidden, OUTREACH forbidden, audit-row assertion on cross-tenant probe, and error-code assertion on out-of-range. Will be expanded in this pass.
- [x] 5.5 Remove `PUT /api/v1/tenants/{id}/observability` from `TenantController` entirely (the 6 platform-wide fields move to the platform endpoint). Keep the GET for now — backward-read per design D3.
- [x] 5.6 Fix: TemperatureThresholdController write path preserves existing `observability` JSONB keys (doesn't overwrite with only `temperature_threshold_f`).

## 6. Frontend — SurgeTemperatureSettings component

- [ ] 6.1 Create `frontend/src/pages/admin/components/SurgeTemperatureSettings.tsx` mirroring DvPolicySettings pattern (no-optimistic-update, structured-error parsing, useRef + useEffect for modal focus, Escape closes modal).
- [ ] 6.2 Read state via `GET /api/v1/tenants/{id}/observability` (existing read endpoint, returns full JSONB; we read `temperature_threshold_f`). Wait until §5 lands so the GET stays alive.
- [ ] 6.3 Read temperature status via `GET /api/v1/monitoring/temperature` (already CoC-readable per `MonitoringController`).
- [ ] 6.4 Save via the new `PUT /api/v1/tenants/{id}/temperature-threshold`.
- [ ] 6.5 Extract `parseTemperatureError` pure helper for Vitest coverage (mirrors `parseDvPolicyError`).
- [ ] 6.6 EN i18n strings (label, save-error, threshold-out-of-range, status-banner). ES strings AI-synthetic; mark provenance per `reference_es_json_ai_synthetic_reviewed`. Maria reviews at §13.
- [ ] 6.7 6 data-testids: `surge-temperature-settings`, `temperature-threshold-input`, `temperature-status-banner`, `temperature-save-button`, `temperature-error`, `temperature-saved-toast`.

## 7. Frontend — embed in SurgeTab

- [ ] 7.1 Read existing `frontend/src/pages/admin/tabs/SurgeTab.tsx`.
- [ ] 7.2 Embed `<SurgeTemperatureSettings />` at the appropriate vertical location (above or below existing surge controls — operator UX call; default: ABOVE the activate/deactivate controls so operators see the threshold context first).
- [ ] 7.3 Ensure the section is collapsible if SurgeTab is becoming crowded; otherwise just inline.

## 8. Frontend — Platform Action cards for the 6 platform fields

- [x] 8.1 Add `'observability'` to the `ActionCategory` type union in `frontend/src/pages/platform/platformActions.ts`.
- [ ] 8.2 Add 6 entries to `PLATFORM_ACTIONS`:
   - `observability-prometheus-toggle` (POST, dangerLevel: safe)
   - `observability-tracing-toggle` (POST, dangerLevel: safe)
   - `observability-tracing-endpoint` (PUT, dangerLevel: destructive — bad endpoint can blackhole spans)
   - `observability-stale-interval` (PUT, dangerLevel: safe)
   - `observability-dv-canary-interval` (PUT, dangerLevel: destructive — security cadence; lowering this weakens the platform's posture)
   - `observability-temperature-interval` (PUT, dangerLevel: destructive — NOAA rate-limit)
   **PARTIAL.** 6 entries exist, but ALL are coded as `dangerLevel: 'safe'` — three are spec'd as `destructive`. Will be fixed in this pass.
- [x] 8.3 Add `CATEGORY_LABELS['observability']` + add `'observability'` to `CATEGORY_ORDER`.
- [ ] 8.4 The actions need a form input (interval value, endpoint URL). The existing PlatformActionCard pattern is button-only — add a generic `inputType: 'number' | 'string' | 'toggle' | 'none'` to the `PlatformAction` interface, then update the card render to show the input when set. **DEFERRED.** Initial implementation uses `needsValue: boolean` + `window.prompt()` for value entry. Replacing with proper modal form is the better long-term fix; tracked as a follow-up.
- [ ] 8.5 Wire submit to the new `PUT /api/v1/platform/observability` with the partial body (one field per action). **PARTIAL.** Wire exists in PlatformDashboard.handleActivate, but the destructive-action safety guard from main was removed in the process (regression). Will be restored.
- [x] 8.6 The platform dashboard already has a justification-header flow (per F11 task 4.8); reuse it.

## 9. Frontend — remove ObservabilityTab from /admin

- [x] 9.1 Remove the `'observability'` entry from `TABS` + `TAB_COMPONENTS` in `frontend/src/pages/admin/AdminPanel.tsx`. (Verified in working tree: AdminPanel.tsx no longer imports or references ObservabilityTab.)
- [x] 9.2 Delete `frontend/src/pages/admin/tabs/ObservabilityTab.tsx`. (Verified deleted.)
- [x] 9.3 Delete the corresponding lazy-loaded chunk import. (Done in 9.1.)
- [ ] 9.4 Delete admin.observability.* i18n keys EXCEPT the temperature ones that move to SurgeTemperatureSettings (rename keys to `admin.surge.temperature.*`). **PENDING.** The temperature-related keys (tempThreshold, station, threshold, surgeActive, belowThreshold, considerSurge, lastChecked, save, saved, saveError) are still under `admin.observability.*`. Renaming would touch SurgeTab + SurgeTemperatureSettings; deferring as a low-risk cleanup, captured as §15.5.

## 10. Tests

- [ ] 10.1 Vitest for `parseTemperatureError` — 8 scenarios mirroring parseDvPolicyError coverage.
- [ ] 10.2 Playwright spec for `SurgeTemperatureSettings`: panel renders + threshold updates persist + modal opens on confirm + Escape closes + auto-focus on cancel.
- [ ] 10.3 Re-target `e2e/playwright/tests/observability.spec.ts:42, :83` from `test.fixme` to active. The "toggle tracing" test re-points at the new platform action card; "temperature threshold" re-points at SurgeTab.
- [ ] 10.4 Playwright spec for the 6 new platform action cards on `/platform`: read state, submit a value, verify the audit row was emitted, verify the operator UI shows success/error.
- [ ] 10.5 Backend full mvn test green.
- [ ] 10.6 Frontend npm run build clean + Vitest green.

## 11. Documentation

- [x] 11.1 Update FOR-DEVELOPERS.md "platform-operator dashboard" section with the new observability category.
- [ ] 11.2 Update DBML / docs/data-model.md for the `platform_config` table.
- [ ] 11.3 Update OpenAPI annotations on the new endpoints (mirrors dv-policy-tenant-flag §10.4 — Springdoc auto-generates from `@Operation` + `@ApiResponses`).
- [ ] 11.4 Update the v0.58+ deploy runbook with: (a) verify all platform-config values in the dashboard before deploy verification gates; (b) note that `tenant.config.observability` keys for the obsoleted fields are now read-only — drop in v0.58+. **UNVERIFIED.** Previously marked `[x]` but no diff against the runbook is visible in the working tree. Re-check before archive.
- [ ] 11.5 CHANGELOG entry: BREAKING (operator-facing) note about the /admin#observability tab removal + where to find the platform settings now. **UNVERIFIED.** Previously marked `[x]` but no CHANGELOG diff visible in the working tree. Re-check before archive.
<!-- §11.6 / §11.7 entries removed — they were §9 housekeeping accidentally re-filed under §11. The actual §9.1-§9.4 tasks live above; tracking the deletions there. The TracingSamplerConfig.java deletion is captured below as §15.4 follow-up since it's not in the original §9 scope. -->


## 12. Validation

- [ ] 12.1 Backend mvn test green (full suite).
- [ ] 12.2 Frontend Vitest green + npm run build clean.
- [ ] 12.3 Playwright suite green against the live stack.
- [ ] 12.4 `openspec validate platform-observability-split` clean.
- [ ] 12.5 `legal-language-scan.sh` clean for new content.
- [ ] 12.6 `/opsx:verify platform-observability-split` clean.

## 13. Pre-deploy

- [ ] 13.1 Manual smoke: as PLATFORM_OPERATOR, change each of the 6 fields via the dashboard; verify audit row, verify cadence change took effect.
- [ ] 13.2 Manual smoke: as COC_ADMIN, change `temperature_threshold_f` via the new SurgeTab UI; verify audit row, verify subsequent temperature monitor invocations honor the new threshold.
- [ ] 13.3 Real-reviewer signoffs: Casey (platform-vs-tenant boundary + audit fields), Marcus (security — operator can disable own tracing), Sam (V98 migration + runbook), Maria (ES strings).
- [ ] 13.4 Bucket4j rate-limit verification on the two new endpoints (per the dv-policy-tenant-flag pattern).

## 14. Deploy + housekeeping

- [ ] 14.1 Open code-repo + docs-repo PRs.
- [ ] 14.2 Tag release per project flow (could bundle with v0.56+ or ship as v0.57+ standalone — Sam's call).
- [ ] 14.3 Deploy to findabed.org. Verify Flyway HWM advances (V97 → V98).
- [ ] 14.4 Post-deploy smoke: PLATFORM_OPERATOR + COC_ADMIN UIs both work as expected.
- [ ] 14.5 Update memory: refresh `project_resume_point.md`. Add a memory entry for the platform_config singleton pattern (so future maintainers don't reinvent it).
- [ ] 14.6 `/opsx:archive platform-observability-split` after deploy verifies green.

## 15. Out-of-scope follow-ups

- [ ] 15.1 v0.58+ — drop the obsoleted `tenant.config.observability.{prometheus_enabled, tracing_enabled, tracing_endpoint, monitor_*_interval_minutes}` JSONB keys via Flyway. Pre-flight: prod metric showing zero reads of these keys for one full release.
- [ ] 15.2 Tomás ADR (deferred per design Q2): if a 4th platform-singleton-config pattern ever appears, extract a generic platform-singleton-config helper. v0.59+.
- [ ] 15.3 Tier-2 IT (per design Q4): the slow integration test that runs an actual 1-minute cycle is gated by `@Tag("slow")` and runs nightly only; CI for PRs uses the mock-TaskScheduler tier.
- [x] 15.4 (Bookkeeping) Delete `TracingSamplerConfig.java` dead code (was wired to nothing). Verified deleted in working tree.
- [ ] 15.5 (Bookkeeping) Rename `admin.observability.*` i18n keys for the temperature surface to `admin.surge.temperature.*` (touches SurgeTab + SurgeTemperatureSettings). Low-risk cleanup, defer to v0.58+ to avoid blocking this slice.
- [ ] 15.6 §8.4 follow-up: replace `window.prompt()` value entry on the platform dashboard with a proper input modal that shares pattern with DvPolicySettings (extra-confirm modal + auto-focus + Escape). Low-risk UX upgrade for a platform-operator surface; defer.
