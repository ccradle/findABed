## ADDED Requirements

### Requirement: offline-queue-e2e
The E2E suite SHALL verify PWA offline behavior using Playwright's `page.context().setOffline()`.

#### Scenario: Offline banner appears on connectivity loss
- **WHEN** the browser goes offline
- **THEN** a yellow/amber banner containing "offline" text is visible and persists

#### Scenario: Offline queue holds and replays on reconnect
- **WHEN** a coordinator submits an availability update while offline, then reconnects
- **THEN** the queued update fires and the shelter shows updated availability within 5 seconds

#### Scenario: Search results stale-served from cache while offline
- **WHEN** the browser goes offline after results have loaded
- **THEN** existing results remain visible with stale indicators, no error page
