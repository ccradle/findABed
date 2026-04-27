## MODIFIED Requirements

### Requirement: escalation-recipient-role-validation
The system SHALL validate recipient roles on escalation policy PATCH operations against the role allowlist `{COORDINATOR, COC_ADMIN, OUTREACH_WORKER}`. (Previously the allowlist included `PLATFORM_ADMIN`. PLATFORM_ADMIN is deprecated; escalation policies SHALL NOT route to platform operators because platform operators are not part of any tenant's escalation chain by design.)

#### Scenario: Validation rejects invalid roles in recipients
- **WHEN** the PATCH body contains a recipient role not in `{COORDINATOR, COC_ADMIN, OUTREACH_WORKER}`
- **THEN** the system SHALL return `400 Bad Request`
- **AND** the error body includes `{"error":"validation_failed","field":"recipients[*].role","rejected_value":"<role>"}`

#### Scenario: Validation rejects PLATFORM_ADMIN as recipient
- **WHEN** the PATCH body contains `recipients[*].role = "PLATFORM_ADMIN"`
- **THEN** the system SHALL return `400 Bad Request`
- **AND** the error message includes "PLATFORM_ADMIN is deprecated; escalation policies cannot route to platform operators"

#### Scenario: Validation rejects PLATFORM_OPERATOR as recipient
- **WHEN** the PATCH body contains `recipients[*].role = "PLATFORM_OPERATOR"`
- **THEN** the system SHALL return `400 Bad Request`
- **AND** the error message includes "Escalation policies are tenant-scoped; platform operators are not in tenant escalation chains"

#### Scenario: Validation rejects invalid severity
- **WHEN** the PATCH body contains a severity not in `{INFO, ACTION_REQUIRED, CRITICAL}`
- **THEN** the system SHALL return `400 Bad Request`
