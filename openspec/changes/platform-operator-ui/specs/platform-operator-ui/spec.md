## ADDED Requirements

### Requirement: Platform operator SPA route tree
The system SHALL expose a `/platform/*` route tree as a lazy-loaded chunk separate from the tenant-admin route tree. The chunk SHALL be gated by a build-time flag `VITE_PLATFORM_UI_ENABLED`; when the flag is false, all `/platform/*` routes return the standard NotFound (404) component.

#### Scenario: Routes load when flag is enabled
- **WHEN** the application is built with `VITE_PLATFORM_UI_ENABLED=true` and an operator navigates to `/platform/login`
- **THEN** the platform-operator chunk is dynamically imported
- **AND** the platform login page renders

#### Scenario: Routes 404 when flag is disabled
- **WHEN** the application is built with `VITE_PLATFORM_UI_ENABLED=false` and an operator navigates to `/platform/login`
- **THEN** the route does NOT match
- **AND** the standard NotFound component renders
- **AND** no platform-operator code is loaded into the bundle

#### Scenario: Build-time tree-shaking excludes platform chunk when flag is false
- **WHEN** the application is built with `VITE_PLATFORM_UI_ENABLED=false`
- **THEN** the dynamic `import()` of the `pages/platform/` module is guarded by a top-level `if (import.meta.env.VITE_PLATFORM_UI_ENABLED !== 'true')` so Rollup dead-code-eliminates the import literal
- **AND** the resulting `dist/assets/` directory contains zero files matching `platform-*.js`
- **AND** a CI step asserts the absence of platform chunks in the `false`-flag build

#### Scenario: Tenant routes do not link to platform routes
- **WHEN** an operator inspects the rendered DOM of the tenant `/login` page
- **THEN** there is no link to `/platform/login`
- **AND** the existence of the platform login is not discoverable via the tenant UI

### Requirement: Platform operator sign-in page
The system SHALL provide a `/platform/login` route distinct in heading and copy from the tenant `/login` page, accepting email + password and posting to `POST /api/v1/auth/platform/login`.

#### Scenario: Sign-in page heading distinguishes from tenant login
- **WHEN** an operator navigates to `/platform/login`
- **THEN** the heading reads "Platform Operator Sign-In"
- **AND** a subheading explains "This is for FABT platform staff only. If you're a CoC administrator, [go to your CoC sign-in page →]" with a link to `/login`

#### Scenario: Successful first-login routes to MFA enrollment
- **WHEN** an operator submits valid credentials and `mfa_enabled=false`
- **THEN** the response is HTTP 200 with an MFA-setup scoped token
- **AND** the SPA stores the token in sessionStorage
- **AND** the SPA navigates to `/platform/mfa-enroll`

#### Scenario: Successful subsequent login routes to MFA verify
- **WHEN** an operator submits valid credentials and `mfa_enabled=true`
- **THEN** the response is HTTP 200 with an MFA-verify scoped token
- **AND** the SPA navigates to `/platform/mfa-verify`

#### Scenario: Failed login displays generic error
- **WHEN** an operator submits invalid credentials
- **THEN** the response is HTTP 401
- **AND** the SPA displays "Invalid credentials" without distinguishing between unknown email and wrong password

### Requirement: Platform JWT stored in sessionStorage
The SPA SHALL store the platform JWT in `sessionStorage` (not `localStorage`). The JWT SHALL NOT survive a browser tab close.

#### Scenario: JWT is stored on successful authentication
- **WHEN** the SPA receives a platform JWT from `/auth/platform/login/mfa-verify`
- **THEN** the JWT is written to `sessionStorage` under a known key
- **AND** the JWT is NOT written to `localStorage`
- **AND** the JWT is NOT written to a cookie

#### Scenario: JWT is cleared on tab close
- **WHEN** the operator closes the browser tab and reopens to `/platform/dashboard`
- **THEN** sessionStorage is empty
- **AND** the SPA redirects to `/platform/login`

### Requirement: Platform protected route guard
The SPA SHALL include a `<PlatformProtectedRoute>` component that checks for a valid platform JWT in sessionStorage AND a `mfaVerified=true` claim. The guard SHALL redirect to `/platform/login` if either check fails.

#### Scenario: Unauthenticated access redirects to login
- **WHEN** an operator navigates to `/platform/dashboard` without a platform JWT in sessionStorage
- **THEN** the SPA redirects to `/platform/login`
- **AND** the dashboard is not rendered

