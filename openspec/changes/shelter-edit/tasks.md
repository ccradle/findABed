## Tasks

> **Dependency:** This change requires the `audit_events` table from `admin-user-management` (T-2).
> Implement `admin-user-management` first, or extract the audit table migration into a shared prerequisite.

### Setup

- [x] T-0: Create branch `feature/shelter-edit` in code repo (`finding-a-bed-tonight`)

### Backend — DV Safeguards

- [x] T-1: `ShelterService.updateShelter()` — enforce role check if dvShelter field is changing (COC_ADMIN+ required, 403 for COORDINATOR)
- [x] T-2: Audit log DV shelter address changes (old/new values) via audit_events table (from admin-user-management change)
- [x] T-3: Audit log DV flag changes with elevated visibility

### Backend — Tests

- [x] T-4: Integration test: coordinator edits shelter phone — succeeds
- [x] T-5: Integration test: coordinator changes dvShelter flag — returns 403
- [x] T-6: Integration test: COC_ADMIN changes dvShelter flag — succeeds with audit
- [x] T-7: Integration test: coordinator edits unassigned shelter — returns 403

### Frontend — ShelterForm Edit Mode

- [x] T-8: Update ShelterForm.tsx — accept `initialData` prop, detect edit mode, PUT on save instead of POST
- [x] T-9: Add route `/coordinator/shelters/:id/edit` that fetches shelter data and passes to ShelterForm
- [x] T-10: In edit mode, disable fields based on role (COORDINATOR: name, address, DV flag read-only)
- [x] T-11: DV flag toggle: disabled for COORDINATOR with tooltip. For COC_ADMIN: confirmation dialog on true→false change

### Frontend — Navigation

- [x] T-12: Admin Shelters tab: add "Edit" link on each shelter row, navigates to edit route
- [x] T-13: Coordinator dashboard: add "Edit Details" button on expanded shelter card
- [x] T-14: After save, navigate back to originating page (admin or coordinator)

### Frontend — i18n & Accessibility

- [x] T-15: Add i18n keys for shelter edit (en.json + es.json): edit button, confirmation dialog, field tooltips
- [x] T-16: WCAG: form fields have labels, disabled fields have aria-disabled, confirmation dialog is keyboard-navigable

### Frontend — Tests

- [x] T-17: Playwright: admin edits shelter name via Shelters tab, saves, verifies
- [x] T-18: Playwright: coordinator edits phone from dashboard, saves, verifies
- [x] T-19: Playwright: coordinator sees DV flag disabled with tooltip (partial — verifies toggle renders; full COORDINATOR role E2E needs fixture addition)
- [x] T-20: Playwright: COC_ADMIN changes DV flag, confirmation dialog appears

### Docs-as-Code — DBML, OpenAPI, ArchUnit

- [x] T-21: Verify `docs/schema.dbml` matches current shelter table schema (no new columns expected, but confirm)
- [x] T-22: Verify `@Operation` annotation exists on PUT /api/v1/shelters/{id} — add or update summary to reflect edit capabilities and DV safeguards
- [x] T-23: Verify ArchUnit boundary rules pass — shelter edit logic stays in shelter module, DV safeguard audit uses shared event bus (not direct audit repo access)

### Demo Flow — 211 Import → Edit Lifecycle

- [x] T-24: Create `finding-a-bed-tonight/e2e/fixtures/nc-211-sample.csv` — 3 fictitious NC shelters with iCarol-style headers (`agency_name`, `street_address`, `address_city`, `address_state`, `postal_code`, `telephone`). One standard shelter (Hope Harbor), one with intentionally wrong phone/555-0000 (Sunrise Family Center — motivates edit), one that should be DV-flagged but isn't (Safe Passage House — motivates DV config). Real NC cities/zips, fictitious names.
- [x] T-25: Playwright e2e: full demo lifecycle — admin imports `nc-211-sample.csv` via Import 211 page, preview shows correct column mapping, confirms import, verifies 3 shelters appear in Shelters tab
- [x] T-26: Playwright e2e: admin clicks Edit on the phone-correction shelter, fixes phone number, saves, verifies updated value in Shelters tab
- [x] T-27: Playwright e2e: admin (PLATFORM_ADMIN, dvAccess=true) clicks Edit on the DV shelter, sets dvShelter flag, saves, verifies DV status applied. Must use adminPage — RLS requires dvAccess to write dv_shelter=true.

### Import/Export — Contract Fixes (D7)

