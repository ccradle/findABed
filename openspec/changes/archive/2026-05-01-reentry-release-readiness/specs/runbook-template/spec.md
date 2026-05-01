## ADDED Requirements

### Requirement: Per-version runbook includes verification for any operationally-claimed retention SLA
When a release introduces or modifies an operationally-claimed retention SLA (e.g., the 24h hold-attribution PII purge in v0.55), the per-version runbook (`docs/oracle-update-notes-vX.Y.Z.md`) SHALL include a post-deploy verification section that gives the operator at least one command to confirm the SLA mechanism is registered AND one command to confirm a sample row honored the SLA in practice.

#### Scenario: v0.55 runbook includes purge SLA verification
- **WHEN** `docs/oracle-update-notes-v0.55.0.md` is read post-change
- **THEN** it SHALL contain a section verifying the 24h purge job
- **AND** the section SHALL provide an operator command that confirms the `@Scheduled` purge bean is registered in the running backend
- **AND** the section SHALL provide a SQL or container command that confirms a purged row's `_encrypted` columns are NULL beyond the SLA window

#### Scenario: Section honestly discloses metric/alert state
- **WHEN** the verification section is read
- **THEN** it SHALL state whether a Prometheus metric exists for the SLA's success/failure signal
- **AND** if no metric exists, it SHALL describe the manual or log-based alternative an operator should use until the metric ships
