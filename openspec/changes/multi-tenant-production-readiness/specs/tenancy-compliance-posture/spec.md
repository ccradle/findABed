## ADDED Requirements

### Requirement: tenancy-model-adr
The project SHALL publish `docs/architecture/tenancy-model.md` as the tenancy-model ADR (per H1) documenting pool-by-default + silo-on-trigger. Trigger criteria SHALL include (a) HIPAA BAA request, (b) VAWA-exposed DV CoC, (c) data-residency requirement, (d) procurement request. Schema-per-tenant SHALL be documented as a non-scope with an upgrade-path note for the regulated tier.

#### Scenario: ADR documents pool-by-default decision
- **GIVEN** `docs/architecture/tenancy-model.md` is published
- **WHEN** an operator reads it
- **THEN** the document states pool-by-default for the discriminator + RLS hybrid architecture
- **AND** lists the four trigger criteria for the silo path

#### Scenario: ADR documents non-scope
- **WHEN** the same document is read
- **THEN** schema-per-tenant and DB-per-tenant are documented as non-scope
- **AND** the upgrade path for regulated tier is referenced (separate deploy)

### Requirement: hipaa-baa-template-and-registry
The project SHALL publish `docs/legal/baa-template.md` (HIPAA BAA template) and `docs/legal/per-tenant-baa-registry.md` (per-tenant BAA registry, per H2). The template SHALL include a data-flow diagram, encryption-in-transit attestation, encryption-at-rest attestation with DEK scope, access-log retention commitment, and breach-notification SLA.

#### Scenario: BAA template references DEK scope
- **WHEN** Casey reviews `baa-template.md`
- **THEN** the encryption-at-rest attestation names the per-tenant DEK (A3) as the isolation primitive
- **AND** the document cites the crypto-shred procedure (F6) as the deletion guarantee

#### Scenario: Registry tracks per-tenant execution
- **WHEN** a regulated-tier tenant signs a BAA
- **THEN** the registry is updated with the tenant UUID, executed date, breach-SLA override if any, and signatory
- **AND** the registry is source of truth for platform-admin-facing compliance state

### Requirement: vawa-24-hour-ovw-breach-pipeline
The project SHALL publish `docs/security/vawa-breach-runbook.md` (per H3) with a detection path (alert → classification → OVW notification draft) and a pre-filled OVW notification template. The pipeline SHALL integrate with G5 per-tenant alerting to meet the 24-hour reporting window for VAWA-funded grantees.

#### Scenario: Runbook describes 24-hour pipeline
- **GIVEN** the runbook is published
- **WHEN** a breach is classified as DV / VAWA-covered
- **THEN** the runbook's step sequence from alert to OVW notification draft fits within 24 hours
- **AND** the pre-filled template requires only incident-specific fields to be populated

#### Scenario: Per-tenant alert triggers VAWA classification
- **GIVEN** a breach-indicator metric fires with `tenant_id=<dv-tenant>`
- **WHEN** the G5 routing delivers the alert
- **THEN** the runbook's decision tree routes to the VAWA pipeline
- **AND** platform on-call is paged alongside the tenant on-call

### Requirement: vawa-comparable-database-architecture
The project SHALL publish a VAWA "Comparable Database" architecture document (per H4) describing the per-tenant encryption posture that prevents platform operators from reading DV survivor PII without audited unseal. The document SHALL align with `feedback_rls_hides_dv_data.md`'s `fabt` vs `fabt_app` role distinction.

#### Scenario: Document describes primary + secondary control
- **WHEN** Casey reviews the Comparable Database doc
- **THEN** the primary control is documented as per-tenant DEK encryption-at-rest (A3)
- **AND** the secondary control is `platform_admin_access_log` (G3) for audited reads
- **AND** the SLA to DV CoCs is stated

#### Scenario: Operator cannot read DV PII without audit
- **GIVEN** a platform admin attempts to read a DV tenant's PII
- **WHEN** the access is routed through `@PlatformAdminOnly` with justification
- **THEN** the access is logged to `platform_admin_access_log` and PII decrypt requires the per-tenant DEK
- **AND** unauthorized attempts fail both controls

### Requirement: dv-safe-breach-notification-protocol
The project SHALL publish `docs/legal/dv-safe-breach-notification.md` (per H5) describing survivor notification ONLY through survivor-declared safe channels, with an explicit escalation procedure when the safe channel is unavailable. Email to a shared household inbox SHALL NOT be the default.

#### Scenario: Safe channel first, documented escalation second
- **GIVEN** a survivor has declared a safe channel (e.g., sms to a specific number)
- **WHEN** a breach notification must reach them
- **THEN** the protocol tries the safe channel first
- **AND** if unavailable, escalates to the documented fallback (e.g., notify the DV advocate at the agency)

#### Scenario: Household email blocked as default
- **GIVEN** a tenant has survivor contact info that includes a shared household email
- **WHEN** the breach notifier prepares the message
- **THEN** the household email is NOT used unless explicitly authorized by the survivor
- **AND** the runbook documents this as a potentially-lethal defect to avoid

### Requirement: breach-notification-contacts-table
The system SHALL maintain a `breach_notification_contacts` per-tenant table (per H6) with tenant legal, technical, and on-call recipients + acknowledgment SLA. A tabletop exercise at release SHALL validate the notification flow.

