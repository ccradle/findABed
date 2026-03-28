## ADDED Requirements

### Requirement: Screenshot-narrative alignment

The demo seed data SHALL produce screenshots that visually match every narrative caption in the walkthrough pages. Each caption's specific claims (shelter count, freshness color, constraint flags, analytics numbers) SHALL be verifiable by visual inspection of the corresponding screenshot.

#### Scenario: Family bed search returns exactly three results

- **WHEN** an outreach worker without dvAccess searches for FAMILY_WITH_CHILDREN beds
- **THEN** exactly 3 shelters appear in results, all with green freshness badges (updated < 1 hour)

#### Scenario: First family shelter shows pets and wheelchair

- **WHEN** the outreach worker taps the first family shelter result
- **THEN** the detail view shows pets_allowed=true, wheelchair_accessible=true, and freshness ~12 minutes

#### Scenario: Analytics shows target utilization and zero-result count

- **WHEN** a CoC administrator opens the analytics executive summary
- **THEN** system utilization is near 78% and zero-result searches show approximately 47 for the prior week

#### Scenario: Analytics utilization trend is climbing

- **WHEN** a CoC administrator views the utilization trends chart
- **THEN** the trend line shows steady increase over the displayed period (not flat or random)

#### Scenario: DV shelter supports family referral narrative

- **WHEN** a DV-authorized user searches for beds
- **THEN** the DV shelter shows both DV_SURVIVOR and FAMILY_WITH_CHILDREN population types with beds available

### Requirement: Walkthrough structure follows story-first pattern

The demo walkthrough SHALL lead with the core user story (bed search through placement), not with authentication. The login screen SHALL NOT be the first screenshot.

#### Scenario: First screenshot is the bed search

- **WHEN** a visitor opens the platform walkthrough (demo/index.html)
- **THEN** the first screenshot card shows the bed search interface, not the login page

#### Scenario: Core story is self-contained in first 8 cards

- **WHEN** a visitor views only the first 8 screenshot cards
- **THEN** they see the complete Darius workflow: search → results → detail → hold → coordinator → update → i18n → security

#### Scenario: Walkthrough ends with trust section

- **WHEN** a visitor scrolls to the end of the walkthrough
- **THEN** they see a closing section with WCAG compliance, DV privacy design, Apache 2.0 license, and deployment tiers

#### Scenario: Audience-specific CTAs are present

- **WHEN** a visitor reaches the end of the walkthrough
- **THEN** they see at least 3 distinct call-to-action paths: for funders, for city officials, and for implementers

### Requirement: Person-first language throughout

All documentation SHALL use person-first language when referring to people experiencing homelessness. "The homeless," "homeless individuals," "homeless families," and "homeless person" SHALL NOT appear in any committed documentation.

#### Scenario: Grep finds zero instances of non-person-first language

- **WHEN** a grep is run across both repos for "homeless individuals|homeless families|the homeless|homeless person"
- **THEN** zero matches are found in committed .md and .html files

### Requirement: Cost savings quantified for funders

The FOR-FUNDERS.md document SHALL include specific, sourced cost savings data to support funding conversations.

#### Scenario: Funders page cites emergency services cost savings

- **WHEN** a funder reads FOR-FUNDERS.md
- **THEN** they see a specific dollar amount with source attribution (Funders Together to End Homelessness data)

### Requirement: Seed data timestamps follow day-in-the-life timeline

Seed data availability snapshots SHALL follow a coherent temporal narrative — timestamps reflect a realistic evening where Sandra updates beds and Darius searches for placement.

#### Scenario: Freshness badges are green for family shelters

- **WHEN** the demo stack starts with seed data
- **THEN** all 3 FAMILY_WITH_CHILDREN shelters have snapshots less than 45 minutes old (green freshness badges)

#### Scenario: Crabtree Valley shows 12-minute freshness

- **WHEN** the outreach worker views Crabtree Valley Family Haven detail
- **THEN** the freshness indicator shows approximately 12 minutes (matching caption "updated 12 minutes ago")
