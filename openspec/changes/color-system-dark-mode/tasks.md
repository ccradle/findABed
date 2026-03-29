## Tasks

### Setup

- [ ] T-0: Create branch `feature/color-system-dark-mode` in code repo (`finding-a-bed-tonight`)

---

## Track 1 — Color System & Dark Mode

### Color Token Infrastructure

- [ ] T-1: Audit all 18 component files — extract every hardcoded hex color, map to semantic role (brand, surface, text, border, status, badge, safety). Correct the scope: 18 files, 73 unique hex values, 593 instances.
- [ ] T-2: Define light mode color tokens in `global.css` as `:root` CSS custom properties (~24 semantic tokens)
- [ ] T-3: Define dark mode overrides in `@media (prefers-color-scheme: dark)` block
- [ ] T-4: Create `frontend/src/theme/colors.ts` — TypeScript constants mirroring CSS properties (same pattern as `typography.ts`)
- [ ] T-5: Verify WCAG 4.5:1 contrast ratios for all token pairs in both light and dark modes (use WebAIM contrast checker, document results in colors.ts header comment)

### Component Migration (Light + Dark)

- [ ] T-6: Migrate `Layout.tsx` — header bg, text, border, nav colors
- [ ] T-7: Migrate `LoginPage.tsx` — form bg, input borders, button colors
- [ ] T-8: Migrate `OutreachSearch.tsx` — card bg, badge colors, filter styles, hold button
- [ ] T-9: Migrate `CoordinatorDashboard.tsx` — shelter cards, availability forms, stepper colors, Edit Details button
- [ ] T-10: Migrate `AdminPanel.tsx` — tab styles, table colors, form elements, all sub-tabs, Edit links
- [ ] T-11: Migrate `ShelterForm.tsx` + `ShelterEditPage.tsx` — form bg, input borders, DV toggle, confirmation dialog
- [ ] T-12: Migrate `NotificationBell.tsx` — dropdown bg, badge colors, item hover
- [ ] T-13: Migrate `ConnectionStatusBanner.tsx` — amber/green banner colors
- [ ] T-14: Migrate `LocaleSelector.tsx`, `OfflineBanner.tsx`, `SessionTimeoutWarning.tsx`, `ChangePasswordModal.tsx`
- [ ] T-15: Migrate `DataAge.tsx` — freshness badge colors (Fresh/Aging/Stale). Ensure dark mode variants meet 4.5:1 on dark bg.
- [ ] T-16: Migrate `AnalyticsTab.tsx` — Recharts colors via props (stroke, fill, axis, grid). Recharts does NOT read CSS variables from DOM. (D5)
- [ ] T-17: Migrate `TwoOneOneImportPage.tsx`, `HsdsImportPage.tsx` — import page colors
- [ ] T-18: Migrate `UserEditDrawer.tsx` — drawer bg, border, status badge colors
- [ ] T-19: Verify no raw hex values remain in any .tsx file (automated grep check)

### Dark Mode Testing

- [ ] T-20: Playwright: emulate `prefers-color-scheme: dark`, verify app renders with dark colors on all key views
- [ ] T-21: Playwright: axe-core accessibility scan in dark mode — zero contrast violations
- [ ] T-22: Playwright: axe-core accessibility scan in light mode — verify no regressions from migration
- [ ] T-23: Playwright: screenshot capture in dark mode for visual comparison
- [ ] T-24: Playwright: verify no hardcoded hex colors in rendered DOM (automated grep of computed styles)

### Color System Docs

- [ ] T-25: Document color token naming convention in `colors.ts` header comment (for future developers)
- [ ] T-26: Add to CONTRIBUTING.md or colors.ts: "Use `color.*` tokens for all new components, never hardcoded hex"

---

## Track 2 — Training Materials (Devon's Gaps)

> Devon's lens: "Can Reverend Monroe's 67-year-old volunteer coordinator do this with zero training?"
> Simone's lens: "Does this make the person in crisis more visible, or the technology more visible?"

### Coordinator Quick-Start Card (Devon #1 — highest priority)

