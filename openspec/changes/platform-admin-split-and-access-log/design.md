## Context

FABT today has 4 flat-listed roles in `Role.java`: `PLATFORM_ADMIN`, `COC_ADMIN`, `COORDINATOR`, `OUTREACH_WORKER`. The naming `PLATFORM_ADMIN` is a misnomer — every existing call site implements it as "top role within a tenant" because the cryptographic boundary (per-tenant DEK signing JWTs + kid-resolves-to-tenant cross-check at `JwtService.java:409-424`) prevents cross-tenant access at the JWT layer regardless of role.

**Verified ground truth (Phase G-3 deploy session, 2026-04-25):**
- 18 `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` sites across 7 controllers (TestReset, TenantKeyRotation, SecurityConfig (3 sites), TenantController (2), HmisExport (6), OAuth2TestConnection, BatchJob (4))
- 34 files reference `PLATFORM_ADMIN` total (the other 16 are tests, comments, role-check helpers)
- AuthController login keyed on `(tenantId, email)`; same email in two tenants = two distinct user records
- Per-tenant DEKs derived via HKDF; each tenant's signing key schedule is its own
- A `PLATFORM_ADMIN` of `dev-coc` cannot log into `dev-coc-west` — kid resolves to wrong tenant, JWT rejected with `CrossTenantJwtException`

**Phase G-4 (per `project_phase_g_implementation_plan.md`)** plans `@PlatformAdminOnly("reason")` annotation + `platform_admin_access_log` table. Both require a *real* platform-scoped role to gate against. The current PLATFORM_ADMIN role's tenant-bound semantics make it the wrong gate — annotating tenant-bound endpoints as "platform-only" creates a false security claim.

**Stakeholders** (warroom personas synthesized 2026-04-25):
- **Alex Chen (Principal Engineer):** type-system split, not rename
- **Marcus Webb (Pen Tester):** three hard constraints — no upgrade path between roles, mandatory MFA, don't loosen kid cross-check
- **Jordan Reyes (SRE):** provisioning order critical; cold-start trap if no platform_user exists post-deploy
- **Riley Cho (QA):** test fixture explosion; new platformOperatorPage required
- **Casey Drummond (Legal):** compliance UPGRADE — pre-split, PLATFORM_ADMIN can silently read DV PII; post-split requires audited unseal channel
- **Elena Vasquez (DBA):** RLS posture decision; REVOKE + SECURITY DEFINER mirrors Phase G-1 chain-head pattern

**Constraints:**
- Must not break in-flight tenant admin sessions through deploy window (use COC_ADMIN backfill)
- Must not weaken Phase A4 D25 cross-tenant cross-check (separate JWT class, NOT sentinel-tenantId)
- Must integrate cleanly with Phase G-1 audit chain (write to chained `audit_events`, not parallel)
- Phase F-6 hard-delete + Phase G-3 OCI anchor are downstream consumers; don't disrupt them
- Per `feedback_legal_claims_review.md`: language stays "designed to support VAWA H4" not "VAWA compliant"

## Goals / Non-Goals

**Goals:**
- Eliminate the PLATFORM_ADMIN misnomer by introducing a real platform-scoped role with separate identity model.
- Enable Phase G-4 audited unseal channel (`@PlatformAdminOnly` + `platform_admin_access_log`) to gate platform-only endpoints.
- Maintain backward compatibility for existing tenant admin sessions through the deploy window via COC_ADMIN backfill in V87.
- Improve compliance posture (VAWA H4 / NIST alignment) without claims of certification.
- Preserve the cryptographic cross-tenant boundary (per-tenant DEK signing) — extend it to platform-side with a master-KEK-derived platform key.
- Stage delivery in 4 reviewable PRs (G-4.1 through G-4.4) for incremental review.
- Expand "Try it Live" demo surface to all 3 tenants × 4 roles (12 entries) with hardened DV defenses (defended-not-obscured posture).

**Non-Goals:**
- **No FIDO2 / WebAuthn / hardware keys.** TOTP MFA + backup codes is sufficient for v0.53; FIDO2 is a Phase H+ enhancement.
- **No SSO for platform users.** SAML / Okta integration deferred to Phase H; the separate `platform_user` table makes future SSO straightforward but not in-scope now.
- **No automated platform-key rotation.** Manual rotation tooling later; one fixed generation initially. Same pattern as F-4 single-generation start.
- **No removal of PLATFORM_ADMIN enum value in this release.** Marked `@Deprecated` only; the cleanup release (separate change) removes the enum value entirely after CI guards confirm no source references.
- **No admin UI for platform_user management.** Bootstrap row + psql activation + API endpoint (gated by `@PlatformAdminOnly`) for adding more. Phase H+ adds a UI.
- **No "remember this device" / long-lived MFA bypass.** Every platform login is full re-auth.
- **No CAPTCHA on the demo DV referral endpoint.** Friction wall for the legit users we want; defended via rate-limit + anomaly alert + monitoring instead.

## Decisions

### Decision 1 — Naming: deprecate PLATFORM_ADMIN; promote COC_ADMIN to "tenant top role"; add PLATFORM_OPERATOR

**Why:** Domain language preservation. "CoC Admin" maps to a real, named role at every Continuum of Care; "Tenant Admin" is engineering-speak losing that meaning. Half the migration work compared to a rename pass. Existing `COC_ADMIN` enum value already exists — just needs role assignments to flow to it.

**Alternatives considered:**
- *Rename PLATFORM_ADMIN → TENANT_ADMIN per issue #141:* architecturally cleaner ("admin" = top within scope) but loses domain term. Doubles migration work (all 18 @PreAuthorize sites + all 34 file references).
- *Keep PLATFORM_ADMIN, add PLATFORM_OPERATOR alongside:* simpler code change but preserves the misnomer. Reviewers continue to misread the role's scope.

### Decision 2 — Identity model: separate `platform_user` table, NOT augmented `app_user`

**Why:** RLS clarity. `app_user` is FORCE RLS'd by tenant — every row has `tenant_id`, every query carries tenant context. A nullable-tenant_id approach breaks that invariant: needs a *second* RLS rule for `tenant_id IS NULL`, plus partial unique index for email uniqueness. The Phase B RLS work was deliberate; adding a NULL-tenant exception goes against that grain. Separate table also enables future SSO scoping and clean type-system distinction (`User` vs `PlatformUser`).

**RLS posture:** `REVOKE ALL ON platform_user FROM fabt_app` + access via SECURITY DEFINER function. Mirrors Phase G-1 `tenant_audit_chain_head` write path.

**Alternatives considered:**
- *Nullable `tenant_id` on `app_user`:* one table; UserService handles both. Rejected for RLS complexity, email-uniqueness corner case (PostgreSQL treats NULLs as distinct), AuthController flow mismatch, FK cascade audit blast radius across schema.

### Decision 3 — JWT shape: separate JWT class with `iss: "fabt-platform"`, signed by HKDF-derived platform key

