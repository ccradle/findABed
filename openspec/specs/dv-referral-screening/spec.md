## Purpose

DV shelter screening interface, warm-handoff flow, search integration, and aggregate analytics — all designed to prevent PII leakage.

## ADDED Requirements

### Requirement: safety-screening-ui
The system SHALL provide a screening interface for DV shelter staff to review referral details and accept or reject. The screening view displays only operational data — never client PII.

#### Scenario: Screening view shows operational data only
- **WHEN** DV shelter staff opens a pending referral
- **THEN** they see: household size, population type, urgency level, special needs, referring worker's callback number, time remaining until expiry
- **AND** they do NOT see: client name, DOB, SSN, address, phone number, or any PII

#### Scenario: Accept requires no additional input
- **WHEN** staff clicks "Accept"
- **THEN** the token transitions to ACCEPTED immediately
- **AND** the referring worker is notified with the shelter's intake phone number

#### Scenario: Reject requires a reason
- **WHEN** staff clicks "Reject"
- **THEN** a reason field is required (free text, e.g., "no capacity for pets", "safety concern")
- **AND** the reason must NOT contain client PII (advisory label shown)
- **AND** the token transitions to REJECTED

#### Scenario: Expired tokens cannot be accepted or rejected
- **WHEN** a referral token has expired
- **THEN** the Accept and Reject buttons are disabled
- **AND** the token shows "Expired" status

### Requirement: warm-handoff-flow
The system SHALL facilitate a warm handoff phone call between the referring worker and DV shelter intake staff. The shelter's physical address is never displayed in the system.

#### Scenario: Accepted referral shows callback instructions
- **WHEN** a referral is accepted
- **THEN** the referring worker sees: "Referral accepted. Call shelter intake at [phone number] to arrange arrival."
- **AND** the shelter phone number comes from `shelter.phone` (already RLS-protected)
- **AND** no shelter address is displayed

#### Scenario: Shelter address never exposed to referring worker
- **WHEN** a referral is accepted and the worker views the confirmation
- **THEN** the response body does NOT contain `addressStreet`, `addressCity`, `latitude`, or `longitude`
- **AND** the shelter is identified only by a display name (e.g., "DV Shelter A")

### Requirement: dv-search-referral-integration
The system SHALL replace the "Hold This Bed" button with "Request Referral" for DV shelter results in bed search.

#### Scenario: DV shelter search result shows referral button
- **WHEN** an outreach worker with `dvAccess=true` searches for beds
- **AND** a DV shelter appears in the results
- **THEN** the result shows "Request Referral" instead of "Hold This Bed"

#### Scenario: Non-DV shelter results are unchanged
- **WHEN** a search result is for a non-DV shelter
- **THEN** the result shows the standard "Hold This Bed" button as before

### Requirement: aggregate-analytics
The system SHALL provide aggregate DV referral analytics backed by Micrometer counters, not by querying purged token data.

#### Scenario: Analytics endpoint returns counts only
- **WHEN** an admin queries `GET /api/v1/analytics/dv-referrals?from=2026-03-01&to=2026-03-31`
- **THEN** the response contains: requested, accepted, rejected, expired counts and average response time
- **AND** no PII or individual referral details are included

#### Scenario: Counters survive token purge (with observability stack)
- **WHEN** referral tokens are hard-deleted by the purge service
- **AND** the observability stack is active (Prometheus scraping)
- **THEN** Prometheus retains counter history and the analytics endpoint returns correct aggregates
- **NOTE** Without the observability stack, in-memory counters reset on backend restart — this is a documented limitation (D13)
