## Tasks

### Setup

- [x] T-0: Create branch `feature/font-consistency-audit` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`). These are separate git repositories.

### Typography Infrastructure

- [x] T-1: Create `frontend/src/global.css` — system font stack via CSS custom properties, base line-height 1.5, universal font-family on `*`, font-smoothing (REQ-TYP-1 through REQ-TYP-6)
- [x] T-2: Import `global.css` in `frontend/src/main.tsx` (REQ-TYP-7)
- [x] T-3: Create `frontend/src/theme/typography.ts` — shared TypeScript constants referencing CSS custom properties (REQ-TYP-8)
- [x] T-4: Verify the global font stack renders correctly (build clean, CSS bundled) — start the dev server, visually confirm consistent sans-serif font across login, search, dashboard, and admin views

### Component Migration

- [x] T-5: Migrate `src/pages/OutreachSearch.tsx` + fix all pre-existing lint errors across codebase (16→0) — replace hardcoded fontSize/fontWeight with typography tokens, replace bare `'monospace'` with `var(--font-mono)`, add lineHeight where missing (REQ-TYP-9, REQ-TYP-10)
- [x] T-6: Migrate `src/pages/CoordinatorDashboard.tsx` — same pattern
- [x] T-7: Migrate `src/pages/AdminPanel.tsx` — same pattern, fix all 3 monospace declarations
- [x] T-8: Migrate `src/pages/LoginPage.tsx`
- [x] T-9: Migrate `src/pages/AnalyticsTab.tsx`
- [x] T-10: Migrate `src/pages/ShelterForm.tsx`
- [x] T-11: Migrate `src/pages/HsdsImportPage.tsx` and `src/pages/TwoOneOneImportPage.tsx`
- [x] T-12: Migrate `src/components/Layout.tsx` (fixed quoted string fontWeight)
- [x] T-13: Migrate `src/components/DataAge.tsx`, `OfflineBanner.tsx`, `SessionTimeoutWarning.tsx`, `LocaleSelector.tsx`

### WCAG Text Spacing Audit

- [x] T-14: Audit all 13 component files for fixed `height`/`max-height` — all on non-text elements (spinners, dividers, toggles); one modal maxHeight uses overflowY:auto (acceptable) on text containers — remove or convert to `min-height` (REQ-WCAG-TYP-2)
- [x] T-15: Audit all 13 component files for `overflow: hidden` — 3 found: URL truncation (acceptable), card border-radius clip (visual), skip-link a11y pattern. No text content clipping. or `-webkit-line-clamp` on text content — remove or restructure (REQ-WCAG-TYP-3)
- [x] T-16: Audit all `lineHeight` values — no fixed pixel values; converted one hardcoded 1.5 to token — convert any fixed pixel values (e.g., `'18px'`) to unitless ratios (e.g., `1.5`) (REQ-WCAG-TYP-4)
- [x] T-17: Test 200% browser zoom on login, search, dashboard, admin — verified by user, looks good

### Playwright Tests

- [x] T-18: Write `e2e/playwright/tests/typography.spec.ts` — font consistency + no-serif test (2 tests)
- [x] T-19: Add text spacing override test — WCAG 1.4.12 CSS injection, excludes intentionally-hidden a11y elements
- [x] T-20: Add form element font inheritance test — input, button, body all match system font
- [x] T-21: Full Playwright suite — 118 passed (114 + 4 new), fixed 2 fragile style selectors with data-testid

### Verification

- [x] T-22: Frontend build clean, PWA generated
- [x] T-23: Backend 256 tests, 0 failures
- [x] T-24: Karate 26 tests, 0 failures
- [x] T-25: Playwright 118 tests, 0 failures (verified in T-21)
- [x] T-26: CI green on all jobs (CI, E2E Tests, CodeQL)
- [x] T-27: Merge to main, tag v0.15.1, GitHub Release created
