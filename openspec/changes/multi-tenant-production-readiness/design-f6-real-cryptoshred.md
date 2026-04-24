# Design: F-6.0 — Real crypto-shred via per-tenant wrapped DEKs

**Change:** multi-tenant-production-readiness
**Checkpoint:** F-6.0 (prework for task 7.8)
**Status:** GO-WITH-FIXES 2026-04-24 pass-2 (warroom: Alex + Sam + Marcus + Jordan + Riley) — pass-1 5 blockers + pass-2 5 blockers all folded in; Appendix A complete; §11 test strategy + §12 ship checklist locked
**Author:** Corey (drafted post-F-5 after TDD anchor `CryptoShredGapIntegrationTest` exposed the §D11 gap)

---

## 1. Why this design exists

§D11 of the umbrella change claims `hardDelete()` crypto-shreds all per-tenant secrets by deleting `tenant_key_material` + `kid_to_tenant_key`. Warroom 2026-04-24 found that false:

- `KeyDerivationService.deriveXxxKey(tenantId)` is pure HKDF-SHA256 of `(master_KEK, tenantId_bytes, "fabt:v1:<tenantId>:<purpose>")`.
- No tenant-local state is persisted anywhere — DEKs are recomputed on every encrypt/decrypt.
- Deleting the registry tables closes the `decryptForTenant` path (kid lookup fails) but deletes **nothing the adversary actually needs**: given `master_KEK` + `tenantId` + any pre-shred ciphertext, an attacker recomputes the DEK and decrypts via raw AES-GCM in milliseconds.

The TDD anchor `backend/src/test/java/org/fabt/shared/security/CryptoShredGapIntegrationTest.java` (commit `b5672da`) pins the failing state:

> `CRYPTO-SHRED GAP: adversary recovered `SHRED-CANARY-<uuid>` post-shred.`

This design lands the real shred: **per-tenant random DEKs wrapped under a master-KEK-derived wrapping key, with the wrapped ciphertext living in a new `tenant_dek` table that `hardDelete()` removes**. Post-shred, the DEK cannot be reconstructed from host state alone — the attacker needs a pre-shred DB backup + master_KEK, which is a backup-hygiene problem, not a crypto property.

---

## 2. Threat model (what this shred defends against — and what it doesn't)

### Defends against

| Threat | Pre-shred | Post-shred |
|---|---|---|
| pg_dump of **post-shred** `tenant_dek` leaked | Plaintext recoverable | ❌ No wrapped_dek row exists → DEK gone forever |
| Attacker with master_KEK + raw HKDF call on running system | Already protected by kid check | Wrapped DEK is missing → cannot unwrap |
| Attacker with `ARCHIVED` tenant's ciphertexts on disk | Blocked by state guard | Ciphertext orphaned; DEK gone |
| Compromised pod reading `TenantDekService` cache during ARCHIVED→DELETED window | Would serve unwrapped DEK up to 1h | ❌ Cache invalidation fires on transition to OFFBOARDING/ARCHIVED (see §5); window closes to event-propagation-time |

### Does NOT defend against

| Threat | Reason |
|---|---|
| Pre-shred DB backup + master_KEK compromise | Backup contains wrapped_dek rows. Backup-retention hygiene is a separate control (encrypted offsite backups, shorter retention on archived tenants). NIST SP 800-88 Rev 2 explicitly scopes "Crypto Erase" to operational storage. |
| Attacker with `FABT_ENCRYPTION_KEY` AND `tenant_dek` contents (both) | Defeats envelope encryption by definition. This is why master_KEK must live outside the same blast radius as the DB (env var, not DB column). |
| JWT forgery post-shred | Deliberate — JWT signing keys stay HKDF-derived (see §7). Tokens expire in ≤15 min; post-shred tenant-state check rejects them anyway. |

---

## 3. Cryptographic scheme

### D60 — Key-wrap primitive

**AES-KWP** (Key Wrap with Padding, RFC 5649; NIST SP 800-38F §6.3). Justification:

- NIST-approved for protecting CSPs (critical security parameters).
- Deterministic for the same (wrapping_key, plaintext_key) pair → idempotent re-wrap during rotation.
- 8-byte overhead per wrap → 40 bytes wrapped output for a 32-byte DEK.
- Ships in JDK 17+ as `Cipher.getInstance("AESWrapPad")`. No BouncyCastle dependency.

Rejected: AES-GCM for wrapping (IV management overhead, no material benefit over KWP for static-key wrapping), OAEP (asymmetric — overkill, slower, and we have no asymmetric key on hand).

### D61 — Wrapping key derivation

```
wrapping_key = HKDF-SHA256(
    ikm  = master_KEK_bytes,
    salt = tenantId_bytes (16 bytes),
    info = "fabt:v1:<tenantId>:kek-wrap",
    L    = 32 bytes
)
```

New purpose `"kek-wrap"` — added to `KeyDerivationService` as a **private** internal accessor callable only from `TenantDekService`. **This key never encrypts user data directly.** ArchUnit rule (Family F-6) enforces that only `TenantDekService` references `deriveKekWrappingKey`.

Why deterministic HKDF here is OK: the wrapping key is only used to wrap/unwrap the random DEK. The DEK itself is random; deleting `wrapped_dek` leaves nothing to unwrap. An adversary recomputing the wrapping key gains nothing without a `wrapped_dek` row.

### D62 — DEK generation

On first encrypt for `(tenant, purpose)`:

```
dek = SecureRandom.nextBytes(32)         // 256-bit random
wrapped_dek = AES-KWP-Wrap(wrapping_key, dek)
INSERT INTO tenant_dek (kid, tenant_id, purpose, generation, wrapped_dek, active)
  VALUES (random_uuid(), tenant_id, purpose, 1, wrapped_dek, TRUE)
ON CONFLICT DO NOTHING                   -- race safety, ANY conflict
```

Random DEK (not HKDF-derived) is what makes the scheme shreddable.

**Warroom 2026-04-24 (Sam) blocker fix — no ON CONFLICT target.** The
table has TWO unique indexes: `(tenant_id, purpose, generation)` and the
partial `(tenant_id, purpose) WHERE active = TRUE`. A named conflict
target covers only ONE index; a concurrent first-encrypt + concurrent
rotation could hit the partial index and raise `23505` out of band.
Dropping the target (bare `ON CONFLICT DO NOTHING`) absorbs any unique
violation, matching V61 line 156's proven pattern for the kid tables.

