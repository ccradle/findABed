# Issue Reporting

## Purpose

Provides authenticated users and landing-page visitors with discoverable, privacy-respecting paths to report problems, request features, and ask questions — routed to the GitHub issue / discussions surface with strict pre-fill discipline so no PII ever reaches a world-readable issue body.

## Requirements

### Requirement: in-app-report-problem-link
The authenticated application SHALL display a "Report a Problem" link in the page footer on every page, providing a consistent and discoverable path to submit feedback.

#### Scenario: Footer link visible on all authenticated pages
- **WHEN** an authenticated user views any page (search, coordinator, admin)
- **THEN** the footer SHALL contain a "Report a Problem" link
- **AND** the link SHALL be visible without scrolling past the main content

#### Scenario: Footer link opens GitHub issue template in new tab
- **WHEN** a user clicks the "Report a Problem" footer link
- **THEN** a new browser tab SHALL open to the GitHub `report-a-problem.yml` issue template
- **AND** the URL SHALL include pre-filled parameters for the `triage` label

#### Scenario: Footer link app-version parameter is conditional on value availability
- **WHEN** `appVersion` state is non-null (the `/api/v1/version` fetch has resolved)
- **THEN** the URL SHALL include `&fabt_version={version}` (major.minor only)
- **WHEN** `appVersion` state is null (fetch in flight or failed)
- **THEN** the URL SHALL still construct and open successfully WITHOUT a `fabt_version` parameter (no literal "null" or "undefined" value SHALL appear in the URL)

#### Scenario: Footer link is keyboard accessible
- **WHEN** a keyboard user tabs through the page
- **THEN** the "Report a Problem" link SHALL be focusable and activatable via Enter key
- **AND** the link SHALL have a visible focus indicator per WCAG 2.4.7

### Requirement: report-link-prefill-privacy
The "Report a Problem" URL builder SHALL pre-fill ONLY compile-time-constant or version-derived values.

#### Scenario: Pre-fill excludes identifying values
- **WHEN** the URL is constructed for any user on any route
- **THEN** the URL SHALL NOT contain user role, tenant slug, tenant ID, user ID, user email, current page path, JWT claim values, `window.location` parameters, or route parameters

#### Scenario: Pre-fill includes only allowlisted constants and app version
- **WHEN** the URL is constructed
- **THEN** the URL SHALL include only: `template=report-a-problem.yml`, `labels=triage`, and (when known) `fabt_version={major.minor}`

#### Scenario: URL builder does not read from runtime URL or DOM
- **WHEN** the URL is constructed
- **THEN** the implementation SHALL NOT read from `window.location.search`, `window.location.hash`, `document.title`, or route-parameter objects to populate any URL parameter

### Requirement: report-link-fallback-for-non-github-users
The "Report a Problem" surface SHALL provide a non-GitHub fallback for users without a GitHub account.

#### Scenario: Mailto fallback rendered when contact info available
- **WHEN** the authenticated footer renders
- **AND** `useContactInfo()` returns a non-empty `resolvedEmail`
- **THEN** a secondary `mailto:{resolvedEmail}` link SHALL render beneath the primary GitHub link
- **AND** the link text SHALL match the localized `feedback.reportProblem.email` key

#### Scenario: Mailto fallback omitted when contact info empty
- **WHEN** `useContactInfo()` returns an empty or null `resolvedEmail`
- **THEN** the secondary mailto link SHALL NOT render
- **AND** no broken `mailto:` link with empty href SHALL appear

#### Scenario: noscript fallback when JS disabled
- **WHEN** the page is loaded with JavaScript disabled
- **THEN** a `<noscript>` block SHALL render a static link to the GitHub issues index (`https://github.com/ccradle/finding-a-bed-tonight/issues`)

#### Scenario: Mailto URL has no query parameters
- **WHEN** the secondary `mailto:` link is rendered
- **THEN** the `href` SHALL match the exact shape `mailto:{resolvedEmail}` with NO `?subject=`, `?body=`, `?cc=`, or any other query parameter

### Requirement: dv-policy-tenant-report-link-treatment
Authenticated surfaces SHALL replace GitHub-Issues feedback links with `mailto:` links when the calling tenant has DV-policy enabled.

#### Scenario: Footer link is mailto for DV-policy-enabled tenants
- **WHEN** the authenticated user's tenant has `dv_policy_enabled === true` (sourced from `useContactInfo().tenant?.dvPolicyEnabled`, NOT from the JWT)
- **AND** `useContactInfo()` returns a non-empty `resolvedEmail`
- **THEN** the footer "Report a Problem" link `href` SHALL be `mailto:{resolvedEmail}` (NOT a `github.com/.../issues/new` URL)

#### Scenario: Kebab "Help" item is mailto for DV-policy-enabled tenants
- **WHEN** the authenticated user's tenant has `dv_policy_enabled === true` (sourced from `useContactInfo().tenant?.dvPolicyEnabled`)
- **AND** `useContactInfo()` returns a non-empty `resolvedEmail`
- **THEN** the kebab "Help" item SHALL link to `mailto:{resolvedEmail}` instead of the GitHub issue chooser

#### Scenario: DV-policy-off tenant retains GitHub link
- **WHEN** `useContactInfo().tenant?.dvPolicyEnabled` is `false` or absent
- **THEN** the footer and kebab links SHALL retain their GitHub-Issues URLs (per requirement `in-app-report-problem-link`)

#### Scenario: Platform-operator (no bound tenant) falls through to GitHub
- **WHEN** the authenticated session is a platform-operator session with no bound tenantId (the response `tenant` block is absent or null)
- **THEN** `useContactInfo()` returns `tenantEmail: null` and an undefined `dvPolicyEnabled`
- **AND** the footer + kebab links SHALL retain their GitHub-Issues URLs (default-off behavior)

#### Scenario: Landing page surface is unaffected by DV-policy
- **WHEN** a visitor (unauthenticated) views the landing page
- **THEN** the "Feedback & Support" section SHALL retain its GitHub paths regardless of any tenant state (this surface has no tenant context, and `useContactInfo()` is not consumed there)

### Requirement: in-app-report-link-i18n
The "Report a Problem" link text SHALL be available in all supported locales.

#### Scenario: English locale shows English link text
- **WHEN** the locale is English
- **THEN** the footer link SHALL display "Report a Problem"

#### Scenario: Spanish locale shows Spanish link text
- **WHEN** the locale is Spanish
- **THEN** the footer link SHALL display "Reportar un Problema"

### Requirement: github-link-behavior
All issue reporting and feedback links SHALL open in a new tab without disrupting the user's current workflow.

#### Scenario: Links open in new tab with security attributes
- **WHEN** a user clicks any feedback link (report, feature, question)
- **THEN** the link SHALL open in a new tab (`target="_blank"`)
- **AND** the link SHALL include `rel="noopener noreferrer"`

#### Scenario: User's app state is preserved after reporting
- **WHEN** a user clicks "Report a Problem" while on the coordinator dashboard mid-update
- **THEN** the coordinator dashboard SHALL remain in its current state in the original tab
- **AND** no data SHALL be lost