- [ ] T-27: Draft coordinator quick-start card content — front: 5-step update flow (login with tenant slug, find shelter, update occupied, save, confirm). Back: "If Something Goes Wrong" (can't log in, not sure if saved, offline). Include "Edit Details" for shelter info changes.
- [ ] T-28: Design quick-start card layout (print-ready, front+back, works in B&W). Co-production: Devon (instructional design) + Simone (voice, layout). Target: laminated card at front desk.
- [ ] T-29: Create `docs/training/coordinator-quick-start.html` — print-ready page with `@media print` styles (same pattern as outreach-one-pager.html)

### Freshness Badge Explanation (Devon #5, partial)

- [ ] T-30: Add freshness badge plain-language explanation to coordinator quick-start card: "FRESH = updated in last hour. AGING = 1-8 hours ago — data may be outdated. STALE = 8+ hours — call the shelter before driving there."
- [ ] T-31: Add tooltip or help text to `DataAge.tsx` component explaining freshness in-app (visible on hover/focus, accessible)

### Admin Onboarding Checklist (Devon #5)

- [ ] T-32: Create `docs/training/admin-onboarding-checklist.html` — fillable print-ready checklist, one per shelter. Steps: create profile (or 211 import), edit/verify details, configure DV if needed, create coordinator account, assign coordinator, deliver quick-start card, verify first login, verify first update, go live. Date/name fields per step.

### Error Recovery Guidance (Devon #7)

- [ ] T-33: Incorporate error recovery into quick-start card back panel (3 scenarios: tenant slug, save confirmation, offline). Include CoC admin contact placeholder.

### Training Verification

- [ ] T-34: Review all training materials through persona lenses: Sandra (30-second test), Reverend Monroe (zero training), Devon (format-first), Simone (story-first, technology-invisible)

---

## Track 3 — HIC/PIT Export Hardening

> Riley: "If Marcus hands this to HUD, it gets rejected before a human looks at it."
> Kenji: "Element 2.07 is correct but the implementation doesn't conform."
> Casey: "The docs are honest. The code should match the honesty."

### HIC CSV Rewrite (D7)

- [ ] T-35: Rewrite HIC CSV header to match HUD Inventory.csv schema: `InventoryID,ProjectID,CoCCode,HouseholdType,Availability,UnitInventory,BedInventory,CHVetBedInventory,YouthVetBedInventory,VetBedInventory,CHYouthBedInventory,YouthBedInventory,CHBedInventory,OtherBedInventory,ESBedType,InventoryStartDate,InventoryEndDate`
- [ ] T-36: Add `mapHouseholdTypeCode()` returning HUD integers: 1 (without children), 3 (adult+child), 4 (children only). Throw on unknown types.
- [ ] T-37: Add `mapProjectTypeCode()` returning HUD integers: 0 (ES Entry/Exit) or 1 (ES Night-by-Night). Default to 0 for now (FABT is entry/exit model).
- [ ] T-38: Add CoCCode column populated from tenant slug or configured CoC code
- [ ] T-39: Add InventoryID column (generate deterministic UUID from shelterId + populationType)
- [ ] T-40: Add Availability column (default 1=Year-round; future: derive from shelter constraints or surge association)
- [ ] T-41: Add ESBedType column (default 1=Facility-based)
- [ ] T-42: Add veteran bed breakdown columns — populate VetBedInventory from VETERAN population type, others default to 0
- [ ] T-43: Add InventoryStartDate (shelter createdAt) and InventoryEndDate (null for active shelters)
- [ ] T-44: Fix DV aggregated row: HMISParticipation = 2 (Comparable Database), TargetPopulation = 1 (DV)
- [ ] T-45: Fix mapHouseholdType() default case: throw IllegalArgumentException on unknown population types

### PIT CSV Update

- [ ] T-46: Update PIT CSV header to use integer codes matching HUD structure (HouseholdType as int, ProjectType as int)
- [ ] T-47: Ensure PIT DV aggregation uses correct HMISParticipation (2) and TargetPopulation (1) codes

### HIC/PIT Testing

- [ ] T-48: Integration test: HIC CSV has correct HUD column headers (exact match)
- [ ] T-49: Integration test: HIC HouseholdType values are integers (1, 3, 4), not strings
- [ ] T-50: Integration test: HIC DV aggregated row has HMISParticipation=2 and TargetPopulation=1
- [ ] T-51: Integration test: HIC veteran beds populate VetBedInventory column correctly
- [ ] T-52: Integration test: HIC with 0 shelters returns header-only CSV
- [ ] T-53: Integration test: HIC with null population type skips row (no NPE)
- [ ] T-54: Integration test: HIC with exactly 3 DV shelters includes aggregated row (boundary)
- [ ] T-55: Integration test: mapHouseholdType() throws on unknown population type
- [ ] T-56: Update FOR-COC-ADMINS.md HIC/PIT section — note FY2024+ format alignment, list columns

---

## Screenshots & Documentation

- [ ] T-57: Capture dark mode screenshots: login, search, coordinator, admin (supplementary to light mode)
- [ ] T-58: Recapture light mode screenshots with color tokens (capture.sh)
- [ ] T-59: Update FOR-DEVELOPERS.md — color system section, dark mode, HIC/PIT format alignment, training materials
- [ ] T-60: Update README.md — version, test counts, feature list

### Verification

- [ ] T-61: Run full backend test suite — all green
- [ ] T-62: Run full Playwright test suite — all green in both light and dark modes
- [ ] T-63: ESLint + TypeScript clean
- [ ] T-64: CI green on all jobs
- [ ] T-65: Merge to main, tag
