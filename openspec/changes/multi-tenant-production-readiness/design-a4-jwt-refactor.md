# Phase A Checkpoint A4 — JwtService refactor design (DRAFT for warroom)

**Status:** DRAFT — pre-implementation. Warroom review precedes code in
`feature/multi-tenant-production-readiness-phase-a` Checkpoint A4.

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

    // 2. Insert new active generation
    int nextGen = currentGen + 1;
    jdbc.update(
        "INSERT INTO tenant_key_material (tenant_id, generation, active) "
        + "VALUES (?, ?, TRUE)", tenantId, nextGen);

    // 3. Add all outstanding kids of prior gen to jwt_revocations
    jdbc.update(
        "INSERT INTO jwt_revocations (kid, expires_at) "
        + "SELECT kid, NOW() + INTERVAL '7 days' "
        + "FROM kid_to_tenant_key WHERE tenant_id = ? AND generation = ?",
        tenantId, currentGen);

    // 4. Bump the tenant.jwt_key_generation column
    jdbc.update(
        "UPDATE tenant SET jwt_key_generation = ? WHERE id = ?",
        nextGen, tenantId);

    // 5. Invalidate KidRegistryService caches
    kidRegistryService.invalidateTenantActiveKid(tenantId);
    // (kidToResolutionCache stays — old kids' resolutions are still
    //  valid for the dual-key-accept grace; revoked check above handles them)
}
```

Atomic via `@Transactional`. Cache invalidation per the post-A3
warroom hooks (added this session).

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

## Open questions for warroom

1. **Hard cutover vs dual-validate window (D28).** My lean: dual-validate
   for 7 days = bounded by refresh-token max lifetime. Casey/Marcus check
   for whether the cleanup commitment ("delete legacy code path after
   7 days") is operationally realistic.
2. **`jwt_revocations` cache TTL.** 1 minute = balance between
   cross-replica propagation speed + DB load. Open to 30s if Marcus
   wants tighter. Or longer if Sam wants less DB churn.
3. **Where does `bumpJwtKeyGeneration` live?** `KeyDerivationService`?
   New `TenantKeyRotationService`? Phase F's `TenantLifecycleService`?
   My lean: new `TenantKeyRotationService` in
   `org.fabt.shared.security` for now; Phase F can absorb it later.
4. **Operator endpoint to trigger rotation in Phase A.** Just for
   testing? Or production-ready admin UI? My lean: admin-only
   `POST /api/v1/admin/tenants/{id}/rotate-jwt-key` returning 202 +
   audit event, no UI yet (Phase F adds the UI).
5. **`CrossTenantJwtException` vs reusing `CrossTenantCiphertextException`.**
   Different conceptual surface (JWT vs ciphertext) but same audit
   pattern. Distinct exception = grep-friendly per Casey/Marcus's
   reasoning in A3 Q4. My lean: distinct.
6. **JJWT version + algorithm selection.** Existing JwtService likely
   uses HS256 (HMAC-SHA256) under FABT_JWT_SECRET. Phase A keeps HS256
   but with per-tenant derived keys. Should I confirm JJWT supports
   per-call `SecretKey` injection (vs requiring a static signing key)?
   Belief: yes, but worth a quick code-read of existing JwtService
   before implementation.

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
9. Integration tests:
   - Sign + validate round-trip per tenant (T1)
   - Cross-tenant kid confusion: sign with A's key, swap body to B's
     tenantId, assert validate rejects + audit (T2)
   - Rotation: bump tenant A's gen, assert old-gen JWTs rejected,
     new-gen accepted, tenant B unaffected (T3)
   - Legacy JWT (no kid header) signed under FABT_JWT_SECRET → still
     accepted via D28 path (T4)
   - jwt_revocations fast-path: revoke a kid, assert validate rejects
     within cache TTL (T5)
   - Rotation cache invalidation: bump gen, assert next sign uses new
     kid (T6)

## Approval gate

Before implementation: warroom thumbs-up from Marcus + Alex + Elena +
Riley + **Sam** (perf) + **Casey** (legal — D28 dual-validate window
+ rotation audit shape) + **Jordan** (operator-trigger endpoint).

## Out of scope for A4

- Vault Transit alternative path (task 2.15)
- `docs/security/key-rotation-runbook.md` (task 2.16)
- Phase F's `TenantLifecycleService` integration (Phase F)
- Asymmetric JWT signing (RS256 / regulated-tier — separate proposal)
- Token theft detection / anomaly alerting (separate scope)
