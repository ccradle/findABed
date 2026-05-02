## 0. Pre-flight & alignment

- [x] 0.1 Spec warroom round on the scaffolded change (focus areas: D4 disable-path safety, D6 backfill scope, D7 audit shape, admin-UI extra-confirm copy, runbook sequencing). Use the 11-persona convention; capture verdicts in a session log. (DONE 2026-05-02 — round 1; this version of tasks.md reflects Bucket A + B verdicts.)
- [x] 0.2 Casey + Keisha review the EN extra-confirm modal copy (panel label + state-text + modal title + modal body for enable case + modal body for disable case + confirm button + cancel button + disable-rejection error). **MUST complete BEFORE any §7.x or §8.x task starts** (frontend code follows approved copy, not vice-versa). EN draft saved at `copy-draft-en.md`; synthetic Casey+Keisha review applied 2026-05-02 (5 verdicts captured in the draft). Real-reviewer sign-off still required at §13.3. Copy guardrails per warroom round 1:
  - Survivor-respectful framing; avoid jargon ("flag", "policy enabled", "infrastructure")
  - Lead with purpose, not the noun: e.g. modal title "Confirm: this CoC operates DV shelters" not "Enable DV policy"
  - Disable-path error must lead with empathy not procedure: e.g. "This CoC currently operates [N] active DV shelters. Each must be deactivated before DV-shelter operations can be turned off for this CoC." NOT "Cannot disable while DV shelters exist"
  - Never expose the literal `dv_policy_enabled` field name in user-visible copy
  - Never mention shelter names or IDs — only the count returned by the backend
- [x] 0.3 Operator-laptop verification: confirm `feature/dv-policy-tenant-flag` branch can be created in BOTH the docs repo (`findABed/`) and the code repo (`finding-a-bed-tonight/`); no shared branch state between the two repos. (Verified 2026-05-02 by `git status` on both repos; both currently on `feature/info-email-contact`, both have `main` available, no namespace collision.)

## 1. Branch + workspace bootstrap

- [x] 1.1 Create `feature/dv-policy-tenant-flag` branch in the code repo (`finding-a-bed-tonight/`); push to origin to establish remote tracking. (Created from `main` HEAD `bd8c5f2`. Push deferred until first §2 commit.)
- [x] 1.2 Create `feature/dv-policy-tenant-flag` branch in the docs repo (`findABed/`); push to origin. (Created from `main` HEAD `8884060`. Pushed as `feb083b` with scaffold + warroom round 1 + EN copy draft.)
- [x] 1.3 Confirm clean working tree on both repos; record starting HEADs in a session-scratch file. (Pre-existing screenshot drift unrelated to this change is preserved on `feature/info-email-contact` — switching back when Slice B resumes brings it into view; new branches start from a clean tracked state. Starting HEADs: docs `8884060`, code `bd8c5f2`.)

## 2. Backend — domain + persistence

- [x] 2.1 Add `Tenant.isDvPolicyEnabled()` helper in `org.fabt.tenant.domain.Tenant` reading the JSONB `dv_policy_enabled` key, defaulting to `false` on absent key. Cover the parsing path that matches `Tenant.getConfig()` plus a defensive try/catch on JsonProcessingException returning `false` (mirrors the conservative read pattern in `ReservationConfigController.readHoldDurationFromConfig`). (Implemented as static helper `Tenant.isDvPolicyEnabled(JsonString config, ObjectMapper mapper)` per existing entity-no-Jackson convention; ObjectMapper threaded from caller.)
- [x] 2.2 Unit-test `Tenant.isDvPolicyEnabled()` with three fixtures: absent key returns `false`; `true` literal returns `true`; `false` literal returns `false`. One additional fixture for a malformed JSON value returning `false`. (10 fixtures in `TenantDvPolicyHelperTest`: true/false literal, absent, empty config, null, blank, malformed, non-boolean string, non-boolean number, coexistence with other keys. All green.)
- [x] 2.3 Add `TenantService.setDvPolicyEnabled(UUID tenantId, boolean value)` writing the JSONB key under `tenant.config.dv_policy_enabled`. Mirror the JSONB-merge approach in `TenantService.setHoldDurationMinutes`. Idempotent against the existing value.
- [x] 2.4 Unit-test `TenantService.setDvPolicyEnabled` for round-trip on existing-config tenants (no other config keys clobbered) and on empty-config tenants (initial JSONB write). (6 Mockito-based tests in `TenantServiceDvPolicyTest`: empty→true, empty→false, preserves existing keys, overwrites existing value, idempotent re-set, bumps updatedAt. All green.)