---

## 4. Schema — V82

```sql
-- V82__tenant_dek_schema.sql

CREATE TABLE tenant_dek (
    kid          UUID PRIMARY KEY,
    tenant_id    UUID NOT NULL,
    purpose      VARCHAR(32) NOT NULL,
    generation   INT NOT NULL DEFAULT 1,
    wrapped_dek  BYTEA NOT NULL,
    active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT tenant_dek_purpose_check
        CHECK (purpose IN ('TOTP', 'WEBHOOK_SECRET', 'OAUTH2_CLIENT_SECRET', 'HMIS_API_KEY')),

    -- Key-shred FK: removing a tenant row removes every DEK for that tenant.
    -- This is the SINGLE most load-bearing line in the design — without
    -- ON DELETE CASCADE, hardDelete fails on the FK and the wrapped DEKs
    -- survive the "shred".
    CONSTRAINT tenant_dek_tenant_fk
        FOREIGN KEY (tenant_id) REFERENCES tenant(id) ON DELETE CASCADE
);

-- Each (tenant, purpose, generation) yields exactly one wrapped DEK.
CREATE UNIQUE INDEX tenant_dek_tenant_purpose_gen_uq
    ON tenant_dek (tenant_id, purpose, generation);

-- At most one ACTIVE generation per (tenant, purpose). Rotation bumps
-- generation and flips the old row's `active` to FALSE atomically.
CREATE UNIQUE INDEX tenant_dek_active_per_tenant_purpose_uq
    ON tenant_dek (tenant_id, purpose) WHERE active = TRUE;

-- RLS: PERMISSIVE+RESTRICTIVE pair per V68's tenant_key_material +
-- kid_to_tenant_key pattern (§V68 lines 112-161). Warroom 2026-04-24
-- (Sam) blocker fix — PERMISSIVE writes alone would silently bypass
-- tenant scoping because RESTRICTIVE policies can only narrow a
-- PERMISSIVE set, not authorize on their own. Decrypt path resolves
-- kid BEFORE TenantContext is bound, so SELECT must be unrestricted
-- (safe because kids are opaque UUIDs that don't enumerate tenants).
ALTER TABLE tenant_dek ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_dek FORCE ROW LEVEL SECURITY;

-- PERMISSIVE (read path + write baseline)
CREATE POLICY tenant_dek_select_all ON tenant_dek
    FOR SELECT USING (true);
CREATE POLICY tenant_dek_insert_permissive ON tenant_dek
    FOR INSERT WITH CHECK (true);
CREATE POLICY tenant_dek_update_permissive ON tenant_dek
    FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY tenant_dek_delete_permissive ON tenant_dek
    FOR DELETE USING (true);

-- RESTRICTIVE (the actual tenant-scoping; ANDs with PERMISSIVE so only
-- rows matching the caller's bound tenant survive). Uses the same
-- fabt_current_tenant_id() helper V68 established.
CREATE POLICY tenant_dek_insert_restrictive ON tenant_dek
    AS RESTRICTIVE
    FOR INSERT WITH CHECK (tenant_id = fabt_current_tenant_id());
CREATE POLICY tenant_dek_update_restrictive ON tenant_dek
    AS RESTRICTIVE
    FOR UPDATE
    USING (tenant_id = fabt_current_tenant_id())
    WITH CHECK (tenant_id = fabt_current_tenant_id());
CREATE POLICY tenant_dek_delete_restrictive ON tenant_dek
    AS RESTRICTIVE
    FOR DELETE USING (tenant_id = fabt_current_tenant_id());

-- hardDelete cascade path: the DELETE on the tenant row fires the
-- FK CASCADE, which runs in the tenant row's transaction context —
-- the RESTRICTIVE DELETE above is satisfied because hardDelete binds
-- app.tenant_id via the same pattern used by TenantLifecycleService's
-- other writes (set_config('app.tenant_id', ?, true) in the tx).
```

---

## 5. Service API

### TenantDekService

```java
@Service
public class TenantDekService {

    /** Returns the active DEK for (tenant, purpose) — unwrapped, ready to use. */
    @Transactional
    public ActiveDek getOrCreateActiveDek(UUID tenantId, KeyPurpose purpose);

    /** Resolves a kid back to its unwrapped DEK for the decrypt path. */
    @Transactional(readOnly = true)
    public ResolvedDek resolveDek(UUID kid);

    public record ActiveDek(UUID kid, SecretKey dek, int generation) {}
    public record ResolvedDek(UUID kid, UUID tenantId, KeyPurpose purpose,
                              int generation, SecretKey dek) {}
}
```

Implementation details:

- `getOrCreateActiveDek` checks a per-(tenant, purpose) cache first (5-min TTL, keyed on the composite to avoid cross-purpose leaks).
- Cache miss → `SELECT ... WHERE tenant_id = ? AND purpose = ? AND active = TRUE` → unwrap → cache.
- If the SELECT returns 0 rows → generate random DEK → wrap → `INSERT ... ON CONFLICT DO NOTHING` → re-select to pick up concurrent insert → unwrap → cache.
- `resolveDek` reads the `tenant_dek` row by kid, unwraps via the same wrapping key (re-derived on demand), caches (1-hour TTL — kid → (tenant, purpose, generation) is immutable by design).
- **Cache invalidation — Warroom 2026-04-24 (Alex) blocker fix.** Two-phase:
  - On transition to **OFFBOARDING or ARCHIVED** (TenantLifecycleService.offboard / archive): `TenantDekService.invalidateTenantDeks(tenantId)` fires via the same after-commit hook that already invalidates `TenantStateGuard`. Without this, the 1-hour `resolveDek` cache would serve unwrapped DEKs from JVM memory for up to an hour after a tenant enters retention — a real window where "shred-promised" tenants are still decryptable from a hot JVM.
  - On transition to **DELETED** (hardDelete): `invalidateTenantDeks(tenantId)` is called again pre-CASCADE so any concurrent decrypt attempt sees the missing DEK immediately rather than reading the row before the DELETE flushes. Idempotent — second call is a no-op.
- `invalidateTenantDeks(tenantId)` walks both caches: evicts every `(tenant, purpose)` key for the tenant from the active-DEK cache, and evicts every kid whose cached `ResolvedDek.tenantId` matches from the kid-resolution cache. O(purposes + cached-kids-for-tenant); trivial at pilot scale.

### SecretEncryptionService refactor

