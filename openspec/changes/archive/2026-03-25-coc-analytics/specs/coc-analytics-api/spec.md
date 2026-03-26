## ADDED Requirements

### Requirement: aggregate-analytics-api
The system SHALL provide REST API endpoints for querying aggregate bed availability analytics. All endpoints return aggregate data with no client PII.

#### Scenario: Utilization rates over time
- **WHEN** an admin queries `GET /api/v1/analytics/utilization?from=2026-01-01&to=2026-03-31`
- **THEN** the response contains daily/weekly utilization rates (beds_occupied / beds_total) per population type

#### Scenario: Demand signals from reservations
- **WHEN** an admin queries `GET /api/v1/analytics/demand`
- **THEN** the response contains reservation conversion rate, expiry rate, zero-result search count, and average hold-to-confirmation time

#### Scenario: System capacity trends
- **WHEN** an admin queries `GET /api/v1/analytics/capacity`
- **THEN** the response shows total system beds over time with add/remove deltas

#### Scenario: DV summary with minimum cell size
- **WHEN** an admin queries `GET /api/v1/analytics/dv-summary`
- **THEN** DV shelter data is aggregated across all DV shelters
- **AND** any metric representing fewer than 5 beds is suppressed
- **AND** if fewer than 3 distinct DV shelters exist, the entire summary is suppressed with reason "Insufficient DV shelters for safe aggregation"

#### Scenario: DV summary suppressed for single-shelter CoC
- **WHEN** a CoC has only 1 DV shelter with 20 beds
- **AND** an admin queries `GET /api/v1/analytics/dv-summary`
- **THEN** the response contains `suppressed: true` and no bed counts
- **AND** the reason indicates insufficient DV shelter count for safe aggregation

#### Scenario: Geographic data excludes DV shelters
- **WHEN** an admin queries `GET /api/v1/analytics/geographic`
- **THEN** the response includes shelter locations with utilization
- **AND** DV shelters are excluded from the location list

#### Scenario: HMIS health from audit log
- **WHEN** an admin queries `GET /api/v1/analytics/hmis-health`
- **THEN** the response shows push success/failure rates and last push timestamp per vendor

#### Scenario: Outreach worker cannot access analytics
- **WHEN** an OUTREACH_WORKER queries any analytics endpoint
- **THEN** the API returns 403
