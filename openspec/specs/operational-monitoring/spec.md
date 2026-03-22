## Purpose

In-app @Scheduled operational monitors for failure mode detection (stale data, DV privacy leaks, temperature/surge gaps), with temperature status API and admin UI display.

## Requirements

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
The system SHALL detect when ambient temperature at the pilot city drops below a configurable threshold (default 32°F) and no active surge event exists. Default NOAA station: KRDU (Raleigh-Durham, NC). Uses NOAA API with Resilience4J circuit breaker. Logs WARNING on mismatch and publishes `fabt.temperature.surge.gap` gauge (1=gap detected, 0=no gap). Caches latest temperature reading for UI display. Temperature threshold and polling frequency configurable via tenant config JSONB and Admin UI.

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

### Requirement: temperature-status-api
The system SHALL expose a `GET /api/v1/monitoring/temperature` endpoint that returns the cached NOAA temperature reading, station ID, configured threshold, surge active state, gap detected state, and last check timestamp. This endpoint requires authentication (any role) and does not trigger an additional NOAA API call.

#### Scenario: Temperature status returned
- **WHEN** an authenticated user calls `GET /api/v1/monitoring/temperature`
- **THEN** the response includes `temperatureF`, `stationId`, `thresholdF`, `surgeActive`, `gapDetected`, `lastChecked`

#### Scenario: NOAA unavailable
- **WHEN** the NOAA circuit breaker is open and no cached temperature exists
- **THEN** the endpoint returns `temperatureF: null` with `lastChecked: null`

### Requirement: temperature-admin-ui-display
The Admin UI Observability tab SHALL display the current station temperature, NOAA station ID, configured threshold, and a visual warning indicator when the temperature is below threshold with no active surge. The temperature threshold and polling frequency SHALL be editable in the Admin UI.

#### Scenario: Admin sees temperature status
- **WHEN** a PLATFORM_ADMIN views the Observability tab
- **THEN** the current temperature, station ID, and threshold are displayed

#### Scenario: Warning indicator shown when gap detected
- **WHEN** the temperature is below threshold and no surge is active
- **THEN** an amber/red warning banner is displayed with the temperature, threshold, and suggestion to activate surge

#### Scenario: Admin changes temperature threshold
- **WHEN** the admin changes the threshold from 32°F to 40°F and saves
- **THEN** the config is persisted and the monitor uses the new threshold on its next check

### Requirement: operational-runbook
An operational runbook (`docs/runbook.md`) SHALL document all monitor types, what they mean, how to investigate, and what action to take.

#### Scenario: Runbook covers all monitors
- **WHEN** an operator sees a stale-data, dv-canary, or temperature-surge log entry
- **THEN** the runbook provides investigation and response procedures
