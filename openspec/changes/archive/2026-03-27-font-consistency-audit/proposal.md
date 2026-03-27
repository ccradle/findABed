## Why

The frontend has no global font stack, no typography tokens, and no CSS infrastructure. All 13 component files set font sizes and weights independently via inline styles with no shared constants. The application renders in browser-default system fonts with no explicit `font-family` declared at any level. This produces visible inconsistencies across views (serif vs sans-serif rendering depending on browser/OS), undermines the WCAG 2.1 AA work we completed, and makes the platform look unpolished for city IT evaluations.

Evaluated through AI personas (defined in PERSONAS.md): Teresa Nguyen (City Official) — first-impression polish for procurement evaluation. Riley Cho (QA) — "If a font changes between views, users perceive something is broken." Darius Webb (Outreach Worker) — inconsistent rendering on mid-range Android outdoors erodes trust.

## What Changes

- Establish a global CSS file with system font stack, line-height, and CSS custom properties for typography tokens
- Create shared TypeScript typography constants backed by CSS custom properties
- Audit and update all 13 component files to use consistent typography tokens
- Audit all text rendering against WCAG 1.4.4 (Resize Text), 1.4.8 (Visual Presentation), and 1.4.12 (Text Spacing)
- Verify no container clips text when user overrides text spacing (WCAG 1.4.12 compliance)
- Add Playwright tests to verify font consistency across key views and catch regressions
- Fix monospace font fallback chain (currently bare `'monospace'` with no fallbacks)

## Capabilities

### New Capabilities
- `typography-system`: Global CSS file with system font stack, CSS custom properties for font sizes/weights/line-heights, shared TypeScript constants, monospace fallback chain
- `typography-playwright-tests`: Playwright tests verifying font-family consistency across all key views, text spacing override tolerance, and no text clipping under WCAG 1.4.12 conditions

### Modified Capabilities
- `wcag-accessibility-compliance`: Verify WCAG 1.4.4, 1.4.8, 1.4.12 compliance with the new typography system — text resizes correctly, line-height meets requirements, no content loss on spacing override

## Impact

- **Frontend**: All 13 component files updated to use shared typography tokens. New `global.css` and `typography.ts` files.
- **Testing**: New Playwright test file for typography consistency and WCAG text spacing verification
- **Build**: Vite already handles CSS imports — no config changes needed
- **Accessibility**: Strengthens existing WCAG 2.1 AA conformance for text presentation criteria
- **No backend changes**
