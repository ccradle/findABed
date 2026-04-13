## 0. Setup

- [x] 0.1 Switch to the code repo (`finding-a-bed-tonight`), checkout `main`, pull latest, then create and switch to branch `feature/issue-65-shelter-import-docs` from `main`. Verify with `git log --oneline -1` that HEAD matches the latest main commit.

## 1. Backend — Extend Adapter (core work)

- [x] 1.1 Read the current import code: `TwoOneOneImportAdapter.java`, `ShelterImportService.java`, `ImportController.java`, `ImportErrorDto.java`, `ImportResult.java`. Document the actual CSV column schema as implemented. **Finding: adapter only populates 8 of 18 fields. Service layer supports all 18. Gap is adapter-only.**
- [x] 1.2 Add `HEADER_SYNONYMS` entries to `TwoOneOneImportAdapter` for the 10 missing fields: dvShelter, populationTypesServed, bedsTotal, bedsOccupied, sobrietyRequired, referralRequired, idRequired, petsAllowed, wheelchairAccessible, maxStayDays. Include fuzzy matching (e.g., "dv_shelter", "dv shelter", "is_dv", "beds_total", "total_beds", "beds total", "population_types", "populations_served").
- [x] 1.3 Update `parseCsv()` to read the new columns: booleans via flexible parsing (true/yes/1/Y → true), doubles for lat/lng (already done), integers for bedsTotal/bedsOccupied/maxStayDays, semicolon-delimited string for populationTypesServed. Validate enum values against `PopulationType` constants.
- [x] 1.4 Update the `ShelterImportRow` constructor call in `parseCsv()` to pass all 18 fields instead of 10 nulls.
- [x] 1.5 Add capacity conflict validation: if bedsOccupied > bedsTotal, reject the row with a specific error message.
- [x] 1.6 Add population type validation: each value in the semicolon-delimited list must be a recognized `PopulationType`. Reject with error listing valid values if not.

## 2. Backend — Upsert Support

- [x] 2.1 Review current `ShelterImportService` to determine if upsert exists or if import is create-only. Document findings.
- [x] 2.2 If create-only: implement upsert logic — match on (name, address_street, tenant_id). If match found, UPDATE shelter details + constraints + capacities. If no match, INSERT.
- [x] 2.3 Add DV flag change detection: if re-importing changes an existing shelter's dvShelter flag, log WARN and flag in the import result as a safety-sensitive change.
- [x] 2.4 Update the import preview response to include `willUpdate` and `willCreate` counts for the frontend.
- [x] 2.5 Update `ImportResult` / `ImportResultResponse` to include per-row error details (row number, field, value, message) for the frontend error display.

## 3. Documentation

- [x] 3.1 Create `docs/shelter-import-format.md` — column reference table covering all columns (8 existing + 10 new). Include: column name, recognized header synonyms, required/optional, data type, allowed values, example value. Document file requirements (UTF-8, headers row 1, CSV). Document boolean parsing rules and semicolon-delimited multi-values.
- [x] 3.2 Create `infra/templates/shelter-import-template.csv` — headers-only CSV with all columns.
- [x] 3.3 Create `infra/templates/shelter-import-example.csv` — 3 rows: (a) emergency shelter with 50 SINGLE_ADULT beds, (b) DV shelter with dvShelter=true and DV_SURVIVOR capacity, (c) constrained shelter with sobrietyRequired=true, referralRequired=true, populationTypesServed=SINGLE_ADULT;VETERAN.
- [x] 3.4 Document upsert behavior in `docs/shelter-import-format.md`: match key, update vs. create, DV flag safety warning.

## 4. Frontend — In-App Guidance

- [x] 4.1 Add a quick-start card to the 211 Import page. 3 numbered steps: (1) Download template, (2) Fill in shelter data, (3) Upload here. Include download links for both template and example CSV.
- [x] 4.2 Add a link from the quick-start card to the full format reference.
- [x] 4.3 Add help text below the upload area explaining upsert behavior.

## 5. Frontend — Error Handling Improvements

- [x] 5.1 Update the import preview to show a validation summary: "{N} valid rows, {M} rows with errors."
- [x] 5.2 Display row-level error details: row number, field name, actual value, human-readable message.
- [x] 5.3 Add a "Download errors" button that exports a CSV of only the failed rows with an added "Error" column.
- [x] 5.4 Display upsert preview counts: "Will update: N / Will create: M" before commit.
- [x] 5.5 i18n: add all new error message and guidance keys to both `en.json` and `es.json`.

## 6. Backend — Test Coverage

- [x] 6.1 Audit existing import tests. List what's covered vs. missing.
- [x] 6.2 Test: full round-trip — import CSV with all 18 columns → shelter created with constraints + capacities → bed search finds it with correct availability.
- [x] 6.3 Test: minimal CSV (name + address only) → shelter created with defaults, zero beds.
- [x] 6.4 Test: boolean parsing — "true", "yes", "1", "Y", "TRUE" all parse as true; "false", "no", "0", empty parse as false.
- [x] 6.5 Test: semicolon-delimited populationTypesServed → multiple capacities created.
- [x] 6.6 Test: invalid population type → row rejected with error listing valid values.
- [x] 6.7 Test: bedsOccupied > bedsTotal → row rejected with specific error.
- [x] 6.8 Test: DV shelter import → dvShelter=true, RLS-protected.
- [x] 6.9 Test: upsert — re-import same file → existing shelters updated, no duplicates.
- [x] 6.10 Test: partial success — valid rows imported, invalid rows rejected with per-row errors.
- [x] 6.11 Test: DV flag change on re-import → WARN logged, flagged in result.

## 7. Playwright — E2E Verification

- [x] 7.1 Test: import page shows quick-start card with download links.
- [x] 7.2 Test: upload valid CSV with full columns → preview shows correct row count → commit → shelters created with capacities.
- [x] 7.3 Test: upload CSV with errors → preview shows summary → row-level errors visible → "Download errors" button present.
- [x] 7.4 Test: re-upload same file → preview shows "Will update: N / Will create: 0".

## 8. Verification

- [x] 8.1 Run full backend test suite (`mvn clean test`). Tee to `logs/issue-65-import-docs-regression.log`.
- [x] 8.2 Run Playwright import tests through nginx. Tee to `logs/issue-65-import-playwright.log`.
- [x] 8.3 `npm run build` — frontend builds clean.
