## Purpose

Real-time notification of DV shelter coordinators and outreach workers on referral token state changes — zero PII in event payloads.

## ADDED Requirements

### Requirement: referral-notification
The system SHALL notify DV shelter coordinators in real-time when a referral token is created for their shelter. Notifications contain no client PII.

#### Scenario: Coordinator sees pending referral badge
- **WHEN** a referral token is created for a DV shelter
- **THEN** the coordinator dashboard shows a badge count of pending referrals on that shelter's card
- **AND** the badge updates without page reload (event-driven or polling)

#### Scenario: Event published on token creation
- **WHEN** a referral token is created
- **THEN** a `dv-referral.requested` domain event is published via the event bus
- **AND** the event payload contains only `tokenId` and `shelterId` — no PII

#### Scenario: Event published on token response
- **WHEN** DV shelter staff accepts or rejects a referral token
- **THEN** a `dv-referral.responded` domain event is published
- **AND** the referring worker's dashboard updates to show the response

#### Scenario: Outreach worker sees referral status updates
- **WHEN** a referral token they created changes status (ACCEPTED, REJECTED, EXPIRED)
- **THEN** the worker sees the updated status in their "My Referrals" section
- **AND** for ACCEPTED: the shelter intake phone number is displayed
- **AND** for REJECTED: the reason is displayed
- **AND** for EXPIRED: a "Referral expired" message is displayed
