## Why

The `Role.PLATFORM_ADMIN` enum value is a **misnomer** — it reads as "platform-spanning super-admin" but every existing call site implements it as "top role within a tenant." The cryptographic boundary (per-tenant DEK signing JWTs + kid-resolves-to-tenant cross-check at `JwtService.java:409-424`) already prevents cross-tenant access, so today's behavior IS correct — the *name* is what's wrong.

This becomes a Phase G blocker: the planned `@PlatformAdminOnly("justification")` annotation (Phase G task 8.7) and `platform_admin_access_log` table (task 8.2) need a *real* platform-scoped role and identity to gate against. We can't add audited platform-only access if "platform admin" is just "tenant admin in disguise."

Resolves issue #141 + unlocks Phase G-4. Required dependency before `transitional-reentry-support` ships (REENTRY adds VAWA-protected PII that requires the audited unseal channel this change provides).

## What Changes

### Identity + role model

- **Add new role** `Role.PLATFORM_OPERATOR` for genuinely platform-scoped operations (tenant create/suspend/offboard/hardDelete, key rotation, HMIS exports, batch job triggers, OAuth2 connection probes).
- **Promote existing `Role.COC_ADMIN`** to be the canonical "tenant top role." All current `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` sites that gate tenant-scoped resources move to `COC_ADMIN`.
- **Deprecate `Role.PLATFORM_ADMIN`** (mark `@Deprecated`; remove from new role assignments; cleanup release later removes the enum value entirely).
- **BREAKING (internal)** for in-flight JWTs: existing PLATFORM_ADMIN tokens will lose access to platform-scoped endpoints immediately on deploy. Tenant admins keep tenant-scoped access via the COC_ADMIN backfill in V87.

### New `platform_user` identity (separate from `app_user`)

- **New `platform_user` table** with NO `tenant_id` column; bootstrap row created in V87 (locked, no credentials) for operator activation.
- **REVOKE ALL ON platform_user FROM fabt_app**; access via SECURITY DEFINER function (mirrors Phase G-1 `tenant_audit_chain_head` write path).
- **Mandatory TOTP MFA** for all platform users; 10 single-use backup codes generated at MFA setup; 5-failed-attempt lockout for 15 minutes.
- **Tiny `fabt-cli` bcrypt-hash tool** (Spring Boot CommandLineRunner, ~30 LoC) for operator activation: generates bcrypt hash; operator UPDATEs the bootstrap row via psql.
- **Forced MFA-on-first-login flow**: short-lived (10 min) MFA-setup-only token returned at first password auth; full platform JWT not issued until TOTP confirmed.

### New JWT class for platform users

- **Distinct JWT shape** with `iss: "fabt-platform"`, NO `tenantId` claim, 15-minute expiry (vs 60-min for tenant JWTs).
- **Signed by HKDF-derived platform key** from master KEK (NOT a per-tenant DEK; NOT master KEK directly).
- **New `platform_key_material` table** mirroring `tenant_key_material` shape (id, generation, kid, key_bytes, active). Manual rotation tooling later.
- **Iss-routed `JwtDecoder` dispatch** in SecurityConfig: tenant kids resolve via `jwt_key_generation`; platform kids resolve via `platform_key_material`. The cross-tenant cross-check stays simple — separate validation paths instead of weakened conditional logic.

### Audited access log + AOP aspect