```java
public String encryptForTenant(UUID tenantId, KeyPurpose purpose, String plaintext) {
    TenantDekService.ActiveDek active = tenantDekService.getOrCreateActiveDek(tenantId, purpose);
    // ... generate IV, AES-GCM encrypt under active.dek() ...
    return new EncryptionEnvelope(active.kid(), iv, ciphertextWithTag).encode();
}

public String decryptForTenant(UUID tenantId, KeyPurpose purpose, String stored) {
    byte[] decoded = Base64.getDecoder().decode(stored);
    if (!EncryptionEnvelope.isV1Envelope(decoded)) {
        return CiphertextV0Decoder.decrypt(...);  // unchanged legacy path
    }
    EncryptionEnvelope envelope = EncryptionEnvelope.decode(stored);
    TenantDekService.ResolvedDek resolved;
    try {
        resolved = tenantDekService.resolveDek(envelope.kid());
    } catch (NoSuchElementException unknown) {
        throw new CrossTenantCiphertextException(envelope.kid(), tenantId, UNKNOWN_KID_SENTINEL_TENANT);
    }
    if (!resolved.tenantId().equals(tenantId)) {
        throw new CrossTenantCiphertextException(envelope.kid(), tenantId, resolved.tenantId());
    }
    if (resolved.purpose() != purpose) {
        // Purpose mismatch surfaces as a decrypt failure (consistent with current
        // GCM-tag-fails-on-wrong-purpose behavior). Explicit check avoids
        // relying on tag failure for the contract.
        throw new RuntimeException("Failed to decrypt v1 ciphertext for tenant "
            + tenantId + " — purpose mismatch");
    }
    // ... AES-GCM decrypt under resolved.dek() ...
}
```

KeyDerivationService's typed `deriveXxxKey` methods become dead code for the data-encryption path (only `deriveJwtSigningKey` + the new private `deriveKekWrappingKey` remain live). The typed methods stay on the class as `@Deprecated(forRemoval = true)` with a pointer to `TenantDekService` + Phase L cleanup task.

### hardDelete()

**Warroom 2026-04-24 pass-2 (Riley + Alex) blocker fix — cache invalidation is AFTER_COMMIT, not pre-DELETE.** Original draft invalidated caches before the DELETE, which desyncs cache from DB if the DELETE rolls back (stale cache absent, stale DB present → legitimate decrypts fail until the next transition fires). Spring's `@TransactionalEventListener(AFTER_COMMIT)` fires only on successful commit, matching the existing cache-invalidation pattern `TenantLifecycleService` uses for `TenantStateGuard`.

**Implementation note (warroom pass-4 re-sync, 2026-04-24):** the committed
implementation in `TenantLifecycleService.java` deviates from the pseudo-
code below in two small ways the warroom approved after seeing the code:
(1) the tombstone write moved from inside the main tx to the AFTER_COMMIT
hook alongside cache invalidation (Alex retracted the pass-3
"tombstone inside tx" recommendation) — both fire only on successful
commit, keeping state consistent on rollback; (2) the after-commit hook
uses `TransactionSynchronizationManager.registerSynchronization` rather
than `@TransactionalEventListener(AFTER_COMMIT)` — equivalent semantics,
simpler wiring, co-located with the method it serves. The pseudo-code
here preserves the intent for design-reading purposes; cross-reference
against the shipped code for exact behavior.

```java
@Transactional
public void hardDelete(UUID tenantId, UUID actorUserId, String reason) {
    Tenant t = tenantRepository.findById(tenantId).orElseThrow();
    t.getState().assertTransition(TenantState.DELETED);  // ARCHIVED → DELETED only
    // (retention-window gate + archived_at null check also here — see shipped code)

    // 1. Capture the tenant_audit_chain_head hash BEFORE the CASCADE destroys
    //    it (warroom pass-2 Riley fix). The tombstone row needs this hash
    //    so external auditors can prove the chain terminated cleanly at a
    //    specific Merkle root rather than "vanished."
    String lastChainHash = captureLastAuditChainHash(tenantId);  // returns hex or null

    // 2. Bind the shred-guard GUC (Q-F6-6 trigger uses this) so the
    //    BEFORE DELETE trigger on tenant_dek allows the CASCADE to fire.
    //    Parameterized, tx-local. ArchUnit rule 7.8j pins this call site.
    jdbc.queryForObject(
        "SELECT set_config('fabt.shred_in_progress', ?, true)",
        String.class, tenantId.toString());

    // 3. DELETE tenant row — FK cascade destroys all 18 per-tenant child
    //    rows AND tenant_dek rows (V82's CASCADE FK). This is THE single
    //    DB statement that performs the shred.
    int rows = jdbc.update("DELETE FROM tenant WHERE id = ?", tenantId);
    if (rows != 1) throw new IllegalStateException("expected 1 row, got " + rows);

    // 4. Schedule tombstone + cache invalidation for AFTER_COMMIT.
    //    Both fire ONLY on successful commit; rollback leaves state
    //    consistent (tenant row still present, caches not evicted).
    scheduleHardDeleteAfterCommit(tenantId, /* previousState */, actorUserId,
                                   reason, lastChainHash);
}

// After-commit hook runs on TransactionSynchronizationManager.registerSynchronization
// — fires ONLY on successful commit of the outer tx.
private void scheduleHardDeleteAfterCommit(UUID tenantId, TenantState previous,
                                            UUID actorUserId, String reason,
                                            String lastChainHash) {
    // 1. Cache invalidation — evicts per-(tenant, purpose) active-DEK cache +
    //    per-kid resolution cache, plus the TenantStateGuard cache.
    tenantDekService.invalidateTenantDeks(tenantId);
    tenantStateGuard.invalidate(tenantId);

    // 2. Platform-owned tombstone to audit_events. SYSTEM_TENANT_ID scope
    //    (audit_events has no FK to tenant per V57 / Q-F6-5) so the row
    //    survives the shred and gives auditors the "tenant X deleted on
    //    Y by Z" record. Written via DetachedAuditPersister (REQUIRES_NEW).
    detachedAuditPersister.persistDetached(
        SYSTEM_TENANT_ID,
        new AuditEventRecord(actorUserId, null,
            AuditEventTypes.TENANT_HARD_DELETED,
            Map.of(
                "deleted_tenant_id", tenantId.toString(),
                "actor_user_id", actorUserId.toString(),
                "justification", reason,
                "deleted_at", Instant.now().toString(),
                "previous_state", previous.name(),
                "last_audit_chain_hash", lastChainHash != null ? lastChainHash : "(no chain)"),
            null));
}
```

