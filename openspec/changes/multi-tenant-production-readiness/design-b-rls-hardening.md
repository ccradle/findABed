# Design: Phase B — Database-layer hardening (RLS + FORCE RLS + pgaudit)

**Change:** multi-tenant-production-readiness
**Phase:** B (tasks 3.1–3.25 + 3.26 retroactive V74 amendment)
**Status:** APPROVED v2 — confirmation warroom PASSED 2026-04-17 (Marcus + Jordan + Sam all approve for implementation). Q2 + Q4 resolved post-confirmation. Ready for implementation.
**Author:** Corey (v1 drafted 2026-04-17 post-A5 merge; v2 rewrite 2026-04-17 post-warroom)
**Migrations:** V67–V73 (V62–V66 reserved for Phase E; V74 is Phase A5)

---

## v1 → v2 rewrite summary

Three-persona warroom on v1 surfaced **16 critical items** — 10 correctness (including 4 Postgres-semantics errors) and 6 operational. v2 incorporates all 16. Major deltas:

- **D44 corrected** — `FOR ALL USING` implicitly uses USING as WITH CHECK (Postgres 17 doc). v1's "INSERT allows any tenant_id" rationale was factually wrong. v2 writes explicit WITH CHECK for clarity either way.
- **D45 corrected** — RESTRICTIVE-only policies without PERMISSIVE companions DENY the command. v1's kid table policies would have broken all INSERT/UPDATE/DELETE. v2 adds PERMISSIVE-per-command companions.
- **D50 removed** — `SET LOCAL` at pool-borrow under `autoCommit=true` is a no-op. v1 B9 defaults-only plan can't work. v2 defers B9 entirely to Phase E (unblocks when `tenant_rate_limit_config` lands).
- **D49 corrected** — pgaudit is NOT in `postgres:16-alpine`. v1 claim was factually wrong (we self-host on Oracle VM with that image, not Oracle Managed Postgres). v2 mandates image swap.
- **D46 hardened** — V74 amendment uses parameterized `set_config($1, true)` via PreparedStatement (not `SET LOCAL` string interpolation which is injection-exposed + silently no-ops under autoCommit).
- **D55 replaced** — SYSTEM_TENANT_UUID sentinel instead of NULL-tenant-id audit_events policy. Closes forensic-evasion bypass.
- **NEW D59-D64** — prepared-statement plan verification, Phase F gap mitigation, panic script, Micrometer coverage, pgaudit `log_parameter='off'`, PG ≥16.6 pin.

---

## 1. Purpose (unchanged from v1)

Phase B adds a **database-enforced backstop** under the application-layer tenant scoping shipped in Phases 0 + A + A5. App-layer defenses (`@TenantUnscoped`, `findByIdAndTenantId`, per-tenant DEKs, per-tenant JWT keys) all live in Java. A missing `WHERE tenant_id = ?`, a raw SQL path in a migration, or a direct DB edit bypasses them. Phase B makes Postgres itself reject the cross-tenant read/write at the row level, FORCE-enforced so even owner sessions can't bypass.

---

## 2. Current state (confirmed 2026-04-17)

| Thing | Where it already exists |
|-------|-------------------------|
| `app.tenant_id` session variable set on every connection borrow via `set_config('app.tenant_id', ?, false)` (session-scoped) | `RlsDataSourceConfig.RlsAwareDataSource.applyRlsContext` |
| `SET ROLE fabt_app` at pool-borrow | Same config; closes Testcontainers superuser-bypass-RLS gap |
| `audit_events.tenant_id` column + backfill + index | V57 (v0.40 cross-tenant-isolation-audit Phase 2.12) |
| FORCE RLS pattern precedent on `shelter` (dv_access) | V8, V8_1, V13, V15, V19, V35, V38 |
| `TenantContext` uses ScopedValue (Java 25 JEP 506) | `TenantContext.java` |
| `TenantContext` bound at HTTP filter boundary AFTER `JwtAuthenticationFilter` | `TenantContextFilter` (chicken-and-egg source) |
| **Postgres deployment: `postgres:16-alpine` on Oracle Always Free VM** (self-managed Docker, NOT Oracle Managed Postgres) | `docker-compose.yml` |
| Tenant-owned regulated tables lacking RLS today | `audit_events` (col but no policy), `hmis_audit_log`, `password_reset_token`, `one_time_access_code`, `totp_recovery`, `hmis_outbox`, `tenant_key_material` (V61 deferred), `kid_to_tenant_key` (V61 deferred) |

`app.tenant_id` source-of-truth note: `RlsDataSourceConfig:107` stores `""` (empty string) when unset, not NULL. Both `set_config(..., '', false)` and `set_config(..., null, false)` with null-handling normalize through `NULLIF(...,'')`. v2 policies use `fabt_current_tenant_id()` which normalizes both.

---

## 3. Decisions (D43–D64, revised)

### D43 — `fabt_current_tenant_id()` function (v2: CASE-guarded, operator-asserted LEAKPROOF lie documented)

