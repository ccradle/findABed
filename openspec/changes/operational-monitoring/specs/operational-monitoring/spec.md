## ADDED Requirements

### Requirement: stale-shelter-monitor
The system SHALL detect shelters that have not published an availability snapshot in more than 8 hours via an in-app @Scheduled task. The monitor publishes a `fabt.shelter.stale.count` Micrometer gauge and logs WARNING-level structured JSON for each stale shelter. No external dependencies required (no CloudWatch, no Lambda).

#### Scenario: Stale shelter detected
- **WHEN** the scheduled monitor runs and finds a shelter with no snapshot in 8+ hours
- **THEN** the `fabt.shelter.stale.count` gauge reflects the count
- **AND** a WARNING-level structured log entry is emitted with shelter ID and last update time

### Requirement: dv-canary-monitor
The system SHALL run a periodic DV canary check that queries the bed search API as a non-DV user and asserts zero DV shelters appear. The monitor publishes a `fabt.dv.canary.pass` Micrometer gauge (1=pass, 0=fail) and logs CRITICAL-level on failure.

#### Scenario: DV canary passes
- **WHEN** the scheduled canary queries POST /api/v1/queries/beds as a non-DV user
- **THEN** no DV shelter appears in results and `fabt.dv.canary.pass` is 1

#### Scenario: DV canary fails
- **WHEN** a DV shelter appears in the canary query results
- **THEN** `fabt.dv.canary.pass` is 0 and a CRITICAL-level log is emitted

### Requirement: temperature-surge-gap-monitor
The system SHALL detect when ambient temperature at the pilot city drops below 32°F and no active surge event exists. Uses NOAA API with Resilience4J circuit breaker. Logs WARNING on mismatch.

#### Scenario: Cold weather without surge
- **WHEN** NOAA reports temperature below 32°F and no active surge exists
- **THEN** a WARNING-level log is emitted suggesting surge activation

### Requirement: operational-runbook
An operational runbook (`docs/runbook.md`) SHALL document all monitor types, what they mean, how to investigate, and what action to take.

#### Scenario: Runbook covers all monitors
- **WHEN** an operator sees a stale-data, dv-canary, or temperature-surge log entry
- **THEN** the runbook provides investigation and response procedures
