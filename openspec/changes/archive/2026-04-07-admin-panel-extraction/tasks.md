## 1. Setup

- [x] 1.1 Create branch `refactor/admin-panel-extraction` from main
- [x] 1.2 Create directory structure: `frontend/src/pages/admin/`, `admin/tabs/`, `admin/components/`

## 2. Extract Types and Styles

- [x] 2.1 Create `admin/types.ts` — extract SHARED interfaces only: User, ShelterListItem, ApiKeyRow, ApiKeyCreateResponse, ImportRow, SubscriptionRow, TabKey. Tab-specific types (ObservabilityConfig, TemperatureStatus, OAuth2ProviderRow, HmisInventoryRecord, HmisAuditEntry, HmisVendorStatus, HmisStatus) stay in their respective tab files.
- [x] 2.2 Create `admin/styles.ts` — extract shared style objects: tableStyle, thStyle, tdStyle, inputStyle, primaryBtnStyle, and any other reused style constants
- [x] 2.3 Verify `npm run build` passes after extraction

## 3. Extract Shared Components

- [x] 3.1 Create `admin/components/StatusBadge.tsx` — extract StatusBadge function
- [x] 3.2 Create `admin/components/RoleBadge.tsx` — extract RoleBadge function
- [x] 3.3 Create `admin/components/ErrorBox.tsx` — extract ErrorBox function
- [x] 3.4 Create `admin/components/NoData.tsx` — extract NoData function
- [x] 3.5 Create `admin/components/Spinner.tsx` — extract Spinner function
- [x] 3.6 Create `admin/components/ReservationSettings.tsx` — extract ReservationSettings function
- [x] 3.7 Create `admin/components/index.ts` — barrel export for all shared components
- [x] 3.8 Verify `npm run build` passes after extraction

## 4. Extract Tabs (one at a time, build after each)

- [x] 4.1 Create `admin/tabs/UsersTab.tsx` — extract UsersTab, delete original from AdminPanel.tsx, default export
- [x] 4.2 Verify `npm run build` passes
- [x] 4.3 Create `admin/tabs/SheltersTab.tsx` — extract, delete original, default export
- [x] 4.4 Verify `npm run build` passes
- [x] 4.5 Create `admin/tabs/ApiKeysTab.tsx` — extract, delete original, default export
- [x] 4.6 Verify `npm run build` passes
- [x] 4.C1 **COMMIT CHECKPOINT**: commit types + styles + components + first 3 tabs
- [x] 4.7 Create `admin/tabs/ImportsTab.tsx` — extract, delete original, default export
- [x] 4.8 Verify `npm run build` passes
- [x] 4.9 Create `admin/tabs/SubscriptionsTab.tsx` — extract, delete original, default export
- [x] 4.10 Verify `npm run build` passes
- [x] 4.11 Create `admin/tabs/SurgeTab.tsx` — extract, delete original, default export
- [x] 4.12 Verify `npm run build` passes
- [x] 4.C2 **COMMIT CHECKPOINT**: commit next 3 tabs
- [x] 4.13 Create `admin/tabs/ObservabilityTab.tsx` — extract, delete original, default export
- [x] 4.14 Verify `npm run build` passes
- [x] 4.15 Create `admin/tabs/OAuth2ProvidersTab.tsx` — extract, delete original, default export
- [x] 4.16 Verify `npm run build` passes
- [x] 4.17 Create `admin/tabs/HmisExportTab.tsx` — extract, delete original, default export
- [x] 4.18 Verify `npm run build` passes
- [x] 4.19 Move existing `AnalyticsTab.tsx` from `pages/` to `admin/tabs/AnalyticsTab.tsx` — update lazy import path
- [x] 4.20 Verify `npm run build` passes after AnalyticsTab move
- [x] 4.C3 **COMMIT CHECKPOINT**: commit remaining tabs + AnalyticsTab move
- [x] 4.21 Add code comment in AdminPanel.tsx TABS array: "Future: filter by user role for per-tab permissions (see design D5)"

## 5. Update Orchestrator

- [x] 5.1 Replace inline tab components in AdminPanel.tsx with `React.lazy()` + dynamic `import()` for each tab
- [x] 5.2 Wrap each lazy tab in `<Suspense fallback={<Spinner />}>`
- [x] 5.3 Remove all extracted code from AdminPanel.tsx — should be ~80-100 lines remaining
- [x] 5.4 Update AdminPanel.tsx imports (types from `./types`, components from `./components`)
- [x] 5.5 Verify `npm run build` passes — AdminPanel.tsx should compile clean
- [x] 5.6 Verify Vite output shows separate chunks for each tab (check dist/ after build)

## 6. Update Existing Import Paths

- [x] 6.1 AnalyticsTab moved to admin/tabs/ in task 4.19 — verify lazy import path in orchestrator is correct
- [x] 6.2 Update `App.tsx` (or route config) import path from `./pages/AdminPanel` to `./pages/admin/AdminPanel`
- [x] 6.3 Search for any other files importing from AdminPanel.tsx (`grep -r "AdminPanel" frontend/src/`) — update all paths

## 7. Testing

- [x] 7.1 Run `npm run build` — zero TypeScript errors, zero Vite errors
- [x] 7.2 Start dev stack (`./dev-start.sh --nginx`) and manually verify each admin tab renders
- [x] 7.3 Run full Playwright suite through nginx — all existing admin tests pass
- [x] 7.4 Run axe-core accessibility tests — zero new violations
- [x] 7.5 Verify admin panel loads in dark mode (no broken styles from extraction)
- [x] 7.6 Verify AdminPanel.tsx is under 150 lines (spec requirement) — 128 lines
- [x] 7.7 Verify Vite build output shows separate chunks for lazy-loaded tabs (`ls dist/assets/ | grep -c chunk`) — 10 chunks
- [x] 7.8 Add `<ErrorBoundary>` per tab — verify a failing tab shows error message, not blank panel, and tab bar stays functional. (Note: this is a small behavior improvement bundled with the refactor — existing behavior crashes the whole page on tab error.)

## 8. Documentation & Deploy

- [x] 8.1 Add CHANGELOG entry
- [x] 8.2 Version bump in pom.xml (patch)
- [x] 8.3 Commit, push, create PR, wait for CI green
- [x] 8.4 Merge to main, tag, create release
- [x] 8.5 Deploy to Oracle VM (frontend-only: `npm run build` + docker rebuild frontend + restart)
- [x] 8.6 Run deploy-verify script against live site — verify admin panel loads, all tabs render
- [x] 8.7 Manual spot check: click through each admin tab on findabed.org (incognito)
