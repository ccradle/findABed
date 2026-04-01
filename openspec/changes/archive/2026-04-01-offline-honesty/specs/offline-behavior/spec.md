## MODIFIED Requirements

### Requirement: Playwright tests use explicit DOM event dispatch

All Playwright offline tests SHALL explicitly dispatch `online` and `offline` DOM events rather than relying on `context.setOffline()` alone, because Playwright's `setOffline()` does NOT fire these events or change `navigator.onLine`.

**Acceptance criteria:**
- Every test that goes offline dispatches `window.dispatchEvent(new Event('offline'))` after `setOffline(true)`
- Every test that reconnects dispatches `window.dispatchEvent(new Event('online'))` after `setOffline(false)`
- No test relies on implicit detection of `setOffline` state changes

### Requirement: Offline queue E2E test verifies actual behavior

The Playwright offline test ("queued availability update replays on reconnect") SHALL verify that the action was actually queued in IndexedDB and replayed after reconnection — not merely that the page didn't crash.

**Acceptance criteria:**
- Test goes offline (setOffline + dispatchEvent), submits availability update, verifies action appears in IndexedDB queue
- Test reconnects (setOffline false + dispatchEvent online), waits for replay, verifies API received the update
- Test checks shelter availability data reflects the update
- IndexedDB inspection uses the app's own `getQueuedActions()` export, not reimplemented DB access

### Requirement: Hold queued and replayed E2E test

A new Playwright test SHALL verify the full Darius scenario: search → hold → lose signal → reconnect → hold confirmed.

**Test flow:**
1. Login as outreach worker
2. Search for beds, find a shelter with availability
3. Go offline (setOffline + dispatchEvent offline)
4. Click "Hold This Bed"
5. Verify UI shows "Hold queued" (not "Bed held")
6. Verify IndexedDB has 1 queued action
7. Reconnect (setOffline false + dispatchEvent online)
8. Wait for replay (including jitter delay)
9. Verify hold was replayed successfully (queued hold removed from panel)
10. Verify IndexedDB queue is empty

**Acceptance criteria:**
- Test uses the app's exported `getQueuedActions()` to inspect queue state
- Test makes real assertions about queue contents and replay outcome
- Test fails if the hold is not actually queued or replayed

### Requirement: Hold expiry E2E test

A Playwright test SHALL verify that an expired hold is not replayed and the user is notified.

**Acceptance criteria:**
- Test enqueues a hold action with a timestamp older than hold duration
- Test triggers reconnect via explicit dispatchEvent('online')
- Verify the expired hold is removed from queue (not replayed)
- Verify user sees expiry notification

### Requirement: Conflict notification E2E test

A Playwright test SHALL verify that a 409 conflict on replay shows an actionable notification.

**Acceptance criteria:**
- Test sets up a scenario where the bed is no longer available (route intercept returns 409)
- Test triggers replay of a queued hold
- Verify 409 is handled gracefully
- Verify user sees "Bed was taken while offline" with search-again action

### Requirement: Queue status indicator E2E test

A Playwright test SHALL verify the queue status badge appears when actions are pending and disappears after replay.

**Acceptance criteria:**
- Go offline, enqueue an action, verify badge shows "1"
- Reconnect, wait for replay (including jitter delay), verify badge disappears
- Badge is accessible (`aria-label`)

### Requirement: Negative test — double online event

A Playwright test SHALL verify that two `online` events fired within 100ms do not cause `replayQueue()` to execute twice concurrently.

**Acceptance criteria:**
- Go offline, enqueue a hold
- Fire two `online` events rapidly (within 100ms)
- Verify only one API call is made for the hold (no duplicate)
- Verify queue is empty after replay

### Requirement: Negative test — try/catch fallback when online but network fails

A Playwright test SHALL verify that a mutation attempted while `navigator.onLine` is `true` but the network request fails results in the action being enqueued (not an error shown to the user).

**Acceptance criteria:**
- Use `page.route()` to intercept the hold API and return a network error
- Click "Hold This Bed" while nominally online
- Verify the action is enqueued to IndexedDB (not an error displayed)
- Remove the route intercept, trigger replay, verify hold succeeds

### Requirement: Nginx proxy offline tests

The offline E2E test suite SHALL run through the nginx proxy in addition to direct Vite dev server.

**Acceptance criteria:**
- All offline tests pass with `NGINX=1` Playwright project configuration
- Replay through nginx proxy does not exhibit buffering or timeout issues
- CI runs the nginx offline suite

### Requirement: Unit tests for offlineQueue.ts

Vitest unit tests SHALL cover the critical logic in `offlineQueue.ts` using `fake-indexeddb`.

**Acceptance criteria:**
- Enqueue/dequeue ordering by timestamp
- Hold expiry at exactly (holdDuration - bufferMs): skipped
- Hold expiry at (holdDuration - bufferMs - 1ms): replayed
- 409 conflict: action removed from queue, added to conflicts list
- Non-409 error: action remains in queue, increments failed count
- Idempotency key: each enqueued action gets a unique UUID
- Concurrent replay guard: two `replayQueue()` calls don't process the same action twice

### Requirement: Concurrent reconnection performance test

A Gatling simulation SHALL verify that concurrent queue replay from multiple users does not cause data corruption or unacceptable latency.

**Acceptance criteria:**
- 5 simulated users replay queued holds simultaneously for the same shelter
- No duplicate reservations created (idempotency key enforced)
- Advisory lock contention does not cause response times > 5 seconds
- No HikariCP pool exhaustion

### Requirement: Hospital use case — service workers blocked

A Playwright test SHALL verify the app functions fully when service workers are blocked, using Playwright's `serviceWorkers: 'block'` context option.

**Acceptance criteria:**
- Browser context created with `{ serviceWorkers: 'block' }`
- Search, filter, and hold bed all function correctly
- Offline queue (try/catch fallback) still works without SW
- No SW-related errors crash the page
