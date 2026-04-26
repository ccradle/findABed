# G-4.4 — Per-endpoint role migration table (M-S1)

Per the warroom M-S1 amendment, the v0.53 PR description includes this per-endpoint OLD-role → NEW-role + AuditEventType table so reviewers sign off endpoint-by-endpoint.

**Branch:** `feature/g-4.4-endpoint-migration` (HEAD `8eb0fec` plus warroom-fix commit)
**Source-of-truth grep:** `grep -rn '@PreAuthorize' backend/src/main/java/org/fabt/*/api/`
**Verified by ArchUnit:** `NoPlatformAdminPreauthorizeTest` (no `@PreAuthorize` in `..api..` references `PLATFORM_ADMIN`) + `PlatformAdminOnlyArchitectureTest` (every `@PlatformAdminOnly` method also has `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")`).

**Staleness disclaimer:** This is a point-in-time snapshot. No automated test ensures the table tracks future controller edits — re-derive on every role change.

---

## Tenant-scoped sites (PLATFORM_ADMIN → COC_ADMIN)

Annotations are method-level unless explicitly noted as class-level (`@PreAuthorize` on the `@RestController` class).

### Class-level @PreAuthorize migrations

| Controller | OLD class-level | NEW class-level | Notes |
|---|---|---|---|
| `auth.api.UserController` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` | Covers all CRUD methods |
| `auth.api.ApiKeyController` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` | Covers all 4 methods |
| `auth.api.OAuth2ProviderController` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` | Per-tenant OAuth2 provider config |
| `dataimport.api.ImportController` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` | Tenant data import |
| `tenant.api.TenantConfigController` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` | Per-tenant config (locale, hold duration, etc.) |

### Method-level @PreAuthorize migrations

| Controller / method | OLD `@PreAuthorize` | NEW `@PreAuthorize` |
|---|---|---|
| `auth.api.TotpController.disableUserTotp` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` |
| `auth.api.TotpController.adminRegenerateRecoveryCodes` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` |
| `auth.api.AccessCodeController.generateAccessCode` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` |
| `auth.api.PasswordController.adminResetPassword` | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` |
| `availability.api.AvailabilityController.updateAvailability` | `hasAnyRole('COORDINATOR', 'PLATFORM_ADMIN')` | `hasAnyRole('COORDINATOR', 'COC_ADMIN')` |
| `shelter.api.ShelterController` (admin write methods, ~7 sites at lines 72/254/292/310/331/350/387) | `hasRole('PLATFORM_ADMIN')` | `hasRole('COC_ADMIN')` |
| `shared.api.TestResetController.resetTestData` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` + `@PlatformAdminOnly` (dev/test profile only — bean does not exist in prod) |

---

## Platform-scoped sites (PLATFORM_ADMIN → PLATFORM_OPERATOR + `@PlatformAdminOnly`)

Each entry below requires (a) PLATFORM_OPERATOR role, (b) `MFA_VERIFIED` authority on the JWT (added by `JwtAuthenticationFilter.handlePlatformToken` only for platform JWTs with `mfaVerified=true`), and (c) `X-Platform-Justification` header (≥10 chars after trim, ASCII).

All annotations are method-level. There is NO class-level `@PreAuthorize` on `TenantController` or `BatchJobController` — every method carries its own.

