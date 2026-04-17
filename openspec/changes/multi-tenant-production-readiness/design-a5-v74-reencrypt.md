# Design: A5 — V74 re-encrypt migration + callsite refactor

**Change:** multi-tenant-production-readiness
**Checkpoint:** A5 (task 2.13)
**Status:** APPROVED 2026-04-17 (warroom pass with Marcus + Jordan + Sam); executing
**Author:** Corey (drafted 2026-04-17 post-merge of Phase 0 + Phase A; see `project_multi_tenant_phase0_resume.md` for upstream state)

---

## 1. Purpose

Close Phase A by converting every existing ciphertext column from the v0 envelope (single-platform-key, Phase 0 format) to the v1 envelope (per-tenant HKDF-derived DEK, Phase A format). Ship in one Flyway migration (V74) + the companion service-layer refactor so every encrypt path on main emits v1 and every decrypt path routes v1 through `decryptForTenant`.

Per A3 D22, V74 is explicitly the one-shot bulk re-encryption. Read-time self-heal is rejected — operator-predictable is worth more than self-healing here.

**Scope (confirmed 2026-04-17):** all four columns per A3 D22, not just task 2.13's literal wording. See §"Resolved questions" Q2.

---

## 2. Affected columns

| Column                                      | Table                      | Purpose enum                    | Current state              | V74 action                 |
|---------------------------------------------|----------------------------|---------------------------------|----------------------------|----------------------------|
| `totp_secret_encrypted`                     | `app_user`                 | `KeyPurpose.TOTP`               | v0 (Phase 0 encrypt-on-save since V31) | v0 → v1 under per-tenant DEK |
| `callback_secret_hash`                      | `subscription`             | `KeyPurpose.WEBHOOK_SECRET`     | v0 (pre-Phase-0 field; always encrypted) | v0 → v1                  |
| `client_secret_encrypted`                   | `tenant_oauth2_provider`   | `KeyPurpose.OAUTH2_CLIENT_SECRET` | v0 (V59 encrypted the plaintext legacy rows under single-platform key) | v0 → v1 |
| `tenant.config → hmis_vendors[].api_key_encrypted` | `tenant` (JSONB)   | `KeyPurpose.HMIS_API_KEY`       | v0 (V59 encrypted JSONB-embedded plaintext under single-platform key) | v0 → v1 |

Column naming quirks:
- `subscription.callback_secret_hash` is misnamed (it stores ciphertext, not a hash). Renaming is out of scope for V74; noted in `project_*` followups for a future housekeeping migration.
- `tenant.config` is JSONB — V74 re-walks the `hmis_vendors[]` array, same pattern as V59's JSONB path.

---

## 3. Migration design (V74)

### D30 — Java Flyway migration, not SQL

Decrypt/re-encrypt requires JCE + KeyDerivationService + KidRegistryService. SQL cannot express that. Same pattern as V59.

Location: `backend/src/main/java/db/migration/V74__reencrypt_secrets_under_per_tenant_deks.java`. Package `db.migration` is mandatory — Flyway scans it by name; moving under `org.fabt.*` silently drops the migration.

### D31 — Idempotency via magic-byte skip

Each candidate value is Base64-decoded; `EncryptionEnvelope.isV1Envelope(decoded)` is consulted. v1 → skip. Non-v1 → treat as v0 and re-wrap. A partial-failure re-run is safe (already-v1 rows skipped; already-v0 rows re-processed correctly).

### D32 — Per-row transaction? Or one transaction?

**Decision: one transaction** — Flyway's default, matches V59. Oracle Always Free at pilot scale (~10 users, ~0–5 subscriptions, ~1 tenant) means the transaction is trivially small. For future scale, V74 re-run with idempotent skip handles partial-commit cleanly, so a future PG14 backpressure event doesn't require a schema change — just re-run the migration.

Documented explicitly in the migration's class-level Javadoc so a future operator with 10k users doesn't inherit an unexamined single-transaction assumption.

### D33 — Tenant ID resolution

