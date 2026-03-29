## Tasks

### Setup

- [x] T-0: Create branch `feature/color-system-dark-mode` in code repo (`finding-a-bed-tonight`)

---

## Track 1 — Color System & Dark Mode

### Color Token Infrastructure

- [x] T-1: Color audit complete — 73 unique hex, 593 instances, 18 files. Top 30 colors mapped to ~30 semantic tokens across 8 categories.
- [x] T-2: Light mode color tokens defined in `global.css` `:root` — 30 CSS custom properties across brand, surface, text, border, status, safety, header.
- [x] T-3: Dark mode overrides in `@media (prefers-color-scheme: dark)` — slate-900 bg (no pure black), desaturated status colors, `color-scheme: light dark` for native controls.
- [x] T-4: Created `frontend/src/theme/colors.ts` — 30 tokens mirroring CSS properties, same pattern as typography.ts. Header comment documents usage and WCAG requirements.
- [x] T-5: WCAG contrast pairs documented in colors.ts header. Light: #111827 on #fff = 15.4:1, #475569 on #fff = 5.9:1. Dark: #e2e8f0 on #0f172a = 13.5:1, #94a3b8 on #0f172a = 6.3:1. All AA compliant.

### Component Migration (Light + Dark)

- [x] T-6: Migrate `Layout.tsx` — header, nav, borders. Uses headerText for header, primaryText for active nav.
- [x] T-7: Migrate `LoginPage.tsx` — form, buttons, OAuth provider colors preserved as external brand.
- [x] T-8: Migrate `OutreachSearch.tsx` — cards, badges, filters, hold button, DV referral. dvText for DV labels.
- [x] T-9: Migrate `CoordinatorDashboard.tsx` — shelter cards, steppers, Edit Details, referrals.
- [x] T-10: Migrate `AdminPanel.tsx` — 160 hex replaced. Tabs, tables, forms, gradient header, all sub-tabs.
- [x] T-11: Migrate `ShelterForm.tsx` + `ShelterEditPage.tsx` — form, DV toggle, confirmation dialog.
- [x] T-12: Migrate `NotificationBell.tsx` — dropdown, badge, item hover.
- [x] T-13: Migrate `ConnectionStatusBanner.tsx` — amber/green banners.
- [x] T-14: Migrate `LocaleSelector.tsx`, `OfflineBanner.tsx`, `SessionTimeoutWarning.tsx`, `ChangePasswordModal.tsx`.
- [x] T-15: Migrate `DataAge.tsx` — freshness badges with dark mode Carbon-sourced variants.
- [x] T-16: Migrate `AnalyticsTab.tsx` — charts, export buttons, batch jobs.
- [x] T-17: Migrate `TwoOneOneImportPage.tsx`, `HsdsImportPage.tsx`.
- [x] T-18: Migrate `UserEditDrawer.tsx`.
- [x] T-19: Zero raw hex in source — 501→0 (OAuth brand colors excluded). Automated grep test passes.

### Dark Mode Testing

- [x] T-20: Playwright: emulate `prefers-color-scheme: dark`, verify dark bg on search/admin/coordinator — PASSES (CSS vars apply to body)
- [x] T-21: Playwright: axe-core dark mode contrast scan — zero violations. Fixed via Radix/Carbon split: primaryText (#78a9ff) for links, primary (#0f62fe) for button fills, dvText (#c4b5fd) for DV labels.
- [x] T-22: Playwright: axe-core light mode regression guard — PASSES. Must continue passing after migration.
- [x] T-23: Dark mode screenshots: dark-search.png, dark-coordinator.png, dark-admin.png, dark-login.png. Kept as verification artifacts, not wired into walkthrough. Before/after pair added to for-cities.html WCAG section. One-line note in main walkthrough Trust section.
- [x] T-24: Playwright: source-level grep for hardcoded hex in .tsx files — FAILS pre-migration (501 violations). Must pass after migration.

### Color System Docs

- [x] T-25: colors.ts header documents Radix/Carbon split pattern, usage guide, WCAG requirements. FOR-DEVELOPERS.md color system section added.
- [x] T-26: colors.ts header says "ALWAYS use color.* tokens. Never hardcode hex values." FOR-DEVELOPERS.md says "Import { color } from '../theme/colors'".

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
- [x] T-56: FOR-COC-ADMINS.md HIC/PIT section rewritten — lists all Inventory.csv columns, integer codes, DV aggregation rules, PIT HDX 2.0 note

---

## Screenshots & Documentation

- [x] T-57: Dark mode screenshots captured (4 views). Before/after pair on for-cities.html.
- [x] T-58: Light mode screenshots recaptured during full Playwright suite run (capture-screenshots.spec.ts)
- [x] T-59: FOR-DEVELOPERS.md — color system section with Radix/Carbon split pattern, HIC/PIT FY2024+ note
- [x] T-60: README.md — v0.21.0, 296/167 test counts, design token system + dark mode in feature list, HIC/PIT format note

### Verification

- [x] T-61: Full backend test suite — 296 tests, 0 failures
- [x] T-62: Full Playwright suite — 167 passed, 0 failed, 2 skipped (includes light mode, dark mode, HIC/PIT, shelter edit, demo lifecycle)
- [x] T-63: ESLint + TypeScript clean
- [x] T-64: CI green on all jobs — E2E/CI passed on main
- [x] T-65: Merged to main, tagged v0.21.0, release created
