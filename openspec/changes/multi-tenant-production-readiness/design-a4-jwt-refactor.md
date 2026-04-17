# Phase A Checkpoint A4 — JwtService refactor design (APPROVED)

**Status:** APPROVED post-warroom 2026-04-17. 8 personas weighed in; all 6
open questions resolved unanimously; 9 enhancements (W1–W9) folded into
the decisions + implementation plan below. Casey + Marcus + Sam formal
review of the eventual A4 PR will reference this doc.

**Scope:** tasks 2.8, 2.9, 2.10, 2.11, 2.12, 2.17, 2.18. Refactors
`JwtService` to sign with per-tenant HKDF-derived signing keys + opaque
kid header + cross-tenant claim cross-check + jwt_revocations fast-path
+ rotation hook.

**Why a separate doc:** A4 affects every authenticated request — same
blast radius as A3 (and arguably higher, because A3 only touched
TOTP/webhook/OAuth2 secrets at rest while A4 touches the JWT validate
hot path). Mistakes here lock pilots out (failed validate) or grant
unauthorized access (failed rejection). Worth slow design work first.

---

## Decisions (D23–D29)

### D23 — Per-tenant JWT signing key via HKDF

`JwtService.sign(claims)` derives a per-tenant signing key:

```java
SecretKey signingKey = keyDerivationService.deriveJwtSigningKey(claim.tenantId());
```

The signing key is derived deterministically from the master KEK +
tenant UUID + purpose `"jwt-sign"`. Different tenants → different keys
cryptographically. Same tenant → same key across restarts (until
rotation bumps the generation).

HMAC-SHA256 is the chosen JWT signing algorithm — JJWT supports it
natively, no key-pair management overhead, sufficient for a
single-issuer single-validator model. (RS256 / asymmetric is regulated-
tier territory if a future tenant requires it.)

### D24 — Opaque random kid in JWT header

Per design D1: every signed JWT carries a `kid` header that's an opaque
random UUID. The kid never embeds tenant identity, generation, purpose,
or any structural information leakable to a client inspecting the
token.

```
JWT header: {"alg":"HS256", "typ":"JWT", "kid":"<uuid>"}
```

