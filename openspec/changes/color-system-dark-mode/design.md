## Context

The frontend uses 73 hardcoded hex colors across 18 component files (593 total instances). The typography migration (v0.16.0) established the pattern: CSS custom properties as design tokens with shared TypeScript constants. Colors should follow the same pattern. The GitHub Pages demo site supports `prefers-color-scheme: dark` but the React app does not.

Devon Kessler's training assessment identifies 7 gaps blocking pilot onboarding. The coordinator quick-start card and freshness badge explanation are prerequisites — Sandra Kim doesn't open GitHub.

The HIC/PIT export audit reveals CSV output doesn't match HUD's actual Inventory.csv schema (FY2024+). Column headers, coded values (strings vs integers), and required fields are misaligned. The docs are honest ("designed to align") but the gap undermines trust with Marcus and Teresa.

## Goals / Non-Goals

**Goals:**
- Define canonical brand palette as CSS custom properties in `global.css`
- Add dark mode via `@media (prefers-color-scheme: dark)` — system-only, follows OS setting
- Create shared TypeScript color constants (`colors.ts`) mirroring CSS properties
- Migrate all 18 component files from hardcoded hex to color tokens
- Verify WCAG 4.5:1 contrast ratios in both light and dark modes
- Produce coordinator quick-start card, freshness explanation, admin checklist, error recovery guidance
- Rewrite HIC/PIT CSV to match HUD Inventory.csv schema (FY2024+)

