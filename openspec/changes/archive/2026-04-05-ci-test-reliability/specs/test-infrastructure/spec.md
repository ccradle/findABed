## MODIFIED Requirements

### Requirement: Test helpers validate API responses before field extraction
All test helper methods that call API endpoints and extract fields from responses SHALL assert the expected HTTP status code and non-null body before extraction.

#### Scenario: createShelter returns descriptive error on API failure
- **WHEN** `createShelter()` is called and the API returns a non-201 status
- **THEN** the test SHALL fail with an assertion message containing the actual status code and response body
- **AND** no NullPointerException SHALL occur

#### Scenario: extractField does not cause NPE on missing field
- **WHEN** `extractField()` is called on a response body that does not contain the requested field
- **THEN** the method SHALL either throw a descriptive exception or the caller SHALL have already asserted the status code

#### Scenario: All 5 vulnerable test files are fixed
- **WHEN** any of the following test helpers execute against an erroring API:
  - `DvReferralIntegrationTest.createShelter()`
  - `BedAvailabilityHardeningTest.createTestShelter()`
  - `DvAddressRedactionTest.createShelter()`
  - `CrossTenantIsolationTest.createShelter()`
  - `HmisBridgeIntegrationTest.createShelter()`
- **THEN** each SHALL produce a descriptive assertion failure, not an NPE

#### Scenario: Silent API failures are eliminated
- **WHEN** `HmisBridgeIntegrationTest.createShelter()` is called and the API fails
- **THEN** the test SHALL fail immediately with the error status, not silently continue

### Requirement: app-version test uses web-first assertions
The `app-version.spec.ts` test SHALL use Playwright's `toBeVisible({ timeout })` instead of `waitForTimeout` followed by element count check.

#### Scenario: app-version test fails on missing element instead of skipping
- **WHEN** the version element does not render within 10 seconds
- **THEN** the test SHALL FAIL (not skip)
- **AND** the failure message SHALL indicate the version endpoint may not be available

#### Scenario: app-version test passes when element renders
- **WHEN** the version element renders (build-info available)
- **THEN** the test SHALL pass and verify the version text matches `v\d+\.\d+`
