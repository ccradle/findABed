## Context

The admin panel's "Import from 211" feature accepts CSV files to bulk-create shelters. The backend has a well-structured import pipeline: `TwoOneOneImportAdapter` parses CSV → `ShelterImportRow` (18-field record) → `ShelterImportService` creates/updates shelters with constraints and capacities. However, the adapter only populates 8 of 18 fields (name, address, phone, lat/lng), passing `null` for DV flag, constraints, and capacities. The service layer IS capable of handling the full data set — the gap is exclusively in the CSV parsing layer.

No documentation describes the expected format, no template is provided, and validation errors are not surfaced at the row level.

## Goals / Non-Goals

**Goals:**
- Extend the 211 CSV adapter to parse the full shelter data model (DV flag, population types, bed counts, constraints)
- Enable single-upload onboarding: one CSV produces fully functional shelters ready for bed search
- Provide downloadable template CSV with example data and all enum values
- Document every column with type, required/optional, allowed values
- Surface row-level validation errors with specific, non-technical messages
- Verify and extend backend import test coverage for the full column set
- Support upsert behavior (update existing shelters on re-import)

**Non-Goals:**
- Changing the `ShelterImportRow` record or `ShelterImportService` (they already support all fields)
- Building a column-mapping wizard (the format is fixed with fuzzy header matching)
- HMIS CSV import (separate capability — the 211 format is FABT-specific)
- Excel (.xlsx) support (CSV only for now)
- Capacity auto-calculation (bedsAvailable is derived; the CSV only sets bedsTotal and bedsOccupied)

## Decisions

### Decision 1: Extend the adapter, not the service

**Rationale**: `ShelterImportRow` already has 18 fields. `ShelterImportService` already creates shelters with constraints and capacities when the fields are non-null. The ONLY change needed is in `TwoOneOneImportAdapter.parseCsv()` — add more entries to `HEADER_SYNONYMS` and populate the remaining 10 fields in the row constructor. This is a wiring change, not an architecture change. Elena Vasquez confirmed: no schema migration needed.

### Decision 2: Two-tier documentation (quick-start + reference)

**Rationale**: Import users range from Rev. Alicia Monroe's 67-year-old volunteer to city IT staff. A 3-step quick-start card on the import page itself, with a link to the full column reference in `docs/shelter-import-format.md`. Following HubSpot's pattern.

### Decision 3: Template CSV with example data showing the full column set

**Rationale**: Headers-only templates leave users guessing. Provide two files — headers-only template + 3-row example showing: (a) emergency shelter with 50 SINGLE_ADULT beds, (b) DV shelter with dvShelter=true and DV_SURVIVOR capacity, (c) constrained shelter with sobrietyRequired=true, referralRequired=true. All enum values demonstrated across the example rows.

### Decision 4: Row-level error reporting with downloadable error CSV

**Rationale**: After validation, show summary ("47 valid, 3 errors") with per-row error details ("Row 5: populationType 'ADULTS' is not recognized — expected one of: SINGLE_ADULT, FAMILY_WITH_CHILDREN, VETERAN, DV_SURVIVOR, YOUTH_UNDER_18"). Offer "Download errors" button for offline correction. Following Salesforce NPSP and CSVBox patterns.

### Decision 5: Upsert match key = shelter name + address street + tenant

**Rationale**: For re-import, match on (name, address_street, tenant_id). If match found, UPDATE details + constraints + capacities. If no match, INSERT. Preview shows "Will update: N / Will create: M" before commit.

### Decision 6: DV flag import with safety validation

**Rationale**: Marcus Webb flagged that importing `dvShelter=true` on a non-DV shelter (or vice versa) has RLS consequences. The import should support the flag but validate: if changing an existing shelter's DV status via re-import, log a WARN and flag in the preview as a safety-sensitive change. This mirrors the admin UI's DV toggle confirmation pattern without requiring an interactive dialog in a bulk flow.

### Decision 7: Boolean and enum parsing with fuzzy matching

**Rationale**: CSV boolean values vary: "true", "TRUE", "yes", "1", "Y". Enum values may have casing differences: "single_adult" vs "SINGLE_ADULT". The adapter should normalize booleans (true/yes/1/y → true, everything else → false) and uppercase enum values before validation. Population types served is a semicolon-delimited list in a single column (following HubSpot's multi-value convention).

## Risks / Trade-offs

- **[Risk] DV flag change via import**: Importing a shelter with the wrong DV flag has RLS consequences. Mitigated by preview warning + WARN log (Decision 6).
- **[Risk] Capacity conflicts**: CSV specifies bedsTotal and bedsOccupied but bedsAvailable is derived. If bedsOccupied > bedsTotal, reject the row with a clear error. bedsOnHold is never set via import (it's reservation-driven).
- **[Trade-off] Fixed format vs. column mapping**: A mapping wizard would be more flexible but the 211 format is well-defined. Fuzzy header matching (already implemented for 8 columns) provides sufficient flexibility.
- **[Trade-off] Semicolon-delimited multi-values**: populationTypesServed as a semicolon-delimited list in one column is less clean than multiple columns, but it's the industry convention (HubSpot, Salesforce) and avoids column-count explosion for shelters serving 5+ population types.
