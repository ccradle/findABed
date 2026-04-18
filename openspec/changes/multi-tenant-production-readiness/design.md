## Context

Post v0.40 (cross-tenant-isolation-audit shipped 2026-04-16), FABT has service-layer tenant enforcement, ArchUnit Family A + B guards, SQL-predicate static analysis, `SafeOutboundUrlValidator`, `@TenantUnscoped` annotations, and an `app.tenant_id` session variable installed but unused. This change completes the posture shift to "pool multiple CoCs safely on one shared instance" across 13 themes (A–M) and 116 sub-items. Scope consolidated via three-agent research: SME persona-lens review (Marcus + Alex + Elena + Casey + Jordan + Sam + Riley), codebase reality-check (16-point audit), 2026 industry best-practices research.

Architecture stays with the discriminator + RLS hybrid (not schema-per-tenant or DB-per-tenant). Current deploy target is Oracle Always Free A1 Flex ARM64 (Postgres 16, single Docker compose, Cloudflare edge). Pilot prospects span standard-tier (generic CoC) and regulated-tier (HIPAA BAA / VAWA-exposed DV CoCs). Change-closure gate is a demonstrable second tenant on `findabed.org` answering "show us multi-tenant isolation" from a procurement browser.

Key stakeholders: Corey (engineering lead, 1-person core team + AI collab), Marcus Webb (AppSec persona for audit), Casey Drummond (legal persona for compliance artifacts), Sarah Dickerson (City of Asheville contact — Casey's branding guardrail motivation for M2).

## Goals / Non-Goals

**Goals:**
- Enable any pooled multi-tenant procurement review to answer "yes, safe to pool" — technically, operationally, legally
- Close every LIVE + ARCHITECTURAL gap identified by the three-agent research; zero deferred items
- Preserve the shipped v0.40 investment (build-time guards, ArchUnit rules, `SafeOutboundUrlValidator`, `@TenantUnscoped` annotations, `app.tenant_id` infrastructure) and activate the dormant defense-in-depth (`app.tenant_id` gets consumed by policies; audit_events + hmis_audit_log gain tenant-RLS per D14)
- Fix two latent pre-existing issues on day one: plaintext OAuth2/HMIS credentials (A4), and the leaky `kid=tenant:<uuid>` design the STUB originally proposed (A1)
- Ship a demonstrable live proof on `findabed.org` — not just a design document
- Stay compatible with Oracle Always Free deployment footprint (no K8s, no paid KMS mandatory)

**Non-Goals:**
- Schema-per-tenant / database-per-tenant architectural shift — preserves discriminator + RLS hybrid
- Per-tenant dedicated cloud instances (handled by the silo tier via separate deploy)
- SOC 2 Type II audit engagement (requires 3–12 month observation; post-pilot year-1)
- Continuous CTEM (Strobes / Pentera / XM Cyber) subscription
- Bug bounty program
- Self-service tenant provisioning by external users (operator-only for v1)

## Decisions

### D1 — Opaque JWT `kid`; server-side mapping to (tenant, key_generation)

Marcus Webb's SME review flagged that the STUB's originally-proposed `kid=tenant:<uuid>` leaks tenant UUIDs via captured tokens (pcap, log aggregation, browser history). Decision: `kid=<random-uuid>` resolves server-side via a bounded cache (`kid_to_tenant_key(kid, tenant_id, key_generation, rotated_at)` table) to the signing key pair. Rejected alternatives: (a) signed-but-encrypted kid (over-engineered), (b) kid-as-hash-of-tenant+salt (still enumerable). Additional guard: `JwtService.validate` asserts the `tenantId` claim in the token body matches the `kid`-resolved tenant (A7). Cache the resolution for sub-microsecond validate.

### D2 — HKDF derivation rooted in a single platform KEK; per-tenant DEK/JWK rotation

Derivation: `derivedKey = HKDF(masterKekBytes, salt=<tenant_uuid>, info="fabt:v1:<tenant-uuid>:<purpose>")` where `masterKekBytes` is the 32-byte value already established as `FABT_ENCRYPTION_KEY` in Phase 0. Purposes scoped today: `jwt-sign`, `totp`, `webhook-secret`, `oauth2-client-secret`, `hmis-api-key`. Context strings are versioned (`v1`) for future migration. `kid=<opaque-uuid>` stored alongside ciphertext includes the DEK version, enabling in-place rotation with an old-key decrypt grace window.

Rejected alternative: per-tenant randomly-generated keys stored wrapped under KEK. Rejected because HKDF is deterministic, auditable, and allows re-derivation of lost keys from KEK + tenant_uuid without needing key-escrow infrastructure.

### D3 — Master KEK storage: env var (standard) + Vault Transit (regulated)

Standard tier (current Oracle Always Free demo + most pilot CoCs): the `FABT_ENCRYPTION_KEY` env var introduced in Phase 0 is the master KEK for HKDF derivation. Sourced from `~/fabt-secrets/.env.prod` (or the systemd drop-in `/etc/systemd/system/fabt-backend.service.d/encryption-key.conf` per Phase 0 oracle notes) with filesystem permissions 400, `root:fabt` ownership, prod-profile-rejects-dev-key guard (already shipped as the C2 hardening of `SecretEncryptionService` in Phase 0). No new env var; Phase A reads the same bytes. Documented as acceptable for non-regulated pooled tenants.

Regulated tier (HIPAA BAA, VAWA-exposed): HashiCorp Vault Transit engine with `derived=true` keys + per-tenant context. `FABT_KEK_VAULT_TOKEN` + `FABT_KEK_VAULT_ADDR` env vars replace the direct master key; `SecretEncryptionService` proxies through Vault for derivation. Regulated-tier deploy is a silo, not pooled.

Rejected alternatives: OCI Vault/KMS (mostly out of Oracle Always Free tier; vendor-locked), AWS KMS (wrong cloud). HashiCorp Vault is open-source, self-hostable on the same Oracle VM for smaller regulated deployments.

### D4 — Per-role `statement_timeout` rejected; `SET LOCAL` per @Transactional chosen

Elena's SME review proposed per-role Postgres roles (`tenant_free`, `tenant_pro`, `tenant_enterprise`) with `ALTER ROLE tenant_pro SET statement_timeout = '30s'`. Rejected: requires a per-tier role matrix that complicates the RLS `SET ROLE fabt_app` flow in `RlsDataSourceConfig` (would need per-tenant `SET ROLE`). Chosen: `SET LOCAL statement_timeout = :tenant_timeout_ms` inside every `@Transactional` method entry AFTER `app.tenant_id` is bound (B9). Value sourced from `tenant_rate_limit_config` (E2); fail-safe default when config absent. Same pattern applies to `work_mem`.

### D5 — Rate limit bucket key: pre-auth `(api_key_hash, ip)`, post-auth `(tenant_id, ip)`

Marcus found that the STUB's proposed `(tenant_id, ip)` composite is impossible pre-authentication (tenant is unknown until the API key or JWT is validated). Decision: two-tier rate-limiting per endpoint:
- Unauthenticated / pre-auth endpoints (login, forgot-password, password-change with code, verify-totp, api-key challenge): `(SHA-256(api_key_header_value)[:16], ip)` composite; prevents one attacker from exhausting another tenant's login quota via shared NAT.
- Authenticated / post-auth endpoints: `(tenant_id, ip)` composite once `TenantContext` is bound.

`tenant_rate_limit_config` (E2) provides the per-endpoint-class thresholds per tier.

### D6 — Redis pooling: single-tenant Redis default (ADR documented)

C4 decision: single-tenant Redis deployment is the default and documented stance. Pooled-multi-tenant Redis (shared across tenants) requires Redis ACL per-tenant OR separate logical DBs per tenant — both operationally heavy for 1-engineer team. For regulated-tier pilots, the silo deploy includes its own Redis. For standard-tier pilots on shared backend, Redis is either a single-tenant cache (flush-on-tenant-shutdown) OR not used (Caffeine L1 only); `project_standard_tier_untested.md` stance codified.

### D7 — `TenantScoped<T>` SPI as uniform per-tenant resource accessor

Alex's architectural coherence gate. A single interface through which every per-tenant resource is obtained:

```java
interface TenantScoped<T> {
    T forTenant(UUID tenantId);
    T forCurrent();  // pulls from TenantContext
}
```

Implementations: `TenantScoped<SigningKey>`, `TenantScoped<SecretKey>` (DEK), `TenantScoped<Cache<K,V>>`, `TenantScoped<Bucket>` (rate-limit), `TenantScoped<Duration>` (statement_timeout), `TenantScoped<Tags>` (metrics). Replaces bespoke per-concern tenant plumbing; prevents the "each feature has its own tenant lookup" smell. ArchUnit Family F enforces that per-tenant concerns flow through this SPI or carry a `@TenantUnscopedResource("justification")` annotation.

### D8 — TenantState FSM transitions

```
       create                    suspend                  offboard
NEW -----------> ACTIVE <------------------> SUSPENDED ----------> OFFBOARDING
                    |                                                   |
                    | offboard (direct from active)                     | export-complete
                    v                                                   v
                OFFBOARDING ------> ARCHIVED -----> DELETED <-----------+
                                       ^
                                       | retention-complete (30-day window)
                                       |
```

Allowed transitions:
- `NEW → ACTIVE` (tenant-create workflow, F3)
- `ACTIVE → SUSPENDED` (operator-triggered quarantine, F4)
- `SUSPENDED → ACTIVE` (un-suspend after incident resolution)
- `ACTIVE → OFFBOARDING`, `SUSPENDED → OFFBOARDING` (tenant-requested or policy-triggered)
- `OFFBOARDING → ARCHIVED` (export complete; 30-day retention window begins)
- `ARCHIVED → DELETED` (retention window complete; crypto-shred)

Disallowed: `DELETED → *`, `ARCHIVED → ACTIVE` (re-onboarding is a new tenant create). State-machine test asserts invalid transitions throw.

### D9 — Audit-log hash chain: per-tenant SHA-256, weekly external anchor

G1 decision: each `audit_events` row computes `row_hash = SHA256(prev_tenant_hash || canonical_json(row))`. Per-tenant chain head stored in `tenant_audit_chain_head(tenant_id, last_hash, last_row_id)`. Weekly external anchor: cron job writes the tuple `(tenant_id, last_hash, timestamp)` to an S3 Object Lock bucket (WORM) — provides tamper evidence beyond DB layer. Verification: a scheduled job recomputes the chain and fails if drift detected.

Rejected alternative: full Merkle tree per tenant. Overkill for write-append load; SHA-256 chain is the 2026 state-of-the-art for this class of audit log.

### D10 — Timing-attack on `findByIdAndTenantId`: accept UUID-not-secret

I1 decision: accept the position that FABT resource UUIDs are not secrets. Cross-tenant 404 timing may distinguish "cached miss" (fast) from "DB miss" (slow) but this reveals only that a UUID does or doesn't exist somewhere in the system — it doesn't leak which tenant owns it, doesn't leak data, and the UUIDs are random 128-bit values so enumeration is computationally infeasible. Documented ADR in `docs/security/timing-attack-acceptance.md`. Rejected alternative: fixed sleep floor + random jitter (adds latency to all 404s; user-visible cost outweighs the theoretical risk).

### D11 — Crypto-shred procedure for F6 tenant hard-delete

F6 crypto-shred: destroy the per-tenant DEK (HKDF input row removed from `tenant_key_material` table). Ciphertexts for that tenant become computationally unrecoverable — from live DB, from backups, from replicas. Satisfies GDPR Article 17 + EDPB Feb 2026 erasure-in-backups guidance.

Step-by-step:
1. Verify tenant state is `ARCHIVED` and retention window elapsed.
2. `DELETE FROM tenant_key_material WHERE tenant_id = <uuid>`.
3. `DELETE FROM tenant_audit_chain_head WHERE tenant_id = <uuid>` (audit chain un-verifiable post-shred — expected).
4. `DELETE FROM tenant WHERE id = <uuid>` (cascades via FK).
5. Audit event `TENANT_HARD_DELETED` with actor + justification + UUID shredded.

Documented boundary: audit_events rows with `tenant_id = <shredded_uuid>` may remain in PITR backups within the retention window. Operator runbook states this explicitly; satisfies "proportionate" per EDPB framework.

### D12 — Two-new-tenant branding: `Asheville CoC (demo)` + `Beaufort County CoC (demo)` per Casey

M2 decision (revised 2026-04-18 to cover two new tenants): use two real NC jurisdictions with geographic spread (Western NC + Eastern NC), each with a mandatory `(demo)` suffix in every display surface (login UI, landing page, admin panel header, page title):

- **`dev-coc-west` — "Asheville CoC (demo)"** — Western NC, City of Asheville area. Project-relevant context (Sarah Dickerson / City of Asheville contact) makes Asheville the obvious peer-tenant choice for WNC.
- **`dev-coc-east` — "Beaufort County CoC (demo)"** — Eastern NC, Washington NC county seat. Chosen to demonstrate geographic spread within NC without implying state-capital or Triangle-area partnership context.

Seed uses demonstrably-fictional shelter names ("Example House North"), non-geocodable addresses, persona-derived fake contacts in BOTH tenants. Pre-merge review gate (M8) by Casey confirms branding consistency on each migration (V76 for west, V77 for east); Marcus confirms no real-PII patterns in either; Maria confirms procurement-audience language.

Alternative considered: two fictional city names (e.g., "Riverbend CoC" + "Pine Ridge CoC"). Rejected because real named peer tenants with clear `(demo)` labeling are more demonstrably "real-tenant-shaped" than fictional cities, and using NC jurisdictions keeps the walkthrough grounded in project context.

Alternative considered (2026-04-18 scope expansion): single Asheville tenant. Rejected because two geographically-distinct peer tenants exercise a broader cross-tenant-probe matrix (east↔west, east→core, west→core) as regression guards — and east-west geographic pairing is more legible to procurement than core-vs-peer pairing alone.

### D13 — Partition audit_events + hmis_audit_log by tenant_id (list partitioning)

B8 decision: list-partition the high-write regulated-audit tables by `tenant_id`. Enables: per-tenant backup via partition export, per-tenant VACUUM attribution, per-tenant retention windows (drop-partition-when-expired), better query plans under tenant-RLS. Managed via Flyway migration adding partitions per tenant-create; partition-drop included in tenant hard-delete (F6).

Alternative: range partition by time + tenant_id filter in queries. Rejected: list partitioning by tenant_id is the canonical multi-tenant pattern; combines better with D14 RLS policies.

### D14 — Module-by-module rollout of `TenantScoped<T>` SPI; not retrofit-all-at-once

L1 rollout: introduce `TenantScoped<T>` interface + implementations incrementally as each A–L theme lands. `TenantScoped<SigningKey>` lands with A1; `TenantScoped<SecretKey>` with A3; `TenantScoped<Cache>` with C1; etc. ArchUnit Family F activates progressively (starts with each theme, tightens as more modules adopt). Avoids a big-bang retrofit that would block every other workstream.

## Risks / Trade-offs

- **JWT invalidation outage on first deploy** — existing access tokens (15 min) + refresh tokens (7 days) are invalidated when per-tenant keys activate. All pilots forced to re-login. → **Mitigation:** coordinated notification 48h ahead + logout-banner on the login page for 7 days post-cutover.

- **Ciphertext re-encryption migration window** — two distinct migrations re-encrypt existing secrets, each with a different blast radius:
  - **V59 (Phase 0, this PR's foundation)** — re-encrypts pre-Phase-0 plaintext OAuth2 client secrets and HMIS API keys under the *current single-platform key* (`SecretEncryptionService`). Idempotent (the migration's `looksLikeCiphertext` guard skips already-encrypted rows). Closes the latent A4 plaintext-at-rest exposure on day one.
  - **V74 (Phase A)** — re-encrypts existing `totp_secret_encrypted` + `subscription.callback_secret_encrypted` (and the V59-encrypted OAuth2/HMIS secrets) under the new *per-tenant DEKs* derived via HKDF (D2). Larger blast radius because TOTP verify can fail mid-migration. → **Mitigation for V74:** dual-key-accept grace (old single-platform key + new per-tenant DEK) for 1 week post-migration; TOTP verify tries old key if new fails. **V59 has no such risk** — single-platform key is stable across the run.

- **Postgres ≥ 16.5 pin (B1) may conflict with Oracle Always Free default** — CVE-2024-10976 patch floor is 16.5, but Oracle's standard Postgres image version may lag. → **Mitigation:** verify current Oracle image version before scheduling deploy; if below 16.5, standalone Postgres container from postgres.org official image in docker-compose.

- **`FORCE ROW LEVEL SECURITY` (B3) affects every admin migration** — migrations running as `fabt` owner previously bypassed RLS. Post-B3, any Flyway migration that does UPDATE/DELETE on a force-RLS table needs `SET LOCAL app.tenant_id = '...'` or explicit `SET LOCAL row_security = off` (requires superuser). → **Mitigation:** migration style rule in `L3` (Flyway `@tenant-safe` or `@tenant-destructive` tag); review gate at PR level.

- **Crypto-shredding is irreversible** (F6/D11) — a hard-deleted tenant cannot be restored from backup (ciphertexts are unrecoverable). → **Mitigation:** 30-day archival state (F1 FSM) before hard-delete; operator confirms via break-glass command; audit event trails the decision.

- **Per-tenant `statement_timeout` could surprise tenants** (B9) — a tenant tier change from "pro" (30s) to "free" (5s) could cause previously-successful queries to fail. → **Mitigation:** tier changes audited; tenant-facing documentation explicit.

- **Audit hash chain becomes un-verifiable after crypto-shred** (D9/D11) — once a tenant is hard-deleted, the weekly external anchor for that tenant's chain is a historical artifact; future recomputation fails. → **Mitigation:** document explicitly; the last anchor before shred is the final integrity proof.

- **Real-jurisdiction branding confusion risk** (M2) — even with `(demo)` suffix, a demo visitor may momentarily think "wait, is FABT actually deployed in Asheville / Beaufort County?" → **Mitigation:** Casey's pre-merge review of every copy-written surface in BOTH new tenants; FAQ entry on landing page explicitly disclaiming both; explicit disclaimer in login UI. Risk multiplied by two tenants but mitigation is symmetric.

- **Demo-site cross-tenant drill frequency (M10/M11)** — quarterly operator drills on `dev-coc-west` OR `dev-coc-east` (rotating per quarter) require someone to run them. For a 1-engineer team, this is meaningful ops overhead — and doubling the tenant count does NOT double the drill count because the two new tenants share the drill rotation. → **Mitigation:** automate drills into a nightly or weekly cron once validated manually; Grafana panel (M7) exposes freshness; rotate target tenant so both exercise their lifecycle across a year.

- **Effort estimate optimistic under distraction** — 13–19 weeks assumes focused 1-2 engineer capacity. Interleaving with other roadmap items (Darius native app, MCP integration, Teresa procurement conversations) could extend to 26+ weeks calendar. → **Mitigation:** sequence A–F as the critical path (cryptographic + DB + lifecycle); G–L + M run in parallel where possible; defer nothing but re-negotiate calendar if other priorities surface.

- **VAWA Comparable Database architecture (H4) changes the ops trust model** — if platform operators cannot read DV survivor PII, then diagnostic operations on DV-tenant issues become harder. → **Mitigation:** `platform_admin_access_log` (G3) with audited unseal procedure; Casey + Marcus-reviewed break-glass command with justification string and tenant admin notification.

## Migration Plan

### Phase order (critical path: A4 → A1–A3 → B → C → D → E → F → G → H → I → J → K → L → M)

1. **A4 — Encrypt OAuth2 + HMIS credentials NOW** (latent fix). First PR of the change. Zero dependencies. Closes the immediate plaintext-in-DB exposure.

2. **A1–A3, A5–A7 — Per-tenant key derivation + JWT + DEK** (~2 weeks). `SecretEncryptionService` refactor, `JwtService` refactor, `tenant_key_material` + `kid_to_tenant_key` tables, HKDF derivation + opaque kid + rotation support. V73 re-encrypt migration. Coordinated re-login window begins.

3. **B1–B13 — DB-layer hardening** (~2 weeks). Postgres 16.5 floor enforcement, V66 D14 RLS policies, V67 LEAKPROOF function, V68 FORCE RLS, V69 indexes, V70 partitioning, V71 REVOKE UPDATE/DELETE, V72 pgaudit. Each step validated by existing + new integration tests.

4. **C1–C6 — Cache isolation** (~1 week). `TenantScopedCacheService`, ArchUnit Family C, EscalationPolicyService composite key fix, Redis ADR.

5. **D1–D4 — Control-plane hardening** (~1 week). Deferred URL-path-sink sibling controllers, `TenantConfigController` stricter validation, nginx tenant-header rewrite. mTLS for regulated tier optional in this phase.

6. **E1–E8 — Operational boundaries** (~2 weeks). `tenant_rate_limit_config` table, per-tenant rate limit, SSE buffer shard, fair-queue dispatch, virtual-thread guard, scheduled-task metrics.

7. **F1–F8 — Tenant lifecycle FSM** (~2 weeks). `TenantState` enum, `TenantLifecycleService`, create/suspend/offboard/delete workflows, `findByIdAndActiveTenantId` pattern, crypto-shred procedure.

8. **G1–G9 — Audit + observability isolation** (~1 week). Hash chain + external anchor, REVOKE on audit tables, `platform_admin_access_log`, OTel baggage, per-tenant alert routing.

9. **H1–H11 — Compliance documentation** (~2 weeks, Casey review loops). Tenancy-model ADR, BAA template, VAWA pipeline, data-custody matrix, right-to-be-forgotten, children/FERPA carve-out.

10. **I1–I6 — Defense-in-depth** (~1 week). Inbound webhook signing, actuator authz, session binding, egress allowlist, delivery-time re-validation.

11. **J1–J20 — Testing + validation** (~2 weeks, interleaved with earlier phases). Most J items implemented as each theme lands; final integration coverage + pre-prod pentest at end.

12. **K1–K3 — Breach response** (~1 week). Quarantine break-glass, forensic query tooling, IR runbooks.

13. **L1–L10 — Developer guardrails** (~1–2 weeks). `TenantScoped<T>` SPI rolled out progressively across phases 2–8; module boundary ArchUnit, typed config, typed feature flags, stage environment, DR drill, cost allocation, rotation runbooks consolidated at end.

14. **M1–M11 — Demo-site multi-tenant validation** (~1 week, AFTER F ships). V76 `dev-coc-west` / Asheville seed, V77 `dev-coc-east` / Beaufort County seed, three-tenant UI indicator with distinct accent colors, educational 404 envelope, post-deploy smoke all-tenant coverage (minimum 3-probe rotation across the 6-pair matrix), walkthrough doc covering all three tenants, tenant-pair validation Grafana panel. **Change-closure gate: `opsx:archive` blocked until M validated on live `findabed.org` for all three tenants.**

### Rollback strategy

- **Per-phase rollback** — each phase ships as an independently-deployable set of commits + migrations + integration tests. A failed phase can be reverted without affecting prior-phase gains.
- **Migration rollbacks** — destructive migrations (V70/V72 REVOKE, V74 re-encrypt, V76 `dev-coc-west` seed, V77 `dev-coc-east` seed) have pre-deploy dry-runs on throwaway DB. Destructive operations (F6 hard-delete) have 30-day archival pause.
- **Key-rotation rollback** — if per-tenant JWT rotation destabilizes, fallback to dual-sign mode (old + new keys) until issue resolved.
- **Demo-site rollback** — if either new-tenant seed breaks the live demo, migrations are idempotent + reversible (DELETE rows for the affected tenant + redeploy without that tenant's V76/V77). V76 and V77 are independent: one can land + bake before the other.

### Coordination

- Pilot notification 48h ahead of any JWT-rotation deploy window.
- Weekly progress updates via GitHub issue comments on the companion tracking issue.
- Casey review loops scheduled at phase boundaries for H1–H11 compliance artifacts.
- Marcus review loops at phase 2 (crypto), phase 5 (control-plane), phase 11 (testing sign-off), phase 14 (demo-seed branding).

## Open Questions

1. **Q: `FABT_ENCRYPTION_KEY` env var (the Phase 0 master KEK) for standard tier — acceptable under HIPAA BAA for a regulated pilot that doesn't need full Vault?** — Casey to advise. If `No`, regulated tier deploy MUST use Vault Transit (D3).

2. **Q: Asheville tenant — keep name as "Asheville CoC (demo)" or rename to fictional city pre-merge?** — **RESOLVED 2026-04-18 (Corey):** keep Asheville, and add a second real-NC-jurisdiction tenant "Beaufort County CoC (demo)" with slug `dev-coc-east`. Asheville tenant slug becomes `dev-coc-west` (geographic positioning explicit in slug). Both tenants carry mandatory `(demo)` suffix per D12.

3. **Q: Crypto-shred verification test — can we assert ciphertext is unrecoverable without exposing the KEK in test?** — D11 test design; resolve in F6 implementation PR.

4. **Q: Per-tenant statement_timeout defaults for each tier** — E2 `tenant_rate_limit_config` row defaults. Tenant tier matrix (free / pro / enterprise) undefined; suggest 5s / 30s / 120s but validate with Gatling benchmarks (J19).

5. **Q: External anchor location for audit hash chain (D9)** — S3 Object Lock is mentioned but Oracle Always Free deployment has no S3. Alternatives: OCI Object Storage with WORM retention, append-only file on separate-volume disk, third-party log service (Datadog, Splunk). Resolve in G1 implementation.

6. **Q: Tenant-specific CSP / CORS headers** — if regulated-tier tenants have different domains (`fabt-coc-a.example.gov`), CSP + CORS headers need per-tenant origin handling. Scope for a follow-up change or add to D (control-plane)? Decide before D phase starts.

7. **Q: Observability per-tenant read access (G9) scope for regulated tier** — deferred to regulated tier in the proposal. If first pilot is regulated, accelerate into this change; if standard first, keep deferred.

8. **Q: Breach simulation tests (J7) — 15+ attack vectors require a synthetic "attacker tenant"** — use `dev-coc-west` OR `dev-coc-east` as the attacker tenant (operator-selectable per simulation), or spin up a fourth synthetic test-only tenant for isolation? Decide in J7 implementation. The two new demo tenants now provide symmetric east-west pairing which J7 can exploit.

9. **Q: Can K1 tenant-quarantine break-glass trigger ALL 5 atomic actions in a single transaction?** — `jwt_key_generation++`, API key disable, worker-stop, state-change, audit — some are cross-service. Design K1 as a saga or a coordinated-script? Resolve in K1 PR.

10. **Q: Training walkthrough (M6) — hosted on `findabed.org` as a standalone page or just linked as docs/?** — Devon persona input. Preferred: hosted static page + videoed screen-capture walkthrough. Budget-dependent.
