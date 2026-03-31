## MODIFIED Requirements

### Requirement: Switch to @microsoft/fetch-event-source

The `useNotifications` hook SHALL replace native `EventSource` with `@microsoft/fetch-event-source` for the SSE notification stream.

**Acceptance criteria:**
- SSE connection uses `Authorization: Bearer <jwt>` header (not query-param `?token=`)
- No `?token=` parameter in SSE request URLs
- Connection auto-closes when tab is backgrounded (Page Visibility API)
- Connection auto-reconnects when tab is foregrounded, with `Last-Event-ID`
- `@microsoft/fetch-event-source` added to `package.json` dependencies

### Requirement: Exponential backoff with jitter on reconnect

On SSE connection failure, the client SHALL retry with exponential backoff (initial 1s, max 30s, factor 2) and 30% jitter.

**Acceptance criteria:**
- First retry: ~1 second
- Second retry: ~2 seconds
- Third retry: ~4 seconds
- Max retry interval: 30 seconds
- Jitter prevents thundering herd (±30% randomization)
- Retry counter resets to 0 on successful message receipt

### Requirement: Remove catchUp refetch pattern

The `catchUp()` function and its associated `SSE_REFERRAL_UPDATE` / `SSE_AVAILABILITY_UPDATE` window event dispatching SHALL be removed entirely. Missed events are handled by server-side `Last-Event-ID` replay.

**Acceptance criteria:**
- No `window.dispatchEvent(new Event(SSE_REFERRAL_UPDATE))` on reconnect
- No `window.dispatchEvent(new Event(SSE_AVAILABILITY_UPDATE))` on reconnect
- Reconnection does NOT trigger `fetchBeds()` or `fetchReferrals()`
- Only a server `refresh` event type triggers a bulk refetch (when gap is too large)
- Playwright test verifies: over 30 seconds, max 1 request to `/api/v1/queries/beds` (initial load only)

### Requirement: Page Visibility integration

SSE connection SHALL close when the browser tab is hidden and reconnect when the tab becomes visible.

**Acceptance criteria:**
- `fetch-event-source` `openWhenHidden: false` option used
- Backgrounding the tab closes the SSE connection (verified by Playwright)
- Foregrounding the tab reconnects with `Last-Event-ID` (verified by Playwright)
- No visible UI disruption on reconnect after foregrounding
