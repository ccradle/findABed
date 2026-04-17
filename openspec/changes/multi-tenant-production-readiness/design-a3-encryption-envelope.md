# Phase A Checkpoint A3 — Encryption refactor design (APPROVED)

**Status:** APPROVED post-warroom 2026-04-17. 8 personas weighed in;
all 6 open questions resolved unanimously; 5 enhancements (E1–E5) folded
into the decisions + implementation plan below. Casey + Marcus formal
review of the eventual A3 PR will reference this doc.

**Scope:** tasks 2.6, 2.7. Refactors `SecretEncryptionService` to delegate
per-tenant encryption to `KeyDerivationService` (Checkpoint A2) while
preserving the ability to decrypt existing v0 (Phase 0) ciphertexts during
the dual-key-accept grace window before V74 re-encrypts them.

**Why a separate doc:** A3 is the highest-risk surface in Phase A. Wrong
envelope format or wrong backward-compat detection = unrecoverable
ciphertext = data loss for every TOTP / webhook / OAuth2 / HMIS secret in
the database. Worth slowing down to align before writing code.

---

## Decisions (D17–D22)

### D17 — Extract `MasterKekProvider` as the single FABT_ENCRYPTION_KEY validator

Phase 0's `SecretEncryptionService` and Phase A2's `KeyDerivationService`
each parse `FABT_ENCRYPTION_KEY` independently with duplicate prod-fail-fast
+ DEV_KEY-fallback logic. Drift risk: a future change to one validator
silently diverges from the other.

**Decision:** extract `MasterKekProvider` as a Spring `@Component`:

```java
@Component
public class MasterKekProvider {
    private final byte[] keyBytes;
    public MasterKekProvider(@Value(...) String base64Key, Environment env) {
        // Single owner of the prod-fail-fast / non-prod-DEV_KEY-fallback
        // / wrong-length / dev-key-prod-rejection validation logic
    }
    /** Public — safe to surface a SecretKey for AES init; bytes never escape. */
    public SecretKey getPlatformKey() {
        return new SecretKeySpec(keyBytes, "AES");
    }
    /**
     * Package-private (E1) — only KeyDerivationService in the same
     * org.fabt.shared.security package may call this. ArchUnit Family A
     * rule prevents extra-package callers from accidentally serializing
     * the master KEK to a log or response body.
     */
    byte[] getMasterKekBytes() { return keyBytes.clone(); }
}
```

`SecretEncryptionService` and `KeyDerivationService` both depend on
`MasterKekProvider`. Validation lives in one place; both services consume it
via well-typed accessors (`getPlatformKey()` for v0 / Phase-0 backward
compat — public; `getMasterKekBytes()` for HKDF derivation — package-private).

**E1 (warroom):** add `MasterKekProviderArchitectureTest` to ArchUnit
Family A:

```
classes that reside outside org.fabt.shared.security
should not call MasterKekProvider.getMasterKekBytes
```

Closes the "accidental serializer leaks raw KEK" foot-gun. Memory-hygiene
zeroization deferred to regulated tier per design D3.

**Risk surface:** the constructor change to `SecretEncryptionService` is
visible to Phase 0's pre-existing test `SecretEncryptionServiceConstructorTest`.
That test currently exercises the constructor's prod-fail-fast path. After
the refactor, those assertions move to `MasterKekProviderTest`.

### D18 — Ciphertext envelope v1 format

Phase 0's v0 envelope (post-Base64-decode):

```
[iv: 12][ciphertext: N][tag: 16]
```

Phase A v1 envelope adds (from the front):

```
[magic: 4 = "FABT"][version: 1 = 0x01][kid: 16][iv: 12][ciphertext: N][tag: 16]
```

Total fixed overhead: v0 = 28 bytes, v1 = 49 bytes. v1 grows TOTP/webhook
ciphertexts by ~21 bytes each — manageable.

**Magic bytes choice:** ASCII "FABT" = `0x46 0x41 0x42 0x54`. Picked because:

- Distinct: any v0 ciphertext starting with these 4 bytes by chance is
  ~1 in 4 billion (uniform random). At 1M ciphertexts, expected
  false-positive collisions per scan = 0.00025. Acceptable.
- Memorable: aids forensic reading of raw DB rows.
- ASCII-printable: shows up legibly in `pg_dump` plain-text format.