The kid is registered in `kid_to_tenant_key` via
`KidRegistryService.findOrCreateActiveKid(tenantId)` BEFORE signing.
For typical tenants this is a single kid that lives across many JWTs
(per design D19's "one kid per (tenant, generation), purpose
implicit"). The kid only changes on rotation (D27).

### D25 — `claim.tenantId` cross-check on validate (A7)

`JwtService.validate(token)`:

1. Parse header to extract kid
2. Resolve kid → (tenant_id, generation) via `KidRegistryService.resolveKid(kid)`
3. Derive the signing key for that tenant + verify signature
4. Parse claims → extract `tenantId` claim
5. **Assert `claim.tenantId == kid-resolved tenantId`**. If mismatch:
   - Increment `fabt.security.cross_tenant_jwt_rejected.count` counter
   - Publish `CROSS_TENANT_JWT_REJECTED` audit event with same shape
     as A3's `CROSS_TENANT_CIPHERTEXT_REJECTED`
   - Throw new `CrossTenantJwtException` (parallel to
     `CrossTenantCiphertextException`)
   - GlobalExceptionHandler maps to **403** (NOT 401 — this is an
     authenticated forgery attempt, not missing credentials)

This step closes the kid-confusion attack: an attacker who steals
Tenant A's signing key can sign JWTs for Tenant A's kid, but they
can't forge a JWT for Tenant B's kid+key combo even if they swap the
body `tenantId` claim.

**W1 (Marcus):** the `CROSS_TENANT_JWT_REJECTED` audit event's `details`
JSONB carries the offending JWT's body claims to aid incident response:
`{kid, expectedTenantId, actualTenantId, actorUserId, sourceIp,
claimsTenantId, claimsSub, claimsIat, claimsExp}`. Incident responders
can reconstruct what the attacker presented without retrieving the
token from logs.

### D26 — `jwt_revocations` fast-path check before signature verify

V61 `jwt_revocations(kid, expires_at, revoked_at)` is a blocklist
populated by:
- D27 rotation (bumps generation; old kids of prior generation become
  revoked with their natural exp as expires_at)
- Phase F suspend (immediate kid revocation)
- Phase F hard-delete (ON DELETE CASCADE clears the rows)

`JwtService.validate(token)` checks `jwt_revocations` BEFORE signature
verify (saves the HMAC compute on revoked tokens):

```java
if (jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM jwt_revocations WHERE kid = ?)",
                        Boolean.class, kid)) {
    throw new RevokedJwtException(kid);
}
```

Caffeine cache on the revoked-kid lookup (separate from the
KidRegistryService caches — different lifecycle). 1-minute TTL —
revocations need to propagate fast across replicas.

**Marcus + Jordan:** the cache MUST expose an `invalidateKid(UUID)`
bypass method (parallel to `KidRegistryService.invalidateKidResolution`)
so emergency revocations propagate sub-second instead of waiting up to
60s for natural eviction. The `bumpJwtKeyGeneration` flow (D27 step 5)
calls this for every kid it adds to `jwt_revocations`.

### D27 — `bumpJwtKeyGeneration(tenantId)` for rotation + suspend

New method on `TenantLifecycleService` (Phase F territory but starts
here as a stub callable from `KeyDerivationService` operator endpoint
for Phase A demo):

```java
@Transactional
public void bumpJwtKeyGeneration(UUID tenantId) {
    // 1. Mark current gen inactive
    int currentGen = jdbc.queryForObject(
        "SELECT generation FROM tenant_key_material WHERE tenant_id = ? AND active = TRUE",
        Integer.class, tenantId);
    jdbc.update(
        "UPDATE tenant_key_material SET active = FALSE, rotated_at = NOW() "
        + "WHERE tenant_id = ? AND generation = ?", tenantId, currentGen);

    // 2. Insert new active generation (W4: ON CONFLICT for retry idempotency)
    int nextGen = currentGen + 1;
    jdbc.update(
        "INSERT INTO tenant_key_material (tenant_id, generation, active) "
        + "VALUES (?, ?, TRUE) ON CONFLICT DO NOTHING", tenantId, nextGen);

    // 3. Add all outstanding kids of prior gen to jwt_revocations
    //    W5: expires_at = 7 days is the conservative ceiling — JWT max
    //    lifetime is 7d (refresh tokens), so any token signed under an
    //    old kid will be naturally expired by then. Some prune-table
    //    bloat is acceptable; tracking exact per-kid max-exp is
    //    complexity not worth the storage.
    jdbc.update(
        "INSERT INTO jwt_revocations (kid, expires_at) "
        + "SELECT kid, NOW() + INTERVAL '7 days' "
        + "FROM kid_to_tenant_key WHERE tenant_id = ? AND generation = ?",
        tenantId, currentGen);

    // 4. Bump the tenant.jwt_key_generation column
    jdbc.update(
        "UPDATE tenant SET jwt_key_generation = ? WHERE id = ?",
        nextGen, tenantId);

    // 5. Invalidate KidRegistryService cache + revocation cache
    kidRegistryService.invalidateTenantActiveKid(tenantId);
    // (kidToResolutionCache stays — old kids' resolutions are still
    //  valid for the dual-key-accept grace; revoked check below handles them)
    // For each newly-revoked kid, bypass the revocation cache TTL so
    // sub-second propagation across replicas:
    revokedKidCache.invalidateAll(jdbc.queryForList(
        "SELECT kid FROM kid_to_tenant_key WHERE tenant_id = ? AND generation = ?",
        UUID.class, tenantId, currentGen));

    // 6. W3 (Casey): publish JWT_KEY_GENERATION_BUMPED audit event so
    //    operators can demonstrate "we rotated keys per schedule" via
    //    audit query. details JSONB:
    //    {tenantId, oldGen, newGen, actorUserId, revokedKidCount}
    eventPublisher.publishEvent(new AuditEventRecord(
        currentActorUserId(), null, "JWT_KEY_GENERATION_BUMPED",
        Map.of("tenantId", tenantId.toString(),
               "oldGen", currentGen, "newGen", nextGen,
               "revokedKidCount", revokedCount), null));
}
```

Atomic via `@Transactional`. Cache invalidation per the post-A3
warroom hooks (added this session). All 6 steps run inside the same
transaction; partial failure rolls everything back.

### D28 — Backward-compat path: legacy JWTs accepted during cutover window

Existing access tokens (15-min) + refresh tokens (7-day) are signed
under the legacy `FABT_JWT_SECRET` HMAC. After Phase A4 ships, every
new token signs under the per-tenant key. **What happens to in-flight
legacy tokens?**

Two options:

- **A — hard cutover.** All legacy tokens immediately rejected; users
  forced to re-login. Simple but causes a coordinated outage.
- **B — dual-validate window.** `JwtService.validate(token)`:
  1. If token has `kid` header → new path (D25)
  2. If token has NO `kid` header → legacy path (HMAC verify with
     `FABT_JWT_SECRET`); accepted for 7 days post-cutover (refresh
     token max lifetime); after 7 days the legacy code path is
     deleted.

**Decision: B (dual-validate).** Per `proposal.md`: *"Coordinated
re-login window — pilots receive notice; existing JWTs invalidated at
cutover"* — but option B reduces the outage to "users get a fresh
login on first access" rather than "all sessions die at deploy
moment." Operationally smoother. The 7-day window is bounded by
refresh-token max age; after that no legacy tokens exist by definition.

**W2 (Alex):** path selection MUST use explicit if/else on header
presence — NOT try-new-catch-fall-back-to-legacy. The latter would
silently legacy-accept a JWT with an unknown kid (a forgery attempt
where the attacker invented a `kid` value). Pseudocode:

```java
public Authentication validate(String token) {
    if (parseHeader(token).get("kid") == null) {
        return legacyValidate(token);   // FABT_JWT_SECRET HMAC
    }
    return newValidate(token);          // throws on any failure
                                         // (unknown kid, sig fail, revoked, etc.)
}
```

**Marcus:** add `fabt.security.legacy_jwt_validate.count` counter every
time the legacy path runs. A spike during the 7-day window could
indicate the cleanup is not happening (forgotten clients) OR
compromise (forged legacy tokens). Operator can monitor + decide.

**Jordan J1:** at A4 deploy moment, file a 7-day calendar reminder +
follow-up issue: "remove legacy JwtService.legacyValidate code path +
delete `fabt.security.legacy_jwt_validate.count` counter." After the
window, the calendar fires and the cleanup PR ships.

**Marcus also:** add an ArchUnit Family A rule preventing references
to `FABT_JWT_SECRET` from any class outside `JwtService.legacyValidate`
during the window, so accidental new uses can't compound the cleanup
debt.

### D29 — `kid_to_tenant_key` Caffeine cache for sub-µs validate

Per A3.2.2 + post-warroom W-A3-1: `KidRegistryService.resolveKid(kid)`
already has a 100k-entry, 1-hour-TTL Caffeine cache. This same cache
serves the JWT validate path. No additional cache needed for D29 —
already done in A3.

The `jwt_revocations` lookup (D26) does need its own cache (different
shape, different TTL), but that's a small addition inside JwtService.

---

## Risk register

| Risk | Mitigation | Residual |
|---|---|---|
| Stolen tenant DEK → forge any JWT for that tenant | Per-tenant key blast-radius is one tenant, not the whole platform; rotation via D27 flushes the key in seconds | Acceptable; same as Phase 0 platform-key compromise but narrower |
| Kid-confusion attack (sign with A's key, claim B's tenant) | D25 cross-check rejects with audit + 403 | Eliminated |
| Legacy-JWT-accept window (D28) extends attack surface | 7-day bounded; legacy tokens already had this window pre-Phase-A; no new exposure | None — net-neutral |
| Rotation cache staleness | D27 invalidates `tenantToActiveKidCache`; 5-min worst case for `kidToResolutionCache` (TTL bound) | 5-min stale post-rotation acceptable for any non-emergency rotation; emergency rotation should `invalidateKidResolution` per kid |
| `jwt_revocations` cache stale (D26) | 1-min TTL; emergency-revoke flow can `invalidate(kid)` for sub-second propagation | 1-min worst case |
| `bumpJwtKeyGeneration` partial failure mid-transaction | `@Transactional` ensures atomicity; either all 5 steps succeed or none | None |
| Pre-Phase-A tokens signed under FABT_JWT_SECRET don't have `kid` header | D28 dual-validate path detects absence + falls back to legacy verify | Mitigated; expires in 7 days |
| Legacy code path removal after grace window | Calendar reminder + ArchUnit rule "no class outside JwtService.legacyValidate may reference FABT_JWT_SECRET" | Deferred to post-cutover |
| `CrossTenantJwtException` 403 vs UnauthorizedException 401 confusion | Distinct mapping in GlobalExceptionHandler — 403 for forgery, 401 for missing/expired | Clear |

## Resolved questions (warroom 2026-04-17)

1. **Cutover:** dual-validate (D28). Unanimous. Casey: not a HIPAA
   downgrade (new path is strictly stronger; legacy path uses the same
   platform key Phase 0 already validates). Marcus: net-neutral attack
   surface; legacy code path doesn't expand exposure beyond pre-A baseline.
   See D28 for path-selection logic clarification (W2) + counter (Marcus)
   + ArchUnit rule + 7-day cleanup reminder (Jordan J1).
2. **`jwt_revocations` cache TTL:** 1 minute + `invalidateKid(UUID)`
   bypass for emergency revoke. Elena: DB load negligible at FABT scale.
3. **Service location:** new `TenantKeyRotationService` in
   `org.fabt.shared.security`. Alex: don't couple to Phase F's
   not-yet-existent `TenantLifecycleService`. Phase F absorbs later.
4. **Operator endpoint:** admin-only
   `POST /api/v1/admin/tenants/{id}/rotate-jwt-key` → 202 + audit event,
   rate-limited to 1 rotation/tenant/min (Marcus + Jordan, prevents
   accidental rapid-rotation that could exhaust DB connections). Dry-run
   mode (`?dry-run=true`) deferred to follow-up.
5. **Custom exception types:** `CrossTenantJwtException` (→ 403) +
   `RevokedJwtException` (→ 401). Parallel to A3's pattern; grep-friendly
   for incident response.
6. **JJWT version + algorithm:** code-read of existing `JwtService` is
   step 1 of the implementation plan. Pin to a specific JJWT version +
   write a sanity test asserting kid header presence in parsed token
   (Riley).

## Implementation plan (post-warroom approval)

1. Read existing `JwtService` + `JwtAuthenticationFilter` + `JwtDecoderConfig`
   to map current architecture.
2. New `RevokedKidCache` — Caffeine + JdbcTemplate `SELECT EXISTS` lookup.
3. New `TenantKeyRotationService` with `bumpJwtKeyGeneration(tenantId)`
   per D27.
4. New `CrossTenantJwtException` + `RevokedJwtException`.
5. Refactor `JwtService.sign` to use per-tenant key + emit kid header.
6. Refactor `JwtService.validate` with the 5-step flow per D25 + D26 +
   D28 dual-validate.
7. Wire `GlobalExceptionHandler` for `CrossTenantJwtException` (403)
   and `RevokedJwtException` (401).
8. New `POST /api/v1/admin/tenants/{id}/rotate-jwt-key` controller +
   admin auth.
9. Integration tests (8 cases per warroom W7 + W8):
   - T1 sign + validate round-trip per tenant
   - T2 cross-tenant kid confusion: sign with A's key, swap body to B's
     tenantId, assert validate rejects + audit (with W1 enriched JSONB)
   - T3 rotation: bump tenant A's gen, assert old-gen JWTs rejected,
     new-gen accepted, tenant B unaffected
   - T4 legacy JWT (no kid header) signed under FABT_JWT_SECRET → still
     accepted via D28 path
   - T5 jwt_revocations fast-path: revoke a kid, assert validate
     rejects within cache TTL
   - T6 rotation cache invalidation: bump gen, assert next sign uses
     new kid (no stale-cache window)
   - **T7 (W8) dual-key-accept grace:** rotate, assert old-gen kid
     STILL validates BETWEEN the rotation and revocation expiry, then
     stops validating after revocation expires
   - **T8 (W7) rotation atomicity:** simulate D27 step 4 failure (e.g.,
     UPDATE tenant trips a CHECK constraint), assert NONE of steps 1-3
     persisted (tenant_key_material rollback, jwt_revocations rollback)
10. Plus a `GlobalExceptionHandlerJwtTest` covering both
    `CrossTenantJwtException` (403, audit shape) and `RevokedJwtException`
    (401, no audit) — parallel to A3's `GlobalExceptionHandlerCrossTenantTest`.

## Approval gate

**APPROVED 2026-04-17 via warroom.** All 8 personas weighed in;
unanimous on the 6 open questions; 9 enhancements (W1–W9) folded into
the design above. No further approval needed before implementation —
Casey + Marcus + Sam will review the eventual A4 PR using this doc as
the canonical pre-flight record.

## Out of scope for A4

- Vault Transit alternative path (task 2.15)
- `docs/security/key-rotation-runbook.md` (task 2.16, Devon training note)
- Phase F's `TenantLifecycleService` integration (Phase F)
- Asymmetric JWT signing (RS256 / regulated-tier — separate proposal)
- Token theft detection / anomaly alerting (separate scope)
- **W6:** `kid_to_tenant_key` orphan-row GC scheduled task — Alex's
  concern about post-rotation accumulation; Phase F crypto-shred handles
  tenant-level cleanup, rotation-only cleanup is a follow-up issue
- **W9 (Maria + Devon):** pilot cutover communication + admin-rotation-
  feature mention in onboarding docs — folded into Devon's existing
  training task + Casey's runbook authoring
