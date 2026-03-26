## ADDED Requirements

### Requirement: demo-activity-seed
The system SHALL provide a seed script that generates 28 days of realistic activity data for dev/demo environments.

#### Scenario: Utilization trends show daily variation
- **WHEN** the seed script has run and an admin views the analytics utilization trends
- **THEN** the chart shows 28 data points with visible weekday/weekend variation

#### Scenario: Demand signals show zero-result searches
- **WHEN** the seed script has run and an admin views demand analytics
- **THEN** zero-result search count is non-zero and reflects realistic unmet demand patterns

#### Scenario: Shelter performance shows varied utilization
- **WHEN** the seed script has run and an admin views shelter performance
- **THEN** at least one shelter shows high utilization (>90%) and one shows low utilization (<40%)

#### Scenario: Reservation data shows realistic conversion rates
- **WHEN** the seed script has run and an admin views demand analytics
- **THEN** reservation conversion rate is approximately 60-70% and expiry rate is approximately 10-20%

#### Scenario: Batch job history shows completed executions
- **WHEN** the seed script has run and an admin views batch jobs
- **THEN** the dailyAggregation job shows 28 completed executions with step-level detail

#### Scenario: Seed is idempotent
- **WHEN** the seed script runs a second time
- **THEN** it produces the same result without duplicating data

#### Scenario: Seed does not affect shelter configuration
- **WHEN** the seed script runs
- **THEN** the shelter table, shelter_constraints table, and existing seed availability snapshots are unchanged
