## MODIFIED Requirements

### Requirement: stale-shelter-monitor
The system SHALL detect shelters that have not published an availability snapshot in more than 8 hours via an in-app @Scheduled task. The monitor SHALL fan out per-tenant checks concurrently on virtual threads using semaphore-bounded fan-out, rather than iterating tenants sequentially. The monitor publishes a `fabt.shelter.stale.count` Micrometer gauge and logs WARNING-level structured JSON for each stale shelter. No external dependencies required (no CloudWatch, no Lambda).

#### Scenario: Stale shelter detected
- **WHEN** the scheduled monitor runs and finds a shelter with no snapshot in 8+ hours
- **THEN** the `fabt.shelter.stale.count` gauge reflects the count
- **AND** a WARNING-level structured log entry is emitted with shelter ID and last update time

#### Scenario: Per-tenant stale checks run concurrently
- **WHEN** the stale shelter monitor runs with 5 active tenants
- **THEN** each tenant's stale shelter query executes on its own virtual thread
- **AND** total execution time is bounded by the slowest tenant, not the sum of all tenants

### Requirement: dv-canary-monitor
The system SHALL run a periodic DV canary check that queries the bed search API as a non-DV user and asserts zero DV shelters appear. The monitor SHALL fan out per-tenant canary checks concurrently on virtual threads. The monitor publishes a `fabt.dv.canary.pass` Micrometer gauge (1=pass, 0=fail) and logs CRITICAL-level on failure.

#### Scenario: DV canary passes
- **WHEN** the scheduled canary queries POST /api/v1/queries/beds as a non-DV user
- **THEN** no DV shelter appears in results and `fabt.dv.canary.pass` is 1

#### Scenario: DV canary fails
- **WHEN** a DV shelter appears in the canary query results
- **THEN** `fabt.dv.canary.pass` is 0 and a CRITICAL-level log is emitted

#### Scenario: Per-tenant canary checks run concurrently
- **WHEN** the DV canary monitor runs with 3 active tenants
- **THEN** each tenant's canary query executes on its own virtual thread
- **AND** a slow tenant query does not delay canary checks for other tenants

### Requirement: temperature-surge-gap-monitor
The system SHALL detect when ambient temperature at the pilot city drops below a configurable threshold (default 32°F) and no active surge event exists. Default NOAA station: KRDU (Raleigh-Durham, NC). Uses NOAA API with Resilience4J circuit breaker. Logs WARNING on mismatch and publishes `fabt.temperature.surge.gap` gauge (1=gap detected, 0=no gap). Caches latest temperature reading for UI display. Temperature threshold and polling frequency configurable via tenant config JSONB and Admin UI. Per-tenant surge gap evaluation SHALL fan out concurrently on virtual threads after the shared NOAA temperature fetch.

#### Scenario: Cold weather without surge
- **WHEN** NOAA reports temperature below the configured threshold and no active surge exists
- **THEN** a WARNING-level log is emitted suggesting surge activation
- **AND** `fabt.temperature.surge.gap` gauge is set to 1

#### Scenario: Cold weather with active surge
- **WHEN** NOAA reports temperature below threshold but a surge is active
- **THEN** `fabt.temperature.surge.gap` gauge is 0 and no warning is logged

#### Scenario: Warm weather
- **WHEN** NOAA reports temperature above the configured threshold
- **THEN** `fabt.temperature.surge.gap` gauge is 0 regardless of surge state

#### Scenario: Per-tenant surge gap checks run concurrently
- **WHEN** NOAA returns a temperature below threshold and 4 tenants have different surge states
- **THEN** each tenant's surge state check executes on its own virtual thread
- **AND** total evaluation time is bounded by the slowest tenant query