```sql
CREATE OR REPLACE FUNCTION fabt_current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
LEAKPROOF
PARALLEL SAFE
AS $$
  SELECT CASE
    WHEN current_setting('app.tenant_id', true) IS NULL THEN NULL::uuid
    WHEN current_setting('app.tenant_id', true) = '' THEN NULL::uuid
    WHEN current_setting('app.tenant_id', true) !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN NULL::uuid
    ELSE current_setting('app.tenant_id', true)::uuid
  END
$$;

COMMENT ON FUNCTION fabt_current_tenant_id() IS
  'Returns the current session tenant UUID, or NULL if unset/malformed. '
  'Operator-asserted LEAKPROOF per design-b-rls-hardening D43: the regex-'
  'guarded CASE statement prevents the ::uuid cast from throwing on '
  'malformed input, which would otherwise make the function NOT truly '
  'LEAKPROOF (functions that throw can leak via error-path timing). '
  'The app.tenant_id GUC is only written by RlsDataSourceConfig with a '
  'validated UUID or empty string — the regex is belt-and-suspenders.';
```

Per Jordan + Marcus: a naïve `NULLIF(..., '')::uuid` throws on garbage input. Throwing functions are NOT true-LEAKPROOF in the strict sense (Postgres 17 §40 RLS docs: functions "used in RLS expressions should be marked LEAKPROOF, meaning they don't leak information through side channels including error messages or timing"). The CASE-guarded regex normalizes three branches (NULL / empty / malformed / valid) before the cast, so the function cannot throw.

`PARALLEL SAFE` added per Jordan — without it, parallel query plans won't use the function and `audit_events` scans regress.

Validator test:

```sql
SELECT proleakproof, provolatile, proparallel
FROM pg_proc WHERE proname = 'fabt_current_tenant_id';
-- Expect: t, s, s
```

Integration test asserts the function returns NULL for the three sad paths + valid UUID for the happy path.

### D44 — Policy shape: explicit `USING` AND `WITH CHECK` (v2: corrected)

**v1 error:** author claimed `FOR ALL USING` leaves INSERT ungated. **Actually:** per Postgres 17 docs, when `WITH CHECK` is omitted, `USING` is used as the default `WITH CHECK`. So `FOR ALL USING (tenant_id = fabt_current_tenant_id())` DOES gate INSERT.

**v2 decision:** write `USING` AND `WITH CHECK` explicitly for every policy, with identical expressions on non-kid tables. Four reasons:

1. Eliminates surprise for future readers (no "does this gate INSERT? let me grep the Postgres docs")
2. pg_policies snapshot diffs are unambiguous
3. Defense-in-depth against a rogue service method hardcoding a foreign tenant_id at INSERT (Marcus Q1, Sam C-B-N2)
4. If future migrations ever need the USING vs WITH CHECK asymmetry, the shape is already two-expr

Canonical policy:

```sql
CREATE POLICY tenant_isolation_<table> ON <table>
    FOR ALL
    USING (tenant_id = fabt_current_tenant_id())
    WITH CHECK (tenant_id = fabt_current_tenant_id());
```

### D45 — Kid table chicken-and-egg: PERMISSIVE-per-command + RESTRICTIVE WRITE (v2: PERMISSIVE companions fixed)

