## ADDED Requirements

### Requirement: language-switching-e2e
The E2E suite SHALL verify that switching to Español changes UI text and switching back reverts to English.

#### Scenario: Language switch to Spanish and back
- **WHEN** the user selects Español from the language selector
- **THEN** at least three visible strings change from their English values
- **WHEN** the user selects English
- **THEN** all text reverts to English
