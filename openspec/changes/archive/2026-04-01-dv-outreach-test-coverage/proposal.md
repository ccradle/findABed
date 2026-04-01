## Why

No test coverage exists for a DV-authorized outreach worker — an `OUTREACH_WORKER` with `dvAccess=true`. This is a real operational persona: DV-certified outreach workers and hospital social workers who encounter survivors in the field need DV shelter visibility with address redaction and referral access.

The existing DV canary test verifies that `outreach@dev.fabt.org` (dvAccess=false) does NOT see DV shelters. The admin tests verify that `admin@dev.fabt.org` (dvAccess=true) DOES see them. But the middle case — an outreach worker who CAN see DV shelters but with redacted addresses — has zero coverage.

Persona consensus (Keisha, Marcus Okafor, Riley, Dr. Whitfield) confirms this is a real gap.

## What Changes

- Add seed user `dv-outreach@dev.fabt.org` with role `OUTREACH_WORKER` and `dvAccess=true`
- Add Playwright tests: DV shelters visible in search results, address redacted per tenant policy, "Request Referral" button shown (not "Hold This Bed"), referral request succeeds
- Add backend integration test: RLS returns DV shelters for dvAccess=true outreach worker, address redacted in response

## Capabilities

### New Capabilities
_None — tests existing functionality that has no coverage._

### Modified Capabilities
- `dv-opaque-referral`: Add test coverage for DV-authorized outreach worker persona

## Impact

- **Seed data:** `infra/scripts/seed-data.sql` — add 1 user row
- **Tests:** 3-4 new Playwright E2E tests, 1-2 backend integration tests
- **No code changes** — the feature already works, we're just verifying it
