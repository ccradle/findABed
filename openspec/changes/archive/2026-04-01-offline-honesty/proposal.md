## Why

The offline banner tells users "Actions will sync when connection returns." This is false. Only shelter creation (admin operation) queues offline. The two operations that matter most to field workers — bed holds and availability updates — silently fail when offline. The queue replay function (`replayQueue()`) exists but is never called.

Darius (outreach worker) tests the platform by saying: "Hold a bed, lose signal, come back online. What happened to my hold?" Today the answer is: the hold vanished and the banner lied. This is a trust-destroying gap for the core use case.

The infrastructure is 80% built — `offlineQueue.ts` (IndexedDB-backed), `useOnlineStatus` hook, `OfflineBanner` component. The work is wiring it to the critical operations, adding honest UI states, and ensuring queued actions are validated before replay.

## What Changes

**Tier 1 — Wire existing infrastructure to critical operations:**
- Wire `enqueueAction()` to bed holds (`OutreachSearch.tsx`) and availability updates (`CoordinatorDashboard.tsx`) when offline
- Add `online` event listener that calls `replayQueue()` on reconnect with jittered delay (0-2s) to prevent thundering herd
- Add hold expiry validation — skip replaying holds older than the tenant's hold duration TTL
- Show "queued, not confirmed" UI state — never display success for unsynced actions
- Show conflict/expiry notifications when replay encounters 409 or expired holds
- Fix offline banner copy: honest about what works offline and what doesn't

**Tier 2 — Defense-in-depth for spotty signal:**
- Switch vite-plugin-pwa from `generateSW` to `injectManifest` mode (caching only — no BackgroundSync)
- Add try/catch fallback in the online code path: if `navigator.onLine` is `true` but the fetch fails, enqueue to the app-level queue rather than silently failing. This makes the app queue the single retry mechanism in ALL offline scenarios.
- Add `X-Idempotency-Key` header to prevent double-replay
- Request persistent storage via `navigator.storage.persist()` to protect IndexedDB from browser eviction

**Stability hardening (lessons from SSE stabilization):**
- All Playwright offline tests must explicitly dispatch `online`/`offline` DOM events (Playwright's `setOffline()` does NOT fire these)
- Run offline E2E suite through nginx proxy (`NGINX=1`) — same gap that burned us with SSE
- Add Vitest unit tests for offlineQueue.ts boundary conditions (expiry math, conflict handling, concurrent replay)
- Add negative tests: double replay, expired hold boundary, IndexedDB eviction, SSE+replay race

**Testing:**
- Fix the misleading Playwright offline test to verify actual queue/replay behavior
- Add tests for hold expiry, conflict resolution, and queue status visibility
- Add negative tests for failure modes
- Add Gatling simulation for concurrent queue replay

## Capabilities

### New Capabilities
_None — all changes modify existing capabilities._

### Modified Capabilities
- `pwa-shell`: Wire offline queue to hold and availability operations, add replay trigger, add honest UI states
- `offline-behavior`: Fix misleading test assertions, add queue/replay/conflict/expiry tests, add negative tests

## Impact

- **Frontend:** `OutreachSearch.tsx` — offline check + enqueue for bed holds; try/catch fallback for online failures
- **Frontend:** `CoordinatorDashboard.tsx` — offline check + enqueue for availability updates; try/catch fallback
- **Frontend:** `offlineQueue.ts` — add hold expiry validation, queue status query
- **Frontend:** `Layout.tsx` — add `online` event listener calling `replayQueue()` with jittered delay
- **Frontend:** `OfflineBanner.tsx` — honest copy, queue status indicator
- **Frontend:** New `QueueStatusIndicator` component — shows pending/syncing/conflicted states
- **Frontend:** `vite.config.ts` — switch to `injectManifest` (caching only)
- **Frontend:** New `src/sw.ts` — custom service worker for precaching and runtime caching (no BackgroundSync)
- **Frontend:** `en.json` / `es.json` — new i18n keys for queue states
- **Frontend:** App startup — request `navigator.storage.persist()` to protect IndexedDB
- **Backend:** Add `X-Idempotency-Key` support on hold endpoint (idempotent POST)
- **Tests:** Rewrite `offline-behavior.spec.ts` with real assertions and explicit DOM event dispatch
- **Tests:** New negative tests for failure modes (double replay, expiry boundary, eviction, SSE race)
- **Tests:** Vitest unit tests for `offlineQueue.ts`
- **Tests:** Gatling simulation for concurrent queue replay
- **Tests:** Nginx proxy offline test suite
- **Docs:** `FOR-COORDINATORS.md` — correct offline claims
- **Database:** Flyway V30 — add nullable `idempotency_key VARCHAR(36)` to `reservation` table (no data migration)
