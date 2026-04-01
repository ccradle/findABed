## Context

FABT is a React 19 + Vite PWA with a Workbox-generated service worker. The existing offline infrastructure includes:

- `offlineQueue.ts` — IndexedDB-backed queue using `idb` library. Stores actions with type, URL, method, body, timestamp. Has `enqueueAction()` and `replayQueue()`. Only `ShelterForm.tsx` calls `enqueueAction()`. Nothing calls `replayQueue()`.
- `useOnlineStatus.ts` — React hook wrapping `navigator.onLine` + online/offline events.
- `OfflineBanner.tsx` — Yellow banner shown when offline. Currently says "Actions will sync when connection returns."
- Workbox config in `vite.config.ts` — NetworkFirst for GET `/api/v1/*` with 5-second timeout. Only caches reads, not writes.
- Playwright `offline-behavior.spec.ts` — 4 tests. Test 3 ("queued availability update replays") only asserts page doesn't crash, not that the action was queued or replayed.

The two critical offline operations:
1. **Bed hold** (`POST /api/v1/reservations`) — Darius in a parking lot, signal drops
2. **Availability update** (`PATCH /api/v1/shelters/{id}/availability`) — Sandra at the front desk, WiFi glitches

## Goals / Non-Goals

**Goals:**
- Bed holds and availability updates survive brief network interruptions (30-60 seconds)
- User always knows the true status: queued, sending, confirmed, conflicted, expired, or failed
- Queued holds are validated against hold duration TTL before replay
- Works on all browsers (Chrome, Firefox, Safari, iOS) without service worker dependency
- Single queue architecture — one code path for offline resilience, fully testable
- Reconnect replay uses jittered delay to prevent thundering herd
- IndexedDB protected from browser eviction via persistent storage request
- Documentation and UI copy are honest about what offline can and cannot do
- Playwright tests verify actual queue/replay behavior using explicit DOM events, not synthetic `setOffline` alone
- Offline tests run through nginx proxy to catch proxy-layer issues (SSE lesson)

