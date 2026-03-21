## ADDED Requirements

### Requirement: stale-shelter-monitor
The system SHALL detect shelters that have not published an availability snapshot in more than 8 hours and alert the onboarding team via CloudWatch alarm + SNS (non-paging, business hours).

#### Scenario: Stale shelter triggers alarm
- **WHEN** an active shelter has no availability snapshot with snapshot_ts within the last 8 hours
- **THEN** a custom CloudWatch metric `fabt/shelter_stale_count` increments
- **AND** when the metric exceeds 0, the CloudWatch alarm transitions to ALARM state
- **AND** an SNS notification is sent to the onboarding team

### Requirement: dv-canary-monitor
The system SHALL run a post-deploy Lambda canary that asserts zero DV shelters appear in public query results. Failure triggers a PAGING CloudWatch alarm immediately.

#### Scenario: DV canary passes
- **WHEN** the Lambda queries POST `/api/v1/queries/beds` as a non-DV user
- **THEN** no shelter with `dv_shelter = true` appears in results
- **AND** the canary publishes `fabt/dv_canary_pass = 1` metric

#### Scenario: DV canary fails
- **WHEN** a DV shelter appears in public query results
- **THEN** the canary publishes `fabt/dv_canary_pass = 0` metric
- **AND** the CloudWatch alarm transitions to ALARM state immediately
- **AND** a PAGING notification is sent via SNS

### Requirement: temperature-surge-gap-monitor
The system SHALL detect when ambient temperature at the pilot city drops below 32F and no active surge event exists. Alert via SNS (non-paging, hourly check). This monitor is stubbed until `surge-mode` is implemented.

#### Scenario: Cold weather without surge triggers alert
- **WHEN** NOAA API reports temperature below 32F for the pilot city
- **AND** no active surge event exists in the database
- **THEN** an SNS notification is sent to the CoC admin contact

#### Scenario: Cold weather with active surge does not trigger
- **WHEN** NOAA API reports temperature below 32F
- **AND** an active surge event exists
- **THEN** no alert is sent

### Requirement: alb-access-logging
The ALB SHALL log all access requests to an S3 bucket with 90-day lifecycle retention.

#### Scenario: ALB logs are written
- **WHEN** any request reaches the ALB
- **THEN** the request is logged to S3 with source IP, timestamp, path, status code

#### Scenario: Old logs are expired
- **WHEN** ALB log objects are older than 90 days
- **THEN** the S3 lifecycle policy automatically deletes them

### Requirement: operational-runbook
An operational runbook (`docs/runbook.md`) SHALL document all three alert types: what they mean, how to investigate, and what action to take.

#### Scenario: Runbook covers all alerts
- **WHEN** an operator receives a stale-data, dv-canary, or temperature-surge alert
- **THEN** the runbook provides step-by-step investigation and response procedures
