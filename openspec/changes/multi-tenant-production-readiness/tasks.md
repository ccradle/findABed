## 1. Phase 0 — Foundation + latent fix (1 week)

- [x] 1.1 Create branch `feature/multi-tenant-production-readiness` from main HEAD
- [x] 1.2 Add `docs/architecture/tenancy-model.md` (H1) — pool-by-default + silo-on-trigger ADR
- [x] 1.3 Add `docs/security/timing-attack-acceptance.md` (D10, I1) — UUID-not-secret ADR
- [x] 1.4 [LATENT A4] Encrypt `TenantOAuth2Provider.clientSecretEncrypted` in `TenantOAuth2ProviderService.create/update` — call `SecretEncryptionService.encrypt()` before save
- [x] 1.5 [LATENT A4] Encrypt `HmisVendorConfig.apiKeyEncrypted` in `HmisConfigService` paths — same pattern
- [x] 1.6 Flyway V59 — re-encrypt existing plaintext OAuth2 + HMIS credentials in-place (idempotent; reads plaintext, writes ciphertext, verifies, commits)
- [x] 1.7 Integration test: round-trip OAuth2 client secret through encryption; pre-fix state simulated via manual INSERT of plaintext + verify migration encrypts on startup
- [x] 1.8 Integration test: round-trip HMIS apiKey through encryption
- [x] 1.9 Update CHANGELOG.md with Phase 0 bullet under `## [Unreleased]`
- [x] 1.10 Commit Phase 0 + open PR #127 with Casey review (legal-scan of code comments) + Marcus review (threat-model of encryption path)

## 2. Phase A — Per-tenant JWT + DEK derivation (2 weeks)

- [x] 2.1 Flyway V60 — `tenant` table additions: `state TenantState NOT NULL DEFAULT 'ACTIVE'`, `jwt_key_generation INT NOT NULL DEFAULT 1`, `data_residency_region VARCHAR(50) NOT NULL DEFAULT 'us-any'`, `oncall_email VARCHAR(255)`
- [x] 2.2 Create `tenant_key_material(tenant_id, generation, created_at, rotated_at, active)` table (Flyway addition) — bundled into V61
- [x] 2.3 Create `kid_to_tenant_key(kid UUID PRIMARY KEY, tenant_id UUID NOT NULL REFERENCES tenant(id), generation INT NOT NULL, created_at TIMESTAMPTZ NOT NULL)` table — bundled into V61
- [x] 2.4 Create `jwt_revocations(kid UUID PRIMARY KEY, expires_at TIMESTAMPTZ NOT NULL)` table + daily pruning scheduled task
- [x] 2.5 Implement `KeyDerivationService` — HKDF-SHA256 with context `"fabt:v1:<tenant-uuid>:<purpose>"` (per D2)
- [x] 2.6 Refactor `SecretEncryptionService` to delegate to per-tenant DEK via `KeyDerivationService.forTenant(tenantId).derive("totp" | "webhook-secret" | "oauth2-client-secret" | "hmis-api-key")` — typed `encryptForTenant(tenantId, KeyPurpose, plaintext)` + `decryptForTenant(tenantId, KeyPurpose, stored)` per A3 D17/D19
- [x] 2.7 Add `kid` prefix to ciphertext format: v1 envelope `[FABT magic + version + kid + iv + ct+tag]`; backward-compat decrypt detects v0 by magic-bytes-absence per A3 D18/D21
- [x] 2.8 Refactor `JwtService.sign` to use per-tenant signing key (derived via `KeyDerivationService.forTenant(tenantId).derive("jwt-sign")`); emit `kid=<random-uuid>` in JWT header (D1); insert row into `kid_to_tenant_key`
- [x] 2.9 Refactor `JwtService.validate` to resolve `kid` via `kid_to_tenant_key` cache → tenant + generation → derive signing key → verify (D1)
- [x] 2.10 Add `JwtService.validate` assertion: `claim.tenantId` MUST equal `kid`-resolved tenant (A7); reject if mismatch with dedicated audit event
- [x] 2.11 Add `kid_to_tenant_key` in-memory cache (Caffeine; bounded ~100k entries; TTL 1 hour) for sub-microsecond validate — implemented in A3 (`KidRegistryService.kidToResolutionCache`) + A4.1 (`RevokedKidCache` for revocation fast-path)
- [x] 2.12 Implement `TenantLifecycleService.bumpJwtKeyGeneration(tenantId)` — increments generation + adds all outstanding kids of the prior generation to `jwt_revocations` with their natural expiry — landed as `TenantKeyRotationService` (org.fabt.shared.security) per warroom Q3; Phase F can absorb later
- [ ] 2.13 Flyway V74 — re-encrypt existing v0 ciphertexts under per-tenant DEKs. Scope per A3 D22 + design-a5: TOTP (`app_user.totp_secret_encrypted`) + webhook (`subscription.callback_secret_hash`) + OAuth2 (`tenant_oauth2_provider.client_secret_encrypted`) + HMIS (`tenant.config → hmis_vendors[].api_key_encrypted`). Idempotent via v1 magic-byte skip; indefinite v0 fallback on read path (D42). See `design-a5-v74-reencrypt.md` for per-decision detail + warroom resolutions.
  - [ ] 2.13.1 Write `V74__reencrypt_secrets_under_per_tenant_deks.java` (Java Flyway migration; package `db.migration`) — preflight Phase A (C-A5-N7) + dev-skip guard (C-A5-N9) + `SET LOCAL lock_timeout/statement_timeout` (C-A5-N1) + round-trip verify per row (C-A5-N3) + audit row with expanded JSONB via Jackson (C-A5-N10 + W-A5-1) + hardened ObjectMapper StreamReadConstraints (C-A5-N5) + structured "V74 COMMITTED" log (W-A5-6)
  - [ ] 2.13.2 Migration column walk: `app_user.totp_secret_encrypted` (WHERE `tenant_id IS NOT NULL` — C-A5-N2; `FOR UPDATE` — W-A5-4)
  - [ ] 2.13.3 Migration column walk: `subscription.callback_secret_hash` (same guards)
  - [ ] 2.13.4 Migration column walk: `tenant_oauth2_provider.client_secret_encrypted` (same guards)
  - [ ] 2.13.5 Migration column walk: `tenant.config → hmis_vendors[].api_key_encrypted` (JSONB walker; hardened parser)
  - [ ] 2.13.6 Refactor `TotpService.encryptSecret` + `decryptSecret` to accept `UUID tenantId` parameter (D38); update `TotpController.enrollTotp`, `TotpController.confirmTotpEnrollment`, `AuthController` MFA verify callsites
  - [ ] 2.13.7 Refactor `SubscriptionService.create` internally to call `encryptForTenant(tenantId, WEBHOOK_SECRET, callbackSecret)`; refactor `SubscriptionService.decryptCallbackSecret` to accept `UUID tenantId`; update `WebhookDeliveryService` callsites (both `test` and normal delivery paths)
  - [ ] 2.13.8 Refactor `TenantOAuth2ProviderService` encrypt callsites to `encryptForTenant(tenantId, OAUTH2_CLIENT_SECRET, ...)`; refactor `DynamicClientRegistrationSource` decrypt callsite to `decryptForTenant`
  - [ ] 2.13.9 Refactor `HmisConfigService.encryptApiKey` + `decryptApiKey` to accept `UUID tenantId`; update in-module callsites
  - [ ] 2.13.10 Add `CiphertextV0Decoder` "DO NOT REMOVE" class-level Javadoc (W-A5-5); mark legacy `SecretEncryptionService.encrypt/decrypt` `@Deprecated(forRemoval = true)` (Q5)
  - [ ] 2.13.11 Add `fabt.security.v0_decrypt_fallback.count` counter (tagged by purpose + tenant_id) + throttled `CIPHERTEXT_V0_DECRYPT` audit event in `SecretEncryptionService.decryptForTenant` v0-fallback branch (C-A5-N4)
  - [ ] 2.13.12 Integration test `V74ReencryptIntegrationTest` — T1 happy-path + T2 idempotency + T3 cross-tenant DEK separation + T4 expanded (truncated / forged-kid / unregistered-kid v1 envelopes per W-A5-2) + T5 empty-table + T6 dev-skip + T7 V59-produced-v0 unwrap + T8 kid bootstrap + T9 audit row contract + T10 refactored-service ITs + T11 `KeyPurpose.values()` round-trip loop (W-A5-3) + JSONB edge cases (Jordan W2)
  - [ ] 2.13.13 Integration test `V74RestrictedRoleTest` — runs V74 under a role without BYPASSRLS; expected failure is loud not silent-filtered (C-A5-N6)
  - [ ] 2.13.14 Add release gate: `CHANGELOG.md` [Unreleased] LEADS with "v0.41 → v0.42 is effectively one-way" + task 2.16 precondition note (C-A5-N8)
  - [ ] 2.13.15 Update memory `project_multi_tenant_phase0_resume.md` — mark task 2.13 [x]; strip 7-day-grace claim from Phase A.5 followups
  - [ ] 2.13.16 `/opsx:sync` — update `per-tenant-key-derivation/spec.md`: strip "Grace window closes after 7 days" scenario; add "v0 fallback decrypt path remains as defense-in-depth" scenario per D42; rename "Existing TOTP ciphertext re-wrapped by V73" typo scenario to V74