- [x] T-28: Fix `ColumnMappingResponse` → return `{columns: [{sourceColumn, targetField, sampleValues}], totalRows, unmapped}`. Update controller to parse first 3 data rows for sample values. (D7a)
- [x] T-29: Fix `ImportResultResponse` → rename `errors` to `errorCount`, rename `errorDetails` to `errors`, format each as `"Row N: field — message"` string. Update `ImportResultResponse.from()`. (D7b)
- [x] T-30: Fix `ImportLogResponse` → rename `createdCount/updatedCount/skippedCount/errorCount` to `created/updated/skipped/errors`. (D7c)
- [x] T-31: Integration tests: verify preview returns columns array with sample values and totalRows
- [x] T-32: Integration tests: verify import result returns errors as string array
- [x] T-33: Integration tests: verify import history returns correct field names

### Import/Export — CSV Parser Replacement (D8)

- [x] T-34: Add Apache Commons CSV dependency to pom.xml
- [x] T-35: Rewrite `TwoOneOneImportAdapter.parseCsv()` and `parseCsvRow()` to use Commons CSV. Handle BOM, escaped quotes, embedded newlines. Keep fuzzy header matching.
- [x] T-36: Integration test: CSV with UTF-8 BOM imports correctly (first column maps properly)
- [x] T-37: Integration test: CSV with escaped quotes parses correctly
- [x] T-38: Add coordinate validation in `ShelterImportService.sanitizeCoordinates()` — lat -90..90, lng -180..180. Invalid coords set to null with warning.
- [x] T-39: Integration test: CSV with invalid coordinates imports with null coords

### Import/Export — Security (D9, D10)

- [x] T-40: Add `spring.servlet.multipart.max-file-size=10MB` and `max-request-size=10MB` to application.yml. Handle `MaxUploadSizeExceededException` in `GlobalExceptionHandler` with 413 response.
- [x] T-41: Add CSV injection sanitization to `HicPitExportService.escCsv()` — prefix cells starting with `=`, `+`, `-`, `@` with tab character inside quotes per OWASP.
- [x] T-42: Integration test: file exceeding size limit returns 413 (dedicated test class with @TestPropertySource max-file-size=256KB)
- [x] T-43: Integration test: HIC export with formula-prefixed shelter name produces sanitized CSV cell
- [x] T-44: Integration test: cross-tenant import isolation — import history is tenant-scoped via TenantContext

### Import/Export — i18n

- [x] T-45: Add i18n keys for TwoOneOneImportPage.tsx (~15 hardcoded strings) — en.json + es.json: drag/drop text, preview button, confirm button, success/error messages, column labels
- [x] T-46: Add i18n keys for HsdsImportPage.tsx (~10 hardcoded strings) — en.json + es.json: drag/drop text, upload button, success/error messages

### Import/Export — Additional Test Coverage

- [x] T-47: Integration test: HSDS export format — existing test_hsdsExport already covers structure (organization, service, location, fabt: extensions)
- [x] T-48: Integration test: HSDS export DV redaction for non-dvAccess user — tests RLS visibility + address field removal
- [x] T-49: Integration test: HIC CSV has correct column headers, valid row format, and consistent column count per row
- [x] T-50: Mark HMIS vendor stub endpoints as `@Deprecated(forRemoval=true)`, return 501 Not Implemented instead of fake success

### Screenshots & GitHub Pages (D5, D11)

> **Simone's lens (D5):** Every caption leads with the human story. The person in crisis is visible. Technology is invisible. Copy must pass the Keisha dignity test. No overclaimed partnerships (Casey's truthfulness rule).
> **Devon's lens:** Each card self-explanatory without external context. Marcus can follow this step-by-step with zero training.

- [x] T-51: Screenshots captured via Playwright capture-screenshots.spec.ts — 7 new images (20-import-211-preview through 26-coordinator-edit-form)
- [x] T-52: Create `demo/shelter-onboarding.html` — 7-card walkthrough page with story-first captions (D11). 3 acts: Import → Correct → Protect. Simone/Devon/Keisha lenses applied.
- [x] T-53: Update `demo/index.html` — Card 11 caption refreshed with edit + import mention. "Shelter Onboarding" link added to "More Walkthroughs" footer.
- [x] T-54: sitemap.xml updated with shelter-onboarding.html entry. Open Graph + Twitter Card meta tags on new page.
- [x] T-55: Update FOR-DEVELOPERS.md — project status, shelter edit notes, migration count (27→29)
- [x] T-56: Write demo walkthrough narrative for shelter-edit + 211 import lifecycle — story-first, reviewed through Simone/Keisha/Marcus persona lenses (demo/shelter-edit-walkthrough.md)

### Verification

- [x] T-57: Run full backend test suite (including ArchUnit) — all green (290 tests, 0 failures)
- [x] T-58: Run full Playwright test suite — all green (159 passed, 2 skipped, 0 failed)
- [x] T-59: ESLint + TypeScript clean
- [ ] T-60: CI green on all jobs
- [ ] T-61: Merge to main, tag