#### Scenario: Table rows per tenant
- **WHEN** a regulated-tier tenant onboards
- **THEN** `breach_notification_contacts` is populated with at least legal, technical, and on-call rows
- **AND** each row has a target address and SLA for acknowledgment

#### Scenario: Tabletop exercise validates flow
- **GIVEN** the release cycle includes a tabletop exercise
- **WHEN** a simulated breach notification runs
- **THEN** each contact row receives the expected message
- **AND** the acknowledgment SLA timing is measured and recorded

### Requirement: data-custody-and-retention-matrix
The project SHALL publish `docs/legal/data-custody-matrix.md` (per H7) with per data class (DV referral, shelter ops, analytics, audit) × per column (custodian, breach-recipient, retention-window, deletion-trigger, export-format, residency-pin). Audit-log retention conflict (HIPAA 6-year vs GDPR erasure) SHALL be resolved case-by-case.

#### Scenario: Matrix covers every data class
- **WHEN** Casey reviews the matrix
- **THEN** DV referral, shelter ops, analytics, and audit data classes each have a complete row
- **AND** columns include retention-window, deletion-trigger, and residency-pin

#### Scenario: HIPAA vs GDPR conflict resolution documented
- **WHEN** the auditor asks how the 6-year HIPAA retention conflicts with the 30-day GDPR erasure
- **THEN** the matrix documents the per-class resolution (e.g., HIPAA-required audit logs retained with justification; non-HIPAA-required rows purged)
- **AND** the resolution aligns with F6 crypto-shred posture

### Requirement: contract-clause-template-library
The project SHALL publish a contract clause template library (per H8) of per-tenant MSA / SLA addenda covering isolation mechanism, breach-SLA, retention, exit procedure, and custody. Casey SHALL own the artifact.

#### Scenario: Library covers core clauses
- **GIVEN** `docs/legal/contract-clauses/` is published
- **WHEN** Casey reviews the library
- **THEN** each core clause category has a template (isolation, breach-SLA, retention, exit, custody)
- **AND** each template is parameterized for per-tenant tier

#### Scenario: Procurement uses templates to assemble tenant-specific addenda
- **WHEN** a prospective CoC requests an SLA addendum
- **THEN** Casey assembles from the templates in hours rather than weeks
- **AND** the assembled document is referenced from the per-tenant BAA registry when applicable

### Requirement: right-to-be-forgotten-procedure
The project SHALL document and test (per H9) a right-to-be-forgotten per-user procedure: DELETE order across `app_user`, `audit_events` (per H7 resolution), `one_time_access_code`, `password_reset_token`, `user_oauth2_link`, `totp_recovery`, `coordinator_assignment`, `referral_token` (historical terminal states). Regression test SHALL verify erasure is complete.

#### Scenario: DELETE cascades cover every referenced table
- **WHEN** a user's right-to-be-forgotten is invoked
- **THEN** the documented DELETE order runs across all enumerated tables
- **AND** a post-delete query confirms zero rows remain referencing the user's UUID

#### Scenario: Audit retention is the only deliberate exception
- **GIVEN** the H7 matrix documents audit retention for a HIPAA-covered tenant
- **WHEN** the erasure runs for that tenant
- **THEN** audit_events rows for the user may be retained per the matrix (justification documented)
- **AND** the retention is cited in the response to the user's request

#### Scenario: Regression test verifies erasure
- **WHEN** the `RightToBeForgottenTest` integration test runs
- **THEN** a synthetic user is erased and every table is queried post-erasure
- **AND** any leaked row fails the test

### Requirement: children-ferpa-carve-out
The project SHALL publish `docs/legal/children-data.md` (per H10) acknowledging that FABT does not currently serve unaccompanied-youth CoCs directly. If such a tenant onboards, FERPA obligations attach differently and SHALL trigger a separate compliance review.

#### Scenario: Document acknowledges the carve-out
- **WHEN** an operator reads `children-data.md`
- **THEN** the document states the current non-scope (unaccompanied-youth CoCs)
- **AND** specifies that FERPA obligations require a separate compliance review before onboarding

#### Scenario: Onboarding check blocks unaccompanied-youth tenant without review
- **GIVEN** a prospective tenant self-identifies as serving unaccompanied youth
- **WHEN** the onboarding runbook runs
- **THEN** the operator is prompted for the FERPA review completion artifact
- **AND** onboarding is blocked until the artifact is attached

### Requirement: legal-language-scan-in-code-comments
The project SHALL run a legal-language scan (per H11) for "compliant", "equivalent", "guarantees" (and related overclaim phrasing) in Javadoc and code comments added by this change. The scan SHALL be a CI gate.

#### Scenario: Scan fails on overclaim phrasing in Javadoc
- **GIVEN** a developer adds `/** HIPAA-compliant encryption service */` to a Javadoc block
- **WHEN** the CI legal-language scan runs
- **THEN** the scan fails with a message identifying the file, line, and offending phrase
- **AND** points to the remediation: use "designed to support" phrasing per `feedback_legal_claims_review.md`

#### Scenario: Scan passes on restrained phrasing
- **GIVEN** the Javadoc says `/** Designed to support HIPAA encryption-at-rest requirements */`
- **WHEN** the CI scan runs
- **THEN** the build passes
- **AND** no false positives trigger on neutral phrasing
