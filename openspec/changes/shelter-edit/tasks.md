## Tasks

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

### Screenshots & Documentation

- [ ] T-21: Capture screenshots: shelter edit form (admin), shelter edit form (coordinator), DV confirmation dialog
- [ ] T-22: Update FOR-DEVELOPERS.md — project status, shelter edit notes
- [ ] T-23: Update demo walkthrough captions if needed

### Verification

- [ ] T-24: Run full backend test suite — all green
- [ ] T-25: Run full Playwright test suite — all green
- [ ] T-26: ESLint + TypeScript clean
- [ ] T-27: CI green on all jobs
- [ ] T-28: Merge to main, tag
