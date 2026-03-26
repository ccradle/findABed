## ADDED Requirements

### Requirement: analytics-admin-dashboard
The system SHALL provide an Analytics tab in the Admin panel for COC_ADMIN and PLATFORM_ADMIN users with 7 dashboard sections.

#### Scenario: Executive summary shows system-wide metrics
- **WHEN** an admin opens the Analytics tab
- **THEN** they see total beds, occupied, available, on hold, and system utilization rate
- **AND** utilization is color-coded: green (65-90%), amber (90-105%), red (>105% or <65%)

#### Scenario: Utilization trends chart
- **WHEN** an admin views utilization trends
- **THEN** they see a time-series chart with daily/weekly/monthly toggle
- **AND** filters for population type are available

#### Scenario: Shelter performance table
- **WHEN** an admin views the shelter performance section
- **THEN** they see per-shelter utilization with RAG indicators
- **AND** DV shelters appear only as an aggregated row

#### Scenario: Demand signals section
- **WHEN** an admin views demand signals
- **THEN** they see reservation expiry rate, zero-result search count, and hold-to-confirmation time

#### Scenario: Geographic view excludes DV shelters
- **WHEN** an admin views the geographic section
- **THEN** shelter markers are shown on a map colored by utilization
- **AND** DV shelters are NOT shown on the map

#### Scenario: HIC/PIT export tools
- **WHEN** an admin clicks export in the HIC/PIT section
- **THEN** a CSV is downloaded in HUD-compatible format for the selected date

#### Scenario: Outreach worker cannot see Analytics tab
- **WHEN** an OUTREACH_WORKER navigates to the admin panel
- **THEN** the Analytics tab is not visible
