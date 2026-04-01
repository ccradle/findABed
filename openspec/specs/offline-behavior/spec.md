## Purpose

PWA offline behavior Playwright tests (banner, stale cache, queue replay, negative tests, nginx proxy).

## ADDED Requirements

### Requirement: offline-queue-e2e
The E2E suite SHALL verify PWA offline behavior using Playwright's `page.context().setOffline()` combined with explicit DOM event dispatch.

#### Scenario: Offline banner appears on connectivity loss
- **WHEN** the browser goes offline
- **THEN** a yellow/amber banner containing "offline" text is visible and persists

#### Scenario: Offline queue holds and replays on reconnect
- **WHEN** a coordinator submits an availability update while offline, then reconnects
- **THEN** the queued update fires and the shelter shows updated availability within 5 seconds

#### Scenario: Search results stale-served from cache while offline
- **WHEN** the browser goes offline after results have loaded
- **THEN** existing results remain visible with stale indicators, no error page

### Requirement: Playwright tests use explicit DOM event dispatch
All Playwright offline tests SHALL explicitly dispatch `online` and `offline` DOM events rather than relying on `context.setOffline()` alone, because Playwright's `setOffline()` does NOT fire these events or change `navigator.onLine`.

**Acceptance criteria:**
- Every test that goes offline dispatches `window.dispatchEvent(new Event('offline'))` after `setOffline(true)`
- Every test that reconnects dispatches `window.dispatchEvent(new Event('online'))` after `setOffline(false)`

### Requirement: Hold queued and replayed E2E test
A Playwright test SHALL verify the full Darius scenario: search, hold while offline, reconnect, hold replayed.

### Requirement: Hold expiry E2E test
A Playwright test SHALL verify that an expired hold is not replayed and the user is notified.

### Requirement: Conflict notification E2E test
A Playwright test SHALL verify that a 409 conflict on replay shows an actionable notification.

### Requirement: Queue status indicator E2E test
A Playwright test SHALL verify the queue badge appears when pending and disappears after replay.

### Requirement: Double online event negative test
A Playwright test SHALL verify two rapid `online` events do not cause duplicate API calls.

### Requirement: Try/catch fallback E2E test
A Playwright test SHALL verify that a mutation attempted while online but failing results in the action being enqueued.

### Requirement: Multi-action replay order test
A Playwright test SHALL verify multiple queued actions replay in timestamp order.

### Requirement: FAILED state rendering test
A Playwright test SHALL verify the FAILED UI state appears for non-409 replay errors and the action remains in queue.

### Requirement: Replay success toast test
A Playwright test SHALL verify the toast notification shows the correct count of replayed actions.

### Requirement: Nginx proxy offline tests
The offline E2E test suite SHALL run through the nginx proxy (`NGINX=1` project).

### Requirement: Unit tests for offlineQueue.ts
Vitest unit tests SHALL cover expiry boundaries, conflict handling, concurrent replay guard, and idempotency key uniqueness using `fake-indexeddb`.

### Requirement: Concurrent reconnection performance test
A Gatling simulation SHALL verify concurrent queue replay from multiple users does not cause data corruption or unacceptable latency (5-user, 10-user shelter outage, 20-user citywide outage scenarios).

### Requirement: Hospital use case — service workers blocked
A Playwright test SHALL verify the app functions fully when service workers are blocked, using `serviceWorkers: 'block'` context option.