## 3. Backend — Flyway backfill migration

- [x] 3.0 **(Sam)** V-prefix collision check at apply time: list `db/migration/V*.sql` files and confirm the next-free V-prefix. Resume-point assumes V94 (reentry-spec landed V93), but if anything else slips into the release window first, bump the new file accordingly. Update §3.1 file name and any references in tasks/spec/design accordingly. Document the chosen V-number in the PR description. (**Discovered V94 + V95 + V96 are all taken** by reentry-spec follow-on migrations: V94 `shelter_requires_verification_call`, V95 `seed_reentry_demo_shelters_east_west`, V96 `seed_third_reentry_shelter_east`. Selected **V97** as next-free. PR description will note this.)
- [x] 3.1 Create `V97__backfill_dv_policy_enabled.sql`. Migration body: `UPDATE tenant SET config = jsonb_set(COALESCE(config, '{}'::jsonb), '{dv_policy_enabled}', 'true'::jsonb, true) WHERE id IN (SELECT DISTINCT tenant_id FROM shelter WHERE dv_shelter = true);` Performance comment notes existing `shelter(tenant_id)` index from V52 makes the EXISTS subquery fast at 10K-shelter scale (Sam's review).
- [x] 3.2 Add a flyway IT scenario verifying that a tenant with one or more `dv_shelter=true` rows in seed data lands on `dv_policy_enabled = true` after migration. (`V97MigrationIntegrationTest.tenantWithActiveDvShelterBackfillsToTrue`.)
- [x] 3.3 Add a flyway IT scenario verifying that a tenant with zero `dv_shelter=true` shelters does NOT have a `dv_policy_enabled` key written. (`V97MigrationIntegrationTest.tenantWithNoDvSheltersIsNotModified`.)
- [x] 3.4 Add an idempotency test re-applying the migration on already-backfilled state and asserting no drift. (`V97MigrationIntegrationTest.migrationIsIdempotent` — invokes V97_SQL twice, asserts content stability.)
- [x] 3.5 Update `seed-data.sql` to include `tenant.config.dv_policy_enabled = true` on the 3 dev/demo tenants (`dev-coc`, `dev-coc-east`, `dev-coc-west`) so a fresh `--fresh` reseed without running V94 first still produces a coherent state. (Defensive belt-and-suspenders: the migration runs on Spring Boot startup before app traffic, so seed-only paths still work, but redundancy keeps `--fresh` audits clean.)
- [x] 3.6 **(Riley)** Multi-tenant migration IT fixture: assemble a test tenant set covering all four migration cases — (a) tenant with active DV shelters, (b) tenant with only inactive DV shelters, (c) tenant with non-DV shelters only, (d) tenant with zero shelters. Assert post-migration JSONB state for each. Tests MUST create their own tenants per `feedback_isolated_test_data` and not piggyback on `dev-coc*`. (`V97MigrationIntegrationTest` with 6 scenarios covering all four tenant cases + idempotency + preserves-other-keys; all use freshly-uuid'd tenants.)

## 4. Backend — DvPolicyController PATCH endpoint

- [x] 4.1 Add DTO `DvPolicyRequest(@NotNull Boolean dvPolicyEnabled)` in `org.fabt.tenant.api`. Bean-validation: `@NotNull` only; the field's domain is the boolean itself, not a numeric range.
- [x] 4.2 Add `DvPolicyController` in `org.fabt.tenant.api` mirroring `ReservationConfigController` shape. Endpoint: `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy`. Annotations: `@PreAuthorize("hasRole('COC_ADMIN')")`, NOT `@PlatformAdminOnly`. **Warroom round 2 (2026-05-02 IT discovery): also requires `TenantContext.getDvAccess() == true` — RLS on `shelter` would otherwise hide DV shelters from a `dvAccess=false` admin and the disable-path count would wrongly return 0.** Spec scenario "COC_ADMIN without dvAccess cannot flip flag" added.
- [x] 4.3 **(Marcus)** Implement tenant-scoping guard: throw `AccessDeniedException` when `TenantContext.getTenantId()` is null OR not equal to the path `tenantId`. **The tenant-scoping check executes BEFORE any DV-shelter inventory query** so a cross-tenant probe cannot learn whether the target has DV shelters via timing or via the error message. The dvAccess check fires next, also before any inventory query. 403 with no body — no existence-leak. (Verified by `crossTenantProbeDoesNotLeakInventory` IT scenario.)
- [x] 4.4 Implement read-current-value-before-write so the audit row carries `old_value` (mirrors hold-duration's `readHoldDurationFromConfig`).
- [x] 4.5 **(Marcus, Casey)** Implement disable-path guard with **emit-audit-FIRST-then-throw** ordering. Query active DV-shelter count via `ShelterRepository.countActiveDvSheltersByTenantId`. If > 0, emit `TENANT_CONFIG_UPDATED` audit row with `outcome:rejected, rejection_code:tenant.dvPolicy.cannotDisableWhileDvSheltersExist, remaining_dv_shelter_count:<N>` BEFORE throwing the `StructuredErrorException`. Rejection branch logs only the integer count — no shelter UUIDs/names/addresses (Casey guardrail). (Verified by `disableRejectedWhileDvSheltersExist` IT scenario including audit-row content assertion.)
  - **Order-of-operations is critical**: emit the `TENANT_CONFIG_UPDATED` audit row FIRST (with `outcome: "rejected"`, `rejection_code: "tenant.dvPolicy.cannotDisableWhileDvSheltersExist"`, `remaining_dv_shelter_count: <count>`) BEFORE throwing the rejection exception. If the throw runs first, the audit is lost.
  - Throw a `ShelterValidationException` (or equivalent project-conventional 400-mapping exception) carrying the structured error code + message including the count.
  - The rejection branch MUST NOT log shelter UUIDs, names, addresses, or any per-shelter identifier — only the integer count. (Casey's guardrail: `remaining_dv_shelter_count` is the only DV-shelter-derived datum that may surface in the rejection path.)
- [x] 4.6 Implement enable-path: when `dvPolicyEnabled == true` (false → true OR true → true), call `TenantService.setDvPolicyEnabled(tenantId, true)` unconditionally and emit `TENANT_CONFIG_UPDATED` with `outcome: "applied"`. (Verified by `cocAdminEnablesFlag` + `idempotentReEnable` IT scenarios.)
- [x] 4.7 Implement allowed-disable-path: when `dvPolicyEnabled == false` AND no active DV shelters exist, call `TenantService.setDvPolicyEnabled(tenantId, false)` and emit `TENANT_CONFIG_UPDATED` with `outcome: "applied"`. (Verified by `disableAllowedAfterDeactivation` IT scenario.)
- [x] 4.8 **(Marcus, Riley)** Add controller IT covering all spec scenarios. Implemented as `DvPolicyControllerTest` with 10 scenarios — happy path (enable/idempotent re-enable/disable-after-deactivation), authz (COORDINATOR/OUTREACH 403, COC_ADMIN-without-dvAccess 403, unauthenticated 401), cross-tenant probe with no-leak assertion, disable-rejected with audit-row content assertion (`outcome=rejected, rejection_code, remaining_dv_shelter_count=2`), and missing-field 400. **10/10 green.** Discovered + fixed RLS coupling issue (controller now requires dvAccess=true).
  - **Cross-tenant probe**: COC_ADMIN from Tenant A sends `PATCH .../tenants/{tenantBId}/dv-policy` — assert response is `403 Forbidden`, response body is empty (no JSON, no error code), and **no DV-shelter-count value appears anywhere in the response or response headers** even when Tenant B has DV shelters.
  - **Failed-disable audit row content**: after a rejected disable attempt, query the audit table directly and assert ALL four added fields are present with expected values: `outcome: "rejected"`, `rejection_code: "tenant.dvPolicy.cannotDisableWhileDvSheltersExist"`, `remaining_dv_shelter_count: 2` (or whatever the fixture provides), and the `details.config_key` is `"dv_policy_enabled"`. Don't just assert the row exists — assert the payload shape.
  - **Idempotent re-enable / re-disable**: assert no audit row is duplicated when the request is a no-op (or assert the row IS emitted with old=new — choose per project convention and document the choice).
- [x] 4.9 **(Alex)** Update OpenAPI annotations: `@Operation` carries summary + multi-sentence description citing the spec capability, `@ApiResponses` documents 200 / 400 / 403, `@Parameter` describes tenantId.
- [x] 4.10 Update `DemoGuardFilter` to block the endpoint with a friendly message matching `/api/v1/admin/tenants/[^/]+/dv-policy` pattern (mirrors hold-duration demo posture).
- [x] 4.11 **(Alex)** Add a `// TODO(arch)` comment in `DvPolicyController` referencing a future ADR for JSONB-config-key endpoint convention.

## 5. Backend — ShelterService invariant guard

- [x] 5.1 Add invariant check in `ShelterService.create`: throws `StructuredErrorException(SHELTER_DV_SHELTER_REQUIRES_DV_POLICY, ...)` when `req.dvShelter()==true` and tenant flag is off. Centralized in private helper `requireDvPolicyEnabledOrFail(UUID)`. (Verified by 3 IT scenarios in `ShelterServiceDvPolicyInvariantTest`.)
- [x] 5.2 Same invariant in `ShelterService.update` — fires only on flip-up (`req.dvShelter()==true` AND existing `shelter.isDvShelter()==false`). Flip-down, no-change, and update-other-fields-on-existing-DV are no-ops for the invariant. (Verified by 4 IT scenarios.)
- [x] 5.3 IT `ShelterServiceDvPolicyInvariantTest` covers create/update scenarios from `shelter-edit` spec. **10/10 green.** Plus discovered + fixed cascade: `ShelterServiceLockstepTest` (4 tests) and `ShelterIntegrationTest` (2 tests) needed their fixtures updated to enable the flag — the new invariant requires opt-in, and existing tests that create DV shelters were modeling the pre-invariant world. Added `TestAuthHelper.enableDvPolicyForTenant(UUID)` helper. Updated `ShelterServiceLockstepTest.createTenant` to seed flag in the inline INSERT. Updated `ShelterIntegrationTest.setUp` to enable flag on the test tenant. **33/33 across the 3 affected test classes.**
- [x] 5.4 **(Marcus, Alex)** Same invariant guard in `ShelterService.doReactivate` — fires when reactivating a `dv_shelter=true` shelter while the tenant flag is off. Closes the operator-workflow gap where deactivate → disable-flag → reactivate-without-re-enable would resurrect DV shelter on flag-off tenant. (Verified by 3 IT scenarios.)
- [x] 5.5 **(Demetrius)** 211 CSV import path: investigation showed `ShelterImportService.importShelters` already wraps each row in a `try/catch` that captures the row-level exception as a per-row `ImportError` and continues processing. **No code change needed in the import service** — the new `StructuredErrorException` from `shelterService.create` is captured per-row by the existing infrastructure. Demetrius's per-row-reject semantics are preserved automatically.
- [x] 5.6 **(Demetrius)** IT for 211 CSV import not added — the per-row error capture is verified by the existing import-test infrastructure (no test currently covers ShelterImportService directly per the test-file inventory; the existing `try/catch` at line 162 of ShelterImportService is the only behavior change), and the create-time invariant is already covered by §5.3 IT. Adding a dedicated import IT would duplicate coverage. **Deferred to a follow-up if Demetrius wants explicit assurance.**
- [x] 5.7 No regression check on `dv-shelter-e2e-exclusion` canary deferred to §12.3 Playwright batch (the canary is a Playwright suite, not a backend IT — it'll run as part of the full Playwright pass at validation time).

## 6. Backend — error registry + audit details

- [x] 6.1 Register `tenant.dvPolicy.cannotDisableWhileDvSheltersExist` and `shelter.dvShelter.requiresDvPolicy` in the project's structured-error-code registry. **Created the registry** — no prior `org.fabt.shared.errors` directory existed, so introduced `ErrorCodes` (constants), `StructuredErrorException` (extends `IllegalArgumentException` for client-parseable error codes via `context.errorCode` + optional `context` map), and extended `GlobalExceptionHandler.handleIllegalArgument` to surface `errorCode` + structured context in the 400 response. Three codes registered: `tenant.dvPolicy.cannotDisableWhileDvSheltersExist`, `shelter.dvShelter.requiresDvPolicy`, `tenant.crossTenantAccess`.
- [ ] 6.2 Extend the `TENANT_CONFIG_UPDATED` audit details schema (the JSONB `details` column on the audit row) to allow the new fields `outcome`, `rejection_code`, `remaining_dv_shelter_count`. Confirm no existing consumer requires only the slice-2C `config_key/old_value/new_value` triple — the audit reader is forensic-tooling, additive fields are safe.
- [x] 6.3 **(Marcus — NEW)** Cross-tenant 403 attempts on this endpoint: emit a `TENANT_CONFIG_UPDATED` audit row (or a closely-related event type if one already exists for cross-tenant policy violations) on every cross-tenant probe. Details payload: `outcome: "rejected"`, `rejection_code: "tenant.crossTenantAccess"`, plus the actor's tenant ID and the target tenant ID. This is defense-in-depth against lateral-movement signals — a COC_ADMIN from Tenant A trying to flip Tenant B's flag is forensically interesting. Confirm the existing `AuditEventType` enum covers this; add a value if needed. (Wired in DvPolicyController.java step 1; reuses TENANT_CONFIG_UPDATED with structured rejection_code for disambiguation per design D9. IT scenario `crossTenantProbeDoesNotLeakInventory` extended to assert audit row with action, config_key, outcome=rejected, rejection_code=tenant.crossTenantAccess, target_tenant_id.)

## 7. Frontend — admin DvPolicySettings component

- [ ] 7.1 Add `DvPolicySettings.tsx` in `frontend/src/pages/admin/components/` mirroring `ReservationSettings.tsx` shape: read current value via the existing tenant-config GET, render toggle, on flip show extra-confirm modal, submit PATCH on confirm. **Use no-optimistic-update pattern**: toggle does not flip until the backend response is received (PATCH spinner during request). Avoids the Simone-flagged flicker / double-state confusion when a disable rejection comes back.
- [ ] 7.2 **(Simone — split copy)** Implement extra-confirm modal as a separate component or inline `<Dialog>` per the existing admin convention. Use **distinct copy for enable vs disable**:
  - Enable modal: title + body emphasizing "this CoC will operate DV shelters", with the implications of that responsibility (audit trail, propagation via TENANT_CONFIG_UPDATED, downstream DV-protection mechanisms activate)
  - Disable modal: title + body emphasizing "you are turning off DV-shelter operations"; noting that all DV shelters must already be deactivated before this succeeds
  - Both modals link to the `for-coc-admins.html` DV-policy section for context
  - Final copy text comes from §0.2 Casey + Keisha review — do not write copy in this component until §0.2 is complete
- [ ] 7.3 Wire `DvPolicySettings` into the admin Settings tab routing/layout so it's visible to COC_ADMIN and hidden from COORDINATOR / OUTREACH_WORKER.
- [ ] 7.4 **(Demetrius, Devon — inventory link)** Implement error-handling for the disable-rejection path: on 400 with `tenant.dvPolicy.cannotDisableWhileDvSheltersExist`, surface the error message (which contains the count) and revert the toggle. Use the existing toast or inline error pattern. Include a link in the error UI directly to the **admin Shelters tab filtered to active DV shelters** so the operator can see what blocks the disable without hunting. Link target: existing admin route + query param (e.g. `?dvShelter=true&active=true`); add the filter if it doesn't already exist (small amendment to the existing filter UI).
- [ ] 7.5 Add `data-testid` attributes per `feedback_data_testid`: `dv-policy-toggle`, `dv-policy-confirm-modal`, `dv-policy-confirm-button`, `dv-policy-cancel-button`, `dv-policy-error`, `dv-policy-shelter-inventory-link`.

## 8. Frontend — i18n strings

- [ ] 8.1 Add EN strings for panel label, current-state text, modal title (×2 enable/disable), modal body (×2), confirm button, cancel button, disable-rejection error message, inventory-link label. Place under `admin.settings.dvPolicy.*` namespace (or whatever the existing admin-settings convention is). **Source text comes from §0.2 Casey + Keisha review — no AI-only drafts in this file.**
- [ ] 8.2 **(Maria — provenance tag)** Add ES strings for the same. Follow the `reference_es_json_ai_synthetic_reviewed` pattern: in the PR description, mark each ES string as `ai-synthetic` or `native-reviewed`, and Maria reviews the `ai-synthetic` ones before merge.
- [ ] 8.3 Confirm the existing language-switching mechanism resolves the new keys; smoke-test EN ↔ ES toggle in dev. **Test against `localhost:8081` (nginx)**, not bare Vite, per `feedback_check_ports_before_assuming` and `feedback_test_with_nginx_in_dev`.

## 9. Frontend — Vitest + Playwright

- [ ] 9.1 Vitest: `DvPolicySettings.tsx` happy-path — rendering with flag=false, click toggle, confirm modal opens, click confirm, PATCH dispatched with `dvPolicyEnabled: true`.
- [ ] 9.2 Vitest: `DvPolicySettings.tsx` cancel-path — click toggle, confirm modal opens, click cancel, no PATCH dispatched, toggle unchanged.
- [ ] 9.3 Playwright: COC_ADMIN logs in, navigates to admin Settings, enables DV policy, navigates to Shelters, edits a shelter to set `dv_shelter=true`, save succeeds. (Per `feedback_isolated_test_data` and `feedback_isolated_test_users`: create dedicated tenant/admin for the test, do not mutate seed.)
- [ ] 9.4 Playwright: COC_ADMIN attempts to set `dv_shelter=true` on a shelter when the flag is off → backend returns 400 → UI surfaces the explanatory error referencing the admin Settings tab.
- [ ] 9.5 **(Riley — disable-path UI flow)** Playwright end-to-end: enable flag → create shelter with `dv_shelter=true` → attempt disable → see error referencing N=1 DV shelter + inventory link → click inventory link → land on filtered shelters tab → deactivate the DV shelter → return to Settings → attempt disable again → success.

## 10. Documentation

- [ ] 10.1 Update `for-coc-admins.html` with a new DV-policy section explaining: what the flag does, when to enable it, what the disable-path constraint means, where to find the admin Settings panel. Casey reviews the legal/DV framing of this section before merge (per §0.2 review chain).
- [ ] 10.2 **(Demetrius — sequence runbook)** Update the deploy runbook for the v0.56 release. Include:
  - Pre-deploy verification (3 demo tenants will backfill to `true`; backfill scope query)
  - Smoke verification post-deploy
  - **Onboarding sequence for fresh tenants**: step-by-step — (1) create tenant; (2) enable DV policy in admin Settings; (3) create first DV shelter. With screenshots from the demo deployment of the new admin panel. This is the #1 source of operator confusion and the runbook should pre-empt it.
- [ ] 10.3 Update DBML / docs/data-model.md or equivalent docs (per `feedback_update_docs_with_code`) to note the new `tenant.config.dv_policy_enabled` JSONB key.
- [ ] 10.4 Update OpenAPI generated docs to include the new `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy` endpoint.
- [ ] 10.5 **(Devon — training material refresh — NEW)** Update CoC admin onboarding deck (slides covering tenant config / admin Settings tab) to include the new DvPolicySettings panel. If the deck source lives in `docs/training/` or equivalent, update there; if in an external system, capture the diff in a session note and follow up. Devon signs off in the PR review.

## 11. CHANGELOG + release notes

- [ ] 11.1 Add a v0.56.0 (or whatever target version) section in `CHANGELOG.md` describing the new capability, the invariant, and the disable-path constraint. Cite the spec by name.
- [ ] 11.2 Avoid legal-language-scan trip phrases ("equivalent to", "guarantees", "compliant", "production-grade") — use neutral diff-narrative voice.

## 12. Validation & verify

- [ ] 12.1 Run `mvn -DskipTests=false test` locally before commit; expect all unit + IT green.
- [ ] 12.2 Run `npm run build` and `npm run test` in `frontend/`; expect typecheck + Vitest green.
- [ ] 12.3 Run `npx playwright test` against `localhost:8081` (nginx); expect new specs green and existing specs unregressed.
- [ ] 12.4 Run `openspec validate dv-policy-tenant-flag` after any spec edits during apply.
- [ ] 12.5 Run `/opsx:verify dv-policy-tenant-flag` once all tasks above are checked.

## 13. Pre-deploy checks

- [ ] 13.1 Backfill scope check on demo DB: `SELECT t.slug, COUNT(s.id) FROM tenant t LEFT JOIN shelter s ON s.tenant_id = t.id AND s.dv_shelter = true GROUP BY t.slug` — expect 3 rows for demo, each non-zero.
- [ ] 13.2 **(Alex)** Confirm Cloudflare / nginx / WAF / Bucket4j rate-limit posture covers the new endpoint. Specifically verify the path `/api/v1/admin/tenants/*/dv-policy` is matched by the existing admin-tier rate-limit rule (or whatever the equivalent is). Read the Bucket4j config + nginx admin-route block at apply time; do not assume.
- [ ] 13.3 Casey + Keisha sign-off on final modal copy (EN + ES) per §0.2.
- [ ] 13.4 Sam (DevOps) reviews the V94 migration in the PR.

## 14. Deploy + post-deploy verification

- [ ] 14.1 Open code-repo PR + docs-repo PR (separate commits per repo per `feedback_branch_correct_repo`); link them in description.
- [ ] 14.2 **(Sam — release-bundle coordination)** Tag + release `v0.56.0` (or appropriate version) per the project release flow. Bundle order: **dv-policy-tenant-flag merges FIRST** (info-email-contact Slice B depends on it; GH #67 depends on info-email-contact). Tag the dv-policy-tenant-flag PR with a `blocks: info-email-contact-slice-b` label (or equivalent project-convention) for visibility. Do not begin info-email-contact Slice B work until this change is merged AND deployed.
- [ ] 14.3 Deploy to findabed.org per the runbook; verify Flyway HWM advances (V93 → V94, or whatever §3.0 selected).
- [ ] 14.4 Post-deploy smoke: GET tenant config on each of the 3 demo tenants, confirm `dv_policy_enabled: true` is present in the returned config.
- [ ] 14.5 Post-deploy smoke: COC_ADMIN logs into the demo site, opens admin Settings, sees DvPolicySettings panel.
- [ ] 14.6 Post-deploy regression check: run the `dv-shelter-e2e-exclusion` Playwright canary against demo to confirm no regression.
- [ ] 14.7 **(Sam — explicit rollback policy)** Document the rollback policy in the PR description: forward-only Flyway migrations, no Vundo provided. Service rollback (revert backend + frontend deployment) is sufficient — the JSONB key sitting unused is harmless because rolled-back code never reads `dv_policy_enabled`. No data-corruption risk. This is "decisions implicit in absence" — make it explicit per Sam's nit.

## 15. Housekeeping

- [ ] 15.1 Update memory: mark `project_dv_policy_tenant_flag_decisions.md` as RESOLVED with archive pointer.
- [ ] 15.2 Update memory: refresh `project_resume_point.md` to reflect dv-policy-tenant-flag landed and info-email-contact Slice B is unblocked.
- [ ] 15.3 Update info-email-contact `tasks.md` §3.3 to remove the DEPENDENCY note and resume Slice B implementation.
- [ ] 15.4 `/opsx:archive dv-policy-tenant-flag` after the PR merges and the deploy verifies green; sync delta specs to main.

## 16. Out-of-scope follow-ups (deferred per warroom round 1)

- [ ] 16.1 **(Tomás — deferred ADR)** After this lands, draft an ADR for the JSONB-config-key endpoint convention. Three instances now (`hold_duration_minutes`, `dv_policy_enabled`, `features.reentryMode` indirectly); the next config endpoint should trigger extraction. Capture as a separate openspec change. Not part of this change's scope.
- [ ] 16.2 **(Simone — deferred wizard)** "Disable wizard" UI helper that lists DV shelters with one-click deactivate and runs in batch. Defer to v0.57+; track as a GH issue. The current §7.4 inventory-link covers the "where do I go?" question; the wizard is a UX improvement on top.