#### Scenario: MFA-setup-only token cannot reach dashboard
- **WHEN** an operator navigates to `/platform/dashboard` with an MFA-setup-scoped token
- **THEN** the guard rejects (mfaVerified !== true)
- **AND** the SPA redirects to `/platform/mfa-enroll`

#### Scenario: Expired JWT redirects with toast
- **WHEN** an operator navigates to `/platform/dashboard` with a JWT whose `exp` is in the past
- **THEN** the SPA wipes sessionStorage
- **AND** redirects to `/platform/login`
- **AND** displays a toast: "Session expired — please sign in again"

#### Scenario: Guard rejects already-expired exp synchronously on mount
- **WHEN** an operator navigates to a guarded route with a JWT whose `exp <= Date.now()/1000`
- **THEN** the guard performs a synchronous `Date.now() >= exp*1000` check INSIDE the guard before any child component renders
- **AND** redirects to `/platform/login` BEFORE any child fetch (e.g. the dashboard's `/me` request) is initiated
- **AND** no spurious 401 toast races the expiry redirect

#### Scenario: Guard validates JWT issuer and shape, not just claim presence
- **WHEN** an operator navigates to a guarded route with a JWT
- **THEN** the guard verifies `iss === "fabt-platform"` AND `mfaVerified === true` AND the token is 3 dot-separated segments
- **AND** rejects to `/platform/login` if any check fails (defense against renamed claims)

### Requirement: 401 / 403 handler clears session and redirects
The SPA platform-API fetch wrapper SHALL handle every 401 response by wiping sessionStorage and redirecting to `/platform/login`. 403 responses SHALL be handled distinctly: a 403 from `/me` indicates a wrong-scope token (typically MFA-setup-only) and SHALL redirect to `/platform/mfa-enroll` WITHOUT wiping sessionStorage.

#### Scenario: Backend revokes JWT mid-session
- **WHEN** the SPA POSTs to a `@PlatformAdminOnly` endpoint and receives HTTP 401
- **THEN** the wrapper clears sessionStorage
- **AND** the SPA redirects to `/platform/login`
- **AND** displays a toast: "Session expired — please sign in again"

#### Scenario: Concurrent 401 responses do not double-navigate
- **WHEN** multiple in-flight requests receive 401 simultaneously after backend invalidation
- **THEN** a module-level `isHandling401` flag ensures only the first 401 triggers the redirect
- **AND** subsequent 401 handlers return early (no duplicate navigation, no toast spam)

#### Scenario: 403 from /me with mfa-setup-only token redirects to enrollment
- **WHEN** the SPA fetches `/me` and receives HTTP 403
- **THEN** the wrapper redirects to `/platform/mfa-enroll`
- **AND** sessionStorage is NOT wiped (the MFA-setup token remains valid for the enrollment flow)
- **AND** no toast is displayed

### Requirement: Persistent platform-operator banner
The SPA SHALL render a persistent "PLATFORM OPERATOR MODE" banner across all `/platform/*` routes using a new `--color-platform` semantic token. The banner SHALL show operator email, a Logout button, and a session-expiry countdown.

#### Scenario: Banner visible on every platform route
- **WHEN** an operator navigates between `/platform/login`, `/platform/mfa-enroll`, `/platform/mfa-verify`, and `/platform/dashboard`
- **THEN** the banner is rendered at the top of every route
- **AND** uses the `--color-platform` token (NOT `--color-warning` or any other reused token)

#### Scenario: Countdown turns amber at 2 minutes
- **WHEN** the JWT has 2 minutes or less until `exp`
- **THEN** the countdown text color shifts to amber
- **AND** the countdown updates every second

#### Scenario: Countdown turns red at 30 seconds
- **WHEN** the JWT has 30 seconds or less until `exp`
- **THEN** the countdown text color shifts to red

#### Scenario: At expiry, redirect with toast
- **WHEN** the countdown reaches 0
- **THEN** the SPA wipes sessionStorage
- **AND** redirects to `/platform/login`
- **AND** displays a toast: "Session expired — please sign in again"

#### Scenario: Logout button clears session
- **WHEN** an operator clicks the Logout button in the banner
- **THEN** the SPA POSTs to `/api/v1/auth/platform/logout`
- **AND** wipes sessionStorage regardless of the logout response
- **AND** redirects to `/platform/login`

### Requirement: MFA enrollment displays QR + manual secret + supported authenticators
The `/platform/mfa-enroll` route SHALL display the TOTP QR code, the manual-entry secret, and an explicit list of supported authenticators.

#### Scenario: QR code rendered from otpauth URI
- **WHEN** the enrollment endpoint returns a TOTP secret + otpauth URI
- **THEN** the SPA renders the QR code from the URI using a vetted library
- **AND** the manual-entry secret is displayed as text below the QR

#### Scenario: Supported authenticators listed
- **WHEN** the enrollment view renders
- **THEN** the SPA displays the text "Works with Google Authenticator, Microsoft Authenticator, 1Password, Authy, Bitwarden, and any TOTP-compatible app"

#### Scenario: QR code is screen-reader accessible
- **WHEN** the QR code element renders
- **THEN** the image has an `aria-label` describing the QR plus pointing to the manual-entry secret element ("QR code containing your TOTP secret. If you cannot scan, use the manual code below.")
- **AND** the manual-entry secret element has an id that the QR's `aria-label` can reference

#### Scenario: Reload mid-enrollment recovers the same secret
- **WHEN** an operator reloads the page during MFA enrollment (after QR is shown but before confirm)
- **AND** the SPA still holds a valid MFA-setup-scoped token in sessionStorage
- **THEN** the SPA re-fetches `/auth/platform/mfa-setup` (idempotent on backend — returns the same secret for the same setup token)
- **AND** the SAME QR + secret are re-rendered
- **AND** the operator can complete enrollment without restart

#### Scenario: Reload after MFA-setup-token expires forces restart
- **WHEN** an operator reloads the page during MFA enrollment AND the MFA-setup token has expired (>10min since issuance)
- **THEN** the SPA detects the expired token, wipes sessionStorage
- **AND** redirects to `/platform/login` with toast: "Enrollment session expired — please sign in again to restart"

### Requirement: Backup codes one-shot display with confirmation gate
The SPA SHALL display backup codes exactly once after MFA confirmation. The Continue button SHALL be disabled until the operator checks "I have saved my backup codes."

#### Scenario: Backup codes displayed in monospace block
- **WHEN** MFA enrollment confirms successfully
- **THEN** 10 backup codes are displayed in a monospace block
- **AND** above the block: "These 10 codes are your ONLY way back in if you lose your phone. Save them in a password manager NOW. They will never be shown again."

#### Scenario: Continue button disabled until confirmation checkbox
- **WHEN** the backup codes are displayed
- **THEN** the Continue button is disabled
- **AND** a checkbox labeled "I have saved my backup codes" is presented
- **AND** the Continue button is enabled only after the checkbox is checked

#### Scenario: Backup codes not re-fetchable via back-button
- **WHEN** an operator clicks Continue, navigates away, and presses the browser back-button
- **THEN** the backup-codes view does NOT re-render the codes
- **AND** the backend `/auth/platform/mfa-confirm` response that delivered the codes carried headers `Cache-Control: no-store, no-cache, must-revalidate` and `Pragma: no-cache`

#### Scenario: Codes rendered as text nodes only (XSS defense)
- **WHEN** the BackupCodesDisplay component renders the 10 codes
- **THEN** each code is rendered via React text-node interpolation (`{code}`), NOT via `dangerouslySetInnerHTML`
- **AND** an ESLint rule (or equivalent linter assertion) forbids `dangerouslySetInnerHTML` in `pages/platform/components/BackupCodesDisplay.tsx`
- **AND** a unit test confirms that codes containing `<script>` characters render as literal text, not interpreted HTML

### Requirement: Print backup codes with confirmation modal and stripped print view
The SPA SHALL provide a Print button on the backup-codes view, gated by a confirmation modal. The print view SHALL strip everything except the heading, the 10 codes, and a "store securely" notice.

#### Scenario: Print button opens confirmation modal
- **WHEN** an operator clicks Print
- **THEN** a confirmation modal appears with copy: "These codes will be sent to your printer or saved as a PDF. They will appear in your OS print queue and may be retained by network printers. Continue?"
- **AND** the primary button is labeled exactly "Cancel" (default-focused)
- **AND** the secondary button is labeled exactly "Print Anyway"
- **AND** `window.print()` is NOT invoked until Print Anyway is clicked

#### Scenario: @media print CSS strips PII
- **WHEN** the operator confirms Print and the print preview renders
- **THEN** the printed page contains only: heading "Platform Operator Backup Codes", the 10 codes in monospace, and the notice "Store securely. These codes can authenticate as your account."
- **AND** the printed page does NOT contain operator email, URL, timestamp, QR code, or any FABT branding beyond the heading

#### Scenario: No telemetry on print action
- **WHEN** the operator clicks Print or Print Anyway
- **THEN** no analytics event is emitted
- **AND** no Sentry breadcrumb is recorded
- **AND** no audit log entry is written for the click

### Requirement: Copy backup codes with confirmation modal and auto-clear
The SPA SHALL provide a Copy-to-Clipboard button on the backup-codes view, gated by the same confirmation modal pattern as Print. After copying, the SPA SHALL auto-clear the clipboard 30 seconds later.

#### Scenario: Copy button opens confirmation modal
- **WHEN** an operator clicks Copy
- **THEN** a confirmation modal appears with copy naming clipboard-history risk: "These codes will be placed on your system clipboard. Clipboard managers and pasted-into apps may retain them. The clipboard will auto-clear in 30 seconds. Continue?"
- **AND** the primary button is labeled exactly "Cancel" (default-focused)
- **AND** the secondary button is labeled exactly "Copy Anyway"
- **AND** the codes are NOT copied to the clipboard until Copy Anyway is clicked

#### Scenario: Clipboard auto-cleared after 30 seconds
- **WHEN** an operator confirms Copy Anyway
- **THEN** the SPA invokes `navigator.clipboard.writeText(codes)`
- **AND** displays a toast: "Codes copied — clipboard will auto-clear in 30 seconds"
- **AND** schedules `setTimeout(() => navigator.clipboard.writeText(''), 30000)`
- **AND** the clipboard is empty (or contains only the empty string) 30 seconds after the copy

#### Scenario: No telemetry on copy action
- **WHEN** the operator clicks Copy or Copy Anyway
- **THEN** no analytics event is emitted
- **AND** no Sentry breadcrumb is recorded

### Requirement: Platform dashboard renders operator metadata
The `/platform/dashboard` route SHALL fetch `GET /api/v1/auth/platform/me` on mount and render operator email, last-login timestamp, MFA-enrolled date, and backup-codes-remaining badge.

#### Scenario: Dashboard fetches metadata on mount
- **WHEN** the dashboard route loads
- **THEN** the SPA fetches `GET /api/v1/auth/platform/me` with the platform JWT
- **AND** displays the returned email, lastLoginAt, mfaEnabledAt, backupCodesRemaining

#### Scenario: Backup-codes badge color thresholds
- **WHEN** `backupCodesRemaining > 3`
- **THEN** the badge renders in default color
- **WHEN** `backupCodesRemaining <= 3 AND > 1`
- **THEN** the badge renders in amber
- **WHEN** `backupCodesRemaining <= 1`
- **THEN** the badge renders in red

#### Scenario: Metadata fetch failure shows fallback
- **WHEN** the `/me` request fails (404, 500, or network error)
- **THEN** the dashboard renders the action cards anyway
- **AND** displays "Operator metadata unavailable" in the header (does not crash)

### Requirement: Action cards grouped by category with flag-gated disabled state
The dashboard SHALL render action cards grouped by category (Tenant Lifecycle, Operator Management, System Status). Cards whose endpoint is gated by `fabt.tenant.lifecycle.enabled=false` SHALL render disabled with an explanatory tooltip.

#### Scenario: Lifecycle action card renders disabled when flag off
- **WHEN** the dashboard renders and `fabt.tenant.lifecycle.enabled=false`
- **THEN** the Suspend Tenant card is rendered but disabled
- **AND** hovering the card shows a tooltip: "Tenant lifecycle is disabled in this deployment. Contact platform engineering to enable."
- **AND** clicking the card does NOT POST to the endpoint

#### Scenario: Lifecycle action card renders enabled when flag on
- **WHEN** the dashboard renders and `fabt.tenant.lifecycle.enabled=true`
- **THEN** the Suspend Tenant card is rendered as a clickable button

#### Scenario: Operator Management category placeholder for v0.54
- **WHEN** the dashboard renders in v0.54
- **THEN** the Operator Management category contains a single placeholder card "Operator self-management coming v0.55"

#### Scenario: Heading hierarchy supports screen-reader navigation
- **WHEN** the dashboard renders
- **THEN** the page title (e.g. "Platform Operator Dashboard") renders as `<h1>`
- **AND** each category title (Tenant Lifecycle, Operator Management, System Status) renders as `<h2>`
- **AND** each action card title within a category renders as `<h3>`
- **AND** screen reader navigation by heading level produces a meaningful page outline

### Requirement: Destructive action confirmation with typed slug
Suspend, unsuspend, and (when shipped) hard-delete actions SHALL require typed-confirmation of the target tenant slug before the action POSTs.

#### Scenario: Suspend action requires typed confirmation
- **WHEN** an operator clicks Suspend Tenant for `dev-coc`
- **THEN** a modal opens asking the operator to type `dev-coc` to confirm
- **AND** the Suspend button in the modal is disabled until the typed text matches exactly
- **AND** the modal also requires the X-Platform-Justification text (min 10 chars)

#### Scenario: List/read actions skip the typed confirmation
- **WHEN** an operator clicks a List Tenants or Show Status card
- **THEN** the request POSTs immediately without a typed-confirmation modal

### Requirement: data-testid coverage on every interactive element
Every interactive element on `/platform/*` routes SHALL have a `data-testid` attribute following the pattern `platform-{view}-{action}`.

#### Scenario: Login form interactive elements have testids
- **WHEN** Playwright queries the login form
- **THEN** the email input has `data-testid="platform-login-email"`
- **AND** the password input has `data-testid="platform-login-password"`
- **AND** the submit button has `data-testid="platform-login-submit"`

#### Scenario: Dashboard action cards have testids
- **WHEN** Playwright queries the dashboard
- **THEN** each action card has `data-testid="platform-dashboard-{action-id}"`
- **AND** confirmation modal inputs have `data-testid="platform-confirm-{slug-input,justification-input,confirm-button}"`

### Requirement: MFA verify error states
The `/platform/mfa-verify` route SHALL render distinct error states for invalid TOTP codes, account lockout, and network failure.

#### Scenario: Wrong TOTP code displays attempts-remaining message
- **WHEN** an operator submits an invalid TOTP code and the backend returns 401 with attempts-remaining context
- **THEN** the SPA displays "Code invalid. X attempts remaining before lockout."
- **AND** the input is cleared and refocused
- **AND** the operator can retry without re-entering the email/password

#### Scenario: Account lockout displays lockout-duration message
- **WHEN** an operator's account has been locked (5 failed MFA attempts within 15 minutes)
- **AND** the operator submits another code
- **THEN** the SPA displays "Too many failed attempts. Account locked for 15 minutes. If you've lost your phone, use a backup code."
- **AND** the TOTP input is disabled
- **AND** a "Use backup code instead" link remains active

#### Scenario: Network error displays retryable message
- **WHEN** the MFA verify request fails with a network error (no HTTP response)
- **THEN** the SPA displays "Couldn't reach server. Check your connection and try again."
- **AND** the submit button re-enables for retry
- **AND** sessionStorage is NOT wiped (the MFA-verify scoped token remains valid)

#### Scenario: Backup code path mirrors TOTP error handling
- **WHEN** an operator submits an invalid backup code
- **THEN** the SPA displays "Backup code invalid. X attempts remaining before lockout."
- **AND** the same lockout/network-error scenarios apply as for TOTP

### Requirement: Platform routes inherit production CSP
All `/platform/*` routes SHALL inherit the existing nginx Content Security Policy. The SPA chunk SHALL NOT require `'unsafe-inline'` script or style; the QR-code rendering library SHALL be CSP-compatible.

#### Scenario: CSP headers present on platform responses
- **WHEN** a request to any `/platform/*` route reaches nginx
- **THEN** the response includes the same `Content-Security-Policy` header as tenant routes
- **AND** the SPA loads without CSP violations in the browser console

#### Scenario: QR-code library is CSP-compatible
- **WHEN** the chosen QR-code library (e.g. `qrcode.react`) renders in production CSP
- **THEN** no `'unsafe-inline'` exemption is required
- **AND** no `'unsafe-eval'` exemption is required
- **AND** the library renders the QR via SVG or canvas without inline event handlers

### Requirement: WCAG 2.1 AA conformance on all platform routes
All `/platform/*` routes SHALL pass an axe-core sweep with zero serious or critical violations. The new `--color-platform` token SHALL meet AA contrast against all text colors used on the banner.

#### Scenario: Axe-core sweep passes
- **WHEN** the CI Playwright + axe-core sweep runs against `/platform/login`, `/platform/mfa-enroll`, `/platform/mfa-verify`, `/platform/dashboard`
- **THEN** zero serious or critical accessibility violations are reported

#### Scenario: Banner color meets AA contrast
- **WHEN** the banner renders with `--color-platform` background and white-or-near-white text
- **THEN** the contrast ratio meets WCAG 2.1 AA (4.5:1 for normal text, 3:1 for large text)
