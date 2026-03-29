## Tasks

### Setup

- [ ] T-0: Create branch `feature/color-system-dark-mode` in code repo (`finding-a-bed-tonight`)

### Color Token Infrastructure

- [ ] T-1: Audit all 13+ component files — extract every hardcoded hex color, map to semantic role (brand, surface, text, border, status, badge)
- [ ] T-2: Define light mode color tokens in `global.css` as `:root` CSS custom properties
- [ ] T-3: Define dark mode overrides in `@media (prefers-color-scheme: dark)` block
- [ ] T-4: Create `frontend/src/theme/colors.ts` — TypeScript constants mirroring CSS properties (same pattern as `typography.ts`)
- [ ] T-5: Verify WCAG 4.5:1 contrast ratios for all token pairs in both light and dark modes (use contrast checker tool, document results)

### Component Migration (Light + Dark)

- [ ] T-6: Migrate `Layout.tsx` — header bg, text, border, nav colors
- [ ] T-7: Migrate `LoginPage.tsx` — form bg, input borders, button colors
- [ ] T-8: Migrate `OutreachSearch.tsx` — card bg, badge colors, filter styles, hold button
- [ ] T-9: Migrate `CoordinatorDashboard.tsx` — shelter cards, availability forms, stepper colors
- [ ] T-10: Migrate `AdminPanel.tsx` — tab styles, table colors, form elements, all sub-tabs
- [ ] T-11: Migrate `ShelterForm.tsx` — form bg, input borders, submit button
- [ ] T-12: Migrate `NotificationBell.tsx` — dropdown bg, badge colors, item hover
- [ ] T-13: Migrate `ConnectionStatusBanner.tsx` — amber/green banner colors (already using tokens for some)
- [ ] T-14: Migrate `LocaleSelector.tsx`, `OfflineBanner.tsx`, `SessionTimeoutWarning.tsx`, `ChangePasswordModal.tsx`
- [ ] T-15: Migrate `DataAge.tsx` — freshness badge colors (Fresh/Aging/Stale)
- [ ] T-16: Migrate `AnalyticsTab.tsx` — Recharts colors (pass color tokens via props)
- [ ] T-17: Verify no raw hex values remain in any component file (grep check)

### Testing

- [ ] T-18: Playwright: emulate `prefers-color-scheme: dark`, verify app renders with dark colors
- [ ] T-19: Playwright: accessibility scan in dark mode (axe-core) — zero contrast violations
- [ ] T-20: Playwright: accessibility scan in light mode — verify no regressions from migration
- [ ] T-21: Playwright: screenshot capture in dark mode for visual comparison
- [ ] T-22: Playwright: verify no hardcoded hex colors in rendered DOM (automated grep of computed styles)

### Docs-as-Code

- [ ] T-23: Document color token naming convention in `colors.ts` header comment (for v0.19.0 developers)
- [ ] T-24: Verify ArchUnit not affected (frontend-only change)

### Screenshots & Documentation

- [ ] T-25: Capture dark mode screenshots: login, search, coordinator, admin (supplementary to light mode)
- [ ] T-26: Update FOR-DEVELOPERS.md — color system section, dark mode support, project status
- [ ] T-27: Update CONTRIBUTING.md or colors.ts — "Use `color.*` tokens for all new components, never hardcoded hex"

### Verification

- [ ] T-28: Run full Playwright test suite — all green in both light and dark modes
- [ ] T-29: ESLint + TypeScript clean
- [ ] T-30: CI green on all jobs
- [ ] T-31: Merge to main, tag
