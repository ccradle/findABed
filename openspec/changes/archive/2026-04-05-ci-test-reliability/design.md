## Context

The test suite has two systemic reliability issues discovered through CI failures and persistent test skips.

**Pattern 1 (5 files):** Test helpers call `POST /api/v1/shelters`, then extract `id` from the response body using string parsing without checking HTTP status. When the API returns an error response (no `id` field), `extractField()` returns null → `UUID.fromString(null)` → NPE. The NPE happens in `@BeforeEach setUp()`, so all tests in the class fail with an opaque NPE instead of a clear "API returned 403" message.

**Pattern 2 (1 file):** The `VersionController` uses `@ConditionalOnResource` — the bean only loads when `build-info.properties` exists. The E2E CI workflow omits `spring-boot:build-info` from the Maven command, so the endpoint returns 404. The test gracefully skips instead of failing, hiding the configuration gap.

**Reference implementation:** `ShelterIntegrationTest.java` correctly uses typed `ResponseEntity<ShelterResponse>` with explicit status + body assertions. This is the pattern to follow.

## Goals / Non-Goals

**Goals:**
- Every test helper that extracts fields from API responses validates the status code first
- Failures produce descriptive messages ("POST /shelters returned 403: {body}") instead of opaque NPEs
- app-version test fails instead of skipping when the version endpoint is missing
- E2E CI workflow generates build-info so the version endpoint exists
- Playwright tests use web-first assertions (`toBeVisible`) not `waitForTimeout`

**Non-Goals:**
- Rewriting all test helpers to use typed deserialization (future improvement — too large for this change)
- Adding retry logic for cold start races (the fix is better error messages, not retries)
- Changing the `@ConditionalOnResource` pattern (it's correct — the CI just needs to generate the resource)

## Decisions

### D1: Assert-then-extract pattern for test helpers

Every test helper that calls an API and extracts a field SHALL:
1. Assert the expected HTTP status code
2. Assert the response body is not null
3. Only then extract the field
4. Include the response body in the assertion failure message

```java
ResponseEntity<String> resp = restTemplate.exchange(...);
assertThat(resp.getStatusCode())
    .as("POST /shelters should return 201 — body: %s", resp.getBody())
    .isEqualTo(HttpStatus.CREATED);
return UUID.fromString(extractField(resp.getBody(), "id"));
```

**Why:** The assertion fails with a clear message that includes the actual error response body, enabling diagnosis without re-running the test. The NPE never reaches the test runner.

### D2: Fix all 5 vulnerable files, not just the reported one

The pattern repeats in 5 files. Fixing only the reported file leaves 4 identical time bombs.

**Why per Riley:** "If we find a bug pattern in one file, we grep for it everywhere."

### D3: app-version test fails instead of skipping

Change the test from `if (count === 0) { test.skip() }` to `await expect(version).toBeVisible({ timeout: 10000 })`. If the version element doesn't appear within 10 seconds, the test FAILS — exposing the missing build-info configuration immediately.

**Why:** A test that skips silently is worse than a test that doesn't exist — it creates false confidence. The test's purpose is to verify the version displays. If it can't verify that, it should fail loudly.

### D4: Add build-info goal to E2E CI workflow

Add `spring-boot:build-info` to the E2E Tests job's compile command in `.github/workflows/e2e-tests.yml`, matching the Performance Tests job and `dev-start.sh`.

**Why:** The E2E Tests job is the only build path that omits this goal. All other paths (Performance, local dev) include it. This is a configuration oversight, not a design choice.

### D5: Replace waitForTimeout with web-first assertions

All `waitForTimeout(2000)` calls in `app-version.spec.ts` SHALL be replaced with `expect(locator).toBeVisible({ timeout: 10000 })`.

**Why:** `waitForTimeout` is a Playwright anti-pattern — it waits a fixed duration regardless of page state. `toBeVisible` internally polls (re-checks repeatedly) and returns immediately when the condition is met. This is both faster and more reliable.

## Risks / Trade-offs

**[Risk] Changing test from skip to fail may break CI initially** → Mitigation: D4 (adding build-info goal) must be in the same commit. If the goal is added, the test will pass. If we accidentally deploy without the goal, the test fails loudly — which is the desired behavior.

**[Risk] Assertion messages may expose sensitive data in CI logs** → Mitigation: The response bodies are from test API calls against Testcontainers — no production data. Error messages like "returned 403" are diagnostic, not sensitive.

**[Risk] Some test files have different helper patterns (extractId vs extractField vs substring)** → Mitigation: Fix each file individually using its existing pattern. Don't force all files into one pattern — that's a refactor, not a reliability fix.
