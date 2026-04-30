## ADDED Requirements

### Requirement: Path-scoped PII claims on public surfaces
Every public-facing assertion about the platform's PII handling SHALL be scoped to the specific data path it describes (DV referral path vs non-DV navigator-hold path). Platform-wide claims that the system stores zero PII SHALL be removed or rewritten when v0.55+ is the deployed version.

#### Scenario: Live root page does not assert platform-wide zero-PII
- **WHEN** `https://findabed.org/index.html` is fetched after v0.55 deploy
- **THEN** the page SHALL NOT contain the literal phrase "no client name, no address in the system, ever"
- **AND** any zero-PII claim on the page SHALL be qualified to "DV referral path" or equivalent specific scope

#### Scenario: Government adoption guide path-scopes its PII claims
- **WHEN** `docs/government-adoption-guide.md` is read post-change
- **THEN** the line at `:73` and `:121` SHALL distinguish DV-path zero-PII from non-DV opt-in encrypted-and-purged PII
- **AND** the VAWA-protection section SHALL include an explicit sentence stating that v0.55 hold-attribution PII is NOT used in the DV referral path

#### Scenario: Audience FOR-*.md docs scope each zero-PII reference
- **WHEN** any of `docs/FOR-COC-ADMINS.md`, `docs/FOR-CITIES.md`, `docs/FOR-DEVELOPERS.md` is read post-change
- **THEN** every "zero PII" or "no client information" claim SHALL be followed within the same paragraph by a scope sentence covering the navigator-hold path

### Requirement: Hospital privacy summary distinguishes data paths
`docs/hospital-privacy-summary.md` SHALL present the platform's PII storage posture as a two-column comparison (DV referral path / navigator-hold path) rather than a single "Never" column, because the hospital social worker is a navigator-role audience that may opt into PII collection.

#### Scenario: Two-column "what FABT stores" table
- **WHEN** the document is read post-change
- **THEN** the storage table SHALL have at least two columns: one for the DV referral path showing "Never" for client identifiers, and one for the navigator-hold path showing "Optional, encrypted at rest, purged 24h" for client name + DOB

#### Scenario: BAA framing reflects opt-in PII path
- **WHEN** the document's BAA section is read post-change
- **THEN** the section SHALL state that no BAA is *typically* required if the hospital workflow uses zero opt-in PII fields
- **AND** the section SHALL recommend that the hospital privacy officer review the platform's data flow before any hospital-employed user creates an account, regardless of whether opt-in fields are used (because incidental metadata from a covered-entity workforce member can independently trigger BAA review)
- **AND** the section SHALL state that using the opt-in fields is a HIPAA conversation the hospital privacy officer must own

### Requirement: Right-to-be-forgotten doc exists at the cited path
`docs/legal/right-to-be-forgotten.md` SHALL exist in the code repo, because `docs/security/compliance-posture-matrix.md:110` cites the file as authoritative documentation. A cited-but-missing file is a `feedback_truthfulness_above_all` violation.

#### Scenario: File exists at the cited path
- **WHEN** the change is archived
- **THEN** `docs/legal/right-to-be-forgotten.md` SHALL exist
- **AND** the file SHALL contain at least: a self-hosted-vs-SaaS scope statement, a description of the 24h hold-attribution PII purge as the platform's automated retention behavior, and a deferral statement directing data-subject access requests to the deployment owner (not the FABT project)

#### Scenario: File deferral language for jurisdictional reach
- **WHEN** the file is read
- **THEN** it SHALL state explicitly that the project does not currently take a position on GDPR/CCPA reach, and that international deployment compliance is the deployment owner's responsibility

#### Scenario: 24h automated purge does not satisfy ad-hoc data-subject deletion requests
- **WHEN** the file is read
- **THEN** it SHALL state that the 24-hour automated purge is the platform's automated retention floor, NOT a substitute for an ad-hoc data-subject deletion request
- **AND** it SHALL state that ad-hoc requests are the deployment owner's responsibility, with tenant offboarding as the mechanism for full erasure

#### Scenario: File includes a deployment-owner runbook
- **WHEN** the file is read
- **THEN** it SHALL include a one-page runbook for the deployment owner covering: how to verify data-subject request authenticity; which SQL queries enumerate a person's data across `reservation`, `audit_events`, and `app_user`; and how the tenant offboarding workflow effects full erasure
- **AND** the runbook SHALL be operator-readable (no engineer-internal jargon; named tables and columns are fine)

### Requirement: AsyncAPI contract distinguishes DV-event PII posture from reservation-event PII posture
`docs/asyncapi.yaml` SHALL keep its zero-client-PII assertions verbatim on DV-event sites (the contract is unchanged) AND SHALL add explicit documentation on reservation-event-related sites that the reservation row may carry encrypted PII server-side that is never published over AsyncAPI by design.

#### Scenario: DV events keep zero-PII contract
- **WHEN** the YAML is grepped for "zero client PII" within DV-namespaced event definitions
- **THEN** all such matches SHALL remain present and unchanged

#### Scenario: Reservation events carry the negative-space note
- **WHEN** any reservation-event-related schema is inspected
- **THEN** it SHALL include a doc note stating that hold-attribution PII is server-side-only and is not emitted over AsyncAPI, by design
