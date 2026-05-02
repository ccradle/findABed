## Context

A tenant in the FABT modular monolith is the unit of CoC-level governance. It currently carries operational config in a JSONB `tenant.config` column (e.g., `hold_duration_minutes`, `features.reentryMode`) and structural columns (`dv_address_visibility`, `kid_eligible`, etc.). Per-shelter sensitivity is expressed via `shelter.dv_shelter` (boolean), and per-user authorization via the `dv_access` claim.

What is missing today is a tenant-level acknowledgement that the tenant operates DV-shelter infrastructure. The existing per-shelter `dv_shelter` flag can be flipped on without any tenant-level signal, even though all DV protections (VAWA-aware redaction, RLS, audit suppression, dv_access claim filtering, the `dv-shelter-e2e-exclusion` canary suite) presuppose tenant-level coherence.

This gap surfaced when `info-email-contact` Slice B referenced `tenant.dv_policy_enabled` as a discriminator and ground-truthing found the field did not exist. The 11-persona warroom (2026-05-01) decided to ship the DV-policy infrastructure as its own coherent change rather than smuggle a one-off field into a contact-email change.

**Stakeholders**:
- Platform-operator-owned (rare — this is in-tenant operational config, not platform authority).
- COC_ADMIN-owned: operational responsibility for the tenant's DV posture.
- Casey (legal), Marcus (security), Tomás (architecture), Demetrius (ops), Devon (training), Keisha (community), Maria (i18n), Simone (UX), Riley (testing), Sam (DevOps), Alex (engineering) — all signed off on the invariant.

## Goals / Non-Goals

**Goals:**
- Make tenant-level DV acknowledgement explicit, auditable, and enforceable at the service layer.
- Block accidental DV-shelter creation on tenants that have not explicitly opted in.
- Preserve consistency: while the flag is `false`, no DV shelters can exist on the tenant.
- Provide a forensic trail on flag changes AND on rejected change attempts.
- Unblock `info-email-contact` Slice B as a follow-up.

