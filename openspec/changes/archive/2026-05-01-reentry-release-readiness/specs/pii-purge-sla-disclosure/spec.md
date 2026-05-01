## ADDED Requirements

### Requirement: Compliance posture matrix documents hold-attribution PII
`docs/security/compliance-posture-matrix.md` SHALL contain a section that names the v0.55 hold-attribution PII columns, the encryption envelope (per-tenant DEK, purpose `RESERVATION_PII`), and the 24-hour purge contract.

#### Scenario: Hold-attribution PII section exists
- **WHEN** the matrix is read post-change
- **THEN** a section SHALL exist with a heading containing "Hold-attribution PII" or equivalent
- **AND** the section SHALL name the encrypted columns `held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `hold_notes_encrypted`
- **AND** the section SHALL state the purge SLA is "no later than 25 hours after terminal status" (per design D10 — affirmative bound; the operational floor with the 15-min cadence is 24h15m)

#### Scenario: Section names what survives the purge
- **WHEN** the section is read
- **THEN** it SHALL state explicitly that the reservation row itself is preserved post-purge (sans ciphertext) so that aggregate analytics are preserved
- **AND** that auditing-relevant metadata (who placed the hold, when, for which shelter) survives the purge
- **AND** the section SHALL state that hold-attribution PII is NEVER published to HMIS, AsyncAPI, or any external system; it is server-side encrypted only

### Requirement: Compliance posture matrix honestly discloses operational gap
The compliance posture matrix's purge-SLA documentation SHALL explicitly disclose, in v0.55, that no Prometheus metric and no alert is yet wired for the purge job's success/failure signal — and that this is a known gap to be closed in a follow-up slice. Honest disclosure is required because the public claim ("purged in 24h") is otherwise contractually stronger than the operational evidence.

#### Scenario: Metric/alert gap disclosed
- **WHEN** the relevant matrix row is read post-change
- **THEN** it SHALL contain a sentence stating that the metric (e.g., `fabt.reservation.pii_purge.success.count`) and the failure alert are not yet wired in v0.55
- **AND** the sentence SHALL identify the gap as a v0.56 work item with a target quarter (Q2-2026), not as evidence of platform failure
- **AND** parallel sentences SHALL disclose the deferred companion docs (`docs/security/dek-rotation-policy.md`, `docs/security/threat-model.md`, `docs/security/zap-v0.55-baseline.md`) with their target quarters (Q2-2026 each), so the matrix is internally consistent about scope deferrals

#### Scenario: Operator log-parse fallback documented
- **WHEN** the section is read
- **THEN** it SHALL describe the alternative signal an operator can use today (server-side log parsing for the purge job's `INFO`-level success line) so the gap is mitigated even before the metric ships

### Requirement: v0.55 runbook includes PII purge verification section
`docs/oracle-update-notes-v0.55.0.md` SHALL contain a §6.5 section instructing the operator how to verify, post-deploy, that the purge job is registered and that a sample row honored the 24-hour SLA — and acknowledging that no failure metric exists yet.

#### Scenario: Section §6.5 exists
- **WHEN** the runbook is read post-change
- **THEN** it SHALL contain a section titled "PII purge verification" or equivalent
- **AND** the section SHALL provide at least one operator command that confirms the `@Scheduled` purge job is registered in the running backend
- **AND** the section SHALL provide at least one SQL or container command that confirms a purged row's ciphertext columns are NULL after expected SLA window

#### Scenario: Section acknowledges the metric gap
- **WHEN** the runbook section is read
- **THEN** it SHALL state explicitly that no failure metric is yet wired and that operators should manually verify until the follow-up ships

### Requirement: CHANGELOG calls out PII collection as a privacy-relevant capability change
`CHANGELOG.md` v0.55 entry SHALL contain a Privacy/Security subsection (or equivalent) so that PII collection is not buried in a "Added" feature bullet.

#### Scenario: Privacy/Security subsection exists in v0.55 entry
- **WHEN** `CHANGELOG.md` is read post-change
- **THEN** the v0.55 entry SHALL contain a subsection (with a `###` heading) named "Privacy / Security" or equivalent
- **AND** the subsection SHALL describe: the opt-in PII collection capability, the per-tenant DEK encryption envelope, the 24h purge contract, and a pointer to `docs/government-adoption-guide.md` and `docs/hospital-privacy-summary.md` for operators reviewing before exposing the new capability