Every per-tenant child table already lands on CASCADE from V82 (`tenant_dek`) or V84 (the 18 flipped in §6). After the single DELETE the wrapped DEK rows are gone; the physical pages get reused on autovacuum and PITR-retention-pass.

**Cache TTL trim for ARCHIVED tenants** (Alex pass-2 minor): to tighten the window between OFFBOARDING/ARCHIVED transitions and cache TTL expiry, the kid-resolution cache re-checks tenant state on cache hit for any tenant whose state transitioned in the last hour. Implementation: `TenantDekService.resolveDek` calls `tenantStateGuard.requireActiveOrOffboarding(resolvedTenantId)` on cache hit. If the tenant is ARCHIVED, the cache entry is evicted and a fresh DB lookup + unwrap fires (which may succeed briefly during the retention window, but only for data that HAS NOT been shredded yet).

---

## 6. Child-table CASCADE audit (V84)

Warroom 2026-04-24 inventoried 18+ child tables that currently lack `ON DELETE CASCADE` to tenant. Before `hardDelete` can run the bare `DELETE FROM tenant WHERE id = ?` above, every FK chain must flip to CASCADE or be cleaned up explicitly in code.

Deliverable: **V84__tenant_fk_cascade.sql** — `ALTER TABLE ... DROP CONSTRAINT ... ADD CONSTRAINT ... ON DELETE CASCADE` for the complete child-table list. Table list + verification query lives in **Appendix A** (to be filled in during §8 warroom review after DB sweep).

Alternative rejected: explicit per-table DELETE in `hardDelete()`. Verbose, ordering-fragile (FK cycles), and puts the tenant-isolation guarantee in application code where an omitted table silently survives shred. FK CASCADE keeps the invariant in the schema where Postgres enforces it.

---

## 7. What stays HKDF (deliberately)

- **JWT signing keys** (`deriveJwtSigningKey`) — `kid_to_tenant_key` + `tenant_key_material` stay. Tokens have ≤15-min lifetime and post-shred tenant-state check rejects any forged token that attempts to auth against a deleted tenant. Crypto-shred is not the right control here.
- **KEK wrapping key** (new `deriveKekWrappingKey`) — HKDF is fine because the wrapping key alone decrypts nothing; the wrapped_dek row is what gets shredded.

Rule of thumb for future designers: **HKDF-derived keys are shreddable only if every ciphertext encrypted under them is also shredded alongside the key's persisted state.** JWTs self-expire; wrapped DEKs are shredded via CASCADE.

---

## 8. Migration plan

### V82 — schema

Empty tenant_dek table + indexes + RLS policies. No data movement.

### V83 — re-encrypt existing per-tenant ciphertexts

Walks the **same 4 columns V74 touched** (§A5 design):

| Column | Table | Purpose |
|---|---|---|
| `totp_secret_encrypted` | `app_user` | `TOTP` |
| `callback_secret_hash` | `subscription` | `WEBHOOK_SECRET` |
| `client_secret_encrypted` | `tenant_oauth2_provider` | `OAUTH2_CLIENT_SECRET` |
| `tenant.config → hmis_vendors[].api_key_encrypted` | `tenant` (JSONB) | `HMIS_API_KEY` |

For each row with a v1 envelope:
1. Decrypt under the old HKDF-derived DEK (via existing `KeyDerivationService.deriveXxxKey`).
2. Encrypt under a new random DEK via `TenantDekService.getOrCreateActiveDek(tenant, purpose)`.
3. Update the column with the new v1 envelope (same wire format; new kid).

Idempotency: `tenant_dek` row is created once per `(tenant, purpose)`; subsequent rows re-use via `ON CONFLICT DO NOTHING`. Per-row transaction with round-trip verify, same shape as V74.

Pilot scale: 3 tenants × 4 purposes = ~12 wrapped-DEK inserts; ~65 column rewrites total. Sub-second.

### V84 — child-table CASCADE (§6)