**Why:** The cross-tenant cross-check at `JwtService.java:409-424` is a hard cryptographic containment boundary established in Phase A4 D25. The "nullable tenantId + sentinel kid" alternative turns a 1-branch check into 3-branch logic (`null+platform=ok`, `null+tenant=reject`, `uuid+platform=reject`) — the exact conditional pattern that grows bugs. Separate JWT shape keeps the cross-check simple: tenant kids resolve to tenants, platform kids resolve to "platform identity," and validation paths are entirely separate.

**Cryptographic anchor:** HKDF-derived from master KEK (NOT master KEK directly — same defense-in-depth pattern as per-tenant DEKs). Single starting key generation, no automated rotation initially (manual rotation tooling later — analogous to F-4 pattern).

**JWT shape:**
- Tenant: `{ "iss": "fabt-tenant", "sub": <user_id>, "tenantId": <uuid>, "roles": [...], "ver": <token_version>, ... }`
- Platform: `{ "iss": "fabt-platform", "sub": <platform_user_id>, "roles": ["PLATFORM_OPERATOR"], "mfaVerified": true, "ver": <token_version>, ... }` — NO `tenantId` claim

**Validation:** iss-routed `JwtDecoder` dispatch in SecurityConfig. Tenant kids resolve via `jwt_key_generation`; platform kids resolve via `platform_key_material`. Two separate validation paths.

**Expiry:** 15 min for platform JWTs (vs 60 min tenant). Platform actions are deliberate; long-lived tokens add risk for nothing.

**Alternatives considered:**
- *Same JWT shape with `tenantId=null` sentinel + platform-key kid:* leaner code (~150 fewer LoC) but quietly weakens a Phase A4 cryptographic boundary. Rejected on Marcus's hard constraint.
- *Master KEK signs JWTs directly (no derivation):* simpler key management; rejected because key rotation rotates everything.

### Decision 4 — Provisioning: bootstrap row in V87 + tiny bcrypt CLI + forced MFA-on-first-login + COC_ADMIN backfill in same migration

**Why:** Migration is auditable + reproducible (a row in V87 is in version control, reviewed in PR, applied by Flyway, logged); CLI alternative gets forgotten. Cold-start safe — no race between "deploy completed" and "someone remembered to bootstrap." Reuses existing FABT bootstrap pattern (DB owner / JWT secret / OCI keys all use env vars + file paths). Defense-in-depth: application code refuses login when `password_hash IS NULL OR account_locked = true` — even if the row leaks, it's not a credential.

**Activation sequence:**
1. V87 inserts bootstrap row at hardcoded UUID `00000000-0000-0000-0000-000000000fab` with `email=NULL, password_hash=NULL, account_locked=true`.
2. Operator runs `java -jar fabt-cli.jar hash-password` (small Spring Boot CommandLineRunner, ~30 LoC); tool prompts for password, prints bcrypt hash.
3. Operator UPDATEs the bootstrap row via psql to set email + password_hash + unlock.
4. First login at `POST /auth/platform/login` returns short-lived (10-min) MFA-setup-only token; operator scans QR + 10 backup codes; confirms TOTP code; `mfa_enabled=true`.
5. Subsequent logins issue real platform JWTs.

**Backfill:** Same V87 migration grants `COC_ADMIN` to existing `app_user` rows that have `PLATFORM_ADMIN` (preserves tenant admin sessions through deploy window):
```sql
UPDATE app_user
   SET roles = roles || '{COC_ADMIN}'
 WHERE 'PLATFORM_ADMIN' = ANY(roles)
   AND NOT ('COC_ADMIN' = ANY(roles));
```

**Activation window risk:** Between deploy and platform_user activation (~5 min), no one can run platform-only operations like `TenantLifecycleController.suspend`. Mitigated by: (a) activation in same SSH session as deploy; (b) operations of this kind are infrequent; (c) the v0.53 runbook lists activation as a numbered post-deploy step.

**Alternatives considered:**
- *One-shot CLI tool only (no migration row):* less SQL magic but more code to maintain + ship + version + test, plus "remember to run it" foot-gun.
- *Env-var-based bootstrap on first startup:* matches some FABT bootstrap patterns but adds a "first startup" code path that's hard to test idempotently.

### Decision 5 — MFA: mandatory TOTP + backup codes + 5-fail lockout

**Why:** PLATFORM_OPERATOR is the highest-value account class in FABT (suspend tenants, rotate keys, hard-delete tenant data via crypto-shred). Single-person credential makes MFA cost trivial. Industry baseline for ops/admin accounts in compliance-adjacent contexts. TotpService from Phase A4 already exists — reuse is ~30 LoC.

**Specifics:**
- **TOTP only** (no SMS, no email-based MFA, no push). RFC 6238, 30-sec window, 6-digit codes.
- **10 single-use backup codes** generated at MFA setup, displayed ONCE, stored as bcrypt hashes in `platform_user_backup_code(id, platform_user_id, code_hash, used_at NULL, created_at)`. "Regenerate backup codes" later invalidates the existing 10 by `DELETE` and generates 10 new.
- **5 failed MFA attempts within 15 minutes** → account locked for 15 minutes. Lockout entry written to `platform_admin_access_log`.
- **No "remember this device" pattern.** Every login is full re-auth.
- **MFA cannot be disabled via UI.** `mfa_enabled` is permanent-true once set; flipping back to false requires direct psql by another platform_user (or bootstrap re-activation flow).

**Alternatives considered:**
- *FIDO2 / WebAuthn:* better security (phishing-resistant), more code to ship + test. Phase H+ enhancement.
- *Password-only with longer expiry:* would put one of the highest-value account classes in the platform behind one phishing email. Rejected on Marcus's hard constraint.

### Decision 6 — Audit chain: double-write to BOTH `platform_admin_access_log` and chained `audit_events`; tenant_id chosen by action target

**Why:** Phase G-1 made `audit_events` tamper-evident via per-tenant hash chains, daily verifier, and weekly OCI anchor. If platform actions only land in `platform_admin_access_log`, that table needs its own integrity story or there's a tamper-evidence hole exactly at the highest-stakes actions. Tenant operators querying their own tenant's audit history must see what platform admins did to them — both for UX and compliance posture.

**Two tables play complementary roles** (not duplication):
- `platform_admin_access_log`: structured platform-admin record (justification required, endpoint, request body excerpt, before/after, who+when). Append-only via `REVOKE UPDATE/DELETE ON ... FROM fabt_app` (Phase B V70 pattern). Linear append-only sufficient for this surface.
- `audit_events`: universal audit log; cross-tenant queries; chain-walk forensics; OCI anchor coverage. Per-tenant hash chain (G-1) + verifier (G-2) + anchor (G-3).

**Tenant_id for the audit_events row is action-target-driven:**

