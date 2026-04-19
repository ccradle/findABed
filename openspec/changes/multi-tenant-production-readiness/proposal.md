## Why

Companion change to `cross-tenant-isolation-audit` (Issue #117), shipped as FABT v0.40.0 on 2026-04-16. That audit closed the LIVE VULN-HIGH vulnerabilities (`findById`, URL-path-sink, `audit_events` cross-tenant read, SSRF in webhook/OAuth2/HMIS URLs) and installed mechanical guards (ArchUnit Family A+B, `TenantPredicateCoverageTest`, `SafeOutboundUrlValidator`, `@TenantUnscoped` annotations, `app.tenant_id` session variable as defense-in-depth infrastructure). That work moved the posture from "per-town dedicated instance is safe" toward "pool-ready." **This change closes the remaining gap.**

Post-audit three-agent research consolidation (2026-04-16) — SME persona-lens review (Marcus Webb + Alex Chen + Elena Vasquez + Casey Drummond + Jordan Reyes + Sam Okafor + Riley Cho) + codebase reality-check + 2026 industry web research — identified approximately 80 sub-items across 12 themes that must land before any multi-tenant procurement security review can answer "yes, safe to pool." The v0.40 audit was necessary; it is not sufficient. Without this change, the honest answer to any CoC is "take a dedicated instance today; pool when this lands." With this change, pooling becomes the default recommendation — for the standard tier. Regulated-tier (HIPAA BAA, VAWA-exposed DV CoCs) remains silo with an explicit upgrade path.

**Scope shape:**

- Cryptographic isolation at the per-tenant key level (JWT + DEK)
- Database-layer hardening using the `app.tenant_id` session variable installed in v0.40 Phase 4.8 — with Postgres 16.5+ pin for CVE-2024-10976, LEAKPROOF-wrapped policies, audit-log tamper-evidence, and `fabt_app` role restriction
- Cache isolation (`TenantScopedCacheService` + ArchUnit coverage of every Caffeine cache)
- Per-tenant operational boundaries (rate limit, connection pool budget via per-tenant `statement_timeout`, SSE buffer sharding, background-worker fair queueing, virtual-thread pinning guard)
- Tenant lifecycle FSM (create → active → suspended → offboarding → archived → deleted) with crypto-shredding for GDPR Article 17 + EDPB Feb 2026 erasure-in-backups compliance
- Audit + observability isolation (per-tenant hash-chained audit, OTel baggage, alert routing, log retention)
- Compliance documentation (HIPAA BAA template, VAWA 24-hour OVW pipeline, DV-safe breach notification, tenancy-model ADR, per-tenant retention matrix)
- Defense-in-depth hardening (opaque JWT `kid`, timing-attack mitigation, inbound webhook signing, ingress tenant-header rewrite, egress allowlist)
- Testing + validation (reflection-driven cache-bleed, SSE replay cross-tenant, breach simulation, noisy-neighbor Gatling, superuser-bypass CI guard, multi-tenant pentest engagement)
- Breach response (tenant-quarantine break-glass, forensic query tooling, IR runbook per class)
- Developer guardrails (`TenantScoped<T>` SPI, typed per-tenant config, per-tenant feature flags, stage environment with synthetic tenants, per-tenant canary)
- **Demo-site multi-tenant validation** (two additional permanent tenants seeded on `findabed.org` alongside `dev-coc`: `dev-coc-west` — Asheville CoC (demo) — and `dev-coc-east` — Beaufort County CoC (demo) — each with a full user/shelter/referral matrix. Pooling works as a live public proof across three tenants, not just a design document)

**Change-closure gate:** This change is NOT closed until the live demo at `findabed.org` serves three pooled tenants (`dev-coc`, `dev-coc-west`, `dev-coc-east`), and cross-tenant isolation probes against the live site from a demo visitor's browser return 404 with an educational message in every tested direction (at minimum: `dev-coc → dev-coc-west`, `dev-coc-west → dev-coc-east`, `dev-coc-east → dev-coc`). Per Maria + Teresa: a design document alone does not answer "can you show multi-tenant isolation live?" Per Riley: live additional tenants are also the most convincing regression guard against cross-tenant leakage in production — with three tenants the guard covers east→west leaks as well as core→peer leaks.

**Also absorbs two latent pre-existing issues** surfaced during pre-scope codebase audit:

1. `TenantOAuth2Provider.clientSecretEncrypted` and `HmisVendorConfig.apiKeyEncrypted` are **stored plaintext** despite the names (TODO comments in code acknowledge deferral to "production"). Encrypted on day-one of this change.
2. The originally-proposed `kid=tenant:<uuid>` JWT header would have leaked tenant UUIDs in every captured token. Redesigned to an opaque `kid=<random-uuid>` that resolves to `(tenant_id, key_generation)` server-side.

## What Changes

Organized into 12 workstream themes (A–L). No deferrals; every item ships in this change. Items flagged **[LATENT]** close pre-existing issues.

### A. Cryptographic isolation

- **A1. Per-tenant JWT signing keys** — HKDF-derived from platform KEK via `fabt:v1:<tenant-uuid>:jwt-sign` context string. Opaque `kid=<random-uuid>` in JWT header resolves to `(tenant_id, key_generation)` server-side (NOT `kid=tenant:<uuid>` — that leaks tenant IDs in captured tokens; Marcus). `JwtService.sign` uses the caller's current key; `JwtService.validate` resolves `kid` → tenant key → verify. Token claims cross-checked: the `tenantId` claim MUST equal the kid-resolved tenant. Bounded cache of kid→key for sub-microsecond validate.
- **A2. JWT revocation and suspend semantics** — `tenant.jwt_key_generation` column bumps on suspend, atomically invalidating all existing JWTs for that tenant. Fast-path `jwt_revocations(kid, expires_at)` list checked on validate; pruned daily.
- **A3. Per-tenant encryption DEKs** — HKDF-derived per-tenant via `fabt:v1:<tenant-uuid>:<purpose>` context strings (purpose ∈ {totp, webhook-secret, oauth2-client-secret, hmis-api-key, future}). Ciphertext prefixed with `kid` (tenant + DEK version) for in-place rotation with old-key decrypt grace.
- **A4. [LATENT] Encrypt OAuth2 + HMIS credentials NOW** — `TenantOAuth2Provider.clientSecretEncrypted` and `HmisVendorConfig.apiKeyEncrypted` are plaintext today (TODO comments in code). Call `SecretEncryptionService.encrypt()` on storage, `decrypt()` on retrieval. Flyway V59 re-encrypts existing rows idempotently with a `looksLikeCiphertext` guard. First PR of this change — does not wait for per-tenant DEKs (A3).
   - **Scoped out of A4 (folded into platform-hardening):** the typed HMIS vendor-CRUD endpoints (`HmisExportController.addVendor` / `updateVendor`) are stubbed 501 today. Until they ship, tenant-admin writes flow through the generic `PUT /api/v1/tenants/{tenantId}/config`, which serializes whatever JSONB the admin sends — including any net-new `hmis_vendors[].api_key_encrypted` plaintext. A4 closes the **read-side** gap (decrypt-on-read in `HmisConfigService` + V59 re-encryption of existing rows), exposes `HmisConfigService.encryptApiKey` for the future typed-write path, and accepts the residual write-side gap until platform-hardening lands those typed endpoints. OAuth2 has no equivalent gap — `TenantOAuth2ProviderService.create/update` is the sole write surface and encrypts unconditionally.
- **A5. Master KEK storage posture** — Oracle Always Free (standard tier): env var with filesystem permissions + kernel keyring + prod-profile guard + sealed-secrets tooling (extends `feedback_dev_keys_prod_guard.md`). Regulated tier: HashiCorp Vault Transit engine with derived keys. Rotation-procedure runbook (per-tenant + master-level) with documented RTO per scenario.
- **A6. Re-encryption migration for existing ciphertexts** — TOTP secrets + webhook callback secrets currently encrypted under the single platform key. Flyway + service migration re-wraps each under per-tenant DEK during v-next deploy. Dual-key-accept grace window for zero-downtime rollout.
- **A7. JWT `aud` / `iss` claim binding** — validate path asserts the `tenantId` claim matches the `kid`-resolved tenant key pair. A token signed with Tenant A's key but claiming Tenant B is rejected.

### B. Database-layer hardening (D14 realization + Elena's Postgres extensions)

- **B1. Postgres ≥ 16.5 pin** — CVE-2024-10976 (RLS policies evaluated below subqueries retain old role context under `SET ROLE`) is directly exploitable against v0.40's `app.tenant_id` pattern. Update `docs/oracle-update-notes-*.md` runbook floor; add CI check rejecting < 16.5.
- **B2. D14 tenant-RLS policies on regulated tables** — `audit_events`, `hmis_audit_log`, plus expansion to `password_reset_token`, `one_time_access_code`, `totp_recovery`, `hmis_outbox`. Policy shape: `USING (tenant_id::text = fabt_current_tenant_id())` where `fabt_current_tenant_id` is a `STABLE LEAKPROOF` SQL function wrapping `current_setting('app.tenant_id', true)` (avoids index disablement + error-message side-channel leaks).
- **B3. `FORCE ROW LEVEL SECURITY`** on all regulated tables — prevents owner bypass during admin sessions and migrations. Per Elena's non-negotiable.
- **B4. RLS index coverage + EXPLAIN regression** — `CREATE INDEX` on `(tenant_id, ...)` for every RLS-protected table. Integration test: EXPLAIN the canonical query per table; assert Index Scan, not Seq Scan.
- **B5. `pg_policies` snapshot as git-tracked artifact** — `docs/security/pg-policies-snapshot.md` is the output of `SELECT * FROM pg_policies` post-migration. CI diffs a live-DB snapshot against the git copy; drift fails the build. Elena's ground-truth tool for incident response.
- **B6. `SECURITY DEFINER` governance** — today: zero `SECURITY DEFINER` functions (correct per D1 intent). Future-proof: any Flyway migration that introduces one fails CI unless the migration header includes `@security-definer-exception: <justification>`. Migration-test guard.
- **B7. pgaudit extension enabled** — per-query DB-layer audit log (NOT application-layer). Format includes `app.tenant_id`. HIPAA BAA-class requirement. Log-rotation policy documented.
- **B8. Partition `audit_events` + `hmis_audit_log` by `tenant_id`** — list partitioning. Enables per-tenant backup via partition export, per-tenant VACUUM attribution, per-tenant retention windows.
- **B9. Per-tenant `statement_timeout` + `work_mem`** — `SET LOCAL statement_timeout = :tenant_timeout_ms` and `SET LOCAL work_mem = :tenant_work_mem` on every `@Transactional` entry AFTER `app.tenant_id` is set. Values sourced from `tenant_rate_limit_config` (E2) per tier.
- **B10. Logical replication + `pg_dump` + PITR posture** — document (v1 stance): no logical replication in use; per-tenant backup via `pg_dump --where="tenant_id = '<uuid>'"` with policy-strip step; PITR restores whole cluster only (per-tenant rollback unavailable, documented boundary).
- **B11. `SET LOCAL` + `@Transactional` ordering ArchUnit rule** — per `feedback_transactional_rls_scoped_value_ordering.md`. Rule: tenant-scoped `@Transactional` methods must not call `TenantContext.runWithContext()` inside the transaction; tenant context must be set BEFORE the `@Transactional` boundary.
- **B12. Connection-pool partial-failure test** — inject `SET ROLE` failure mid-setup; assert connection removed from pool, not returned in a mutated state. Extends existing `TenantIdPoolBleedTest`.
- **B13. Testcontainers-vs-prod RLS parity** — integration tests assert `current_user = 'fabt_app'` post-connection-borrow; fail if still `fabt` (superuser bypasses RLS silently — `feedback_rls_hides_dv_data.md`).

### C. Cache isolation

**Status as of 2026-04-19 PM:** 4.0 + 4.0b + 4.1 + 4.4 + 4.2 + 4.3 + 4.5 +
4.7 + 4.a shipped (8 of 10 tasks); 4.b (migrate 9 `PENDING_MIGRATION_SITES`
callers) + 4.6 (reflection bleed test) remain; release-group target v0.47.0
= "Phase C completes: cache isolation active across all application call
sites." Full decision trail in `design-c-cache-isolation.md` (D-C-1..13 +
D-4.b-1..7).

