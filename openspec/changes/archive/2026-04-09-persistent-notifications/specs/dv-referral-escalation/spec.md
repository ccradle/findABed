## ADDED Requirements

### Requirement: escalation-scheduler
A `@Scheduled` job SHALL run every 5 minutes, scanning for PENDING DV referrals past escalation thresholds.

#### Scenario: 1-hour reminder to coordinator
- **GIVEN** a DV referral created 65 minutes ago, still PENDING
- **WHEN** the escalation job runs
- **THEN** an ACTION_REQUIRED notification SHALL be created for the assigned coordinator

### Requirement: escalation-coc-admin
At T+2h, a CRITICAL notification SHALL be created for the CoC admin (escalation).

#### Scenario: 2-hour escalation
- **GIVEN** a DV referral pending for 125 minutes, T+1h notification already sent
- **WHEN** the escalation job runs
- **THEN** a CRITICAL notification SHALL be created for the CoC admin

### Requirement: escalation-expiry-warning
At T+3.5h, a CRITICAL notification SHALL be sent to both coordinator and outreach worker.

#### Scenario: 30-minute expiry warning
- **GIVEN** a DV referral pending for 3 hours 35 minutes
- **WHEN** the escalation job runs
- **THEN** CRITICAL notifications SHALL be created for both the coordinator and the outreach worker

### Requirement: escalation-dedup
Each escalation threshold SHALL fire only once per referral.

#### Scenario: No duplicate escalation
- **GIVEN** the T+1h notification was already created
- **WHEN** the job runs again at 70 minutes
- **THEN** no additional T+1h notification SHALL be created

### Requirement: escalation-stops-on-action
If a referral is accepted or rejected before a threshold, no further escalations SHALL be created.

#### Scenario: Accepted referral stops escalation
- **GIVEN** a referral accepted at 55 minutes
- **WHEN** the escalation job runs at 65 minutes
- **THEN** no T+1h notification SHALL be created

### Requirement: escalation-zero-pii
Escalation notification payloads SHALL contain zero PII — only referralId, threshold, and time remaining.

#### Scenario: Escalation payload is opaque
- **WHEN** an escalation notification is created
- **THEN** the payload SHALL contain referralId and threshold label only
