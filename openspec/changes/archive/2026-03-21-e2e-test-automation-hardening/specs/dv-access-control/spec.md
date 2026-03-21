## ADDED Requirements

### Requirement: dv-shelter-e2e-exclusion
The E2E suite SHALL verify that DV shelters never appear in any public API response. This is a blocking CI canary gate — if any scenario fails, the entire pipeline halts.

#### Scenario: DV shelter absent from bed search
- **WHEN** an OUTREACH_WORKER (without DV_REFERRAL) sends POST `/api/v1/queries/beds` with no filters
- **THEN** no result contains the DV shelter's UUID, name, address, or phone

#### Scenario: DV shelter absent from shelter list
- **WHEN** an OUTREACH_WORKER sends GET `/api/v1/shelters`
- **THEN** the DV shelter UUID does not appear in any result

#### Scenario: DV shelter direct access returns 404 not 403
- **WHEN** an OUTREACH_WORKER sends GET `/api/v1/shelters/{dvShelterId}`
- **THEN** the response is 404 (not 403 — 403 leaks existence)

#### Scenario: DV shelter HSDS export returns 404
- **WHEN** an OUTREACH_WORKER sends GET `/api/v1/shelters/{dvShelterId}?format=hsds`
- **THEN** the response is 404

#### Scenario: COC_ADMIN without dvAccess cannot see DV shelter
- **WHEN** a COC_ADMIN with `dvAccess: false` sends GET `/api/v1/shelters`
- **THEN** the DV shelter is absent from results
