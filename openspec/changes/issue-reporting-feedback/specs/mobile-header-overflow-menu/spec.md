## MODIFIED Requirements

### Requirement: Kebab overflow menu on mobile header
On viewports below 768px, the header SHALL show only the app title (shortened), notification bell, and a kebab (three-dot) menu icon. All other header controls SHALL be accessible via the kebab dropdown menu.

#### Scenario: Kebab menu opens on tap
- **WHEN** a user taps the kebab menu icon on mobile
- **THEN** a dropdown menu SHALL appear showing: username (display only), language selector, change password, security, **help**, sign out
- **AND** each menu item SHALL have a minimum touch target of 44x44px

#### Scenario: Tab navigation through kebab menu items
- **WHEN** the kebab dropdown is open
- **AND** the user presses Tab
- **THEN** focus SHALL move through menu items in logical order (password, security, **help**, sign out)
- **AND** when focus leaves the last item, the menu SHALL close

## ADDED Requirements

### Requirement: help-menu-item-in-kebab
The kebab overflow menu SHALL include a "Help" item that links to issue reporting, positioned before "Sign Out".

#### Scenario: Help item opens GitHub issue chooser
- **WHEN** a user taps "Help" in the kebab menu
- **THEN** a new browser tab SHALL open to the GitHub issue template chooser (`/issues/new/choose`)
- **AND** the kebab menu SHALL close

#### Scenario: Help item has data-testid
- **WHEN** the mobile header kebab menu is rendered
- **THEN** the Help menu item SHALL have `data-testid="header-overflow-help"`

#### Scenario: Help item has correct i18n
- **WHEN** the locale is English
- **THEN** the menu item SHALL display "Help"
- **WHEN** the locale is Spanish
- **THEN** the menu item SHALL display "Ayuda"
