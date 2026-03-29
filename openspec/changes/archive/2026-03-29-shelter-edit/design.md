## Context

ShelterForm.tsx is create-only. The Admin Shelters tab shows a read-only table. The Coordinator dashboard only allows bed availability updates, not shelter detail edits. The API supports PUT /api/v1/shelters/{id} for COORDINATOR+ but no frontend uses it. DV shelters have special sensitivity — changing the DV flag or address could expose a survivor's location.

## Goals / Non-Goals

**Goals:**
- Reuse ShelterForm for both create and edit modes
- Admin can edit all shelter fields from the Shelters tab
- Coordinator can edit own shelter's operational details (phone, hours, constraints)
- DV shelter edits have tiered safeguards (role-gated fields, confirmation dialogs, audit logging)

**Non-Goals:**
- Shelter deactivation/archival (future change)
- Shelter transfer between tenants
- Bulk shelter editing
- Shelter merge/duplicate detection

## Decisions

### D1: ShelterForm mode detection via initialData prop

If `initialData` is provided, form is in edit mode (PUT on save). If not, create mode (POST). Parent component handles the routing: `/coordinator/shelters/new` for create, `/coordinator/shelters/:id/edit` for edit. Form fields identical in both modes except disabled fields for role-based restrictions.

### D2: Tiered field sensitivity

| Field Category | Examples | Who Can Edit | UX |
|---|---|---|---|
| Operational | phone, curfew, max stay, accepting guests | COORDINATOR+ | Immediate save |
| Structural | name, address, population types, capacity | COC_ADMIN+ | Save + audit log |
| Safety-critical | dvShelter flag | COC_ADMIN+ | Confirmation dialog + audit |

Coordinator sees structural fields as read-only in the edit form. COC_ADMIN sees all fields editable.

### D3: DV shelter safeguards

- `dvShelter` toggle: disabled for roles below COC_ADMIN. Not hidden (transparency), but locked with tooltip "Contact your CoC administrator to change DV status."
- Changing `dvShelter` from true→false: confirmation dialog explaining "This will make the shelter address visible to all users including outreach workers without DV authorization."
- Backend enforcement: PUT /api/v1/shelters/{id} checks role if `dvShelter` field is changing. Returns 403 if COORDINATOR tries to change it.
- Address changes on DV shelters: audit-logged with old/new values.

### D4: Edit navigation paths

- Admin Shelters tab: "Edit" link in each table row → navigates to `/coordinator/shelters/:id/edit`
- Coordinator dashboard: "Edit Details" button on expanded shelter card → same route
- After save: navigate back to the originating page (admin or coordinator)

### D5: Demo flow — 211 Import → Edit lifecycle

The demo tells Marcus's onboarding story: a CoC admin receives a 211 CSV from NC 211 (iCarol export), imports it, reviews the imported shelters, and edits one to correct details and configure DV status. This is the realistic first-day experience for a new CoC joining the platform.

**Demo sequence:**
1. Admin navigates to Imports tab, selects "Import 211 Data"
2. Uploads a curated demo CSV (3 shelters: one standard, one needing phone correction, one needing DV flag set)
3. Preview screen shows column mapping — confirms fuzzy matching worked
4. Confirms import — success summary shows 3 created
5. Admin navigates to Shelters tab — sees 3 new shelters
6. Clicks "Edit" on the shelter needing correction — fixes phone number, saves
7. Clicks "Edit" on the shelter needing DV configuration — sets dvShelter flag with confirmation dialog

**Demo CSV file:** A curated `demo/data/nc-211-sample.csv` with realistic NC shelter data using iCarol-style headers (`agency_name`, `street_address`, `address_city`, `address_state`, `postal_code`, `telephone`). Data should feel real but use fictitious names — no actual shelter data.

