## ADDED Requirements

### Requirement: Kebab overflow menu on mobile header
On viewports below 768px, the header SHALL show only the app title (shortened), notification bell, and a kebab (three-dot) menu icon. All other header controls SHALL be accessible via the kebab dropdown menu.

#### Scenario: Mobile header shows only primary items
- **WHEN** the viewport width is below 768px
- **THEN** the header SHALL display: shortened app title (i18n key `app.nameShort`), notification bell with badge, queue status indicator, and kebab menu icon
- **AND** the username, language selector, change password, security, and sign out controls SHALL NOT be visible in the header bar

#### Scenario: Desktop header unchanged
- **WHEN** the viewport width is 768px or above
- **THEN** the header SHALL display all controls inline as before (full title, username, language selector, notification bell, change password, security, sign out)
- **AND** no kebab menu icon SHALL be visible

#### Scenario: Kebab menu opens on tap
- **WHEN** a user taps the kebab menu icon on mobile
- **THEN** a dropdown menu SHALL appear showing: username (display only), language selector, change password, security, sign out
- **AND** each menu item SHALL have a minimum touch target of 44x44px

#### Scenario: Kebab menu closes on outside tap
- **WHEN** the kebab dropdown is open
- **AND** the user taps outside the menu
- **THEN** the menu SHALL close

#### Scenario: Kebab menu closes on Escape key
- **WHEN** the kebab dropdown is open
- **AND** the user presses the Escape key
- **THEN** the menu SHALL close
- **AND** focus SHALL return to the kebab icon

#### Scenario: Tab navigation through kebab menu items
- **WHEN** the kebab dropdown is open
- **AND** the user presses Tab
- **THEN** focus SHALL move through menu items in logical order (password, security, sign out)
- **AND** when focus leaves the last item, the menu SHALL close

#### Scenario: Kebab menu closes after action selection
- **WHEN** the user selects any action from the kebab menu (change password, security, sign out)
- **THEN** the action SHALL execute
- **AND** the menu SHALL close

#### Scenario: Language selection works inside kebab menu
- **WHEN** the user opens the kebab menu on mobile
- **AND** changes the language via the language selector
- **THEN** the language SHALL change immediately
- **AND** the kebab menu items SHALL re-render in the selected language

### Requirement: Shortened app title on mobile
On viewports below 768px, the app title SHALL display a shortened form using i18n key `app.nameShort` instead of the full `app.name` to prevent multi-line wrapping. The short name is a brand abbreviation and SHALL be defined in both en.json and es.json.

#### Scenario: Mobile shows shortened title
- **WHEN** the viewport width is below 768px
- **THEN** the header title SHALL display the value of i18n key `app.nameShort`

#### Scenario: Desktop shows full title
- **WHEN** the viewport width is 768px or above
- **THEN** the header title SHALL display the value of i18n key `app.name`

#### Scenario: Short title is defined in both languages
- **WHEN** the locale is English
- **THEN** `app.nameShort` SHALL display "FABT"
- **WHEN** the locale is Spanish
- **THEN** `app.nameShort` SHALL display "FABT"

### Requirement: Queue status indicator stays visible on mobile
The QueueStatusIndicator (offline queue badge) SHALL remain visible in the mobile header bar alongside the notification bell. It SHALL NOT be moved into the kebab menu.

#### Scenario: Queue indicator visible on mobile
- **WHEN** the viewport width is below 768px
- **AND** the user has queued offline actions
- **THEN** the queue status indicator SHALL be visible in the header bar (not in the kebab menu)

### Requirement: Kebab dropdown renders correctly in dark mode
The kebab dropdown menu SHALL render with adequate contrast in dark mode using existing CSS variables.

#### Scenario: Dark mode dropdown has adequate contrast
- **WHEN** the system preference is dark mode
- **AND** the kebab dropdown is open on a mobile viewport
- **THEN** the dropdown background, text, and borders SHALL use dark mode CSS variables
- **AND** axe-core SHALL report zero contrast violations

### Requirement: No horizontal scrolling on mobile
The header SHALL NOT cause horizontal scrolling at any viewport width down to 320px.

#### Scenario: No horizontal overflow at 412px
- **WHEN** the viewport width is 412px (common Android)
- **THEN** the page SHALL NOT have horizontal scrollbar
- **AND** all visible header items SHALL be fully within the viewport

#### Scenario: No horizontal overflow at 320px
- **WHEN** the viewport width is 320px (WCAG 1.4.10 minimum)
- **THEN** the page SHALL NOT have horizontal scrollbar

### Requirement: data-testid attributes for overflow menu
All kebab menu elements SHALL have data-testid attributes for Playwright test stability.

#### Scenario: Testable elements present
- **WHEN** the mobile header is rendered
- **THEN** the following data-testid attributes SHALL exist:
  - `header-kebab-menu` on the kebab icon button
  - `header-overflow-dropdown` on the dropdown container
  - `header-overflow-username` on the username display
  - `header-overflow-signout` on the sign out menu item
  - `header-overflow-password` on the change password menu item
  - `header-overflow-security` on the security menu item
