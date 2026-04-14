## ADDED Requirements

### Requirement: Banner click respects referralId query param
The CoordinatorReferralBanner SHALL open the shelter containing the specified referral when the dashboard URL includes a `referralId` query parameter, instead of always opening the first DV shelter.

#### Scenario: Banner opens specific referral's shelter
- **WHEN** a coordinator lands on `/coordinator?referralId=abc-123`
- **AND** the referral `abc-123` is pending at shelter `shelterB`
- **THEN** the CoordinatorReferralBanner uses the query param to open `shelterB` (not the first DV shelter)
- **AND** the specific referral row is scrolled into view

#### Scenario: Banner click without query param (existing behavior)
- **WHEN** a coordinator clicks the banner on `/coordinator` (no query param)
- **THEN** the first DV shelter with pending referrals is opened (existing behavior preserved)
- **AND** the first pending referral in that shelter is visible
