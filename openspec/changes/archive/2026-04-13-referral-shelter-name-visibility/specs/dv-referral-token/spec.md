## MODIFIED Requirements

### Requirement: referral-token-lifecycle
The system SHALL support a referral token lifecycle (PENDING → ACCEPTED/REJECTED/EXPIRED) for DV shelter bed requests. Tokens contain no structured client PII (names, DOB, SSN, phone, address). **The shelter name SHALL be snapshotted into the token record at creation time.** **The system SHALL perform a "Safety Check" on list retrieval; if the destination shelter is deactivated, the status SHALL be flagged as SHELTER_CLOSED.** All terminal-state tokens are hard-deleted within 24 hours.

#### Scenario: Outreach worker creates referral token
- **WHEN** an outreach worker with `dvAccess=true` submits a referral request for a DV shelter
- **THEN** a referral token is created with status `PENDING`, containing household size, population type, urgency, special needs, and the worker's callback number
- **AND** the shelter name is snapshotted into the token record
- **AND** no client name, DOB, SSN, address, or phone is stored

#### Scenario: Shelter deactivated after referral
- **GIVEN** a pending referral token for "Safe Haven"
- **WHEN** "Safe Haven" is deactivated by an administrator
- **AND** the worker views their "My Referrals" list
- **THEN** the status for that referral shows `SHELTER_CLOSED`
- **AND** the worker is advised to contact their administrator

#### Scenario: DV shelter staff accepts referral
- **WHEN** DV shelter staff clicks "Accept" on a pending referral token
- **THEN** the token status changes to `ACCEPTED`
- **AND** the referring outreach worker sees the shelter's intake phone number
- **AND** the shelter address is NOT displayed anywhere in the system

#### Scenario: Token expires after configurable window
- **WHEN** a PENDING token exceeds `dv_referral_expiry_minutes` (default 240 = 4 hours)
- **THEN** the token status changes to `EXPIRED`
- **AND** the token is eligible for immediate hard-delete
- **AND** `expireTokens()` SHALL use `UPDATE ... RETURNING id` to atomically expire and retrieve token IDs      
- **AND** `expireTokens()` SHALL publish a `dv-referral.expired` domain event containing the list of expired token IDs and the tenant ID

#### Scenario: Terminal tokens are hard-deleted within 24 hours
- **WHEN** a token reaches ACCEPTED, REJECTED, or EXPIRED status
- **THEN** `ReferralTokenPurgeService` hard-deletes the row within 24 hours
- **AND** no audit trail of the individual referral remains in the database
- **AND** Micrometer counters (`fabt_dv_referral_total{status=...}`) are incremented before purge

### Requirement: dv-outreach-worker-test-coverage
Seed data and test infrastructure SHALL include a DV-authorized outreach worker persona for verifying the DV referral flow from the outreach worker perspective.

#### Scenario: Referral request succeeds for DV outreach worker
- **WHEN** a DV-authorized outreach worker submits a referral request via the modal
- **THEN** the referral is created and appears in "My DV Referrals"
- **AND** the list item displays the status, shelter name, and creation time on the primary line (e.g., "Accepted — Safe Haven — 2:15 PM") with population type and household count on a secondary line (S2 mobile overflow fix, war room 2026-04-12)
- **AND** the item has a structured `aria-label` following the Tomas persona's priority: Status first, then Shelter, then Population and Time.
- **AND** the `myReferrals` frontend cache is cleared when the user logs out.
