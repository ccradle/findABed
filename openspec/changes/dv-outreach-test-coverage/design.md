## Context

The FABT platform has four test users in seed data: admin (PLATFORM_ADMIN, dvAccess=true), cocadmin (COC_ADMIN, dvAccess=false), outreach (OUTREACH_WORKER, dvAccess=false), and former (deactivated). No outreach worker with DV access exists for testing.

The DV shelter protection model: shelters with `dvShelter=true` are invisible to users without `dvAccess=true` (enforced by PostgreSQL RLS). For users with `dvAccess=true`, DV shelters appear in search but addresses are redacted per the tenant's `dv_address_visibility` policy. The "Request Referral" button replaces "Hold This Bed" for DV shelters.

## Goals / Non-Goals

**Goals:**
- Verify the DV-authorized outreach worker experience end-to-end
- Ensure address redaction works correctly for this persona
- Ensure "Request Referral" (not "Hold This Bed") appears for DV shelters
- Add to the Playwright auth fixtures for reuse

**Non-Goals:**
- Changing DV shelter behavior (it already works correctly)
- Adding a DV outreach worker to the demo flow (keep demo simple with 3 roles)

## Design

**Seed user:** `dv-outreach@dev.fabt.org`, password `admin123`, role `OUTREACH_WORKER`, `dvAccess=true`, display name "DV Outreach Worker".

**Playwright auth fixture:** Add `dvOutreachPage` fixture in `auth.fixture.ts` alongside existing `outreachPage`, `coordinatorPage`, `adminPage`.

**Tests:**
1. DV shelters visible in bed search results (Safe Haven, Harbor House, Bridges to Safety)
2. DV shelter address is redacted (shows "Address withheld" or similar per policy)
3. DV shelter shows "Request Referral" button instead of "Hold This Bed"
4. Referral request modal opens and can be submitted
5. Regular (non-DV) shelters still show full address and "Hold This Bed"

**Backend test:** Query `/api/v1/queries/beds` as DV outreach worker, verify DV shelters in results with address redacted.
