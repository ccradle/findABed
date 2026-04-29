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

- [x] 4.1 **DONE 2026-04-29 (slice 2B + 2D refactor)** — `BedSearchService`: `shelterType` (multi-value), `county` (case-insensitive), `acceptsFelonies` filters wired on `BedSearchRequest`. Three-way logic extracted to `AcceptsFeloniesEvaluator` per slice-2 warroom 17.H2. Java-layer JSONB extraction; SQL containment + GIN activation deferred to slice 5 per warroom H4.
- [x] 4.2 **DONE 2026-04-29 (slice 2B + 2D refactor)** — three-way logic implemented in `AcceptsFeloniesEvaluator.evaluate()` covering all three branches; unit tests in `AcceptsFeloniesEvaluatorTest` (14 cases incl. negative controls); integration tests in `BedSearchFilterIntegrationTest` (14 cases incl. branch (a) sentinel-override-loses).
- [x] 4.3 **DONE 2026-04-29 (slice 2B)** — `county` + `eligibilityCriteria` + `requiresVerificationCall` flow through `ShelterService.create()` / `update()`. `ShelterService.isValidCounty` 4-branch state machine covered by `ShelterServiceIsValidCountyTest` (12 cases). Note: `shelterType` column write is still tied to `dvShelter` only (slice 5.4 will expose it on the write DTO).
- [x] 4.4 **DONE 2026-04-29 (slice 2C)** — `ReservationService.createReservation(...,heldForClientName,heldForClientDob,holdNotes)` overload encrypts via `SecretEncryptionService.encryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, ...)`. `validateHoldClientDob` enforces > 1900-01-01. ISO-8601 round-trip verified by `HoldAttributionIntegrationTest`.
- [x] 4.5 **DONE 2026-04-29 (slice 2C + 2D fix)** — `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration` shipped. **Bug found in slice 2D §13 testing 2026-04-29:** initial draft used camelCase `holdDurationMinutes` for the JSON key, but the read path (`ReservationService.getHoldDurationMinutes`) and seed data (V76, V77) use snake_case `hold_duration_minutes` — so the PATCH silently no-op'd. Fixed in `TenantService.setHoldDurationMinutes` to write snake_case. §13.7 integration test now passes.
- [x] 4.5a **DONE 2026-04-29 (slice 2C)** — `DemoGuardFilter.getBlockMessage()` matches the path and returns the per-action message; verified by `HoldAttributionIntegrationTest` role-gating tests.
- [x] 4.6 **DONE 2026-04-29 (slice 2C)** — `ReferralTokenPurgeService.purgeExpiredHoldAttribution()` `@Scheduled` extension lands; service-layer wrapper `ReservationService.purgeExpiredHoldAttribution(cutoff)` keeps the modular-monolith boundary (referral → reservation must go through service, not repo).

## 5. Backend: API Layer and DTOs

