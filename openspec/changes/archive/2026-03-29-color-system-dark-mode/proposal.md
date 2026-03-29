## Why

Three forces converge to make this the right moment for a combined usability and adoption push:

**Color & dark mode:** The frontend uses 73 unique hardcoded hex colors across 18 component files with no shared tokens. The GitHub Pages site supports dark mode, but the React app does not — a brand disconnect when Darius moves from the demo site to the app at midnight on his Android phone. The typography migration (v0.16.0) proved the pattern. Colors should follow.

**Training gaps:** Devon Kessler's training assessment (TRAINING-ASSESSMENT.md) identifies 7 gaps that block pilot onboarding. The coordinator quick-start card, freshness badge explanation, and error recovery guidance are prerequisites for the first real coordinator. These are not optional documentation — they are the difference between a coordinator who updates bed counts and one who stops after the first week.

**HIC/PIT export accuracy:** The HIC/PIT export claims to "align with HUD format" but the audit reveals the CSV headers, column structure, and coded values don't match the actual HUD Inventory.csv schema (FY2024+). HouseholdType uses strings ("Families") instead of HUD integers (3). Required columns are missing (CoCCode, InventoryID, veteran bed breakdown). Riley: "If Marcus hands this to HUD, it gets rejected before a human looks at it." The docs are honest (disclaim certification) but the implementation gap undermines trust.

## What Changes

**Track 1 — Color System & Dark Mode:**
- Define canonical brand palette as CSS custom properties in `global.css` (~24 semantic tokens × 2 modes = 48 properties)
- Add dark mode via `@media (prefers-color-scheme: dark)` — system-only, no manual toggle
- Create shared TypeScript color constants (`colors.ts`)
- Migrate all 18 component files from 73 hardcoded hex values to semantic color tokens (593 instances)
- Verify WCAG 4.5:1 contrast ratios in both light and dark modes
- Add Playwright tests for dark mode rendering, contrast, and regression

**Track 2 — Training Materials (Devon's gaps):**
- Coordinator quick-start card (1-page print PDF, front: 5-step update flow, back: troubleshooting)
- Freshness badge explanation (FRESH/AGING/STALE in plain language — "STALE means call before driving")
- Admin onboarding checklist (fillable PDF, per-shelter, includes 211 import and DV config steps)
- Error recovery guidance ("If Something Goes Wrong" section for job aids)
- Import page in-app help text improvements
- Defer: DV referral workflow cards (need DV practitioner review), outreach worker 5-min onboarding (needs running app gap analysis)

**Track 3 — HIC/PIT Export Hardening:**
- Rewrite HIC CSV to match HUD Inventory.csv schema (FY2024+): correct column headers, integer codes for HouseholdType/ProjectType/Availability/ESBedType/TargetPopulation/HMISParticipation
- Add missing required columns: CoCCode, InventoryID, veteran bed breakdown (CHVetBedInventory, YouthVetBedInventory, VetBedInventory, etc.)
- Fix DV shelters: HMISParticipation = 2 (Comparable Database), not 1
- Fix ES ProjectType: support both Entry/Exit (0) and Night-by-Night (1) per FY2024 split
- Fix mapHouseholdType() default case: throw on unknown types instead of silent pass-through
- Edge case tests: 0 shelters, 0 beds, null population type, exactly 3 DV shelters boundary
- Update docs to reflect actual HUD alignment status

## Capabilities

### New Capabilities
- `color-system`: CSS custom properties for all colors with light/dark mode sets, shared TypeScript constants
- `dark-mode`: System-only `prefers-color-scheme` support across all views
- `training-materials`: Coordinator quick-start card, freshness explanation, admin checklist, error recovery guidance

### Modified Capabilities
- `wcag-accessibility-compliance`: Contrast verification in both light and dark modes (4.5:1 minimum)
- `data-export`: HIC/PIT CSV rewritten to match HUD Inventory.csv schema (FY2024+)

## Impact

- **Frontend**: `global.css` extended with ~48 color properties, new `colors.ts`, all 18 component files migrated, dark mode support. In-app help text for import pages.
- **Backend**: HicPitExportService rewritten — column headers, coded values, missing columns, DV participation type, edge case handling.
- **Docs**: Coordinator quick-start card (PDF), admin onboarding checklist (PDF), freshness badge explanation, FOR-DEVELOPERS updated.
- **Testing**: Playwright dark mode tests + axe-core contrast scans. HIC/PIT format validation tests with HUD schema assertions. Training material review against personas.
- **Demo**: Dark mode screenshots captured. Light mode screenshots recaptured with color tokens.
