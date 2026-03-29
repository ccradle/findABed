## Tasks

> **Dependency:** This change requires the `audit_events` table from `admin-user-management` (T-2).
> Implement `admin-user-management` first, or extract the audit table migration into a shared prerequisite.

### Setup

- [ ] T-0: Create branch `feature/shelter-edit` in code repo (`finding-a-bed-tonight`)

### Backend — DV Safeguards

- [ ] T-1: `ShelterService.updateShelter()` — enforce role check if dvShelter field is changing (COC_ADMIN+ required, 403 for COORDINATOR)
- [ ] T-2: Audit log DV shelter address changes (old/new values) via audit_events table (from admin-user-management change)
- [ ] T-3: Audit log DV flag changes with elevated visibility

### Backend — Tests

- [ ] T-4: Integration test: coordinator edits shelter phone — succeeds
- [ ] T-5: Integration test: coordinator changes dvShelter flag — returns 403
- [ ] T-6: Integration test: COC_ADMIN changes dvShelter flag — succeeds with audit
- [ ] T-7: Integration test: coordinator edits unassigned shelter — returns 403

### Frontend — ShelterForm Edit Mode

- [ ] T-8: Update ShelterForm.tsx — accept `initialData` prop, detect edit mode, PUT on save instead of POST
- [ ] T-9: Add route `/coordinator/shelters/:id/edit` that fetches shelter data and passes to ShelterForm
- [ ] T-10: In edit mode, disable fields based on role (COORDINATOR: name, address, DV flag read-only)
- [ ] T-11: DV flag toggle: disabled for COORDINATOR with tooltip. For COC_ADMIN: confirmation dialog on true→false change

### Frontend — Navigation

- [ ] T-12: Admin Shelters tab: add "Edit" link on each shelter row, navigates to edit route
- [ ] T-13: Coordinator dashboard: add "Edit Details" button on expanded shelter card
- [ ] T-14: After save, navigate back to originating page (admin or coordinator)

### Frontend — i18n & Accessibility

- [ ] T-15: Add i18n keys for shelter edit (en.json + es.json): edit button, confirmation dialog, field tooltips
- [ ] T-16: WCAG: form fields have labels, disabled fields have aria-disabled, confirmation dialog is keyboard-navigable

### Frontend — Tests

- [ ] T-17: Playwright: admin edits shelter name via Shelters tab, saves, verifies
- [ ] T-18: Playwright: coordinator edits phone from dashboard, saves, verifies
- [ ] T-19: Playwright: coordinator sees DV flag disabled with tooltip
- [ ] T-20: Playwright: COC_ADMIN changes DV flag, confirmation dialog appears

### Docs-as-Code — DBML, OpenAPI, ArchUnit

- [ ] T-21: Verify `docs/schema.dbml` matches current shelter table schema (no new columns expected, but confirm)
- [ ] T-22: Verify `@Operation` annotation exists on PUT /api/v1/shelters/{id} — add or update summary to reflect edit capabilities and DV safeguards
- [ ] T-23: Verify ArchUnit boundary rules pass — shelter edit logic stays in shelter module, DV safeguard audit uses shared event bus (not direct audit repo access)

### Screenshots & Documentation

- [ ] T-24: Capture screenshots: shelter edit form (admin), shelter edit form (coordinator), DV confirmation dialog
- [ ] T-25: Update FOR-DEVELOPERS.md — project status, shelter edit notes
- [ ] T-26: Update demo walkthrough captions if needed

### Verification

- [ ] T-27: Run full backend test suite (including ArchUnit) — all green
- [ ] T-28: Run full Playwright test suite — all green
- [ ] T-29: ESLint + TypeScript clean
- [ ] T-30: CI green on all jobs
- [ ] T-31: Merge to main, tag