- [ ] 5.1 `BedSearchController`: expose `shelterType`, `county`, `acceptsFelonies` as query parameters on `GET /api/v1/beds/search`; document in OpenAPI spec — **PARTIAL**: filter fields ARE accepted on `POST /api/v1/queries/beds` JSON body (slice 2B) and exercised end-to-end by `BedSearchFilterIntegrationTest`. The "GET /api/v1/beds/search query params" wording is aspirational; current path is the existing POST endpoint. Open question whether to add a redundant GET alias or update the spec wording — defer.
- [~] 5.2 Bed search response DTO: include `shelterType`, `county`, `eligibilityCriteria` (full object), `requiresVerificationCall`, `acceptsFelonies` (derived from JSONB for convenience) — **PARTIAL DONE 2026-04-29 (slice 4 prereq, warroom H2)**: `shelterType` (verify-round-2 S3) + `county` + `requiresVerificationCall` now flow through `BedSearchResult`. Full `eligibilityCriteria` JSONB + derived `acceptsFelonies` still ride §10.7 — they gate the expanded-card eligibility summary, not the badge/filter UI that §8/§9 need.
- [x] 5.3 **DONE 2026-04-29 (slice 4 prereq, warroom C1)** — `ShelterResponse` adds `shelterType`, `county`, `requiresVerificationCall`. Round-trip verified by `ShelterIntegrationTest.test_getShelterDetail` (default-values path) + `test_getShelterDetail_includesNonNullSliceTwoFields` (user-supplied path). `DvAddressRedactionHelper` updated to pass the new fields through (safe — taxonomy + jurisdictional, not address-leak). `eligibilityCriteria` already flows through `ShelterDetailResponse.constraints` (no change needed there).
- [x] 5.4 **DONE 2026-04-29 (slice 2D warroom H2)** — `CreateShelterRequest` + `UpdateShelterRequest` accept optional `ShelterType shelterType`. `ShelterService.create()` / `update()` honor it with the V91 lockstep guard: `dvShelter=true` forces shelter_type=DV; `dvShelter=false` + explicit `shelterType=DV` rejects with a clear message instead of the cryptic CHECK-constraint failure. `BedSearchFilterIntegrationTest` no longer needs the `forceShelterType` direct-UPDATE workaround. `ShelterImportService` + `ShelterServiceLockstepTest` constructors updated; new behavior covered by `BedSearchFilterIntegrationTest.createShelter`'s post-create DB readback assertion.
- [x] 5.4a **DONE 2026-04-29 (slice 4 prereq, warroom H1)** — `GET /api/v1/active-counties` endpoint added (`ActiveCountiesController`). Returns the resolved list per the 4-branch state machine: NC defaults fallback when key absent, explicit list verbatim, `[]` returned literal (UI signal for free-text mode), defensive NC fallback on parse failure. Authorized to any authenticated tenant member; tenant scoping via `TenantContext.getTenantId()` — no path tenantId, structurally cross-tenant-safe. Necessary because the existing `/api/v1/tenants/{id}/config` is COC_ADMIN-only and OUTREACH_WORKER needs the list to populate the §9.3 county filter dropdown.
- [ ] 5.5 Reservation create request DTO: add optional `heldForClientName`, `heldForClientDob`, `holdNotes`; reservation response DTO: include new fields
- [ ] 5.6 Hold duration admin endpoint DTO: `HoldDurationRequest { holdDurationMinutes: int }` with validation 30–480
- [ ] 5.7 Update DBML and OpenAPI docs for all new fields and endpoints (per `feedback_update_docs_with_code.md`)

## 6. Frontend: i18n Keys

- [x] 6.1 **DONE 2026-04-29 (slice 3)** — 8 ShelterType keys landed in en.json + es.json; build passes.
- [x] 6.2 **DONE 2026-04-29 (slice 3)** — `shelter.criminalRecordPolicyDisclaimer`, `shelter.vawaNoteDisclaimer`, `shelter.vawaProtectionsApplyNote` use Casey-reviewed strings VERBATIM per `i18n-legal-review-strings.md` (2026-04-28 review). Form/display labels also added: `shelter.acceptsFelonies` (dignity-centered "Accepts individuals with felony convictions"), `shelter.county`, `shelter.requiresVerificationCall`, `shelter.excludedOffenseTypes`. Task 15.6 still gates final pre-merge sign-off if any string drifts.
- [x] 6.3 **DONE 2026-04-29 (slice 3)** — 6 `offenseType.*` display labels (SEX_OFFENSE, ARSON, DRUG_MANUFACTURING, VIOLENT_FELONY, PENDING_CHARGES, OPEN_WARRANTS) in EN + ES.
- [x] 6.4 **DONE 2026-04-29 (slice 3)** — `hold.heldForClientName/Dob` with sublabels per D4; `hold.notes`; `hold.clientAttributionPrivacyNote` (Casey-reviewed verbatim — states 24h post-resolution purge in plain language with the explicit "Use these fields only for shelter check-in coordination" load-bearing line).
- [x] 6.5 **DONE 2026-04-29 (slice 3)** — `admin.holdDurationMinutes`, `admin.eligibilityCriteria`, `admin.requiresVerificationCall`, `search.filterByCounty`, `search.filterByShelterType`, `search.acceptsFelonies`, `search.advancedFilters` in EN + ES.
- [x] 6.6 **DONE 2026-04-29 (slice 3)** — `npm run build` (tsc + vite) passes; JSON validates; EN+ES key parity asserted (708 keys each).

## 7. Frontend: CriminalRecordPolicyDisclaimer Component

