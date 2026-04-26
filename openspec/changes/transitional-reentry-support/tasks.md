## 0. Scaffolding status

- [x] 0.1 Feature branch `feature/transitional-reentry-support` created in code repo (2026-04-24 post-v0.51.0)
- [x] 0.2 Migration numbering renumbered twice: V79–V82 → V85–V88 (post-v0.51.0 Phase F) → **V90–V93** (2026-04-26, Phase G consumed V85/V87/V88/V89). Final slot assignments live in §2 below; design.md migration plan + every spec/* reference matches.
- [x] 0.3 Design open questions #1 + #2 resolved (500-char UI / 1000-char server hold note; county detail-card only)
- [x] 0.4 Design open question #4 resolved (features.reentryMode scoped into V90)
- [x] 0.5 Design open question #5 resolved to **Option A** (tenant_dek-wrapped ciphertext) via issue #152, closed 2026-04-24. V92 bundles tenant_dek.purpose CHECK update + reservation column adds. See §2.3 for shape.
- [ ] 0.6 Book Casey Drummond i18n legal-review window for EN+ES disclaimer strings BEFORE implementation starts (not at task 15.6).
- [x] 0.7 ~~Clarify Asheville stakeholder messaging posture~~ — **N/A per Corey 2026-04-26**: there is no Asheville implementation; this comms-posture concern doesn't apply. Item dropped.
- [x] 0.8 Re-verify Flyway HWM after Phase G tags — **DONE 2026-04-26**: Phase G claimed V85/V87/V88/V89; reentry migrations renumbered to **V90 / V91 / V92 / V93**. All references in proposal.md, design.md, tasks.md §2, and specs/* updated in the same commit. Reference: memory `project_reentry_spec_renumber.md`.

## 1. Pre-flight

- [ ] 1.1 **SCAFFOLDED** — feature branch `feature/transitional-reentry-support` already created (2026-04-24); confirm still exists and pull latest main before resuming active work.
- [ ] 1.2 Verify actual Flyway HWM: `SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1` — expected to be **V89** post-Phase-G (v0.53.0). If any further pre-reentry slice has shipped between v0.53 and reentry-implementation start (e.g. a backlog item from design.md F1/F5/F6/F7/F9/F13), bump tasks 2.x slots to land above the new HWM.
- [ ] 1.3 Re-confirm design open question #5 resolution = **Option A** (tenant_dek-wrapped). Write V92 per §2.3 below.

## 2. Database Migrations

- [ ] 2.1 Write V90: add `shelter_type` VARCHAR(50) DEFAULT 'EMERGENCY' to `shelter`; add indexed `county` VARCHAR(100) nullable to `shelter`; UPDATE backfill `dvShelter=true` rows to `shelter_type='DV'`; add check constraint `CHECK (dvShelter = FALSE OR shelter_type = 'DV')`; add `features.reentryMode` key to tenant.config default shape (per open question #4 resolution)
- [ ] 2.2 Write V91: add `eligibility_criteria` JSONB nullable to `shelter_constraints`; add GIN index `CREATE INDEX CONCURRENTLY idx_shelter_constraints_eligibility ON shelter_constraints USING GIN (eligibility_criteria)` — use `mixed=true` migration or separate non-transactional step (CONCURRENTLY cannot run inside a transaction block)
- [ ] 2.3 Write V92 **(Option A per issue #152)** — two coupled steps in one migration:
  - (a) **ALTER `tenant_dek.purpose` CHECK constraint** to add `RESERVATION_PII` to the allowed set. V82 currently pins `CHECK (purpose IN ('TOTP', 'WEBHOOK_SECRET', 'OAUTH2_CLIENT_SECRET', 'HMIS_API_KEY'))`. Use the DROP/ADD CONSTRAINT pattern from V82 (not a plpgsql function rewrite).
  - (b) **ALTER `reservation`** to add `held_for_client_name_encrypted TEXT`, `held_for_client_dob_encrypted TEXT`, `hold_notes_encrypted TEXT` — all nullable, all storing base64 v1 `EncryptionEnvelope`.
  - Migration is Flyway-SQL (not Java) because neither step needs JCE; both are DDL.

- [ ] 2.3a Add `KeyPurpose.RESERVATION_PII` enum value to `org.fabt.shared.security.KeyPurpose`. No associated `KeyDerivationService.deriveXxxKey` method needed — this purpose uses the random-DEK path exclusively (the deprecated HKDF derive methods are for the legacy backward-compat shim only).
- [ ] 2.4 Write V93: add `requires_verification_call` BOOLEAN DEFAULT FALSE to `shelter`
- [ ] 2.5 Verify V90 migration backfill: integration test confirms `dvShelter=true` rows all have `shelter_type='DV'` and check constraint is active post-migration

## 3. Backend: Domain Model

- [ ] 3.1 Add `ShelterType` enum to backend domain with values: EMERGENCY, DV, TRANSITIONAL, SUBSTANCE_USE_TREATMENT, MENTAL_HEALTH_TREATMENT, REENTRY_TRANSITIONAL, PERMANENT_SUPPORTIVE, RAPID_REHOUSING
- [ ] 3.2 Add `shelterType` and `county` fields to `Shelter` entity/domain record; update JDBC row mapper and `ShelterRepository`
- [ ] 3.3 Add `requiresVerificationCall` boolean to `Shelter` entity; update row mapper
- [ ] 3.4 Add `EligibilityCriteria` JSONB value type (record/class) with `CriminalRecordPolicy` sub-type; add to `ShelterConstraints` entity; JSONB serialization via `ObjectMapper`
- [ ] 3.5 Add `heldForClientName`, `heldForClientDob`, `holdNotes` fields to `Reservation` entity as plaintext Java types (String / LocalDate / String). **Domain layer holds plaintext; DB columns are the `_encrypted` siblings** (same pattern as `app_user.totpSecret` ↔ `totp_secret_encrypted`). Row mapper calls `SecretEncryptionService.decryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, columnValue)` on read; writer calls `encryptForTenant(...)` on write. Null-safe: null columns map to null fields without attempting decrypt.

## 4. Backend: Service and Repository Layer

- [ ] 4.1 `BedSearchService`: add `shelterType` filter (enum, optional, multi-value); add `county` filter (string, case-insensitive, optional); add `acceptsFelonies` filter (boolean, optional — queries `eligibility_criteria->'criminal_record_policy'->>'accepts_felonies'`); update `BedSearchParams` record
- [ ] 4.2 `BedSearchService`: when `acceptsFelonies=true`, shelters with null `eligibility_criteria` are excluded (unknown policy)
- [ ] 4.3 `ShelterService`/`ShelterRepository`: persist `shelterType`, `county`, `eligibilityCriteria`, `requiresVerificationCall` on PUT/PATCH; validate `shelterType` against enum; validate `county` against `tenant.config.active_counties` if configured; enforce `dvShelter=true` implies `shelterType=DV` at application layer
- [ ] 4.4 `ReservationService`: persist `heldForClientName`, `heldForClientDob`, `holdNotes` from hold creation request via `SecretEncryptionService.encryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, plaintext)`. Store the resulting v1 envelope in the `_encrypted` columns. Validate `heldForClientDob` is before today and after 1900-01-01 BEFORE encryption (plaintext validation only). `dob` is serialized to ISO-8601 string before encryption (`LocalDate.toString()` round-trips cleanly).
- [ ] 4.5 Add `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration` endpoint: accepts `holdDurationMinutes` integer (30–480), updates `tenant.config.holdDurationMinutes`, requires COC_ADMIN role; hold duration change applies to new holds only
- [ ] 4.6 Extend Spring Batch cleanup job: null `held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `hold_notes_encrypted` on reservation records where resolution time + 24h has passed. The job nulls the **ciphertext** columns (it has no key material and no need for it — NULL is NULL regardless of what was encrypted). Logic must be null-safe on pre-V92 databases (no-op if columns not present).

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
- [ ] 7.3 Write CI guard job (grep-based, similar to existing `phase-b-rls-test-discipline` pattern): any JSX/TSX file containing a prop reference to `criminal_record_policy`, `accepts_felonies`, or `excluded_offense_types` that does NOT also contain `<CriminalRecordPolicyDisclaimer` in the same file fails CI; match on exact string tokens to avoid false positives from comments
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
- [ ] 13.10 V79 migration backfill: all `dvShelter=true` rows have `shelter_type='DV'`; DB constraint rejects diverged updates
- [ ] 13.11 Cross-tenant isolation: `eligibility_criteria` on Shelter from Tenant A not returned in Tenant B queries
- [ ] 13.12 Cross-tenant isolation: `heldForClientName` on Reservation from Tenant A not accessible from Tenant B session

- [ ] 13.13 **[Option A encryption invariants]** Round-trip integration test: Tenant A encrypt `heldForClientName` = "Probe-<UUID>", read back via the row mapper's `decryptForTenant` path, assert plaintext matches. Bypass the service: load ciphertext directly from DB, assert it does NOT equal plaintext (proves at-rest ciphertext). Attempt `decryptForTenant` with Tenant B context on Tenant A's ciphertext: assert `CrossTenantCiphertextException` (inherits Phase F-6 kid-check). This exercises the exact invariant pass-2 Marcus required.
- [ ] 13.13 `shelterType=DV` filter combined with `dvShelter=false` never returns a DV shelter (DV access control unaffected by new filter)

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

## 15. Build and Release Verification

- [ ] 15.1 `npm run build` (tsc + vite) passes with no errors before any commit (per `feedback_build_before_commit.md`)
- [ ] 15.2 CI guard job for disclaimer co-rendering passes on PR (task 7.3)
- [ ] 15.3 Update `CHANGELOG.md` with feature summary
- [ ] 15.4 Bump `backend/pom.xml` version for release (confirm version number at tag time)
- [ ] 15.5 Update DBML and AsyncAPI/OpenAPI docs for all new fields (per `feedback_update_docs_with_code.md`)
- [ ] 15.6 Casey Drummond legal review: final EN and ES i18n strings for `shelter.criminalRecordPolicyDisclaimer` and `shelter.vawaNoteDisclaimer` signed off before merge
- [ ] 15.7 `make rehearse-deploy` PASS before tagging release
