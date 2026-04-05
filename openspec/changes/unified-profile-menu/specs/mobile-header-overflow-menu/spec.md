## MODIFIED Requirements

### Requirement: Kebab overflow menu on mobile header
The kebab (⋮) menu SHALL be replaced by the avatar/initials profile button. The dropdown contents remain the same (username, language, password via settings link, security via settings link, sign out).

#### Scenario: Avatar replaces kebab on mobile
- **WHEN** the viewport width is below 768px
- **THEN** the avatar/initials button SHALL appear where the kebab icon was
- **AND** no kebab (⋮) icon SHALL be visible
- **AND** tapping the avatar SHALL open the same dropdown with account actions