- [x] 7.1 **DONE 2026-04-29 (slice 4 §7)** — `frontend/src/components/CriminalRecordPolicyDisclaimer.tsx` shipped: `role="note"` (NOT `alert` — passive informational), non-dismissable, uses `color.warningBg`/`color.warning` tokens that adapt to dark mode via CSS custom properties. `data-testid` for Playwright. Renders `shelter.criminalRecordPolicyDisclaimer` via `<FormattedMessage>` (Casey-reviewed string, slice 3 §6.2).
- [x] 7.2 **DONE 2026-04-29 (slice 4 §7)** — `vawaProtectionsApply?: boolean` prop renders the additional `shelter.vawaNoteDisclaimer` paragraph when true. Order is base disclaimer first, VAWA note second so navigators encounter the universal-applicability note before the case-specific override.
- [x] 7.3 **DONE 2026-04-29 (slice 4 §7, warroom H3 fix applied)** — `scripts/ci/check-criminal-record-disclaimer-co-rendering.sh` enforces the co-rendering rule. Comment-line filter tightened from the original spec wording (`grep -vE '^\s*(\*|//|/\*)'` left inline trailing `// ...` comments matching) to a 3-step pre-pass: (1) strip inline `/\*[^*]*\*/` blocks, (2) strip trailing `//.*` to EOL, (3) drop lines that begin with `*` (JSDoc body) or `/*` (block opener). Fixtures at `scripts/ci/fixtures/check-criminal-record-disclaimer/` cover all 5 cases (FAIL: raw-prop-no-disclaimer; PASS: raw-prop-with-disclaimer, jsdoc-only-mention, inline-trailing-comment H3 case, inline `/* */` block). `run-fixtures.sh` drives them. Guard accepts an optional file path arg for the fixture runner. Sanity-flip verified: removing the disclaimer from `pass-raw-prop-with-disclaimer.tsx` would flip it to fail.
- [ ] 7.4 NVDA/VoiceOver spot-check: disclaimer is announced after the criminal record policy data it annotates; screen reader does not skip it — **DEFERRED 2026-04-29 (manual)**: requires a screen-reader-equipped human; track for v0.55 release prep alongside §15.x manual passes.

## 8. Frontend: Shelter Type Taxonomy UI

- [x] 8.1 **DONE 2026-04-29 (slice 4 §8)** — shelterType chip on search-result cards (summary view) via `data-testid="shelter-type-display-{shelterId}"`. Renders only when present.
- [x] 8.2 **DONE 2026-04-29 (slice 4 §8 + warroom M3)** — `shelter-type-dropdown` in `ShelterForm`. Bidirectional V91 lockstep: dvShelter=true forces DV (locked); dvShelter=false disables DV option with the tooltip. DV option hidden entirely for non-`dvAccess` users (matches §8.3 RLS-aware posture per warroom H1).
- [x] 8.3 **DONE 2026-04-29 (slice 4 §8 + warroom H1+H2+M1)** — chip-group multi-select inside a `<details>` "Advanced filters" section. DV chip hidden for non-dvAccess users (warroom H1). Chip group preferred over native `<select multiple>` for mobile + a11y (warroom H2). `aria-pressed` + per-chip `data-testid`.

## 9. Frontend: Supervision County Filter UI

- [x] 9.1 **DONE 2026-04-29 (slice 4 §9)** — `shelter-county-dropdown` in `ShelterForm`. Three render modes per design D3: loading (placeholder + disabled), empty-list (free-text input — explicit `active_counties=[]` validation-disabled mode), populated (`<select>` from `useActiveCounties` hook).
- [x] 9.2 **DONE 2026-04-29 (slice 4 §9)** — county chip on search-result cards via `data-testid="county-display-{shelterId}"`. Adjacent to the §8.1 shelterType chip.
- [x] 9.3 **DONE 2026-04-29 (slice 4 §9 + warroom M1+M4)** — county dropdown inside the same `<details>` advanced-filters section. `htmlFor` association on `<label>`. `<details open>` per warroom M4 — desktop sees filters open by default; mobile users tap to toggle.

## 10. Frontend: Extended Eligibility Criteria UI

