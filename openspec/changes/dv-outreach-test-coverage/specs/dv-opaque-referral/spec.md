## MODIFIED Requirements

### Requirement: DV-authorized outreach worker seed user

Seed data SHALL include a user `dv-outreach@dev.fabt.org` with role `OUTREACH_WORKER` and `dvAccess=true`.

**Acceptance criteria:**
- User exists in seed data with correct role and DV access
- User can log in with password `admin123`
- Playwright auth fixture `dvOutreachPage` available for tests

### Requirement: DV shelter visibility for DV outreach worker

When a DV-authorized outreach worker searches for beds, DV shelters SHALL appear in results with addresses redacted per the tenant's `dv_address_visibility` policy.

**Acceptance criteria:**
- Bed search returns DV shelters (Safe Haven, Harbor House, Bridges to Safety) for DV outreach worker
- DV shelter addresses are redacted (not shown in full)
- Non-DV shelters show full addresses as normal
- Playwright E2E test verifies visibility and redaction
- Backend integration test verifies API response

### Requirement: Request Referral button for DV shelters

DV shelters in search results SHALL show "Request Referral" button instead of "Hold This Bed" for DV-authorized outreach workers.

**Acceptance criteria:**
- DV shelter card shows "Request Referral" button
- Non-DV shelter card shows "Hold This Bed" button
- Clicking "Request Referral" opens the referral request modal
- Playwright E2E test verifies button text and modal opening

### Requirement: Referral request succeeds for DV outreach worker

A DV-authorized outreach worker SHALL be able to submit a referral request for a DV shelter.

**Acceptance criteria:**
- Referral request submitted successfully
- "My Referrals" shows the pending referral
- Playwright E2E test verifies the full flow
