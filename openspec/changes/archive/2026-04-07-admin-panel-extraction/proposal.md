## Why

AdminPanel.tsx is 2,136 lines with 14 component functions, shared styles, shared utilities, and 10 TypeScript interfaces — all in one file. Adding the platform-hardening frontend features (revoke/rotate buttons, delivery log panels, pause/resume toggles) would push it past 2,600 lines. The file is 5-10x the recommended React component file size (200-400 lines).

Impact: PR diffs for any tab change show the entire file. Devon (training) can't reference individual tabs by file. Code splitting is impossible — all 14 tabs load in one bundle even though users typically visit one tab per session. The AnalyticsTab was already extracted (lazy-loaded), proving the pattern works.

## What Changes

- **Extract each tab** into its own file under `frontend/src/pages/admin/tabs/`
- **Extract shared components** (StatusBadge, RoleBadge, ErrorBox, NoData, Spinner, ReservationSettings) into `frontend/src/pages/admin/components/`
- **Extract shared types** (ApiKeyRow, SubscriptionRow, User, etc.) into `frontend/src/pages/admin/types.ts`
- **Lazy-load all tabs** via `React.lazy()` + `<Suspense>` in the orchestrator — same pattern as existing AnalyticsTab
- **AdminPanel.tsx** shrinks to ~80-100 lines: tab bar + lazy imports + Suspense boundaries
- **Pure refactor** — zero API changes, zero visual changes. One small behavior improvement: ErrorBoundary per tab prevents a failing tab from crashing the entire admin panel.

## Capabilities

### New Capabilities
- `admin-panel-structure`: File organization, lazy loading, and code splitting for the admin panel

### Modified Capabilities
- (none — pure refactor, no requirement changes)

## Impact

- **Frontend**: 1 monolith file → ~15 focused files in `pages/admin/` directory
- **Bundle size**: Each tab becomes a separate Vite chunk (automatic with dynamic `import()`)
- **Testing**: Existing Playwright tests hit the same URLs and DOM — should pass unchanged. axe-core scans per tab are unaffected.
- **No backend changes**
- **No API changes**
- **No visual changes**