- `app_user.totp_secret_encrypted` → `app_user.tenant_id` (direct column)
- `subscription.callback_secret_hash` → `subscription.tenant_id` (direct column)
- `tenant_oauth2_provider.client_secret_encrypted` → `tenant_oauth2_provider.tenant_id` (direct column)
- `tenant.config → hmis_vendors[].api_key_encrypted` → the owning `tenant.id` (JSONB lives on the tenant row)

Migration uses raw `PreparedStatement` — no Spring Data JDBC dependency, no `TenantContext` binding required. HKDF + KidRegistryService are instantiated directly from the master KEK bytes + a local JDBC-backed KidRegistry helper (since the application Spring context isn't bootstrapped when Flyway runs).

### D34 — KID registration path

Every re-encrypt needs a `kid` registered in `kid_to_tenant_key`. The migration uses the same `findOrCreateActiveKid(tenantId)` contract as runtime, but implemented inline against the JDBC connection (no Spring bean wiring). Pattern:

```java
UUID findOrCreateActiveKid(Connection conn, UUID tenantId) {
    // 1. SELECT kid FROM kid_to_tenant_key
    //    WHERE tenant_id = ? AND key_generation = (SELECT jwt_key_generation FROM tenant WHERE id = ?) AND active = TRUE
    // 2. If present → return.
    // 3. Else INSERT ON CONFLICT DO NOTHING + re-SELECT (race-safe; matches runtime path).
}
```

Why inline: the runtime `KidRegistryService` uses Caffeine + Spring-managed JdbcTemplate, and dragging a partial Spring context into a Flyway migration is worse than duplicating 15 lines of SQL. The integration test verifies the migration produces the same `kid_to_tenant_key` state the runtime path would produce.

### D35 — Audit row contract

Single `SYSTEM_MIGRATION_V74_REENCRYPT` row into `audit_events`, same transaction. Details JSONB shape:

```json
{
  "migration": "V74",
  "totp_reencrypted": 0,
  "webhook_reencrypted": 0,
  "oauth2_reencrypted": 0,
  "hmis_reencrypted": 0
}
```

(Zero-count fields still included so downstream queries don't have to handle missing-key vs zero ambiguity.)

### D36 — Dev-environment skip

Mirror V59: if `FABT_ENCRYPTION_KEY` is unset, log WARN and return cleanly. No audit row. Protects dev/CI shells where encryption isn't configured.

Note: in prod, `FABT_ENCRYPTION_KEY` is required by the Phase 0 C2 + Phase A4 W-A4-3 startup guards — application won't boot without it. So the dev-skip branch is unreachable in prod; it exists solely for the Testcontainers-without-encryption-key scenario.

### D37 — Rollback

Flyway atomic transaction means partial-failure = full rollback = no change to data. Explicitly NOT reversible once committed — there's no V-back migration that un-re-encrypts v1 back to v0. Defense-in-depth: any v0-era operator backup can be restored independently, and the runtime v0-fallback read path stays alive permanently (D22) so a corrupted V74 commit doesn't brick the deploy.

Rollback runbook entry: "if V74 fails mid-commit, Flyway rolls back automatically. If V74 commits but application startup fails for unrelated reasons, the v1 ciphertexts on disk are still readable via the runtime v1 path — no data-layer rollback required."

---

## 4. Service-layer refactor

### D38 — Signature changes (non-backward-compatible within the repo)

| Service                          | Before                                             | After                                                                     |
|----------------------------------|----------------------------------------------------|---------------------------------------------------------------------------|
| `TotpService.encryptSecret`      | `String encryptSecret(String plaintext)`           | `String encryptSecret(UUID tenantId, String plaintext)`                   |
| `TotpService.decryptSecret`      | `String decryptSecret(String encrypted)`           | `String decryptSecret(UUID tenantId, String encrypted)`                   |
| `SubscriptionService.create`     | already takes `callbackSecret` → encrypts internally | internally calls `encryptForTenant(tenantId, WEBHOOK_SECRET, ...)`; tenantId from `TenantContext` (unchanged at the API boundary) |
| `SubscriptionService.decryptCallbackSecret` | `String decryptCallbackSecret(String)`  | `String decryptCallbackSecret(UUID tenantId, String)`                     |
| `TenantOAuth2ProviderService.*`  | `encryptionService.encrypt(clientSecret)`          | `encryptForTenant(tenantId, OAUTH2_CLIENT_SECRET, clientSecret)`          |
| `HmisConfigService.encryptApiKey`| `String encryptApiKey(String plaintext)`           | `String encryptApiKey(UUID tenantId, String plaintext)`                   |
| `HmisConfigService.decryptApiKey`| `String decryptApiKey(String stored)`              | `String decryptApiKey(UUID tenantId, String stored)`                      |
| `DynamicClientRegistrationSource` | `encryptionService.decrypt(stored)` fallback path | `decryptForTenant(tenantId, OAUTH2_CLIENT_SECRET, stored)`                |

Why not keep both signatures and let old callsites resolve against a default-tenant shim: a silent fallback hides a wiring bug. Compile-break is the goal.

### D39 — Callsite updates (5 files)

| File                                        | Line            | Change                                                        |
|---------------------------------------------|-----------------|---------------------------------------------------------------|
| `TotpController.enrollTotp`                 | ~80             | pass `user.getTenantId()` to `encryptSecret`                  |
| `TotpController.confirmTotpEnrollment`      | ~118            | pass `user.getTenantId()` to `decryptSecret`                  |
| `AuthController` (MFA login verify)          | ~327            | pass `user.getTenantId()` to `decryptSecret`                  |
| `WebhookDeliveryService` (normal delivery)  | ~283            | pass `subscription.getTenantId()` to `decryptCallbackSecret`  |
| `WebhookDeliveryService` (test delivery)    | ~129            | pass `subscription.getTenantId()` to `decryptCallbackSecret`  |

### D40 — `isEncryptionConfigured()` branch stays

`TotpController.enrollTotp` still returns 503 when encryption is unconfigured. In prod this is unreachable (startup fail-fast), but dev/CI needs the graceful degradation. Leave it.

### D41 — `encryptionService.encrypt/decrypt` deprecation

The un-typed legacy methods (`String encrypt(String)`, `String decrypt(String)`) must remain public for the V74 migration itself (it needs to decrypt v0 under the platform key without a tenant binding). Mark `@Deprecated(since = "v0.42", forRemoval = false)` with Javadoc pointing to `encryptForTenant` / `decryptForTenant`. A follow-up Phase M task can package-private them.

ArchUnit rule (Phase L family F): application code outside `org.fabt.shared.security` + `db.migration` may not call the deprecated methods. Not in A5 scope — added alongside Phase L's family F activation.

---

## 5. Dual-key-accept grace window

### D42 — Indefinite, NOT 7-day

Per A3 D22 the v0 fallback path (`CiphertextV0Decoder.decrypt`) stays alive **forever** as defense-in-depth. The OpenSpec scenario "Grace window closes after 7 days" (per-tenant-key-derivation spec §ciphertext-reencryption-migration) contradicts D22 and must be removed as part of the OpenSpec-sync pass.

Why indefinite:
- If V74 commits cleanly, no v0 rows remain → the fallback path is dead code but costs nothing.
- If a row was locked / skipped / partially-corrupted, the fallback preserves availability (TOTP still works for that user; webhook still signs).
- A 7-day flag adds a failure mode (operator-forgets-to-flip, operator-flips-early) with no upside.

Operator-facing statement (runbook 2.16): "V74 re-encrypts all known ciphertexts under per-tenant DEKs. The v0 fallback decrypt path remains permanently available as defense-in-depth. No grace-window closure step is required."

---

## 6. Integration test plan

One dedicated IT class: `V74ReencryptIntegrationTest` (under `org.fabt.migration` — since V59 has precedent there as `V59ReencryptPlaintextCredentialsTest`).

### T1 — Happy-path round-trip
- GIVEN seed: 2 tenants, 1 user with v0 TOTP per tenant, 1 subscription per tenant, 1 OAuth2 provider per tenant, 1 HMIS vendor per tenant (all v0 envelopes).
- WHEN V74 runs.
- THEN every row's stored value is v1 (`isV1Envelope == true`); plaintext decrypts identically before and after via runtime decryptForTenant.

### T2 — Idempotency on re-run
- Run V74 twice. Second run skips all rows (magic-byte check). Audit row fires once.

### T3 — Cross-tenant DEK separation verified
- Tenant A's v1 TOTP ciphertext cannot be decrypted under Tenant B's DEK (AEAD tag mismatch → `CrossTenantCiphertextException` at runtime).

### T4 — Partial-pre-commit (row-level) recovery
- Insert 1 v1 row manually (simulating a partial deploy). V74 skips it; migrates the rest. Audit row still fires.

### T5 — Empty table no-op
- Tenant with no TOTP / no webhook / no OAuth2 / no HMIS → V74 writes audit row with zero counts; no data changes.

### T6 — FABT_ENCRYPTION_KEY unset → clean skip
- Use a Testcontainers variant without the env var (or, easier, set it to blank via `@DynamicPropertySource`). V74 logs WARN, writes no audit row, mutates no data.

### T7 — V0 ciphertext that was V59-produced unwraps cleanly
- Specifically seed an OAuth2 provider via the V59 code path (plaintext → v0). V74 detects v0 correctly and produces v1. Guards against the case where V59's envelope shape drifts.

### T8 — kid_to_tenant_key rows created for tenants that didn't yet have a kid
- Tenant that existed pre-Phase-A with v0 secrets but zero runtime encrypt calls (so no kid was ever registered). V74 must create the kid as part of the re-encrypt. Post-run: `SELECT COUNT(*) FROM kid_to_tenant_key WHERE tenant_id = ?` ≥ 1.

### T9 — Audit row shape
- `action = SYSTEM_MIGRATION_V74_REENCRYPT`, details JSONB carries all four count fields, counts are accurate.

### T10 — Service-layer refactor ITs stay green
- `TotpServiceIntegrationTest`, `SubscriptionServiceIntegrationTest`, `TenantOAuth2ProviderServiceIntegrationTest`, `HmisConfigServiceIntegrationTest` — all exercise the v1 round-trip post-refactor. Add assertions that stored value is `isV1Envelope == true`.

---

## 7. Risk register

| Risk                                                                 | Mitigation                                                                                  | Residual |
|----------------------------------------------------------------------|---------------------------------------------------------------------------------------------|----------|
| Operator runs v0.41 (Phase 0 only) then v0.42 (Phase A + V74) — V74 refs Phase A tables | Phase A + V74 must ship in the same release. v0.42 release notes lock this explicitly. No Phase-0-only release. | None — release process controls it. |
| V74 crashes mid-migration (GCM failure, bad envelope) | Flyway rolls back entire transaction → DB unchanged. Startup fails with clear Flyway error. | None — Flyway semantics. |
| New `kid_to_tenant_key` rows created by V74 race with a concurrent first-encrypt from a live request | Impossible — Flyway migrations run pre-application-boot. No HTTP traffic yet. | None. |
| Audit row row-count doubles on re-run (operator fears drift) | Idempotency-skip logic checks magic-byte BEFORE update; re-run still emits a SYSTEM_MIGRATION_V74_REENCRYPT row with zeroes. Not a data-drift risk — just extra audit rows. | Acceptable — parallels V59 behavior. |
| `tenant.config` JSONB mutation loses a concurrent edit made post-startup | Same as above — migrations run pre-boot. No concurrent edits possible. | None. |
| Dev-skip path (FABT_ENCRYPTION_KEY unset) masks a prod misconfig | Phase 0 C2 + Phase A W-A4-3 startup guards already fail-fast in prod. The migration's skip is unreachable in prod. | None. |
| V74 forgets a column (e.g., HMIS JSONB array item) → some rows stay v0 | Integration tests T1 + T7 seed every column and assert v1 post-migration. T10 re-runs the full service-layer refactor IT suite. | Covered. |
| Service refactor introduces a compile break the IDE misses | Compile is the gate. Java rejects mismatched signatures. `mvn verify` must be green pre-merge. | Covered. |
| `TotpController.disableUserTotp` nulls the secret — no re-encrypt needed — but V74 passes over the row → must tolerate null | V74 `WHERE totp_secret_encrypted IS NOT NULL` filter. Standard defensive SQL. | Covered. |
| Runtime `decryptForTenant` encounters a v0 row AFTER V74 because a row was skipped by V74 (e.g., transient lock) | The runtime v0 fallback path (D22) decrypts under platform key. Caller keeps working. A subsequent V74-rerun cleans up. | Acceptable. |
| V74 emits a `kid_to_tenant_key` row for a tenant that later gets SUSPENDED pre-first-login | Benign — the kid is tied to generation 1. If suspend bumps to generation 2, the old kid goes into `jwt_revocations` via the normal path. No V74-specific concern. | None. |

---

## 8. Out of scope

- Column rename `subscription.callback_secret_hash` → `callback_secret_encrypted` (separate housekeeping migration; noted in followups).
- HashiCorp Vault Transit path (task 2.15 — still deferred, no pilot demand).
- ArchUnit Family F rule forbidding application-code use of un-typed `encrypt`/`decrypt` (Phase L).
- Master-KEK rotation (Phase C/L).
- Key-rotation runbook text (task 2.16 — docs-only PR alongside v0.42).

---

## 9. Warroom questions

### Q1 — 7-day grace closure in the OpenSpec scenario contradicts A3 D22. Accept scenario removal?

**Proposed answer:** Yes. Scenario "Grace window closes after 7 days" is sync'd out of `per-tenant-key-derivation/spec.md`. Replaced with a scenario affirming indefinite v0 fallback for defense-in-depth, matching D22.

### Q2 — V74 scope: strict task 2.13 (2 columns) vs A3 D22 (4 columns)?

**Resolved 2026-04-17 (Corey):** All 4 columns. Rationale in §1 purpose.

### Q3 — Inline KidRegistry JDBC duplicate of runtime bean logic?

**Proposed answer:** Yes, acceptable. 15-line SQL duplication is cheaper than dragging a partial Spring context into Flyway. The integration test compares the post-V74 `kid_to_tenant_key` state to what a runtime first-encrypt would have produced — duplication-drift is caught in CI.

### Q4 — Single-transaction migration — scale concern?

**Proposed answer:** Acceptable for pilot scale (≤10 users, ≤5 subscriptions per tenant, ≤1 tenant at deploy). Documented in the class Javadoc. If a future tenant onboards 100k users, V74 re-runs are idempotent — schema change not required.

### Q5 — `encryptionService.encrypt`/`decrypt` deprecation — keep or break public surface?

**Proposed answer:** Keep public but `@Deprecated`. V74's migration code itself needs the platform-key path, and that code is in `db.migration` package. Removing the methods forces reflective hacks; deprecating documents the direction of travel without causing unnecessary work.

### Q6 — Should V74 also clean up V59's audit row (merge the two system-migration entries)?

**Proposed answer:** No. V59 was a distinct event (plaintext → v0). V74 is a distinct event (v0 → v1). Two rows = accurate history. Merging would erase forensic ground truth.

### Q7 — Service-refactor: should `SubscriptionService.create` accept `tenantId` explicitly (API signature change) or pull from `TenantContext` internally?

**Proposed answer:** Pull from `TenantContext` internally. Matches the existing design-D11 pattern (service methods MUST NOT accept `tenantId` as a parameter). The refactor is entirely internal to `SubscriptionService.create`'s body.

### Q8 — `TotpService` tenantId — who passes it?

**Proposed answer:** The controller layer (`TotpController`, `AuthController`) has the `User` in hand and passes `user.getTenantId()`. `TotpService` does NOT accept `TenantContext` — intentional, because the TOTP login-verify flow runs BEFORE `TenantContext` is bound (JWT hasn't yet been validated; there's no context to bind to).

### Q9 — Post-V74, can we drop the v0 fallback decrypt from `HmisConfigService.decryptApiKey` and `DynamicClientRegistrationSource` (the plaintext-tolerance branches)?

**Proposed answer:** No, not in A5. Those fallbacks handle the case where the *plaintext* was somehow written post-V59 (e.g., an admin direct DB edit). Separate concern from V74. Revisit under Phase L when ArchUnit Family F lands.

### Q10 — V74 rollback — if the deploy must be reverted (back to v0.41), what happens?

**Proposed answer:** v0.41 code does not understand v1 envelopes. Every TOTP verify + webhook signing would fail. v0.41 → v0.42 is effectively one-way. Release notes must state this; operator runbook for v0.42 includes a pre-deploy backup step.

---

## 10. Follow-ups filed post-PR

- **GH Issue:** `subscription.callback_secret_hash` column rename → `callback_secret_encrypted` + migration.
- **GH Issue (reference only — lives in task 2.16):** key-rotation runbook must call out "V74 is irreversible without a pre-deploy backup."
- **OpenSpec note in `project_multi_tenant_phase0_resume.md`:** mark task 2.13 [x] post-merge; strip the 7-day-grace claim from the Phase A.5 followups list.

---

## 11. Warroom resolutions (2026-04-17)

Three independent adversarial reviewers (Marcus Webb / security, Jordan / DBA, Sam / SRE) audited this design. Consolidated findings below.

### C-A5-N1 — `SET LOCAL` lock + statement timeouts at migrate() start (Jordan)

`migrate()` first statement: `SET LOCAL lock_timeout = '30s'; SET LOCAL statement_timeout = '5min';`. Standard Elena-pattern. Protects the deploy from an orphaned background lock pinning V74 indefinitely. Pre-existing gap in V59; not blocking V59 retrofit but V74 must have it.

### C-A5-N2 — `WHERE tenant_id IS NOT NULL` + preflight (Jordan)

Every candidate SELECT includes `AND tenant_id IS NOT NULL`. Migration opens with a preflight:

```sql
SELECT COUNT(*) FROM app_user WHERE totp_secret_encrypted IS NOT NULL AND tenant_id IS NULL;
-- same for subscription, tenant_oauth2_provider
```

If any count > 0, WARN-log the drift with row counts and proceed (re-encrypt the ones we can; don't crash the migration). Operator-visible in the audit JSONB as `skipped_null_tenant_id` (per Sam #10).

### C-A5-N3 — Round-trip verify per re-encrypted row (Marcus)

For every row V74 re-encrypts:

```java
String reencrypted = encryptForTenant(tenantId, purpose, plaintext);
String verify = decryptForTenant(tenantId, purpose, reencrypted);
if (!plaintext.equals(verify)) throw new IllegalStateException("V74 round-trip mismatch for (table, id): ...");
```

<1ms per row at pilot scale. Catches tenant_id drift, GCM mis-keying, HKDF salt drift. Fails the Flyway transaction loudly rather than writing corrupted v1.

### C-A5-N4 — v0 fallback observability (Marcus)

Per D42 the v0 fallback stays alive indefinitely. To catch post-V74 downgrade attacks + silent-skipped-row drift:

- **Counter:** `fabt.security.v0_decrypt_fallback.count` tagged by `purpose` + `tenant_id`. Incremented inside `SecretEncryptionService.decryptForTenant` when `isV1Envelope == false`.
- **Audit event:** action `CIPHERTEXT_V0_DECRYPT` with JSONB `{tenantId, purpose, actorUserId?}`. Throttled to once-per-(tenant, purpose, 60s) window to avoid flood.
- **Grafana alert (documented in runbook 2.16, not created in this PR):** fires on any non-zero 1-hour rate 7 days after v0.42 deploy — by then V74 should have swept clean and any v0 read is either a stuck row we need to investigate OR an attack.

### C-A5-N5 — JSONB parser hardening (Marcus)

`ObjectMapper` used by V74's `tenant.config` walker configured with explicit `StreamReadConstraints`:

```java
.streamReadConstraints(StreamReadConstraints.builder()
    .maxNestingDepth(64)
    .maxStringLength(1_048_576)  // 1 MB
    .maxNumberLength(1_000)
    .build())
```

Defends against malicious tenant `config` JSONB crafted to blow Jackson defaults. Same hardening retroactively applies to V59 — filed as follow-up.

### C-A5-N6 — Flyway runtime role documented + verified (Marcus / Jordan)

Migration class-level Javadoc explicitly states:

> "V74 writes to `audit_events`, `kid_to_tenant_key`, `app_user`, `subscription`, `tenant_oauth2_provider`, `tenant`. Must run as a role with BYPASSRLS or as the table owner — verify via `SELECT current_user, session_user` logged at migrate() start. Failure to do so causes RLS to silently filter writes."

Pre-deploy runbook (task 2.16) mandates `SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = '<flyway-role>'` and fails deploy if neither is true.

Integration test `V74RestrictedRoleTest` runs V74 under a deliberately restricted role; expected failure is loud (not silent-filtered).

### C-A5-N7 — Phase A preflight (Marcus)

Migration opens with:

```sql
SELECT 1
FROM flyway_schema_history
WHERE version IN ('60', '61') AND success = true
HAVING COUNT(*) = 2;
```

If not exactly 2 rows, throw `FlywayMigrationException` with actionable message. Protects against release-notes drift shipping a Phase-0-only v0.41.x without Phase A.

### C-A5-N8 — Release gate + version-skew safety (Marcus / Sam)

Consolidates the "one-way deploy" risk into two concrete gates:

1. **Tag script / CI check:** `release-check.yml` GHA workflow verifies the tagged commit is a descendant of both Phase A squash (`949778b`) and V74 squash (TBD) before allowing a `v0.42.x` tag to publish. No Phase-0-only v0.41.x line is valid — documented explicitly in `CHANGELOG.md` under the `[Unreleased]` heading.
2. **v0.41 refuses v1 envelopes gracefully:** the v0.41 codebase doesn't exist to modify, but v0.42's `CHANGELOG.md` must LEAD with: "v0.41 → v0.42 is effectively one-way; rollback requires restoring from the pre-V74 pg_dump backup taken per runbook 2.16. Do NOT deploy v0.41 container image on a database where V74 has applied."

### C-A5-N9 — Dev-skip recovery (Jordan)

Migration class Javadoc includes:

> "If FABT_ENCRYPTION_KEY is unset at migrate-time, V74 skips silently and Flyway marks version 74 as APPLIED. Setting the env var later and restarting does NOT re-run V74; the v0 rows stay v0 permanently, falling back to the v0 decrypt path every read. To recover in dev: `DELETE FROM flyway_schema_history WHERE version = '74'; ./dev-start.sh restart`. This scenario CANNOT occur in prod — the Phase 0 C2 + Phase A W-A4-3 startup guards fail-fast before Flyway even runs without the key."

### C-A5-N10 — Expanded audit JSONB (Sam)

Audit row details JSONB becomes:

```json
{
  "migration": "V74",
  "started_at": "2026-04-17T23:42:01.123Z",
  "completed_at": "2026-04-17T23:42:01.847Z",
  "duration_ms": 724,
  "master_kek_fingerprint": "<first-8-hex-of-HMAC-SHA256(master_kek, 'v74-audit-fingerprint')>",
  "flyway_role": "fabt",
  "totp_reencrypted": 0,
  "totp_skipped_already_v1": 0,
  "totp_skipped_null_tenant": 0,
  "webhook_reencrypted": 0,
  "webhook_skipped_already_v1": 0,
  "webhook_skipped_null_tenant": 0,
  "oauth2_reencrypted": 0,
  "oauth2_skipped_already_v1": 0,
  "oauth2_skipped_null_tenant": 0,
  "hmis_reencrypted": 0,
  "hmis_skipped_already_v1": 0
}
```

Built via `objectMapper.writeValueAsString(Map.of(...))` — not `String.format` (kills the SQL-injection-adjacent pattern V59 inherited; W2 Marcus).

Fingerprint is one-way HMAC of the master KEK under a fixed label — proves V74 ran under the same KEK later reads will use, without leaking the KEK. A KEK-misconfig between V74 commit and first v1 read is a known latent-wedge risk; the fingerprint is the forensic anchor.

### Strong warnings landing with this PR

- **W-A5-1 (Marcus W2):** audit JSONB via `objectMapper.writeValueAsString(Map.of(...))`. Applied.
- **W-A5-2 (Marcus W3):** T4 expanded to include: (a) v1 envelope with unregistered kid — V74 skips; (b) v1 envelope with truncated ciphertext — V74 skips; (c) v1 envelope with kid belonging to a different tenant — V74 skips + logs WARN. Planned.
- **W-A5-3 (Marcus W6):** T11 iterates `KeyPurpose.values()` round-trip. Catches future enum additions. Planned.
- **W-A5-4 (Marcus W4):** `SELECT ... FOR UPDATE` on candidate rows. Near-zero cost. Applied.
- **W-A5-5 (Sam):** `CiphertextV0Decoder` class-level Javadoc carries "DO NOT REMOVE — defense-in-depth per design-a5-v74 D42." Applied in code.
- **W-A5-6 (Sam C-A5-N2):** V74 emits structured log line `"V74 COMMITTED — re-encrypted {T} TOTP / {W} webhook / {O} OAuth2 / {H} HMIS rows in {D}ms"` as the final statement of `migrate()`. Oracle-update-notes references grep pattern. Applied.
- **W-A5-7 (Sam C-A5-N4):** migration class Javadoc adds "Memory footprint" paragraph: "All candidate ciphertexts are loaded into JVM heap for round-trip decrypt+encrypt. At pilot scale (≤10 users × 1 TOTP + ≤5 subscriptions × 1 callback secret ≈ tens of KB) this is trivial. If the target schema has > 10k re-encryptable rows per column, re-evaluate this migration in favor of batched per-row transactions." Applied.

### Warnings filed as follow-ups (NOT in this PR)

- **Marcus W1 (constant-time magic compare):** `isV1Envelope` uses early-exit byte compare. Not security-meaningful at pilot scale (platform key is 256-bit; magic is fixed known string). Filed as `security/constant-time-envelope-magic` follow-up, Phase L.
- **Marcus W5 (ArchUnit rule scope):** Phase L Family F concern. Deferred.
- **Jordan W3 (manual flyway migrate forbidden):** operator-facing runbook warning. Lands in task 2.16 runbook.
- **Jordan W5 (jwt_key_generation ↔ tenant_key_material preflight):** V74 preflight checks this; code-level, not separate follow-up.
- **Sam W1 (legacy encrypt/decrypt log warning):** filed as `security/legacy-encrypt-runtime-warning` follow-up, Phase L.

### Questions resolved

- **Q1 — 7-day grace removal:** Accepted. Spec scenario stripped via `/opsx:sync`.
- **Q2 — 4-column scope:** Confirmed (Corey 2026-04-17).
- **Q3 — Inline KidRegistry:** Accepted. Marcus's enhancement: shared `public static final String` constant for the INSERT SQL, consumed by both runtime and V74. Applied.
- **Q4 — Single-transaction at scale:** Accepted for pilot; Javadoc captures 10k-row threshold + WAL bloat note (Jordan).
- **Q5 — `@Deprecated` direction:** Changed to `forRemoval = true` targeting Phase L (Marcus).
- **Q6 — Two audit rows (V59 + V74):** Accepted, two rows.
- **Q7 — `SubscriptionService.create` signature:** Accepted, internal refactor only (D11 pattern preserved).
- **Q8 — TotpService tenantId from controller:** Accepted + Javadoc explaining why (Marcus).
- **Q9 — Drop plaintext tolerance fallbacks:** Deferred to Phase L.
- **Q10 — Rollback:** Reworded per Sam W3; full outage surface enumerated: MFA login + webhook signing + OAuth2 SSO + HMIS outbound all break on v0.41 rollback against v0.42 DB.