- [x] 2.14 Add prod-profile guard on `FABT_ENCRYPTION_KEY` (the master KEK in Phase A's HKDF derivation) — already shipped as the Phase 0 C2 hardening; this task subsumed by Phase 0 work since Phase A reuses the same env var rather than introducing a new one
- [ ] 2.15 Add HashiCorp Vault Transit integration adapter (`VaultTransitKeyDerivationService`) as alternative `KeyDerivationService` implementation for regulated tier (D3); env-var-selectable via `FABT_KEY_SOURCE=env|vault`
- [ ] 2.16 Document `docs/security/key-rotation-runbook.md` — per-tenant DEK rotation + master KEK rotation procedures with RTO per scenario (L10)
- [x] 2.17 Integration test: rotation `bumpJwtKeyGeneration(A)`; assert old-gen JWTs rejected, new accepted, Tenant B unaffected — `TenantKeyRotationServiceIntegrationTest` (10 cases including atomicity, concurrent-rotation race, cross-tenant isolation, audit row contract)
- [x] 2.18 Integration test: cross-tenant kid confusion — sign with Tenant A key, swap body tenantId to B, verify rejected with dedicated audit — `JwtServiceV1IntegrationTest.crossTenantRejection` + `GlobalExceptionHandlerJwtTest` (audit JSONB shape contract)
- [ ] 2.19 Unit test: HKDF derivation reproducibility — same tenantId + same purpose + same KEK → same derived key
- [ ] 2.20 Unit test: HKDF derivation separation — different tenantId OR different purpose → different derived key
- [ ] 2.21 Commit Phase A + open PR (coordinated 7-day re-login notice window begins)

## 3. Phase B — Database-layer hardening (2 weeks)

- [x] 3.1 Verify prod Postgres image version ≥ 16.5; if below, upgrade via independent pre-cutover deploy step (B1, CVE-2024-10976) — **live prod PG 16.13 as of v0.44.1 (2026-04-18)**
- [x] 3.2 Add CI check in `.github/workflows/ci.yml` that rejects PRs against Postgres < 16.5 via Testcontainers config — **DONE v0.45.0**: `PgVersionGate` (`@Component`/`@PostConstruct` in `org.fabt.shared.security`) halts JVM boot when `server_version_num < 160005`; paired `PgVersionGateTest` extends `BaseIntegrationTest` and asserts the CI image sits above the floor. Dual-layer per v0.45.0 warroom (IT-only would tautologically pass; startup gate catches prod drift). Floor doubles as CVE gate — revisit on every Postgres minor release (runbook entry added).
- [x] 3.3 Flyway V68 → **shipped as V67** — `fabt_current_tenant_id()` LEAKPROOF SQL function wrapping `current_setting('app.tenant_id', true)` *(version number drifted because v0.42 Phase A5 took V74; Phase B used V67-V72)*
- [x] 3.4 Flyway V67 → **shipped as V68** — D14 tenant-RLS policies on 7 regulated tables (`audit_events`, `hmis_audit_log`, `password_reset_token`, `one_time_access_code`, `hmis_outbox`, `tenant_key_material`, `kid_to_tenant_key`). `totp_recovery` is not in the set (table doesn't exist as of Phase A; TOTP uses `app_user.totp_secret_encrypted` directly which is tenant-scoped via user row). Pre-auth tables use PERMISSIVE-SELECT + RESTRICTIVE-WRITE split per D45.
- [x] 3.5 Flyway V69 — FORCE ROW LEVEL SECURITY on all 7 regulated tables. `fabt_rls_force_rls_enabled{table}=1.0` live on prod.
- [x] 3.6 Flyway V70 → **shipped as V71** — supporting indexes on `(tenant_id, expires_at)` for `password_reset_token` + `one_time_access_code`. Audit-table pre-existing btree on `(tenant_id, target_user_id, timestamp DESC)` covers EXPLAIN regression.
- [ ] 3.7 Flyway V71 — list-partition `audit_events` by `tenant_id` (B8); partition-creation hook in `TenantLifecycleService.create` (F3); partition-drop hook in hard-delete (F6) — **scope-deferred by warroom; audit_events <100k rows doesn't justify partitioning cost yet**
- [ ] 3.8 Flyway V71 (continued) — list-partition `hmis_audit_log` by `tenant_id` — **scope-deferred with 3.7**
- [x] 3.9 Flyway V72 → **shipped as V70 + V72** — V70 REVOKE UPDATE, DELETE on audit tables; V72 REVOKE TRUNCATE, REFERENCES (checkpoint-2 warroom added V72 on top of V70). `platform_admin_access_log` table doesn't exist in v1 (G2 deferred to regulated-tier roadmap).
- [x] 3.10 Flyway V73 — pgaudit config via `ALTER DATABASE ... SET pgaudit.*` (live as of v0.44.1 2026-04-18). Debian+PGDG image swap in deploy/pgaudit.Dockerfile + manual `CREATE EXTENSION pgaudit` step documented in oracle-update-notes-v0.44.0.md + amendments.
- [x] 3.11 Configure `pgaudit.log = 'write,ddl'` + `pgaudit.log_level = 'log'` **DONE**; include `app.tenant_id` in log format — **DONE v0.45.0**: `RlsDataSourceConfig.applyRlsContext` now sets `application_name = 'fabt:tenant:<uuid>'` co-located with `app.tenant_id` in the same prepared statement (drift-safety: a divergence means pgaudit would log the wrong tenant for a query). `deploy/pgaudit.conf` adds `%a` to `log_line_prefix` so pgaudit log lines actually carry the tag. Covered by `PgauditApplicationNameDriftTest` (sequential alternating + null-tenant + concurrent virtual-thread invariant).
- [x] 3.12 `docs/security/pg-policies-snapshot.md` shipped at Phase B merge. Companion `scripts/phase-b-rls-snapshot.sh` regenerates. SHA-256 pin against tag commit is W-CHANGELOG-1 follow-up (Phase C).
- [ ] 3.13 CI check diffing live-DB `pg_policies` against snapshot — **grep-guard `phase-b-rls-test-discipline` exists in ci.yml but is not a live-DB diff**; deferred to Phase C (task #165 bundle)
- [x] 3.14 Migration-lint ArchUnit-for-SQL SECURITY DEFINER rule — **DONE v0.45.0**: `MigrationLintTest` (`org.fabt.architecture`) scans every `V*.sql` + `V*.java` Flyway migration for `SECURITY DEFINER`; allowlist is empty + entries require warroom/design citation. Rationale: `SECURITY DEFINER` runs with the function-owner's privileges (fabt has BYPASSRLS) — would reintroduce owner-bypass Phase B V69 is built to block.
- [ ] 3.15 `SET LOCAL statement_timeout` wrapper — **depends on Phase E rate-limit config (TenantRateLimitConfig)**
- [ ] 3.16 `SET LOCAL work_mem` wrapper — **depends on Phase E**
- [x] 3.17 ArchUnit rule: `@Transactional` methods must not call `TenantContext.runWithContext()` inside the transaction (B11 per `feedback_transactional_rls_scoped_value_ordering.md`) — `TenantContextTransactionalRuleTest` with 2-entry allowlist (HmisPushService.processOutbox, ReservationService.expireReservation) carrying documented carve-out justifications
- [x] 3.18 Extend `TenantIdPoolBleedTest` with B12 scenario — **DONE v0.45.0**: `RlsAwareDataSourceFailureTest` (unit, 3 @Tests) covers the B12 invariant — if `applyRlsContext` fails mid-setup the borrowed connection MUST be closed before `SQLException` escapes, preventing a half-configured connection from returning to the pool with stale `app.tenant_id`. Unit-test approach chosen over IT because manufacturing a `SET ROLE` failure needs DB-level GRANT manipulation; the decorator's error path is 5 lines and unit-testable with mocked JDBC types.
- [x] 3.19 Integration test `current_user = 'fabt_app'` post-connection-borrow — **DONE v0.45.0**: covered by `PhaseBRlsEnforcementTest.connectionBorrow_runsAsFabtAppRole`. Asserts `SELECT current_user` returns `fabt_app` after every borrow, both under TenantContext and under null context (scheduled-job case).
- [x] 3.20 `docs/security/logical-replication-posture.md` — v1 stance doc shipped at Phase B close-out (2026-04-18)
- [x] 3.21 Cross-tenant RLS enforcement IT — **DONE v0.45.0**: `PhaseBRlsEnforcementTest.crossTenantSelectOnAuditEvents_rlsHidesOtherTenantRows` — inserts an `audit_events` row under tenant A, asserts tenant A still sees it (sanity), asserts tenant B sees zero rows. Load-bearing invariant of V68+V69.
- [x] 3.22 Owner-bypass prevention IT — **DONE v0.45.0**: `PhaseBRlsEnforcementTest` covers two flavors — (a) `auditEvents_updateAndDeleteRevoked_defenseInDepth` asserts V70's REVOKE of UPDATE+DELETE is active (fabt_app gets "permission denied" for UPDATE/DELETE on audit_events), (b) `crossTenantInsertWithForeignTenantId_blockedByWithCheck` asserts WITH CHECK clause rejects an INSERT claiming a different tenant_id.
- [ ] 3.23 pg_policies snapshot drift IT — **still deferred** (requires snapshot-diff CI job; see Phase C bundle).
- [x] 3.24 pgaudit log-entry IT per tenant-scoped write — **DONE (pre-v0.45)**: `PgauditLogEntryTest` (`@Tag("pgaudit")`, runs in `pgaudit-tests` Maven profile with pre-built `fabt-pgaudit:ci` image) asserts pgaudit emits AUDIT lines for regulated writes + `ALTER TABLE ... NO FORCE ROW LEVEL SECURITY` DDL.
- [x] 3.25 Commit Phase B + open PR — **merged as PR #131 (commit `9a83562`) 2026-04-18; shipped to demo as v0.43.1 + v0.44.1**

## 4. Phase C — Cache isolation (1 week)

Ordering reflects the design warroom resolution (2026-04-19): Redis ADR first (pure-doc, informs design), wrapper + unit tests second (narrow contract with fast feedback), EscalationPolicy split before Family C rule extension (avoids rule-goes-red-on-first-run), Family C scope extended to `*.api` + `*.security` + `*.auth.*` alongside `*.service` per inventory findings (10 Caffeine fields vs. 3 originally named).

- [x] 4.0 `docs/architecture/redis-pooling-adr.md` (C4) — **DONE 2026-04-19**: ADR published at `finding-a-bed-tonight/docs/architecture/redis-pooling-adr.md`. Three-shape taxonomy (pooled+L1-only today, pooled+L2-single-tenant authorised, silo+L2-silo regulated); shared Redis without ACL-per-tenant rejected as default; ACL shape deferred behind future-addendum gate. Warroom sign-off: Alex + Marcus + Jordan + Sam. Cross-refs tenancy-model.md + spec tenant-scoped-cache + design-c-cache-isolation.md + project_standard_tier_untested.md.
- [x] 4.0b ADR amendments 2026-04-19 PM — extended warroom (Casey + Riley + Elena) + external standards pass (OWASP ASVS 5.0, Redis Inc. Feb 2026, Azure Apr 2026, HIPAA Dec 2025). Six additive clarifications: Phase-A3 DEK compensating control on shape 2 blast-radius; `invalidateTenant` idempotency guarantee; concrete Redis-backed bleed harness pattern; new "Cached-value tenant verification" section (write-side defence); shape-2 Redis-ACL-not-automatic rationale; shape-3 HIPAA/VAWA encryption scope (AES-256 + TLS 1.3); authoritative-standards cross-references.
- [x] 4.1 **DONE 2026-04-19** (feature branch `feature/phase-c-task-4.1-tenant-scoped-cache-wrapper`, commit `c4e9541`). `TenantScopedCacheService` in `org.fabt.shared.cache` — new Spring bean, NOT `@Primary`. Four-contract implementation: key prefix with `|`, value stamp-and-verify via `TenantScopedValue<T>` envelope + `CROSS_TENANT_CACHE_READ` ISE on mismatch via `DetachedAuditPersister` REQUIRES_NEW audit, `invalidateTenant(UUID)` idempotent across retries emitting `TENANT_CACHE_INVALIDATED` with per-cache eviction counts, full Micrometer observability. Exception messages carry action tags only — no UUIDs. Defensive `IllegalArgumentException` on null value at put.
- [x] 4.1a **DONE 2026-04-19**: `CacheService.evictAllByPrefix(cacheName, prefix)` added. Caffeine impl uses `cache.asMap().keySet()` filter. Tiered impl filters L1 identically + carries a Redis-L2 TODO with the correct `SCAN MATCH <prefix>* COUNT 1000` + `UNLINK` shape documented inline.
- [x] 4.1b **DONE 2026-04-19**: Registry eager-seeded at `@PostConstruct` from `CacheNames` reflection (11 constants discovered on boot). Fail-fast on empty seed via `IllegalStateException`. `fabt.cache.registered_cache_names` gauge + INFO-level startup log publish the seeded set.
- [x] 4.1c **DONE 2026-04-19**: `TENANT_CACHE_INVALIDATED` + `CROSS_TENANT_CACHE_READ` + `MALFORMED_CACHE_ENTRY` constants added to `AuditEventTypes`. `AuditEventTypesTest` pinned all three with non-null + non-blank + exact-string assertions (11 pins total now).
- [x] 4.8 **DONE 2026-04-19** (unit test): `TenantScopedCacheService` throws `IllegalStateException` tagged `TENANT_CONTEXT_UNBOUND` on both `get` and `put` when no `TenantContext` is bound. Exception message verified to contain NO UUID.
- [x] 4.9 **DONE 2026-04-19** (unit test): `|` separator; tenant A put + tenant A get returns written value; tenant B get for same logical key returns miss; `fabt.cache.get{result=hit|miss}` + `fabt.cache.put` counters verified.
- [x] 4.9b **DONE 2026-04-19** (unit test): `invalidateTenant(tenantA)` evicts A entries across all caches; B entries survive; audit row emitted with per-cache eviction counts in details.
- [x] 4.9c **DONE 2026-04-19** (unit test): cross-tenant cache-poisoning regression. Write envelope stamped tenant A into tenant B's prefixed slot; wrapper read with `TenantContext=B` throws `CROSS_TENANT_CACHE_READ`; `DetachedAuditPersister.persistDetached` verified invoked; event-bus publisher verified NOT invoked (security audit path is detached only); exception message = "CROSS_TENANT_CACHE_READ" (no UUIDs).
- [x] 4.9d **DONE 2026-04-19** (unit test): malformed-entry defence. Raw non-envelope string payload + envelope with wrong inner type both throw `MALFORMED_CACHE_ENTRY`; counter increments.
- [x] 4.9e **DONE 2026-04-19** (unit test): `invalidateTenant` idempotency. Two calls in sequence; first emits audit with totalEvicted=1, second with totalEvicted=0; neither throws.
- [x] 4.9f **DONE 2026-04-19** (unit test): post-restart empty-registry safety. Fresh wrapper + `invalidateTenant` on never-written tenant iterates all 11 seeded cache names, emits audit with totalEvicted=0, no NPE.
- [x] 4.9g **DONE 2026-04-19** (integration test): `TenantScopedCacheAuditRollbackIntegrationTest` green against Testcontainers Postgres with Phase B V69 FORCE RLS active. Trigger cross-tenant read inside `TransactionTemplate.executeWithoutResult`; caller's `@Transactional` block rolls back on the ISE; `DetachedAuditPersister` (REQUIRES_NEW) audit row remains committed after rollback (verified via `countCrossTenantAuditsAsTenant(TENANT_B)` wrapping the count in `TenantContext.callWithContext(TENANT_B, ...)` since FORCE RLS filters unbound-context reads). Commit `173138d`. Locally green; also passed in PR #135 CI merge verification.
- [x] 4.9h **DONE 2026-04-19** (unit test): `put(cacheName, key, null, ttl)` throws `IllegalArgumentException` immediately; no cache write occurs.
- [x] 4.4 **DONE 2026-04-19** (merged as PR #136 commit `5fe3041`). [LATENT C3] `EscalationPolicyService` cache surface split into two fields: `policyById` (UUID key, `@TenantUnscopedCache("batch job cross-tenant snapshot resolution")`, only called from `findByIdForBatch`) and new `policyByTenantAndId` (composite `PolicyKey(tenantId, policyId)` record, request-path only). Cross-tenant reach on `findByTenantAndId` emits `CROSS_TENANT_POLICY_READ` audit via `DetachedAuditPersister` REQUIRES_NEW + `Optional.empty()` D3 posture. Companion `EscalationPolicyBatchOnlyArchitectureTest` enforces that `findByIdForBatch` may only be called from `org.fabt.referral.batch..` (package-based approximation of `@Scheduled`-caller intent; ArchUnit can't walk the Spring Batch Job → Step → @Scheduled chain). `TenantGuardArchitectureTest.SAFE_SITES` gained `findByTenantAndId` with justification documenting the on-read verification + platform-default-NULL-tenant access pattern.
- [x] 4.2 **DONE 2026-04-19** (merged as PR #137 commit `2f4a8e2`). ArchUnit Family C rule C1: `FamilyCArchitectureTest.c1_cacheServiceCallSitesMustBeTenantScopedOrAnnotated` — direct `CacheService.get` / `put` / `evictAllByPrefix` and `TieredCacheService.get` / `put` call sites in `*.service`, `*.api`, `*.security`, `*.auth.*` require `@TenantUnscopedCache("<non-empty>")` OR `@TenantScopedByConstruction("<non-empty>")` annotation (either on the caller method OR structural-container-class annotation). Rule C2: `c2_springCacheAnnotationsBlockedOutright` — blocks Spring `@Cacheable` / `@CacheEvict` / `@CachePut` at the method level in all application classes (zero usage today). `PENDING_MIGRATION_SITES` fully-qualified allowlist (9 methods, Marcus hardening) carries the 4.b call sites pending migration.
- [x] 4.3 **DONE 2026-04-19** (merged as PR #137 commit `2f4a8e2`). Rule C3: `c3_caffeineFieldsMustBeAnnotatedOrRouteThroughWrapper` — extends Family C to all `Caffeine.newBuilder()` fields in `*.service`, `*.api`, `*.security`, `*.auth.*`. Landing inventory: **11 application-layer Caffeine fields** annotated (`@TenantUnscopedCache` × 10 + `@TenantScopedByConstruction` × 1): `JwtService.claimsCache`, `EscalationPolicyService.{policyById, currentPolicyByTenant, policyByTenantAndId}` (last field `@TenantScopedByConstruction`), `ApiKeyAuthenticationFilter.rateLimitBuckets`, `AuthController.{mfaAttempts, mfaBlocklist}`, `DynamicClientRegistrationSource.cache`, `KidRegistryService.{tenantToActiveKidCache, kidToResolutionCache}`, `RevokedKidCache.cache`. Six negative-test fixtures (`UnannotatedCaffeineFixture`, `SpringCacheableFixture`, `EmptyJustificationFixture`, `NullPutFixture`, `OptionalEmptyPutFixture`, `AnnotatedWithJustificationFixture`) assert positive + negative behaviour per Riley.
- [x] 4.5 **DONE 2026-04-19** (merged as PR #137 commit `2f4a8e2`). `.github/CODEOWNERS` gains `TenantUnscopedCache.java`, `TenantScopedByConstruction.java`, `FamilyCArchitectureTest.java` → `@ccradle`. `.github/PULL_REQUEST_TEMPLATE.md` shipped with security-gate checkboxes (paraphrased to avoid legal-scan self-trigger per `feedback_legal_scan_in_comments.md`). `.github/workflows/ci.yml` gains `family-c-annotation-review-gate` job with `git rev-parse --verify` hardening (Jordan SRE).
- [x] 4.6 **DONE 2026-04-19 night** (PR #140). Shipped as `CacheIsolationDiscoveryTest` per plan warroom pick — name-adjusted from `ReflectionDrivenCacheBleedTest` because the honest discovery mechanism is ArchUnit + `java.lang.reflect` (Java's reflection API doesn't do bytecode call-site graphs; `org.reflections` doesn't either; ArchUnit's `JavaMethodCall` primitives do). `CacheNames.class.getFields()` covers the cache-name inventory; ArchUnit covers the positive-discovery mirror of Rule C2 (zero `@Cacheable` methods). Three guard tests (discovery floor=8, expected-count pin=11 exact, zero `@Cacheable` with import-floor check on 50+ classes) + 11 parametrized rows (one per `CacheNames` constant) running the legitimate-isolation triple `tenantA.put → tenantA.get HIT → tenantB.get MISS`. Post-commit Riley fold-in tightened `discoveryMatchesExpectedMinimum` from `>=` to `.hasSize(11)` exact-equals so additions fire the per-cache-test-update reminder the class Javadoc promised. 14/14 green, 949/949 full-suite green post-addition.
- [x] 4.7 **DONE 2026-04-19** (merged as PR #138 commit TBD). Negative-cache guardrail (C6) shipped as **source-scan Java @Test** (not ArchUnit) because ArchUnit inspects call-site types, not runtime argument values — literal `null` or `Optional.empty()` as a `.put(...)` argument is source-text pattern-matching, not static class-graph reasoning. `NegativeCacheGuardrailTest.noNullOrEmptyOptionalAsCacheValue` regex-scans `backend/src/main/java/org/fabt/` for `.put(something, something, null, ...)` and `.put(something, something, Optional.empty(), ...)`, excluding `TenantScopedCacheService.java` (Javadoc cross-references the rule) + the test file itself by filename. Files-scanned floor of 50 guards against misconfigured cwd (silent-empty-guard per `feedback_never_skip_silently.md`). Companion `putNegative(cacheName, key, ttl)` shipped in `TenantScopedCacheService` with `NEGATIVE_SENTINEL` anonymous `Object` singleton (enum promotion deferred to task #184). Two fixture classes (`NullPutFixture`, `OptionalEmptyPutFixture`) let the scan fire positively against an intentional-violation tree without polluting production source.
- [x] 4.a **DONE 2026-04-19** (shipped with 4.1 commit `c4e9541`, polished in `173138d`): counters cached per `(cache, tenant, result)` in `ConcurrentHashMap<GetCounterKey, Counter>` / `ConcurrentHashMap<PutCounterKey, Counter>` so hot-path calls skip the `MeterRegistry` tag-map walk (Sam's code-review concern). Also wires `fabt.cache.registered_cache_names` gauge — value 11.0 verified live on findabed.org v0.46.0 post-deploy. Result tag values include `cross_tenant_reject` + `malformed_entry` in addition to `hit|miss` — 4-wide cardinality vs. the original 2-wide in the task description. Updated cardinality math: ~8800 series at 100 tenants × 11 caches × 4 results × 2 ops, still within Prometheus budget.
- [x] 4.b **DONE 2026-04-19 (PR #139 merged commit `f74762d`)** [LOAD-BEARING C1 allowlist drain] 9 `PENDING_MIGRATION_SITES` call sites migrated from raw `CacheService.get/put/evictAllByPrefix` to `TenantScopedCacheService.get/put`. All 6 ship-list items delivered. 4 pre-release warroom fold-ins applied in PR #139 legal-scan commit `76db543`. Further pre-release deep-warroom fold-ins shipped in v0.47.0 release-prep (see 4.10).
   - [x] 4.b.1 9 sites migrated in single PR. Composite-key callers strip caller-side tenant prefix; 5 sites (createSnapshot, evictTenantShelterCaches, getDvSummary, getGeographic, getHmisHealth) use `"latest"` constant per D-4.b-2 (extended mid-implementation to cover 3 Analytics tenant-singleton sites; post-warroom ratification in design-c.md). `PENDING_MIGRATION_SITES` drained to `Set.of()`. `invalidateTenant` refactor rejected per D-4.b-3 (kept 2 explicit ShelterService evicts + 3 orphan-cache evicts with inline comment markers).
   - [x] 4.b.2 `docs/performance/probe-bedsearch-4b.sql` shipped (Sam slice-2 warroom fold-in; reframed post-commit from A/B/C wrapper comparison to DB-floor measurement because the DO-block bypasses Spring — scenarios collapsed to identical paths). Operator-runnable harness for future SQL-shape changes + post-v0.47 baseline capture (scheduled in oracle-update-notes-v0.47.0.md step 5 "After deploy succeeds").
   - [x] 4.b.3 `Tenant4bMigrationCrossTenantAttackTest` — 8 parametrized rows, one per cache name. Stages poisoned envelope via raw CacheService; asserts `IllegalStateException("CROSS_TENANT_CACHE_READ")` + `audit_events` row via REQUIRES_NEW. 8/8 green.
   - [x] 4.b.4 `Task4bCacheHitRateTest` — 7 rows (6 Analytics + 1 BedSearch, slice-2 fold-in). Post-commit Riley warroom tightened delta assertions from `>=` to `.isEqualTo(1)` so JVM-global counter bleed can't mask key drift. 7/7 green.
   - [x] 4.b.5 `deploy/prometheus/phase-c-cache-isolation.rules.yml` — 4 rules (not 3 as originally scoped): CRITICAL cross-tenant-reject + WARN malformed-entry + WARN hit-rate-drop + WARN detached-audit-persist-failure (added per Marcus post-commit fold-in). All 4 filter on `env="prod"` (Jordan fold-in) so CI / dev scrapes cannot false-page.
   - [x] 4.b.6 CHANGELOG.md [v0.47.0] entry authored (legal-scan clean phrasing). Companion `docs/security/phase-c-cache-isolation-runbook.md` alert-triage runbook (240 lines, one section per alert) + `docs/oracle-update-notes-v0.47.0.md` deploy runbook (pre-deploy + deploy + post-deploy 9 gates + 2h active watch + rollback).
- [x] 4.10 **DONE 2026-04-19 night** — Phase C closed. PRs merged:
   - PR #127 (Phase 0 latent OAuth2/HMIS encryption)
   - PR #131 (Phase B RLS + pgaudit + PgVersionGate)
   - PR #135 (Phase C task 4.1 wrapper)
   - PR #136 (Phase C task 4.4 EscalationPolicyService split)
   - PR #137 (Phase C tasks 4.2 + 4.3 + 4.5 Family C rules)
   - PR #138 (Phase C task 4.7 negative-cache guardrail)
   - PR #139 (Phase C task 4.b drain PENDING_MIGRATION_SITES)
   - PR #140 (Phase C task 4.6 CacheIsolationDiscoveryTest + pre-release warroom fold-ins)
   - v0.47.0 release-prep commit (pom bump + CHANGELOG + oracle-update-notes + deep-warroom fold-ins on docker-compose.yml, prometheus.yml, prometheus.dev.yml, docker-compose.dev-observability.yml, FOR-DEVELOPERS.md — Prometheus now actually loads Phase B + Phase C rules via new `--web.enable-lifecycle` + rules volume + `rule_files:` glob; retroactively wires 5 Phase B rules that had been on disk since v0.43.1 but never read).
   **Phase C follow-ups (non-blocking for v0.47.0):** #155 Alertmanager routing, #180 EscalationPolicyAuditRollbackIT, #182 Rule C4 ConcurrentHashMap heuristic, #184 NEGATIVE_SENTINEL enum promotion, #163 pgaudit include_dir fix. All tracked in the task-list; can land as follow-up PRs without blocking the v0.47.0 tag.

## 5. Phase D — Control-plane hardening (1 week)

- [x] 5.1 Audit every controller with path parameters — create inventory of write-path controllers with `{tenantId}` or resource ID (D1)
- [x] 5.2 Apply D11 URL-path-sink pattern to `TenantController PUT /{id}/*` (3 PUTs + 1 GET symmetric): new `TenantPathGuard.requireMatchingTenant` helper + inline calls; source tenantId from TenantContext; ignore path-tenantId
- [x] 5.3 Apply D11 to `TenantConfigController` GET + PUT — both endpoints now guarded
- [x] 5.4 Apply D11 to `OAuth2ProviderController` list/create/update/delete — POST already had inline D11 (pre-existing); refactored to the shared helper for consistency with the other 3 methods
- [ ] 5.5 Validate `TenantConfigController` inputs against typed schema (L5 dependency — once typed config lands, tighten here) — **deferred to Phase L**
- [x] 5.6 Update `infra/docker/nginx.conf` — strip `X-FABT-Tenant-Id`, `X-Scope-OrgID`, `X-Tenant-Id` in all 4 proxy locations (SSE, version, api/, actuator/). Note: `$fabt_tenant_from_jwt` variable not implementable on plain nginx:alpine (no Lua/JWT module) — stripping client-supplied headers is the correct defence-in-depth posture. PR #148.
- [x] 5.7 Add nginx-integration test `nginx-tenant-header-stripping.spec.ts` — 7 tests: public endpoint with all 3 forged headers, each header individually on authed endpoint, all 3 simultaneously + body length equality, case-insensitive variant, SSE stream initiation. Auto-skips in CI via `requireReachable`. PR #148.
- [x] 5.8 Document `docs/security/ingress-tenant-binding.md` — architecture flow diagram, why nginx can't extract JWT (plain nginx:alpine), Phase D posture table (4 controls), mTLS upgrade path deferred to Phase F. PR #148.
- [x] 5.9 Integration test: `TenantPathGuardIntegrationTest` — 10 cross-tenant-404 cases + 1 same-tenant-200 control, all green. Covers PUT /tenants/{B}/config, GET /tenants/{B}/config, PUT /tenants/{B} display-name, PUT /tenants/{B}/observability, GET /tenants/{B}/observability, GET /tenants/{B}/oauth2-providers, POST /tenants/{B}/oauth2-providers, PUT /tenants/{B}/dv-address-policy, PUT /tenants/{A}/oauth2-providers/{B-provider} (nested-resource attack), DELETE /tenants/{A}/oauth2-providers/{B-provider} (nested-resource attack). Warroom fold-in 2026-04-20 added the nested-resource tests to verify the service-layer `findByIdAndTenantId` defence-in-depth claim, not just assert it in a code comment.
- [x] 5.10 Commit Phase D + open PR — PR #148 opened 2026-04-22; nginx stripping + Playwright suite + security doc. Merges independently (not bundled with V76/V77).

## 6. Phase E — Per-tenant operational boundaries (2 weeks)

- [ ] 6.1 Flyway V62 — create `tenant_rate_limit_config(tenant_id, endpoint_class, limit, window_seconds, statement_timeout_ms, work_mem, updated_at)` typed table with unique `(tenant_id, endpoint_class)`
- [ ] 6.2 Seed default rate-limit config for `dev-coc` + migrate existing bucket4j defaults to the table
- [ ] 6.3 Implement `TenantRateLimitConfigService` — reads per-tenant overrides; falls back to platform defaults; fail-safe never fail-open on config load failure
- [ ] 6.4 Refactor `ApiKeyAuthenticationFilter` bucket key from `clientIp` to `(SHA-256(api_key_header)[:16], ip)` for unauthenticated path (E1, D5)
- [ ] 6.5 Refactor post-auth rate-limit paths to `(tenant_id, ip)` composite (E1, D5)
- [ ] 6.6 Refactor bucket4j declarative rules in `application.yml` to call `TenantRateLimitConfigService.forTenant(tenantId).limit(endpointClass)` — per-tenant limits
- [ ] 6.7 Audit every background-worker dispatch path: `HmisPushService`, `WebhookDeliveryService`, `EmailService`, notification workers — identify FIFO-over-tenants pattern
- [ ] 6.8 Implement per-tenant fair-queue dispatcher: inner per-tenant queues + round-robin dispatch across tenants (E6)
- [ ] 6.9 Refactor `NotificationService.eventBuffer` from `ConcurrentLinkedDeque` to `Map<UUID, ConcurrentLinkedDeque>` with per-tenant cap (E4)
- [ ] 6.10 Refactor SSE delivery loop to round-robin over tenant queues (E5)
- [ ] 6.11 Add per-tenant SSE emitter limit on `NotificationService.emitters` map — reject new emitter if tenant's count exceeds limit; 503 with Retry-After
- [ ] 6.12 ArchUnit Family E: no `synchronized` blocks in methods dispatched on virtual threads in tenant-scoped paths (E7); `ReentrantLock` required
- [ ] 6.13 Add per-tenant metrics to scheduled tasks: `fabt.scheduled.<task>.invocations{tenant_id}`, `.duration{tenant_id}` for `ReservationExpiryService`, `ReferralTokenPurgeService`, `AccessCodeCleanupScheduler`, `HmisPushScheduler`, `SurgeExpiryService` (E8)
- [ ] 6.14 Integration test: cross-tenant rate-limit isolation — hammer Tenant A at login limit; assert Tenant B unaffected
- [ ] 6.15 Integration test: SSE buffer fairness — Tenant A publishes 200 events; assert Tenant B's 1 buffered event not evicted (per-tenant shard)
- [ ] 6.16 Gatling smoke: NoisyNeighborSimulation (J18) skeleton — two tenants, Tenant A at 3× load
- [ ] 6.17 Commit Phase E + open PR

## 7. Phase F — Tenant lifecycle FSM (2 weeks)

- [ ] 7.1 Flyway V60 continuation — add `TenantState` enum + constraint to existing `tenant.state` column: `ACTIVE | SUSPENDED | OFFBOARDING | ARCHIVED | DELETED`
- [ ] 7.2 Create `TenantLifecycleService` — owns state transitions + enforces FSM (D8); all transitions produce audit events
- [ ] 7.3 Implement `TenantLifecycleService.create(name, slug, residency)` — atomic: insert row, derive JWT key (A1), derive DEKs (A3), apply default typed config (L5), bootstrap audit, verify RLS predicates
- [ ] 7.4 Implement `TenantLifecycleService.suspend(tenantId, reason)` — atomic 5-action quarantine (F4): bump jwt_key_generation (A2), disable API keys, stop worker dispatch, set state=SUSPENDED, continue audit
- [ ] 7.5 Implement `TenantLifecycleService.unsuspend(tenantId)`
- [ ] 7.6 Implement `TenantLifecycleService.offboard(tenantId)` + export workflow: generate schema'd JSON export of all data classes; 30-day delivery per GDPR Article 20 (F5)
- [ ] 7.7 Implement `TenantLifecycleService.archive(tenantId)` — called post-export-complete; moves ARCHIVED → 30-day-retention window
- [ ] 7.8 Implement `TenantLifecycleService.hardDelete(tenantId)` — crypto-shred per D11: delete `tenant_key_material`, delete `tenant_audit_chain_head`, cascade DELETE tenant + FK cascades, audit `TENANT_HARD_DELETED`
- [ ] 7.9 Refactor every tenant-owned repository: add `findByIdAndActiveTenantId(id)` that filters `state IN ('ACTIVE')` — used at service-layer boundary
- [ ] 7.10 Keep `findByIdAndTenantId(id, tenantId)` for internal use; ArchUnit rule: public controllers may only call `findByIdAndActiveTenantId`
- [ ] 7.11 Update `GlobalExceptionHandler` — SUSPENDED tenant returns 503 with Retry-After for writes; reads return 404 for non-active (D3 consistency)
- [ ] 7.12 Add `TenantLifecycleController` — admin break-glass endpoints for suspend/unsuspend/offboard/hardDelete (platform-admin only)
- [ ] 7.13 Write state-machine test asserting allowed + disallowed transitions (D8)
- [ ] 7.14 Integration test: full lifecycle — create Tenant X → ACTIVE → SUSPENDED → JWTs rejected, writes 503 → unsuspend → writes succeed → offboard → export verified → archive → 30-day → hardDelete → crypto-shred verified (ciphertext undecryptable)
- [ ] 7.15 Integration test: offboard export includes shelters, beds, users, referrals, audit events, HMIS history, config — assert schema contract stable
- [ ] 7.16 Create `docs/legal/right-to-be-forgotten.md` (H9) — documented DELETE order + FK cascade verification
- [ ] 7.17 Commit Phase F + open PR

## 8. Phase G — Audit + observability isolation (1 week)

### 8.0 Phase G preflight — `AuditEventType` enum migration (closes [#98](https://github.com/ccradle/finding-a-bed-tonight/issues/98))

Lands BEFORE any chain-hashing work (8.1+) so the serialized form of `audit_events.action` is locked up-front — once the first `row_hash` row is written, the field's on-wire shape becomes permanent hash input. Research settled in Slice F-1 (V79 `tenant_state` conversion): **Spring Data JDBC 4.x bypasses user converters for enums** (spring-data-relational #1689/#1697/#1705/#1935/#2083), so the pattern is Java enum + VARCHAR column + default `.name()` serialization. No CHECK constraint on `audit_events.action` (append-only column, types grow organically as phases add new events — CHECK would force a Flyway migration per new event type).

- [ ] 8.0.1 Create `org.fabt.shared.audit.AuditEventType` enum with one case per `AuditEventTypes.*` constant (current inventory ~23 — read `AuditEventTypes.java` at migration time for authoritative list; includes lifecycle, rejection, cache-isolation, shelter, DV-referral, and BED_HOLDS_RECONCILED families)
- [ ] 8.0.2 Update `AuditEventRecord` — change `String action` → `AuditEventType action`
- [ ] 8.0.3 Update `AuditEventService.publish(...)` signature + all internal uses to take `AuditEventType`
- [ ] 8.0.4 Update `DetachedAuditPersister.persistDetached(UUID, AuditEventRecord)` callers — Phase C's `TenantScopedCacheService.get` cross-tenant-read path + `EscalationPolicyService.findByTenantAndId` cross-tenant-read path (both already pass `AuditEventTypes.*` constants — just need the signature ripple)
- [ ] 8.0.5 Update `AuditEventEntity` to serialize enum → String at persistence boundary via `.name()`; column type stays VARCHAR; zero schema change
- [ ] 8.0.6 Refactor bare-string literal call sites to enum cases — `ShelterService.java:293` (`SHELTER_DV_FLAG_CHANGED`), `ShelterService.java:302` (`DV_SHELTER_ADDRESS_CHANGED`), `AccessCodeService.java:79` (`ACCESS_CODE_GENERATED`)
- [ ] 8.0.7 Refactor threaded `String action` parameters in `UserService.applyAuditEvent`, `ReferralTokenService.publishAuditEvent`, `ReferralTokenController` audit path, `TenantLifecycleService.logRejection` — all take `AuditEventType` from typed callers
- [ ] 8.0.8 Migrate `AuditEventTypesTest` — each test replaced with `assertThat(AuditEventType.X.name()).isEqualTo("X")` form; contract pin preserved because the DB string representation is unchanged
- [ ] 8.0.9 Delete `AuditEventTypes.java` constants class — fully superseded by the enum
- [ ] 8.0.10 Integration test: round-trip `publish(AuditEventType.TENANT_CREATED)` → DB row has `action='TENANT_CREATED'` — proves `.name()` wire form is stable and pre-existing rows from before the migration still query correctly
- [ ] 8.0.11 Integration test: JSONB details payload + enum action serialize deterministically — this row is what Phase G's `canonical_json(row)` hash input will see
- [ ] 8.0.12 Update `docs/FOR-DEVELOPERS.md` "Publishing audit events" section with the new enum pattern
- [ ] 8.0.13 Full backend regression (`mvn verify`) — ~619 tests; catches any missed call sites
- [ ] 8.0.14 Commit 8.0 + open PR targeting Phase G branch (NOT main directly — lands in the Phase G PR chain)

### 8.0 — warroom-deferred follow-ups (apply during 8.1 work)

- [ ] 8.0.15 ArchUnit rule (Family G-0): production packages `org.fabt.*.service|.*.api|.*.batch|.*.security|.*.web` may not reference `AuditEventType.TEST_PROBE`. Riley's warroom concern: the sentinel is necessary in tests but a developer could paste it into a production path and ship. Rule pattern precedent: `FamilyCArchitectureTest`.
- [ ] 8.0.16 Consider `@NotNull` or compact-constructor assertion on `AuditEventRecord.action` — Casey's chain-of-custody concern: `new AuditEventRecord(null, null, null, null, null)` currently writes `action=NULL` to `audit_events`, which will get hashed by G-1 as `"action": null` in canonical_json. Forensically meaningless audit row. Decide: disallow null action OR document the null-action semantic intentionally.

- [ ] 8.1 Flyway V66 — add `prev_hash BYTEA`, `row_hash BYTEA` columns to `audit_events`
- [ ] 8.2 Flyway V65 — create `platform_admin_access_log(id, admin_user_id, tenant_id, resource, resource_id, justification, timestamp)` table
- [ ] 8.3 Create `tenant_audit_chain_head(tenant_id UUID PRIMARY KEY, last_hash BYTEA NOT NULL, last_row_id UUID NOT NULL, updated_at TIMESTAMPTZ NOT NULL)` table
- [ ] 8.4 Implement `AuditChainHasher` — on INSERT to audit_events, compute `SHA256(prev_tenant_hash || canonical_json(row))` via service-layer; update `tenant_audit_chain_head`
- [ ] 8.5 Implement `AuditChainExternalAnchor` — scheduled weekly task writes `(tenant_id, last_hash, timestamp)` to S3 Object Lock OR OCI Object Storage WORM OR append-only disk (decide per open question Q5)
- [ ] 8.6 Implement `AuditChainVerifier` — daily scheduled integrity check; re-computes chain; fails if drift; emits alert
- [ ] 8.7 Add `@PlatformAdminOnly` annotation + `PlatformAdminAccessAspect` — intercepts method invocations; writes `platform_admin_access_log` row with justification from annotation parameter
- [ ] 8.8 Annotate all platform-admin-only service methods with `@PlatformAdminOnly("reason")`
- [ ] 8.9 Add OTel baggage propagation of `fabt.tenant.id` on every server/client span — `BaggagePropagator` setup in `application.yml` OTel config
- [ ] 8.10 Add resource attribute `fabt.tenant.id` on trace exports (G4)
- [ ] 8.11 Update Grafana Alertmanager config — alerts include `tenant_id` label; route to `tenant.oncall_email` contact
- [ ] 8.12 Add `tenant.oncall_email` column to tenant (covered by V60 in task 2.1 — verify here)
- [ ] 8.13 Document `docs/observability/cardinality-budget.md` (G6) — per-metric per-tenant cardinality analysis; drop tenant tag from metrics exceeding budget
- [ ] 8.14 Document `docs/observability/log-retention-per-tenant.md` (G7) — HIPAA 6yr, VAWA per OVW, standard 1yr
- [ ] 8.15 Integration test: tampered audit_events row — manual UPDATE bypassing REVOKE (requires superuser); assert daily verifier detects drift
- [ ] 8.16 Integration test: `@PlatformAdminOnly` invocation writes platform_admin_access_log row with correct fields
- [ ] 8.17 Integration test: OTel baggage preserved across service-to-service call chain; tenant_id correct at sink
- [ ] 8.18 Commit Phase G + open PR

## 9. Phase H — Compliance documentation (2 weeks)

- [ ] 9.1 Casey review loop kickoff — schedule 1h review session; share proposal + design with Casey lens
- [ ] 9.2 Author `docs/architecture/tenancy-model.md` (H1) — drafted in 1.2; Casey review + sign-off
- [ ] 9.3 Author `docs/legal/baa-template.md` (H2) — HIPAA BAA template with data-flow diagram + encryption attestations + breach-notification SLA
- [ ] 9.4 Author `docs/legal/per-tenant-baa-registry.md` (H2) — empty registry; fills as pilots sign
- [ ] 9.5 Author `docs/security/vawa-breach-runbook.md` (H3) — detection path + OVW notification template + escalation tree
- [ ] 9.6 Author `docs/architecture/vawa-comparable-database.md` (H4) — encryption posture that prevents platform operators from reading DV PII without audited unseal
- [ ] 9.7 Author `docs/legal/dv-safe-breach-notification.md` (H5) — survivor-declared safe channel; escalation when unavailable
- [ ] 9.8 Flyway V64 — create `breach_notification_contacts(tenant_id, role, email, phone, sla_hours)` table (H6)
- [ ] 9.9 Author `docs/legal/data-custody-matrix.md` (H7) — matrix per data class × {custodian, breach-recipient, retention, deletion-trigger, export-format, residency-pin}
- [ ] 9.10 Author `docs/legal/contract-clauses.md` (H8) — per-tenant MSA/SLA addendum library
- [ ] 9.11 Author `docs/legal/children-data.md` (H10) — FERPA carve-out acknowledgment
- [ ] 9.12 Extend legal-scan CI check (`feedback_legal_scan_in_comments.md`) — grep added Javadoc/comments for "compliant", "equivalent", "guarantees" (H11)
- [ ] 9.13 Tabletop exercise: simulate DV-tenant breach; time notification from detection to OVW submission; validate 24h target achievable
- [ ] 9.14 Casey final review + sign-off on H1–H11
- [ ] 9.15 Commit Phase H + open PR

## 10. Phase I — Defense-in-depth (1 week)

- [ ] 10.1 Already drafted in 1.3 — finalize `docs/security/timing-attack-acceptance.md` (I1)
- [ ] 10.2 Implement inbound webhook signing verification (I2) — HMAC-SHA256 using per-tenant DEK (context `"inbound-webhook"`); `WebhookInboundSignatureVerifier` checks `X-FABT-Signature` header; rejects missing/mismatch with 401
- [ ] 10.3 Add `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` to `/actuator/prometheus` endpoint (I3); document in `feedback_actuator_security.md` update
- [ ] 10.4 Add `referral_token.originating_session_id` column + validation on accept/reject: session match OR 2FA re-step (I4)
- [ ] 10.5 Implement `EgressAllowlistService` — per-tenant allowlist for webhook/OAuth2/HMIS destination domains; sources from `tenant.egress_allowlist` typed config (L5); 403 with educational message on block
- [ ] 10.6 Wire `EgressAllowlistService` into `WebhookDeliveryService.send`, `OAuth2AccountLinkService.dial`, `HmisPushService.deliver` — regulated-tier-only enforcement (check tenant tier flag); standard tier bypasses
- [ ] 10.7 Modify `WebhookDeliveryService.send` retry loop — call `SafeOutboundUrlValidator.validateForDial` on EVERY attempt, not just first (I6)
- [ ] 10.8 Integration test: inbound webhook with wrong signature → 401
- [ ] 10.9 Integration test: inbound webhook with Tenant A signature against Tenant B endpoint → 401
- [ ] 10.10 Integration test: `/actuator/prometheus` with COC_ADMIN credentials → 403
- [ ] 10.11 Integration test: referral_token accept from different session → 2FA re-step OR 403
- [ ] 10.12 Integration test: webhook callback URL changed to private IP post-creation → delivery-time validator rejects on retry
- [ ] 10.13 Commit Phase I + open PR

## 11. Phase J — Testing + validation (2 weeks — interleaved with prior phases; this phase consolidates)

- [ ] 11.1 Create `docs/security/test-coverage-matrix.md` (J1) — maps each A1–M11 sub-item to test file + layer
- [ ] 11.2 Implement `ReflectionDrivenCacheBleedTest` (J2; started in 4.6) — extend to ALL Caffeine caches + TieredCacheService sites
- [ ] 11.3 Implement `SseReplayCrossTenantTest` (J3) — 2-tenant disconnect/reconnect; each tenant's replay contains zero cross-tenant events
- [ ] 11.4 Implement `JwtKeyRotationTest` (J4) — sign under gen 1, bump to 2, verify old rejected/new accepted/cross-tenant confusion rejected
- [ ] 11.5 Extend `TenantPredicateCoverageTest` to cover every write-path controller with path variables (J5)
- [ ] 11.6 Implement `TenantLifecycleTest` (J6) — full create → suspend → offboard → archive → delete → crypto-shred flow
- [ ] 11.7 Implement `BreachSimulationTest` (J7) — 15+ attack vectors against Tenant A's DV referral from Tenant B; all fail
- [ ] 11.8 Implement Playwright cross-tenant cache-bleed test (J8) — login A, logout, login B; assert A's DOM/SW/IDB not visible
- [ ] 11.9 Implement hospital-PWA tenant-isolation test (J9) — locked-down Chrome config, SW blocked; multi-tenant still works
- [ ] 11.10 Implement offline-hold + tenant-switch test (J10) — queued hold doesn't cross tenants
- [ ] 11.11 Extend DV canary (J11) — multi-tenant variant: Tenant A DV shelter invisible to Tenant B no-dvAccess user in every surface
- [ ] 11.12 Implement scale test (J12) — 20 tenants × 50 concurrent requests; zero cross-tenant leak + per-tenant SLO met
- [ ] 11.13 Implement file-path tenant-isolation harness (J13) — regression guard for future file-write paths
- [ ] 11.14 Implement Flyway migration rollback test (J14) — drop + re-add each D14 policy
- [ ] 11.15 ArchUnit rule negative tests for Family C/D/E/F (J15) — intentional violations fire expected rules
- [ ] 11.16 PR review checklist updated with "person in crisis" comment rule (J16) — every new tenant-isolation test includes the comment
- [ ] 11.17 Add CI guard: fail if any test runs as DB owner `fabt` (J17; relates to B13)
- [ ] 11.18 Implement `NoisyNeighborSimulation` Gatling (J18; extended from 6.16) — quantified per-tenant p95 SLO
- [ ] 11.19 Implement multi-tenant chaos scenario (J19) — one tenant hostile load; assert other tenant SLO preserved
- [ ] 11.20 Pre-production pentest engagement (J20) — OWASP Cloud Tenant Isolation checklist; external vendor OR documented self-audit
- [ ] 11.21 Commit Phase J + open PR

## 12. Phase K — Breach response + incident response (1 week)

- [ ] 12.1 Implement `TenantQuarantineService.quarantine(tenantId, reason)` (K1) — atomic 5 actions: bump JWT generation (A2), disable API keys, block inbound webhooks, set state=SUSPENDED (writes 503, reads preserved), audit `TENANT_QUARANTINED`
- [ ] 12.2 Expose quarantine via `TenantLifecycleController` admin endpoint + CLI script in `infra/scripts/quarantine-tenant.sh`
- [ ] 12.3 Implement `ForensicQueryService` (K2) — pre-built queries: given user/token/IP/timestamp, list every row accessed
- [ ] 12.4 Grafana panel (extends `fabt-cross-tenant-security` dashboard) — forensic query tool front-end
- [ ] 12.5 Author `docs/security/ir-runbooks/01-suspected-cross-tenant-read.md` (K3a)
- [ ] 12.6 Author `docs/security/ir-runbooks/02-stolen-credential.md` (K3b)
- [ ] 12.7 Author `docs/security/ir-runbooks/03-vendor-compromise.md` (K3c)
- [ ] 12.8 Author `docs/security/ir-runbooks/04-dv-tenant-breach.md` (K3d) — VAWA pipeline entry point (H3)
- [ ] 12.9 Integration test: quarantine atomic — assert all 5 actions visible + audit row present
- [ ] 12.10 Integration test: quarantine reversible — unsuspend restores full access
- [ ] 12.11 Commit Phase K + open PR

## 13. Phase L — Developer guardrails (1-2 weeks; SPI rolled out incrementally across prior phases)

- [ ] 13.1 Define `TenantScoped<T>` interface in `org.fabt.shared.tenant` (L1)
- [ ] 13.2 Implementations added progressively in prior phases — consolidate audit here: `TenantScoped<SigningKey>` (A), `TenantScoped<SecretKey>` DEK (A), `TenantScoped<Cache>` (C), `TenantScoped<Bucket>` rate-limit (E), `TenantScoped<Duration>` statement_timeout (B), `TenantScoped<Tags>` metrics (G)
- [ ] 13.3 ArchUnit Family F rule (L2) — no module reads `tenant` table directly; must go through `TenantService` / `TenantLifecycleService`
- [ ] 13.4 Migration review gate (L3) — ArchUnit-for-SQL: Flyway migrations must include `@tenant-safe` or `@tenant-destructive: <justification>` comment header; CI rejects
- [ ] 13.5 Flyway V63 — create `tenant_feature_flag(tenant_id, flag_name, enabled, updated_at)` typed table replacing JSON (L4)
- [ ] 13.6 Implement `FeatureFlagService.isEnabled(tenantId, flag)` with Caffeine cache (tenant-scoped per C1)
- [ ] 13.7 Refactor `tenant.config` JSONB to typed sub-tables OR typed columns (L5) — `tenant_rate_limit_config` (E2) is one; add columns for `default_locale`, `api_key_auth_enabled`, `oncall_email`, `data_residency_region` to `tenant` directly; keep `config` JSONB for operator-experimental flags
- [ ] 13.8 Per-tenant canary deploy (L6) — feature-flag-gated code paths; admin UI to toggle per-tenant
- [ ] 13.9 Provision stage environment with 3 synthetic tenants (L7) — `stage.findabed.org`; mirrors prod infrastructure
- [ ] 13.10 Document `docs/operational/dr-drill.md` (L8) — per-tenant DR drill playbook, quarterly cadence; verification checklist
- [ ] 13.11 Implement cost-allocation reporter (L9) — per-tenant DB storage (from partition sizes per B8), per-tenant CPU (via OTel baggage G4), per-tenant bytes (webhook delivery). Quarterly report.
- [ ] 13.12 Author `docs/operational/rotation-runbooks.md` (L10) — consolidates per-tenant DEK, per-tenant JWT, master KEK rotation
- [ ] 13.13 Integration test: `TenantScoped<SigningKey>.forTenant(A)` returns different key than `forTenant(B)`
- [ ] 13.14 Integration test: typed feature flag toggles per tenant independently
- [ ] 13.15 Commit Phase L + open PR

## 14. Phase M — Demo-site multi-tenant validation (1 week; change-closure gate)

- [ ] 14.1 Casey pre-merge review — confirm `Blue Ridge CoC (demo)` + `Pamlico Sound CoC (demo)` branding in all surfaces, no real-PII patterns, no partnership implication for either tenant, no name collision with HUD-registered CoCs (M2, M8)
- [ ] 14.2 Marcus pre-merge review — confirm both new-tenant seeds contain no real credentials, no real addresses, no real names (M8)
- [ ] 14.3 Maria pre-merge review — confirm procurement-audience-appropriate language in walkthrough covering all three tenants (M8)
- [x] 14.4 Flyway V76 — `dev-coc-west` tenant seed (Blue Ridge CoC (demo)) with UUID `a0000000-0000-0000-0000-000000000002` + tenant.config including `noaa_station_id: KAVL` (M1)
- [x] 14.5 V76 — 6 `dev-coc-west` users (admin, cocadmin, coordinator, outreach, dv-coordinator, dv-outreach — all password `admin123`)
- [x] 14.6 V76 — 3 `dev-coc-west` shelters: Example House North (Boone), Blue Ridge Example Shelter (Waynesville), Safe Haven Demo DV West (Undisclosed) — real cities, fictional streets per D12
- [x] 14.7 V76 — bed_availability for all 3 west shelters (5 rows, ~66% utilised). **Sample pending DV referral deferred** to a later pass — non-blocking for v0.48 demo-login flow; tracked as 14.7c below.
- [x] 14.8 V76 idempotency — `ON CONFLICT DO UPDATE` on tenant / user / shelter / shelter_constraints; `ON CONFLICT DO NOTHING` on bed_availability (no natural unique key)
- [x] 14.4b Flyway V77 — `dev-coc-east` tenant seed (Pamlico Sound CoC (demo)) with UUID `a0000000-0000-0000-0000-000000000003` + `noaa_station_id: KEWN`
- [x] 14.5b V77 — 6 `dev-coc-east` users (parallel to V76)
- [x] 14.6b V77 — 3 `dev-coc-east` shelters: Example Coastal House (New Bern), Pamlico Example Shelter (Washington NC), Safe Haven Demo DV East (Undisclosed)
- [x] 14.7b V77 — bed_availability for all 3 east shelters (4 rows). DV referral deferred per 14.7c.
- [x] 14.8b V77 idempotency — same pattern as V76
- [ ] 14.7c **Follow-up**: seed a sample pending DV referral in each new tenant so coordinator screening demo is non-empty end-to-end. Can land pre-v0.48 tag or in the Phase M proper bundle.
- [ ] 14.9 Frontend — update `Layout.tsx` header: visible tenant indicator with three distinct accent colors + tenant name (M3, three-tenant-aware)
- [ ] 14.10 Frontend — update `<title>` element to include tenant name per page
- [ ] 14.11 Frontend — login UI tenantSlug dropdown shows all three tenants with "(demo)" suffix on west + east
- [ ] 14.12 Backend — update `GlobalExceptionHandler` cross-tenant 404 envelope to include educational message when request pattern indicates cross-tenant attempt (M4); feature-flag-gated; symmetric across all three tenants
- [ ] 14.13 Extend `e2e/playwright/deploy/post-deploy-smoke.spec.ts` to cover ALL THREE tenants (M5) — login each, attempt cross-tenant URL against at least one other, assert educational 404; minimum 3-probe rotation (dev-coc → dev-coc-west, dev-coc-west → dev-coc-east, dev-coc-east → dev-coc)
- [ ] 14.14 Extend `e2e/karate/src/.../cross-tenant-isolation.feature` (post-deploy version) to iterate all three tenants
- [ ] 14.15 Author `docs/training/multi-tenant-demo-walkthrough.md` (M6) — 3-minute scripted walkthrough covering all three tenants
- [ ] 14.16 Capture screenshot bundle for walkthrough across all three tenants — folded into #120 pilot-readiness bundle
- [ ] 14.17 Link walkthrough from `findabed.org` landing page + FOR-COORDINATORS + FOR-COC-ADMINS audience docs
- [ ] 14.18 Grafana `fabt-cross-tenant-security` dashboard — add "Tenant-pair last validation timestamp" panel (M7) with green/yellow/red indicator
- [ ] 14.19 Implement NoisyNeighborSimulation "against-live-demo" variant (M9, extends 11.18) — operator selects `dev-coc-west` OR `dev-coc-east` as load target, monitors `dev-coc` + non-targeted new tenant p99
- [ ] 14.20 Quarterly tenant-quarantine live drill (M10) — quarantine `dev-coc-west` OR `dev-coc-east` (rotate per quarter), show targeted-tenant login fails + other two remain reachable, unsuspend; add to operational calendar
- [ ] 14.21 Quarterly offboard live drill (M11) — export data for targeted new tenant (west or east), hard-delete, re-seed via V76 or V77 respectively; verify crypto-shred and reseed succeed
- [ ] 14.22 **CHANGE-CLOSURE GATE**: Deploy to prod. Run post-deploy smoke all-tenant. Open public browser against findabed.org, attempt cross-tenant URLs in all three directions, verify educational 404. Screenshot evidence for each direction.
- [ ] 14.23 Commit Phase M + open PR — FINAL PR OF THE CHANGE (V76 + V77 may be separate PRs per M8, or a single combined PR; warroom decision at implementation time)

### Phase M fold-in — per-tenant-weather-station (Option A)

Observation during Phase M-light seed bring-up (2026-04-20): the NOAA weather station was a single global `@Value("${fabt.monitoring.noaa.station-id:KRDU}")` injected into `NoaaClient` + `OperationalMonitorService`, and the cached `TemperatureStatus` was a single non-tenant-scoped field. A Blue Ridge admin seeing "Raleigh-Durham temperature" is wrong for mountain geography and undermines the surge-gap signal. Option A (minimum-viable, in-scope here) adds per-tenant station lookup; Option B (typed column + admin UI) and Option C (per-shelter or multi-station) deferred to warroom research (14.w-longterm).

- [x] 14.w-1 `NoaaClient.getCurrentTemperatureFahrenheit(String stationId)` overload — accepts explicit station, falls back to injected default on null/blank; keep no-arg overload for callers wanting default.
- [x] 14.w-2 `ObservabilityConfigService.ObservabilityConfig` record — add nullable `String noaaStationId`; parse `noaa_station_id` from `tenant.config.observability` JSON; DEFAULTS pass `null`.
- [x] 14.w-3 `OperationalMonitorService.checkTemperatureSurgeGap` — fan out per tenant, resolve station per tenant config (fallback to global default), memoize per-station fetch within the cycle so shared stations don't fan-hit NOAA.
- [x] 14.w-4 `cachedTemperatureStatus` → `Map<UUID, TemperatureStatus> cachedTemperatureByTenant`; expose `getTemperatureStatus(UUID tenantId)`.
- [x] 14.w-5 `MonitoringController.getTemperatureStatus` — read `TenantContext.getTenantId()` and return per-tenant cached status (not a global singleton).
- [x] 14.w-6 Seed updates — Blue Ridge tenant config adds `noaa_station_id: KAVL` (Asheville regional, covers Boone/Waynesville); Pamlico adds `noaa_station_id: KEWN` (New Bern coastal). `dev-coc` keeps the global default (KRDU) since Raleigh is the original reference station.
- [x] 14.w-7 Unit tests — 2 added (`tenantSpecificStationIsUsed`, `nullStationFallsBackToGlobalDefault`); all 11 OperationalMonitorServiceTest methods green.
- [ ] 14.w-8 Integration test — start backend with 3 tenants (dev-coc, dev-coc-west, dev-coc-east), run the monitor, assert each tenant's `/api/v1/monitoring/temperature` reports the expected station id.
- [ ] 14.w-9 Admin UI copy — wherever the observability dashboard shows temperature, surface the station id clearly so operators understand which geography they're looking at (may be existing — confirm).
- [ ] 14.w-longterm **Warroom deferred**: long-term per-tenant weather strategy — first-class typed column vs multi-station per tenant vs shared-catalog model. Consult Alex, Jordan, Sam + web-search NOAA/weather.gov rate limits + HUD CoC geographic best practices. Fold decision into appropriate later phase. Not in scope for this change.

### Phase M-light fold-in — tenant-identity UI surfaces (for v0.48 bundle)

Warroom consensus (Casey + Marcus + Alex + Riley 2026-04-20): with three tenants about to go live in prod via V76/V77, the footer-version field is not enough for wayfinding. Accent colors from the original 14.9 are walked back (gimmicky on a shelter app, make screenshots inconsistent). Ship a neutral header chip + augmented footer instead — both surfaces carry `tenant.name` verbatim (already includes the "(demo)" suffix for Blue Ridge + Pamlico per Elena). Hide the header chip behind the kebab on narrow screens per the existing responsive pattern.

- [x] 14.t-1 `Layout.tsx` header — tenant-name chip left of the user menu, **border-only pill using `color.headerText` token** (warroom fold-in flipped from rgba opacity to WCAG-verified token per `project_accessibility_contrast_failures.md`), `data-testid="app-tenant-name"`, desktop-only with matching entry in the mobile kebab dropdown (`data-testid="header-overflow-tenant-name"`). Shows `user.tenantName` verbatim (incl. "(demo)" suffix).
- [x] 14.t-2 `Layout.tsx` footer — " — {tenantName}" appended to the version string wrapped in `data-testid="app-tenant-name-footer"`. Existing `app-version` testid preserved.
- [x] 14.t-3 Playwright smoke 13 + 14 assert both `app-tenant-name` + `app-tenant-name-footer` render the expected tenant string after login. 3/3 green.
- [ ] 14.t-4 Screenshot capture deferred to Phase M proper walkthrough bundle (14.16).

Intentionally deferred to Phase M proper (14.9 + 14.10 as originally written): per-tenant accent colors, `<title>` element tenant awareness, tenant-slug login-UI dropdown, login-screen helper text.

## 15. Verification + archive

- [ ] 15.1 `openspec validate multi-tenant-production-readiness --strict` green
- [ ] 15.2 Full backend test suite green (Karate + Playwright + Gatling)
- [ ] 15.3 All A–M themes have PR merged to main
- [ ] 15.4 Prod deploy complete; all three tenants live on findabed.org (`dev-coc`, `dev-coc-west`, `dev-coc-east`)
- [ ] 15.5 Change-closure gate (14.22) validated — public-browser evidence captured for all three tenants
- [ ] 15.6 `/opsx:verify multi-tenant-production-readiness` passes
- [ ] 15.7 `/opsx:sync multi-tenant-production-readiness` merges delta specs into main specs
- [ ] 15.8 `/opsx:archive multi-tenant-production-readiness`
- [ ] 15.9 Update memory `project_live_deployment_status.md` — multi-tenant mode active; `dev-coc-west` (Blue Ridge) + `dev-coc-east` (Pamlico Sound) present alongside `dev-coc`
- [ ] 15.10 Publish GitHub release + announcement
