## Why

Coordinators are assigned to shelters via the `coordinator_assignment` table, but there is no admin UI to manage these assignments. Currently assignments can only be made via seed SQL or direct API calls. This blocks pilot onboarding — when Marcus Okafor adds a new shelter, he cannot assign coordinators without developer assistance. It also breaks the notification flow: `GET /api/v1/dv-referrals/pending/count` returns 0 for coordinators not assigned to any shelters, and the referral banner never appears.

Clarity Human Services (the dominant HMIS platform) handles staff-to-program assignment from the program side, with a read-only view from the user side. We follow the same pattern.

## What Changes

- **Shelter edit: "Assigned Coordinators" section** — searchable combobox + removable chips, added to `ShelterForm.tsx` after the capacities section. Primary editing surface for coordinator-shelter assignments.
- **User edit: "Assigned Shelters" read-only view** — chip list in `UserEditDrawer.tsx` showing which shelters the coordinator is assigned to, with links to shelter edit. No inline editing (avoids dual edit surfaces).
- **User-side API** — `GET /api/v1/users/{id}/shelters` returning assigned shelter names/IDs. The write API already exists shelter-side (`POST/DELETE /api/v1/shelters/{id}/coordinators`).

## Capabilities

### New Capabilities
- `shelter-coordinator-assignment-ui`: Combobox + chips widget on shelter edit page for assigning/removing coordinators. Search by name, WCAG-compliant (W3C APG combobox pattern), dark mode via color tokens.
- `user-shelter-readonly-view`: Read-only chip list on user edit drawer showing assigned shelters.

### Modified Capabilities
- `notification-rest-api`: No spec change, but the coordinator pending count endpoint now becomes useful once assignments are manageable via UI.

## Bundled Fix: DV Referral Token Expiry (Critical)

Discovered during pre-implementation investigation: DV referral tokens are never expired by the `@Scheduled` job. Root cause: `@Transactional` on `expireTokens()` eagerly acquires a JDBC connection before `TenantContext.runWithContext()` sets dvAccess=true. The RLS-aware DataSource reads dvAccess=false, making DV shelters (and their referral tokens) invisible. Same bug exists in `purgeTerminalTokens()`.

Reproduced on live demo site (3 stuck PENDING tokens, oldest 7 days) and locally via integration test. Fix: remove `@Transactional` (single-statement SQL is already atomic), add fail-fast assertion, add diagnostic logging. Proven by new `DvReferralExpiryRlsTest`.

## Impact

- **Frontend**: New combobox+chips component in `ShelterForm.tsx`, read-only chips in `UserEditDrawer.tsx`. No new dependencies (built with existing design tokens, inline styles).
- **Backend**: One new endpoint: `GET /api/v1/users/{id}/shelters`. Write endpoints already exist. Fix: `@Transactional` removed from `expireTokens()` and `purgeTerminalTokens()`, fail-fast assertions and diagnostic logging added.
- **Database**: No schema changes — `coordinator_assignment` table already exists. Manual cleanup of 3 stuck PENDING referral tokens on demo site.
- **Security**: Assignment changes restricted to COC_ADMIN and PLATFORM_ADMIN roles. DV referral expiry fix restores defense-in-depth for referral lifecycle.