- **New `platform_admin_access_log` table** with required `justification` column. Append-only at DB layer (REVOKE UPDATE/DELETE ON ... FROM fabt_app; Phase B V70 pattern).
- **New `@PlatformAdminOnly("reason-for-access-template")`** method-level annotation + Spring AOP aspect. Aspect runs AFTER `@PreAuthorize` (so unauthorized calls don't write log rows) and BEFORE method body (so audit row is committed even if method throws).
- **Double-write pattern**: every `@PlatformAdminOnly` invocation writes to BOTH `platform_admin_access_log` (structured, justification-bearing) AND `audit_events` (chained per Phase G-1, tamper-evident, OCI-anchored per G-3).
- **`audit_events.tenant_id` chosen by action target**: tenant-affecting platform actions (suspend, hardDelete, key-rotation, etc.) land in the target tenant's chain — visible to that tenant's operators, tamper-evident, anchored. Platform-wide actions (BatchJobController, TestResetController) use SYSTEM_TENANT_ID (not chained, per existing Phase G-1 SYSTEM rule).
- **10 new `AuditEventType` values**: `PLATFORM_TENANT_CREATED`, `PLATFORM_TENANT_SUSPENDED`, `PLATFORM_TENANT_UNSUSPENDED`, `PLATFORM_TENANT_OFFBOARDED`, `PLATFORM_TENANT_HARD_DELETED`, `PLATFORM_KEY_ROTATED`, `PLATFORM_HMIS_EXPORTED`, `PLATFORM_OAUTH2_TESTED`, `PLATFORM_BATCH_JOB_TRIGGERED`, `PLATFORM_TEST_RESET_INVOKED`.

### Endpoint migrations

- **18 `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` sites** across 7 controllers split by intent:
  - **11 sites → `COC_ADMIN`** (tenant-scoped admin: TestReset is dev-only with COC_ADMIN; SecurityConfig path patterns; selected TenantController operations like read-self).
  - **7 sites → `PLATFORM_OPERATOR` + `@PlatformAdminOnly`**: TenantController.create; TenantLifecycleController (suspend/unsuspend/offboard/hardDelete); TenantKeyRotationController.rotate; HmisExportController (6 endpoints); OAuth2TestConnectionController.test; BatchJobController (4 endpoints — global runs).

### Demo / public-facing surface

- **Expand "Try it Live" to 12 entries** (3 tenants × {admin, outreach, dv-coordinator, dv-outreach}) with consistent password (`admin123`). Platform user explicitly NOT listed.
- **6 DV-exposure security defenses** required in same release (DV demo accounts are now publicly listed; defended-not-obscured posture):
  1. Per-IP rate limit on `POST /api/v1/dv-referrals` (5/hour) via bucket4j.
  2. Prometheus anomaly alert on referral-creation burst.
  3. `docs/security/dv-incident-response.md` query playbook.
  4. **48-hour** scheduled cleanup of un-acted-upon demo DV referrals (BatchJobScheduler).
  5. `Sec-Fetch-Site` cross-site rejection on `/dv-referrals` POST.
  6. "Demo is monitored; abuse triggers automated rate-limits + alerts" notice on Try-it-Live page.
- **Demo guard remains** — all PLATFORM_OPERATOR endpoints stay demo-restricted.

## Capabilities

### New Capabilities

- `platform-operator-identity`: Separate `platform_user` table, JWT class (iss=fabt-platform), MFA + backup codes, forced-first-login MFA flow, bootstrap activation pattern, lockout policy.
- `platform-admin-access-log`: New `platform_admin_access_log` table, `@PlatformAdminOnly` annotation + AOP aspect, double-write to chained `audit_events`, 10 new audit event types.

### Modified Capabilities

- `auth-and-roles`: Role enum gains PLATFORM_OPERATOR + deprecates PLATFORM_ADMIN; iss-routed JWT validation; second login endpoint `/auth/platform/login` for platform users.
- `admin-user-management`: Tenant-scoped admin endpoints now gate on COC_ADMIN (functional change is the role name; behavior stays the same).
- `admin-password-reset`: Same — gating role moves from PLATFORM_ADMIN to COC_ADMIN.
- `batch-job-management`: Global batch-job triggers move from PLATFORM_ADMIN to PLATFORM_OPERATOR + `@PlatformAdminOnly`.
- `bed-hold-integrity`: Same — ensure spec language updated where it cited PLATFORM_ADMIN.
- `bed-reservation`: Same — spec language sweep.
- `coc-admin-escalation`: Same — gating role on policy-edit and reassign endpoints (currently PLATFORM_ADMIN per spec; should be COC_ADMIN).
- `hmis-admin`: HMIS-export endpoints move to PLATFORM_OPERATOR + `@PlatformAdminOnly`.
- `multi-tenancy`: Tenant-create / lifecycle endpoints move to PLATFORM_OPERATOR + `@PlatformAdminOnly`; cross-tenant cross-check spec language extended for platform-key kid resolution.
- `observability-testing`: Spec language sweep where PLATFORM_ADMIN appears.
- `cross-tenant-isolation-test`: Extend with explicit "COC_ADMIN of A cannot reach tenant B" scenarios; new "PLATFORM_OPERATOR action lands in target tenant's audit chain" scenarios.
- `demo-seed-data`: Expand from 4 dev-coc users to 12 across 3 tenants; COC_ADMIN backfill SQL applied to existing PLATFORM_ADMIN-bearing rows.
- `demo-guard`: PLATFORM_OPERATOR endpoints stay restricted; new DV-defense items added (rate limit, anomaly alert, Sec-Fetch-Site, monitoring notice).

## Impact

### Code

- **34 files** reference PLATFORM_ADMIN today (18 `@PreAuthorize` sites + 16 tests, helpers, comments). All touched.
- **New code**: ~1500–2000 LoC across PlatformUserService, PlatformKeyRotationService, PlatformJwtService, `@PlatformAdminOnly` annotation + AOP aspect, `fabt-cli` bcrypt tool, MFA-on-first-login flow, backup-code generation/validation, COC_ADMIN backfill SQL, DV defense implementations, 10 audit event types, and Playwright fixture (`platformOperatorPage`).
- **Frontend**: role-visibility checks updated; new platform login URL; i18n strings (3+ new keys; "Platform Admin" label changes everywhere).

### Schema (Flyway)

- **V87**: `platform_user` + `platform_user_backup_code` + `platform_key_material` tables; bootstrap rows; COC_ADMIN backfill on existing PLATFORM_ADMIN-bearing app_user rows; REVOKE/SECURITY DEFINER setup.
- **V88**: `platform_admin_access_log` table; REVOKE UPDATE/DELETE policy; indexes.

### APIs

- **New**: `POST /auth/platform/login`, `POST /auth/platform/mfa-setup`, `POST /auth/platform/mfa-confirm`, `POST /api/v1/platform/users` (gated by `@PlatformAdminOnly`).
- **Changed gating role**: 18 existing endpoints (split 11/7 between COC_ADMIN and PLATFORM_OPERATOR).

### Operational

- **Provisioning runbook addition**: "First platform_user activation" (`docs/runbook.md` + v0.53 oracle-update-notes); ~5 min one-shot post-deploy.
- **Backfill safety**: COC_ADMIN added in V87 + token-version bump (per design Decision 16) means tenant admin sessions are FORCIBLY logged out on deploy and re-login fresh under the new role taxonomy. Closes the "stolen pre-v0.53 PLATFORM_ADMIN JWT" window at deploy time. Acceptable cost: every active admin session experiences a re-login.
- **Cold-start mitigation**: 5-minute platform-user activation window is the only "no platform operator" period — operations like `TenantLifecycleController.suspend` cannot run during it. Pre-deploy checklist (per design Migration Plan): operator has TOTP app + backup-code storage ready; if first-ever platform_user, 2nd operator on standby; `fabt-cli.jar` pre-staged on VM.

### Compliance posture (Casey)

- This is a **compliance UPGRADE**, not a regression. Pre-split: PLATFORM_ADMIN of dev-coc could silently read all DV PII (because they're a tenant admin). Post-split: viewing DV PII via the platform side requires `@PlatformAdminOnly("justification")` + `platform_admin_access_log` row + chained audit_events row. Audited unseal channel.
- Phrasing: "designed to support VAWA H4 posture." Never "VAWA compliant" — per `feedback_legal_claims_review.md`.

### Tests

- **CrossTenantIsolationTest** extended with COC_ADMIN-cannot-cross-tenant scenarios.
- **New IT family**: `PlatformAdminAccessLogTest` proving every `@PlatformAdminOnly` invocation writes the structured log row + the chained audit_events row, with hash equality verification.
- **Playwright fixtures**: new `platformOperatorPage`; existing `cocadminPage` re-resolves to a COC_ADMIN credential; new tests for forced-MFA-on-first-login flow and backup-code use.
- **DV defense tests**: rate-limit at 6th referral within an hour; alert-fires-on-burst; cleanup-job-removes-stale-referral-after-48h.

### Targets

- **Release**: v0.53.0 (Phase G-4 ships, unblocks G-5).
- **Slices for review**: **5 PRs** (split increased from 4 post-warroom for review tractability) — G-4.1 (schema + identity + COC_ADMIN backfill with token-version bump), G-4.2 (auth flow + JWT + fabt-cli + rate limits + MFA lockout), G-4.3 (V88 + @PlatformAdminOnly + AOP), G-4.4 (endpoint migration + Playwright + ArchUnit guard), G-4.5 (demo expansion + DV defenses + accessibility + monitoring + customer comms).