**Non-Goals:**
- Manual dark/light toggle (future — system-only for now)
- Theme customization per tenant
- Color animation transitions between modes
- DV referral workflow cards (deferred — need DV practitioner review per Devon)
- Outreach worker 5-min onboarding (deferred — needs running app gap analysis)
- Full SPM methodology alignment (tracked separately per Kenji's recommendation)

## Decisions

### D1: CSS custom properties with `:root` and `@media (prefers-color-scheme: dark)`

```css
:root {
  /* Brand */
  --color-primary: #1a56db;
  --color-primary-hover: #1e40af;
  --color-header-bg: #1a56db;
  --color-header-text: #ffffff;

  /* Surface */
  --color-bg: #ffffff;
  --color-bg-secondary: #f3f4f6;
  --color-bg-active: #dbeafe;
  --color-bg-highlight: #eff6ff;

  /* Text */
  --color-text: #111827;
  --color-text-secondary: #6b7280;
  --color-text-muted: #9ca3af;
  --color-text-inverse: #ffffff;

  /* Border */
  --color-border: #e5e7eb;
  --color-border-light: #f3f4f6;
  --color-border-focus: #1a56db;

  /* Status */
  --color-success: #047857;
  --color-success-bg: #f0fdf4;
  --color-warning: #d97706;
  --color-warning-bg: #fefce8;
  --color-error: #ef4444;
  --color-error-bg: #fef2f2;
  --color-error-text: #991b1b;

  /* Safety (DV-specific) */
  --color-dv: #7c3aed;
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-primary: #3b82f6;
    --color-primary-hover: #60a5fa;
    --color-header-bg: #1e293b;
    --color-header-text: #e2e8f0;
    --color-bg: #0f172a;
    --color-bg-secondary: #1e293b;
    --color-bg-active: #334155;
    --color-bg-highlight: #1e3a5f;
    --color-text: #e2e8f0;
    --color-text-secondary: #94a3b8;
    --color-text-muted: #64748b;
    --color-text-inverse: #0f172a;
    --color-border: #334155;
    --color-border-light: #1e293b;
    --color-border-focus: #3b82f6;
    --color-success: #10b981;
    --color-success-bg: #064e3b;
    --color-warning: #f59e0b;
    --color-warning-bg: #78350f;
    --color-error: #fca5a5;
    --color-error-bg: #7f1d1d;
    --color-error-text: #fca5a5;
    --color-dv: #a78bfa;
  }
}
```

TypeScript mirrors CSS (same pattern as `typography.ts`):
```typescript
export const color = {
  primary: 'var(--color-primary)',
  primaryHover: 'var(--color-primary-hover)',
  // ... ~24 tokens
} as const;
```

### D2: Color inventory — 73 hex values → ~24 semantic tokens

Audit found 73 unique hex colors across 18 files (not 13 as originally estimated). Group by semantic role, not by hex value. Same hex used for different roles gets different tokens. Different hex values used for the same role converge to one token.

### D3: Dark mode palette — WCAG-verified

Every dark mode color must meet WCAG 2.1 AA contrast ratios:
- Normal text (< 18pt): 4.5:1 against background
- Large text (>= 18pt bold or >= 24pt): 3:1 against background
- UI components and graphical objects: 3:1 against adjacent colors

Avoid pure black (#000000) — use #0f172a (slate-900) to reduce halation. Avoid pure white text — use #e2e8f0 (slate-200). Desaturate bright colors in dark mode to prevent vibrancy bleeding.

### D4: Migration approach — mechanical replacement with verification

1. Define tokens in `global.css` and `colors.ts`
2. Migrate one component at a time (same as typography migration)
3. After each component, run Playwright axe-core scan to verify no contrast regressions
4. Screenshot comparison (visual diff) for light and dark modes

### D5: Recharts and data visualization

Recharts requires explicit color props on chart components (doesn't read CSS variables from DOM). Pass `color.*` constants via props. Chart-specific tokens may be needed (stroke, fill, axis, grid).

### D6: Training materials — format decisions (Devon's lens)

**Coordinator quick-start card (Devon deliverable #1):**
- Format: Single page, front and back, print-ready PDF (designed to be laminated)
- Front: 5-step update flow (log in, find shelter, update occupied, save, confirm)
- Back: "If Something Goes Wrong" (can't log in, not sure if saved, offline)
- Persona test: "Can Reverend Monroe's 67-year-old volunteer coordinator do this with zero training?"
- Co-production: Devon (instructional design) + Simone (voice, layout)

**Freshness badge explanation (Devon deliverable #5, partial):**
- Add to coordinator quick-start card AND as tooltip in DataAge component
- Plain language: "FRESH = updated in last hour. AGING = 1-8 hours. STALE = 8+ hours — call before driving."

**Admin onboarding checklist (Devon deliverable #5):**
- Format: Fillable PDF, one per shelter being onboarded
- Updated to include: 211 import, shelter edit, DV configuration steps (from shelter-edit change)
- Fields: shelter name, coordinator name, date completed for each step

**Error recovery guidance (Devon deliverable #7):**
- Three scenarios in plain language: can't log in (check tenant slug), not sure if saved (look for green check), app says offline (check connection, work is saved locally)
- Incorporated into quick-start card back panel

### D7: HIC/PIT export — rewrite to HUD Inventory.csv schema

**Current state vs HUD spec (FY2024+):**

| Field | Our output | HUD requires | Fix |
|---|---|---|---|
| Column headers | `ProjectID,ProjectName,...` | `InventoryID,ProjectID,CoCCode,HouseholdType,...` | Rewrite header |
| ProjectType | `"ES"` (string) | `0` or `1` (int, ES split in FY2024) | Map to int code |
| HouseholdType | `"Families"` (string) | `3` (int) | Map to int code |
| TargetPopulation | Raw enum `SINGLE_ADULT` | `4` (int, N/A) or `1` (DV) | Map to int code |
| HMISParticipation | `"Yes"` | `1` (HMIS) or `2` (Comparable DB for DV) | DV shelters → 2 |
| CoCCode | Missing | Required | Add from tenant slug |
| InventoryID | Missing | Required | Generate UUID |
| Availability | Missing | Required (`1`=Year-round, `2`=Seasonal) | Add, default 1 |
| ESBedType | Missing | Required for ES (`1`=Facility) | Add |
| Veteran bed columns | Missing | CHVetBedInventory, YouthVetBedInventory, VetBedInventory, etc. | Add (default 0, populate from VETERAN population type) |

**mapHouseholdType() fix:**
```java
// BEFORE (strings, silent default)
case "FAMILY_WITH_CHILDREN" -> "Families";
default -> populationType;

// AFTER (HUD integer codes, fail on unknown)
case "FAMILY_WITH_CHILDREN" -> 3;  // Households with at least one adult and one child
case "SINGLE_ADULT", "WOMEN_ONLY" -> 1;  // Households without children
case "YOUTH_18_24", "YOUTH_UNDER_18" -> 4;  // Households with only children
case "VETERAN" -> 1;  // Households without children (veteran status tracked in bed columns)
case "DV_SURVIVOR" -> 3;  // DV household type varies — use 3 for aggregated row
default -> throw new IllegalArgumentException("Unmapped population type: " + populationType);
```

**PIT count note:** PIT data is submitted via direct entry in HDX 2.0, not CSV upload. Our PIT CSV is a working document for Marcus, not a HUD submission file. The header and format should still be accurate but doesn't need to match HDX field-for-field.

### D8: AvailabilityCategory — seasonal shelter support

Current code hardcodes `"Year-Round"`. Reverend Monroe's faith community shelters are seasonal (White Flag nights only). The shelter entity should have an `availabilityCategory` field (or derive from surge association). For now, default to `1` (Year-round) but make it configurable per shelter — add to shelter constraints or a new field.

## Risks / Trade-offs

- **Dark mode on data-dense pages** (analytics charts, admin tables): Recharts needs prop-based color passing, not CSS variables. May need chart-specific color tokens.
- **Screenshot recapture**: All demo screenshots need recapture for both light and dark modes. Run capture.sh twice with different OS settings.
- **HIC column count increase**: Adding veteran bed breakdown columns (7 new columns) makes the CSV wider. This is required by HUD spec.
- **Training materials versioning**: Devon's principle — materials must be versioned with the software. Quick-start card written for v0.21.0 may need revision if UI changes in v0.22.0.
- **Deferred training items**: DV referral workflow cards require practitioner review (Keisha's network). Outreach worker onboarding requires running app gap analysis. Both deferred to post-pilot.
