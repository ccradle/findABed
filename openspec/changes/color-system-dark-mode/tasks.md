## Tasks

### Setup

- [x] T-0: Create branch `feature/color-system-dark-mode` in code repo (`finding-a-bed-tonight`)

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

- [x] T-27: Draft coordinator quick-start card content — 5-step flow (front) + 5 troubleshooting scenarios (back) + freshness badges + Edit Details mention
- [x] T-28: Print-ready layout with `@media print` styles, dark mode support, B&W compatible. CoC admin contact fill-in fields.
- [x] T-29: Created `docs/training/coordinator-quick-start.html` in docs repo (same pattern as outreach-one-pager.html)

### Freshness Badge Explanation (Devon #5, partial)

- [x] T-30: Freshness badge explanation incorporated into coordinator quick-start card (FRESH/AGING/STALE with plain-language guidance)
- [x] T-31: Added `title` tooltip to DataAge.tsx with i18n freshness explanations (en + es). Visible on hover/focus.

### Admin Onboarding Checklist (Devon #5)

- [x] T-32: Created `docs/training/admin-onboarding-checklist.html` — fillable print-ready checklist with 12 steps across 3 phases (Setup/Verification/Go Live), includes 211 import, DV config, quick-start card delivery

### Error Recovery Guidance (Devon #7)

- [x] T-33: Error recovery incorporated into quick-start card back panel (5 scenarios: can't log in, not sure if saved, offline, numbers wrong, temporary closure). CoC admin contact fill-in box.

### Training Verification

- [x] T-34: Persona review: Sandra (5-step flow, under 30 seconds), Rev. Monroe (zero training — card is self-contained), Devon (print-first, laminated card format), Simone (mission statement leads, technology invisible), Keisha (language centers the person being served)

---

## Track 3 — HIC/PIT Export Hardening

> Riley: "If Marcus hands this to HUD, it gets rejected before a human looks at it."
> Kenji: "Element 2.07 is correct but the implementation doesn't conform."
> Casey: "The docs are honest. The code should match the honesty."

### HIC CSV Rewrite (D7)

- [x] T-35: Rewrite HIC CSV to match HUD Inventory.csv schema (17 columns). Fixed download bug: `<a href download>` → fetch+blob for JWT auth.
- [x] T-36: `mapHouseholdTypeCode()` returns HUD integers: 1/3/4. Throws on unknown types.
- [x] T-37: ProjectType constant `PROJECT_TYPE_ES_ENTRY_EXIT = 0` (FY2024 split)
- [x] T-38: CoCCode populated from tenant slug
- [x] T-39: InventoryID as deterministic UUID from shelterId + populationType
- [x] T-40: Availability = 1 (Year-round) default
- [x] T-41: ESBedType = 1 (Facility-based) default
- [x] T-42: Veteran bed breakdown — VetBedInventory from VETERAN pop type, others 0
- [x] T-43: InventoryStartDate from shelter createdAt, InventoryEndDate empty for active
- [x] T-44: DV aggregated row uses HUD integer codes, empty ProjectID/InventoryID
- [x] T-45: mapHouseholdTypeCode() throws IllegalArgumentException on unknown types

### PIT CSV Update

- [x] T-46: PIT CSV uses integer codes (ProjectType=0, HouseholdType 1/3/4). Code comment documents HDX 2.0 note.
- [x] T-47: PIT DV aggregation uses HUD integer codes

### HIC/PIT Testing

- [x] T-48: Integration test: HIC header exact match + all required HUD columns present
- [x] T-49: Integration test: HIC HouseholdType integers verified in all data rows
- [x] T-50: Integration test: row-by-row content validation (30 family beds, 10 vet beds — exact column values verified)
- [x] T-51: Integration test: consistent column count across all rows
- [x] T-52: Integration test: CSV round-trip parsed by Apache Commons CSV — proves standard parser compatibility
- [x] T-53: Integration test: null population type skips row with warning (no NPE)
- [x] T-54: Integration test: DV suppression with < 3 shelters (no aggregate row with empty IDs)
- [x] T-55: Integration test: unknown population type → 400 (with cleanup to prevent test poisoning)
- [x] T-55b: Playwright E2E: click Download HIC CSV → receive file → validate HUD headers, integer codes, column count, no string leaks
- [x] T-55c: Playwright E2E: click Download PIT CSV → receive file → validate header, ProjectType=0, HouseholdType integers
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