**Screenshot and copy guidelines (Simone's lens):**
- Every screenshot caption leads with the human story, not the feature name
- "Marcus is onboarding three new partner shelters from the region's 211 database" — not "Admin imports CSV file"
- The person in crisis should be visible in every narrative beat — why does this import matter? Because every hour a shelter isn't in the system is an hour a family can't find it
- Technology should be invisible — the story is about shelters joining the network, not about CSV parsing
- Copy must pass the Keisha test: does this language center the people being served?

**DV configuration screenshot note:** The DV flag change requires `dvAccess=true` (RLS enforcement). In the dev seed data, only `admin@dev.fabt.org` (PLATFORM_ADMIN) has dvAccess. Screenshots for T-30 (DV configuration) must use the PLATFORM_ADMIN account. The persona narrative uses "Marcus" (CoC Admin) because in production, a COC_ADMIN would have dvAccess granted — the seed data limitation is a dev environment choice, not a design constraint.

### D6: Demo data curation principles

The demo CSV must feel authentic without using real shelter data:
- Use fictitious but plausible NC shelter names (e.g., "Hope Harbor Emergency Shelter", "Sunrise Family Center")
- Use real NC city names and valid NC zip codes for geographic plausibility
- Include one shelter with a phone number that's "wrong" (555 prefix) to motivate the edit
- Include one shelter that should be DV but isn't flagged yet — motivates the DV configuration story
- Headers use iCarol-style column names (`agency_name`, `street_address`, etc.) to demonstrate fuzzy matching

### D7: Import/Export contract alignment

The audit revealed three frontend-backend contract mismatches that break the import UI:

**D7a: Preview response** — Backend `ColumnMappingResponse` returns `{mapped: Map, unmapped: List}`. Frontend expects `{columns: [{sourceColumn, targetField, sampleValues}], totalRows}`. Fix: rewrite `ColumnMappingResponse` to return the structure the frontend expects, including sample values extracted from the first 3 data rows of the CSV.

**D7b: Import result errors** — Backend `ImportResultResponse` returns `errors: int` (count) + `errorDetails: List<ImportErrorDto>`. Frontend expects `errors: string[]`. Fix: change backend field name from `errors` to `errorCount`, rename `errorDetails` to `errors`, and format each `ImportErrorDto` as `"Row N: field — message"` strings. This matches the frontend contract and provides human-readable error messages.

**D7c: Import history field names** — Backend `ImportLogResponse` uses `createdCount/updatedCount/skippedCount/errorCount`. Frontend expects `created/updated/skipped/errors`. Fix: rename backend fields to match frontend (drop the `Count` suffix).

### D8: CSV parser replacement

Replace the hand-rolled CSV parser in `TwoOneOneImportAdapter` with Apache Commons CSV. The current parser (lines 228-255) doesn't handle escaped quotes inside quoted fields, BOM bytes, or encoding detection. Apache Commons CSV handles RFC 4180 edge cases, BOM transparency, and is battle-tested.

### D9: CSV injection protection on exports

HIC/PIT CSV exports write shelter names and other user-supplied strings directly to CSV cells via `escCsv()`. Cells starting with `=`, `+`, `-`, `@` are interpreted as formulas by Excel. Fix: prefix dangerous cells with a tab character inside quotes (`"\t=SUM"`) per OWASP guidance. Apply to `HicPitExportService.escCsv()`.

### D10: File upload security

Add `spring.servlet.multipart.max-file-size=10MB` and `max-request-size=10MB` in application.yml. Handle `MaxUploadSizeExceededException` in `GlobalExceptionHandler` with a 413 response.

### D11: GitHub Pages integration strategy

The shelter-edit screenshots integrate into the GitHub Pages site following the story-redesign pattern (archived change 2026-03-28). The main walkthrough tells *one story* — Darius's crisis → Sandra's dashboard → administration. Adding 7 import cards would dilute that narrative.

**Decision: Dedicated page + light touch on main walkthrough.**

1. **`demo/shelter-onboarding.html`** — New standalone walkthrough page with 7 cards telling Marcus's onboarding story (import → edit → DV). Same dark-mode design system as existing walkthrough pages.

2. **Main walkthrough (`demo/index.html`)** — Two changes only:
   - Update Card 11 (Shelter Management) caption to mention edit and import capability
   - Add "Shelter Onboarding" to the "More Walkthroughs" footer alongside DV, HMIS, Analytics

3. **Narrative voice** — Same as story-redesign: lead with the human story, keep technology invisible, pass Keisha's dignity test. Devon's lens: each card should be self-explanatory enough that Marcus can follow it without training.

**Not adding:** Individual import/edit/DV cards to the main walkthrough. The main walkthrough stays focused on the crisis-to-resolution arc. The onboarding story lives in its own page.

## Risks / Trade-offs

- **Coordinator editing wrong shelter**: mitigated by existing coordinator-shelf assignment checks in backend (coordinators can only edit shelters they're assigned to).
- **DV flag change race condition**: if two admins edit simultaneously and one changes DV flag, the other's save could overwrite it. Mitigated by optimistic locking (version field on shelter entity, 409 on conflict).
- **Demo data authenticity vs. privacy**: demo CSV uses fictitious shelter names to avoid implying partnerships that don't exist (Casey's truthfulness rule). City names and zip codes are real for geographic plausibility.
- **CSV parser dependency**: Adding Apache Commons CSV is a new dependency (~70KB). Trade-off accepted — hand-rolled parsers are the #1 source of CSV import bugs in civic tech systems (Queensland Health payroll, Healthcare.gov). The OWASP File Upload Cheat Sheet explicitly recommends against custom parsers.
