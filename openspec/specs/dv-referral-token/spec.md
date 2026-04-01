## Purpose

Opaque referral token lifecycle for DV shelter bed requests — zero PII storage, automatic purge of terminal tokens.

## ADDED Requirements

### Requirement: referral-token-lifecycle
The system SHALL support a referral token lifecycle (PENDING → ACCEPTED/REJECTED/EXPIRED) for DV shelter bed requests. Tokens contain zero client PII. All terminal-state tokens are hard-deleted within 24 hours.

#### Scenario: Outreach worker creates referral token
- **WHEN** an outreach worker with `dvAccess=true` submits a referral request for a DV shelter
- **THEN** a referral token is created with status `PENDING`, containing household size, population type, urgency, special needs, and the worker's callback number
- **AND** no client name, DOB, SSN, address, or phone is stored

#### Scenario: DV shelter staff accepts referral
- **WHEN** DV shelter staff clicks "Accept" on a pending referral token
- **THEN** the token status changes to `ACCEPTED`
- **AND** the referring outreach worker sees the shelter's intake phone number
- **AND** the shelter address is NOT displayed anywhere in the system

#### Scenario: DV shelter staff rejects referral
- **WHEN** DV shelter staff clicks "Reject" on a pending referral token with a reason
- **THEN** the token status changes to `REJECTED`
- **AND** the referring outreach worker sees "Referral declined" with the reason

#### Scenario: Token expires after configurable window
- **WHEN** a PENDING token exceeds `dv_referral_expiry_minutes` (default 240 = 4 hours)
- **THEN** the token status changes to `EXPIRED`
- **AND** the token is eligible for immediate hard-delete

#### Scenario: Terminal tokens are hard-deleted within 24 hours
- **WHEN** a token reaches ACCEPTED, REJECTED, or EXPIRED status
- **THEN** `ReferralTokenPurgeService` hard-deletes the row within 24 hours
- **AND** no audit trail of the individual referral remains in the database
- **AND** Micrometer counters (`fabt_dv_referral_total{status=...}`) are incremented before purge

#### Scenario: Non-DV-access user cannot create referral (defense-in-depth)
- **WHEN** a user without `dvAccess=true` attempts to create a referral token for a DV shelter
- **THEN** the service layer checks `TenantContext.getDvAccess()` and rejects with 403 Forbidden
- **AND** this check is independent of RLS — it enforces even if the database role bypasses RLS
- **NOTE** Two-layer protection: RLS hides DV shelters at the database level, service-layer check rejects at the application level (D14)

#### Scenario: Token for non-DV shelter rejected
- **WHEN** a user attempts to create a referral token for a shelter where `dvShelter=false`
- **THEN** the API returns 400 Bad Request — referral tokens are only for DV shelters

#### Scenario: Only one pending token per worker per shelter
- **WHEN** an outreach worker already has a PENDING token for a DV shelter
- **AND** they attempt to create another token for the same shelter
- **THEN** the API returns 409 Conflict

### Requirement: referral-token-rls
The system SHALL enforce Row Level Security on referral tokens so that only authorized users can view them.

#### Scenario: Referring worker sees only their own tokens
- **WHEN** an outreach worker queries their pending referrals
- **THEN** they see only tokens they created, not tokens from other workers

#### Scenario: DV coordinator sees tokens for assigned shelters only
- **WHEN** a DV shelter coordinator views pending referrals
- **THEN** they see only tokens for shelters they are assigned to

### Requirement: dv-outreach-worker-test-coverage
Seed data and test infrastructure SHALL include a DV-authorized outreach worker persona for verifying the DV referral flow from the outreach worker perspective.

#### Scenario: DV outreach worker seed user exists
- **GIVEN** seed data is loaded
- **THEN** `dv-outreach@dev.fabt.org` exists with role `OUTREACH_WORKER` and `dvAccess=true`
- **AND** Playwright auth fixture `dvOutreachPage` is available for tests

#### Scenario: DV shelters visible to DV outreach worker
- **WHEN** a DV-authorized outreach worker searches for beds
- **THEN** DV shelters appear in results with addresses redacted ("Address withheld for safety")

#### Scenario: Request Referral button for DV shelters
- **WHEN** a DV shelter has available beds in search results for a DV-authorized outreach worker
- **THEN** the shelter card shows "Request Referral" button instead of "Hold This Bed"

#### Scenario: Referral request succeeds for DV outreach worker
- **WHEN** a DV-authorized outreach worker submits a referral request via the modal
- **THEN** the referral is created and appears in "My DV Referrals"
