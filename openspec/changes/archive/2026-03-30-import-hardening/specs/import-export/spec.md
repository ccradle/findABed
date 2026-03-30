## MODIFIED Requirements

### Requirement: Admin panel import navigation

The admin panel import links must use React Router client-side navigation, not HTML anchor tags with `href`.

**Changed from:** `<a href="/import/211">` (full page navigation to wrong route)
**Changed to:** `<Link to="/coordinator/import/211">` (SPA client-side navigation)

**Acceptance criteria:**
- Clicking "2-1-1 Import" in the admin panel navigates to the import page
- Clicking "HSDS Import" in the admin panel navigates to the HSDS import page
- No full page reload occurs during navigation
- Playwright test verifies the click-through from admin panel to import page

### Requirement: CSV injection sanitization (CWE-1236)

All string fields in imported CSV and JSON data must be sanitized before storage to prevent formula injection when data is later exported and opened in spreadsheet software.

**Sanitization rules:**
- Strip leading `=` when followed by a non-digit character
- Strip leading `+` when followed by a non-digit character (preserve `+1` phone prefixes)
- Strip leading `@` always (never valid as first character in shelter data)
- Strip tab characters (`\t`) and carriage return (`\r`) from all field values
- Log a warning with row number and field name when sanitization occurs
- Document in the class that `@`-stripping is shelter-field-specific; if email fields are ever imported, the sanitizer needs a field-type-aware mode

**Applies to:** Both `TwoOneOneImportAdapter` and `HsdsImportAdapter`, on all string fields (name, address, city, state, zip, phone).

**Acceptance criteria:**
- `=CMD('calc')` in a name field is stored as `CMD('calc')` (leading `=` stripped)
- `+cmd|'/C calc'` is stored as `cmd|'/C calc'` (leading `+` stripped, non-digit follows)
- `+1-919-555-0100` is stored as `+1-919-555-0100` (preserved — `+` followed by digit)
- `@SUM(A1:A10)` is stored as `SUM(A1:A10)` (leading `@` stripped)
- `-123 Main St` is stored as `-123 Main St` (leading `-` preserved — common in addresses)
- Tab and CR characters are stripped from all values
- Backend integration test verifies each sanitization rule

### Requirement: Field length validation

Imported fields must be validated against maximum lengths before database insertion.

**Limits:**
| Field | Max Length |
|-------|-----------|
| name | 255 |
| addressStreet | 500 |
| addressCity | 255 |
| addressState | 50 |
| addressZip | 10 |
| phone | 50 |

**Acceptance criteria:**
- A row with a 300-character name produces a row-level error: "Name cannot exceed 255 characters"
- The row is skipped (not truncated) and the error is included in the import result
- Other valid rows in the same file are still imported
- Backend integration test verifies length rejection

### Requirement: MIME type validation

The import controller must validate the uploaded file's content type before processing.

**Accepted types for 211 CSV:** `text/csv`, `text/plain`, `application/csv`, `application/octet-stream`, `null`
**Accepted types for HSDS JSON:** `application/json`, `text/plain`, `application/octet-stream`, `null`

**Acceptance criteria:**
- Uploading an `image/png` file to the 211 endpoint returns 400 with message "File must be CSV format"
- Uploading an `image/png` file to the HSDS endpoint returns 400 with message "File must be JSON format"
- `application/octet-stream` is accepted (browsers may send this for any file)
- `null` content type is accepted with a logged warning (some clients omit it)
- Backend integration test verifies rejection of invalid MIME types

### Requirement: Playwright click-through test

A Playwright E2E test must verify the full user flow from admin panel to import completion, clicking through the UI — not navigating directly to the import URL.

**Test flow:**
1. Login as platform admin
2. Navigate to admin panel
3. Click the Imports tab
4. Click "2-1-1 Import" link
5. Verify TwoOneOneImportPage renders (file upload area visible)
6. Upload a test CSV via `setInputFiles()` with `Buffer.from()` (in-memory)
7. Click "Preview Column Mapping"
8. Verify preview table shows column mappings
9. Click "Confirm Import"
10. Verify "Import Complete" message

**Acceptance criteria:**
- Test uses `data-testid` locators where available, falls back to role/text locators
- Test generates CSV in memory (no fixture file dependency for this test)
- Test clicks through the admin panel — does NOT navigate directly to `/coordinator/import/211`

### Requirement: Playwright negative tests

Playwright E2E tests must verify user-visible error handling for bad import data.

**Test cases:**
1. **Empty file:** Upload 0-byte CSV → error message displayed
2. **Headers only, no data rows:** Upload CSV with header row but no data → error message displayed
3. **CSV injection payload:** Upload CSV with `=CMD('calc')` in name → import succeeds, verify via API that value is sanitized

**Acceptance criteria:**
- Each test uses `Buffer.from()` to generate test data in memory
- Error messages are verified as visible in the UI (not just network response)
- Tests do not share state — each starts clean

### Requirement: Backend negative integration tests

Backend integration tests must cover error paths and security edge cases.

**Test cases:**
1. `test_211Import_emptyFile_returns400` — empty multipart file
2. `test_211Import_headersOnly_returns400` — CSV with headers but no data rows
3. `test_211Import_malformedCsv_returns400` — unclosed quotes
4. `test_211Import_csvInjection_sanitized` — verify `=`, `+`, `@` prefixes stripped, `-` and `+digit` preserved
5. `test_211Import_fieldLengthExceeded_reportsRowError` — 300-char name rejected as row error
6. `test_211Import_missingNameColumn_reportsError` — CSV without name column
7. `test_hsdsImport_csvInjection_sanitized` — verify injection sanitization in JSON path

**Acceptance criteria:**
- Each test is independent (no shared state)
- Tests use the existing `ImportIntegrationTest` base class and auth helpers
- Error responses include meaningful messages (not generic 500)
