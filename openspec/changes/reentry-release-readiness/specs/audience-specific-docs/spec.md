## ADDED Requirements

### Requirement: Audience FOR-*.md docs scope each zero-PII claim
Each of `docs/FOR-COC-ADMINS.md`, `docs/FOR-CITIES.md`, `docs/FOR-DEVELOPERS.md` SHALL include, after every existing "zero PII" or "no client information" claim, a one-sentence scope addendum acknowledging the v0.55 navigator-hold opt-in PII path.

#### Scenario: COC Admins doc scopes its zero-PII claim
- **WHEN** `docs/FOR-COC-ADMINS.md:84` and `:108` are read post-change
- **THEN** each "zero PII" claim SHALL be followed (within the same paragraph or as the next sentence) by a scope statement acknowledging that v0.55 navigator holds may optionally collect client name/DOB/notes, encrypted at rest and purged 24h post-resolution

#### Scenario: Cities doc scopes its zero-PII claim
- **WHEN** `docs/FOR-CITIES.md:108` is read post-change
- **THEN** the existing "zero PII" claim SHALL be followed by the same path-scoping addendum

#### Scenario: Developers doc scopes its zero-PII claim
- **WHEN** `docs/FOR-DEVELOPERS.md:849` is read post-change
- **THEN** the existing "Zero client PII in the database" claim SHALL be followed by the path-scoping addendum

### Requirement: Audience-page acknowledgment of reentry use case
`docs/FOR-CITIES.md` and `docs/FOR-FUNDERS.md` SHALL include at least one sentence acknowledging reentry / justice-system-adjacent populations as a distinct use case the platform supports.

#### Scenario: Cities doc mentions reentry use case
- **WHEN** `docs/FOR-CITIES.md` is read post-change
- **THEN** at least one sentence SHALL reference the reentry use case
- **AND** the sentence SHALL NOT name a specific real city, real CoC, or real reentry program

#### Scenario: Funders doc mentions reentry use case
- **WHEN** `docs/FOR-FUNDERS.md` is read post-change
- **THEN** at least one sentence SHALL reference reentry as a distinct use case
- **AND** the sentence SHALL NOT name a specific real city, real CoC, or real reentry program
