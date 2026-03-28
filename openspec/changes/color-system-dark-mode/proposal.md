## Why

The frontend uses 20+ hardcoded hex colors across all component files with no shared color tokens. The GitHub Pages site supports dark mode via `prefers-color-scheme`, but the React app does not — creating a brand disconnect when Darius (AI persona, Outreach Worker, PERSONAS.md) moves from the Pages site to the app at midnight on his Android phone (which auto-switches to dark at sunset). The typography migration established the pattern: CSS custom properties as design tokens, shared TypeScript constants. The same pattern should apply to colors, enabling dark mode and brand consistency in one change.

## What Changes

- Define canonical brand color palette as CSS custom properties in `global.css`
- Add dark mode color set via `@media (prefers-color-scheme: dark)` — system-only, no manual toggle (follows OS setting automatically; toggle can be added later if users request it)
- Create shared TypeScript color constants (like `typography.ts`)
- Migrate all 13 component files from hardcoded hex values to color tokens
- Verify WCAG contrast ratios in both light and dark modes
- Add Playwright tests for dark mode rendering and contrast

## Capabilities

### New Capabilities
- `color-system`: CSS custom properties for all colors with light/dark mode sets, shared TypeScript constants
- `dark-mode`: System-only `prefers-color-scheme` support across all views — no manual toggle, follows OS setting

### Modified Capabilities
- `wcag-accessibility-compliance`: Contrast verification in both light and dark modes (4.5:1 minimum for normal text in both)

## Impact

- **Frontend**: `global.css` extended with color tokens, new `colors.ts` constants file, all 13 component files migrated
- **Testing**: Playwright dark mode tests (emulate prefers-color-scheme: dark), contrast verification
- **No backend changes**
- **Scope similar to typography migration** — mechanical replacement + infrastructure
- **Future-proof**: Adding a manual toggle later requires only a UI component + class swap, not a refactor
