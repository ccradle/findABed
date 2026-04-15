## Why

Companion change to `cross-tenant-isolation-audit` (Issue #117). That audit closes the LIVE VULN-HIGH vulnerabilities (`findById`, URL-path-sink, `audit_events` cross-tenant read, SSRF in webhook/OAuth2/HMIS URLs) and installs mechanical guards (ArchUnit Family A+B, `TenantPredicateCoverageTest`, `SafeOutboundUrlValidator`, `@TenantUnscoped` annotations, `app.tenant_id` session variable as defense-in-depth infrastructure).

This change completes the posture shift from **"per-town dedicated instance is safe"** to **"multiple towns can pool safely on one shared instance"** — by closing the architectural gaps the audit identified but deferred: per-tenant JWT signing keys, tenant-scoped caches, tenant-scoped RLS on regulated tables, per-tenant operational boundaries (rate limit, pool budget, SSE buffer sharding), and an audit of file/blob storage and the deferred URL-path-sink sibling controllers.

**This is the change that answers a multi-tenant procurement security review.** Without it, Corey's honest answer to a town is "pool with other towns once this lands; today, take a dedicated instance." With it, pooling is the default recommendation.

## What Changes

### Per-tenant JWT signing keys (J class)

- Replace single platform-wide HMAC-SHA256 secret with HKDF-derived per-tenant signing keys rooted in a platform master key.
- `JwtService.sign` uses the caller's tenant key; `JwtService.validate` derives the key from the token's `kid` claim (which encodes `tenant:<uuid>`).
- Key rotation: per-tenant rotation becomes trivial; platform master key rotation is a defined operational procedure.
- Compromise scope: a tenant's leaked key no longer forges other tenants' tokens.

### Per-tenant encryption DEKs for data-at-rest (J class)

- `SecretEncryptionService` currently uses one platform `FABT_ENCRYPTION_KEY` for TOTP secrets and webhook callback secrets across all tenants.
- HKDF-derive per-tenant DEKs from the platform KEK; store `kid=tenant:<uuid>` next to ciphertext.
- Rotation scoped to one tenant at a time.

### `TenantScopedCacheService` wrapper (D class)

- `TieredCacheService` currently takes arbitrary string keys — no mechanical tenant-in-key enforcement.
- Add `TenantScopedCacheService` that prepends `TenantContext.getTenantId()` to every key.
- ArchUnit rule: direct `TieredCacheService.get/put` calls on tenant-sensitive caches require `@TenantUnscopedCache("justification")` annotation; otherwise the caller must go through `TenantScopedCacheService`.
- Audit `EscalationPolicyService.policyById` — change key to `(tenantId, id)` composite to eliminate residual cache-bleed exposure.

### Tenant-scoped RLS on regulated tables (D14 realization)

- Leverages `app.tenant_id` session variable installed in the cross-tenant-isolation-audit Phase 4.8.
- Add RLS policies to: `audit_events`, `hmis_audit_log`. Possibly `one_time_access_code` and `hmis_outbox` — decide in design.
- Policy shape: `USING (tenant_id::text = current_setting('app.tenant_id', true))`. Platform-admin role exempted.
- Service-layer guard stays primary; RLS is DB-layer defense-in-depth for regulated data.

### Deferred URL-path-sink sibling controllers (B class)

- `TenantController PUT /{id}/*` — verify if COC_ADMIN can reach; if yes, apply D11 pattern.
- `TenantConfigController.updateConfig` — same.
- `OAuth2ProviderController.list` read-side enumeration — filter by caller tenant or 404 on URL-path mismatch.

### Per-tenant rate limiting (L class)

- `ApiKeyAuthenticationFilter` rate-limit buckets currently keyed per-IP only. One tenant's noisy IP (shared NAT, Tor exit) can throttle another tenant's users.
- Shard buckets by `(tenant_id, ip)` composite key.
- New per-tenant rate-limit configuration in `tenant_config` table.

### Per-tenant Hikari connection budget (Jordan)

- Default HikariCP pool is single shared. One tenant's slow query starves others.
- Two options: (a) per-tenant sub-pool via DataSource wrapper, (b) per-tenant `statement_timeout` via `SET LOCAL` keyed on `app.tenant_id`. Option (b) is lighter-weight; decide in design.

### SSE event buffer sharding (P class, new finding)

- Global `NotificationService.eventBuffer` deque is shared across all tenants.
- One tenant's high-volume events can evict another tenant's buffered events (and in the extreme, OOM the JVM).
- Shard buffer per-tenant with per-tenant cap.

### File / blob storage audit (H class)

- Dedicated audit of every file-write path: `ImportController` (CSV upload), `HicPitExportService` (export generation), `HmisPushService` (payload serialization), attachment paths if any.
- Verify all paths are tenant-isolated (filename includes tenant hash, directory structure includes tenant, S3 prefix includes tenant, etc.).
- Fix any shared-path findings; add regression tests.

### Per-tenant backup + restore runbook (Jordan)

- Current Postgres PITR restores whole DB; cannot restore one tenant's state without touching others.
- Document either (a) per-tenant logical backup via `pg_dump --where="tenant_id = '<uuid>'"` OR (b) schema-per-tenant alternative for regulated pilots.
- This is primarily an operational / documentation deliverable, not code.

### Breach notification boundaries + data-custody documentation (Casey)

- For each data class (DV referrals, shelter ops, analytics, audit), document: data custodian per tenant, breach-notification recipient per tenant, retention policy per tenant.
- Required for HIPAA BAA and VAWA compliance reviews.

## Capabilities

### New Capabilities

- `per-tenant-key-derivation`: covers HKDF JWT + encryption DEK derivation, kid handling, rotation procedure
- `tenant-scoped-cache`: covers `TenantScopedCacheService`, caching conventions, ArchUnit guard
- `tenant-rls-regulated-tables`: covers the narrow D14 carve-out (audit_events, hmis_audit_log)
- `per-tenant-operational-boundaries`: rate limit, pool budget, SSE buffer shard, backup/restore

### Modified Capabilities

- `multi-tenancy` — adds per-tenant key, per-tenant budgets, breach-notification scope requirements
- `rls-enforcement` — adds tenant-RLS on regulated tables (D14)
- `cross-tenant-isolation-test` — adds test coverage for cache bleed, file-path isolation, per-tenant rate limit

## Impact

- **Affected code paths:** JwtService, SecretEncryptionService, TieredCacheService, RlsDataSourceConfig, ApiKeyAuthenticationFilter, NotificationService, TenantController, TenantConfigController, OAuth2ProviderController, import/export services, operational runbook.
- **Breaking changes:** existing JWTs invalidated on first deploy (per-tenant key rotation). Requires coordinated re-login window for pilots. SSE reconnect on deploy (already required today).
- **Migrations:** new tenant-RLS policies on `audit_events` and `hmis_audit_log`. New `tenant_rate_limit_config` table if per-tenant rate limit config is selected.
- **Deploy footprint:** coordinated: logout-and-reissue banner for pilots; ~2-week calendar for engineering + 1-2 weeks rollout.
- **Effort:** ~30-40 engineering days + 10-15 testing days = 8-10 weeks calendar with 1-2 engineers.
- **Prerequisite:** `cross-tenant-isolation-audit` must be merged and deployed first. This change extends that audit's infrastructure (especially `app.tenant_id` session variable from Phase 4.8, `@TenantUnscoped` from Phase 1, `SafeOutboundUrlValidator` from Phase 2.14).
- **Non-scope:** schema-per-tenant or DB-per-tenant architectural change. That would be a separate proposal; this change stays with the discriminator-column + RLS hybrid that FABT uses today.

## Status

**STUB — scoping in progress.** Filed 2026-04-15 as the companion deferred-items tracker for `cross-tenant-isolation-audit`. Full proposal / design / specs / tasks artifacts will be authored once that audit is merged. This stub exists so the deferred items do not get lost.