**Non-Goals:**
- This change does NOT alter per-user `dv_access` claim semantics, RLS policies, redaction helpers, or the existing `dv-shelter-e2e-exclusion` canary tests. Those continue to operate on the per-shelter `dv_shelter` flag, now with a tenant-level invariant guard upstream of writes.
- This change does NOT introduce a tenant-level enable / disable for redaction or audit suppression — the flag gates per-shelter writes, not data-protection behaviors.
- This change does NOT add a UI for retroactively migrating DV shelters off a tenant (that is the operator's responsibility before requesting disable).
- This change does NOT cover platform-operator authority. COC_ADMIN owns this flag.

## Decisions

### D1: JSONB key, not new column

**Decision**: Store the flag as `tenant.config.dv_policy_enabled` (JSONB key) rather than a new `tenant.dv_policy_enabled` column.

**Rationale**: The `tenant.config` JSONB is the established surface for tenant-scoped operational config (e.g., `hold_duration_minutes` v0.49+, `features.reentryMode` v0.55). Mirroring that pattern keeps the schema stable and matches how `ReservationSettings.tsx` already reads/writes JSONB keys at the admin-UI surface. A new column would require Flyway DDL plus a downstream JPA mapping change for a single boolean — disproportionate.

**Alternative considered**: First-class column. Rejected — adds schema churn for one boolean and breaks the JSONB-config convention without a forcing reason.

### D2: Dedicated `PATCH .../dv-policy` endpoint, not a generic config endpoint

**Decision**: Add a dedicated `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy` endpoint, mirroring the slice-2C `PATCH .../hold-duration` precedent (`ReservationConfigController`).

**Rationale**: Each tenant-config key has its own auth posture, audit semantics, and validation envelope. A generic config endpoint would either need JSON-pointer-style routing with conditional auth (complex, easy to get wrong) or accept arbitrary key/value pairs (loose contract). The dedicated-endpoint-per-key pattern keeps the auth boundary visible in the URL surface and makes the OpenAPI surface self-documenting. The `ReservationConfigController` design notes already articulate this argument.

**Alternative considered**: Generic `PATCH /api/v1/admin/tenants/{id}/config` with JSON-pointer body. Rejected per above.

### D3: COC_ADMIN scope with extra-confirm modal

**Decision**: The endpoint requires `COC_ADMIN` role plus an extra-confirm modal in the UI before the request is submitted. PLATFORM_OPERATOR cannot flip this flag.

**Rationale (operator-stated, 2026-05-01)**: "Platform Operator likely doesn't have the training to understand domestic violence." The COC admin owns operational responsibility for the tenant's DV posture and has DV-context awareness platform operators don't. The extra-confirm modal pattern matches other consequential admin operations (e.g., shelter deactivation with pending-DV-referrals confirmation) and ensures the COC admin sees the implications before flipping.

**Tenant-scoping**: Identical to `ReservationConfigController` — caller's JWT-bound `TenantContext.getTenantId()` MUST equal the path's `tenantId`. A COC_ADMIN from Tenant A who learns Tenant B's UUID MUST NOT be able to flip Tenant B's flag. Enforced via `AccessDeniedException` (403, no body) before the write executes.

**Alternative considered**: PLATFORM_OPERATOR with `@PlatformAdminOnly` annotation (and the Phase G `JustificationValidationFilter`). Rejected per operator decision — wrong actor for this concern.

### D4: Disable-path forbidden while DV shelters exist

**Decision**: A `true → false` flip MUST return 400 if `EXISTS(SELECT 1 FROM shelter WHERE tenant_id = ? AND dv_shelter = true AND active = true)`. Operator must first migrate or deactivate all DV shelters, THEN disable the flag. Structured error code: `tenant.dvPolicy.cannotDisableWhileDvSheltersExist`. The error message MUST include the count of remaining DV shelters so the operator knows the scope of work.

**Rationale**: The invariant is "no DV shelters without flag." Allowing flag-disable while DV shelters exist would leave the system in a state where the per-shelter `dv_shelter=true` flag still triggers DV protections (RLS, redaction, audit suppression) but the tenant-level acknowledgement is absent — exactly the failure mode the invariant was added to prevent. Forcing deactivate-then-disable preserves coherence. (Marcus, security: aligned. Operator, 2026-05-01: aligned.)

**Audit on failed disable**: A `TENANT_CONFIG_UPDATED` audit row is emitted on the FAILED disable attempt as well as on the successful change, with `outcome: "rejected"` in the details payload. Marcus: "the attempt itself is forensically interesting" — an operator trying and failing to disable the flag is a signal worth preserving.

**Order-of-operations (Marcus, warroom round 1)**: the audit row MUST be emitted BEFORE the rejection exception is thrown. If the throw runs first, the audit is lost (the exception propagates through the controller before the publishEvent call executes). The implementation MUST sequence: (1) compute count, (2) `eventPublisher.publishEvent(...)` with `outcome: "rejected"`, (3) throw the validation exception. Mirror existing emit-then-throw patterns elsewhere in the project (e.g. `ShelterService.deactivate` if it emits failure-path audits).

**No-leak guarantee on cross-tenant probes**: the tenant-scoping check in D3 MUST execute BEFORE the disable-path inventory query, so a `403 Forbidden` response from a cross-tenant probe carries no body, no headers, and no timing variance derived from Tenant B's DV-shelter count. This protects against side-channel inventory leakage. Captured as a normative scenario in the spec ("Cross-tenant probe does not leak DV-shelter inventory").

**Symmetric note on enable path**: The enable path (`false → true`) is unrestricted by shelter state. A tenant with zero shelters can enable the flag in preparation for onboarding DV shelters. Only the disable path is gated.

**Alternative considered**: Allow disable + cascade-deactivate all DV shelters. Rejected — destructive action with broad blast radius (cancels active reservations, notifies coordinators, triggers SHELTER_DEACTIVATED audit per shelter), buries the operator's intent. The "disable then deactivate" pattern keeps the operator in control of each step.

### D5: Service-layer invariant guard, not DB constraint

**Decision**: The "DV shelter requires DV-policy flag" invariant is enforced in `ShelterService.create`, `ShelterService.update`, AND `ShelterService.activate` (reactivation path), not as a Postgres CHECK constraint or trigger.

**Reactivation extension (Marcus + Alex, warroom round 1)**: without the activate-path guard, an operator who deactivates DV shelters → disables the flag → re-enables the flag is fine, but an operator who deactivates DV shelters → disables the flag → tries to re-activate without re-enabling could resurrect a DV shelter on a flag-off tenant. The invariant MUST cover all three write surfaces — create, update (flip-up), and activate (reactivate) — to maintain the "no DV shelters without flag" property under every operator workflow. The 211 CSV bulk-import path is a fourth surface, addressed separately in D8.

**Rationale**:
- Service-layer guards return structured error codes that Bean Validation and the `GlobalExceptionHandler` already map to consistent HTTP responses; DB-level errors require translation.
- The invariant references a value in JSONB (`tenant.config.dv_policy_enabled`), which would require a function-based CHECK constraint or trigger to enforce — both are operationally heavier than a service-layer call to `Tenant.isDvPolicyEnabled()`.
- The Flyway backfill (V94) handles legacy state; once the backfill runs, every existing DV shelter has its tenant flag set to `true`, so service-layer enforcement on new writes is sufficient.
- Mirrors existing pattern: shelter-deactivation safety gates, hold-duration validation, etc., all live at the service layer.

**Alternative considered**: Postgres trigger that rejects `INSERT/UPDATE` on `shelter` setting `dv_shelter=true` when the parent tenant's `config.dv_policy_enabled` is absent or `false`. Rejected as belt-and-suspenders we don't need; the service layer is the single write path.

### D6: Backfill strategy — set true where DV shelters already exist

**Decision**: V94 Flyway migration sets `dv_policy_enabled = true` on every tenant where `EXISTS(SELECT 1 FROM shelter WHERE tenant_id = X AND dv_shelter = true)`. Tenants with zero DV shelters get no migration write (the helper defaults to `false` on absent key).

**Rationale**: The invariant is forward-looking enforcement. Existing DV shelters predate the flag — they are the empirical evidence that the operator already accepted DV-shelter responsibility, just without a tenant-level marker. Backfilling `true` for those tenants preserves their existing posture and avoids a migration that would force operators to opt back in to a state they are already in. Tenants with zero DV shelters legitimately default to `false`.

**Idempotency**: The migration uses `jsonb_set(config, '{dv_policy_enabled}', 'true'::jsonb, true)` which is safe to re-run (it's a no-op if the key is already `true`, and overwrites if `false` — the latter is also acceptable since the WHERE clause already establishes that the tenant has DV shelters).

**Demo seed impact**: All 3 demo tenants (`dev-coc`, `dev-coc-east`, `dev-coc-west`) seed at least one DV shelter, so all 3 land on `true`. `--fresh` reseeds will hit V94 and produce the same state. Documented in `project_dv_policy_tenant_flag_decisions.md` and the runbook.

### D7: Audit details payload shape

**Decision**: The `TENANT_CONFIG_UPDATED` audit details for a flag flip carry:
```json
{
  "config_key": "dv_policy_enabled",
  "old_value": <bool|null>,
  "new_value": <bool>,
  "outcome": "applied" | "rejected",
  "rejection_code": "<error code or null>",
  "remaining_dv_shelter_count": <int or null>
}
```

**Rationale**: Mirrors `hold_duration_minutes` slice-2C audit shape (config_key + old/new) and adds three fields specific to this change: `outcome` (so a forensic reader can distinguish failed disable attempts from successful changes), `rejection_code` (link back to the structured error), and `remaining_dv_shelter_count` (the operational scope-of-work figure that the rejection message also carries).

### D8: 211 CSV bulk import — per-row reject, not wholesale fail

**Decision**: When the 211 CSV importer ingests rows on a tenant where `dv_policy_enabled = false` and a row's source data implies `dv_shelter = true`, the importer SHALL reject *that row* with the structured error `shelter.dvShelter.requiresDvPolicy` while continuing to process other rows. The import response surfaces per-row results so the operator sees which rows were rejected and why. The import does NOT fail wholesale on the presence of DV rows.

**Rationale (Demetrius, warroom round 1)**: 211 imports are mixed in practice — a CSV typically contains a CoC's full shelter inventory, mixing DV and non-DV facilities. A wholesale-fail policy would force the operator into a binary "fix the CSV externally before re-importing" workflow, which is operationally heavy and prone to manual error. A per-row policy lets the operator import what's importable, see the rejected rows in the response, enable the DV-policy flag (if appropriate), and re-import only the rejected subset.

**Alternatives considered**:
- **Wholesale fail with precondition error** ("tenant DV policy not enabled — fix and resubmit"): rejected. Forces the operator into an out-of-band workflow.
- **Strip `dv_shelter=true` flag from imported rows, log warning, surface to operator post-import**: rejected. Silent data alteration violates `feedback_truthfulness_above_all` — the operator who imported those rows expected DV semantics, and quietly dropping them produces a database state that doesn't match the source CSV without an explicit error.

**Implementation note**: locate the import code path during apply (search for `211` / `csv` / `BulkImport` / equivalent). If the importer bypasses `ShelterService.create()` via a bulk JPA insert, route it through the service layer OR replicate the invariant inline at the import boundary. Decide and document at apply time per task §5.5.

### D9: Audit cross-tenant probe attempts

**Decision**: Cross-tenant access attempts on this endpoint (a COC_ADMIN from Tenant A sending a PATCH to Tenant B's path) emit a `TENANT_CONFIG_UPDATED` audit row with `outcome: "rejected"`, `rejection_code: "tenant.crossTenantAccess"`, plus the actor's tenant ID and the target tenant ID. The audit fires regardless of whether Tenant B exists or has DV shelters.

**Rationale (Marcus, warroom round 1)**: defense-in-depth against lateral-movement signals. A COC_ADMIN trying to flip another tenant's flag is forensically interesting on its own — even if the 403 response correctly hides existence/inventory information, the *attempt* is a behavioral signal worth preserving for incident response. Cost of capture is one audit row; benefit is forensic visibility into a class of misuse the response-side leak guard does not directly address.

**Alternative considered**: silently 403 without audit. Rejected — leaves no trail for incident-response reconstruction.

**AuditEventType reuse**: confirm at apply time whether the existing `TENANT_CONFIG_UPDATED` enum value covers this, or whether a dedicated `CROSS_TENANT_ACCESS_DENIED` (or similar) value is more appropriate. The audit table schema accommodates either; the choice is a categorization decision for the audit reader. Default: reuse `TENANT_CONFIG_UPDATED` with the structured `rejection_code` doing the disambiguation, matching the rejected-disable audit shape.

### D10: Endpoint requires `dvAccess=true`, not just `COC_ADMIN` role

**Decision (warroom round 2, 2026-05-02 IT discovery)**: the `PATCH .../dv-policy` endpoint requires the caller's JWT to carry `dvAccess=true` IN ADDITION TO the `COC_ADMIN` role. A COC_ADMIN without `dvAccess` is rejected with `403 Forbidden`.

**Rationale (grounded in production semantics)**: the disable-path guard (D4) reads `shelter` to count active DV shelters. That table is RLS-protected: the policy filters DV shelters out for callers with `dvAccess=false`. If a COC_ADMIN without `dvAccess` calls the disable path, the count returns 0 even when DV shelters exist on the tenant — and the disable wrongly succeeds. This is the EXACT failure mode the invariant was added to prevent.

Two architectural options were considered:
- **(a) Require `dvAccess=true` on the endpoint** (chosen). One-line guard. Matches the warroom rationale that COC_ADMIN owns this flag because they have DV-context awareness — `dvAccess` is the formal claim representing that awareness.
- **(b) Use a privileged DataSource for the count query** to bypass RLS for the authoritative count. Architecturally cleaner ("system-level vs user-visibility-level" reads) but requires new injection / SET LOCAL ROLE mechanism — more invasive than the current change warrants.

**Where the check lives**: `DvPolicyController.updateDvPolicy` (controller method, after the tenant-scoping check, before the inventory query). Both checks fire BEFORE any DV-shelter-derived data is read so a probe cannot learn inventory state via timing.

**Why this matters for spec maintenance**: a future maintainer might "simplify" by removing the `dvAccess` check, viewing it as redundant against the `COC_ADMIN` role. This decision documents WHY the gate exists (RLS coupling) so the refactor is correctly rejected. The IT scenario `cocAdminWithoutDvAccessForbidden` covers it.

**Spec scenario**: "COC_ADMIN without dvAccess cannot flip flag" (added to `dv-policy-tenant-flag/spec.md` under PATCH endpoint requirement).

## Risks / Trade-offs

- **[Risk]** Onboarding sequence confusion: an operator stands up a fresh tenant, attempts to flip a shelter to DV before enabling the flag, and gets a 400. → **Mitigation**: runbook update documents the sequence ("Enable DV policy BEFORE creating the first DV shelter"); the 400 error message points to the admin-UI tab; admin-UI surface places `DvPolicySettings.tsx` adjacent to shelter management so the dependency is visible.

- **[Risk]** Test surface cost (~4–6h per Riley): full coverage requires 8 IT scenarios, 2 Vitest scenarios, 2 Playwright scenarios. → **Mitigation**: scope is bounded; reuses existing test fixtures (`TestAuthHelper.setupSecondaryTenant` for cross-tenant scoping); no new test infrastructure.

- **[Risk]** Operator misuse — COC_ADMIN flips the flag without DV training. → **Mitigation**: extra-confirm modal copy describes the implications (flag is auditable, enables per-shelter DV writes, propagates via `TENANT_CONFIG_UPDATED`); link to `for-coc-admins.html` DV-policy section provides context. Casey + Keisha review the modal copy before merge.

- **[Trade-off]** Disable-path "forbidden while DV shelters exist" forces a multi-step operator workflow (deactivate each DV shelter → disable flag) instead of one-click cascade. → **Accepted**: the operator-control narrative is preferred over the convenience of cascade; cascade-deactivate has high blast radius (active reservations, coordinator notifications, audit storm) that should be the operator's explicit decision, not a flag-flip side-effect.

- **[Trade-off]** Service-layer invariant (D5) means a direct SQL UPDATE to `shelter.dv_shelter` would bypass enforcement. → **Accepted**: the same property holds for every other service-layer guard in the codebase (hold duration, shelter deactivation, etc.); direct SQL is a break-glass operation outside the normal write path.

## Migration Plan

**Pre-deploy**:
1. Operator reviews backfill scope: `SELECT t.id, t.slug, COUNT(s.id) FROM tenant t LEFT JOIN shelter s ON s.tenant_id = t.id AND s.dv_shelter = true GROUP BY t.id`. Expect 3 rows for the demo environment, 1+ for any prod tenant operating DV shelters.
2. Spec-warroom approval on disable-path copy and admin-UI extra-confirm modal copy (Casey + Keisha).

**Deploy**:
1. Flyway runs V94 migration on Spring Boot startup. The migration is idempotent; safe to re-apply on a partially-deployed environment.
2. Backend rolls out with new endpoint + service-layer invariant guard. Existing shelters are unaffected (their tenants are already on `true`).
3. Frontend rolls out with new `DvPolicySettings.tsx` admin tab.

**Post-deploy smoke**:
- `GET /api/v1/admin/tenants/{tenantId}` includes the new flag in `config` payload.
- Existing DV shelters remain visible in `dv-shelter-e2e-exclusion` canary suite (no regression).
- Negative-path: a fresh tenant with the flag off rejects `dv_shelter=true` shelter creation with `shelter.dvShelter.requiresDvPolicy`.

**Rollback**:
- Service rollback (revert backend + frontend deployment) is sufficient. The Flyway migration only writes `true`, which the rolled-back backend ignores (older code never reads `dv_policy_enabled`); no data-corruption risk.
- Flyway migration rollback NOT required and NOT provided — the JSONB key sitting unused is harmless.

## Open Questions

None resolved-blocking at scaffold time. The disable-path policy and audit-on-rejection decisions were ratified by the operator in the 2026-05-01 warroom (recorded in memory `project_dv_policy_tenant_flag_decisions.md`). Spec warroom round on the scaffolded artifacts is the next gate before `/opsx:apply`.
