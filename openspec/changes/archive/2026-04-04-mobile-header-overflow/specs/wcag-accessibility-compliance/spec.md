## ADDED Requirements

### Requirement: WCAG 1.4.10 Reflow compliance for header
The application header SHALL not cause horizontal scrolling at viewport widths down to 320px, satisfying WCAG 1.4.10 (Reflow) Level AA.

#### Scenario: Header reflows at 320px without horizontal scroll
- **WHEN** the viewport width is set to 320px
- **THEN** all header content SHALL be accessible without horizontal scrolling
- **AND** axe-core SHALL report zero Critical or Serious violations

#### Scenario: Header touch targets meet WCAG 2.5.5
- **WHEN** the kebab menu is open on a mobile viewport
- **THEN** all interactive menu items SHALL have a minimum touch target of 44x44 CSS pixels