### D19 — Single `kid` per `(tenant_id, generation)`, purpose implicit in caller

`kid_to_tenant_key` has columns `(kid, tenant_id, generation, created_at)`
— **no purpose column**. One kid identifies a `(tenant_id, generation)` pair.
The same kid is reused across all 5 purposes (`jwt-sign`, `totp`,
`webhook-secret`, `oauth2-client-secret`, `hmis-api-key`).

The actual DEK is recomputed per-encrypt/decrypt call via
`KeyDerivationService.deriveXxxKey(tenantId)`. Different methods derive
different keys — purpose distinguishes the derived material; kid
distinguishes the `(tenant, generation)`.

**Why no purpose column:** simplifies the registry; reduces row count;
purposes aren't enumerated in the DB (caller's typed method choice IS the
purpose binding). A purpose-mismatched decrypt fails on GCM auth tag —
defense-by-cipher.

**Trade-off:** a forensic operator inspecting an encrypted blob can't tell
"was this a TOTP secret or an OAuth2 client secret" from the envelope alone.
They can tell which `(tenant, generation)` it belongs to via the kid.
For audit/forensics, the table column the ciphertext lives in is the
purpose discriminator (`tenant_oauth2_provider.client_secret_encrypted`
is OAuth2; `app_user.totp_secret_encrypted` is TOTP). Acceptable.

### D20 — Lazy `kid` registration on first encrypt per `(tenant, generation)`

Encrypt flow:

```
encrypt(tenantId, plaintext, purpose):
    generation = SELECT generation FROM tenant_key_material WHERE tenant_id = ? AND active
    kid = SELECT kid FROM kid_to_tenant_key WHERE tenant_id = ? AND generation = ?
    if kid is null:
        kid = UUID.randomUUID()
        INSERT INTO kid_to_tenant_key (kid, tenant_id, generation) VALUES (?, ?, ?)
    dek = KeyDerivationService.deriveXxxKey(tenantId)   // recomputed every call
    ciphertext = AES-GCM(dek, plaintext)
    return base64( "FABT" || 0x01 || kid || iv || ciphertext || tag )
```

**Concurrency on first-encrypt:** two simultaneous encrypts for the same
`(tenant, generation)` could both miss the kid lookup and both insert.
Mitigations:
- Add `UNIQUE INDEX kid_to_tenant_key_unique_per_tenant_gen ON kid_to_tenant_key (tenant_id, generation)` to V61 (currently only the kid PK enforces uniqueness across kids; nothing prevents two kids for the same `(tenant, generation)`).
- Use `INSERT ... ON CONFLICT (tenant_id, generation) DO NOTHING RETURNING kid` semantics; on conflict re-SELECT to get the winning kid.
- Cache the `(tenant_id, generation) → kid` lookup with Caffeine to amortize.

**V61 schema amendment needed:** add the unique index above. **E2 + E5
(warroom):**

- E2: `KidRegistryService` uses raw `JdbcTemplate` for the
  INSERT-or-SELECT flow (Elena anti-Spring-Data-magic). Explicit SQL is
  reviewable; Spring Data JDBC's repository abstractions don't
  cleanly express the `INSERT ... ON CONFLICT (tenant_id, generation)
  DO NOTHING RETURNING kid` pattern.
- E5: V61 in-place edit means any developer who already ran their local
  stack against the old V61 schema must `./dev-start.sh --fresh` after
  pulling. The commit message that lands E5 must call this out. CI is
  unaffected (Testcontainers spins fresh DB per run).

### D21 — Backward-compat decrypt: v0 detected by magic-bytes-absence

```
decrypt(stored, tenantId, purpose):
    bytes = base64Decode(stored)
    if bytes.length >= 4 and bytes[0..4] == "FABT":
        // v1 path
        version = bytes[4]
        if version != 0x01: throw new UnsupportedVersionException()
        kid = bytes[5..21]
        tenantFromKid = lookupKidTenant(kid)
        if tenantFromKid != tenantId: throw new CrossTenantException()
        dek = KeyDerivationService.deriveXxxKey(tenantId)
        return AES-GCM-decrypt(dek, bytes[21..])
    else:
        // v0 legacy path — single-platform key
        platformKey = MasterKekProvider.getPlatformKey()
        return AES-GCM-decrypt(platformKey, bytes)
```

