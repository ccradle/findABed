# Deploy runbook fragments — dv-policy-tenant-flag

These fragments are inputs to the eventual `docs/oracle-update-notes-v0.56.0.md` (in the code repo) when the v0.56 release bundle is assembled. The bundle is expected to include `dv-policy-tenant-flag` + `info-email-contact` + GH #67 per the resume-point release plan.

This doc closes warroom round 2 M3 (Sam — `--fresh` clarification + Flyway HWM verification step) and M4 (Demetrius — onboarding sequence).

---

## Pre-deploy verification

### Backfill scope query (run on prod DB before deploy)

Connect via `fabt` owner role (per `feedback_rls_hides_dv_data` — `fabt_app` would have RLS hide DV shelters from the count):

```sql
SELECT t.slug,
       COUNT(s.id) FILTER (WHERE s.dv_shelter = true) AS dv_shelter_count,
       (t.config -> 'dv_policy_enabled')::text AS current_dv_policy_value
FROM tenant t
LEFT JOIN shelter s ON s.tenant_id = t.id
GROUP BY t.id, t.slug, t.config
ORDER BY t.slug;
```

**Expected output (prod, pre-deploy):**

| slug | dv_shelter_count | current_dv_policy_value |
|---|---|---|
| dev-coc | (>= 1) | null |
| dev-coc-east | (>= 1) | null |
| dev-coc-west | (>= 1) | null |

After V97 runs at Spring Boot startup, all 3 tenants should land at `current_dv_policy_value = true`.

### Flyway HWM verification

V94 + V95 + V96 already shipped with v0.55. The dv-policy-tenant-flag migration is **V97** (Sam's collision check found V94/V95/V96 taken). Expected HWM transition:

```
Before deploy: 96
After deploy:  97
```

Verify post-deploy:

```sql
SELECT MAX(installed_rank) AS rank,
       MAX(version) AS hwm
FROM flyway_schema_history;
```

If HWM is anything other than `97` after deploy, investigate before continuing — a missing migration is a deploy gate failure.

---

## `--fresh` behavior clarification (Sam M1)

`./dev-start.sh --fresh` runs:
1. `seed-reset.sql` (truncates app tables, leaves Flyway state intact)
2. `seed-data.sql` (re-seeds 3 demo tenants + their fixtures)

It does **NOT** re-run Flyway migrations. V97 already fired at Spring Boot startup; subsequent `--fresh` rebuilds skip migrations and reload via `psql`.

**Implication**: the `dv_policy_enabled = true` literal in `seed-data.sql` (added in this change) is **load-bearing for `--fresh`**. Without it, a `--fresh` reseed would produce demo tenants with `dv_policy_enabled` absent (which `Tenant.isDvPolicyEnabled` reads as `false`), and the demo would fail any DV-shelter-create flow.

The seed-data redundancy was originally framed as belt-and-suspenders against the migration. Closer inspection: it's **the only load-bearing source** for `--fresh` paths. Keep it; never remove.

---

## Onboarding sequence for fresh CoCs (Demetrius M4)

A NEW tenant (created via `/api/v1/tenants` POST after V97 has already run on this DB) starts with `tenant.config = {}`. The first DV-shelter create attempt will fail with `400 shelter.dvShelter.requiresDvPolicy`.

**Required operator workflow:**

1. **Create tenant** via `POST /api/v1/tenants` (PLATFORM_OPERATOR role).
2. **Provision a COC_ADMIN** with `dvAccess=true` for the new tenant.
3. **Enable DV policy** before creating any DV shelters:
   - The COC_ADMIN logs in.
   - Navigates to admin Settings → DV Shelter Operations panel.
   - Clicks the toggle to enable.
   - Confirms in the extra-confirm modal.
   - PATCH `/api/v1/admin/tenants/{tenantId}/dv-policy` fires with `{"dvPolicyEnabled": true}`.
4. **Create DV shelters** as normal — they now pass the invariant.

**Skipping step 3 surfaces the structured error** at first DV-shelter create attempt. The error message includes "Enable DV policy in admin Settings before flipping a shelter to DV", and the admin UI's `DvPolicySettings` panel (when §7 lands) is the destination.

For coordinating CoCs that pre-existed the migration: V97 backfilled the flag. No operator action required for them.

---

## Rollback policy (Sam L)

Forward-only Flyway: V97 has no `Vundo` script and one is **not required**. Service rollback (revert backend + frontend deployment) is sufficient. The `dv_policy_enabled` JSONB key sitting unused in `tenant.config` is harmless because rolled-back code never reads it. No data-corruption risk.

If a CoC operator has flipped the flag to `false` on a tenant after deploy AND a rollback is required, the post-rollback world correctly ignores the flag value. If a rollback then a re-deploy occurs, the flag value is preserved.

---

## Post-deploy smoke verification

Run from a localhost shell on the VM after deploy:

```bash
# 1. HWM advanced to V97
docker compose exec -T postgres psql -U fabt -d fabt -c \
    "SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1;"
# Expect: 97

# 2. All 3 demo tenants backfilled to true
docker compose exec -T postgres psql -U fabt -d fabt -c \
    "SELECT slug, config -> 'dv_policy_enabled' AS dv_policy
     FROM tenant
     WHERE slug IN ('dev-coc', 'dev-coc-east', 'dev-coc-west');"
# Expect 3 rows, each with dv_policy = true

# 3. dv-shelter-e2e-exclusion canary still green
# (Run the full Playwright canary suite against demo)
```

If any of these fail, the deploy is incomplete — investigate before announcing.
