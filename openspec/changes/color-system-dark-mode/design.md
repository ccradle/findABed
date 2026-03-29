## Context

The frontend uses 20+ hardcoded hex colors across 13 component files. The typography migration (v0.16.0) established the pattern: CSS custom properties as design tokens with shared TypeScript constants. Colors should follow the same pattern. The GitHub Pages demo site supports `prefers-color-scheme: dark` but the React app does not — a brand disconnect when Darius moves from the demo site to the app at midnight on his Android phone.

The v0.19.0 changes (admin-user-management, shelter-edit, password-recovery-2fa, platform-hardening) will add new frontend components. Without a color system, those components will use more hardcoded hex values, increasing migration debt.

## Goals / Non-Goals

**Goals:**
- Define canonical brand palette as CSS custom properties in `global.css`
- Add dark mode via `@media (prefers-color-scheme: dark)` — system-only, follows OS setting
- Create shared TypeScript color constants (`colors.ts`) mirroring CSS properties
- Migrate all existing component files from hardcoded hex to color tokens
- Verify WCAG 4.5:1 contrast ratios in both light and dark modes
- Establish the pattern so v0.19.0 components use tokens from the start

**Non-Goals:**
- Manual dark/light toggle (future — system-only for now)
- Theme customization per tenant
- Color animation transitions between modes
- Gradient or brand illustration system

## Decisions

### D1: CSS custom properties with `:root` and `@media (prefers-color-scheme: dark)`

```css
:root {
  --color-primary: #1a56db;
  --color-primary-hover: #1e40af;
  --color-bg: #ffffff;
  --color-bg-secondary: #f3f4f6;
  --color-text: #111827;
  --color-text-secondary: #6b7280;
  --color-border: #e5e7eb;
  --color-success: #047857;
  --color-warning: #d97706;
  --color-error: #ef4444;
  --color-badge-red: #ef4444;
  /* ... */
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-primary: #3b82f6;
    --color-bg: #0f172a;
    --color-bg-secondary: #1e293b;
    --color-text: #e2e8f0;
    --color-text-secondary: #94a3b8;
    --color-border: #334155;
    /* ... */
  }
}
```

Same pattern as `typography.ts` — CSS owns the values, TypeScript provides type-safe references:
```typescript
export const color = {
  primary: 'var(--color-primary)',
  bg: 'var(--color-bg)',
  text: 'var(--color-text)',
  // ...
};
```

### D2: Color inventory — extract from existing components

Audit all 13+ component files to build the canonical palette. Group by semantic role:
- **Brand**: primary, primary-hover, header-bg, header-text
- **Surface**: bg, bg-secondary, bg-active, bg-highlight
- **Text**: text-primary, text-secondary, text-muted, text-inverse
- **Border**: border, border-light, border-focus
- **Status**: success, warning, error, info
- **Badge**: badge-red, badge-green, badge-amber

Each hardcoded hex maps to exactly one semantic token. No 1:1 hex-to-variable replacement — group by intent.

### D3: Dark mode palette — WCAG-verified

Every dark mode color must meet WCAG 2.1 AA contrast ratios:
- Normal text (< 18pt): 4.5:1 against background
- Large text (>= 18pt bold or >= 24pt): 3:1 against background
- UI components and graphical objects: 3:1 against adjacent colors

Dark mode follows the Tailwind dark palette convention (slate-900 bg, slate-100 text) which is proven accessible and consistent with the GitHub Pages demo site.

### D4: Migration approach — mechanical replacement with verification

1. Define tokens in `global.css` and `colors.ts`
2. Migrate one component at a time (same as typography migration)
3. After each component, run Playwright accessibility scan to verify no contrast regressions
4. Screenshot comparison (visual diff) for light and dark modes

### D5: Interaction with v0.19.0 changes

New components from v0.19.0 changes (UserEditDrawer, DV confirmation dialog, TOTP enrollment, delivery log panel) should use `color.*` tokens from the start, not hardcoded hex. Document this in the CONTRIBUTING guide or a brief note in `colors.ts`.

## Risks / Trade-offs

- **Dark mode on data-dense pages** (analytics charts, admin tables): Recharts and table styling need dark-mode-aware CSS. Recharts supports custom colors via props — pass `color.*` tokens.
- **Third-party component styling**: ChangePasswordModal, OAuth provider list — any inline styles from libraries may not respect CSS custom properties. Verify during migration.
- **Screenshot recapture**: All demo screenshots will need recapture for both light and dark modes (or just light, with dark mode screenshots as supplementary).
