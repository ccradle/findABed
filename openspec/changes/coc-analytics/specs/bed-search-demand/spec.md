## ADDED Requirements

### Requirement: bed-search-demand-logging
The system SHALL log bed search events to track unmet demand, particularly searches returning zero results.

#### Scenario: Search with results is logged
- **WHEN** an outreach worker searches for beds and gets results
- **THEN** a `bed_search_log` entry is created with results_count > 0

#### Scenario: Search with zero results is logged
- **WHEN** an outreach worker searches for SINGLE_ADULT beds and no shelters have availability
- **THEN** a `bed_search_log` entry is created with results_count = 0
- **AND** this event contributes to the "unmet demand" analytics metric

#### Scenario: DV searches are logged without identifying the searcher
- **WHEN** a DV-access user searches for DV_SURVIVOR beds
- **THEN** the log records population_type and results_count only — no user identity

### Requirement: demand-analytics
The system SHALL compute unmet demand metrics from bed search logs and reservation lifecycle data.

#### Scenario: Zero-result search count over time
- **WHEN** an admin queries demand analytics
- **THEN** they see the count of zero-result searches per time period, broken down by population type

#### Scenario: Reservation expiry as demand proxy
- **WHEN** an admin queries demand analytics
- **THEN** they see the reservation expiry rate (expired / total) as a proxy for unmet demand