The magic-bytes check is the ONLY format discriminator. Any v0 ciphertext
that happens to start with `FABT\x01` would be misidentified — at 1M
ciphertexts, expected ≈ 0.00025 collisions (negligible). For absolute
safety we could lengthen the magic to 6 bytes (`FABTv1`) but the cost-vs-
collision-rate trade-off doesn't justify it.

**Cross-tenant safety check (`tenantFromKid != tenantId`):** caller passes
the tenantId they THINK the ciphertext belongs to (usually from
TenantContext). The kid_to_tenant_key lookup independently resolves the
ciphertext's actual owning tenant. Mismatch means either kid forgery or
caller bug — either way, refuse to decrypt + write audit event.

This is the SAME defensive pattern as task 2.10's JWT validate
cross-check. Same code style and audit category.

### D22 — V74 (Phase A) does bulk re-encrypt; no per-request write amplification

Two re-encryption strategies were considered:

- **A.** On every decrypt of a v0 ciphertext, encrypt under v1 and write
  back to DB. Self-healing migration — every read amortizes one rewrite.
- **B.** V74 Flyway migration scans every encrypted column, decrypts under
  v0 (single-platform key), re-encrypts under v1 (per-tenant DEK), writes
  back. One-shot bulk operation.

**Decision: B.** Reasons:

1. **Predictability.** Operator knows when the rewrite happens (the V74
   migration window) instead of "whenever someone happens to read."
2. **No per-request write amplification.** Reads stay reads. Hot-path
   latency unaffected by migration state.
3. **Idempotency.** V74 can be re-run safely (already-v1 rows skipped via
   magic-byte check).
4. **Audit clarity.** Single `SYSTEM_MIGRATION_V74_REENCRYPT` row in
   audit_events captures the event; option A would generate millions of
   "row updated by re-encrypt" entries.

Backward-compat read path stays alive forever — even after V74 completes,
the v0-detection path catches any stragglers (e.g., a row that V74
skipped due to a transient lock).

---

## Risk register

| Risk | Mitigation | Residual |
|---|---|---|
| Magic-byte collision (v0 misidentified as v1) | 4-byte ASCII "FABT" → ~1/4 billion per ciphertext | Negligible at FABT scale |
| Concurrent first-encrypt creates duplicate kids | UNIQUE (tenant_id, generation) index + ON CONFLICT DO NOTHING + Caffeine cache | Eliminated by index |
| `MasterKekProvider` constructor change breaks `SecretEncryptionServiceConstructorTest` | Move tests to `MasterKekProviderTest` | Pure test refactor; coverage preserved |
| Caller passes wrong tenantId on decrypt → kid resolves to different tenant | Cross-tenant check rejects + audits | Coverage hole if caller is the test itself; integration test must verify the audit |
| V74 partially completes → mixed v0/v1 rows in same column | Decrypt path tolerates both indefinitely; V74 is idempotent | None |
| Master KEK rotation (future Phase A future iteration) — old DEKs unrecoverable | Explicit out-of-scope for Phase A; design D3 silos rotation to Vault Transit tier | Future phase |
| `KeyDerivationService` cache stale after rotation | Phase A doesn't yet cache; lookup hits DB per call. Cache layer added in Phase C task 4.3. | Future phase |
| GCM auth tag failure on purpose mismatch | Test exercises this — purpose-mismatched decrypt MUST throw, not return garbage | Coverage in IT |
| TOTP verify fails during V74 migration window | Dual-key-accept grace per design.md:147; verify tries old then new | Documented |
| Forensic operator can't see purpose from raw bytes | Column name IS the purpose discriminator | Acceptable per D19 |

## Resolved questions (warroom 2026-04-17)

1. **Magic bytes length:** **4 bytes "FABT"**. Unanimous. The 1-byte version
   field after gives ~5 bytes of effective discrimination (1 in 1T
   collision). Cost-vs-precision doesn't justify 6.
2. **V61 schema amendment:** **in-place edit**. Unanimous. Migration on
   feature branch only ever applied to ephemeral Testcontainers DBs — see E5.
3. **Lazy vs eager kid registration:** **lazy** + UNIQUE
   `(tenant_id, generation)` index + `ON CONFLICT DO NOTHING`.
   Unanimous. Eager would couple to `TenantLifecycleService.create()` —
   premature Phase F coupling.
