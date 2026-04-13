## Why

The 211 CSV shelter import feature exists in the admin UI but only imports 8 basic fields (name, address, phone, lat/lng). Critical operational data — DV shelter flag, population types, bed counts, and constraints (sobriety, referral, ID, pets, wheelchair) — must be configured manually per shelter after import. This defeats the purpose of bulk onboarding: a CoC admin uploading 18 shelters still has to visit each one individually to make it functional in bed search.

Additionally, there is no user-facing documentation of the expected format, no downloadable template, and no in-app guidance for non-technical users. Import test coverage is thin because the adapter only handles 8 trivial string columns — the interesting edge cases (DV flag validation, constraint conflicts, capacity math) can't be tested because the adapter doesn't support them.

This matters for any community adoption: the first question during onboarding is "how do I get my shelters into the system?" Without a full-featured import and format documentation, every new community is a support ticket.

## What Changes

- **Adapter extension**: Extend `TwoOneOneImportAdapter` to parse the full column set — dvShelter, populationTypesServed, bedsTotal, bedsOccupied, sobrietyRequired, referralRequired, idRequired, petsAllowed, wheelchairAccessible, curfewTime, maxStayDays. The `ShelterImportRow` record and `ShelterImportService` already support all 18 fields; only the CSV parsing layer needs to be extended.
- **Documentation**: Column-by-column reference table for the full CSV import format (field name, required/optional, data type, allowed values, example)
- **Template CSV**: Two downloadable files — headers-only template + 3-row example with realistic shelter data (emergency with capacity, DV shelter with RLS flag, constrained shelter with sobriety/referral requirements)
- **In-app guidance**: Quick-start card on the import page (3 numbered steps + template download link), plus help text explaining upsert behavior
- **Error handling improvements**: Row-level validation messages with specific field + value + expected format, downloadable error CSV for offline correction
- **Import test coverage**: Full test suite for the extended adapter — DV flag validation, constraint parsing, capacity math, missing required fields, invalid enums, upsert behavior
- **Upsert support**: Match on name + address street + tenant. Preview shows "Will update: N / Will create: M" before commit.

## Capabilities

### Modified Capabilities
- `shelter-management`: Extend the 211 CSV import adapter to support the full shelter data model (DV flag, constraints, capacities, population types). Add format documentation, template CSV, in-app guidance, row-level error reporting, upsert behavior, and comprehensive test coverage.

## Impact

- **Backend**: `TwoOneOneImportAdapter` (extend column parsing), `ShelterImportService` (upsert logic, per-row error reporting), `ImportResult` / `ImportResultResponse` (error detail DTOs)
- **Frontend**: Import page UI (quick-start card, error display improvements, template download link, upsert preview counts)
- **Documentation**: New `docs/shelter-import-format.md` reference, template CSV files in `infra/templates/`
- **Training**: Addresses Marcus Okafor (CoC admin onboarding 18 partners), Rev. Alicia Monroe (non-technical volunteer), and Devon Kessler (training deliverables) persona needs. A complete CSV import means onboarding is a single spreadsheet upload, not a spreadsheet + 18 manual configurations.
