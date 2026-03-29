## Why

When a DV shelter coordinator accepts or rejects a referral, the outreach worker has no way to know without manually refreshing the page. The walkthrough caption originally said "Darius gets notified instantly" — we corrected it to "when Darius refreshes" because no notification mechanism exists. This is a real UX gap: Darius is in a parking lot with a family, staring at his phone, not knowing if the shelter accepted.

The same gap applies to coordinators: when a new referral arrives, they don't know until they check. And when another coordinator updates bed availability, outreach workers on the search page see stale data until they refresh.

Server-Sent Events (SSE) is the right solution for our stack: one-directional server→client push, native Spring MVC support via `SseEmitter`, virtual threads handle long-lived connections cheaply, works through proxies, and `EventSource` auto-reconnects in the browser.

## What Changes

- **Backend**: New SSE endpoint `GET /api/v1/notifications/stream` returning `text/event-stream`. A `NotificationService` manages per-user `SseEmitter` connections and subscribes to `SpringEventBus` application events, filtering by tenant + user role and pushing relevant events.
- **Frontend**: `EventSource` connection established on login. Bell icon / notification badge in the header showing unread count. Notification dropdown with recent events. Auto-refresh of referral list when `dv-referral.responded` event arrives. Auto-refresh of search results when `availability.updated` event arrives.
- **Accessibility**: WAI-ARIA disclosure pattern (not menu) — `aria-expanded`, `aria-controls`, Escape-to-close, focus management. `aria-live="polite"` hidden region for screen reader announcements. Badge `aria-hidden="true"`. Keyboard: Enter/Space toggles, Tab through items, Escape closes.
- **Connection status**: Disconnect/reconnecting banner (Slack pattern) — hidden when connected, shown on disconnect with `role="status"` + `aria-live="polite"`. Brief "Reconnected" toast on recovery.
- **DV Safety**: Referral response notifications to outreach workers contain status + phone number (if accepted), never shelter address or name. Same zero-PII principle as the referral system itself. DV safety test asserts on actual SSE payload bytes, not just no-error.
- **Person-centered language**: Notification messages written for the person in crisis context — "A shelter responded to your referral" not "Referral response received".

## Capabilities

### New Capabilities
- `sse-notifications`: Server-Sent Events endpoint with per-user event filtering, notification bell UI, WCAG-compliant badge

### Modified Capabilities
- `dv-referral-notification`: Outreach workers receive real-time notification when referral is accepted/rejected (was manual refresh)

## Impact

- **Backend**: New `NotificationService`, `NotificationController` (SSE endpoint), `@EventListener` for domain events
- **Frontend**: New `NotificationBell.tsx` component, `useNotifications` hook with `EventSource`, Layout header modification
- **Security**: SSE endpoint requires JWT authentication, tenant-scoped event filtering
- **Testing**: Integration test for SSE event delivery, Playwright test for notification badge
- **Documentation**: Runbook update for SSE connection monitoring, walkthrough caption update
- No database schema changes (events are transient, not persisted)
