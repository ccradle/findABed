## ADDED Requirements

### Requirement: admin-tab-file-isolation
Each admin panel tab SHALL be a separate file in `frontend/src/pages/admin/tabs/` with a `default export` function component.

#### Scenario: Each tab is its own file
- **WHEN** the admin panel source code is inspected
- **THEN** each tab component SHALL exist in its own file under `pages/admin/tabs/`
- **AND** no tab component SHALL be defined inside `AdminPanel.tsx`

#### Scenario: AdminPanel.tsx is the orchestrator only
- **WHEN** `AdminPanel.tsx` is inspected
- **THEN** it SHALL contain only the tab bar, lazy imports, Suspense boundaries, and ReservationSettings
- **AND** it SHALL be under 150 lines

### Requirement: admin-tab-lazy-loading
Each admin tab SHALL be lazy-loaded via `React.lazy()` + `<Suspense>` to enable code splitting.

#### Scenario: Tab loads on demand
- **WHEN** a user navigates to the admin panel
- **THEN** only the active tab's code SHALL be loaded initially
- **AND** switching tabs SHALL trigger a dynamic import for the new tab

#### Scenario: Loading state shown during tab load
- **WHEN** a user switches to a tab that hasn't been loaded yet
- **THEN** a loading spinner SHALL appear until the tab component loads

#### Scenario: Tab error does not crash the entire admin panel
- **WHEN** a tab component fails to load or throws during render
- **THEN** the tab bar SHALL remain functional
- **AND** an error message SHALL appear in the tab panel area only

### Requirement: admin-shared-components
Shared UI components (StatusBadge, RoleBadge, ErrorBox, NoData, Spinner) SHALL be extracted to `frontend/src/pages/admin/components/`.

#### Scenario: Shared components importable from components directory
- **WHEN** a tab needs StatusBadge or ErrorBox
- **THEN** it SHALL import from `../admin/components/` (not inline it)

### Requirement: admin-shared-types
Shared TypeScript interfaces (ApiKeyRow, SubscriptionRow, User, ShelterListItem, etc.) SHALL be extracted to `frontend/src/pages/admin/types.ts`.

#### Scenario: Types importable from types file
- **WHEN** a tab needs a shared interface
- **THEN** it SHALL import from `../admin/types` (not redeclare it)

### Requirement: no-visual-regression
The extraction SHALL produce zero visual changes to the admin panel.

#### Scenario: All existing Playwright tests pass
- **WHEN** the full Playwright suite runs after extraction
- **THEN** all admin panel tests SHALL pass without modification

#### Scenario: axe-core accessibility scan unchanged
- **WHEN** axe-core scans the admin panel after extraction
- **THEN** zero new violations SHALL be reported

#### Scenario: Frontend builds clean
- **WHEN** `npm run build` is executed after extraction
- **THEN** TypeScript compilation SHALL succeed with zero errors
- **AND** Vite build SHALL produce separate chunks for each lazy-loaded tab