| Controller / method | OLD `@PreAuthorize` | NEW `@PreAuthorize` | `@PlatformAdminOnly.emits` |
|---|---|---|---|
| `analytics.api.BatchJobController.run` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_BATCH_JOB_TRIGGERED` |
| `analytics.api.BatchJobController.restart` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_BATCH_JOB_TRIGGERED` |
| `analytics.api.BatchJobController.schedule` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_BATCH_JOB_TRIGGERED` |
| `analytics.api.BatchJobController.enable` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_BATCH_JOB_TRIGGERED` |
| `tenant.api.TenantController.create` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_TENANT_CREATED` |
| `tenant.api.TenantController.listAll` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | (read-only — see "Read-only platform reads" note below) |
| `tenant.api.TenantController.getById` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | (read-only — see note below) |
| `tenant.api.TenantController.update` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | **`PLATFORM_TENANT_UPDATED`** (NEW enum value, distinct from CREATED) |
| `tenant.api.TenantController.getObservabilityConfig` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | (read-only — see note below) |
| `tenant.api.TenantController.updateObservabilityConfig` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | **`PLATFORM_TENANT_OBSERVABILITY_UPDATED`** (NEW enum value) |
| `tenant.api.TenantController.updateDvAddressPolicy` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | **`PLATFORM_DV_ADDRESS_POLICY_CHANGED`** (NEW enum value, highest-sensitivity tenant config) |
| `tenant.api.TenantKeyRotationController.rotateJwtKey` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_KEY_ROTATED` |
| `auth.api.OAuth2TestConnectionController.testConnection` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_OAUTH2_TESTED` |
| `hmis.api.HmisExportController.retry` | `hasRole('PLATFORM_ADMIN')` | `hasRole('PLATFORM_OPERATOR')` | `PLATFORM_HMIS_EXPORTED` |

### Read-only platform reads — deliberate decision (Marcus warroom)

`listAll`, `getById`, `getObservabilityConfig` are gated `PLATFORM_OPERATOR` but do NOT carry `@PlatformAdminOnly`. The deliberate decision: requiring an `X-Platform-Justification` header on every read of tenant metadata is friction without compliance value (operators viewing the tenant list 50× a day produces unhelpful audit noise). The cost of NOT auditing reads is reconnaissance-grade activity isn't logged via PAL. **Tracked as F20** in `design.md` for Phase H+ revisit if compliance review demands it. Until then: reads of tenant metadata are PLATFORM_OPERATOR-gated but not aspect-audited.

---

## REVERTED to COC_ADMIN — F16 mitigation

Endpoints originally migrated to PLATFORM_OPERATOR + `@PlatformAdminOnly` reverted because their service contract reads `TenantContext` (incompatible with platform JWTs that carry no tenantId).

See **CHANGELOG v0.53.0 + design.md F16 + oracle-update-notes-v0.53.0.md §F16** for the full revert rationale, authority-broadening disclosure, and mitigation design. The role table just records the final state:

| Controller / method | Final `@PreAuthorize` | F16 mitigation |
|---|---|---|
| `hmis.api.HmisExportController.manualPush` | `hasRole('COC_ADMIN')` | `X-Confirm-HMIS-Push: CONFIRM` header + `HMIS_EXPORT_TRIGGERED` audit_event row (actor + vendor list + outbox count) |
| `hmis.api.HmisExportController.listVendors` | `hasRole('COC_ADMIN')` | (read-only) |
| `hmis.api.HmisExportController.addVendor` (501 stub) | `hasRole('COC_ADMIN')` | endpoint returns 501; stub kept tenant-scoped because vendor config is per-tenant |
| `hmis.api.HmisExportController.updateVendor` (501 stub) | `hasRole('COC_ADMIN')` | endpoint returns 501; stub tenant-scoped |
| `hmis.api.HmisExportController.removeVendor` (501 stub) | `hasRole('COC_ADMIN')` | endpoint returns 501; stub tenant-scoped |

**Note on F16 stub-vs-`retry` consistency** (Alex warroom): `manualPush` + vendor stubs are tenant-scoped because vendor config is per-tenant (each CoC manages its own HMIS vendor connections). `retry/{outboxId}` is platform-scoped because it operates on a SHARED dead-letter queue across all tenants. The two roles are correct for the two different concerns.

---

## Unchanged (already correctly scoped — no migration needed)

For reviewer completeness — these controllers had no `PLATFORM_ADMIN` references to migrate:

| Controller | Existing role | Notes |
|---|---|---|
| `analytics.api.AnalyticsController` (8 methods: utilization, demand, capacity, dv-summary, geographic, hic, pit, hmis-health) | `hasRole('COC_ADMIN')` | Tenant-scoped read API |
| `analytics.api.BatchJobController.list` | `hasRole('COC_ADMIN')` | Read-only batch-job catalog (see note below on platform-scope leak) |
| `analytics.api.BatchJobController.executions` | `hasRole('COC_ADMIN')` | Read-only execution history (see note below) |
| `notification.api.EscalationPolicyController` | `hasRole('COC_ADMIN')` | Per-tenant escalation policy |
| `availability.api.TestDataController` | `@Profile("test")` (no auth — profile is the boundary) | Test-only snapshot backdate |

### `BatchJobController.list/executions` platform-scope leak — deliberate decision (Marcus warroom)

These COC_ADMIN-gated read endpoints expose the full job catalog (cron schedules, last-execution status, step-level read/write counts) for jobs that affect cross-tenant scheduler state. A CoC admin at Tenant A can see metadata about jobs that run for Tenant B. This is an existing behavior not introduced by G-4.4. Acceptable for v0.53 because no PII / tenant-scoped data leaks through the metadata. **Tracked as F20** for future hardening to PLATFORM_OPERATOR.

---

## Verification surface

- `NoPlatformAdminPreauthorizeTest` (ArchUnit) — fails build if any `@PreAuthorize` in `..api..` mentions `PLATFORM_ADMIN`. ✅ green at HEAD.
- `PlatformAdminOnlyArchitectureTest` (ArchUnit) — pins that every `@PlatformAdminOnly` method also has `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")`. ✅ green.
- `TestControllerProfileGuardTest` (ArchUnit, NEW G-4.4) — every `Test*Controller` has `@Profile("dev | test")` gate. ✅ green.
- `PlatformAdminAccessAspectTest` (10 IT scenarios) — happy path + filter rejections + unauthenticated probe + forged mfaVerified=false rejection. ✅ green.
- `platform-admin-access-log.spec.ts` (5 Playwright scenarios) — end-to-end pipeline pin. ✅ green at runtime verify.
- `platform-totp-lockout.spec.ts` (4 Playwright scenarios) — end-to-end lockout contract. ✅ green at runtime verify.
- Backend full-suite at HEAD: 1246/1246 + new tenant-event-type tests (run at HEAD).
- Playwright full-suite at HEAD: pending re-verify post-warroom-fix.
