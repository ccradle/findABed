## Overview

Establish a typography system for the FABT frontend: global CSS with system font stack, CSS custom properties as design tokens, shared TypeScript constants, and Playwright regression tests. The goal is best-practice typography infrastructure that futureproofs for team scaling, theme support, and city IT evaluation.

## Design Decisions

### Global CSS File (`src/global.css`)

Create a proper CSS file imported in `main.tsx`. This is the best-practice foundation for a design system — not an index.html `<style>` tag (fragile) or CSS-in-JS (unnecessary dependency).

Contents:
- System font stack on `html` element
- CSS custom properties for all typography tokens
- Base `line-height: 1.5` (WCAG 1.4.12 threshold)
- Universal `font-family` on `*, *::before, *::after` — ensures `input`, `button`, `select`, `textarea` inherit correctly (these elements don't inherit `font-family` from `body` by default)
- Monospace custom property with proper fallback chain

```css
:root {
  /* Font families */
  --font-sans: system-ui, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji';
  --font-mono: ui-monospace, 'Cascadia Code', 'Source Code Pro', Menlo, Consolas, 'Courier New', monospace;

  /* Font sizes */
  --text-xs: 12px;
  --text-sm: 13px;
  --text-base: 14px;
  --text-md: 16px;
  --text-lg: 18px;
  --text-xl: 20px;
  --text-2xl: 24px;
  --text-3xl: 28px;

  /* Font weights */
  --font-normal: 400;
  --font-medium: 500;
  --font-semibold: 600;
  --font-bold: 700;
  --font-extrabold: 800;

  /* Line heights */
  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;
}

*, *::before, *::after {
  font-family: var(--font-sans);
}

html {
  font-size: var(--text-base);
  line-height: var(--leading-normal);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

### TypeScript Constants (`src/theme/typography.ts`)

Shared constants that reference the CSS custom properties. Components import these instead of hardcoding values. This provides type safety and a single source of truth while keeping the CSS custom properties as the canonical token definitions.

```typescript
export const typography = {
  fontFamily: {
    sans: "var(--font-sans)",
    mono: "var(--font-mono)",
  },
  fontSize: {
    xs: 'var(--text-xs)',
    sm: 'var(--text-sm)',
    base: 'var(--text-base)',
    md: 'var(--text-md)',
    lg: 'var(--text-lg)',
    xl: 'var(--text-xl)',
    '2xl': 'var(--text-2xl)',
    '3xl': 'var(--text-3xl)',
  },
  // ... weights, line-heights
} as const;
```

### Component Migration Strategy

Migrate all 13 component files to use tokens:
- Replace hardcoded `fontSize: 14` with `fontSize: 'var(--text-base)'`
- Replace `fontFamily: 'monospace'` with `fontFamily: 'var(--font-mono)'`
- Add `lineHeight: 'var(--leading-normal)'` where missing
- Keep numeric values for `fontWeight` (already consistent, just reference constants for clarity)

Priority: start with the views users see most (OutreachSearch, CoordinatorDashboard, LoginPage), then admin views.

Note: React 19 supports CSS `var()` in inline styles — `fontSize: 'var(--text-base)'` is passed through to the DOM correctly (verified via React GitHub issue #6411, resolved since 2017).

### WCAG Text Spacing Audit

WCAG 1.4.12 requires that no content is lost when users override:
- Line height to 1.5× font size
- Letter spacing to 0.12× font size
- Word spacing to 0.16× font size
- Paragraph spacing to 2× font size

Audit all containers for:
- Fixed `height`/`max-height` on text containers (risk: text overflow)
- `overflow: hidden` on text blocks (risk: text clipping)
- `-webkit-line-clamp` (risk: content loss)
- Fixed pixel `lineHeight` values (should be unitless ratios)

### Playwright Tests

New test file `typography.spec.ts`:
1. **Font consistency**: verify `computed font-family` is the same system font on key pages (login, search, dashboard, admin)
2. **Text spacing override**: inject CSS that increases line-height/letter-spacing to WCAG 1.4.12 thresholds, verify no text overflow or clipping
3. **No serif fonts**: assert no element renders with a serif `font-family` computed style

## File Changes

| File | Change |
|------|--------|
| New: `src/global.css` | System font stack, CSS custom properties, base typography |
| New: `src/theme/typography.ts` | Shared TypeScript constants referencing CSS properties |
| `src/main.tsx` | `import './global.css'` |
| `src/pages/OutreachSearch.tsx` | Migrate to typography tokens |
| `src/pages/CoordinatorDashboard.tsx` | Migrate to typography tokens |
| `src/pages/AdminPanel.tsx` | Migrate to typography tokens, fix monospace fallback |
| `src/pages/LoginPage.tsx` | Migrate to typography tokens |
| `src/pages/AnalyticsTab.tsx` | Migrate to typography tokens |
| `src/pages/ShelterForm.tsx` | Migrate to typography tokens |
| `src/pages/HsdsImportPage.tsx` | Migrate to typography tokens |
| `src/pages/TwoOneOneImportPage.tsx` | Migrate to typography tokens |
| `src/components/Layout.tsx` | Migrate to typography tokens |
| `src/components/DataAge.tsx` | Migrate to typography tokens |
| `src/components/OfflineBanner.tsx` | Migrate to typography tokens |
| `src/components/SessionTimeoutWarning.tsx` | Migrate to typography tokens |
| `src/components/LocaleSelector.tsx` | Migrate to typography tokens |
| New: `e2e/playwright/tests/typography.spec.ts` | Font consistency + WCAG text spacing tests |
