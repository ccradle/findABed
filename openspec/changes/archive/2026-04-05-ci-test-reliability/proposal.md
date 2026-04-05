## Why

Two CI reliability issues erode trust in the test suite:

**Issue #50 — DvReferralIntegrationTest NPE on cold start:** The `createShelter()` helper extracts `id` from the API response without checking the HTTP status code. When the API returns an error (401, 403, 500 during cold start), `extractField()` returns null, causing `UUID.fromString(null)` → NPE. Investigation reveals **5 test files** have the same vulnerability — a systemic test infrastructure problem, not a single-file fix.

**Issue #49 — app-version test always skips:** Root cause is NOT timing. The `VersionController` uses `@ConditionalOnResource(resources = "classpath:META-INF/build-info.properties")` — the controller bean only loads if the build-info file exists. The E2E CI workflow runs `mvn compile` but omits `spring-boot:build-info`, so the file is never generated, the controller never loads, `/api/v1/version` returns 404, the version element never renders, and the test skips. The Performance Tests workflow and `dev-start.sh` correctly include the goal.

**Riley's lens:** A test that NPEs in setUp before any test runs gives zero signal. A test that always skips is invisible coverage loss. Both make the CI green/red signal unreliable.

## What Changes

### Backend test infrastructure (#50)
- Add response status validation to ALL test helpers that extract fields from API responses
- Fix `extractField()` pattern: assert status before extraction, throw descriptive error with response body on failure
- Fix 5 vulnerable test files: DvReferralIntegrationTest, BedAvailabilityHardeningTest, DvAddressRedactionTest, CrossTenantIsolationTest, HmisBridgeIntegrationTest
- ShelterIntegrationTest is already safe (uses typed deserialization + assertions) — use as reference pattern

### CI pipeline fix (#49)
- Add `spring-boot:build-info` to the E2E Tests workflow Maven command
- Change app-version test from skip-on-missing to fail-on-missing — a test that silently skips hides the problem

### Test improvements
- app-version test: replace `waitForTimeout(2000)` with `toBeVisible({ timeout: 10000 })` — Playwright best practice (internally polls, faster + more reliable)

## Capabilities

### Modified Capabilities
- `test-infrastructure`: Response validation in test helpers, descriptive failure messages
- `ci-infrastructure`: E2E workflow build-info goal, app-version test reliability

## Impact

**Backend test files (5 fixes):**
- `DvReferralIntegrationTest.java` — add status assertion to `createShelter()`, `extractField()`
- `BedAvailabilityHardeningTest.java` — add status assertion to `createTestShelter()`, `extractId()`
- `DvAddressRedactionTest.java` — add status assertion to `createShelter()`
- `CrossTenantIsolationTest.java` — improve existing assertion (prevent NPE after assertion failure)
- `HmisBridgeIntegrationTest.java` — add status assertion to `createShelter()` (silent failure)

**CI workflow:**
- `.github/workflows/e2e-tests.yml` — add `spring-boot:build-info` to compile step

**Playwright test:**
- `app-version.spec.ts` — replace skip-on-missing with fail, replace `waitForTimeout` with `toBeVisible`

**No production code changes.** All fixes are in tests and CI infrastructure.