4. **Custom exception:** **new `CrossTenantCiphertextException extends
   RuntimeException`**, mapped to 403 + D3 envelope by
   `GlobalExceptionHandler`. Unanimous (Casey + Maria value the named
   threat for incident-narrative writing).
5. **Audit event name:** **`CROSS_TENANT_CIPHERTEXT_REJECTED`** —
   parallel to task 2.10's eventual `CROSS_TENANT_JWT_REJECTED`.
   Unanimous. `details` JSONB schema:
   `{kid, expectedTenantId, actualTenantId, actorUserId, sourceIp}` so
   incident responders can pivot.
6. **`getMasterKekBytes()` defensive `clone()`:** **ship as-designed +
   restrict visibility to package-private (E1)**. Marcus + Alex
   reinforced. Closes the accidental-serializer leak. Memory-hygiene
   zeroization stays regulated-tier (design D3).

## Implementation plan (post-warroom approval)

1. Create `MasterKekProvider`. Move validation + bytes from
   `SecretEncryptionService` constructor.
2. Refactor `SecretEncryptionService` constructor to consume
   `MasterKekProvider`.
3. Refactor `KeyDerivationService` constructor to consume
   `MasterKekProvider`.
4. Move `SecretEncryptionServiceConstructorTest` validation tests to
   new `MasterKekProviderTest`. Adjust `KeyDerivationServiceTest`
   constructor injection accordingly.
5. Add `EncryptionEnvelope` value class with constants for magic bytes
   + version + serialize/parse helpers.
6. Add `CiphertextV0Decoder` static helper that wraps the legacy decrypt
   path (detects magic-byte-absence, decrypts with platform key).
7. Add typed `SecretEncryptionService.encryptForTenant(tenantId,
   purpose, plaintext)` and `decryptForTenant(tenantId, purpose,
   ciphertext)`. Old `encrypt(plaintext)` / `decrypt(ciphertext)`
   methods become deprecated platform-only paths used solely by V74's
   migration code + the v0-fallback decrypt branch.
8. Add `KidRegistryService` that wraps the `kid_to_tenant_key` lookup +
   first-encrypt INSERT-or-SELECT pattern.
9. V61 amendment: add `UNIQUE (tenant_id, generation)` index.
10. Integration tests (E3 — expanded from 4 to 8 cases):
    - encrypt-then-decrypt round-trip per tenant
    - cross-tenant decrypt rejection
    - decrypt of pre-existing v0 ciphertext via legacy path
    - first-encrypt-race lazy-registration via 10 concurrent threads
      → assert exactly one row in `kid_to_tenant_key` per
      `(tenant, generation)`
    - **E3a:** synthetic v0 ciphertext that happens to start with
      `FABT\x01` bytes → assert v1 path fails clean (no silent corruption)
    - **E3b:** `GlobalExceptionHandler` maps `CrossTenantCiphertextException`
      to 403 with D3 `{"error":"cross_tenant","status":403,...}` envelope
    - **E3c:** audit_events row contract — assert action name
      `CROSS_TENANT_CIPHERTEXT_REJECTED` AND JSONB shape
      `{kid, expectedTenantId, actualTenantId, actorUserId, sourceIp}`
    - **E3d:** ArchUnit Family A test — `MasterKekProvider.getMasterKekBytes()`
      cannot be called from outside `org.fabt.shared.security`
11. **E4 (warroom)** — perf SLO test: first 100 encrypts on a cold-cache
    tenant ≤ 100ms each. Implementable as either (a) JMH micro-bench or
    (b) Gatling `EncryptionWarmupSimulation`. Lean: JMH — runs in CI
    without Postgres + without `BaseIntegrationTest` overhead.

## Approval gate

Before implementation: warroom thumbs-up from Marcus + Alex + Elena +
Riley. Casey check on the audit event names + the cross-tenant
exception type (per #5). Jordan check on operator visibility
(forensic read of v1 envelope).

## Out of scope for A3

- V74 migration code (Checkpoint A5)
- TOTP / webhook / OAuth2 callsite refactor to use the typed encrypt /
  decrypt methods (Checkpoints A4 + A5)
- DEK caching in `KeyDerivationService` (Phase C task 4.3)
- Master KEK rotation (separate proposal — current design assumes the
  master KEK never rotates within the Phase A timeframe)
