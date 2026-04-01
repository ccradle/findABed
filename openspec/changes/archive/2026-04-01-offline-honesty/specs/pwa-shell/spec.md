## MODIFIED Requirements

### Requirement: Offline queue wired to bed holds

The outreach search flow (`OutreachSearch.tsx`) SHALL check `navigator.onLine` before posting a bed hold. When offline, the hold action SHALL be enqueued via `enqueueAction()` with type `HOLD_BED`. When online but the request fails, the hold SHALL also be enqueued as a fallback.

**Acceptance criteria:**
- Clicking "Hold This Bed" while offline enqueues the action to IndexedDB
- Clicking "Hold This Bed" while online but network fails also enqueues (try/catch fallback)
- UI shows "Hold queued — will send when online" (not "Bed held successfully")
- No API request is attempted while offline
- The queued action includes shelterId, populationType, and a UUID idempotency key

### Requirement: Offline queue wired to availability updates

The coordinator dashboard (`CoordinatorDashboard.tsx`) SHALL check `navigator.onLine` before posting an availability update. When offline, the update SHALL be enqueued via `enqueueAction()` with type `UPDATE_AVAILABILITY`. When online but the request fails, the update SHALL also be enqueued as a fallback.

**Acceptance criteria:**
- Submitting availability while offline enqueues the action to IndexedDB
- Submitting availability while online but network fails also enqueues (try/catch fallback)
- UI shows "Update queued — will send when online" (not success)
- No API request is attempted while offline

### Requirement: Automatic queue replay on reconnect with jitter

The application SHALL listen for the `online` event and automatically call `replayQueue()` when connectivity returns, after a random jittered delay of 0-2 seconds.

**Acceptance criteria:**
- `online` event listener registered in `Layout.tsx`
- Random delay of 0-2000ms applied before `replayQueue()` call
- User notified of replay results: "{N} actions sent", or conflict/expiry details
- If replay encounters network failure (still flaky), actions remain in queue for next attempt
- Custom DOM events dispatched for component state transitions (`fabt-queue-replaying`, `fabt-queue-replayed`)

### Requirement: Hold expiry validation before replay

`replayQueue()` SHALL check the age of `HOLD_BED` actions against the tenant's hold duration TTL before replaying. Expired holds are removed from the queue and the user is notified.

**Acceptance criteria:**
- A hold queued more than (holdDuration - 5 minutes) ago is skipped
- The 5-minute buffer prevents holds that would expire moments after creation
- User sees: "Hold request expired (queued {N} minutes ago). Search again?"
- Availability updates have no expiry — always replayed

### Requirement: Queue status visibility

A `QueueStatusIndicator` component SHALL show the count of pending queued actions in the header when count > 0.

**Acceptance criteria:**
- Badge appears near the notification bell showing pending count
- Clicking shows a summary of queued actions with their status (queued/sending/failed)
- Badge disappears when queue is empty
- Accessible: `aria-label` describes the count

### Requirement: Honest offline banner copy

The offline banner SHALL not promise that actions "will sync." It SHALL accurately describe what works offline and what is queued.

**Acceptance criteria:**
- EN: "You are offline. Cached searches are still visible. Bed holds and updates will be queued and sent when you reconnect."
- ES: Equivalent Spanish translation
- No mention of "sync" (implies guaranteed success)
- FOR-COORDINATORS.md and training quick-start card updated to match

### Requirement: Service worker for caching only

A custom service worker (`src/sw.ts`) SHALL use `injectManifest` for precaching and NetworkFirst runtime caching for API GETs. The service worker SHALL NOT include BackgroundSyncPlugin.

**Acceptance criteria:**
- `vite.config.ts` uses `injectManifest` strategy instead of `generateSW`
- `src/sw.ts` provides precaching and NetworkFirst for GET `/api/v1/*`
- No BackgroundSyncPlugin — offline resilience is handled entirely by the app-level queue
- App still works when service worker is blocked (hospital use case)

### Requirement: Idempotency key for hold replay deduplication

Queued hold actions SHALL include a UUID `X-Idempotency-Key` header. The backend `POST /api/v1/reservations` endpoint SHALL check for existing active holds with the same user and idempotency key, returning the existing hold instead of creating a duplicate.

**Acceptance criteria:**
- New Flyway migration adds nullable `idempotency_key VARCHAR(36)` to `reservation` table
- Duplicate POST with same user + idempotency key returns 200 with existing hold (not 201)
- First POST with a new key creates hold as normal (201)
- Idempotency key is optional — requests without it behave as before

### Requirement: Queued action UI states

The reservation panel and coordinator dashboard SHALL display distinct visual states for queued actions.

**States:**
- **QUEUED:** Amber clock icon, "Hold queued — will send when online"
- **SENDING:** Spinner, "Syncing..."
- **CONFIRMED:** Transitions to normal hold UI with countdown
- **CONFLICTED:** Red alert, "Bed was taken while offline. [Search again]"
- **EXPIRED:** Gray, "Hold request expired (queued {N} min ago). [Search again]"
- **FAILED:** Amber retry, "Could not reach server. Will retry automatically."

**Acceptance criteria:**
- Each state is visually distinct and accessible (not color-alone)
- State transitions driven by custom DOM events from Layout replay
- Conflicted and expired states include an actionable next step
- Screen reader announces state changes via `aria-live` region

### Requirement: IndexedDB persistence protection

The application SHALL request persistent storage at startup to protect the offline queue from browser eviction.

**Acceptance criteria:**
- `navigator.storage.persist()` called at app startup
- Result logged (granted or denied)
- App functions normally if persistence is denied (best-effort protection)

### Requirement: Try/catch fallback for online failures

When `navigator.onLine` is `true` but a mutation request fails with a network error, the application SHALL fall back to enqueuing the action rather than showing an error.

**Acceptance criteria:**
- Bed hold: network error during online POST triggers `enqueueAction()` fallback
- Availability update: network error during online PATCH triggers `enqueueAction()` fallback
- User sees "queued" state, not an error message
- Subsequent `online` event triggers replay as normal