- [x] 10.1 **DONE 2026-04-29 (slice 4 §10)** — `<EligibilityCriteriaSection>` component, role-gated via `visible` prop driven by `COC_ADMIN`/`PLATFORM_ADMIN` check in `ShelterForm`. Renders nothing when invisible. Placed in fieldset with legend.
- [x] 10.2 **DONE 2026-04-29 (slice 4 §10)** — `accepts_felonies` as tri-state radio group (Yes/No/Not specified — preserves the H1 evaluator's distinction between explicit-false and absent-data); `excluded_offense_types` chip-group multi-select (6 controlled values via slice 3 §6.3 i18n with `aria-pressed`); `individualized_assessment` checkbox; `vawa_protections_apply` checkbox with conditional `shelter.vawaProtectionsApplyNote` form-level note (warroom M3 — distinct from search-side `vawaNoteDisclaimer`); `notes` textarea (max 500 chars).
- [x] 10.3 **DONE 2026-04-29 (slice 4 §10)** — `program_requirements` + `documentation_required` use new reusable `<TagEditor>` component (input + add + chip list, dedup + trim, `aria-label` per chip remove button). `intake_hours` text input.
- [x] 10.4 **DONE 2026-04-29 (slice 4 §10)** — every form field suffixed " (Optional)" via `common.optional` i18n key. Read-only display (`<EligibilityCriteriaDisplay>`) renders "Not specified" via `common.notSpecified` for null/empty fields.
- [x] 10.5 **DONE 2026-04-29 (slice 4 §10)** — `<CriminalRecordPolicyDisclaimer>` rendered FIRST in DOM order in BOTH `<EligibilityCriteriaSection>` (form) AND `<EligibilityCriteriaDisplay>` (read-only). Casey-reviewed legal posture: disclaimer precedes the data it annotates. §7 CI guard satisfied per-file at every checkpoint during implementation.
- [x] 10.6 **DONE 2026-04-29 (slice 4 §10)** — `requires_verification_call` checkbox toggle in `ShelterForm` (`requires-verification-call-toggle` testid). "📞 Requires verification call" badge in OutreachSearch result cards (`requires-verification-call-badge-{shelterId}` testid) using `color.warning`/`warningBg` for visual prominence.
- [x] 10.7 **DONE 2026-04-29 (slice 4 §10)** — `<EligibilityCriteriaDisplay>` rendered in OutreachSearch expanded shelter modal as a "Eligibility Criteria" Section. Parses `JsonString` via `parseEligibilityCriteria`. Renders `program_requirements`, `intake_hours`, criminal record policy summary, AND the "Not specified" empty-state per §10.4. Disclaimer co-rendered at top.

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

- [x] 13.1 **DONE 2026-04-29 (slice 2D)** — `BedSearchFilterIntegrationTest`: shelterTypes single + multi-value + no-filter (3 cases, with negative-control assertions on excluded IDs).
- [x] 13.2 **DONE 2026-04-29 (slice 2D)** — `BedSearchFilterIntegrationTest`: county exact + case-insensitive (Wake/WAKE/wake same set) + no-match (3 cases).
- [x] 13.3 **DONE 2026-04-29 (slice 2D)** — `BedSearchFilterIntegrationTest`: branches (a)/(b)/(c) covered with both positive AND negative control siblings, including branch (a) sentinel-override-loses (5 cases).
- [x] 13.4 **DONE 2026-04-29 (slice 2D)** — `BedSearchFilterIntegrationTest`: included shelter has both `accepts_felonies=true` AND sentinel=true verified at the DB layer to guard against false-positive routing (2 cases). Note: response DTO doesn't yet expose these — task 5.2 will surface them at API.
- [x] 13.5 **DONE 2026-04-29 (slice 2D + warroom H1)** — `HoldAttributionIntegrationTest`: round-trips name/DOB/notes through encrypt → DB → decrypt via `ReservationRepository` AND through the API response surface (warroom H1 added the fields to `ReservationResponse`; test now asserts the response echoes plaintext back to the caller). Plus negative control: omitted attribution stays null, columns NOT written with empty-string ciphertext.
- [x] 13.6 **DONE 2026-04-29 (slice 2D)** — `HoldAttributionIntegrationTest`: future DOB → 400 + no row persisted (negative-control DB query); plus today's DOB also rejected (catches @PastOrPresent regression).
- [x] 13.7 **DONE 2026-04-29 (slice 2D + warroom M1)** — `HoldAttributionIntegrationTest.holdDurationChange_appliesForwardOnly`. **Found a real bug**: slice 2C wrote `holdDurationMinutes` (camelCase) to `tenant.config` but the read path + seed migrations (V76/V77) use `hold_duration_minutes` (snake_case) — PATCH was silently no-op'ing. Fixed `TenantService.setHoldDurationMinutes` to write snake_case. Tolerance tightened from ±2 min to ±10 s (warroom M1) so a 60-second off-by-minute regression can't slip through.
- [x] 13.8 **DONE 2026-04-29 (slice 2D + warroom B1)** — `HoldAttributionIntegrationTest`: COC_ADMIN succeeds (positive control); OUTREACH_WORKER + COORDINATOR each receive 403; below-min and above-max return 400 (Bean Validation @Min/@Max). Warroom B1 added: happy-path test now asserts a `TENANT_CONFIG_UPDATED` audit row was emitted with the new value in the details blob.
- [x] 13.9 **DONE 2026-04-29 (slice 2D warroom H3)** — `HoldAttributionIntegrationTest` adds three purge tests: (a) EXPIRED reservation past `expires_at + 24h` → ciphertext columns nulled, other reservation fields preserved (negative-control DB readback proves we didn't null `id` / `notes` / etc.); (b) active recent HELD → NOT purged; (c) recently CANCELLED → NOT purged. Production purge SQL + service-layer wrapper (slice 2C) now have integration coverage at the 24h-elapse boundary.
- [ ] 13.10 V91 migration backfill: all `dvShelter=true` rows have `shelter_type='DV'`; DB constraint rejects diverged updates — **DEFERRED**: existing `V91MigrationVerificationTest` + `ShelterServiceLockstepTest` cover the constraint and the lockstep, but a focused-on-§13.10 test reads cleaner. Track for slice 5 release-prep.
- [ ] 13.11 Cross-tenant isolation: `eligibility_criteria` on Shelter from Tenant A not returned in Tenant B queries — **DEFERRED**: generic shelter cross-tenant RLS is already covered by `CrossTenantIsolationTest` family; the new field rides existing RLS so no new path. Track for slice 5 release-prep audit.
- [ ] 13.12 Cross-tenant isolation: `heldForClientName` on Reservation from Tenant A not accessible from Tenant B session — **PARTIALLY DONE**: 13.13 covers cross-tenant **decrypt** rejection (the security-meaningful part). Reservation table RLS visibility is generic existing coverage. Track for slice 5 release-prep.

- [x] 13.13 **DONE 2026-04-29 (slice 2D + warroom M2)** — `HoldAttributionIntegrationTest`: (a) DB ciphertext is a structurally valid v1 envelope (`EncryptionEnvelope.isV1Envelope` magic-bytes check, M2 upgrade from coarse length fingerprint); (b) tenant A round-trips own ciphertext (positive control); (c) tenant B `decryptForTenant` on tenant A ciphertext throws `CrossTenantCiphertextException`. Closes warroom 16.M1 + 16.M2 round-trip + cross-tenant invariants for `KeyPurpose.RESERVATION_PII`.
- [ ] 13.14 `shelterType=DV` filter combined with `dvShelter=false` never returns a DV shelter (DV access control unaffected by new filter) — **DEFERRED**: the V91 CHECK constraint `shelter_dv_implies_dv_type` makes this combo structurally impossible (covered by `ShelterServiceLockstepTest`); a dedicated integration test would be redundant. Confirm with warroom and either close or add a defensive-design test in slice 5.

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

- [x] 16.M1 **DONE 2026-04-29 (slice 2D §13.13)** — `HoldAttributionIntegrationTest` exercises the full encrypt → store → load → decrypt round-trip on `KeyPurpose.RESERVATION_PII` end-to-end through the public reservation API. The TenantDekService + random-DEK pathway is no longer "currently unreachable" — production POSTs hit it now and integration tests verify it.
- [x] 16.M2 **DONE 2026-04-29 (slice 2D §13.13)** — Cross-tenant `CrossTenantCiphertextException` assertion on `KeyPurpose.RESERVATION_PII` ciphertext landed in `HoldAttributionIntegrationTest.crossTenantDecrypt_throwsCrossTenantCiphertextException`. The kid-check inherits the Phase F-6 behavior (verified live + by integration test). `NTenantCanaryShredTest` "should never reach here" TODO at lines 228-244 can be revisited in slice 5 release-prep with a happy-path-decrypt-fails-after-shred proof shape.
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

- [x] 17.H1 **DONE 2026-04-29 (slice 2D)** — `BedSearchFilterIntegrationTest` adds 14 dedicated tests across §13.1-13.4. Each branch has positive AND negative-control assertions on the same call. Slice-2 merge unblocked.

- [x] 17.H2 **DONE 2026-04-29 (slice 2D)** — `AcceptsFeloniesEvaluator` extracted from `BedSearchService`. Takes `(ShelterConstraints, Shelter) → Decision`. `BedSearchService` constructor went from 7 params back to 7 (the new evaluator replaces `ObjectMapper`). Slice-5 SQL-filter equivalence test target ready.

- [x] 17.H3 **DONE 2026-04-29 (slice 2D)** — `ShelterServiceIsValidCountyTest` adds 12 unit tests covering all 4 branches plus boundary cases (non-NC county with config=[] accepts; NC county explicitly excluded rejects; case-sensitivity asserted). Negative-control sibling on every branch.

### Slice 4 / 5 (UX + ops)

- [x] 17.M1 **DONE 2026-04-29 (slice 4 §8/§9 + warroom H4)** — empty-state banner ships in `OutreachSearch.tsx` triggered by `acceptsFelonies && filtered.length === 0`. New i18n key `search.acceptsFeloniesEmptyHint` — Casey re-review pending, captured in `i18n-legal-review-strings.md` per its dedicated section. Also: the `acceptsFelonies` toggle itself ships in this same commit (spec gap close — no §8.x/§9.x task explicitly added the UI even though i18n key + backend field existed; warroom H3 captured the gap).

- [ ] 17.M2 (slice 4 i18n + backend exception refactor) — **Backend "Invalid county" error is operator-cryptic**. `ShelterService.create/update` throws `IllegalArgumentException("Invalid county 'X' for tenant; not in active_counties")` reaching the user as 400 Bad Request body. A COC_ADMIN doesn't know what `active_counties` is or how to fix it. Slice 4: introduce `CountyNotConfiguredException` → global handler maps to i18n key `error.shelter.county_not_configured` ("County '{0}' is not configured for your CoC. Contact your platform operator to add it.").

- [ ] 17.M3 (slice 4 backlog OR slice-2 carryover) — **`UpdateShelterRequest` cannot CLEAR fields**. PATCH semantics: null = "leave unchanged." A COC_ADMIN wanting to remove a previously-set county has no path through this DTO. Documented limitation. Slice 4 may need a sentinel pattern (`""` empty string = clear) OR a separate explicit clear-field endpoint. Worth a Marcus-Webb / Casey-Drummond pass before deciding the shape.

- [ ] 17.M4 (slice 5 perf) — **`tenantService.findById` fires per shelter create/update**. Bulk operations (211 imports, future bulk-edit features) cause N redundant tenant config reads. Add request-scoped caching (e.g., `@RequestScope` parsed-tenant-config bean). Don't optimize until pilot-scale measurement justifies it.

- [x] 17.M5 **DONE 2026-04-29 (slice 2D)** — Resolved by 17.H2: `AcceptsFeloniesEvaluator` is the focused test target. `BedSearchService` constructor still has 7 params (evaluator replaced `ObjectMapper`); per-method unit tests of the constructor are not needed because filter logic is no longer there.

### NITs (track but don't gate)

- [ ] 17.N1 (codebase-wide policy decision) — **Reservation entity holds plaintext while User entity holds encrypted**. Documented in JavaDoc as intentional but it's a cross-codebase inconsistency. Future warroom round: pick one direction and standardize.

- [ ] 17.N2 (deferred ergonomics) — **5 callsites of `BedSearchRequest` manually null-padded for the new fields**. Records are explicit (good for compile-time safety) but each new field forces N callsite updates. Builder pattern would be more forward-compatible. Don't refactor now.

- [ ] 17.N3 (deferred refactor) — **`BedSearchService.doSearch` is now ~60 lines of filter logic**. Approaching the threshold where extracting `ShelterFilter` strategy classes pays off. Don't refactor now; revisit if more filters arrive.
