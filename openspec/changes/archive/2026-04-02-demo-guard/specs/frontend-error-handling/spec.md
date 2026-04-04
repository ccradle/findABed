## ADDED Requirements

### Requirement: All API catch blocks display the actual error message
Every catch block in the frontend that handles API errors SHALL use the actual error message from the API response as the primary display text, with a localized fallback for non-API errors. The pattern SHALL be:
```typescript
catch (err: unknown) {
  const apiErr = err as { message?: string };
  setError(apiErr.message || intl.formatMessage({ id: 'fallback.id' }));
}
```

#### Scenario: Demo guard message displayed in AdminPanel
- **WHEN** an admin clicks "Create User" and the DemoGuardFilter returns 403 demo_restricted
- **THEN** the admin panel displays "User management is disabled in the demo environment. This feature is available in a full deployment."

#### Scenario: Demo guard message displayed in CoordinatorDashboard
- **WHEN** a coordinator triggers a demo-restricted operation
- **THEN** the coordinator dashboard displays the actual demo_restricted message from the API

#### Scenario: Non-demo API error displays actual message
- **WHEN** an API call returns a validation error (e.g., "Email already exists")
- **THEN** the component displays "Email already exists" (not a generic fallback)

#### Scenario: Network error displays fallback
- **WHEN** an API call fails due to network error (no JSON body)
- **THEN** the component displays the localized fallback message

### Requirement: Fix AdminPanel.tsx swallowed catch blocks
All 20 catch blocks in AdminPanel.tsx that use `catch { setError(intl.formatMessage(...)) }` SHALL be updated to capture and display the actual error message.

#### Scenario: AdminPanel createUser shows API error
- **WHEN** the create user API returns any error
- **THEN** the error banner shows the API's error message, not "Couldn't load your shelters"

#### Scenario: AdminPanel surge activation shows API error
- **WHEN** surge activation fails with demo_restricted
- **THEN** the error shows "Surge management is disabled in the demo environment."

### Requirement: Fix CoordinatorDashboard.tsx swallowed catch blocks
All 8 catch blocks in CoordinatorDashboard.tsx that use `catch { setError(intl.formatMessage(...)) }` SHALL be updated to capture and display the actual error message.

#### Scenario: CoordinatorDashboard availability update shows API error
- **WHEN** an availability update fails
- **THEN** the coordinator dashboard shows the actual API error message

### Requirement: Fix ShelterEditPage.tsx swallowed catch block
The catch block in ShelterEditPage.tsx SHALL be updated to use the actual error message.

#### Scenario: ShelterEditPage load error shows API message
- **WHEN** the shelter detail API returns an error
- **THEN** the page shows the actual API error message

### Requirement: Intentionally silent catch blocks are documented
Catch blocks that intentionally swallow errors (e.g., `catch { /* monitor may not have run yet */ }`) SHALL remain as-is but MUST have a comment explaining why silence is intentional.

#### Scenario: Silent catch has explanatory comment
- **WHEN** a catch block intentionally ignores an error
- **THEN** the catch block contains a comment explaining the rationale

### Requirement: E2E tests verify demo guard messages in browser
Playwright tests SHALL verify that demo_restricted messages appear in the browser UI for key admin operations, testing the full stack: API response → error handler → component → visible text.

#### Scenario: Playwright verifies Create User demo restriction
- **WHEN** the Playwright test logs in as admin and submits the Create User form
- **THEN** the page text contains "disabled in the demo environment" and "full deployment"

#### Scenario: Playwright verifies outreach search works
- **WHEN** the Playwright test logs in as outreach worker and searches for beds
- **THEN** the page shows "shelters found" with "Hold This Bed" buttons

#### Scenario: Tests run locally before deployment
- **WHEN** the demo guard change is ready for deployment
- **THEN** all Playwright E2E tests pass against a local dev instance with `demo` profile active
