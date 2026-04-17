## ADDED Requirements

### Requirement: tenant-quarantine-break-glass
The system SHALL provide an atomic tenant-quarantine break-glass command (per K1) as both a CLI action and an admin UI action. The command SHALL perform 5 actions atomically: (a) bump `jwt_key_generation` (A2), (b) disable all API keys, (c) block inbound webhooks, (d) freeze writes (reads preserved), (e) audit the action. The command SHALL be E2E-tested.

#### Scenario: Break-glass quarantines tenant in one call
- **GIVEN** tenant A is `ACTIVE` and an operator discovers a suspected breach
- **WHEN** the operator runs `fabt-admin quarantine --tenant <tenantA> --justification "suspected compromise of pilot-admin creds"`
- **THEN** all five actions execute atomically
- **AND** the tenant's state becomes `SUSPENDED`
- **AND** an `audit_events` row + `platform_admin_access_log` row record the quarantine action
- **AND** existing JWTs for tenant A begin failing validation within seconds

#### Scenario: Reads preserved during quarantine
- **GIVEN** tenant A has been quarantined
- **WHEN** a platform admin reads tenant A's data for forensic inspection
- **THEN** read queries succeed (reads preserved per F4)
- **AND** write attempts fail with 503 Service Unavailable

#### Scenario: Missing justification rejected
- **WHEN** the operator invokes quarantine without a non-empty justification
- **THEN** the command errors out with an explicit message requiring justification
- **AND** no partial state change occurs

#### Scenario: E2E test validates the 5-action flow
- **GIVEN** an integration test seeds tenant A with JWTs, API keys, in-flight webhooks, and write traffic
- **WHEN** the test invokes the quarantine command
- **THEN** it asserts all five actions took effect (JWTs invalidated, API keys disabled, webhooks blocked, writes 503, audit row present)
- **AND** the test fails if any action is partial or missing

### Requirement: forensic-query-tooling
The project SHALL publish forensic query tooling (per K2) — pre-built SQL + Grafana panel — answering the primary IR question: "given a user / token / IP / timestamp, list every row read + written across every tenant." This SHALL be the primary incident-response tool.

#### Scenario: Pre-built SQL answers "user activity across tenants"
- **GIVEN** the forensic SQL at `docs/security/forensic-queries/user-activity.sql` is published
- **WHEN** an operator runs it with `:user_uuid` and `:timestamp_range` parameters
- **THEN** the output enumerates every `audit_events` and `platform_admin_access_log` entry matching the user within the range
- **AND** the output includes tenant_id per row for cross-tenant correlation

#### Scenario: Grafana panel provides point-in-time forensic view
- **GIVEN** the forensic Grafana panel is provisioned
- **WHEN** an operator enters a token UUID or actor UUID in the template variables
- **THEN** the panel renders activity timeline across tenants
- **AND** the panel links back to the raw SQL for deeper inspection

#### Scenario: Tooling accessible to incident commander only
- **GIVEN** the forensic queries require platform-admin credentials
- **WHEN** a non-admin attempts to open the Grafana panel or run the SQL
- **THEN** access is denied at the query/panel layer
- **AND** attempts are logged per G3 `platform_admin_access_log`

### Requirement: ir-runbooks-per-breach-class
The project SHALL publish `docs/security/ir-runbooks/` (per K3) with runbooks per breach class: (a) suspected cross-tenant read, (b) stolen credential, (c) vendor / infra compromise, (d) DV-specific breach (integrates VAWA pipeline per H3).

#### Scenario: Suspected cross-tenant read runbook exists
- **GIVEN** `docs/security/ir-runbooks/cross-tenant-read.md` is published
- **WHEN** an operator opens it in response to an alert
- **THEN** the runbook's first step is to run the forensic query tooling (K2) against the suspected actor
- **AND** the subsequent steps cover containment, notification, and post-mortem

#### Scenario: Stolen credential runbook exists
- **GIVEN** `docs/security/ir-runbooks/stolen-credential.md` is published
- **WHEN** an operator follows it
- **THEN** it walks through credential revocation, user notification, and forensic review
- **AND** cites K1 quarantine as the escalation path if blast-radius is tenant-wide

#### Scenario: DV-specific runbook routes to VAWA pipeline
- **GIVEN** `docs/security/ir-runbooks/dv-breach.md` is published
- **WHEN** an operator follows it
- **THEN** the first escalation is to the H3 VAWA 24-hour OVW pipeline
- **AND** survivor notification uses the H5 DV-safe protocol

#### Scenario: Vendor/infra compromise runbook exists
- **GIVEN** `docs/security/ir-runbooks/vendor-infra-compromise.md` is published
- **WHEN** an operator opens it
- **THEN** it documents tenant-by-tenant impact assessment, rotation of shared secrets, and external-dependency review
- **AND** the master KEK rotation runbook (L10) is linked for the cryptographic dependency scenario