| Platform action | audit_events tenant_id | Chained? |
|---|---|---|
| `TenantLifecycleController.suspend(X)` / unsuspend / offboard / hardDelete | X | ✅ in X's chain |
| `TenantKeyRotationController.rotate(X)` | X | ✅ in X's chain |
| `HmisExportController.export(X)` | X | ✅ in X's chain |
| `OAuth2TestConnectionController.test(X)` | X | ✅ in X's chain |
| `TenantController.create(newSlug=Y)` | new tenant Y's id | ✅ in Y's brand-new chain (first row) |
| `BatchJobController.run(jobName)` (platform-wide) | SYSTEM_TENANT_ID | ❌ not chained (per existing SYSTEM rule) |
| `TestResetController.reset` (dev-only) | SYSTEM_TENANT_ID | ❌ not chained |

**10 new `AuditEventType` enum values** (Phase G-0 pattern): `PLATFORM_TENANT_CREATED`, `PLATFORM_TENANT_SUSPENDED`, `PLATFORM_TENANT_UNSUSPENDED`, `PLATFORM_TENANT_OFFBOARDED`, `PLATFORM_TENANT_HARD_DELETED`, `PLATFORM_KEY_ROTATED`, `PLATFORM_HMIS_EXPORTED`, `PLATFORM_OAUTH2_TESTED`, `PLATFORM_BATCH_JOB_TRIGGERED`, `PLATFORM_TEST_RESET_INVOKED`. Each carries `details` JSONB with at minimum: `{ "platform_admin_access_log_id": "<uuid>", "platform_user_id": "<uuid>", "platform_user_email": "<email>", "justification_excerpt": "<first 200 chars>" }`.