- **C1. `TenantScopedCacheService` wrapper** — prepends `TenantContext.getTenantId()` to every key (`|` separator per D-C-10); throws `IllegalStateException` tagged `TENANT_CONTEXT_UNBOUND` if no tenant context. ArchUnit **Family C** Rule C1 enforces `@TenantUnscopedCache("justification")` or `@TenantScopedByConstruction("justification")` on every raw `CacheService` / `TieredCacheService` call site. Wrapper additionally stamps-and-verifies values via `TenantScopedValue<T>(UUID tenantId, T value)` envelope (D-C-13: write-side defence — key-prefix defends read side, envelope defends write side; both must fail in the same direction for a leak).
- **C2. Extend ArchUnit Family C across `*.service` + `*.api` + `*.security` + `*.auth.*`** (D-C-3) — 11-field inventory at Phase C kickoff; all annotated (`@TenantUnscopedCache` × 10 + `@TenantScopedByConstruction` × 1). Rule C2 additionally blocks Spring `@Cacheable` / `@CacheEvict` / `@CachePut` outright (D-C-4: zero usage today; forbid to prevent parallel caching pattern).
- **C3. [LATENT] `EscalationPolicyService` cache split** — per D-C-2 two caches (not one composite rekey). `policyById` UUID-keyed `@TenantUnscopedCache` reserved for `@Scheduled` batch path; new `policyByTenantAndId` composite-keyed `@TenantScopedByConstruction` for request path. `EscalationPolicyBatchOnlyArchitectureTest` enforces the batch-only boundary on `findByIdForBatch` (package-restriction approximates `@Scheduled`-caller intent because ArchUnit can't walk the Spring Batch Job → Step → @Scheduled chain).
- **C4. Redis pooling ADR** — `docs/architecture/redis-pooling-adr.md` shipped (tasks 4.0 + 4.0b amendments): three-shape taxonomy (pooled+L1-only today, pooled+L2-single-tenant authorised, silo+L2-silo regulated); shared Redis without ACL-per-tenant rejected as default; HIPAA/VAWA encryption scope + shape-2 compensating controls + cached-value tenant verification documented.
- **C5. Reflection-driven cache-bleed test fixture** — lands at task 4.6 AFTER 4.b drains `PENDING_MIGRATION_SITES` (site-discovery count is load-bearing and changes during migration). Asserts `discoveredSites.size() >= EXPECTED_MIN_SITES` per D-C-7 (silent-empty guard per `feedback_never_skip_silently.md`).
- **C6. Negative-cache guardrail** — per D-C-5 shipped as source-scan `NegativeCacheGuardrailTest` (ArchUnit cannot inspect runtime argument values for literal-`null` / `Optional.empty()` detection); `putNegative(cacheName, key, ttl)` helper shipped for future 404-cache callers (zero today). Tenant-scoped by construction: `<tenantId>|:404:<key>` under the wrapper.
- **C7. `CacheService.evictAllByPrefix` API extension** — per D-C-12 new interface method used by `TenantScopedCacheService.invalidateTenant(UUID)`; Caffeine impl filters `keySet()`, Redis L2 path uses `SCAN MATCH <prefix>* COUNT 1000` + `UNLINK` per batch (documented; Redis L2 wiring deferred).
- **C8. PENDING_MIGRATION_SITES drain** (task 4.b) — 9 callers migrated from raw `CacheService` to `TenantScopedCacheService` in a single PR per D-4.b-1 (Alex coupling finding: `BedSearchService` + `AvailabilityService` share `CacheNames.SHELTER_AVAILABILITY`; staged migration would leave reader + writer on divergent envelope formats). Ship-list carries BedSearch pg_stat A/B/C baseline (D-4.b-4), parametrized cross-tenant attack IT × 8 caches + hit-rate sanity IT × 10 sites (D-4.b-5), and 3 Prometheus alert rules (D-4.b-6) co-located with v0.39.0 cross-tenant-isolation alerts.

### D. Control-plane hardening

- **D1. Deferred URL-path-sink sibling controllers** — Phase 2.1's D11 pattern applied to: `TenantController PUT /{id}/*`, `TenantConfigController.updateConfig`, `OAuth2ProviderController.list` (read-side enumeration filter). Plus a codebase sweep for any write-path controller with `{tenantId}` or `{id}` in the URL that the v0.40 audit missed.
- **D2. `TenantConfigController` stricter than write-path controllers** — tenant config is the root of every other tenant security boundary (rate-limit override, hold duration, webhook allowlist, statement_timeout, key rotation cadence). Validates against typed schema (L5); changes produce audit events; revertible.
- **D3. Nginx tenant-header rewrite from JWT** — any `X-Scope-OrgID` / `X-Tenant-Id` header from the client is rewritten by container nginx to the authenticated JWT's `tenantId` before reaching the backend. `proxy_set_header` REPLACES client value. T-Mobile 2021 lesson.
- **D4. mTLS or signed-header ingress binding (regulated tier only)** — for HIPAA BAA / VAWA-exposed tenants, nginx↔backend uses mTLS; belt-and-suspenders against `kid`-strip / Host-confusion. Standard tier continues without (acceptable trade-off documented in tenancy-model ADR, H1).

### E. Per-tenant operational boundaries

- **E1. Per-tenant rate limiting** — bucket key:
  - Unauthenticated paths (login, password reset, forgot-password): `(api_key_hash, ip)` — tenant isn't known pre-auth; the previously-proposed `(tenant_id, ip)` is impossible (Marcus finding, Agent A).
  - Authenticated paths: `(tenant_id, ip)` composite.
- **E2. `tenant_rate_limit_config` typed table** — per-tenant overrides for each endpoint-class rule (login, password-change, admin-reset, forgot-password, verify-totp, api-key, statement_timeout_ms, work_mem). Audit event on config change. Fail-safe defaults when config load fails (never fail-open).
- **E3. Per-tenant Hikari connection budget** — option (b) from the original stub: `SET LOCAL statement_timeout` per B9 sized per tenant tier. Sub-pool (option a) rejected as overcomplicated for current scale (~20-tenant ceiling).
- **E4. Per-tenant SSE event buffer shard** — replace global `ConcurrentLinkedDeque` in `NotificationService` with `Map<UUID, ConcurrentLinkedDeque>`; per-tenant cap (100 events) + per-platform cap (OOM guard).
- **E5. Per-tenant SSE delivery fairness** — dispatch loop round-robins over tenant queues, not FIFO. Per-tenant SSE connection limit (on `emitters` map, `NotificationService`).
- **E6. Fair-queue dispatch in background workers** — `HmisPushService`, `WebhookDeliveryService`, `EmailService`, future notifications workers: per-tenant inner queues + round-robin dispatch. Today's HMIS push processes one tenant's backlog before another's.
- **E7. Virtual-thread carrier-thread starvation guard** — forbidden-APIs / ArchUnit rule: no `synchronized` blocks in tenant-dispatched virtual-thread paths (pinned carrier threads can starve other tenants). `ReentrantLock` mandatory. Per `feedback_transactional_rls_scoped_value_ordering.md` + 2026 Java virtual-thread guidance.
- **E8. Per-tenant metrics for scheduled tasks** — `ReservationExpiryService`, `ReferralTokenPurgeService`, `AccessCodeCleanupScheduler`, `HmisPushScheduler`, `SurgeExpiryService` each emit per-tenant invocation + duration counters. Detects one tenant starving the batch window.

### F. Tenant lifecycle FSM (cross-persona consensus gap #1)

- **F1. `TenantState` enum on `tenant` table** — `ACTIVE`, `SUSPENDED`, `OFFBOARDING`, `ARCHIVED`, `DELETED`. FSM transitions documented + state-machine test asserting valid transitions only.
- **F2. `TenantLifecycleService.findByIdAndActiveTenantId`** — state-aware variant used by all tenant-owned repositories. Inactive tenant returns 404 (not 403 — D3 existence-leak consistency). Replaces `findByIdAndTenantId` at service-layer boundaries; repository-layer `findByIdAndTenantId` preserved for internal use.
- **F3. Tenant create workflow** — atomic: insert row, derive per-tenant JWT key + DEK (A1/A3), apply default config (typed per L5), bootstrap audit with `TENANT_CREATED` event, verify RLS predicates with a test query. Idempotent with rollback on partial failure.
- **F4. Tenant suspend workflow** — atomic 5-action quarantine: (a) bump `jwt_key_generation` (A2, invalidates existing tokens), (b) disable all API keys, (c) stop worker dispatch, (d) set `state=SUSPENDED` (writes return 503, reads preserved), (e) continue audit append. Operator break-glass command.
- **F5. Tenant offboard with JSON export** — schema'd export of all data classes (shelters, beds, users, referrals, audit events, HMIS history, config). 30-day delivery per GDPR Article 20 + EU Data Act (September 2025). Format stability contract documented.
- **F6. Tenant hard-delete with crypto-shredding** — primary data cascade by `tenant_id`, destroy per-tenant DEK (crypto-shred — ciphertexts computationally unrecoverable even from backups), document audit-log retention resolution (HIPAA 6-year vs GDPR erasure — per H7), document PITR backup-retention window ("tenant data persists in PITR for X days post-delete; after X days, provably destroyed"). Satisfies GDPR Article 17 + EDPB Feb 2026 erasure-in-backups coordinated enforcement framework.
- **F7. `data_residency_region` column on `tenant`** — per-tenant jurisdiction tag. Standard tier: `us-any`. Regulated tier: `us-<region>` or `silo`. Controls that depend on residency set (today: informational; enforced when any federal / EU tenant onboards).
- **F8. Lifecycle audit events** — every state transition produces a `platform_admin_access_log` + `audit_events` row with actor, target, prior state, new state, justification string.

### G. Audit + observability isolation

- **G1. Audit-log hash-chaining per tenant** — each `audit_events` row computes `row_hash = SHA256(prev_tenant_hash || canonical_json(row))`. Per-tenant chain head stored; externally anchored weekly (S3 Object Lock or equivalent append-only store) for tamper-evidence beyond DB-layer protection. VAWA-defensible audit (H4).
- **G2. `REVOKE UPDATE, DELETE FROM fabt_app` on audit tables** — `audit_events`, `hmis_audit_log`, `platform_admin_access_log` become INSERT-only for the application role. Tamper-evident at the DB layer.
- **G3. `platform_admin_access_log` table** — every platform-admin read of tenant-owned data logs `(admin_user_id, tenant_id, resource, justification, timestamp)`. Annotation-driven capture on `@PlatformAdminOnly` methods. Supports VAWA "comparable database" audit requirement (H4).
- **G4. OTel baggage tenant_id propagation** — W3C tracecontext `baggage: fabt.tenant.id=<uuid>` on every span. Resource attribute `fabt.tenant.id` for span-level filter in Jaeger / Tempo. No formal OpenTelemetry semantic convention for tenancy yet (2026); `fabt.*` namespace used as custom attribute.
- **G5. Per-tenant Grafana alert routing** — alerts include `tenant_id` label; Alertmanager routes to `tenant.oncall_email` (new column on `tenant`). Platform on-call receives platform-wide; tenant on-call receives tenant-scoped.
- **G6. Per-tenant metric cardinality budget** — explicit per-high-cardinality-metric budget documented (e.g., `http_server_requests_seconds` × `tenant_id` × 15 histogram buckets × N tenants). Exclude tenant tag from metrics that would exceed budget; provide per-tenant scoped queries via `$tenant` Grafana template variable (shipped in v0.40).
- **G7. Per-tenant log retention policy** — documented per tenant class. HIPAA: 6 years. VAWA: per OVW guidance. Standard: 1 year. Implemented via Loki retention (if adopted) or external log store rules.
- **G8. Reverse-proxy `X-Scope-OrgID` enforcement** — if Loki / Mimir adopted, nginx sets the tenant header from the JWT; never trusts client-supplied header. 2026 Grafana Loki / Mimir multi-tenant pattern.
- **G9. Per-tenant observability read access (regulated tier)** — future: tenant admins see ONLY their own metrics/logs/traces (Grafana organizations + Loki / Mimir auth_enabled). Scoped to regulated tier; standard tier stays operator-only.

### H. Compliance documentation

- **H1. Tenancy-model ADR** — `docs/architecture/tenancy-model.md`: pool-by-default + silo-on-trigger. Trigger criteria documented: (a) HIPAA BAA request, (b) VAWA-exposed DV CoC, (c) data-residency requirement, (d) procurement request. Non-scope documented explicitly: schema-per-tenant with upgrade-path note for regulated tier.
- **H2. HIPAA BAA template + per-tenant BAA registry** — `docs/legal/baa-template.md` + `docs/legal/per-tenant-baa-registry.md`. Data-flow diagram, encryption-in-transit attestation, encryption-at-rest attestation with DEK scope, access-log retention commitment, breach-notification SLA.
- **H3. VAWA 24-hour OVW breach reporting pipeline** — detection path (alert → classification → OVW notification draft) with `docs/security/vawa-breach-runbook.md` + pre-filled OVW notification template. Integration with G5 per-tenant alerting.
- **H4. VAWA "Comparable Database" architecture document** — per-tenant encryption posture that prevents platform operators (Corey + contractors) from reading DV survivor PII without audited unseal. Aligns with `feedback_rls_hides_dv_data.md`'s `fabt` vs `fabt_app` role distinction. Documented as SLA to DV CoCs. Encryption-at-rest with tenant DEK (A3) is the primary control; `platform_admin_access_log` (G3) is the secondary.
- **H5. DV-safe breach notification protocol** — survivor notification only through survivor-declared safe channels; explicit escalation procedure when safe channel unavailable. `docs/legal/dv-safe-breach-notification.md`. Email to shared household inbox is potentially lethal.
- **H6. `breach_notification_contacts` per-tenant table** — tenant's legal, technical, and on-call recipients + acknowledgment SLA. Tabletop exercise at release validates notification flow.
- **H7. Data-custody + retention-policy matrix** — `docs/legal/data-custody-matrix.md`: per data class (DV referral, shelter ops, analytics, audit) × per column (custodian, breach-recipient, retention-window, deletion-trigger, export-format, residency-pin). Resolves audit-log retention conflict (HIPAA 6-year vs GDPR erasure) case-by-case.
- **H8. Contract clause template library** — per-tenant MSA / SLA addendum covering isolation mechanism, breach-SLA, retention, exit procedure, custody. Casey artifact.
- **H9. Right-to-be-forgotten per-tenant procedure** — documented DELETE order across all tables referencing a user; cascade review verified; regression test that erasure is complete across `app_user`, `audit_events` (per H7 resolution), `one_time_access_code`, `password_reset_token`, `user_oauth2_link`, `totp_recovery`, `coordinator_assignment`, `referral_token` (historical terminal states). Integrates F6 crypto-shredding for per-user DEKs if per-user-keyed secrets ever introduced.
- **H10. Children / FERPA carve-out** — explicit acknowledgment in `docs/legal/children-data.md`: FABT does not currently serve unaccompanied-youth CoCs directly; if added, FERPA obligations attach differently.
- **H11. Legal-language scan extended to code comments** — `feedback_legal_scan_in_comments.md`: grep for "compliant", "equivalent", "guarantees" in any Javadoc / code comment added by this change. CI gate.

### I. Defense-in-depth hardening

- **I1. Timing-attack mitigation on `findByIdAndTenantId`** — either (a) constant-time 404 via fixed sleep floor + random jitter, OR (b) explicit ADR documenting UUID-is-not-secret acceptance. Decision in design.md; measured + documented either way.
- **I2. Inbound webhook per-tenant signing verification** — HMIS inbound callback / OAuth2 callback / any inbound webhook verified via per-tenant signing secret (per-tenant DEK context per A3). Rejects requests with missing or incorrect signature.
- **I3. Actuator authorization** — `/actuator/prometheus` → platform-admin only (metrics tagged by `tenant_id` visible only to cross-tenant operators). Other actuator endpoints unchanged per `feedback_actuator_security.md`.
- **I4. Referral token session binding** — `referral_token` table gains `originating_session_id`; accept/reject validates session match to originator OR requires 2FA re-step. Warm-handoff safety.
- **I5. Egress proxy per-tenant allowlist (regulated tier)** — per-tenant destination allowlist for webhook / OAuth2 / HMIS outbound. Belt-and-suspenders beyond v0.40's `SafeOutboundUrlValidator` IP checks. Standard tier continues without.
- **I6. Delivery-time webhook re-validation** — `WebhookDeliveryService` re-runs `SafeOutboundUrlValidator.validateForDial` on every retry attempt (defeats post-creation URL swap).

### J. Testing + validation

- **J1. Per-workstream test coverage matrix** — `docs/security/test-coverage-matrix.md`: each workstream A1–L10 mapped to test file(s) + layer (unit / integration / E2E / Gatling).
- **J2. Reflection-driven cache-bleed fixture** — parameterized over every Caffeine cache + every `TieredCacheService` call site. Test: `tenantA.write(k); tenantB.read(k)` → expect cache miss.
- **J3. SSE replay cross-tenant test** — 2-tenant setup; both disconnect with events buffered; both reconnect with `Last-Event-ID`; assert each tenant's replay contains ZERO events from the other.
- **J4. Per-tenant JWT key rotation test** — sign under key-gen 1, bump to 2, assert old token rejected at validate, new accepted, cross-tenant-key-confusion rejected (Tenant A token signed with Tenant A key but claiming Tenant B).
- **J5. URL-path-sink coverage for every write-path controller** — `TenantPredicateCoverageTest`-style parameterized fixture extended to ALL controllers with path variables. Regression guard for future additions.
- **J6. Tenant lifecycle tests** — create → provision users → suspend → 401 on all APIs → offboard → data preserved + no login → archived → reactivate blocked → delete → crypto-shred verified (DEK unrecoverable, encrypted columns now undecryptable).
- **J7. Breach-simulation tests** — seed DV referral in Tenant A; attempt cross-tenant read via 15+ attack vectors (path parameter, query parameter, header, body, cached value, SSE replay, audit event read, webhook payload, HMIS outbox, rate-limit bucket enumeration, prometheus scrape, log grep, timing, DNS rebinding, host-header injection, cache-bleed). Every attempt fails.
- **J8. Playwright cross-tenant cache-bleed** — login Tenant A, cache populated (DOM, Service Worker, IndexedDB); logout; login Tenant B; assert Tenant A data not visible anywhere.
- **J9. Hospital-PWA tenant-isolation test** (Dr. Whitfield persona) — locked-down Chrome, Service Worker blocked; multi-tenant doesn't break.
- **J10. Offline hold + tenant switch** (Darius persona) — queued offline hold, logout, login to different tenant; assert hold doesn't submit to new tenant.
- **J11. DV canary extension to multi-tenant** — pooled-instance DV canary: Tenant A has DV shelter, Tenant B has no dvAccess; Tenant B cannot see Tenant A's DV shelter in any surface (search, audit, HMIS, cache, replay, prometheus).
- **J12. Multi-tenant concurrent isolation at SCALE** — 20 tenants × 50 concurrent requests; zero cross-tenant leak + per-tenant p95 within SLO. Extends existing `CrossTenantIsolationTest`.
- **J13. File-path tenant-isolation test harness** — generates a test for every file-write code path; fails CI if a new write-path doesn't include `tenant_id` in filename or path. (Current codebase has no file-write paths; this is regression infrastructure for future additions.)
- **J14. Flyway migration rollback test** — drop each D14 tenant-RLS policy, re-add, assert identical state. Rehearsal for rollback plan.
- **J15. ArchUnit rule negative tests** — intentional violations for every new Family C / D / E rule asserts rule fires as expected.
- **J16. "What happens to the person in crisis if this test is missing?" comment** in every new tenant-isolation test — Riley's rule, enforced via PR review checklist.
- **J17. Superuser-bypass CI guard** — fail if any test runs as DB owner (`fabt`). `SELECT current_user` assertion in test harness; must be `fabt_app`.
- **J18. `NoisyNeighborSimulation` Gatling scenario** — two tenant simulations concurrent; Tenant A at 3× normal load; assert Tenant B p95 degrades ≤ 20%. Quantified SLO per-tenant.
- **J19. Multi-tenant chaos approximation** — Gatling-approximation of AWS FIS on Oracle Always Free: hostile-load one tenant while monitoring another's SLO.
- **J20. Pre-production external pentest** — OWASP Cloud Tenant Isolation checklist. Engaged before first pooled-tenant pilot. If external vendor not feasible (budget), self-audit against the checklist with evidence.

### K. Breach response + incident response

- **K1. Tenant-quarantine break-glass command** — atomic CLI + admin UI action: invalidate JWTs (A2), disable API keys, block inbound webhooks, freeze writes, preserve reads, audit the action (F8). E2E-tested.
- **K2. Forensic query tooling** — pre-built SQL + Grafana panel: "given a user / token / IP / timestamp, list every row read + written across every tenant." Primary incident-response tool.
- **K3. IR runbook per breach class** — `docs/security/ir-runbooks/`: (a) suspected cross-tenant read, (b) stolen credential, (c) vendor / infra compromise, (d) DV-specific breach (VAWA pipeline per H3).

### L. Developer experience + guardrails

- **L1. `TenantScoped<T>` SPI** — one type through which every per-tenant resource is acquired (signing key, DEK, Caffeine cache, rate-limit bucket, metrics tag, statement_timeout value). Replaces bespoke per-concern plumbing that would result from implementing A–G in isolation. Alex's architectural-coherence gate.
- **L2. Tenant module boundary ArchUnit (Family F)** — no other module reads `tenant` table directly; must go through `TenantService` / `TenantLifecycleService`. Reinforces modular-monolith (`feedback_modular_monolith.md`).
- **L3. Tenant-destructive migration review gate** — Flyway migration comment must include `@tenant-safe` or `@tenant-destructive: <justification>`. CI rejects if absent. Prevents silent cross-tenant `UPDATE`s in migrations.
- **L4. Typed per-tenant feature flags** — `tenant_feature_flag` table (not JSON blob); strongly-typed config read via `FeatureFlagService.isEnabled(tenantId, flag)`. Canary rollout per-tenant supported.
- **L5. Typed per-tenant config** — replace `tenant.config` JSONB with typed columns or typed sub-tables (hold duration, surge threshold, rate-limit overrides, webhook allowlist, statement_timeout, `work_mem`, key rotation cadence, `api_key_auth_enabled`, `default_locale`, `oncall_email`, `data_residency_region`).
- **L6. Per-tenant canary deployment** — feature-flag-gated new-code paths per tenant; one tenant can run "next" while others stay on "current."
- **L7. Stage environment with 3 synthetic tenants** — `stage.findabed.org` runs pooled 3-tenant setup. Demo (`findabed.org`) stays single-tenant. Any pool-readiness test runs against stage.
- **L8. Per-tenant DR drill** — quarterly: "Tenant X corrupted; restore just X." Scripted; verification checklist in `docs/runbook.md`.
- **L9. Cost allocation per tenant** — DB storage (per-tenant partition size after B8), CPU via OTel per-tenant baggage (G4), webhook outbound bytes. Quarterly attribution report.
- **L10. Rotation runbooks** — per-tenant DEK rotation, per-tenant JWT key rotation, master KEK rotation — all with documented RTO and zero-downtime procedure.

### M. Demo-site multi-tenant validation (change-closure gate)

This theme is the **public proof-of-life** for the rest of the change. Without it, multi-tenant production-readiness is a design document; with it, any procurement review, pilot prospect, or security auditor can confirm isolation by pointing a browser at `findabed.org` and logging in as either tenant.

- **M1. Two additional permanent tenants in seed data** — TWO new permanent tenants added to `infra/scripts/seed-data.sql` alongside the existing `dev-coc`:
  - **`dev-coc-west` — "Asheville CoC (demo)"** — UUID `a0000000-0000-0000-0000-000000000002`. Asheville-themed fictional seed content (Western NC positioning).
  - **`dev-coc-east` — "Beaufort County CoC (demo)"** — UUID `a0000000-0000-0000-0000-000000000003`. Beaufort County, NC (Washington NC seat) themed fictional seed content (Eastern NC positioning).
  Each tenant's seed matrix mirrors `dev-coc` scope: 6 role users (PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER, DV_COORDINATOR, DV_OUTREACH), 3–5 shelters (at least one DV shelter so the DV-access cross-tenant boundary is exercisable), sample bed availability, 1 sample pending DV referral. Idempotent `INSERT ... ON CONFLICT DO UPDATE` pattern; safe to re-run. Credential conventions: `admin@asheville.fabt.org` / `admin123` for west users, `admin@beaufort.fabt.org` / `admin123` for east users (shared password mirrors `dev-coc` for demo-visitor convenience).
- **M2. Branding clarity — "(demo)" suffix on both new tenants** — per Casey: both `Asheville` (City of Asheville relationship via Sarah Dickerson) AND `Beaufort County, NC` are real jurisdictions. To avoid any visitor mistaking the demo tenants for real Asheville-Buncombe CoC OR Beaufort County CoC deployments, displayed tenant names are `Asheville CoC (demo)` and `Beaufort County CoC (demo)` respectively in login UI, landing page, admin panel header, page title, and all training materials. Seed data uses demonstrably-fictional shelter names (e.g., "Example House North", "Example Family Center"), fictional addresses (obviously non-geocodable patterns), and persona-derived fake contact names in BOTH tenants.
- **M3. Visible tenant indicator in UI** — Layout component (header or footer) shows current tenant name + subtle accent color differentiator. `<title>` element carries tenant name. Tenant switches between ANY pair of `dev-coc`, `dev-coc-west`, `dev-coc-east` produce obviously-different UI state (not just route, but visual identity). Three distinct accent colors SHALL be used so screenshot evidence visually disambiguates. Accessibility: tenant name announced on page-load per WCAG 2.4.2.
- **M4. Educational cross-tenant UX messaging** — when a demo visitor attempts cross-tenant access (URL manipulation, bookmark paste, copy-paste from another admin's UI), the 404 response body carries an educational message: *"This resource belongs to a different tenant. FABT's multi-tenant isolation prevents cross-tenant data access — this is the system working as designed."* This converts a silent 404 into a pool-readiness proof-point for the procurement audience. Guarded by an internal feature flag so the educational message can be toggled off if it ever becomes an information disclosure concern (it is not today — D3 prevents existence leak, the message does not reveal the other tenant's state). Message applies across all three tenants symmetrically.
- **M5. Post-deploy smoke covers ALL THREE tenants** — cross-tenant Playwright + Karate smoke runs against `dev-coc`, `dev-coc-west`, AND `dev-coc-east`: login to each, attempt cross-tenant URL against at least one other tenant, expect 404 with educational envelope. Minimum 3-probe rotation (e.g., `dev-coc → dev-coc-west`, `dev-coc-west → dev-coc-east`, `dev-coc-east → dev-coc`); full 6-pair matrix encouraged. Regression guard against "live multi-tenant deployment develops cross-tenant leak" — now covers east-west leaks in addition to core-peer leaks.
- **M6. Multi-tenant demo walkthrough** — new doc `docs/training/multi-tenant-demo-walkthrough.md`: 3-minute scripted visitor walkthrough covering all three tenants ("log in as `dev-coc`, observe shelters; log out; log in as `dev-coc-west` / Asheville, observe different shelters + different DV posture; attempt cross-tenant URL, observe educational 404; log out; log in as `dev-coc-east` / Beaufort County, observe third regional posture; attempt another cross-tenant URL, observe educational 404"). Screenshot bundle folded into the `#120` pilot-readiness bundle. Linked from findabed.org landing page and FOR-COORDINATORS / FOR-COC-ADMINS audience docs.
- **M7. Live-validation probe as Grafana panel (operator-facing)** — new panel on `fabt-cross-tenant-security` dashboard: "Tenant-pair last validation timestamp" — updates when the post-deploy smoke from M5 runs, so operator sees at a glance whether live multi-tenant isolation was validated in the last 24 hours. Green/yellow/red indicator.
- **M8. Seed migration safety gate (covers BOTH new-tenant migrations)** — BOTH Flyway migrations that create new demo tenants are reviewed pre-merge: **V76** (`dev-coc-west` / Asheville) and **V77** (`dev-coc-east` / Beaufort County). Reviewers per migration: Casey (real-jurisdiction-name confirmation + `(demo)` suffix enforcement), Marcus (no real-PII patterns), Maria (procurement-audience language). Review gate applies independently to each PR. Deploy sequence: both migrations land in prod → seed populates → M5 all-tenant post-deploy smoke green → only then does `opsx:archive` gate close.
- **M9. Noisy-neighbor live validation** — `NoisyNeighborSimulation` (J18) gains an "against-live-demo" variant that can be operator-triggered: hostile-load one of the new tenants (`dev-coc-west` OR `dev-coc-east`, operator's choice per drill) while monitoring `dev-coc` p99 AND the non-targeted new tenant's p99. Proves per-tenant performance isolation on the actual production path across all three tenants — not just test bench, not just core-vs-peer.
- **M10. Tenant quarantine live drill** — `K1` tenant-quarantine break-glass is demonstrable on `dev-coc-west` OR `dev-coc-east` (operator's choice; rotate across quarters to exercise both): operator quarantines the targeted tenant, shows that tenant's logins fail with 503, shows the other two tenants remain reachable, un-quarantines, shows login restored. Quarterly operator drill. `dev-coc` SHALL NOT be used as a quarantine target — its availability is the public-demo baseline.
- **M11. Offboard live drill** — once F5 export + F6 crypto-shred ship, an operator-run drill offboards `dev-coc-west` OR `dev-coc-east` (operator's choice; rotate across quarters): exports data, destroys DEK, re-seeds fresh via V76 (for west) or V77 (for east). Proves end-to-end tenant lifecycle works on production. Quarterly.

## Capabilities

### New capabilities

- **`per-tenant-key-derivation`** — HKDF JWT + DEK derivation, opaque kid mapping, revocation semantics, rotation procedure, re-encryption migration (A1–A7, L10).
- **`tenant-scoped-cache`** — `TenantScopedCacheService`, ArchUnit Family C, every Caffeine instance covered, Redis posture ADR, cache-bleed reflection test (C1–C6).
- **`tenant-rls-regulated-tables`** — D14 carve-out + LEAKPROOF function + `FORCE ROW LEVEL SECURITY` + `pg_policies` snapshot + SECURITY DEFINER governance + pgaudit + partitioning + per-role statement_timeout (B2–B13).
- **`tenant-lifecycle`** — TenantState FSM, state-aware repositories, create/suspend/offboard/hard-delete workflows, crypto-shredding, GDPR Article 17 + EDPB Feb 2026 erasure-in-backups, GDPR Article 20 + EU Data Act Sept 2025 portability, data residency tagging (F1–F8).
- **`per-tenant-operational-boundaries`** — rate limit, Hikari budget via `statement_timeout`, SSE buffer shard + delivery fairness + connection cap, background-worker fair queuing, virtual-thread pinning guard, scheduled-task per-tenant metrics (E1–E8).
- **`audit-log-tamper-evidence`** — per-tenant hash-chain + external anchor + DB-layer REVOKE + `platform_admin_access_log` (G1–G3).
- **`per-tenant-observability-isolation`** — OTel baggage, alert routing, cardinality budget, retention per tenant class, reverse-proxy tenant-header enforcement, regulated-tier per-tenant read access (G4–G9).
- **`tenancy-compliance-posture`** — tenancy-model ADR, HIPAA BAA, VAWA 24-hr pipeline + Comparable Database, DV-safe notification, data-custody matrix, right-to-be-forgotten, children/FERPA carve-out, legal-scan in comments (H1–H11).
- **`tenant-defense-in-depth`** — timing-attack mitigation, inbound webhook signing, actuator authorization, session binding, egress allowlist, delivery-time re-validation (I1–I6).
- **`tenant-breach-response`** — quarantine break-glass, forensic queries, IR runbooks per breach class (K1–K3).
- **`tenant-developer-guardrails`** — `TenantScoped<T>` SPI, module boundary ArchUnit, migration gate, typed feature flags, typed config, per-tenant canary, stage environment, DR drill, cost allocation, rotation runbooks (L1–L10).
- **`multi-tenant-demo-seed`** — two additional permanent tenants on `findabed.org` (`dev-coc-west` / "Asheville CoC (demo)" AND `dev-coc-east` / "Beaufort County CoC (demo)") each with full user/shelter/referral matrix, visible three-way tenant indicator in UI, educational cross-tenant 404 envelope, post-deploy smoke against all three tenants, multi-tenant walkthrough doc + screenshot bundle covering all three, operator-facing validation-timestamp Grafana panel, noisy-neighbor / quarantine / offboard live operator drills targeting the two new tenants on rotation (M1–M11). **Change-closure gate: proposal does not archive until live demo serves all three tenants AND cross-tenant probes from a public browser against findabed.org return an educational 404 in every tested direction.**

### Modified capabilities

- **`multi-tenancy`** — adds tenant-lifecycle FSM, per-tenant-state-aware repositories, per-tenant-keyed surfaces, per-tenant observability, breach-notification scope requirements.
- **`rls-enforcement`** — adds tenant-RLS on regulated tables (D14), LEAKPROOF function wrapping, `FORCE ROW LEVEL SECURITY`, pgaudit, per-role `statement_timeout`, SECURITY DEFINER governance, `pg_policies` snapshot.
- **`cross-tenant-isolation-test`** — adds cache-bleed reflection fixture, SSE replay cross-tenant, JWT rotation, tenant-lifecycle tests, breach simulation (15+ vectors), noisy-neighbor Gatling, superuser-bypass CI guard, URL-path-sink coverage for every write controller, Playwright cross-tenant cache-bleed, multi-tenant concurrent-at-scale.
- **`observability`** — adds OTel baggage with `fabt.tenant.id`, per-tenant Grafana alert routing, per-tenant metric cardinality budget, per-tenant log retention, reverse-proxy `X-Scope-OrgID` enforcement (when Loki/Mimir adopted).

## Impact

### Affected code paths

`JwtService`, `SecretEncryptionService`, `TieredCacheService` (new wrapper + ArchUnit coverage), `RlsDataSourceConfig`, `ApiKeyAuthenticationFilter`, `NotificationService`, `TenantService` + new `TenantLifecycleService`, `TenantController`, `TenantConfigController`, `OAuth2ProviderController`, `TenantOAuth2ProviderService`, `HmisVendorConfig` + `HmisConfigService`, `HmisPushService`, `WebhookDeliveryService`, `EscalationPolicyService`, `ReservationExpiryService`, `ReferralTokenPurgeService`, `AccessCodeCleanupScheduler`, `SurgeExpiryService`, `HmisPushScheduler`, `GlobalExceptionHandler` (educational cross-tenant 404 envelope from M4), `frontend/src/components/Layout.tsx` (tenant indicator from M3), `logback-spring.xml`, `infra/docker/nginx.conf`, `infra/scripts/seed-data.sql` (both new-tenant seeds from M1 — `dev-coc-west` / Asheville AND `dev-coc-east` / Beaufort County), `prometheus.yml`, Grafana dashboards (per-tenant alert labels + M7 tenant-pair validation panel), `e2e/playwright/deploy/` post-deploy smoke specs (M5 all-tenant coverage), `docs/training/multi-tenant-demo-walkthrough.md` (M6), `docs/runbook.md`, `docs/security/*`, `docs/legal/*`, `docs/architecture/tenancy-model.md`, operational runbooks.

### Breaking changes

- **JWT invalidation on first deploy** — existing access tokens (15 min) + refresh tokens (7 days) invalidated when per-tenant keys activate. Coordinated logout banner + re-login window for pilots.
- **Ciphertext re-encryption migration** (A6) — TOTP secrets + webhook callback secrets re-wrapped under per-tenant DEKs. Dual-key-accept grace window (old + new) for zero-downtime rollout over ~1 week.
- **OAuth2 + HMIS credential encryption** (A4) — fields currently stored plaintext become encrypted; migration re-encrypts existing rows in-place on first deploy. No downtime.
- **`audit_events` + `hmis_audit_log` + `platform_admin_access_log` INSERT-only for `fabt_app`** (G2) — any code path that does `UPDATE audit_events ...` fails. No such code exists today (verified); rule protects future.
- **Tenant state-aware repository pattern** (F2) — every tenant-owned repository's `findByIdAndTenantId` becomes `findByIdAndActiveTenantId` at the service-layer boundary (404 on SUSPENDED / OFFBOARDING / ARCHIVED / DELETED). Same 404 as "doesn't exist" — consistent with D3 existence-leak-prevention.
- **`X-Scope-OrgID` / `X-Tenant-Id` client headers rewritten by nginx** (D3) — any client currently setting these headers will see them replaced. No legitimate caller does this today.
- **JWT `kid` format change to opaque UUID** (A1) — clients that inspect `kid` for debugging will see the new format. Tokens themselves still opaque to legitimate clients.

### Migrations (Flyway V59–V76 range)

> Numbering finalized 2026-04-17 to ensure Phase 0 ships before Phase A in
> Flyway-version order (Phase 0 = V59; Phase A starts at V60). See `design.md`
> §"Ciphertext re-encryption migration window" for the V59 / V74 split rationale.

- **V59 — Re-encrypt OAuth2 + HMIS credentials** (A4 latent fix; first PR of the change, before the rest of the migration chain). Idempotent Java migration using single-platform `SecretEncryptionService` AES-GCM. Writes one `SYSTEM_MIGRATION_V59_REENCRYPT` row to `audit_events` inside the migration transaction.
- **V60 — tenant table additions**: `state` (TenantState enum), `jwt_key_generation` (int), `data_residency_region` (varchar), `oncall_email` (varchar).
- **V61 — `jwt_revocations`** table (kid, expires_at; daily-pruned).
- **V62 — `tenant_rate_limit_config`** table (per-tenant per-endpoint overrides + statement_timeout_ms + work_mem).
- **V63 — `tenant_feature_flag`** table (replaces JSON feature flags).
- **V64 — `breach_notification_contacts`** per-tenant table.
- **V65 — `platform_admin_access_log`** table.
- **V66 — `audit_events` hash-chain columns** (`prev_hash`, `row_hash`).
- **V67 — D14 tenant-RLS policies** on `audit_events`, `hmis_audit_log`, `password_reset_token`, `one_time_access_code`, `totp_recovery`, `hmis_outbox`.
- **V68 — `fabt_current_tenant_id()` LEAKPROOF function** wrapping `current_setting('app.tenant_id', true)`.
- **V69 — `FORCE ROW LEVEL SECURITY`** on every regulated table.
- **V70 — `CREATE INDEX (tenant_id, ...)`** on every RLS-protected table (per B4).
- **V71 — Partition `audit_events` + `hmis_audit_log`** by `tenant_id` (list partitioning).
- **V72 — `REVOKE UPDATE, DELETE`** on audit tables from `fabt_app`.
- **V73 — pgaudit extension enable** (or documented manual step if extension install is out-of-band on Oracle Always Free).
- **V74 — Re-encrypt TOTP + webhook secrets** under per-tenant DEKs (A6 data migration); the V59 ciphertexts (single-platform key) are unwrapped and re-wrapped under per-tenant DEKs in the same pass. Dual-key-accept grace window for ~1 week post-migration.
- **V76 — `dev-coc-west` / Asheville CoC (demo) tenant seed** (M1) — idempotent `INSERT ... ON CONFLICT DO UPDATE` for tenant row + 6 users + 3–5 shelters (at least one DV) + sample availability + 1 sample pending DV referral. UUID pinned at `a0000000-0000-0000-0000-000000000002`. Users under `@asheville.fabt.org` email domain. Seed reviewed pre-merge by Casey / Marcus / Maria per M8. (V75 left unused as a breathing-room slot.)
- **V77 — `dev-coc-east` / Beaufort County CoC (demo) tenant seed** (M1) — idempotent `INSERT ... ON CONFLICT DO UPDATE` for tenant row + 6 users + 3–5 shelters (at least one DV) + sample availability + 1 sample pending DV referral. UUID pinned at `a0000000-0000-0000-0000-000000000003`. Users under `@beaufort.fabt.org` email domain. Seed reviewed pre-merge by Casey / Marcus / Maria per M8. Same review rigor as V76.

### Rollback procedures (per-phase)

Every phase ships behind a feature flag where possible (L4 typed-flag table)
and with an explicit rollback path documented in its `oracle-update-notes-vX.Y.Z.md`.

- **Phase 0 (V59 + encryption wiring)** — pre-deploy backup of `tenant_oauth2_provider`
  + `tenant.config` JSONB (pg_dump); rollback path is restore-from-backup +
  delete the V59 row from `flyway_schema_history` + roll JAR back to v0.40.0.
  V59 is idempotent; partial-failure-during-batch is recoverable by re-running
  the migration on the next start.
- **Phase A (per-tenant DEK + JWT)** — coordinated 7-day re-login window means
  rollback within that window invalidates pilots' new tokens; mitigation is the
  dual-key-accept grace (old single-platform + new per-tenant DEK) for the
  re-encrypt migration so JWT validation tries both keys before failing.
- **Phase B (RLS + FORCE RLS)** — every D14 policy has a `DROP POLICY` rollback
  in its companion migration; the `FORCE ROW LEVEL SECURITY` step is reversible
  via `ALTER TABLE ... NO FORCE ROW LEVEL SECURITY`. Tested in J14 Flyway rollback
  test before each Phase B PR.
- **Phase F (tenant FSM + crypto-shred)** — hard-delete is irreversible by
  design; the 30-day archival state (F1) provides the rollback window before
  the destructive step. Operators confirm via break-glass command, audit event
  trails the decision.
- **All phases** — every PR carries an `oracle-update-notes-vX.Y.Z.md` with the
  per-deploy rollback procedure. Generic per-phase rollback rules above are the
  defaults; phase-specific risks override them.

### Deploy footprint

- **Coordinated re-login window** — pilots receive notice; existing JWTs invalidated at cutover.
- **Postgres minor-version upgrade** to ≥ 16.5 (CVE-2024-10976) — independent pre-cutover step.
- **Stage environment spin-up** — `stage.findabed.org` with 3 synthetic tenants. One-time infrastructure addition.
- **Effort estimate — ~13–19 weeks calendar with 1–2 engineers**:
  - A. Cryptographic isolation: ~2 weeks
  - B. DB-layer hardening: ~2 weeks
  - C. Cache isolation: ~1 week
  - D. Control-plane hardening: ~1 week
  - E. Operational boundaries: ~2 weeks
  - F. Tenant lifecycle FSM: ~2 weeks
  - G. Observability isolation: ~1 week
  - H. Compliance documentation: ~2 weeks (with Casey review loops)
  - I. Defense-in-depth: ~1 week
  - J. Testing + validation: ~2 weeks
  - K. Breach response: ~1 week
  - L. Developer guardrails: ~1–2 weeks
  - M. Demo-site multi-tenant validation: ~1 week (seed data + UI indicator + post-deploy smoke + walkthrough doc)
  - Sum raw: ~19 weeks; ~13–17 with parallelism + compression.

### Prerequisite

`cross-tenant-isolation-audit` (Issue #117) must be merged and deployed. Shipped as v0.40.0 on 2026-04-16. This change extends that audit's infrastructure (`app.tenant_id` session variable from Phase 4.8, `@TenantUnscoped` from Phase 1, `SafeOutboundUrlValidator` from Phase 2.14, ArchUnit Family A+B rules, `TenantPredicateCoverageTest`).

### Non-scope

- **Schema-per-tenant or DB-per-tenant architectural shift** — explicit ADR (H1) documents pool-by-default + silo-on-request for the regulated tier. Schema-per-tenant would be a separate proposal if it becomes necessary. Current discriminator + RLS hybrid is the architecture this change hardens.
- **Per-tenant dedicated cloud instances** — addressed by the silo tier via separate deploy, not by this change.
- **Continuous CTEM (Strobes / Pentera / XM Cyber) subscription** — J20 pre-production pentest engagement is scoped; continuous paid CTEM tools are nice-to-have.
- **Bug bounty program** — nice-to-have; not in this change.
- **SOC 2 Type II audit engagement** — formal Type II audit requires 3–12 months observation period; scoped as a post-pilot year-1 initiative, not in this change. Control-level groundwork (documented audit trail, tenant-scoped access logs, segregation of duties) is in this change.

## Status

**SCOPED — ready for `/opsx:ff` to generate `design.md` + `specs/` + `tasks.md`.** Previous STUB (10 workstreams, 7869 chars) superseded by this expanded proposal (**13 themes A–M, ~90 sub-items**). Scope finalized 2026-04-16 via three-agent research consolidation: SME persona-lens review (Marcus + Alex + Elena + Casey + Jordan + Sam + Riley), codebase reality-check (16-point audit), 2026 industry web research (SaaS isolation best practices, Postgres RLS guidance, envelope encryption patterns, tenant lifecycle, SOC 2 / HIPAA / VAWA compliance). Theme M (demo-site multi-tenant validation) added 2026-04-16 via warroom review per user request as the change-closure gate — the live demo on `findabed.org` must serve three pooled tenants (`dev-coc`, `dev-coc-west`, `dev-coc-east`; expanded from two to three on 2026-04-18) with live cross-tenant probes returning educational 404 across all tested pairs before `/opsx:archive` closes. See `docs/architecture/tenancy-model.md` (H1) for the tenancy-model decision record produced as the first artifact of the change.
