## Why

Shelters can be created but never edited from the UI. Sandra (Coordinator) can't update her shelter's phone number when it changes. Marcus (CoC Admin) can't fix an address typo from onboarding. Reverend Monroe can't reactivate her seasonal shelter or update capacity for winter. All of these require direct database access or developer intervention — a self-service gap that blocks daily operations and makes the platform look incomplete in procurement review.

## What Changes

- **ShelterForm edit mode**: reuse existing ShelterForm.tsx (currently create-only) with `initialData` prop for edit. POST for create, PUT for edit. Route: `/coordinator/shelters/:id/edit`.
- **Admin Shelters tab — edit link**: "Edit" button on each shelter row, navigates to ShelterForm in edit mode. COC_ADMIN+ can edit all fields.
- **Coordinator dashboard — edit own shelter**: "Edit Details" button on expanded shelter card. Coordinators can edit phone, curfew, max stay, constraints, accepting new guests. Cannot edit name, address, DV flag (admin-only).
- **DV shelter safeguards**: dvShelter flag locked below COC_ADMIN. Changing DV→non-DV requires confirmation dialog. Address changes on DV shelters logged and flagged. Backend enforcement on the PATCH endpoint.
- **Demo flow — 211 Import → Edit lifecycle**: A new guided demo sequence showing the realistic onboarding story: admin uploads a 211 CSV file (matching NC 211/iCarol export format), shelters are created via bulk import, admin reviews and edits one shelter to correct details and configure DV status. Demonstrates the full lifecycle from data ingestion to operational readiness.
- **Import/export hardening**: Fix three frontend-backend contract mismatches (preview response, import result errors, import history field names) that break the import UI. Harden CSV parsing (replace hand-rolled parser with Apache Commons CSV), add file size limits, UTF-8 BOM handling, coordinate validation, CSV injection protection on exports, cross-tenant isolation tests, and i18n for all import page strings.

## Capabilities

### New Capabilities
- `shelter-edit`: Shelter edit form (create/edit mode), admin and coordinator edit paths, DV shelter safeguards with tiered field sensitivity
- `demo-211-import-edit`: Demo flow showing 211 CSV import creating shelters, followed by admin edit to correct details and configure DV status — tells the onboarding story

### Modified Capabilities
- `data-import`: Fix preview/result/history API contracts, replace CSV parser, add file size limits, BOM handling, coordinate validation, i18n
- `data-export`: CSV injection protection on HIC/PIT exports, HSDS export integration tests

## Impact

- **Backend**: Shelter edit endpoint validation for DV safeguards, field-level authorization checks, audit logging for sensitive field changes. Import/export contract fixes, CSV parser replacement, file size limits, CSV injection sanitization, coordinate validation.
- **Frontend**: ShelterForm edit mode detection, admin Shelters tab edit link, coordinator dashboard edit button, DV confirmation dialog. Import page i18n, preview/result response handling fixes.
- **Demo / GitHub Pages**: New `shelter-onboarding.html` walkthrough page with 7-card narrative flow (import → edit → DV safeguards). Main walkthrough updated: Card 11 refreshed with edit capability mention, DV confirmation dialog added as new card, "Shelter Onboarding" link added to More Walkthroughs footer. Follows the story-redesign pattern (Simone: story-first, person-visible, technology-invisible; Devon: can a volunteer follow this with zero training?).
- **Testing**: Backend integration tests for shelter edit, DV safeguards, import/export contracts, cross-tenant isolation, CSV edge cases, HSDS export format. Playwright e2e for edit flow, DV confirmation, and 211-import-to-edit lifecycle. Screenshot captures.
