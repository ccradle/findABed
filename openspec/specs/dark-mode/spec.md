## ADDED Requirements

### Requirement: System dark mode support

The frontend SHALL respect the user's OS dark mode preference via `prefers-color-scheme: dark`.

#### Scenario: Dark mode activates automatically

- **WHEN** the user's OS is set to dark mode
- **THEN** the application renders with dark mode colors (dark background, light text)
- **AND** no manual toggle is required

#### Scenario: Light mode is the default

- **WHEN** the user's OS has no dark mode preference or is set to light mode
- **THEN** the application renders with light mode colors

#### Scenario: WCAG contrast ratios met in dark mode

- **WHEN** the application renders in dark mode
- **THEN** all text meets WCAG 2.1 AA contrast ratios (4.5:1 normal text, 3:1 large text)
- **AND** all UI components meet 3:1 contrast against adjacent colors

#### Scenario: Accessibility scan passes in dark mode

- **WHEN** an axe-core accessibility scan runs with `prefers-color-scheme: dark` emulated
- **THEN** zero color-contrast violations are reported

#### Scenario: Data visualizations respect dark mode

- **WHEN** the analytics dashboard renders charts in dark mode
- **THEN** chart colors, axes, and labels use dark-mode-appropriate colors with sufficient contrast
