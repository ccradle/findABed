## 1. Branch & Baseline

- [x] 1.1 Create branch `ci-test-reliability` in finding-a-bed-tonight repo
- [x] 1.2 Run backend tests — confirm current baseline (388 tests)
- [x] 1.3 Run Playwright suite — note current skip count for app-version test

## 2. Backend Test Helper Fixes (#50)

- [x] 2.1 Fix `DvReferralIntegrationTest.createShelter()`: add `assertThat(resp.getStatusCode()).as("POST /shelters should return 201 — body: %s", resp.getBody()).isEqualTo(HttpStatus.CREATED)` before `extractField()` call
- [x] 2.2 Fix `DvReferralIntegrationTest.extractField()`: if field not found, throw `AssertionError("Field '" + field + "' not found in response: " + json)` instead of returning null
- [x] 2.3 Fix `BedAvailabilityHardeningTest.createTestShelter()`: add status assertion before ID extraction. Add `assertThat(response.getStatusCode()).as("POST /shelters — body: %s", responseBody).isEqualTo(HttpStatus.CREATED)`
- [x] 2.4 Fix `BedAvailabilityHardeningTest.extractId()`: throw descriptive error instead of returning null on missing field
- [x] 2.5 Fix `DvAddressRedactionTest.createShelter()`: add status assertion before substring extraction
- [x] 2.6 Fix `CrossTenantIsolationTest.createShelter()`: move status assertion BEFORE the ID extraction (currently assertion is there but NPE can still occur if assertion throws before reaching the line — restructure to extract only after assert passes)
- [x] 2.7 Fix `HmisBridgeIntegrationTest.createShelter()`: add status assertion — currently silently discards the response. Assert `HttpStatus.CREATED`
- [x] 2.8 Run backend tests — confirm all 388 still pass with new assertions

## 3. CI Pipeline Fix (#49)

- [x] 3.1 Update `.github/workflows/e2e-tests.yml` E2E Tests job: change `mvn compile` to `mvn spring-boot:build-info compile` (matching Performance Tests job line 289 and dev-start.sh line 204)
- [x] 3.2 Verify locally: run `mvn spring-boot:build-info compile -q` then check `target/classes/META-INF/build-info.properties` exists

## 4. Playwright app-version Test Fix (#49)

- [x] 4.1 Update `app-version.spec.ts` login test (line 16): replace `waitForTimeout(2000)` + `count === 0 skip` with `await expect(version).toBeVisible({ timeout: 10000 })` then verify text
- [x] 4.2 Update `app-version.spec.ts` admin test (line 33): same replacement — `toBeVisible({ timeout: 10000 })` instead of skip
- [x] 4.3 Both tests: keep the regex assertion `text.match(/v\d+\.\d+/)` after visibility check
- [x] 4.4 Run app-version test locally — should PASS (dev-start.sh includes build-info)
- [x] 4.5 Verify: if version endpoint returns 404, test FAILS (not skips) — this is the desired behavior

## 5. Positive Tests — Verifying Fixes Work

- [x] 5.1 Verify DvReferralIntegrationTest passes with new assertions (no NPE path)
- [x] 5.2 Verify all 5 fixed test files pass with new status assertions
- [x] 5.3 Verify app-version test passes locally (both login and admin)
- [x] 5.4 Verify build-info.properties exists after compile
- [x] 5.5 Run full backend suite — 388+ tests pass, 0 failures

## 6. Negative Tests — Failures Are Descriptive

- [x] 6.1 Temporarily simulate API failure in DvReferralIntegrationTest: change `createShelter()` to use `authHelper.outreachWorkerHeaders()` (OUTREACH_WORKER role can't create shelters → 403). Run test, verify assertion message contains "403" and the error response body. Confirm NO NullPointerException in the stack trace. Revert the header change after verification.
- [x] 6.2 Temporarily remove build-info.properties and run app-version test — verify it FAILS with a clear message, NOT skips
- [x] 6.3 Revert the temporary simulations after verifying failure messages

## 7. Integration & Release

- [x] 7.1 Run full backend test suite — confirm green
- [x] 7.2 Run full Playwright suite — confirm app-version tests now PASS (not skip)
- [x] 7.3 Commit, PR, CI scans — the CI itself will validate the e2e-tests.yml fix
- [x] 7.4 Merge and tag
- [x] 7.5 Verify CI runs show app-version test PASSING (not skipping) after merge
- [x] 7.6 Update test counts if changed
