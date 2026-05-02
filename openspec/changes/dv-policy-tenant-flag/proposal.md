## Why

Today a tenant can flip a shelter's `dv_shelter=true` without any tenant-level acknowledgement that it operates DV-shelter infrastructure. All existing DV protections (VAWA-aware redaction, RLS, audit suppression, dv_access claim) presuppose that acknowledgement, but no structural enforcement exists. This change introduces a tenant-level boolean flag that gates per-shelter DV writes, making the acknowledgement explicit and auditable.

It also unblocks `info-email-contact` Slice B, which referenced `tenant.dv_policy_enabled` as the discriminator for the DV-tenant guard on the platform contact-email PATCH endpoint. The field did not exist; rather than smuggle it into the contact-email change, the warroom (2026-05-01) decided to ship the DV-policy infrastructure as its own coherent change.

## What Changes

- Introduce `tenant.config.dv_policy_enabled` (boolean, default `false`) as a new JSONB key on the existing `tenant.config` column, mirroring the `features.reentryMode` v0.55 pattern.
- Add `Tenant.isDvPolicyEnabled()` helper that reads from JSONB and defaults to `false` on absent key.
- Add a Flyway migration that backfills `dv_policy_enabled = true` for any tenant that already has at least one shelter with `dv_shelter = true` (the 3 demo tenants will all backfill since each seeds at least one DV shelter).
- Add `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy` endpoint, COC_ADMIN-scoped, with tenant-scoping guard (caller's JWT-bound tenant MUST equal path tenant), emitting `TENANT_CONFIG_UPDATED` audit on success and on FAILED disable attempt.
- **BREAKING (operational)**: Service-layer invariant in `ShelterService.create`, `ShelterService.update`, and `ShelterService.activate` (reactivation path) — if the request sets `dv_shelter=true` AND `Tenant.isDvPolicyEnabled() == false`, return 400 with structured error code `shelter.dvShelter.requiresDvPolicy`. The same invariant applies per-row to the 211 CSV bulk import: rows that would create DV shelters on a flag-off tenant are rejected individually while non-DV rows continue to import. Existing shelters with `dv_shelter=true` are unaffected (Flyway backfill ensures their tenants land on `dv_policy_enabled=true`).
- **Disable-path constraint**: Flipping the flag from `true → false` while the tenant has any active shelter with `dv_shelter=true` SHALL return 400 with structured error code `tenant.dvPolicy.cannotDisableWhileDvSheltersExist`. The error message SHALL include the count of remaining DV shelters. The failed attempt SHALL emit a `TENANT_CONFIG_UPDATED` audit row with `outcome: "rejected"`. Enable path (`false → true`) is unrestricted.
- New admin UI surface `DvPolicySettings.tsx` mirroring `ReservationSettings.tsx`, with extra-confirm modal pre-flip (distinct copy for enable vs disable per UX warroom) and a localized note explaining the flag's effect plus a link to `for-coc-admins.html` DV-policy section. Disable-rejection error UI includes a direct link to the admin Shelters tab filtered to active DV shelters so the operator can identify what blocks the disable.
- **Defense-in-depth audit**: a cross-tenant probe (a COC_ADMIN from Tenant A attempting to flip Tenant B's flag) MUST NOT leak DV-shelter inventory via timing or response data, AND MUST emit an audit row with `rejection_code: "tenant.crossTenantAccess"` for forensic visibility into lateral-movement attempts.
- Document the operator runbook step: "Enable DV policy BEFORE creating the first DV shelter on a fresh tenant."

## Capabilities

### New Capabilities
- `dv-policy-tenant-flag`: tenant-level boolean acknowledging that the tenant operates DV-shelter infrastructure; gates per-shelter DV writes; ships dedicated PATCH endpoint, admin UI, audit, and disable-path safety constraint.

### Modified Capabilities
- `shelter-edit`: shelter create + update now enforce the tenant-flag invariant on the `dv_shelter` field — `true` is rejected when the tenant flag is off.

## Impact

- **Code (backend, modular monolith)**:
  - `tenant` module: new `Tenant.isDvPolicyEnabled()` helper; `TenantService` write helper (mirrors `setHoldDurationMinutes`); new controller `DvPolicyController` (mirrors `ReservationConfigController`); new DTO record `DvPolicyRequest`.
  - `shelter` module: invariant guard in `ShelterService.create` + `ShelterService.update`; new error code in shared error registry.
  - `shared.audit`: existing `TENANT_CONFIG_UPDATED` event type reused; details payload extended to carry `dv_policy_enabled` old/new values + `outcome` field for failed disable attempts.
- **Database**: one Flyway migration (V94 reserved post-V93 `reentry-spec`) to backfill `dv_policy_enabled = true` on tenants with existing DV shelters. JSONB-only — no new column.
- **Frontend**: new `DvPolicySettings.tsx` component in `frontend/src/pages/admin/components/`; wires into existing admin Settings tab; extra-confirm modal pattern; EN + ES strings (Maria review for ES).
- **Docs**: runbook update (sequencing — enable flag THEN flip first DV shelter); `for-coc-admins.html` DV-policy section.
- **Downstream unblocked**: `info-email-contact` Slice B — §3.3 DV-policy guard becomes a 1-line spec edit + helper call once this lands.
- **No client-API regressions**: existing public endpoints unchanged. Existing shelters with `dv_shelter=true` are unaffected by the invariant because the backfill ensures their tenants are `dv_policy_enabled=true` before the invariant takes effect.
- **Demo seed**: 3 demo tenants (`dev-coc`, `dev-coc-east`, `dev-coc-west`) all backfill to `true` via the migration; no operator action required.