**AOP aspect ordering:** `@PlatformAdminOnly` aspect runs AFTER `@PreAuthorize` (so unauthorized calls don't write log rows) but BEFORE method body. `platform_admin_access_log` row is committed in REQUIRES_NEW transaction (so audit row survives even if main method throws + main tx rolls back — Phase C `DetachedAuditPersister` pattern).

**Alternatives considered:**
- *Write only to `platform_admin_access_log`:* leaner code (~30 fewer LoC) but tamper-evidence gap at highest stakes; tenant operators blind to platform actions affecting them.
- *Write only to `audit_events` (skip the structured table):* loses structured justification field; loses table-level REVOKE protection; conflates platform-admin action with regular audit events in queries.
- *Synthetic "PLATFORM_TENANT_ID" with own chain head:* extends chain to platform-wide actions. Rejected as semantically weird (a "tenant" with no users, shelters, etc.). Platform-wide actions land under SYSTEM_TENANT_ID instead.

### Decision 7 — Demo expansion + DV-defense package

**Why:** "Try it Live" currently lists only dev-coc users; visitors don't see Blue Ridge / Pamlico Sound, and the multi-tenancy story we built is invisible. The expanded list (3 tenants × 4 roles = 12 entries) makes cross-tenant isolation tangible and surfaces the DV workflows for advocates / funders evaluating FABT. Hiding DV workflows would frustrate the right audience without stopping bad actors — defended-not-obscured posture is right.

**6 DV-exposure security defenses required in same release:**
1. **Per-IP rate limit on `POST /api/v1/dv-referrals` at 5/hour** via bucket4j filter entry.
2. **Prometheus anomaly alert**: `rate(fabt_dv_referrals_created_total[5m]) by (source_ip) > 10` → page operator.
3. **`docs/security/dv-incident-response.md` query playbook** — how to identify suspicious DV access patterns from `audit_events` post-incident.
4. **48-hour scheduled cleanup** of un-acted-upon demo DV referrals via BatchJobScheduler. (User's tweak: 48h, not 24h.)
5. **`Sec-Fetch-Site` header check** on `POST /api/v1/dv-referrals` — reject if not same-origin. Stops trivial scripted abuse without affecting browser users.
6. **Public note on Try-it-Live page:** "These are real demo credentials in a real environment. The demo is monitored; abuse triggers automated rate-limits + alerts."

**Platform user explicitly NOT listed.** MFA-required + single-operator credential by definition.

## Risks / Trade-offs

- **[Activation window risk]** 5-minute "no platform operator" gap between deploy and bootstrap activation; cannot suspend tenants during this window. → Mitigated by activation in same SSH session as deploy; runbook makes activation a numbered post-deploy step; operations of this kind are infrequent.

- **[In-flight JWT staleness]** Existing PLATFORM_ADMIN tokens valid up to 60 min post-deploy; will lose access to platform-scoped endpoints on first request. → Acceptable — tenant-scoped access preserved via COC_ADMIN backfill; 403 on platform-scoped is the correct security outcome (the JWT bearer never legitimately had platform privileges in the first place; we're closing that hole).

- **[CO C_ADMIN backfill side effects]** Granting COC_ADMIN to all existing PLATFORM_ADMIN-bearing rows touches every active tenant admin account. → Reviewed: COC_ADMIN already exists in the enum; no new permissions are being granted that the user didn't already enjoy under PLATFORM_ADMIN's tenant-scope semantics. Backfill is essentially a label change for tenant-scoped behavior.

- **[Demo DV exposure abuse]** Publicly listing dv-coordinator / dv-outreach credentials invites probing. → Defended-not-obscured: 6-item security checklist (rate limit, anomaly alert, IR runbook, 48h cleanup, Sec-Fetch-Site, monitoring notice). Abuse cost bounded; takedown trail established if escalation needed.

- **[Schema migration order]** V87 + V88 both add new tables. Must be additive (no existing-row impact) so v0.52 → v0.53 rollback path stays clean. → Both migrations create new tables only; no ALTERs on existing tables aside from optional COC_ADMIN backfill (which is an UPDATE on `app_user.roles` — no schema change).

- **[Bootstrap row leak risk]** A leaked `platform_user(id=00000000-...-000fab)` row reveals that fabt has a platform_user table — minor information disclosure. → Acceptable; the row contains no credentials (`password_hash IS NULL` rejects login). Code refuses login on either NULL hash or `account_locked=true`.

- **[Backup code storage]** Operator must store backup codes securely off-device. → Documented in runbook; recommended pattern is 1Password or printed-and-physically-secured. Same recovery posture as DB owner password.

- **[Test fixture churn]** Playwright fixtures `cocadminPage` / `dvCoordinatorPage` semantics shift (cocadminPage was using a PLATFORM_ADMIN JWT). New `platformOperatorPage` fixture needed. → Refactor scoped in G-4.4 slice; documented in `project_coordinator_user_term_confusion.md`.

- **[Forensic walker complexity]** Two log surfaces (chained `audit_events` + structured `platform_admin_access_log`). → Linked by id in `audit_events.details` JSONB — single forensic walk, two data sources joined when full detail is wanted. Documented pattern in `docs/security/dv-incident-response.md`.

- **[Compliance language drift]** Risk that future docs claim "VAWA compliant" or "NIST certified." → CI legal-language scan (existing) catches "compliant" / "guarantees" phrasing; spec-author template uses "designed to support" wording. Reviewer gate.

- **[Stolen pre-v0.53 PLATFORM_ADMIN JWT]** Backward compat keeps PLATFORM_ADMIN JWTs working through the deprecation window; a stolen credential pre-v0.53 retains access. → Mitigated by Decision 16 (token-version bump in V87 backfill invalidates all existing PLATFORM_ADMIN sessions). Cost: every active admin session logged out at deploy.

- **[Cold-start activation window]** 5-min "no platform operator" window between deploy and bootstrap activation. If deploy takes longer (network slow, MFA app on dead phone, 2nd operator unavailable), window extends. → Pre-deploy checklist requires: confirm operator has TOTP app + backup codes; if first-ever platform_user, schedule deploy in maintenance window with 2nd operator on standby for recovery. Acceptable risk because operations requiring PLATFORM_OPERATOR are infrequent (TenantLifecycle suspend/etc. ~weekly at most).

- **[Backup code recovery deadlock]** If a single platform_user exists and they exhaust/lose all 10 backup codes AND lose their TOTP device, no other platform_user exists to unlock — chicken-and-egg. → Documented recovery: SSH to VM, psql `UPDATE platform_user SET password_hash = NULL, account_locked = true` to reset to bootstrap-equivalent state, then re-activate via fabt-cli. Mandatory operational practice: provision a 2nd platform_user (e.g., a delegated ops role) as recovery contact within first week of v0.53.

- **[fabt-cli shipping mechanism]** New CLI tool needs deployment to ops workstations / VM. → Built as separate Maven module per Decision 8; published as GitHub release artifact alongside backend JAR; documented in runbook with `scp` example. Operator downloads on demand.

- **[Three-write transaction failure mode]** PAL+AE both INSERTed in REQUIRES_NEW with pre-generated UUIDs (Decision 11). If REQUIRES_NEW commit fails, both rows fail atomically — but the main method body might have already executed. → Acceptable: better to lose the audit row than block the operation; aspect logs WARN to application log so a missed audit row is detectable in log review. Future hardening: redundant audit emit via `DetachedAuditPersister` REQUIRES_NEW retry (Phase H+).

## Migration Plan

### V87 (G-4.1 deploy)
- `CREATE TABLE platform_user`, `platform_user_backup_code`, `platform_key_material`
- `INSERT` bootstrap rows: one platform_user (locked, no creds) at hardcoded UUID; one platform_key_material (active=true, generation=1, kid=randomly generated, key_bytes=HKDF-derived from master KEK at app startup if column is null on first boot — handled by application code, not migration)
- `REVOKE ALL ON platform_user FROM fabt_app` + SECURITY DEFINER access function
- COC_ADMIN backfill: `UPDATE app_user SET roles = roles || '{COC_ADMIN}' WHERE 'PLATFORM_ADMIN' = ANY(roles) AND NOT ('COC_ADMIN' = ANY(roles))`

### V88 (G-4.3 deploy, can be same release as V87)
- `CREATE TABLE platform_admin_access_log` with required justification column, FKs to platform_user
- `REVOKE UPDATE, DELETE ON platform_admin_access_log FROM fabt_app` (Phase B V70 pattern)
- Indexes on (platform_user_id, timestamp), (timestamp), (resource_id)

### Application code rollout (G-4.1 → G-4.5; split increased post-warroom for review tractability)
1. **G-4.1**: V87 (platform_user + platform_user_backup_code + platform_key_material tables; bootstrap row; COC_ADMIN backfill WITH token-version bump per Decision 16) + Role enum (add PLATFORM_OPERATOR; deprecate PLATFORM_ADMIN). No `@PreAuthorize` changes yet; PLATFORM_ADMIN still works for everything.
2. **G-4.2**: Auth flow + JWT classes + MFA + bootstrap activation runbook + `fabt-cli` separate Maven module (Decision 8) + per-IP rate limit on `/auth/platform/login` + per-account+per-IP MFA lockout. Platform side functional but no endpoints gate on PLATFORM_OPERATOR yet.
3. **G-4.3**: V88 + `@PlatformAdminOnly(reason, emits)` annotation (Decision 9) + AOP aspect (split into JustificationValidator filter + PlatformAdminLogger aspect per Alex) + double-write pattern with client-side UUID ordering (Decision 11). Annotation added to a single endpoint as canary (`BatchJobController.run`).
4. **G-4.4**: Migrate 11 tenant-scoped sites to COC_ADMIN; migrate 7 platform-scoped sites to PLATFORM_OPERATOR + `@PlatformAdminOnly`. Update Playwright fixtures (TOTP automation helper). ArchUnit guard added preventing future PLATFORM_ADMIN annotation use.
5. **G-4.5** (NEW — split out from G-4.4 per Riley): Demo seed expansion to 12 users + COC_ADMIN backfill verification + 6 DV-defense items + accessibility refinements (TOTP input semantics, QR alt text, backup code semantic markup, lockout aria-live) + customer communication note + 4 new Prometheus alerts for platform admin monitoring + MDC `platform_action: true` marker for SOC filtering.

### Cold-start mitigation
Pre-deploy checklist for v0.53.0 (added to runbook per Jordan's hard constraint):
- [ ] Confirm operator has TOTP app installed and accessible (phone charged; backup phone available if first-ever platform_user)
- [ ] Confirm operator has password-manager / secured-physical-storage ready for backup codes
- [ ] If first-ever platform_user: schedule deploy in maintenance window; 2nd operator on standby for recovery
- [ ] Pre-build + scp `fabt-cli.jar` to VM before deploy (avoids "tool missing" mid-activation)
- [ ] Activation runbook section pre-rehearsed (operator has read it)

### Rollback strategy
- **G-4.1 rollback**: drop V87 tables; drop COC_ADMIN backfill (rollback SQL: `UPDATE app_user SET roles = array_remove(roles, 'COC_ADMIN') WHERE 'PLATFORM_ADMIN' = ANY(roles)` — only if no real COC_ADMIN-only users exist). Application code rollback is straightforward (Role enum reversion).
- **G-4.4 rollback**: re-apply previous `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` annotations. Tenant admin sessions still work (COC_ADMIN backfill doesn't break anything by being present).
- **Schema posture**: V87 + V88 are additive (CREATE TABLE only) so the rollback for v0.53 → v0.52 is JAR-only. No DB rollback needed.

### Decision 8 — `fabt-cli.jar` ships as a separate Maven module + JAR artifact

**Why:** Tool stays callable without bringing up the full Spring context (~10s startup overhead avoided). Separate JAR is grep-able in deployment artifacts, can be downloaded independently to ops workstations, and avoids polluting the backend JAR with CLI code paths. Build into `fabt-cli/target/fabt-cli.jar` via dedicated `<module>` in pom; ship alongside backend JAR in v0.53 release artifacts. Operator downloads via `scp` from VM or directly from GitHub release.

### Decision 9 — `@PlatformAdminOnly(reason="...", emits=AuditEventType.X)` — eliminates string-mapping fragility

**Why:** Mapping controller-method-name to AuditEventType via reflection or naming convention is compile-fragile (renaming a method silently changes the audit record). Making the AuditEventType an explicit annotation parameter:
- Forces the developer to declare the audit type at the call site (compile-time documentation)
- Makes the mapping reviewable in source diff (vs. hidden in a mapping bean)
- Catches typos at compile time (enum values are checked)
- Allows a single endpoint to emit different audit types based on conditional logic if needed (future extension)

**Annotation declaration:** `@PlatformAdminOnly(reason String, emits AuditEventType)` — both required, no defaults. AOP aspect uses the `emits` value directly when writing the audit_events row.

### Decision 10 — `X-Platform-Justification` header is operator-asserted DOCUMENTATION, NOT server-validated authority

**Why:** A malicious operator can write any text in the header. The system records it, doesn't validate semantic content. This is intentionally a DOCUMENTATION feature, not an enforcement mechanism. Reframe spec language and ops docs accordingly:
- "The operator MUST provide a justification" — TRUE (server-rejects empty/short headers)
- "The justification proves the action was warranted" — FALSE (it's just text)
- "An auditor reviewing the log can read the justification to UNDERSTAND the action" — TRUE

**Mitigation against abuse:** (a) all platform actions are also visible to tenant operators via the chained `audit_events` row in their tenant chain; tenant-side operator can dispute "this action wasn't warranted"; (b) `docs/security/platform-admin-justification-conventions.md` documents the expected style guide for justifications, enabling auditors to flag malformed entries; (c) regex-validation could be added later if abuse becomes a pattern.

### Decision 11 — Three-write transaction ordering: client-side UUID generation + single REQUIRES_NEW transaction

**Why:** PAL+AE+link-update is three logical writes per platform action. Transactional ordering matters: if it fails between AE-insert and PAL-link-update, PAL is missing the join key. Solution:
1. AOP aspect generates UUIDs for both the new PAL row and the new AE row UP FRONT (client-side via `UUID.randomUUID()`)
2. Within a single REQUIRES_NEW transaction:
   - INSERT PAL with `audit_event_id = <pre-generated AE UUID>`
   - INSERT AE with `id = <pre-generated AE UUID>`, `details->>'platform_admin_access_log_id' = <pre-generated PAL UUID>`
3. Commit
4. Both rows linked atomically; no UPDATE step needed

**Note:** AE INSERT must happen AFTER PAL INSERT in the SQL ordering for FK constraint reasons (PAL.audit_event_id has no FK; AE has no FK to PAL — both directional links live in plain UUID columns).

### Decision 12 — Backup codes hashed with SHA-256 + per-row salt, NOT bcrypt

**Why:** Backup codes are random 8-char strings used at most once each. Bcrypt's slow-comparison property protects against brute-force on user-chosen passwords; backup codes have no such risk (random + single-use + small space). Bcrypt-12 adds 100-200ms per code verification — meaningful latency when an operator is mid-recovery with 60-sec TOTP windows ticking. SHA-256 + per-row 16-byte salt is sufficient cryptographic protection for this use case and 100x faster.

### Decision 13 — `PLATFORM_TENANT_HARD_DELETED` audit row written under SYSTEM_TENANT_ID

**Why:** Phase F-6 hardDelete CASCADEs through 22 FKs including `audit_events.tenant_id`. Writing the hardDelete audit under the target tenant's chain means the row gets deleted BY ITS OWN ACTION — no permanent record of the deletion in the audit chain. Solution: PLATFORM_TENANT_HARD_DELETED audit row uses `tenant_id = SYSTEM_TENANT_ID` (unchained per existing rule but persists post-deletion). The structured `platform_admin_access_log` row also persists (it's keyed by `platform_user_id`, not `tenant_id`). Forensic record survives the deletion event.

### Decision 14 — Retention policy: indefinite for v0.53; explicit policy lands Phase H+

**Why:** Compliance contexts (HIPAA 6yr, VAWA per-OVW, government audit 7yr) typically require multi-year retention for admin access logs. Building proper retention (per-tenant, per-action-type, age-based) is non-trivial. Spec for v0.53: indefinite retention (rows never deleted by application). Phase H+ adds: retention policy column, scheduled cleanup job, per-tenant retention overrides. Operator may manually purge via psql in the interim; document procedure.

### Decision 15 — GDPR Art-17 (right to be forgotten) for platform_user: anonymize email, retain row

**Why:** When a platform operator leaves the org, their identity should be deletable. But `platform_admin_access_log.platform_user_id` FK prevents straightforward DELETE — and removing the audit history would be a compliance regression. Solution: anonymize the platform_user row on departure (`UPDATE platform_user SET email = 'departed-' || id || '@anonymized', password_hash = NULL, account_locked = true`). Audit history preserved; identity unlinkable. Tooling Phase H+; manual psql in the interim.

### Decision 16 — Token-version bump on PLATFORM_ADMIN-bearing app_user rows in V87 backfill

**Why:** During the v0.53 → cleanup-release window, backward compat keeps PLATFORM_ADMIN-bearing JWTs working for tenant-scoped endpoints (via the COC_ADMIN backfill). If a JWT was stolen pre-v0.53, the thief gains the same level of access post-v0.53 until cleanup. Mitigation: bump `app_user.token_version` (existing field, increments on rotation events) in the same V87 UPDATE that adds COC_ADMIN. All existing JWTs invalidated; users re-login fresh. Trade-off: every active session is logged out at deploy time. Acceptable cost for closing the stolen-credential window.

## Open Questions

- **Q1 (UI link visibility)**: Should the platform login link be hidden from public navigation in production (`app.ui.platform-operator-link-visible: false` config)? *Lean: yes, hide in prod; visible in dev profile.*
- **Q2 (bootstrap UUID memorability)**: Use the readable `0fab` suffix or a fully random UUID? *Lean: keep `0fab` — recognizable in audit logs.*
- **Q3 (Sec-Fetch-Site User-Agent allowlist)**: Should we maintain a User-Agent allowlist for legitimate-but-stripped-headers requests (privacy extensions)? *Lean: no for v0.53; revisit if false-rejection reports come in.*

## Deferred follow-ups (warroom 2026-04-25, captured during G-4.2 implementation)

These items were surfaced during the G-4.2 in-progress warroom and intentionally NOT landed in the v0.53 slice. Each is captured here so the next slice / next maintainer can pick them up without re-deriving the rationale.

- **F1 — Single-use scoped tokens (`jti` claim + consumed-token registry).** Per warroom Marcus M4. Today, mfa-setup (10-min TTL) and mfa-verify (5-min TTL) tokens are replayable inside their TTL; `setupMfa` is guarded server-side by the "refuses if already enrolled" check (warroom A4) so the practical replay risk is bounded, but defense-in-depth via single-use tokens is the right next step. Implementation: add `jti = randomUUID()` to scoped tokens; check + insert into a Caffeine `consumedScopedTokens` cache (TTL=token TTL) at controller entry; reject on hit. **Cost:** ~30 LoC + 2 IT scenarios. **Trigger to land:** before adding a UI-driven password-reset flow (which also issues scoped tokens) or before any external pen-test engagement.

- **F2 — `@PlatformAdminOnly` filter MUST assert `mfaVerified = true`.** Per warroom Marcus M5. The G-4.2 platform JWT carries `mfaVerified=true` on access tokens but no consumer asserts it yet (platform endpoints don't ship until G-4.4). When the G-4.4 endpoint migration lands, the corresponding filter — or the {@code JustificationValidationFilter} in G-4.3 §4.4 — must reject any token where `roles` contains `PLATFORM_OPERATOR` but `mfaVerified` is missing or false. Capture as an explicit acceptance criterion in G-4.4 task 5.X.

- **F3 — Full platform-side metrics + MDC marker.** Per warroom Jordan J1, J2. v0.53 ships minimal logging. G-4.5 task 7.X already plans Prometheus alerts; expand the slice to also include the underlying counters: `fabt.platform.jwt.{issued,validated,rejected}{...}`, `fabt.platform.auth.login{outcome=...}`, `fabt.platform.mfa.verify{outcome=...}`, `fabt.platform.mfa.backup_code.consumed`, `fabt.platform.lockout.transitions`, plus the MDC `platform_action: true` marker on every controller entry / aspect emission. The G-4.5 alerts shipped in the same release; without the counters, the alerts have nothing to fire on.

- **F4 — Multi-module split for `fabt-cli`.** Per Decision 8, the CLI was specified as a separate Maven module producing `fabt-cli.jar`. During G-4.2 implementation we discovered the project is single-module (one `pom.xml` under `backend/`), and converting to multi-module touches CI scripts, Docker build paths, IDE configs, and dev-start.sh — all for a CLI that runs once-ever per platform_user activation. **G-4.2 deviation:** ship `org.fabt.cli.HashPasswordCli` as a standalone class inside the backend artifact. Operator invocation: `java -cp /app/app.jar -Dloader.main=org.fabt.cli.HashPasswordCli org.springframework.boot.loader.launch.PropertiesLauncher` (or `htpasswd -bnBC 12` as a Spring-Security-compatible alternative). The original "separate JAR artifact" goal is preserved as F4: when ops volume justifies (e.g., a non-VM deployment target needs the CLI but not the backend), split via `maven-shade-plugin` execution producing `fabt-cli-${version}.jar` with `org.fabt.cli.HashPasswordCli` as the main class — does NOT require multi-module restructure.

- **F5 — Authorized two-party reset flow for locked-out operators.** Per warroom Marcus M1 (review of commit `eb8fcdc`). G-4.2 added `platform_user_reset_to_bootstrap(p_id UUID)` SECURITY DEFINER function in V88 to support the spec line 142-146 recovery flow. The current function is **unauthorized** — any caller running as `fabt_app` can wipe ANY operator's credentials by passing their UUID. Today the only callers are tests; production has no caller. Risk is bounded as long as no operator-facing endpoint calls this function directly (`COMMENT ON FUNCTION` in V88 documents the constraint). **Phase H+ work:** when the recovery endpoint lands, replace the unrestricted call with an authorized variant — e.g. `platform_user_force_reactivate(p_target_id, p_caller_id)` whose body checks `caller is mfa_enabled AND not anonymized AND caller != target` (encoding the spec's "the OTHER platform_user can reset" property at the function level rather than relying on controller-side gating). After the authorized variant ships, `platform_user_reset_to_bootstrap` should be either renamed to `platform_user_test_reset` and moved behind a profile-gated migration, or kept as a private helper called only from the authorized variant. The G-4.3 `@PlatformAdminOnly` aspect MUST then audit the reset action via `PLATFORM_USER_RESET_TO_BOOTSTRAP` (or analogously named) `AuditEventType` value (now folded into G-4.3 task 4.3).

- **F6 — PAL.audit_event_id foreign-key enforcement.** Per warroom G-4.3 design review (Alex A2). G-4.3 ships `platform_admin_access_log` with `audit_event_id UUID NULL` and NO foreign-key constraint to `audit_events.id`. Trade-off: simpler insert ordering (no DEFERRABLE INITIALLY DEFERRED FK complexity in the aspect's REQUIRES_NEW transaction) at the cost of theoretical orphan risk if an `audit_events` row were ever deleted (which is forbidden by Phase B append-only posture, so the risk is hypothetical). **Trigger to land:** if a future compliance audit flags the missing FK, add it as `DEFERRABLE INITIALLY DEFERRED` in a follow-up migration; the aspect's transaction structure already supports both INSERT orders.

- **F7 — Anonymization-aware audit retention.** Per warroom G-4.3 design review (Maria P1). G-4.3's audit chain stores `platform_user_id` in `audit_events.details` (NOT `platform_user_email` per Decision D3 in tasks §4) — but a downstream join against an anonymized `platform_user` row resolves to "anonymized" rather than the original email. For SOC-2 + GDPR Art-17 audit posture, this is acceptable for v0.53: PII flows ONLY through the platform_user table (which respects the anonymization boundary); the audit chain is referential. **Phase H+ work:** when the operator-anonymization tooling ships, decide whether the audit chain entries pointing to anonymized operators should be (a) kept as-is (current proposal — referential resolution shows "anonymized"), (b) updated in place to replace the platform_user_id with a one-way hash (preserves auditability while severing the link), or (c) leave the chain untouched and document the auditability vs anonymization trade-off in the runbook. Trade-off chosen at Phase H requires a warroom synthesis with Maria + Marcus + Riley present — option (a) is the lowest-effort starting point but may not satisfy a full Art-17 review.

- **F8 — True wire-byte SHA-256 in `request_body_excerpt`.** Per warroom Marcus M-RV4 (G-4.3 foundation review). Decision D2 specified `request_body_excerpt = "Content-Type=...;Content-Length=...;SHA-256=<hash>"`. Implementation discovered that by the time the AOP aspect runs, the servlet input stream has been consumed by Spring's `@RequestBody` deserializer — body bytes are no longer available. Emitting `SHA-256(empty string)` for every row is a misleading constant. v0.53 ships with the `SHA-256` segment OMITTED from the format; `Content-Type` + `Content-Length` are real signals; forensic correlation continues via `audit_event_id` against application logs. **Phase H+ work:** if a future compliance review requires true wire-byte body fingerprints, install a `ContentCachingRequestWrapper` filter earlier in the chain to preserve body bytes, then add the SHA-256 to the format. Cost: 1 new filter + 1 cast in the aspect's body-excerpt computation. Acceptable to land late because the `audit_event_id` correlation already provides the same forensic value via application logs.

- **F9 — `audit_events(action, timestamp DESC)` index for cross-table action queries.** Per warroom Elena E-RV3 (G-4.3 foundation review). G-4.3 ships `platform_admin_access_log(action, timestamp DESC)` for compliance queries against PAL. The parallel query against `audit_events` ("show me every PLATFORM_TENANT_HARD_DELETED in 2026 across the audit chain") would benefit from a matching index on `audit_events`. Not blocking: at platform-action volumes (low) the seq scan is acceptable. Land alongside G-4.5's Prometheus alerts when we know the actual query patterns from production usage.

- **F10 — Justification-text quality classifier.** Per warroom Maria P-S2 (G-4.4 design review). The G-4.3 CHECK constraint enforces `length(trim(justification)) >= 10` — prevents trivial "ok" but not low-quality "needed it". For SOC-2 spot-checks this is acceptable as documentation; auditor can flag patterns of low-quality justifications via PAL row inspection. **Phase H+ work:** if a future compliance review requires automated quality enforcement, a server-side classifier (regex-based length-and-vocabulary check, OR a small ML model) could reject submissions below a quality threshold. Out of scope for v0.53 — Decision 10 explicitly says X-Platform-Justification is documentation, not server-validated authority.

- **F11 — Platform-operator UI.** Per warroom Casey C-S3 / Sam S-S1 (G-4.4 design review). v0.53 ships backend-only platform-admin auth + audit. The admin frontend currently uses tenant JWTs to call admin endpoints; post-G-4.4, the 7 platform-scoped endpoints (TenantLifecycleController suspend/unsuspend/offboard/hardDelete, TenantKeyRotationController.rotate, HmisExportController, OAuth2TestConnectionController.test, BatchJobController × 4) only accept platform JWTs. Operators must use curl + the MFA flow until a frontend slice ships. **G-4.5 §6.b** adds a UI shim that hides or grays platform-only buttons when the user's JWT is iss=fabt-tenant. **Future slice (post-G):** ships a `/auth/platform/login` page, MFA enrollment / verify UI, platform-operator dashboard. Coordinate with Devon's training-material work — operators need to know they have TWO logins now (tenant admin + platform operator).

- **F12 — TenantLifecycleController REST endpoints (decided 2026-04-25, lands as G-4.6 in v0.53).** During G-4.4 endpoint inventory we discovered that tasks.md §5.3 referenced a `TenantLifecycleController` (suspend / unsuspend / offboard / hardDelete) that did not actually exist — Phase F shipped `TenantLifecycleService` + the state machine but never landed REST endpoints. Without this slice, tenant lifecycle actions in production happen only via `psql` against the DB owner: no audit row, no MFA gate, no operator identity, no justification. **Decision: add G-4.6 to v0.53.** Cost is ~4-6h (controller is a thin wrapper over the battle-tested service); value is completing the audit-chain story end-to-end so every tenant lifecycle action gets its PAL + chained AE row with operator identity + justification. See G-4.6 §6a in tasks.md for the implementation plan. Out-of-band psql lifecycle actions remain documented in the runbook as emergency-only (and break the audit posture on purpose).

- **F13 — `after_state` capture on PAL (post-G-4.4 limitation).** Per Decision 11, the aspect commits PAL + AE rows BEFORE `proceed()` runs the controller method. By then, `before_state` is available (controller captured it pre-action via `PlatformActionStateCapture.captureBefore`); `after_state` is NOT (the action hasn't run yet). PAL has the append-only trigger from V89/D4 so no UPDATE-after-proceed is possible. v0.53 ships with `before_state` populated and `after_state` always NULL. **Phase H+ options:** (a) Restructure the aspect to commit PAL after proceed (breaks Decision 11 — no audit row on action failure; needs warroom synthesis to weigh against compliance posture); (b) Insert a SECOND companion PAL row post-proceed for the after_state, linked to the original via `correlation_id` (additive but doubles row count); (c) Stash after_state in `audit_events.details` JSONB on a SECOND AE row chained after the first (preserves chain integrity but changes the per-action AE shape). Cost-benefit pending a real compliance-review need; v0.53 ships with the limitation documented + `PlatformActionStateCapture.captureAfter` API in place for forward compat.

- **F14 — cross-tenant operator-driven HMIS push endpoint (G-4.5+).** During G-4.4 triage pass 2 we discovered that `HmisExportController` POST `/api/v1/hmis/push` and the vendor-management endpoints read `TenantContext.getTenantId()` via `HmisPushService.createOutboxEntriesForCurrentTenant()`. Platform JWTs do NOT populate `TenantContext` (Decision 3 + 13), so the mechanical G-4.4 migration to PLATFORM_OPERATOR + @PlatformAdminOnly was incompatible with the service contract — every platform-operator call NPE'd at the tenantId.toString() inside the service. **Reverted to COC_ADMIN** (tenant-scoped) for v0.53: CoC admin is the natural authority for their own tenant's HMIS export, and the V87 backfill ensures every former PLATFORM_ADMIN-bearing user has COC_ADMIN. **Follow-up:** add a NEW endpoint `POST /api/v1/admin/tenants/{tenantId}/hmis/push` (and equivalents for the vendor-management endpoints) that takes tenantId in the path, gates on PLATFORM_OPERATOR + @PlatformAdminOnly + audit chain, and threads the path tenantId through a new `HmisPushService.createOutboxEntriesForTenant(tenantId)` overload (already exists — used by the scheduled batch path) instead of reading TenantContext. This gives the audit story its cross-tenant operator-driven export capability without breaking the existing CoC-admin per-tenant flow. ~3-4h slice, slot in G-4.5 or a dedicated micro-change post-v0.53.

- **F15 — TenantPathGuard removed from @PlatformAdminOnly tenant endpoints (G-4.4 design drift).** During triage pass 2 we discovered that the four @PlatformAdminOnly methods on `TenantController` (update, getObservabilityConfig, updateObservabilityConfig, updateDvAddressPolicy) all called `TenantPathGuard.requireMatchingTenant(id)` as their first line. The guard reads `TenantContext.getTenantId()`, which is null for platform JWTs — so every legitimate platform-operator call 404'd. **Removed the guard from these four methods.** The cross-tenant invariant the guard enforced is now structurally provided by role separation: tenant-scoped JWTs (COC_ADMIN/etc.) cannot reach an @PlatformAdminOnly endpoint at all — Spring Security 403s on the @PreAuthorize gate. The PLATFORM_OPERATOR role is intentionally cross-tenant; "cross-tenant" isn't an attack vector for that role, it's the design intent. The audit chain (PAL row + chained AE row) captures the exact target tenantId from the path variable for compliance review, replacing the per-request guard's role. `TenantPathGuard` itself remains in use for the tenant-scoped endpoints (`TenantConfigController`, `OAuth2ProviderController`) where COC_ADMIN callers still need URL-path-sink protection.

- **F16 — HMIS push authority broadening + audit-chain regression vs G-4.3 baseline (Marcus/Jordan HIGH).** Triage pass 2 reverted `HmisExportController` POST `/api/v1/hmis/push` from `@PreAuthorize("hasRole('PLATFORM_OPERATOR')") + @PlatformAdminOnly` back to `@PreAuthorize("hasRole('COC_ADMIN')")`. Two consequences worth documenting in the v0.53 release notes + runbook BEFORE PR review: (1) **Authority broadening** — pre-G-4.3 the endpoint required `PLATFORM_ADMIN`. The V87 backfill granted `COC_ADMIN` to every PLATFORM_ADMIN-bearing user, but COC_ADMIN exists independently — i.e. CoC admins who never had PLATFORM_ADMIN are NOW authorized to trigger an irreversible outbound integration that exports their tenant's bed inventory to a 3rd-party HMIS vendor. This is a net authority broadening masquerading as a "revert." (2) **Audit-chain regression** — the `@PlatformAdminOnly` aspect that would have written a PAL row + chained `audit_event` no longer fires; only internal service-level audit rows are produced, with no caller-identity capture at the controller boundary. **Mitigations to implement before PR:** add a tenant `audit_event` write inside `manualPush` capturing `userId`, `vendorTypes`, `recordCount`; add a `X-Confirm-HMIS-Push: CONFIRM` header gate parallel to the DV-policy and test-reset patterns to prevent accidental triggers; CHANGELOG + oracle-update-notes-v0.53 must call out both consequences explicitly so CoC pilots are informed. **Long-term:** F14 separately tracks the cross-tenant operator-driven endpoint.

- **F17 — `setupPlatformOperator()` shared bootstrap row caching (Riley/Sam HIGH).** `TestAuthHelper.setupPlatformOperator()` resets and re-activates the same `platform_user` row (id `0000…0fab`) on every call. Each call costs 4 SECURITY-DEFINER round-trips + bcrypt + JWT mint = ~50-200ms. Across the 19 migrated controllers' tests this is ~30s of CI bloat per run. More importantly, if `junit.jupiter.execution.parallel.enabled=true` is ever set (a known Riley/Sam ask for CI speedup), two concurrent tests will collide on the shared row mid-test and one will see the other's TOTP secret / JWT. **Fix:** cache the activated fixture as a `volatile` static inside `TestAuthHelper`, reset only between test classes (`@AfterAll`), not between methods; add an `@implNote` warning that parallel test execution must NOT be enabled until this is rewritten to use per-call UUIDs. ~1h slice; defer to G-4.5 unless CI runtime becomes urgent.

- **F18 — Prometheus alert on `tenant.update.rate{operator=...}` (Marcus MEDIUM).** With TenantPathGuard removed (F15) and PLATFORM_OPERATOR intentionally cross-tenant, the new threat surface is "one compromised platform-operator credential = mass tenant rename / config change with no per-action approval." Justification text is operator-asserted (Decision 10), not gating. **Fix:** add a Prometheus alert in `infra/grafana/alerts/platform-admin.yml` of the form `rate(fabt_platform_admin_actions_total{action=~"PLATFORM_TENANT_.*",operator="$op"}[5m]) > N` that pages oncall when any operator's per-minute rate of tenant mutations exceeds threshold. Document in the runbook that anomalous PAL row volume per operator triggers a security review. Lands in F3 / G-4.5 monitoring buildout.

- **F19 — Platform-operator observability config persistence IT (Elena MEDIUM).** TenantController's @PlatformAdminOnly methods (post-F15) call `tenantService.getConfig(id)` / `updateConfig(id, ...)` from a context where `TenantContext.getTenantId()` is null (platform JWTs do not enter TenantContext). If any service code path transitively touches a table with RLS that depends on `current_setting('app.tenant_id')`, the query is constrained to NULL/no-match and may silently return empty / fail to update — manifesting as "platform operator can read but their write is dropped." `tenant` and `tenant_config` themselves have NO RLS today (per `TestAuthHelper` javadoc), but this is a fragility worth pinning. **Fix:** add an IT in `TenantIntegrationTest` that has the platform-operator PUT observability with `prometheus_enabled=false`, then GET the same config back, asserting the changed value persists. Catches future RLS additions to the join path immediately. ~30 min slice; defer to G-4.5.

- **F20 — Audit gaps on platform-scoped reads + cross-tenant batch metadata reads (Marcus/Alex MEDIUM, deliberate v0.53 decision).** Two related read-side audit gaps surfaced during M-S1 role-table warroom: (a) `TenantController.listAll` / `getById` / `getObservabilityConfig` are PLATFORM_OPERATOR-gated but do NOT carry `@PlatformAdminOnly`, so platform-operator enumeration of tenant metadata produces no PAL row. Reasoning for the decision: requiring `X-Platform-Justification` on every read of the tenant list (loaded 50× a day by ops/billing) generates audit noise without compliance value. The cost is that recon-grade activity isn't logged via PAL. (b) `BatchJobController.list` / `executions` are COC_ADMIN-gated reads that expose cron schedules + execution history of jobs that affect cross-tenant scheduler state — a CoC admin at Tenant A sees metadata for jobs running on Tenant B. No PII / tenant-scoped data leaks through, but the metadata is platform-scope. **Fix path (Phase H+):** decide per compliance-review pressure whether to (1) add a low-noise `@PlatformAdminOnly` variant that suppresses the justification-header requirement for read methods + emits a coalesced PAL row, OR (2) tighten BatchJobController reads to PLATFORM_OPERATOR. Both decisions are deferred to a real compliance-review trigger; v0.53 ships with both gaps documented + acknowledged in the role-migration table.

- **F21 — Karate platform-operator login helper (Riley MEDIUM, deferred follow-up).** Surfaced during PR #163 CI: the `dv-address-policy.feature` "Valid policy change succeeds" Karate scenario broke because the endpoint moved to @PlatformAdminOnly + PLATFORM_OPERATOR + X-Platform-Justification. Karate currently has only tenant-JWT auth helpers (`adminAuthHeader`, `cocadminAuthHeader`, `outreachAuthHeader`) — no platform-operator helper. Adding one requires TOTP code generation in JavaScript + the `/auth/platform/login` + `/verify-mfa` flow, all wired into `karate-config.js`. The scenario was removed from the feature; coverage parity preserved by `DvAddressRedactionTest` backend IT (13 scenarios). **Fix path:** when cross-layer Karate coverage of platform-admin endpoints is needed (likely G-4.5 or later if Karate retention continues — Riley has flagged Karate replacement-by-Playwright as a separate decision), add a `karate-config.js` helper `loginAsPlatformOperator()` that mints a session against the dev-seeded platform_user (id 0fa1 or 0fab) using TOTP secret `JBSWY3DPEHPK3PXP`. ~2-3h slice including TOTP-in-JS implementation.

- **F22 — `fabt_dv_referrals_created_total{source_ip}` cardinality (Marcus/Sam MEDIUM, surfaced during G-4.5 §6.8 implementation).** The metric is unbounded by design — every distinct client IP creates a new Prometheus time series. For the demo deployment the bucket4j 5/hour throttle (§6.7) caps each IP and the audience size is small, so the series count is bounded. For multi-tenant production use, an operator must either (a) configure Prometheus relabel rules to drop the `source_ip` label after the burst alert pages, or (b) disable the counter via a Spring profile and rely on `audit_events` for per-IP forensics. **Fix path:** before any production tenant goes live with this counter enabled, ship a configurable label-mode (e.g. `fabt.metrics.dv.referral.create.source_ip_label=raw|hash16|disabled`) on the bean factory. Hash16 buckets the IP into 16 stable buckets — preserves "single-bucket burst" detection without unbounded cardinality. ~1h slice; defer until a non-demo tenant is on the roadmap.
