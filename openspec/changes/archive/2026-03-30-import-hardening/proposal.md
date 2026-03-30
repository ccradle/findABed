## Why

The 211 import button in the admin panel does nothing — it navigates to `/import/211` but the route is registered at `/coordinator/import/211`. This bug was missed because the Playwright test navigates directly to the correct URL instead of clicking through the admin panel UI.

Beyond the navigation bug, a security review (Marcus Webb lens) and QA analysis (Riley Cho lens) revealed that the import pipeline has no CSV injection protection (CWE-1236), no MIME type validation, no field length limits, and insufficient negative test coverage. A malicious 211 CSV could inject Excel formulas that execute when the data is later exported and opened in a spreadsheet.

The import feature was implemented in shelter-edit (v0.20.0) but the test coverage focused on happy paths. This change hardens the implementation before sharing the demo with external evaluators.

## What Changes

- **Bug fix:** Replace `<a href>` navigation with React Router `Link` for import links in AdminPanel
- **CSV injection sanitization:** Strip or escape cells starting with `=`, `+`, `-`, `@`, tab, CR in both TwoOneOneImportAdapter and HsdsImportAdapter
- **Field length validation:** Enforce max lengths on imported fields (name 255, address 500, phone 50) in ShelterImportService
- **MIME type validation:** Reject non-CSV files at ImportController before parsing
- **Playwright E2E:** Test full click-through from admin panel to import page (the test that would have caught this)
- **Playwright negative tests:** Empty file, malformed CSV, wrong file type, CSV injection payload
- **Backend negative tests:** Empty file, malformed CSV, missing required columns, injection payloads, field length overflow

## Capabilities

### New Capabilities
_None — all changes modify existing capabilities._

### Modified Capabilities
- `import-export`: CSV injection sanitization, MIME validation, field length limits, navigation fix, negative test coverage

## Impact

- **Frontend:** `AdminPanel.tsx` — fix `<a href>` to `Link` for import navigation
- **Backend:** `TwoOneOneImportAdapter.java`, `HsdsImportAdapter.java` — add CSV injection sanitization
- **Backend:** `ShelterImportService.java` — add field length validation
- **Backend:** `ImportController.java` — add MIME type check
- **Tests:** `ImportIntegrationTest.java` — add ~8 negative test cases
- **Tests:** `demo-211-import-edit.spec.ts` — add click-through and negative E2E tests
- **Tests:** `admin-panel.spec.ts` — add import link navigation test
- **No database changes**
- **No API contract changes** (validation returns existing error format)
