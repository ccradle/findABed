## 1. Setup

- [ ] 1.1 Create branch `refactor/admin-panel-extraction` from main
- [ ] 1.2 Create directory structure: `frontend/src/pages/admin/`, `admin/tabs/`, `admin/components/`

## 2. Extract Types and Styles

- [ ] 2.1 Create `admin/types.ts` — extract SHARED interfaces only: User, ShelterListItem, ApiKeyRow, ApiKeyCreateResponse, ImportRow, SubscriptionRow, TabKey. Tab-specific types (ObservabilityConfig, TemperatureStatus, OAuth2ProviderRow, HmisInventoryRecord, HmisAuditEntry, HmisVendorStatus, HmisStatus) stay in their respective tab files.
- [ ] 2.2 Create `admin/styles.ts` — extract shared style objects: tableStyle, thStyle, tdStyle, inputStyle, primaryBtnStyle, and any other reused style constants
- [ ] 2.3 Verify `npm run build` passes after extraction

## 3. Extract Shared Components

- [ ] 3.1 Create `admin/components/StatusBadge.tsx` — extract StatusBadge function
- [ ] 3.2 Create `admin/components/RoleBadge.tsx` — extract RoleBadge function
- [ ] 3.3 Create `admin/components/ErrorBox.tsx` — extract ErrorBox function
- [ ] 3.4 Create `admin/components/NoData.tsx` — extract NoData function
- [ ] 3.5 Create `admin/components/Spinner.tsx` — extract Spinner function
- [ ] 3.6 Create `admin/components/ReservationSettings.tsx` — extract ReservationSettings function
- [ ] 3.7 Create `admin/components/index.ts` — barrel export for all shared components
- [ ] 3.8 Verify `npm run build` passes after extraction

## 4. Extract Tabs (one at a time, build after each)

- [ ] 4.1 Create `admin/tabs/UsersTab.tsx` — extract UsersTab, default export. Update imports.
- [ ] 4.2 Verify `npm run build` passes
- [ ] 4.3 Create `admin/tabs/SheltersTab.tsx` — extract SheltersTab, default export
- [ ] 4.4 Verify `npm run build` passes
- [ ] 4.5 Create `admin/tabs/ApiKeysTab.tsx` — extract ApiKeysTab, default export
- [ ] 4.6 Verify `npm run build` passes
- [ ] 4.7 Create `admin/tabs/ImportsTab.tsx` — extract ImportsTab, default export
- [ ] 4.8 Verify `npm run build` passes
- [ ] 4.9 Create `admin/tabs/SubscriptionsTab.tsx` — extract SubscriptionsTab, default export
- [ ] 4.10 Verify `npm run build` passes
- [ ] 4.11 Create `admin/tabs/SurgeTab.tsx` — extract SurgeTab, default export
- [ ] 4.12 Verify `npm run build` passes
- [ ] 4.13 Create `admin/tabs/ObservabilityTab.tsx` — extract ObservabilityTab, default export
- [ ] 4.14 Verify `npm run build` passes
- [ ] 4.15 Create `admin/tabs/OAuth2ProvidersTab.tsx` — extract OAuth2ProvidersTab, default export
- [ ] 4.16 Verify `npm run build` passes
- [ ] 4.17 Create `admin/tabs/HmisExportTab.tsx` — extract HmisExportTab, default export
- [ ] 4.18 Verify `npm run build` passes
- [ ] 4.19 Move existing `AnalyticsTab.tsx` from `pages/` to `admin/tabs/AnalyticsTab.tsx` — update lazy import path in orchestrator
- [ ] 4.20 Verify `npm run build` passes after AnalyticsTab move
- [ ] 4.21 Add code comment in AdminPanel.tsx TABS array: "Future: filter by user role for per-tab permissions (see design D5)"

## 5. Update Orchestrator

- [ ] 5.1 Replace inline tab components in AdminPanel.tsx with `React.lazy()` + dynamic `import()` for each tab
- [ ] 5.2 Wrap each lazy tab in `<Suspense fallback={<Spinner />}>`
- [ ] 5.3 Remove all extracted code from AdminPanel.tsx — should be ~80-100 lines remaining
- [ ] 5.4 Update AdminPanel.tsx imports (types from `./types`, components from `./components`)
- [ ] 5.5 Verify `npm run build` passes — AdminPanel.tsx should compile clean
- [ ] 5.6 Verify Vite output shows separate chunks for each tab (check dist/ after build)

## 6. Update Existing Import Paths

- [ ] 6.1 AnalyticsTab moved to admin/tabs/ in task 4.19 — verify lazy import path in orchestrator is correct
- [ ] 6.2 Update `App.tsx` (or route config) import path from `./pages/AdminPanel` to `./pages/admin/AdminPanel`
- [ ] 6.3 Search for any other files importing from AdminPanel.tsx (`grep -r "AdminPanel" frontend/src/`) — update all paths

## 7. Testing

- [ ] 7.1 Run `npm run build` — zero TypeScript errors, zero Vite errors
- [ ] 7.2 Start dev stack (`./dev-start.sh --nginx`) and manually verify each admin tab renders
- [ ] 7.3 Run full Playwright suite through nginx — all existing admin tests pass
- [ ] 7.4 Run axe-core accessibility tests — zero new violations
- [ ] 7.5 Verify admin panel loads in dark mode (no broken styles from extraction)
- [ ] 7.6 Verify AdminPanel.tsx is under 150 lines (spec requirement)
- [ ] 7.7 Verify Vite build output shows separate chunks for lazy-loaded tabs (`ls dist/assets/ | grep -c chunk`)
- [ ] 7.8 Add `<ErrorBoundary>` per tab — verify a failing tab shows error message, not blank panel, and tab bar stays functional. (Note: this is a small behavior improvement bundled with the refactor — existing behavior crashes the whole page on tab error.)

## 8. Documentation & Deploy

- [ ] 8.1 Add CHANGELOG entry
- [ ] 8.2 Version bump in pom.xml (patch)
- [ ] 8.3 Commit, push, create PR, wait for CI green
- [ ] 8.4 Merge to main, tag, create release
- [ ] 8.5 Deploy to Oracle VM (frontend-only: `npm run build` + docker rebuild frontend + restart)
- [ ] 8.6 Run deploy-verify script against live site — verify admin panel loads, all tabs render
- [ ] 8.7 Manual spot check: click through each admin tab on findabed.org (incognito)