**Non-Goals:**
- Multi-hour offline operation (holds expire in 30-90 minutes; no point caching longer)
- Offline bed search (stale availability data is dangerous — showing a bed that's taken is worse than showing nothing)
- CRDT or operational transform (bed holds are competitive claims, not mergeable data)
- Push notifications for queue resolution (requires backend push infrastructure — future)
- Periodic Background Sync for refreshing cached data (Chrome-only, future)
- Workbox BackgroundSyncPlugin (removed — see "Architecture decision: single queue" below)

## Design

### Architecture decision: single queue

**Decision:** Use only the app-level IndexedDB queue (`offlineQueue.ts`) for offline resilience. Do NOT use Workbox BackgroundSyncPlugin.

**Why (lessons from SSE stabilization and persona review):**

The original design used a dual-layer approach: app queue + Workbox BackgroundSync. Review by Riley Cho (QA), Sam Okafor (Performance), and Alex Chen (Architecture) identified critical problems:

1. **Untestable:** Playwright cannot test BackgroundSync behavior. The SW runs in a separate context with its own retry schedule. We cannot verify dedup in E2E tests. The SSE stabilization taught us: don't ship what you can't test.

2. **Duplicate requests:** Both layers can replay the same action. The idempotency key protects hold POSTs, but availability PATCHes have no idempotency protection — they're safe only by accident (absolute values). Any future incrementing operation would cause double-counting.

3. **Doubled reconnect load:** On reconnect, both the app queue and BackgroundSync fire, doubling request volume. Combined with SSE reconnection, this is a thundering herd.

4. **Narrow value:** BackgroundSync only helps when `navigator.onLine` lies (says online, fetch fails). This is handled better by a try/catch fallback in the online path that enqueues on failure.

**The single-queue pattern:**

```
if (!navigator.onLine) {
    await enqueueAction(...);       // offline: queue directly
} else {
    try {
        await api.post(...);         // online: try the request
    } catch (err) {
        await enqueueAction(...);   // online but failed: queue as fallback
    }
}
```

This makes the app-level queue the single retry mechanism in ALL scenarios:
- Offline (navigator.onLine false): enqueues immediately
- Online but network fails (navigator.onLine lies): catches error, enqueues
- Hospital Chrome (no SW): works — no SW dependency
- iOS Safari / Firefox (no BackgroundSync API): works — no BackgroundSync dependency

The service worker (`sw.ts`) is retained for precaching and runtime GET caching only.

### Reconnect replay with jitter

When the `online` event fires, add a random 0-2 second delay before calling `replayQueue()`. This prevents the thundering herd when a shelter's WiFi comes back and 5 coordinators reconnect simultaneously.

```typescript
const jitterMs = Math.floor(Math.random() * 2000);
await new Promise(r => setTimeout(r, jitterMs));
const result = await replayQueue();
```

The SSE reconnect in `useNotifications.ts` already uses exponential backoff with jitter. The queue replay must have the same discipline.

### IndexedDB persistence

Call `navigator.storage.persist()` at app startup. Without this, the browser can silently evict IndexedDB under storage pressure — a coordinator's queued hold vanishes without notification. Log whether persistence was granted.

### Hold expiry validation

Before replaying a `HOLD_BED` action, check:
```
if (Date.now() - action.timestamp > holdDurationMs - bufferMs) → skip, notify user "expired"
```

The hold duration is tenant-configurable (default 90 minutes). The 5-minute buffer prevents holds that would expire moments after creation.

For availability updates: no expiry — always replay. A stale availability update is still valuable.

### UI state machine for queued actions

```
QUEUED → SENDING → CONFIRMED
                 → CONFLICTED (409)
                 → EXPIRED (hold too old to replay)
                 → FAILED (network still down, will retry)
```

Visual treatment:
- **QUEUED:** Amber clock icon, "Hold queued — will send when online" in the reservation panel
- **SENDING:** Spinner, "Syncing..."
- **CONFIRMED:** Green check, transitions to normal hold UI with countdown
- **CONFLICTED:** Red alert, "Bed was taken while offline. [Search again]"
- **EXPIRED:** Gray, "Hold request expired (queued {N} min ago). [Search again]"
- **FAILED:** Amber retry icon, "Could not reach server. Will retry automatically."

State transitions are wired via custom DOM events (`fabt-queue-replaying`, `fabt-queue-replayed`) from Layout.tsx to OutreachSearch.tsx, allowing the reservation panel to reflect real-time replay status.

### Queue status indicator

A small badge in the header (near the notification bell) showing the count of pending queued actions. Visible only when count > 0. Clicking it opens a summary panel showing each queued action with its status.

### Honest offline banner

Replace:
```
"You are offline — your last search is still available. Actions will sync when connection returns."
```

With:
```
"You are offline. Cached searches are still visible. Bed holds and updates will be queued and sent when you reconnect."
```

The key difference: "queued and sent" (honest — might fail on replay) vs "will sync" (implies guaranteed success).

### Service worker changes

Switch from `generateSW` to `injectManifest` in `vite.config.ts`. Create `src/sw.ts`:
- Precache static assets (same as current generateSW)
- NetworkFirst for GET `/api/v1/*` with 5-second timeout (real-time bed data must not serve stale cache when network is available)
- **No BackgroundSyncPlugin** — the app-level queue handles all offline resilience

### Backend idempotency

Add `X-Idempotency-Key` support to `POST /api/v1/reservations`:
- If header present, check `reservation` table for existing hold with same user + idempotency key
- If found and still active: return the existing hold (200, not 201)
- If not found: create as normal
- Store the idempotency key on the reservation record (new nullable column)

This is a single Flyway migration adding `idempotency_key VARCHAR(36)` to the `reservation` table, plus a service-layer check.

### Documentation corrections

**FOR-COORDINATORS.md:** Replace "The app saves your work locally and sends it when you reconnect" with accurate description of what queues and what doesn't.

**en.json / es.json:** New keys for all queue states.

## Testing strategy

### Playwright event dispatch requirement

**Critical lesson from SSE stabilization:** Playwright's `context.setOffline(true)` only blocks network requests via Chrome DevTools Protocol. It does NOT:
- Change `navigator.onLine`
- Fire `online`/`offline` DOM events

Every Playwright test that expects queue replay must explicitly:
1. `context.setOffline(true)` to block network
2. `page.evaluate(() => window.dispatchEvent(new Event('offline')))` to trigger app detection
3. `context.setOffline(false)` to restore network
4. `page.evaluate(() => window.dispatchEvent(new Event('online')))` to trigger replay

Tests that rely on implicit detection are false confidence.

### Nginx proxy testing

All offline E2E tests must also run through the nginx proxy (`NGINX=1` Playwright project). The SSE buffering bug was invisible in Vite dev mode — offline queue replay has the same risk profile.

### Negative tests

- **Double dispatch:** Fire `online` event twice rapidly — verify no duplicate API calls
- **Expiry boundary:** Queue a hold at exactly (holdDuration - bufferMs) age — verify it's skipped
- **Expiry boundary minus 1ms:** Queue a hold at (holdDuration - bufferMs - 1) — verify it's replayed
- **IndexedDB unavailable:** Mock IndexedDB failure — verify app degrades gracefully (error shown, not crash)
- **SSE + replay race:** Go offline, enqueue, reconnect — verify SSE-triggered refetch doesn't show stale then fresh data
- **Concurrent replay:** Two `online` events within 100ms — verify `replayQueue()` is not called twice simultaneously

### Unit tests

Vitest unit tests for `offlineQueue.ts` using `fake-indexeddb`:
- Enqueue/dequeue ordering
- Hold expiry boundary conditions
- 409 conflict handling
- Non-409 error handling (actions remain in queue)
- Idempotency key uniqueness
- Concurrent replay guard

### Performance tests

Gatling simulation: 5 users replay queues simultaneously for the same shelter, verifying advisory lock contention stays within acceptable bounds and no data corruption occurs.

## Risks

- **`navigator.onLine` unreliability:** MDN explicitly calls this "inherently unreliable." Mitigated by the try/catch fallback pattern — the app queue catches failures even when `navigator.onLine` lies.
- **IndexedDB eviction:** Mobile browsers can silently evict storage. Mitigated by `navigator.storage.persist()` at startup. If denied, the queue works but is not eviction-proof.
- **Hold expiry race condition:** Hold queued at T, replayed at T+84min (just under 85min cutoff), server accepts, but hold expires 5 minutes later. Mitigated by the 5-minute buffer.
- **`injectManifest` migration:** Requires writing a custom service worker. If the SW has a bug, it could break caching. Mitigated by keeping the SW minimal (caching only, no BackgroundSync) and testing offline behavior through nginx.
- **Idempotency key column migration:** Lightweight — nullable column, no data migration, no index needed.
- **Thundering herd on reconnect:** Multiple coordinators reconnect simultaneously after shelter WiFi outage. Mitigated by 0-2s jittered delay before replay.
