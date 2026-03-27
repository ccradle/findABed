## typography-system

Global typography infrastructure: CSS custom properties, system font stack, shared TypeScript constants.

### Requirements

- REQ-TYP-1: A global CSS file (`src/global.css`) MUST define CSS custom properties for font families, sizes, weights, and line heights
- REQ-TYP-2: The system font stack MUST lead with `system-ui` followed by platform-specific fallbacks (`'Segoe UI', Roboto, Helvetica, Arial, sans-serif`)
- REQ-TYP-3: Emoji font families MUST be included in the font stack (`'Apple Color Emoji', 'Segoe UI Emoji'`)
- REQ-TYP-4: A monospace font stack MUST be defined with proper fallbacks (`ui-monospace, 'Cascadia Code', 'Source Code Pro', Menlo, Consolas, 'Courier New', monospace`)
- REQ-TYP-5: `font-family` MUST be set on `*, *::before, *::after` to ensure form elements (`input`, `button`, `select`, `textarea`) inherit correctly
- REQ-TYP-6: Base `line-height` MUST be set to at least 1.5 (WCAG 1.4.12 threshold)
- REQ-TYP-7: `global.css` MUST be imported in `main.tsx`
- REQ-TYP-8: A shared TypeScript constants file (`src/theme/typography.ts`) MUST export typography tokens referencing the CSS custom properties
- REQ-TYP-9: All 13 component files MUST be migrated to use typography tokens instead of hardcoded values
- REQ-TYP-10: All `fontFamily: 'monospace'` declarations MUST be replaced with the monospace CSS custom property

### Scenarios

```gherkin
Scenario: Global font stack applies to all elements
  Given the application loads in any browser
  When any page renders
  Then the computed font-family of body text starts with "system-ui" or the platform system font
  And no element renders with a serif font-family

Scenario: Form elements inherit font-family
  Given a page contains input, select, and button elements
  When the page renders
  Then these elements have the same font-family as body text
  And they do not fall back to browser default form fonts

Scenario: Monospace renders with fallback chain
  Given the Admin panel displays an API key
  When the key is rendered
  Then the computed font-family includes a monospace font from the defined fallback chain
  And it is not bare browser-default monospace

Scenario: Typography tokens are the single source of truth
  Given a developer searches for hardcoded fontSize values
  When they search for fontSize: followed by a number in component files
  Then no component file contains hardcoded font-size pixel values outside of typography.ts
```