**v1 error:** v1 listed RESTRICTIVE-only INSERT/UPDATE/DELETE policies on `kid_to_tenant_key`. **Actually:** Postgres RLS requires ≥1 PERMISSIVE policy per command OR the command is denied outright (restrictive alone can't authorize; it can only narrow the permissive set).

**v2 correct shape:**

```sql
-- tenant_key_material and kid_to_tenant_key both use this pattern
-- (JWT validate reads these BEFORE TenantContext is bound)

-- PERMISSIVE read: allow all authenticated sessions to resolve a kid.
-- Safe because the kid is a 128-bit opaque random UUID (no enumerable
-- tenant leak) AND the write-side is restrictive.
CREATE POLICY kid_select_all ON kid_to_tenant_key
    FOR SELECT USING (true);

-- PERMISSIVE write companions (required for Postgres to even consider
-- the RESTRICTIVE policy). USING/WITH CHECK true means "passes the
-- permissive check" — the real enforcement is the RESTRICTIVE policy.
CREATE POLICY kid_insert_permissive ON kid_to_tenant_key
    FOR INSERT WITH CHECK (true);
CREATE POLICY kid_update_permissive ON kid_to_tenant_key
    FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY kid_delete_permissive ON kid_to_tenant_key
    FOR DELETE USING (true);

-- RESTRICTIVE: the actual tenant-scoping on writes. ANDed with the
-- permissive above = only writes where tenant_id matches current
-- session survive.
CREATE POLICY kid_write_tenant_restrictive ON kid_to_tenant_key
    AS RESTRICTIVE
    FOR INSERT WITH CHECK (tenant_id = fabt_current_tenant_id());
CREATE POLICY kid_update_tenant_restrictive ON kid_to_tenant_key
    AS RESTRICTIVE
    FOR UPDATE USING (tenant_id = fabt_current_tenant_id())
    WITH CHECK (tenant_id = fabt_current_tenant_id());
CREATE POLICY kid_delete_tenant_restrictive ON kid_to_tenant_key
    AS RESTRICTIVE
    FOR DELETE USING (tenant_id = fabt_current_tenant_id());
```

Same shape for `tenant_key_material`. Eight policies per kid table × 2 tables = 16 policies; non-kid tables stay at 1 policy each (FOR ALL) = 6 policies. Total = 22 policies (was ~40 in v1 per-command split; reverted per Jordan's "D47 FOR ALL default" guidance).

**CI invariant:** a Postgres-side assertion post-migration verifies every (table, cmd) pair has ≥1 PERMISSIVE policy:

```sql
-- Fails Phase B IT if any regulated table has a RESTRICTIVE-only cmd
WITH regulated_tables AS (
    SELECT unnest(ARRAY['audit_events', 'hmis_audit_log', 'password_reset_token',
                        'one_time_access_code', 'totp_recovery', 'hmis_outbox',
                        'tenant_key_material', 'kid_to_tenant_key']) AS t
), cmds AS (
    SELECT unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE']) AS c
), needed AS (
    SELECT rt.t AS tbl, cmds.c AS cmd FROM regulated_tables rt CROSS JOIN cmds
), have_permissive AS (
    SELECT tablename AS tbl,
           CASE WHEN cmd = '*' THEN 'ALL' ELSE cmd END AS cmd
    FROM pg_policies WHERE permissive = 'PERMISSIVE'
)
SELECT needed.tbl, needed.cmd FROM needed
LEFT JOIN have_permissive hp
  ON hp.tbl = needed.tbl
  AND (hp.cmd = needed.cmd OR hp.cmd = 'ALL')
WHERE hp.tbl IS NULL;
-- Must return 0 rows
```

### D46 — V74 re-run amendment: parameterized `set_config` (v2: injection-safe + autoCommit-verified)

**v1 error:** v1 proposed `SET LOCAL app.tenant_id = '<uuid>'` as a string-concatenated statement. Marcus flagged SQL injection if tenant_id ever came from untrusted source. Jordan flagged `SET LOCAL` silently no-ops under autoCommit=true.

**v2 correct form:**

```java
// V74 amendment: executed once per row before the UPDATE.
// Uses set_config() with bind parameter so tenant_id is never string-
// concatenated into SQL. `true` (is_local) scopes to current tx.
try (PreparedStatement ps = conn.prepareStatement(
        "SELECT set_config('app.tenant_id', ?, true)")) {
    ps.setString(1, tenantId.toString());
    ps.execute();
}

// UPDATE follows...
```

AND a hard assertion at the top of `migrate()`:

```java
if (conn.getAutoCommit()) {
    throw new IllegalStateException(
            "V74 amendment requires autoCommit=false — Flyway must wrap this migration "
            + "in a transaction for SET LOCAL / is_local=true semantics to take effect.");
}
```

Task 3.26 added to Phase B scope (PR companion). V74 is amended, not re-created (it has already run on dev; the amendment only affects re-run scenarios per Phase A5 C-A5-N9).

### D47 — `FOR ALL USING...WITH CHECK` as default; split only where asymmetric (v2: reverted per Jordan)

**v1 chose per-command split.** Jordan: "every SPLIT that omits a permissive companion for a given command is a silent denial. FOR ALL can't forget a command." v2 reverts: 6 non-kid tables use one `FOR ALL` policy each. Kid tables still need per-command split because USING and WITH CHECK differ (PERMISSIVE SELECT vs RESTRICTIVE WRITE).

### D48 — Partition rewrite with size guard (v2: year-1-scale abort)

v1 decided rewrite-and-rename. v2 keeps it, adds a **size guard** per Jordan/Sam:

```java
// V71 pre-flight
long auditEventsSize = queryForLong(
        "SELECT pg_total_relation_size('audit_events')");
if (auditEventsSize > 500 * 1024 * 1024) {  // 500 MB
    throw new FlywayException(
        "V71 aborted: audit_events is " + (auditEventsSize / 1024 / 1024) + " MB. "
        + "Partition-rewrite-in-single-transaction unsafe above 500 MB at pilot "
        + "infrastructure scale. Run scripts/phase-b-partition-split.sh during a "
        + "declared maintenance window instead. See runbook Phase B rollback §partition.");
}
```

At pilot scale (today ~1-10k rows, ~1 MB) this never trips. When it would trip (year-1, ~1.8M rows), operators get a loud abort with a pointer to the maintenance-window script. Phase B ships without that script; Phase F can add it when tenant-create hook lands.

**Partition key note (Jordan W-B-2):** partitioned tables in Postgres require the partition key in every UNIQUE/PRIMARY KEY constraint. `audit_events` currently has PK on `id`. V71 rewrites PK to `(tenant_id, id)`. Confirm no FK references `audit_events.id` (spoiler: there are none — audit_events is a leaf table).

**Index re-creation (Jordan W-B-3):** V71 explicitly recreates `idx_audit_events_tenant_target` on the new partitioned parent; indexes don't auto-transfer from heap to partition.

### D49 — pgaudit: image swap mandatory (v2: postgres:16-alpine doesn't ship it)

**v1 error:** v1 claimed postgres:16-alpine ships pgaudit. **Sam confirmed:** it does NOT. The alpine image is core + contrib only; pgaudit is a separate C extension (not contrib-bundled).

**v2 decision: image swap.** v0.43 deploy switches from `postgres:16-alpine` to `postgres:16` (Debian) + `apt-get install postgresql-16-pgaudit` layered via a custom Dockerfile, OR swap to the community pgaudit-bundled image `pgvector/pgvector:pg16` (which happens to bundle pgaudit alongside vector support) — to be confirmed via image audit during implementation.

```dockerfile
# deploy/pgaudit.Dockerfile
FROM postgres:16
RUN apt-get update && apt-get install -y postgresql-16-pgaudit && rm -rf /var/lib/apt/lists/*

# postgresql.conf additions (via /etc/postgresql/postgresql.conf or ALTER SYSTEM):
#   shared_preload_libraries = 'pgaudit'
#   pgaudit.log = 'write,ddl'
#   pgaudit.log_level = 'log'
#   pgaudit.log_parameter = 'off'  (D63 — disable to prevent secret leakage)
```

**D49 sub-decisions:**
- pgaudit preload config (`shared_preload_libraries = 'pgaudit'`) required in `postgresql.conf` + DB restart. Cannot be set via `ALTER DATABASE` — Jordan-confirmed. V73 Flyway migration documents this as a prerequisite and only sets per-session / per-database knobs that complement the preload.
- If image swap blocks the deploy (e.g., data-directory incompat), fall back path: ship Phase B without pgaudit, document the gap honestly in `docs/security/compliance-posture-matrix.md` — NOT "equivalence"; the honest word is "gap, standard tier, pgaudit available on regulated tier".

### D50 — SET LOCAL per-tx timeout plumbing REMOVED from Phase B (v2: deferred to Phase E)

**v1 proposed** ship B9 defaults-only. **Jordan confirmed** `SET LOCAL` at pool-borrow under HikariCP autoCommit=true is a silent no-op. v2 DELETES B9 from Phase B entirely.

**When B9 ships (Phase E):** `tenant_rate_limit_config` table lands; per-tenant values are applied via an `@Transactional`-entry Spring AOP aspect that runs AFTER connection borrow + transaction open, within a tx. Not Phase B's problem.

Tasks 3.15 + 3.16 move from Phase B to Phase E task list.

### D51 — pg_policies snapshot with hash + CODEOWNERS (v2: Marcus hash-pinning + Sam CODEOWNERS + weekly drift)

v2 expands the snapshot to capture GRANTs + table attributes (Marcus W-B-N7: grep the extended output catches rogue `GRANT ALL TO PUBLIC` migrations):

```sql
-- docs/security/pg-policies-snapshot.md header
-- CONTENTS: (policies | grants | force_rls_flags | security_definer_functions)

-- Section 1 — pg_policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname = 'public'
ORDER BY tablename, cmd, policyname;

-- Section 2 — GRANTs on regulated tables
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('audit_events', 'hmis_audit_log', 'password_reset_token',
                     'one_time_access_code', 'totp_recovery', 'hmis_outbox',
                     'tenant_key_material', 'kid_to_tenant_key')
ORDER BY table_name, grantee, privilege_type;

-- Section 3 — FORCE RLS flags
SELECT relname, relforcerowsecurity, relrowsecurity
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND relrowsecurity = true
ORDER BY relname;

-- Section 4 — SECURITY DEFINER functions
SELECT proname, prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND prosecdef = true;
-- Expect: 0 rows (D52 governance)
```

Snapshot file header:
```markdown
# pg_policies snapshot (Phase B+)

SHA-256 of raw query output: <hash>
Last reviewed: 2026-04-17
Review cadence: quarterly + on every migration touching policies
```

**CI checks:**
1. On every PR modifying `backend/src/main/resources/db/migration/V*`, verify the snapshot file is also touched. CI fails otherwise.
2. On every PR, run the query against fresh Testcontainers Postgres, compute SHA-256, diff against file's header hash. Fails on drift.
3. Weekly scheduled CI job runs against main + opens an issue on drift (catches merged-without-snapshot-update).

`.github/CODEOWNERS` adds:
```
/docs/security/pg-policies-snapshot.md  @corey-cradle @marcus-webb @jordan-db-lead
```

### D52 — SECURITY DEFINER governance (v2: Postgres-side check, not grep)

**Marcus W-B-N:** `grep` for `SECURITY DEFINER` is evadable (case, whitespace, split-line). v2 adds a Postgres-side check (included in D51 snapshot section 4):

```sql
SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND prosecdef = true;
```

Snapshot section 4 must be empty (0 rows). If a future migration needs `SECURITY DEFINER`, the PR MUST include the snapshot delta + `@security-definer-exception: <justification>` header on the migration. Snapshot + header are reviewed by a security CODEOWNER.

### D53 — B11 ArchUnit rule (unchanged from v1)

### D54 — Owner-bypass test (v2: also check NOT rolsuper per Marcus W-B-N3)

```java
@Test
void fabt_role_is_not_superuser_and_not_bypassrls() {
    jdbc.queryForObject(
        "SELECT (NOT rolsuper AND NOT rolbypassrls) FROM pg_roles WHERE rolname = ?",
        Boolean.class, "fabt_app");
    // Also for fabt (owner)
    ...
}

@Test
void owner_cannot_update_other_tenants_audit_events_under_FORCE_RLS() {
    // As fabt owner with FORCE RLS, UPDATE cross-tenant audit row MUST return 0 rows
    ...
}
```

### D55 — SYSTEM_TENANT_UUID sentinel replaces NULL audit policy (v2: Jordan preference adopted)

**v1 D55** proposed allowing NULL tenant_id on audit_events with a special OR-NULL policy. **Marcus C-B-N3:** this is a forensic-evasion bypass — NULL rows are invisible to every tenant's SELECT. **Jordan preferred alternative:** require `tenant_id NOT NULL` + bind a SYSTEM_TENANT_UUID for every system context.

**v2 decision:** adopt Jordan's alternative.

```java
// New constant
public final class TenantContext {
    /**
     * Reserved sentinel UUID for platform/system-originated audit events
     * (batch jobs, migrations, scheduled tasks, platform admin cross-tenant
     * actions). Every system context MUST bind this UUID via
     * runWithContext(SYSTEM_TENANT_ID, ...) before any DB write that could
     * hit a regulated table.
     */
    public static final UUID SYSTEM_TENANT_ID =
        UUID.fromString("00000000-0000-0000-0000-000000000001");
    ...
}
```

`audit_events` gets the SAME canonical policy as other tables (D44 shape). Pre-Phase-B sweep task (new task 3.27): every `@Scheduled`, `@EventListener`, `ApplicationRunner`, `CommandLineRunner` that writes to a regulated table wraps its body in `TenantContext.runWithContext(SYSTEM_TENANT_ID, false, ...)`. Caught by B11 ArchUnit rule + manual audit.

**Consequence:** D56 NULL partition deleted. Every audit row lands in some tenant's partition (including SYSTEM_TENANT for system events). Platform admins querying cross-tenant use a separate audit path (Phase G task 7.x) that bypasses RLS via a dedicated platform-admin view.

### D57 — Rollback strategy (v2: all-or-nothing per Marcus W-B-N9)

**Marcus:** partial rollback (NO FORCE but policies intact) silently re-enables owner bypass — worse than full rollback. v2 mandates all-or-nothing:

```sql
-- V67-V73 companion rollback scripts (NOT auto-applied; reference for operator)
-- Must be executed as an atomic unit. Operator cannot skip the FORCE reversal.
BEGIN;
ALTER TABLE audit_events NO FORCE ROW LEVEL SECURITY;
DROP POLICY tenant_isolation_audit_events ON audit_events;
-- ... for every regulated table in the same BEGIN/COMMIT
-- Write audit event documenting the rollback
INSERT INTO audit_events (tenant_id, action, details) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'SYSTEM_PHASE_B_ROLLBACK',
    jsonb_build_object('reason', :reason, 'operator', current_user)
);
COMMIT;
```

Phase B delivers `scripts/phase-b-rls-panic.sh` (D61) which executes this atomically + logs to operator stdout + posts to PagerDuty (if configured).

### D58 — Rehearsal gate: restored-dump alternative (v2: no stage env required)

**Sam C-B-N3:** stage.findabed.org doesn't exist yet; D58's rehearsal-against-prod-copy can't actually happen today. v2 defines the **restored-dump alternative** that doesn't require new infrastructure:

```bash
# scripts/phase-b-rehearsal.sh
# Runs on operator laptop OR a second Oracle Always Free VM.
# Requires: recent prod pg_dump, Docker, local fabt JAR v0.43 build.
#
# 1. Spin up throwaway postgres:16 (pre-pgaudit image — rehearsal doesn't need audit logs)
# 2. pg_restore the prod dump
# 3. Run Flyway migrations V67-V73 against it
# 4. Start fabt-backend JAR pointed at the restored DB
# 5. Run Playwright smoke subset (login + search + DV referral path)
# 6. Report green/red + any policy-related WARN logs
#
# Green = Phase B safe to tag for prod; red = block deploy until fixed.
```

v0.43 release notes REQUIRE a documented successful rehearsal run + commit hash + operator signature before the tag publishes. CODEOWNERS gate on `CHANGELOG.md`'s release-gate section.

### D59 — Prepared-statement plan verification (NEW, per Marcus C-B-N5)

**Catastrophic risk:** if Postgres inlines `fabt_current_tenant_id()` into a cached prepared-statement plan at PREPARE time (not re-evaluated per EXECUTE), cross-tenant plan reuse leaks data.

**Verification test (Phase B IT):**

```sql
-- On a freshly-borrowed connection:
SET app.tenant_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
PREPARE q AS SELECT * FROM audit_events WHERE tenant_id = fabt_current_tenant_id();

-- Inspect the cached plan — CRITICAL: fabt_current_tenant_id should appear
-- as a function call, NOT as a constant literal 'aaaaaaaa-...'.
EXPLAIN (GENERIC_PLAN, VERBOSE) EXECUTE q;

-- Re-bind with a different tenant + execute
SET app.tenant_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
EXECUTE q;
-- MUST return only tenant B rows, NOT tenant A rows
```

If the function IS inlined at PREPARE, mitigation is to mark `fabt_current_tenant_id()` as VOLATILE (at cost of losing index pushdown). v2 ships STABLE LEAKPROOF as primary; VOLATILE fallback documented if D59 fails.

### D60 — Phase F partition-creation-hook gap mitigation (NEW, per Sam C-B-N4)

Between Phase B ship and Phase F ship, new tenants land in no partition (rejected by V71's partition-by-tenant-id constraint if strict, OR go to a "pending" partition). **v2 decision:** V71 creates a `DEFAULT` partition for unmapped tenant UUIDs. Phase F's `TenantLifecycleService.create` hook adds partitions for new tenants going forward. During the Phase B → Phase F window, new tenants' audit events land in DEFAULT; when Phase F ships, a one-shot data-migration script (Phase F task 6.3.5) moves their rows into the proper per-tenant partition.

Risk guard: operator runbook for v0.43 deploy warns "new tenant onboarding between v0.43 and v0.44 lands audit rows in DEFAULT partition; cleanup script runs at v0.44 deploy". Acceptable debt if the B→F window is <30 days.

### D61 — Phase B panic script (NEW, per Sam C-B-N5)

```bash
# scripts/phase-b-rls-panic.sh
#
# Emergency rollback of Phase B RLS enforcement.
# Usage: ./phase-b-rls-panic.sh --reason "<operator note>"
#
# 1. Verify operator is running as postgres superuser via connection URL
# 2. Acquire ACCESS EXCLUSIVE lock on all 8 regulated tables
# 3. Execute the atomic rollback transaction from D57
# 4. Emit audit event + log line + exit non-zero with clear summary
# 5. Post to #fabt-alerts Slack / PagerDuty if configured
#
# Expected time-to-recover: < 60 seconds end-to-end.
# Does NOT un-install pgaudit, does NOT restart Postgres.
```

Phase B delivers the script + rehearses it against Testcontainers during the IT suite.

### D62 — Micrometer coverage (NEW, per Sam C-B-N6)

Phase B ships the following metrics:

| Metric | Type | Tags | Fired by |
|--------|------|------|----------|
| `fabt.rls.tenant_context.empty.count` | Counter | source (filter/scheduled/batch) | `RlsDataSourceConfig.applyRlsContext` when `tenantId == null` |
| `fabt.audit.system_insert.count` | Counter | action | `AuditEventService.onAuditEvent` when `TenantContext.getTenantId() == SYSTEM_TENANT_ID` |
| `fabt.rls.force_rls_enabled` | Gauge | table | Polled every 60s via `SELECT relforcerowsecurity FROM pg_class` |
| `fabt.rls.policy_violation.count` | Counter | table, expected_tenant | Incremented when SQLException indicates policy denial (Postgres error 42501 under RLS context) |

Prometheus alerts (documented in runbook, not shipped in Phase B code):
- `fabt.rls.force_rls_enabled{table="audit_events"} == 0` for ANY regulated table → page
- `fabt.rls.tenant_context.empty.count` rate > baseline → warn (detects post-deploy regressions in system-context binding)

### D63 — pgaudit `log_parameter = 'off'` (NEW, per Marcus C-B-N6)

pgaudit with `log_parameter = 'on'` logs bind values on every write. Our write path includes password hashes, OTP codes, HMIS payloads, JWT body claim UUIDs — all secrets or PII.

**v2:** `pgaudit.log_parameter = 'off'`. Accept the forensic loss (can't replay exactly what was INSERTed). The row-level audit still captures (table, cmd, user, timestamp) which is sufficient for HIPAA BAA-class posture.

### D64 — Postgres version pin ≥ 16.6 (v2, per Marcus C-B-N4)

CVE-2024-10976 patch floor is 16.5, BUT:
- CVE-2024-4317 (pg_stats_ext visibility under RLS)
- CVE-2023-5869 (array modification under RLS context)
- CVE-2022-1552 (autovacuum/REINDEX role escalation)

**v2:** pin to Postgres ≥ **16.6** (16.5 + the CVE-2024-10976-adjacent patches). Verify Oracle VM's current image via `SELECT version()` pre-deploy; if below 16.6, run the image upgrade as an independent pre-v0.43 deploy step. CI Testcontainers config pinned to `postgres:16.6-alpine` (or image-swap target per D49).

---

## 4. Migration order (V67–V73, revised)

| # | Migration | Purpose | Depends on |
|---|-----------|---------|------------|
| V62–V66 | Phase E reservations | NOT Phase B | — |
| **V67** | Create `fabt_current_tenant_id()` CASE-guarded STABLE LEAKPROOF PARALLEL SAFE function (D43) | Dependency for V68 | None |
| **V68** | Create D14 RLS policies on 8 regulated tables (D44 canonical FOR ALL USING+WITH CHECK for 6 tables; D45 per-cmd PERMISSIVE + RESTRICTIVE for 2 kid tables) | The core of Phase B | V67 |
| **V69** | `FORCE ROW LEVEL SECURITY` on every policy-protected table | Enforcement | V68 |
| **V70** | `CREATE INDEX CONCURRENTLY` `(tenant_id, …)` on every RLS-protected table (`flyway:executeInTransaction=false` per-migration header) | Index coverage + no-outage | V69 |
| **V71** | Partition `audit_events` + `hmis_audit_log` by tenant_id via rewrite-and-rename (size guard aborts above 500 MB per D48) | Per-tenant VACUUM/backup | V68 |
| **V72** | `REVOKE UPDATE, DELETE ON audit_events, hmis_audit_log, platform_admin_access_log FROM fabt_app` | Append-only audit | V70 |
| **V73** | pgaudit session config (preload via `postgresql.conf` is a manual superuser step per D49) | DB-layer audit log | Manual image-swap step + CREATE EXTENSION |

---

## 5. Risk register (v2: 17 rows, updated mitigations)

| # | Risk | Severity | Mitigation | Residual |
|---|------|----------|------------|----------|
| 1 | JWT validate queries `kid_to_tenant_key` before TenantContext bound → RLS returns 0 rows → auth breaks | P0 | D45 PERMISSIVE SELECT on kid tables; integration test exercises the full HTTP validate path | Covered |
| 2 | V74 re-run as Flyway owner under FORCE RLS fails | P1 | D46 amend V74 with parameterized `set_config` + autoCommit assertion; task 3.26 | Covered |
| 3 | Partition rewrite loses data mid-migration | P1 | Flyway atomic tx; size guard aborts above 500 MB | Covered |
| 4 | pgaudit unavailable → BAA gap | P1 | D49 image swap; D63 `log_parameter=off` regardless. Honest "gap, regulated tier only" language in compliance-posture-matrix (NOT "equivalence") | Covered |
| 5 | Policy syntax error ships to prod → 500 storm | P0 | D58 restored-dump rehearsal + runtime 4xx-rate alerts (D62) + `phase-b-rls-panic.sh` (D61) | Covered |
| 6 | Missing `(tenant_id, …)` index → full-table scan | P1 | V70 CONCURRENTLY + `pg_stat_statements` A/B test | Covered |
| 7 | LEAKPROOF function throws on malformed input → operator-asserted lie becomes real leak | P2 | D43 CASE-guard normalizes all three sad paths before cast; `RlsDataSourceConfig` only writes validated UUIDs | Covered |
| 8 | `SET LOCAL` plumbing at pool-borrow silently no-ops | — | D50 REMOVED from Phase B (Phase E problem) | Covered by deferral |
| 9 | pg_policies snapshot stale | P2 | D51 hash pinning + CODEOWNERS + weekly drift check + PR rule "migration modification requires snapshot modification" | Covered |
| 10 | SECURITY DEFINER introduced unchecked | P2 | D52 Postgres-side check (not grep); snapshot section 4 = 0 rows | Covered |
| 11 | audit_events NULL-tenant_id forensic evasion | — | D55 REPLACED — SYSTEM_TENANT_UUID sentinel; NOT NULL enforced; no special OR-NULL policy | Covered |
| 12 | Partition for NULL tenant_id missing | — | DELETED — D55 SYSTEM_TENANT_UUID has its own partition | Covered |
| 13 | `fabt` role accidentally SUPERUSER or BYPASSRLS | P1 | D54 integration test checks `NOT rolsuper AND NOT rolbypassrls` for BOTH `fabt` and `fabt_app` | Covered |
| 14 | Partial rollback (NO FORCE but policies intact) silently re-enables owner bypass | P2 | D57 atomic all-or-nothing rollback script; panic script D61 enforces the ordering | Covered |
| 15 | Scheduled jobs fail once RLS lands (no TenantContext bound) | P1 | D55 SYSTEM_TENANT_UUID binding requirement; task 3.27 pre-merge sweep; B11 ArchUnit rule | Covered |
| **16 (NEW)** | Prepared-statement plan caching inlines `fabt_current_tenant_id()` at PREPARE time → cross-tenant leak via cached plan reuse | P0 | D59 EXPLAIN (GENERIC_PLAN) verification test; VOLATILE fallback documented if STABLE fails | Covered (verify in IT) |
| **17 (NEW)** | pgaudit `log_parameter=on` leaks secrets/PII in logs | P1 | D63 `log_parameter=off` hardcoded in V73 + image config | Covered |
| **18 (NEW)** | Phase B → F window: new tenants' audit rows land in DEFAULT partition with no cleanup path | P2 | D60 one-shot cleanup script in Phase F task 6.3.5; runbook documents <30-day window | Accepted with doc |

---

## 6. Warroom questions (v2: 8 remaining — most resolved in v1→v2 rewrite)

### Q1 — V67 function uses SQL or plpgsql?

**Proposed:** SQL (CASE + regex). plpgsql's exception handler would disqualify LEAKPROOF anyway. Regex pre-validation is cheap.

### Q2 — Image swap: `postgres:16` Debian + apt pgaudit, OR `pgvector/pgvector:pg16` bundle?

**RESOLVED 2026-04-17 (Corey post-confirmation-warroom):** Debian + PGDG apt. Minimal surface area, upstream-maintained, explicit version pin (`postgresql-16-pgaudit=<pinned>`). Community pgvector bundle rejected per Marcus (pulls in vector extensions we don't use; security posture not under our control). Implementation `deploy/pgaudit.Dockerfile` + alpine→Debian PGDATA compat rehearsal on Oracle VM during D58 rehearsal pass.

### Q3 — Does Phase B block on stage-env build?

**Proposed:** NO. D58's restored-dump rehearsal is sufficient for v0.43. Stage env remains Phase J task 10.3.

### Q4 — D59 prepared-statement test outcome: does Postgres inline LEAKPROOF STABLE functions at PREPARE?

**RESOLVED 2026-04-17 (Corey post-confirmation-warroom):** If the D59 test FAILS (function inlined at PREPARE time + cross-tenant leak via cached plan reuse), **Phase B STOPS and re-warrooms before any fallback.** VOLATILE-fallback is NOT auto-applied — its perf cliff at year-1 scale (loss of index pushdown on `(tenant_id, …)` composites, partition-pruning break) is too severe to absorb silently. Alternatives to re-warroom: view-based tenant isolation, application-layer pre-filter, or a different RLS architecture. Implementation task ordering: run D59 verification FIRST (before any other Phase B code), abort if failing.

### Q5 — SYSTEM_TENANT_UUID value fixed at `00000000-0000-0000-0000-000000000001`?

**Proposed:** yes. `…0000` is the sentinel used by Phase A's C-A3-1 unknown-kid case; pick a different nibble to avoid confusion. Reserved via constant in `TenantContext`.

### Q6 — Phase F partition-cleanup window: 30 days maximum?

**Proposed:** yes. If B→F slips past 30 days, flag as operational debt + write manual cleanup SQL in the runbook.

### Q7 — Panic script alert wiring: PagerDuty/Slack stub or hardcoded?

**Proposed:** env-var stub (`FABT_PANIC_ALERT_WEBHOOK`). If unset, script writes to stderr + audit_events + exits. Ops team can wire PagerDuty post-Phase-B.

### Q8 — Rehearsal-run documentation format?

**Proposed:** Markdown file `docs/deploys/v0.43-rehearsal.md` + signed commit by operator. CODEOWNERS gate on CHANGELOG.md release-gate section requires the file to exist + be less than 7 days old from tag.

---

## 7. Out of scope for Phase B (v2: expanded)

- B9 `SET LOCAL` per-tenant timeout plumbing → Phase E
- Per-tenant rate-limit config table (V62) → Phase E
- Tenant lifecycle FSM (Phase F)
- Cache isolation (Phase C)
- audit_events hash-chain (V66) → Phase E
- BYPASSRLS grant revocation beyond test-time assertion → Phase L
- pgaudit extension install via Flyway (superuser requirement)
- Stage environment build → Phase J task 10.3
- Cross-instance cache invalidation for `KidRegistryService` → Phase C or G
- Phase F task 6.3.5 one-shot partition cleanup → Phase F

---

## 8. Follow-ups filed post-PR

- Runbook `docs/runbook/phase-b-rls-rollback.md` — incident-triage decision tree + partial-disable recipes
- Prometheus alert rules file `deploy/prometheus/phase-b-rls.rules.yml` — FORCE-RLS gauge, empty-tenant-context rate, 4xx rate per tenant
- `docs/security/compliance-posture-matrix.md` — honest pgaudit gap language per D49 + `feedback_legal_claims_review.md`
- Image-swap operational note in `docs/oracle-update-notes-v0.43.md`
- Phase F task 6.3.5: partition cleanup one-shot for Phase-B→F window

---

## Appendix A — Confirmation warroom checklist

For the revised v2 design, the confirmation warroom verifies:

- [ ] D43 CASE-guard passes LEAKPROOF validator + returns NULL for all three sad paths (Marcus + Jordan)
- [ ] D44/D45 policy shape compiles + the PERMISSIVE-per-command CI invariant SQL runs on Testcontainers (Jordan)
- [ ] D46 V74 amendment uses bind parameter + asserts autoCommit=false (Marcus + Jordan)
- [ ] D49 image swap verified on a throwaway Oracle VM or local Docker before Phase B deploy (Sam)
- [ ] D55 SYSTEM_TENANT_UUID constant wired + scheduled-job sweep (task 3.27) complete (all three)
- [ ] D58 `scripts/phase-b-rehearsal.sh` exists + runs against a test pg_dump (Sam)
- [ ] D59 prepared-statement plan test PASSES (returns per-tenant rows, NOT cached-tenant rows) (Marcus + Jordan)
- [ ] D61 `scripts/phase-b-rls-panic.sh` exists + exits non-zero on a failed rollback rehearsal (Sam)
- [ ] D62 four Micrometer metrics wired + visible in `/actuator/prometheus` (Sam)
- [ ] D63 `pgaudit.log_parameter = off` in V73 + image config (Marcus)
- [ ] D64 Postgres version confirmed ≥ 16.6 on Oracle VM pre-deploy (Sam)
- [ ] CHANGELOG v0.43 release-gate section references rehearsal doc signoff (Sam)
