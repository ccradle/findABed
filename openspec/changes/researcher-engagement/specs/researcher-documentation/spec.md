## ADDED Requirements

### Requirement: for-researchers-document
A `docs/FOR-RESEARCHERS.md` SHALL exist with a complete data inventory of every table in the FABT database, organized by research relevance, with honest limitations and access tier classification.

#### Scenario: University PI evaluates FABT for study
- **GIVEN** a researcher discovers FABT via Google Scholar or NAEH
- **WHEN** they read FOR-RESEARCHERS.md
- **THEN** they SHALL understand: what data FABT captures, what it does NOT capture, how to access it, and what IRB considerations apply
- **AND** they SHALL NOT be told what to study or what metrics to track

### Requirement: data-inventory-completeness
The data inventory SHALL cover every user-facing table with: table name, columns, what research questions the data COULD support, what the data CANNOT answer, retention policies, and PII classification.

#### Scenario: Data inventory covers all tables
- **WHEN** a researcher reads the data inventory
- **THEN** it SHALL include: bed_availability, daily_utilization_summary, bed_search_log, reservation, referral_token, surge_event, shelter (no phone numbers, DV shelter addresses excluded from Open tier), shelter_constraints, audit_events, hmis_outbox, hmis_audit_log, coordinator_assignment, and import_log
- **AND** each entry SHALL state what the table captures, what it does NOT capture, and any data quality caveats

### Requirement: three-access-tiers
The document SHALL define three data access tiers: Open (de-identified aggregate), Protected (minimum cell size), and Restricted (DV data requiring full IRB).

#### Scenario: DV researcher understands access requirements
- **GIVEN** a researcher wants to study DV referral patterns
- **WHEN** they read the access tier section
- **THEN** they SHALL understand that DV shelter identities and individual referral records require: CoC DV committee approval, institutional IRB full review, and a data use agreement
- **AND** they SHALL understand that terminal referral tokens are hard-deleted within 24 hours

### Requirement: honest-limitations
The document SHALL explicitly state what FABT does NOT capture: no client demographics beyond population type, no outcome data, no barrier/eligibility data, no service provision data, no cost data, no discharge location.

#### Scenario: Researcher understands data boundaries
- **WHEN** a researcher reads the limitations section
- **THEN** they SHALL understand that FABT is an operational coordination tool, not a client management system
- **AND** they SHALL NOT expect client-level data

### Requirement: irb-guidance
The document SHALL provide IRB framing that is factual without making legal claims. Use "likely exempt" not "exempt." Direct researchers to their institutional IRB for determination.

#### Scenario: IRB section is legally sound
- **WHEN** a researcher reads the IRB section
- **THEN** it SHALL reference 45 CFR 46.104(d)(4) as context
- **AND** it SHALL NOT claim IRB exemption — only describe the data characteristics that typically qualify

### Requirement: pilot-partnership-pathway
The document SHALL describe how a researcher partners with a deploying CoC for a study, without prescribing the study design.

#### Scenario: Researcher understands partnership pathway
- **WHEN** they read the pilot partnership section
- **THEN** they SHALL understand the steps: identify a CoC, obtain analytics access via CoC admin, IRB determination, DV committee review if applicable, data export via dashboard/API

### Requirement: pii-free-text-warning
The document SHALL warn that free-text fields (bed_availability.notes, reservation.notes, referral_token.special_needs, referral_token.rejection_reason) may contain inadvertent PII despite the platform's zero-PII design intent.

#### Scenario: Researcher understands free-text risk
- **WHEN** a researcher plans to use free-text fields
- **THEN** they SHALL understand that content review is required before research use
- **AND** the document SHALL recommend excluding free-text fields from studies that don't require them

## MODIFIED Requirements

### Requirement: readme-who-its-for
The README.md "Who It's For" table SHALL include a fifth row for researchers and evaluators linking to FOR-RESEARCHERS.md.

#### Scenario: Researcher finds front door
- **GIVEN** a researcher visits the GitHub repository
- **WHEN** they read the README
- **THEN** they SHALL see a row: "Researcher or evaluator → For Researchers — data inventory, access tiers, IRB guidance"

### Requirement: landing-page-researcher-audience
The findabed.org landing page SHALL include a researcher audience card linking to the FOR-RESEARCHERS content.

#### Scenario: SEO-discoverable researcher page
- **WHEN** a researcher searches for "emergency shelter bed availability data open source"
- **THEN** the findabed.org researcher page SHALL be indexable by search engines
- **AND** the page SHALL include schema.org Dataset structured data markup
