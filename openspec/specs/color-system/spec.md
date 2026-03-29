## ADDED Requirements

### Requirement: CSS custom property color tokens

The frontend SHALL define all colors as CSS custom properties in `global.css` with a shared TypeScript constants file.

#### Scenario: Color tokens defined in :root

- **WHEN** the application loads
- **THEN** all semantic color tokens are available as CSS custom properties (--color-primary, --color-bg, --color-text, etc.)

#### Scenario: No hardcoded hex values in component files

- **WHEN** any component file is inspected
- **THEN** all color values reference `var(--color-*)` or the TypeScript `color.*` constants
- **AND** no raw hex values (#xxxxxx) appear in inline styles or CSS

#### Scenario: TypeScript constants mirror CSS properties

- **WHEN** a developer imports from `colors.ts`
- **THEN** each constant resolves to the corresponding `var(--color-*)` reference
