## Context

The FABT import pipeline handles two formats: 211 CSV (iCarol/United Way data) and HSDS JSON (Open Referral standard). Both are used by CoC admins to bulk-load shelter data. The data flows through: file upload → parsing → validation → upsert → database. The same data can later be exported as HIC/PIT CSV, creating a round-trip where injected formulas could execute in Excel.

Current state:
- `AdminPanel.tsx` uses `<a href="/import/211">` — wrong route in SPA
- `TwoOneOneImportAdapter.java` reads cell values directly from Apache Commons CSV with no sanitization
- `ShelterImportService.java` validates only name (required) and city (required) — no length limits
- `ImportController.java` accepts any multipart file — no MIME type check
- Playwright test navigates directly to `/coordinator/import/211` — never tests the admin panel link

## Goals / Non-Goals

**Goals:**
- Fix the navigation bug so import works from the admin panel
- Prevent CSV injection (CWE-1236) at the import layer so exported data is safe to open in Excel
- Add field length validation to prevent database issues and UI overflow
- Validate file type server-side before parsing
- Test the full user flow: admin panel → click → import → preview → confirm → verify
- Test negative cases that represent real-world bad data

**Non-Goals:**
- Rewriting the import UI (it works correctly once you reach it)
- Adding rate limiting on import (tracked in platform-hardening change)
- Character encoding detection (UTF-8 with BOM handling is sufficient for 211 data)
- Drag-and-drop testing (setInputFiles covers the same code path)

## Design

### Navigation fix

Replace `<a href="/import/211">` and `<a href="/import/hsds">` with React Router `<Link to="/coordinator/import/211">` and `<Link to="/coordinator/import/hsds">` in AdminPanel.tsx. This preserves SPA state and routes correctly.

Alternative considered: Move import routes to root level. Rejected — import requires coordinator-level auth guard, which is enforced by the `/coordinator/*` route wrapper.

### CSV injection sanitization

**Location:** New utility method in a shared `CsvSanitizer` class, called by both `TwoOneOneImportAdapter` and `HsdsImportAdapter` on every string field before building `ShelterImportRow`.

**Strategy:** Strip dangerous prefix characters. Per OWASP guidance, cells starting with `=`, `+`, `-`, `@`, tab (`\t`), or carriage return (`\r`) should be sanitized. Options:

1. **Prefix with single quote** (`'=CMD...` → `'=CMD...`) — Excel displays the quote, which is ugly but safe
2. **Strip the leading character** — loses data but prevents execution
3. **Reject the row** — safest but overly aggressive (legitimate `-` in addresses like "123-A Main St")

**Decision:** Use a hybrid approach:
- If a field starts with `=`, `+`, or `@` followed by a non-numeric character, strip the dangerous prefix. These are almost certainly injection attempts, not legitimate data.
- `-` is allowed (common in addresses and phone numbers)
- Tab and CR characters are stripped from all fields (never legitimate in shelter data)
- Log a warning when sanitization occurs for audit trail

This avoids false positives on phone numbers like `+1-919-555-0100` and addresses like `123-A Main St` while catching `=CMD(...)`, `+cmd|...`, `@SUM(...)`.

**Note:** The `@`-stripping rule is specific to shelter data fields (name, address, city, state, zip, phone). If the import format ever includes email fields, the sanitizer would need a field-type-aware mode. Document this in the `CsvSanitizer` class.

### MIME type validation

Add a check in `ImportController` before reading file content:
- For 211 endpoint: accept `text/csv`, `text/plain`, `application/csv`, `application/octet-stream` (browsers vary)
- For HSDS endpoint: accept `application/json`, `text/plain`, `application/octet-stream`
- Reject with 400 and clear message if MIME type doesn't match

Note: MIME types from browsers are unreliable (some send `application/octet-stream` for all files), so this is defense-in-depth, not a sole defense. The real validation is that the content parses as valid CSV/JSON. When MIME type is null, log a warning for monitoring visibility but allow the request to proceed.

### Field length validation

Add to `ShelterImportService.validateRow()`:
- `name`: max 255 characters (matches DB column)
- `addressStreet`: max 500 characters
- `addressCity`: max 255 characters
- `addressState`: max 50 characters (DB column is VARCHAR(50); real 211 data may contain full state names like "North Carolina" — no normalization to abbreviations is performed)
- `addressZip`: max 10 characters (ZIP+4)
- `phone`: max 50 characters

Truncation vs rejection: **Reject with row-level error.** If data exceeds limits, it's likely malformed. The import result already supports per-row errors.

### Playwright test strategy

**Click-through test (the miss):** Add to `admin-panel.spec.ts`:
- Login as admin → navigate to admin panel → click Imports tab → click "2-1-1 Import" link → verify TwoOneOneImportPage renders

**Negative E2E tests:** Add to `demo-211-import-edit.spec.ts`:
- Use `Buffer.from()` to generate test CSVs in memory (no fixture files)
- Empty file → error message visible
- Wrong file type (JSON content in .csv) → error or parse failure shown
- CSV injection payload → import succeeds but values are sanitized (verify via API)

### Backend negative test strategy

Add to `ImportIntegrationTest.java`:
- `test_211Import_emptyFile_returns400`
- `test_211Import_headersOnly_returns400`
- `test_211Import_malformedCsv_unclosedQuote_returns400`
- `test_211Import_csvInjection_sanitized`
- `test_211Import_fieldLengthExceeded_reportsError`
- `test_211Import_missingRequiredColumn_reportsError`
- `test_hsdsImport_csvInjection_sanitized`

## Risks

- **False positive on sanitization:** Legitimate phone numbers starting with `+` (international format) could be stripped. Mitigated by only stripping `+` when followed by a non-digit character.
- **MIME type rejection:** Some browsers send `application/octet-stream` for CSV files. Mitigated by accepting it as valid.
- **Breaking existing imports:** If any current 211 data has fields starting with `=` or `@`, sanitization will modify them. This is acceptable — those values are either injection attempts or data entry errors.
