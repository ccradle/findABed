## ADDED Requirements

### Requirement: Escalation queue auto-opens detail modal from query param
The DvEscalationsTab SHALL open the detail modal for a specific referral when the URL includes `?referralId=X`. The modal SHALL open per the existing claim/release/reassign lifecycle.

#### Scenario: Admin deep-links to escalation detail from notification
- **WHEN** an admin navigates to `/admin#dvEscalations?referralId=abc-123`
- **THEN** the admin panel loads with the DV Escalations tab selected (existing hash-router behavior)
- **AND** the detail modal for referral `abc-123` opens automatically
- **AND** keyboard focus moves into the modal (existing modal focus-trap)

#### Scenario: Referral not found in escalation queue
- **WHEN** an admin deep-links to `?referralId=X` but the referral is not in the current queue (e.g., already handled)
- **THEN** the tab loads normally (no modal opens)
- **AND** a non-blocking toast displays: "This escalation is no longer in the queue."

#### Scenario: Referral claimed by another admin (existing behavior preserved)
- **WHEN** the deep-linked referral has an active claim by another admin
- **THEN** the modal opens in the claim-aware state (show current claim, allow override per existing behavior)