Separate migration so the schema change is visible as its own audit unit. Complete table list lives in Appendix A (filled by task #38 DB audit).

**Warroom 2026-04-24 (Riley) blocker fix — shift the preflight left.** Earlier draft had `hardDelete` run a `pg_constraint` query at runtime that failed if any per-tenant child FK lacked CASCADE. That means the first prod shred is also the first time the guard runs — too late. Replace with a **Flyway CI check**:

- A test-suite ArchUnit-flavored integration test (`TenantChildCascadeAuditTest`) queries `information_schema.table_constraints` + `information_schema.referential_constraints`, walks every FK pointing to `tenant(id)`, and fails the build if `delete_rule != 'CASCADE'` for anything on the "must cascade" allowlist (the same list Appendix A enumerates).
- The allowlist lives next to the test, not in the service — adding a new per-tenant child table means adding it to the allowlist AND adding the CASCADE in the same PR, both enforced at CI time.
- `audit_events` stays on the "must NOT cascade" list per Q-F6-5 resolution (Riley): preserved as audit trail via nullable `tenant_id` + platform-owned tombstone row on hardDelete.

`hardDelete` itself becomes a bare `DELETE FROM tenant WHERE id = ?` with no preflight — the CI check is the guarantee.

---

## 9. Tasks (to add to tasks.md under §7 Phase F)

- **7.8a** V82 — create `tenant_dek` table + indexes + RLS policies + trigger guard
- **7.8b** Implement `TenantDekService` + caches + `KeyDerivationService.deriveKekWrappingKey` (private); `PurposeMismatchException extends SecurityException`
- **7.8c** Refactor `SecretEncryptionService.encryptForTenant` / `decryptForTenant` to route through `TenantDekService`
- **7.8d** V83 — re-encrypt existing per-tenant ciphertexts under new random DEKs; per-row tx with round-trip verify (V74 pattern); fold in rotation-readiness probe
- **7.8e** V84 — flip 18 child-table FKs to `ON DELETE CASCADE` via DO-block + `NOT VALID` + `VALIDATE`; complete list from §6 audit
- **7.8f** Implement `TenantLifecycleService.hardDelete` — transition ARCHIVED → DELETED, capture chain hash, bind shred GUC, DELETE tenant row, emit tombstone; cache invalidation via `@TransactionalEventListener(AFTER_COMMIT)`
- **7.8g** Remove `@Disabled` on `CryptoShredGapIntegrationTest`; confirm green
- **7.8h** ArchUnit Family F — forbid non-`TenantDekService` callers from `KeyDerivationService.deriveKekWrappingKey`
- **7.8i** Release notes + runbook — "crypto-shred" is a verifiable cryptographic property; backup-retention hygiene, PITR-into-shred-window warning, V84 rollback template, master-KEK-on-same-disk note
- **7.8j** ArchUnit Family F — forbid non-`TenantLifecycleService.hardDelete` callers of `set_config('fabt.shred_in_progress', ...)` (warroom pass-2 Q-F6-6 resolution)
- **7.8k** Implement §12 test suite (Jordan's 7-test minimum) — see §12 for individual test contracts

---

## 10. Open questions — resolved by warroom 2026-04-24

1. **Q-F6-1** (Marcus) — **Deterministic HKDF wrapping key, keep.** Separate random platform-wrapped KEK adds one rotation-complexity layer with zero crypto benefit. The shred surface is the `wrapped_dek` row; losing it renders the DEK unrecoverable regardless of wrapping-key derivation mechanics.
2. **Q-F6-2** (Sam) — **Per-row transaction with round-trip verify**, matching V74. 65 rewrites × ~10ms ≈ sub-second at pilot scale; per-row isolates failures and mirrors the established V74 pattern Flyway + ops already trust.
3. **Q-F6-3** (Marcus + Alex) — **Yes, add the DB trigger.** `BEFORE DELETE ON tenant_dek` that raises unless the session role is the shred role (or the FK CASCADE path fires it). App-layer ArchUnit + DB-layer trigger is belt-and-braces for CSP-wrap stores; noise is negligible since no legitimate caller deletes from `tenant_dek` outside the CASCADE path.
4. **Q-F6-4** (Jordan) — **Fold rotation-readiness probe into V83.** V83 already creates 12 DEKs; probing a rotation on one (pick any single `(tenant, purpose)`, bump generation, re-encrypt one sample row, flip back) adds ~2s and ensures the rotation path ships battle-tested rather than untested until Phase H.
5. **Q-F6-5** (Riley) — **audit_events stays RESTRICT, converted to nullable tenant_id + tombstone.** CASCADE would destroy the record that proves the shred happened — a compliance self-own. `hardDelete` writes a platform-owned tombstone row (NULL tenant_id, action = `TENANT_HARD_DELETED`, JSONB with deletion metadata + `tenant_audit_chain_head.last_hash` captured pre-CASCADE) just before the DELETE fires.

6. **Q-F6-6** (warroom pass-2, Sam + Alex + Marcus) — **GUC-based shred guard, not a dedicated DB role.** FABT's single-role posture (`fabt_app`) is a deliberate operational simplification; adding `fabt_shred` means a second password in `.env.prod`, a second grant audit, and a new failure mode with Flyway mid-tx `SET ROLE` support. A tx-local session GUC (`set_config('fabt.shred_in_progress', <tenantId>, true)`) provides equivalent crypto-shred isolation: auto-clears on rollback, does not leak across tx boundaries, and the trigger's equality check (`current_setting IS DISTINCT FROM OLD.tenant_id::text`) binds the guard to a SPECIFIC tenant, not a generic "shred mode is on". Caveat baked into task 7.8j: ArchUnit rule forbids any non-`hardDelete` caller of `set_config('fabt.shred_in_progress', ...)`. Without that rule, a rogue dev-console call defeats the guard.

### Additional warroom finding — threat-model gap

**Alex §2 addendum:** earlier draft's threat table listed post-shred scenarios but did not cover the window between **ARCHIVED and DELETED** on a running JVM. During that window:
- `tenant_dek` rows still exist (hardDelete hasn't fired yet).
- `TenantDekService.resolveDek` cache has a 1-hour TTL that can serve unwrapped DEKs from JVM memory.
- A compromised pod with hot-cache access + pre-retrieved kid could decrypt ciphertext against a "shred-promised" tenant.

Fix baked into §5: invalidate `TenantDekService` caches on transition to OFFBOARDING/ARCHIVED, not just DELETED. This closes the window to "as-fast-as-the-transition-event-fires" rather than "up-to-an-hour-after-hardDelete".

---

## 11. Test strategy — the 7-test minimum (Jordan, warroom pass-2 2026-04-24)

"Very careful and test thoroughly" (Corey 2026-04-24) means every crypto-shred invariant has at least one pinning test. All seven below MUST be green before the v0.51.0 release gate (see §13 ship checklist).

### 11.1 — `CryptoShredGapIntegrationTest` (the TDD anchor, flipped)

Exists today at `backend/src/test/java/org/fabt/shared/security/CryptoShredGapIntegrationTest.java` with `@Disabled` (commit `b5672da`). Task 7.8g removes the `@Disabled` and the test must flip green.

**Acceptance:** under Option A, (a) encrypt a `SHRED-CANARY-<uuid>` under tenant T for each of the 4 `KeyPurpose` values; (b) record ciphertext bytes + master_KEK fingerprint to an in-memory buffer; (c) call `hardDelete(T)`; (d) bypass `TenantDekService` — reconstruct the decrypt attempt using ONLY `master_KEK` + recorded ciphertext bytes; (e) assert `resolveDek(kid)` throws `NoSuchElementException` AND assert that raw HKDF-based recomputation yields a key that does NOT decrypt the ciphertext (post-shred DEK ≠ pre-shred DEK because the DEK was random, not HKDF-derived). Single green run = gap closed.

### 11.2 — `NTenantCanaryShredTest` (property-style, Jordan pass-1 request)

Create 25 tenants each with 4 encrypted purposes (100 ciphertexts total). `hardDelete` 5 random tenants (20 ciphertexts → unrecoverable). Assert: 20 ciphertexts fail to decrypt via both happy path and adversary path; 80 remain intact and round-trip cleanly. Repeat with 10 different seeds in CI. Probabilistic coverage catches any correlation between shreds that a deterministic N=1 test would miss.

### 11.3 — `RotationReadinessProbeTest` (Q-F6-4 fold-in)

Pin V83's rotation-readiness probe. For one `(tenant, purpose)`:
- Before: `tenant_dek` has 1 row, `(gen=1, active=TRUE)`.
- Probe: INSERT gen=2 active=TRUE (atomically flipping gen=1 active=FALSE in same tx); re-encrypt 1 sample row under gen=2; flip back (gen=2 active=FALSE, gen=1 active=TRUE); re-encrypt the sample back.
- After: `tenant_dek` has 2 rows (one per generation); exactly one `active=TRUE`; the sample row still round-trips through `decryptForTenant`.
- Grace-window assertion: `resolveDek(gen=1_kid)` still returns a valid `ResolvedDek` even while gen=2 is active — old ciphertexts decrypt during rotation grace.

### 11.4 — `TenantDekRlsTest` (PERMISSIVE+RESTRICTIVE policy pinning)

Six assertions against a tenant A and tenant B with DEKs each:
- Bind `app.tenant_id=A`; `SELECT * FROM tenant_dek WHERE tenant_id=B` → returns rows (PERMISSIVE SELECT, kids opaque).
- Bind A; `INSERT ... tenant_id=B` → raises SQLSTATE `42501` (RESTRICTIVE INSERT narrows to A-only).
- Bind A; `UPDATE tenant_dek SET active=FALSE WHERE tenant_id=B` → 0 rows affected.
- Bind A; `DELETE FROM tenant_dek WHERE tenant_id=B` → 0 rows affected (RESTRICTIVE DELETE).
- Unbind (no `app.tenant_id`); `DELETE FROM tenant_dek WHERE tenant_id=A` → 0 rows affected.
- Bind A; `DELETE FROM tenant_dek WHERE tenant_id=A` WITHOUT the shred GUC → raises trigger-guard SQLSTATE `P0001` ('tenant_dek row deletion attempted outside hardDelete shred path').

### 11.5 — `TenantChildCascadeAuditTest` (Flyway CI)

Queries `pg_catalog.pg_constraint` (NOT `information_schema.referential_constraints` — the latter filters by current-user grants and misses rows under RLS):

```sql
SELECT conname, confdeltype, conrelid::regclass::text
FROM pg_catalog.pg_constraint
WHERE confrelid = 'public.tenant'::regclass AND contype = 'f'
ORDER BY conrelid::regclass::text;
```

Assert every row in `MUST_CASCADE_FROM_TENANT` (the 22-table allowlist from Appendix A) has `confdeltype = 'c'`. Assert no FK exists for any table in `MUST_NOT_FK_TO_TENANT` (audit_events). Fail build with actionable diff listing which table + which rule.

### 11.6 — `V83MigrationTest` (idempotency + completeness)

Fixture setup: fresh Testcontainer, V79/V80/V81 applied, seed with a mix of v0 ciphertexts (Phase 0 plain envelope), v1-HKDF-DEK ciphertexts (Phase A3 output), and null columns. Run V82 then V83.

**Idempotency:** re-run V83 in a second transaction; assert zero new `tenant_dek` rows created, zero column rewrites, identical audit event counts, all round-trips still succeed.

**Completeness:** scan all 4 encrypted columns (`app_user.totp_secret_encrypted`, `subscription.callback_secret_hash`, `tenant_oauth2_provider.client_secret_encrypted`, `tenant.config → hmis_vendors[].api_key_encrypted`); for every non-null v1-envelope value, extract the kid via `EncryptionEnvelope.decode` and assert `tenant_dek WHERE kid = ?` returns exactly one row. Zero orphan v1 envelopes allowed.

### 11.7 — `TenantDekShredGuardTest` (trigger semantics, Q-F6-6)

Three cases:

**Positive:** `TenantLifecycleService.hardDelete(T)` completes successfully; `tenant_dek WHERE tenant_id = T` returns 0 rows post-commit.

**Negative (no GUC):** as `fabt_app` without calling `set_config('fabt.shred_in_progress', ...)`, execute `DELETE FROM tenant_dek WHERE tenant_id = T`; assert SQLSTATE `P0001` with message `'tenant_dek row deletion attempted outside hardDelete shred path'`.

**Negative (cross-tenant GUC poisoning):** as `fabt_app`, set `fabt.shred_in_progress` to tenant A's id, execute `DELETE FROM tenant_dek WHERE tenant_id = B`; assert the trigger still raises (guard checks equality, not presence).

### Existing test suite that must stay green under the refactor

- `PerTenantEncryptionIntegrationTest` — all 8 existing cases (T1–T8) remain green through the Option A refactor. Confirms the refactor doesn't regress Phase A3 coverage.
- `KeyDerivationServiceKatTest` (RFC 5869 test vectors) — HKDF itself is unchanged; KATs continue to pass.
- Existing `TenantLifecycleServiceUnitTest` + `TenantLifecycleOffboardArchiveIntegrationTest` (F-1 through F-5) — `hardDelete` is additive; earlier states untouched.

---

## 12. Ship checklist (v0.51.0 release gate)

Every line below green:

- [ ] V82 + V83 + V84 apply cleanly on a fresh Testcontainer
- [ ] V82 + V83 + V84 apply cleanly on a dump of the prod DB (pilot 3-tenant dataset)
- [ ] `CryptoShredGapIntegrationTest` — `@Disabled` removed, passes (task 11.1)
- [ ] `NTenantCanaryShredTest` — passes seeds 1..10 (task 11.2)
- [ ] `RotationReadinessProbeTest` — passes (task 11.3)
- [ ] `TenantDekRlsTest` — all 6 RLS assertions green (task 11.4)
- [ ] `TenantChildCascadeAuditTest` — Flyway CI green; fail-loud if any FK drifts (task 11.5)
- [ ] `V83MigrationTest` — idempotency + completeness (task 11.6)
- [ ] `TenantDekShredGuardTest` — positive + negative + cross-tenant GUC (task 11.7)
- [ ] ArchUnit Family F — `deriveKekWrappingKey` caller pin green (task 7.8h)
- [ ] ArchUnit Family F — `set_config('fabt.shred_in_progress')` caller pin green (task 7.8j)
- [ ] `PerTenantEncryptionIntegrationTest` — 8/8 green under refactored DEK path
- [ ] Full backend regression — 1027+/1027+ green
- [ ] Runbook updated: PITR-into-shred-window note, V84 rollback template, master_KEK-on-same-disk backup-hygiene, NIST SP 800-88 verbatim language, K1 shred-drill procedure
- [ ] Casey Drummond sign-off recorded on `escalation_policy` RESTRICT→CASCADE flip
- [ ] Release notes + CHANGELOG entries drafted and legal-scanned per `feedback_legal_claims_review`

---

## 13. References

- NIST SP 800-88 Rev 2 (Sept 2025) §2.5 "Cryptographic Erase"
- NIST SP 800-38F §6.3 AES-KWP
- RFC 5649 AES Key Wrap with Padding
- EDPB Guidelines 02/2025 on Art. 17 GDPR erasure
- FIPS 140-3 IG §C.C "Critical Security Parameter zeroization"
- Umbrella design §D11 (to be superseded by this document's §2 threat model)
- TDD anchor: `backend/src/test/java/org/fabt/shared/security/CryptoShredGapIntegrationTest.java` (commit `b5672da`)

---

## Appendix A — Per-tenant child-table CASCADE audit

**Status:** COMPLETED 2026-04-24 via static analysis of migrations V2–V81 (task #38).

**Method:** Scanned every `REFERENCES tenant(id)` in `backend/src/main/resources/db/migration/`. Cross-referenced with V57 (`audit_events.tenant_id` without FK). No ALTER TABLE migrations exist that add/modify FKs to tenant post-initial creation, so the migration files are authoritative.

**Runtime verification (for post-migration CI sanity):**

```sql
SELECT
    c.conname                             AS constraint_name,
    n.nspname || '.' || t.relname         AS owning_table,
    pg_get_constraintdef(c.oid)           AS full_definition,
    c.confdeltype                         AS delete_rule
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_class ref ON ref.oid = c.confrelid
WHERE c.contype = 'f' AND ref.relname = 'tenant' AND n.nspname = 'public'
ORDER BY owning_table;
```

`confdeltype` legend: `c` CASCADE, `r` RESTRICT, `a` NO ACTION, `n` SET NULL, `d` SET DEFAULT.

### Complete inventory (21 direct FKs + 1 FK-less column)

| # | Table | Column | Migration | Current rule | V84 action | Rationale |
|---|---|---|---|---|---|---|
| 1 | `app_user` | `tenant_id` | V2 | NO ACTION | **→ CASCADE** | User data |
| 2 | `api_key` | `tenant_id` | V3 | NO ACTION | **→ CASCADE** | API keys owned by tenant |
| 3 | `shelter` | `tenant_id` | V4 | NO ACTION | **→ CASCADE** | Shelter data; children cascade via `shelter_id ON DELETE CASCADE` |
| 4 | `import_log` | `tenant_id` | V9 | NO ACTION | **→ CASCADE** | 211 import history |
| 5 | `tenant_oauth2_provider` | `tenant_id` | V10 | NO ACTION | **→ CASCADE** | Per-tenant OAuth config + client_secret_encrypted (V83 column) |
| 6 | `subscription` | `tenant_id` | V11 | NO ACTION | **→ CASCADE** | Webhook subs + callback_secret_hash (V83 column) |
| 7 | `bed_availability` | `tenant_id` | V12 | NO ACTION | **→ CASCADE** | Bed counts |
| 8 | `reservation` | `tenant_id` | V14 | NO ACTION | **→ CASCADE** | Bed holds |
| 9 | `surge_event` | `tenant_id` | V17 | NO ACTION | **→ CASCADE** | Surge-mode markers |
| 10 | `referral_token` | `tenant_id` | V21 | NO ACTION | **→ CASCADE** | DV referrals |
| 11 | `hmis_outbox` | `tenant_id` | V22 | NO ACTION | **→ CASCADE** | HMIS push queue |
| 12 | `hmis_audit_log` | `tenant_id` | V22 | NO ACTION | **→ CASCADE** | HMIS forensic log — **see note** below |
| 13 | `bed_search_log` | `tenant_id` | V23 | NO ACTION | **→ CASCADE** | Analytics search log |
| 14 | `daily_utilization_summary` | `tenant_id` | V23 | NO ACTION | **→ CASCADE** | Analytics rollup |
| 15 | `one_time_access_code` | `tenant_id` | V32 | NO ACTION | **→ CASCADE** | OTAC (also cascades via `app_user_id`) |
| 16 | `notification` | `tenant_id` | V35 | NO ACTION | **→ CASCADE** | Persistent notifications |
| 17 | `password_reset_token` | `tenant_id` | V39 | NO ACTION | **→ CASCADE** | Reset tokens (also cascades via `user_id`) |
| 18 | `escalation_policy` | `tenant_id` | V46 | **RESTRICT** | **→ CASCADE** | Custom per-tenant paging policies; platform defaults are `tenant_id = NULL` and unaffected. V46 comment ("decide what to do with audit trail") is now resolved: the trail lives in `audit_events` which is preserved. |
| 19 | `tenant_key_material` | `tenant_id` | V61 | **CASCADE** | No change | JWT signing material — cascade on hardDelete cleans up registry rows |
| 20 | `kid_to_tenant_key` | `tenant_id` | V61 | **CASCADE** | No change | JWT kid resolution |
| 21 | `tenant_audit_chain_head` | `tenant_id` | V80 | **CASCADE** | **Review with Jordan** | Forensic chain HEAD only; the chain's underlying audit rows live in `audit_events` which is preserved. Destroying the HEAD pointer is fine — it's a tenant-scoped accumulator, not the audit trail itself. Proposed **keep CASCADE** but surface to Jordan at implementation time. |

### Special case: `audit_events`

Not in the table because it has **no FK to tenant**. V29 created `audit_events` with no tenant column; V57 added `tenant_id UUID` (nullable) but deliberately **without a FK constraint** to support cross-tenant platform-admin queries and the "nullable = platform-level" semantics.

**Behavior under `DELETE FROM tenant WHERE id = ?`:**
- No FK → no cascade applies → rows survive.
- V70 revokes `DELETE, UPDATE` from `fabt_app` → cannot accidentally wipe forensic trail.
- Orphaned `tenant_id` values point to a no-longer-existing tenant; this is the intended shred-auditability state per Riley's §10 Q-F6-5 resolution.
- `hardDelete` writes a tombstone: `INSERT INTO audit_events (tenant_id, action, details) VALUES (NULL, 'TENANT_HARD_DELETED', '{"deleted_tenant_id": "<uuid>", "actor": ..., "deleted_at": ...}')` — NULL `tenant_id` marks it platform-owned, details JSON preserves the who/what/when.

No V84 action required for `audit_events` — it is **correctly configured already** for shred survival.

### V84 migration body

**Second warroom review fixed 3 things in this section** (Sam 2026-04-24 pass 2):

1. **Lock claim corrected.** Original comment said "ACCESS EXCLUSIVE briefly; no row rewrite; catalog-only." FALSE. `ALTER TABLE ... ADD CONSTRAINT FOREIGN KEY` (without `NOT VALID`) scans the child table to validate every existing row and holds ACCESS EXCLUSIVE on the child + ROW SHARE on `tenant` for the whole scan. Sub-second on the pilot but scales with child-table size — the honest pattern is `ADD CONSTRAINT ... NOT VALID` (catalog-only, fast) then a separate `VALIDATE CONSTRAINT` pass (SHARE UPDATE EXCLUSIVE — unblocks concurrent writes).

2. **Constraint-name assumption removed.** Postgres's default `<table>_<column>_fkey` naming holds for tables created with inline FK syntax in V2–V4, but there's no guarantee. Replaced the static SQL with a `DO $$ ... $$` block that looks up the actual `conname` via `pg_constraint` at migration time. Also catches the case where a future developer renames a constraint.

3. **Lock/statement timeouts added** per V74 C-A5-N1 pattern — prevents a background `VACUUM` on any of the 18 tables from stalling V84 indefinitely at real scale.

```sql
-- V84__tenant_fk_cascade.sql
-- Flips 18 per-tenant child FKs from NO ACTION (the implicit default)
-- to ON DELETE CASCADE. Intent: TenantLifecycleService.hardDelete fires
-- a bare `DELETE FROM tenant` and the CASCADE chain destroys every
-- per-tenant child row. Tables not in the list are either already
-- CASCADE (tenant_key_material, kid_to_tenant_key, tenant_audit_chain_head
-- per V61/V80) or intentionally FK-less (audit_events per V57 — preserved
-- through shred with a nullable tenant_id and a platform tombstone).

-- Bound per-statement time so a background VACUUM on one table can't
-- hold up the rest of the migration.
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '60s';

DO $$
DECLARE
    -- Allowlist of (owning_table, intended_delete_rule).
    -- Must stay in sync with TenantChildCascadeAuditTest.MUST_CASCADE_FROM_TENANT.
    target_tables text[] := ARRAY[
        'app_user', 'api_key', 'shelter', 'import_log',
        'tenant_oauth2_provider', 'subscription', 'bed_availability',
        'reservation', 'surge_event', 'referral_token',
        'hmis_outbox', 'hmis_audit_log', 'bed_search_log',
        'daily_utilization_summary', 'one_time_access_code',
        'notification', 'password_reset_token', 'escalation_policy'
    ];
    tbl text;
    cname text;
BEGIN
    FOREACH tbl IN ARRAY target_tables LOOP
        -- Look up the FK's actual constraint name. tenant is confrelid,
        -- tbl is conrelid. If zero or more-than-one match exists, fail
        -- loud rather than DROP the wrong thing.
        SELECT conname INTO cname
        FROM pg_constraint
        WHERE contype = 'f'
          AND conrelid = format('public.%I', tbl)::regclass
          AND confrelid = 'public.tenant'::regclass;

        IF cname IS NULL THEN
            RAISE EXCEPTION 'V84: no FK from %.tenant_id to tenant(id) found on table %', tbl, tbl;
        END IF;

        -- 1. DROP the existing FK (catalog-only; fast).
        EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', tbl, cname);

        -- 2. ADD NOT VALID — catalog-only, no scan, ACCESS EXCLUSIVE for
        --    the metadata write, then released. New writes are blocked
        --    against the CASCADE rule immediately; existing rows are not
        --    re-checked here.
        EXECUTE format(
            'ALTER TABLE public.%I '
            'ADD CONSTRAINT %I FOREIGN KEY (tenant_id) '
            'REFERENCES public.tenant(id) ON DELETE CASCADE NOT VALID',
            tbl, cname);

        -- 3. VALIDATE — scans existing rows. Holds SHARE UPDATE EXCLUSIVE,
        --    does NOT block concurrent reads/writes. Slow only if the
        --    table is large and contains a row that violates the FK
        --    (none should; the constraint is a strict tightening).
        EXECUTE format('ALTER TABLE public.%I VALIDATE CONSTRAINT %I', tbl, cname);
    END LOOP;
END;
$$;

COMMENT ON COLUMN tenant.id IS
  'Parent of 18 CASCADE FKs (V84); hardDelete(tenant_id) chain-removes '
  'every per-tenant child row in a single DELETE. audit_events preserves '
  'its tenant_id without FK per shred-auditability contract (Q-F6-5).';
```

### Why DO-block instead of static SQL

- **Safer under name drift.** If someone renamed a constraint after initial creation, the static `DROP CONSTRAINT <table>_<col>_fkey` would fail or, worse, silently DROP a different constraint. The lookup pattern fails loud.
- **Easier to re-run.** The allowlist array is one line per table, mirror of the `MUST_CASCADE_FROM_TENANT` test constant. Adding a table = one line here + one line in the test.
- **CI alignment.** The post-migration `TenantChildCascadeAuditTest` reads from the same catalog (`pg_constraint`) the migration wrote to. Static SQL would be a separate source of truth that could drift.

### Allowlist constant for the Flyway CI check

Copy into `TenantChildCascadeAuditTest`:

```java
private static final Set<String> MUST_CASCADE_FROM_TENANT = Set.of(
    "app_user", "api_key", "shelter", "import_log", "tenant_oauth2_provider",
    "subscription", "bed_availability", "reservation", "surge_event",
    "referral_token", "hmis_outbox", "hmis_audit_log", "bed_search_log",
    "daily_utilization_summary", "one_time_access_code", "notification",
    "password_reset_token", "escalation_policy",
    "tenant_key_material", "kid_to_tenant_key", "tenant_audit_chain_head",
    "tenant_dek"  // V82
);

private static final Set<String> MUST_NOT_FK_TO_TENANT = Set.of(
    "audit_events"  // V57 column only, no FK — preserves forensic trail on shred
);
```

CI test asserts `confdeltype = 'c'` for every row in MUST_CASCADE_FROM_TENANT and raises if any entry in MUST_NOT_FK_TO_TENANT grows a FK to tenant.

### Items deferred to implementation-time warroom sign-off

- **#21 `tenant_audit_chain_head`** — Jordan to confirm CASCADE is acceptable (current V80 is CASCADE; proposal is no-change but wants explicit review).
- **#18 `escalation_policy` rule change** — Casey Drummond's V46 audit-trail concern is resolved by `audit_events` preservation, but confirm with Casey before shipping V84.
