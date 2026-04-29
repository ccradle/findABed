## 0. Scaffolding status

- [x] 0.1 Feature branch `feature/transitional-reentry-support` created in code repo (2026-04-24 post-v0.51.0)
- [x] 0.2 Migration numbering renumbered twice: V79–V82 → V85–V88 (post-v0.51.0 Phase F) → **V91–V94** (2026-04-26, Phase G consumed V85/V87/V88/V89). Final slot assignments live in §2 below; design.md migration plan + every spec/* reference matches.
- [x] 0.3 Design open questions #1 + #2 resolved (500-char UI / 1000-char server hold note; county detail-card only)
- [x] 0.4 Design open question #4 resolved (features.reentryMode scoped into V91)
- [x] 0.5 Design open question #5 resolved to **Option A** (tenant_dek-wrapped ciphertext) via issue #152, closed 2026-04-24. V93 bundles tenant_dek.purpose CHECK update + reservation column adds. See §2.3 for shape.
- [x] 0.6 Casey Drummond i18n legal review of EN+ES disclaimer strings: **DONE 2026-04-28** — reviewed strings captured at `i18n-legal-review-strings.md` in this change directory. Implementor MUST use those strings verbatim for `shelter.criminalRecordPolicyDisclaimer`, `shelter.vawaNoteDisclaimer`, `shelter.vawaProtectionsApplyNote`, `hold.clientAttributionPrivacyNote`. Task 15.6 retained as final pre-merge sign-off (any string drift during implementation triggers re-review).
- [x] 0.7 ~~Clarify Asheville stakeholder messaging posture~~ — **N/A per Corey 2026-04-26**: there is no Asheville implementation; this comms-posture concern doesn't apply. Item dropped.
- [x] 0.8 Re-verify Flyway HWM after Phase G tags — **DONE 2026-04-26**: Phase G claimed V85/V87/V88/V89; reentry migrations renumbered to **V91 / V92 / V93 / V94**. All references in proposal.md, design.md, tasks.md §2, and specs/* updated in the same commit. Reference: memory `project_reentry_spec_renumber.md`.

## 1. Pre-flight

- [x] 1.1 **DONE 2026-04-28**: feature branch `feature/transitional-reentry-support` confirmed (created 2026-04-24); main merged in (now at v0.54.0 commit `12d10ab`).
- [x] 1.2 **DONE 2026-04-28**: live HWM is V90 post-v0.54 (per `project_live_deployment_status.md`). Filesystem highest is also V90. Reentry slots V91-V94 are open as planned.
- [x] 1.3 **DONE 2026-04-28**: Option A re-confirmed; V93 written per §2.3 (tenant_dek.purpose CHECK update + 3 reservation `_encrypted` columns).

## 2. Database Migrations

- [x] 2.1 **DONE 2026-04-28** — `V91__shelter_type_county_and_reentry_flag.sql` written: shelter_type VARCHAR(50) DEFAULT 'EMERGENCY', county VARCHAR(100) nullable + partial index (V55-style precedent, county is sparse at launch), backfill UPDATE for dvShelter=true rows, CHECK constraint `shelter_dv_implies_dv_type`, and tenant.config.features.reentryMode = false seed via `||` jsonb-concat pattern.
- [x] 2.2 **DONE 2026-04-28** — `V92__eligibility_criteria_jsonb.sql` written. Deviated from spec wording: used plain `CREATE INDEX` (not CONCURRENTLY) per V55 precedent line 54-59 — Flyway wraps migrations in a transaction, CONCURRENTLY is incompatible, and at FABT scale plain CREATE INDEX is fast. Migration header documents the deviation.
- [x] 2.3 **DONE 2026-04-28** — `V93__reservation_pii_encrypted.sql` written: tenant_dek.purpose CHECK extended to include RESERVATION_PII via DROP/ADD pattern; three `_encrypted` TEXT columns added to reservation. All commented for shred-path traceability.
- [x] 2.3a **DONE 2026-04-28** — `KeyPurpose.RESERVATION_PII` added with throwing resolver (random-DEK only; HKDF-derive path explicitly unsupported). Required updating `NTenantCanaryShredTest`'s exhaustive switch with a TODO referencing slice 2 task 13.13 for proper canary coverage of the new purpose.
- [x] 2.3b **DONE 2026-04-28** — `org.fabt.shelter.county.NcCountyDefaults` constant (immutable List<String> of 100 NC counties) created.
- [x] 2.4 **DONE 2026-04-28** — `V94__shelter_requires_verification_call.sql` written: BOOLEAN NOT NULL DEFAULT FALSE.
- [x] 2.5 **DONE 2026-04-28** — `V91MigrationVerificationTest` (9 tests) covers: schema introspection (column existence, default, constraint registered in pg_constraint), behavioral CHECK enforcement (rejects diverged INSERT/UPDATE within `TenantContext.runWithContext`, accepts consistent writes), county round-trip, and the V91 jsonb-seed pattern producing `features.reentryMode = false`. All 9 GREEN against the post-migration schema.

## 3. Backend: Domain Model

- [x] 3.1 **DONE 2026-04-28** (slice 1 expansion per warroom decision C) — `ShelterType` enum at `org.fabt.shelter.domain.ShelterType` with all 8 values. Spec D2 documented as "self-reported classification" (no compliance claim).
- [x] 3.2 **PARTIAL DONE 2026-04-28** (slice 1 expansion per warroom decision C) — `shelterType` field + getter/setter added to `Shelter` entity, defaults to `ShelterType.EMERGENCY`. Spring Data JDBC auto-maps via column-name convention (no explicit row mapper needed). **`county` deferred to slice 2** — not needed yet because nothing reads/writes it; the column exists but the entity doesn't surface it.
- [ ] 3.3 Add `requiresVerificationCall` boolean to `Shelter` entity; update row mapper
- [ ] 3.4 Add `EligibilityCriteria` JSONB value type (record/class) with `CriminalRecordPolicy` sub-type; add to `ShelterConstraints` entity; JSONB serialization via `ObjectMapper`
- [ ] 3.5 Add `heldForClientName`, `heldForClientDob`, `holdNotes` fields to `Reservation` entity as plaintext Java types (String / LocalDate / String). **Domain layer holds plaintext; DB columns are the `_encrypted` siblings** (same pattern as `app_user.totpSecret` ↔ `totp_secret_encrypted`). Row mapper calls `SecretEncryptionService.decryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, columnValue)` on read; writer calls `encryptForTenant(...)` on write. Null-safe: null columns map to null fields without attempting decrypt.

## 4. Backend: Service and Repository Layer

- [ ] 4.1 `BedSearchService`: add `shelterType` filter (enum, optional, multi-value); add `county` filter (string, case-insensitive, optional); add `acceptsFelonies` filter (boolean, optional — queries `eligibility_criteria->'criminal_record_policy'->>'accepts_felonies'`); update `BedSearchParams` record
- [ ] 4.2 `BedSearchService`: implement the **three-way `acceptsFelonies=true` filter logic** per design D1 H1 revision: (a) explicit `eligibility_criteria.criminal_record_policy.accepts_felonies = false` → EXCLUDE; (b) explicit `accepts_felonies = true` → INCLUDE; (c) eligibility_criteria/criminal_record_policy/accepts_felonies any-null → INCLUDE if `requires_verification_call = true` on the shelter (UI annotates with "call to verify" badge), else EXCLUDE. **SQL pattern (revised slice-1 warroom H4 to leverage V92 GIN index):** use containment, NOT extraction — `eligibility_criteria @> '{"criminal_record_policy": {"accepts_felonies": true}}'::jsonb OR (eligibility_criteria IS NULL AND requires_verification_call = TRUE)`. The `->` and `->>` extraction operators bypass the GIN index entirely (default `jsonb_ops` only supports `@>`, `?`, `?|`, `?&`); see `V92IndexVerificationTest` JavaDoc and `feedback_pgstat_for_index_validation.md`. Test 13.4 must cover all three branches AND verify pg_stat_statements shows the GIN index actually being used at pilot-shape data volumes.
- [ ] 4.3 `ShelterService`/`ShelterRepository`: persist `shelterType`, `county`, `eligibilityCriteria`, `requiresVerificationCall` on PUT/PATCH; validate `shelterType` against enum; validate `county` against `tenant.config.active_counties` if configured; enforce `dvShelter=true` implies `shelterType=DV` at application layer. **PARTIAL DONE 2026-04-28** (slice 1 expansion per warroom decision C): `ShelterService.create()` and `update()` already enforce the `dvShelter ↔ shelterType` lockstep so the V91 CHECK constraint can never reject ShelterService writes. Remaining for slice 2: persist `county` / `eligibilityCriteria` / `requiresVerificationCall` from request DTOs, and validate `shelterType` and `county` against their controlled sources.
- [ ] 4.4 `ReservationService`: persist `heldForClientName`, `heldForClientDob`, `holdNotes` from hold creation request via `SecretEncryptionService.encryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, plaintext)`. Store the resulting v1 envelope in the `_encrypted` columns. Validate `heldForClientDob` is before today and after 1900-01-01 BEFORE encryption (plaintext validation only). `dob` is serialized to ISO-8601 string before encryption (`LocalDate.toString()` round-trips cleanly).
- [ ] 4.5 Add `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration` endpoint: accepts `holdDurationMinutes` integer (30–480), updates `tenant.config.holdDurationMinutes`, requires COC_ADMIN role; hold duration change applies to new holds only. **NOT** annotated `@PlatformAdminOnly` — therefore Phase G's `JustificationValidationFilter` does NOT apply (no `X-Platform-Justification` header required). Audit via standard `AuditEventType.TENANT_CONFIG_UPDATED`.
- [ ] 4.5a Add a `DemoGuardFilter.getBlockMessage()` branch matching `/api/v1/admin/tenants/[^/]+/hold-duration`: return "Hold duration changes are disabled in the demo environment — would affect other visitors' reservation flow." Without this branch the operator hits the generic `/api/v1/tenants/...` block message ("Tenant management is disabled..."), which is misleading because this is reservation config, not tenant lifecycle. Endpoint is intentionally NOT added to `ALLOWED_MUTATIONS` per design D5 H4 revision.
- [ ] 4.6 Extend the existing `org.fabt.referral.service.ReferralTokenPurgeService` (verified live 2026-04-28: runs hourly via `@Scheduled(fixedRate = 3_600_000)`) to also null `held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `hold_notes_encrypted` on reservation records where resolution time + 24h has passed. The job nulls the **ciphertext** columns (it has no key material and no need for it — NULL is NULL regardless of what was encrypted). Logic must be null-safe on pre-V93 databases (no-op if columns not present). **TenantContext binding**: existing service binds with `dvAccess=true` for the DV referral path; reservation PII purge needs the standard tenant-data binding pattern (NOT `dvAccess=true`). Add a separate `@Scheduled` method or branch within the existing class — do NOT spin up a new `@Service` (operational simplicity: one purge surface, one log line per run).

## 5. Backend: API Layer and DTOs

- [ ] 5.1 `BedSearchController`: expose `shelterType`, `county`, `acceptsFelonies` as query parameters on `GET /api/v1/beds/search`; document in OpenAPI spec
- [ ] 5.2 Bed search response DTO: include `shelterType`, `county`, `eligibilityCriteria` (full object), `requiresVerificationCall`, `acceptsFelonies` (derived from JSONB for convenience)
- [ ] 5.3 Shelter detail response DTO (`GET /api/v1/shelters/{id}`): include all new fields
- [ ] 5.4 Shelter write DTO (`PUT/PATCH /api/v1/shelters/{id}`): include `shelterType`, `county`, `eligibilityCriteria`, `requiresVerificationCall`
- [ ] 5.5 Reservation create request DTO: add optional `heldForClientName`, `heldForClientDob`, `holdNotes`; reservation response DTO: include new fields
- [ ] 5.6 Hold duration admin endpoint DTO: `HoldDurationRequest { holdDurationMinutes: int }` with validation 30–480
- [ ] 5.7 Update DBML and OpenAPI docs for all new fields and endpoints (per `feedback_update_docs_with_code.md`)

## 6. Frontend: i18n Keys

- [ ] 6.1 Add shelter type keys to `en.json` and `es.json`: `shelter.type.EMERGENCY`, `shelter.type.DV`, `shelter.type.TRANSITIONAL`, `shelter.type.SUBSTANCE_USE_TREATMENT`, `shelter.type.MENTAL_HEALTH_TREATMENT`, `shelter.type.REENTRY_TRANSITIONAL`, `shelter.type.PERMANENT_SUPPORTIVE`, `shelter.type.RAPID_REHOUSING`
- [ ] 6.2 Add criminal record policy keys: `shelter.acceptsFelonies`, `shelter.excludedOffenseTypes`, `shelter.requiresVerificationCall`, `shelter.county`, `shelter.criminalRecordPolicyDisclaimer`, `shelter.vawaNoteDisclaimer`, `shelter.vawaProtectionsApplyNote` — EN and ES; labels use dignity-centered language ("Accepts individuals with felony convictions", not "accepts felons"); flag for Casey Drummond legal review before merge; `shelter.vawaProtectionsApplyNote` is the form-level contextual note shown when the admin enables the VAWA protections checkbox (distinct from `shelter.vawaNoteDisclaimer` shown to search users)
- [ ] 6.3 Add offense type vocabulary keys: `offenseType.SEX_OFFENSE`, `offenseType.ARSON`, `offenseType.DRUG_MANUFACTURING`, `offenseType.VIOLENT_FELONY`, `offenseType.PENDING_CHARGES`, `offenseType.OPEN_WARRANTS` — EN and ES display labels
- [ ] 6.4 Add hold attribution keys: `hold.heldForClientName`, `hold.heldForClientNameSublabel`, `hold.heldForClientDob`, `hold.heldForClientDobSublabel`, `hold.notes`, `hold.clientAttributionPrivacyNote` — EN and ES; use dignity-centered framing per D4; `hold.clientAttributionPrivacyNote` must state 24h post-resolution PII purge in plain language
- [ ] 6.5 Add admin keys: `admin.holdDurationMinutes`, `admin.eligibilityCriteria`, `admin.requiresVerificationCall`, `search.filterByCounty`, `search.filterByShelterType`, `search.acceptsFelonies`, `search.advancedFilters` — EN and ES
- [ ] 6.6 Run `npm run build` to verify no missing i18n keys cause build failures before proceeding

## 7. Frontend: CriminalRecordPolicyDisclaimer Component

- [ ] 7.1 Create `CriminalRecordPolicyDisclaimer` React component: renders `shelter.criminalRecordPolicyDisclaimer` i18n text; `role="note"` ARIA attribute; non-dismissable (no close button); accessible at 400% zoom and in dark mode with passing contrast
- [ ] 7.2 Add conditional VAWA note: when `vawa_protections_apply = true` prop is passed, additionally render `shelter.vawaNoteDisclaimer`
- [ ] 7.3 Write CI guard job at `scripts/ci/check-criminal-record-disclaimer-co-rendering.sh` modeled on existing `scripts/ci/check-flyway-migration-versions.sh` + `phase-b-rls-test-discipline` pattern. Logic: any `.tsx`/`.jsx` file under `frontend/src/` containing a non-comment-line match for `criminal_record_policy`, `accepts_felonies`, or `excluded_offense_types` MUST also contain a non-comment-line match for `<CriminalRecordPolicyDisclaimer`. False-positive guard: use `grep -vE '^\s*(\*|//|/\*)'` to filter out comment lines BEFORE matching. Test coverage: write a fixture spec under `scripts/ci/fixtures/` exercising (a) raw-prop-no-disclaimer (FAIL expected), (b) raw-prop-with-disclaimer (PASS expected), (c) comment-only-mention (PASS expected — the script must not flag JSDoc / inline comments containing the token names).
- [ ] 7.4 NVDA/VoiceOver spot-check: disclaimer is announced after the criminal record policy data it annotates; screen reader does not skip it

## 8. Frontend: Shelter Type Taxonomy UI

- [ ] 8.1 Add `shelterType` field display to shelter search result cards (summary view)
- [ ] 8.2 Add `shelter_type` dropdown to admin shelter edit form; prevent selecting DV without `dvShelter=true` (tooltip: "Set the DV Shelter toggle to enable DV type")
- [ ] 8.3 Add `shelterType` multi-select filter to `OutreachSearch.tsx` filter bar (desktop) and advanced filters section (mobile)

## 9. Frontend: Supervision County Filter UI

- [ ] 9.1 Add `county` field to admin shelter edit form (dropdown filtered to `tenant.config.active_counties`; optional)
- [ ] 9.2 Add `county` display to shelter search result cards (in expanded/detail view; not summary)
- [ ] 9.3 Add `county` filter to `OutreachSearch.tsx` advanced filters section (collapsed by default on mobile, expanded on desktop); persistent `<label>` with `htmlFor` association

## 10. Frontend: Extended Eligibility Criteria UI

- [ ] 10.1 Add "Eligibility Criteria" section to `ShelterEditPage.tsx` / admin shelter form — visible to COC_ADMIN and PLATFORM_ADMIN only; not visible to COORDINATOR
- [ ] 10.2 Criminal record policy sub-section: `accepts_felonies` toggle (label: "Accepts individuals with felony convictions"), `excluded_offense_types` multi-select using controlled vocabulary with localized display labels, `individualized_assessment` toggle, `vawa_protections_apply` checkbox, notes text field
- [ ] 10.3 Program requirements, documentation required, intake hours fields (tag editor for arrays, text field for hours)
- [ ] 10.4 All eligibility criteria fields labeled "Optional"; empty state displays "Not specified" in read-only views
- [ ] 10.5 `CriminalRecordPolicyDisclaimer` rendered within the eligibility criteria section
- [ ] 10.6 `requires_verification_call` toggle in shelter edit form; "Requires verification call" badge rendered on shelter search result cards when true
- [ ] 10.7 Eligibility criteria display in expanded shelter card in `OutreachSearch.tsx`: show `program_requirements`, `intake_hours`, criminal record policy summary

## 11. Frontend: Navigator Hold Dialog

- [ ] 11.1 Add optional "For shelter coordination" section to hold creation dialog: "Who is this hold for?" name field, date of birth field, note for shelter coordinator text field
- [ ] 11.2 Labels use dignity-centered framing per D4 (task 6.4 i18n keys)
- [ ] 11.3 Client attribution section collapsed by default with "Add client details (optional)" toggle to keep the default flow uncluttered
- [ ] 11.4 `heldForClientDob` date input: UI validation prevents future dates and dates before 1900-01-01
- [ ] 11.5 Coordinator dashboard hold display: show client name alongside hold if `heldForClientName` is present; omit field entirely when null (not "N/A" or empty)

## 12. Frontend: Admin ReservationSettings Panel

- [ ] 12.1 Wire `ReservationSettings` admin component (stub exists) to `GET /api/v1/admin/tenants/{tenantId}` hold duration config and `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration`
- [ ] 12.2 Range: 30–480 minutes; validation error message: "Hold duration must be between 30 and 480 minutes"
- [ ] 12.3 Confirmation on save; success toast shows new duration; no page reload required

## 13. Backend Integration Tests

- [ ] 13.1 Bed search: `shelterType` filter returns correct types, excludes others
- [ ] 13.2 Bed search: `county` filter matches case-insensitively, excludes null-county shelters
- [ ] 13.3 Bed search: `acceptsFelonies=true` returns shelters with `accepts_felonies=true` in JSONB; excludes null-eligibility shelters
- [ ] 13.4 Bed search: `accepts_felonies=true` AND `requires_verification_call=true` — shelter appears in filtered results with both flags present in response
- [ ] 13.5 Hold with navigator attribution: `heldForClientName`, `heldForClientDob`, `holdNotes` persisted and returned in hold detail
- [ ] 13.6 Hold attribution `heldForClientDob` future date rejected with 400
- [ ] 13.7 Hold duration change via admin endpoint: in-flight holds retain original `expires_at`; new holds created after the change use new duration
- [ ] 13.8 Hold duration endpoint: OUTREACH_WORKER and COORDINATOR receive 403; COC_ADMIN succeeds
- [ ] 13.9 Spring Batch cleanup: after simulated 24h post-expiry, `heldForClientName`, `heldForClientDob`, `holdNotes` are null; other reservation fields preserved
- [ ] 13.10 V91 migration backfill: all `dvShelter=true` rows have `shelter_type='DV'`; DB constraint rejects diverged updates
- [ ] 13.11 Cross-tenant isolation: `eligibility_criteria` on Shelter from Tenant A not returned in Tenant B queries
- [ ] 13.12 Cross-tenant isolation: `heldForClientName` on Reservation from Tenant A not accessible from Tenant B session

- [ ] 13.13 **[Option A encryption invariants]** Round-trip integration test: Tenant A encrypt `heldForClientName` = "Probe-<UUID>", read back via the row mapper's `decryptForTenant` path, assert plaintext matches. Bypass the service: load ciphertext directly from DB, assert it does NOT equal plaintext (proves at-rest ciphertext). Attempt `decryptForTenant` with Tenant B context on Tenant A's ciphertext: assert `CrossTenantCiphertextException` (inherits Phase F-6 kid-check at `backend/src/main/java/org/fabt/shared/security/CrossTenantCiphertextException.java`, verified live 2026-04-28). This exercises the exact invariant pass-2 Marcus required.
- [ ] 13.14 `shelterType=DV` filter combined with `dvShelter=false` never returns a DV shelter (DV access control unaffected by new filter)

## 14. Playwright E2E Tests

- [ ] 14.1 Shelter type filter in bed search: selecting TRANSITIONAL shows only transitional housing, hides EMERGENCY
- [ ] 14.2 County filter in bed search: selecting a county filters results; deselecting returns all
- [ ] 14.3 `CriminalRecordPolicyDisclaimer` renders when criminal record fields are present in search result card
- [ ] 14.4 Disclaimer absent when shelter card shows no criminal record fields (no `eligibility_criteria`)
- [ ] 14.5 Hold dialog: opening optional "Add client details" section shows name/DOB/notes fields; submitting hold with values succeeds and coordinator dashboard shows client name
- [ ] 14.6 Admin panel: hold duration change persists — set to 180 min, confirm, open new hold, verify confirmation message shows 180 min
- [ ] 14.7 `requires_verification_call` badge renders on shelter card when true; absent when false
- [ ] 14.8 Advanced filters section on mobile viewport: collapsed by default; expanding reveals county, shelter type, accepts-felonies filters
- [ ] 14.9 Eligibility criteria section visible for COC_ADMIN in shelter edit form; not visible for COORDINATOR role
- [ ] 14.10 VAWA note renders alongside base disclaimer when `vawa_protections_apply = true`
- [ ] 14.11 All new Playwright tests create their own data (no dependency on seed state, per `feedback_isolated_test_data.md`)
- [ ] 14.12 Integrated navigator end-to-end (Demetrius scenario): (1) outreach worker applies county=Johnston + shelterType=REENTRY_TRANSITIONAL + acceptsFelonies=true filters and confirms matching shelter appears in results; (2) opens hold dialog, expands "Add client details (optional)", verifies `hold.clientAttributionPrivacyNote` is visible, enters name/DOB/notes; (3) submits hold; (4) signs in as shelter coordinator and verifies dashboard shows client name alongside the hold; completes the full three-filter → hold-with-attribution → coordinator-view chain
- [ ] 14.12a (M4 warroom 2026-04-28) Extend `infra/scripts/seed-data.sql` with the 14.12 fixture: (a) one shelter row in dev-coc tenant with `county='Johnston'`, `shelter_type='REENTRY_TRANSITIONAL'`, `requires_verification_call=false`, and `eligibility_criteria.criminal_record_policy.accepts_felonies=true`; (b) ensure `dev-coc.tenant.config.active_counties` includes `'Johnston'` (otherwise the county filter validation in task 4.3 rejects it). Tag the rows with a SQL comment `-- TEST FIXTURE: do not remove without updating tasks.md §14.12`.

## 15. Build and Release Verification

- [ ] 15.1 `npm run build` (tsc + vite) passes with no errors before any commit (per `feedback_build_before_commit.md`)
- [ ] 15.2 CI guard job for disclaimer co-rendering passes on PR (task 7.3)
- [ ] 15.3 Update `CHANGELOG.md` with feature summary
- [ ] 15.4 Bump `backend/pom.xml` version for release (confirm version number at tag time)
- [ ] 15.5 Update DBML and AsyncAPI/OpenAPI docs for all new fields (per `feedback_update_docs_with_code.md`)
- [ ] 15.6 Casey Drummond legal review: final EN and ES i18n strings for `shelter.criminalRecordPolicyDisclaimer` and `shelter.vawaNoteDisclaimer` signed off before merge
- [ ] 15.7 `make rehearse-deploy` PASS before tagging release. Note: rehearsal harness has known lingering containers (mailpit, prometheus, alertmanager) per `feedback_deploy_rehearsal_lessons.md` — manual `docker stop && docker rm` post-run is expected; not a regression.
- [ ] 15.8 (M3 warroom 2026-04-28) Author `docs/operations/reentry-mode-user-guide.md` covering: (a) how to enable `features.reentryMode` for a tenant (PLATFORM_OPERATOR action via lifecycle endpoints); (b) how PLATFORM_OPERATOR seeds / overrides `tenant.config.active_counties`; (c) how COC_ADMIN populates `eligibility_criteria` JSONB via the guided form; (d) how outreach workers / navigators use the new advanced filters + hold-with-attribution flow; (e) the 24h PII purge promise (when, what, how to verify in logs); (f) what `requires_verification_call=true` means for navigators and how it interacts with the `acceptsFelonies` filter. Pattern: same shape as `docs/operations/platform-operator-user-guide.md` shipped in F11.

## 16. Slice-1 warroom (2026-04-28) deferred follow-ups

Items raised in the slice-1 warroom that landed in slice 1 ARE flipped above; items deferred to later slices live here so a future warroom round can reopen them by name.

- [ ] 16.M1 (slice 2) — `KeyPurpose.RESERVATION_PII` resolver throws `UnsupportedOperationException`. Currently unreachable. Slice 2 task 4.4 (`ReservationService` PII encryption) is the first production caller of `encryptForTenant(tenantId, RESERVATION_PII, ...)`; that task must include an integration test that exercises encrypt → store → load → decrypt round-trip end-to-end.
- [ ] 16.M2 (slice 2) — `NTenantCanaryShredTest` switch case for `RESERVATION_PII` is a "should never reach here" marker (TODO inline at line 228-244). Slice 2 task 13.13 must extend canary coverage to `RESERVATION_PII`. The HKDF-bypass adversary half of the canary doesn't apply (no HKDF derive method exists); slice 2 needs a different proof shape — e.g., happy-path-decrypt-fails-after-shred (still proves crypto-shred for the random-DEK path) plus a `CrossTenantCiphertextException` assertion (proves the kid-check inherits Phase F-6 behavior).
- [ ] 16.N1 (slice 2 design.md sweep) — design.md line 185 historical "Phase G ships at HWM V89" language is now stale (Phase G + F11 both shipped; live HWM is V90). Update during slice 2's design.md edits.
- [ ] 16.N2 (slice 2 unit test) — `tenant.config` JSONB array compatibility is unverified for `active_counties`. Existing JSONB column accepts `'[]'::jsonb` in principle but no test confirms. Slice 2 task 4.5 (admin endpoint) is a natural place to lock this in.
- [ ] 16.N3 (slice 2 spec note) — `V91MigrationVerificationTest` documents that V91 partial county index `idx_shelter_tenant_county` uses `(tenant_id, county)` ordering. Single-tenant queries that filter by county-only (no tenant filter) won't hit the index. RLS + service-layer always include tenant filter, so this is correct — but worth noting in `BedSearchService` design comments.
- M4 (NOT a real concern; left here for warroom traceability) — slice-1 warroom flagged "behavior of `shelterType` on entities loaded BEFORE my Java changes shipped." Investigation showed this is a non-issue: when slice 1 deploys, the JVM restarts with the new entity definition; first read post-restart goes through the new mapper correctly.

## 17. Slice-2 warroom (2026-04-29) deferred follow-ups

Items raised in the slice-2 warroom (post-implementation review of slice 2A entity additions + slice 2B-partial BedSearchService filters + ShelterService persistence). B1, B2, H4 landed in slice 2; the rest are documented here so a future warroom round can reopen them by name.

### Resolved in slice 2 (already landed)

- [x] 17.B1 — **DONE 2026-04-29**: `ReservationRepository.encryptIfPresent` no longer silently no-ops on null tenantId; throws `IllegalStateException` instead so a missing-tenantId programming error surfaces at the encryption boundary rather than as silent NULL data loss.
- [x] 17.B2 — **DONE 2026-04-29**: replaced unbounded per-shelter `log.warn` in `BedSearchService.readAcceptsFeloniesFromConstraints` with `ObservabilityMetrics.eligibilityCriteriaParseFailureCounter()` (Micrometer counter, tenant-tagged, no shelter_id per cardinality precedent). `log.warn` downgraded to `log.debug` for operator-driven investigation. Fail-open behavior (parse failure → null → routes to (c) any-null branch) is now a documented decision in the inline comment, not a coincidence of code structure.
- [x] 17.H4 — **DONE 2026-04-29**: V92 header comment updated with explicit "currently un-consumed" note. Documents the slice-5 SQL-refactor activation path + the canonical `@>` containment query + why we keep the index now (cheap insurance vs. CONCURRENTLY-on-populated-data risk later).

### Slice 2C / 2D (load-bearing — block slice-2 merge)

- [ ] 17.H1 (slice 2D §13) — **No targeted tests for new BedSearchService filter behavior**. The 1320-green test count proves NO REGRESSION (no existing test uses these filters because they didn't exist), NOT correctness. Slice 2D §13.1-13.4 must add 5+ dedicated tests covering: shelterType exact match, county case-insensitive match, acceptsFelonies branch (a) explicit-false-excludes, branch (b) explicit-true-includes, branch (c) null-with-sentinel-includes-vs-null-without-sentinel-excludes. Cannot merge slice 2 to main without these.

- [ ] 17.H2 (slice 2D refactor) — **Three-way `acceptsFelonies` logic data dependency spans two tables (`shelter_constraints.eligibility_criteria` + `shelter.requires_verification_call`); no class captures the contract**. Extract a small `AcceptsFeloniesEvaluator` that takes `(ShelterConstraints, Shelter)` → `Decision { INCLUDE, EXCLUDE }`. JavaDoc references design D1 H1 + commented decision tree (a/b/c). Slice 2D unit tests against this evaluator directly. Bonus: when slice 5 adds the SQL filter path, both code paths can produce the same Decision for the same input (testable equivalence).

- [ ] 17.H3 (slice 2D unit test) — **No targeted tests for `ShelterService.isValidCounty` 4-branch state machine**: (1) county null → true; (2) tenant config has `active_counties = []` → true; (3) `active_counties = [...list]` → match-or-miss; (4) `active_counties` key absent → fall back to `NcCountyDefaults`. Add focused unit test exercising all 4 branches; include boundary cases (county NOT in NC defaults but config explicitly empty → accept; county IN NC defaults but config explicitly excludes → reject).

### Slice 4 / 5 (UX + ops)

- [ ] 17.M1 (slice 4 frontend) — **`acceptsFelonies` "0 results at launch" UX landmine**. At launch most shelters have null `eligibility_criteria` AND `requires_verification_call=false`; a coordinator filtering `acceptsFelonies=true` sees an empty result set and can reasonably misread it as "no shelters in our area accept people with felonies" — which is FALSE; the actual interpretation is "we don't have data for most shelters." Slice 4 frontend should surface a banner when filter yields 0 results: "Filtering by 'accepts felonies' may exclude shelters with incomplete eligibility data. Set 'requires verification call' = true on shelters with unknown policy to surface them with a 'call to verify' badge."

- [ ] 17.M2 (slice 4 i18n + backend exception refactor) — **Backend "Invalid county" error is operator-cryptic**. `ShelterService.create/update` throws `IllegalArgumentException("Invalid county 'X' for tenant; not in active_counties")` reaching the user as 400 Bad Request body. A COC_ADMIN doesn't know what `active_counties` is or how to fix it. Slice 4: introduce `CountyNotConfiguredException` → global handler maps to i18n key `error.shelter.county_not_configured` ("County '{0}' is not configured for your CoC. Contact your platform operator to add it.").

- [ ] 17.M3 (slice 4 backlog OR slice-2 carryover) — **`UpdateShelterRequest` cannot CLEAR fields**. PATCH semantics: null = "leave unchanged." A COC_ADMIN wanting to remove a previously-set county has no path through this DTO. Documented limitation. Slice 4 may need a sentinel pattern (`""` empty string = clear) OR a separate explicit clear-field endpoint. Worth a Marcus-Webb / Casey-Drummond pass before deciding the shape.

- [ ] 17.M4 (slice 5 perf) — **`tenantService.findById` fires per shelter create/update**. Bulk operations (211 imports, future bulk-edit features) cause N redundant tenant config reads. Add request-scoped caching (e.g., `@RequestScope` parsed-tenant-config bean). Don't optimize until pilot-scale measurement justifies it.

- [ ] 17.M5 (slice 2D test design) — **`BedSearchService` constructor now has 7 parameters**. Future per-method unit tests need to mock all 7 (including `ObjectMapper`). When slice 2D adds focused filter tests, see 17.H2 — the extracted `AcceptsFeloniesEvaluator` is a cheap test target without the full BedSearchService graph.

### NITs (track but don't gate)

- [ ] 17.N1 (codebase-wide policy decision) — **Reservation entity holds plaintext while User entity holds encrypted**. Documented in JavaDoc as intentional but it's a cross-codebase inconsistency. Future warroom round: pick one direction and standardize.

- [ ] 17.N2 (deferred ergonomics) — **5 callsites of `BedSearchRequest` manually null-padded for the new fields**. Records are explicit (good for compile-time safety) but each new field forces N callsite updates. Builder pattern would be more forward-compatible. Don't refactor now.

- [ ] 17.N3 (deferred refactor) — **`BedSearchService.doSearch` is now ~60 lines of filter logic**. Approaching the threshold where extracting `ShelterFilter` strategy classes pays off. Don't refactor now; revisit if more filters arrive.
