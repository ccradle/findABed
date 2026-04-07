## Context

AdminPanel.tsx: 2,136 lines, 14 function components, 10 interfaces, shared styles, shared utilities. AnalyticsTab was already extracted with `React.lazy` + `Suspense` (proves the pattern works). The file was manageable at 5-6 tabs but grew organically with each feature (OAuth2, HMIS Export, Observability).

## Goals / Non-Goals

**Goals:**
- Split AdminPanel.tsx into ~15 focused files
- Enable Vite code splitting (each tab is a separate chunk)
- Make the codebase approachable for new contributors and documentation
- Prepare for platform-hardening frontend features (revoke/rotate, delivery log)

**Non-Goals:**
- No visual changes to the admin panel
- No new features (revoke, rotate, pause — those come in platform-hardening after this ships)
- No component library migration (stays with inline styles)
- No routing changes (tabs remain in-page, not URL-routed)

## Decisions

### D1: Directory structure

```
frontend/src/pages/admin/
  AdminPanel.tsx           # Orchestrator: tab bar, lazy imports, Suspense
  types.ts                 # Shared interfaces (ApiKeyRow, SubscriptionRow, User, etc.)
  styles.ts                # Shared style objects (tableStyle, thStyle, tdStyle, inputStyle, primaryBtnStyle)
  components/
    StatusBadge.tsx
    RoleBadge.tsx
    ErrorBox.tsx
    NoData.tsx
    Spinner.tsx
    ReservationSettings.tsx
  tabs/
    UsersTab.tsx
    SheltersTab.tsx
    ApiKeysTab.tsx
    ImportsTab.tsx
    SubscriptionsTab.tsx
    SurgeTab.tsx
    ObservabilityTab.tsx
    OAuth2ProvidersTab.tsx
    HmisExportTab.tsx
```

### D2: Lazy loading pattern

Same as existing AnalyticsTab:
```tsx
const UsersTab = lazy(() => import('./tabs/UsersTab'));

{activeTab === 'users' && (
  <Suspense fallback={<Spinner />}>
    <UsersTab />
  </Suspense>
)}
```

Each tab is a `default export`. Vite automatically creates separate chunks for dynamic `import()`.

### D3: Shared imports

Each tab imports what it needs:
- `import { api } from '../../services/api'` — API client
- `import { color } from '../../theme/colors'` — design tokens
- `import { text, weight, font } from '../../theme/typography'` — typography
- `import { FormattedMessage, useIntl } from 'react-intl'` — i18n
- `import { StatusBadge, ErrorBox, Spinner, NoData } from '../admin/components'` — shared components
- `import { tableStyle, thStyle, tdStyle, inputStyle, primaryBtnStyle } from '../admin/styles'` — shared styles
- `import type { ApiKeyRow, SubscriptionRow } from '../admin/types'` — shared types

### D4: Extraction order

Extract in dependency order:
1. Types (no dependencies)
2. Styles (no dependencies)
3. Shared components (depend on types + styles)
4. Each tab (depends on shared components + types + styles)
5. Orchestrator (depends on tab imports)

This order ensures each file compiles before the next is extracted.

## Risks / Trade-offs

- **Import path changes**: Each tab now imports from `../../services/api` instead of same-directory. Search-and-replace.
- **Existing Playwright tests**: Should pass unchanged — they test URLs and DOM, not file structure. Run full suite after extraction.
- **Separate Spring context for AnalyticsTab**: The existing `<Suspense>` around AnalyticsTab uses a different lazy pattern — verify it still works after the refactor.
