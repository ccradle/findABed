## ADDED Requirements

### Requirement: Avatar/initials profile trigger in header
The header SHALL display a single avatar/initials button as the profile trigger, replacing separate Password, Security, and Sign Out buttons.

#### Scenario: Desktop header shows avatar instead of separate buttons
- **WHEN** the viewport width is 768px or above
- **THEN** the header SHALL display: app title, language selector, queue status indicator, notification bell, and avatar/initials button
- **AND** no separate Password, Security, or Sign Out buttons SHALL be visible

#### Scenario: Mobile header shows avatar instead of kebab
- **WHEN** the viewport width is below 768px
- **THEN** the header SHALL display: shortened app title, queue status indicator, notification bell, and avatar/initials button
- **AND** no kebab (⋮) icon SHALL be visible

#### Scenario: Avatar meets WCAG touch target
- **WHEN** the avatar button is rendered on any viewport
- **THEN** the tappable area SHALL be at least 44x44 CSS pixels (visual circle may be smaller, achieved via padding)

#### Scenario: Avatar displays user initials
- **WHEN** the user's displayName is "Sandra Kim"
- **THEN** the avatar SHALL display "SK"
- **WHEN** the displayName is "Darius"
- **THEN** the avatar SHALL display "Da"
- **WHEN** the displayName is empty or null
- **THEN** the avatar SHALL display "?"

### Requirement: Profile dropdown with account actions
Clicking the avatar SHALL open a dropdown containing user identity, settings link, and sign out.

#### Scenario: Dropdown shows user identity
- **WHEN** the profile dropdown is open
- **THEN** it SHALL display the user's display name and role badge at the top

#### Scenario: Dropdown contains settings link
- **WHEN** the profile dropdown is open
- **THEN** it SHALL contain a "Settings" link that navigates to `/settings`

#### Scenario: Dropdown contains language selector on mobile
- **WHEN** the viewport is below 768px and the dropdown is open
- **THEN** the language selector SHALL appear in the dropdown
- **WHEN** the viewport is 768px or above
- **THEN** the language selector SHALL remain in the header (not in dropdown)

#### Scenario: Dropdown contains sign out
- **WHEN** the profile dropdown is open
- **THEN** Sign Out SHALL be the last item, visually separated by a border

#### Scenario: Dropdown closes on outside click, Escape, and action
- **WHEN** the dropdown is open
- **THEN** it SHALL close on outside click, Escape key press, or selecting an action
- **AND** Escape SHALL return focus to the avatar button

#### Scenario: Dropdown is keyboard accessible
- **WHEN** the dropdown is open and user presses Tab
- **THEN** focus SHALL move through items in logical order
- **AND** the avatar button SHALL have `aria-haspopup="true"` and `aria-expanded`

### Requirement: Settings page with password and security sections
A `/settings` route SHALL display password change and security (TOTP) management in a single page.

#### Scenario: Settings page has password section
- **WHEN** the user navigates to `/settings`
- **THEN** a Password section SHALL display with current password, new password, and confirm fields
- **AND** the form SHALL behave identically to the existing ChangePasswordModal

#### Scenario: Settings page has security section
- **WHEN** the user navigates to `/settings`
- **THEN** a Security section SHALL display TOTP enrollment/management
- **AND** the flow SHALL behave identically to the existing TotpEnrollmentPage

#### Scenario: Settings page is responsive
- **WHEN** the viewport is below 768px
- **THEN** the settings sections SHALL stack vertically with full width

### Requirement: Settings page respects DemoGuard and rate limiting
The `/settings` page calls existing backend APIs that are already protected by DemoGuard and rate limiting. These protections SHALL continue to work from the settings page.

#### Scenario: DemoGuard blocks password change from settings page
- **WHEN** a public demo user navigates to `/settings` and submits a password change
- **THEN** the API SHALL return 403 `demo_restricted` (same as the modal path)

#### Scenario: TOTP enrollment allowed from settings page in demo
- **WHEN** a public demo user navigates to `/settings` and starts TOTP enrollment
- **THEN** the API SHALL allow it (TOTP enrollment is on the DemoGuard allowlist)

#### Scenario: Rate limiting applies to settings page API calls
- **WHEN** a user submits rapid password change requests from `/settings`
- **THEN** existing rate limiting SHALL apply (same API endpoint, same limits)

### Requirement: Avatar and dropdown use design tokens
All new UI components SHALL use CSS custom property design tokens — no hardcoded hex values, font sizes, or weights.

#### Scenario: Avatar uses color tokens
- **WHEN** the avatar circle is rendered
- **THEN** background SHALL use `color.primary` and text SHALL use `color.textInverse`
- **AND** no hardcoded hex values SHALL appear in the component

#### Scenario: New components use typography tokens
- **WHEN** any new component (avatar, dropdown, settings page) renders text
- **THEN** font sizes SHALL use `text.*` tokens, weights SHALL use `weight.*` tokens
- **AND** line-height SHALL use unitless ratios >= 1.5 (WCAG 1.4.12)

#### Scenario: Dark mode contrast passes axe-core
- **WHEN** the avatar dropdown is open in dark mode
- **THEN** axe-core SHALL report zero contrast violations on the dropdown and avatar

### Requirement: data-testid attributes for profile UI
All profile dropdown and settings page elements SHALL have data-testid attributes.

#### Scenario: Testable elements present
- **WHEN** the header is rendered
- **THEN** `data-testid="profile-avatar"` SHALL exist on the avatar button
- **AND** `data-testid="profile-dropdown"` SHALL exist on the dropdown container
- **AND** `data-testid="profile-settings-link"` on the settings link
- **AND** `data-testid="profile-signout"` on the sign out item
