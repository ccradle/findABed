## Context

The offline queue (offlineQueue.ts) handles bed holds and availability updates via IndexedDB. DV referrals are intentionally excluded because they contain sensitive operational data (callback number, household size, special needs) that would persist on-device. The zero-PII design depends on data living on the server briefly and being hard-deleted within 24 hours — persisting in browser storage undermines this.

Currently: the Request Referral button stays enabled offline, the modal opens, the worker fills the form, submit fails with a network error caught in `submitReferral()` (OutreachSearch.tsx:291), the error renders behind the modal. No user feedback.

Research findings (NNEDV Safety Net, WCAG, crisis UX):
- No DV platform in the sector has an offline referral workflow
- Never disable buttons with `disabled` attribute — use `aria-disabled="true"` (Adrian Roselli, Axess Lab)
- Crisis UX: action-oriented messages ("Call the shelter"), not explanatory ("Service unavailable because...")
- PWA best practice: never let a form submit appear to succeed while silently dropping it

## Goals / Non-Goals

**Goals:**
- Prevent the referral modal from opening when offline (no sensitive data entry on compromised device)
- Show clear, action-oriented feedback when worker taps Request Referral offline
- Update offline banner to explicitly mention referral limitation
- Document the limitation in coordinator/outreach worker materials
- Accessible implementation (aria-disabled, screen reader announcements)

**Non-Goals:**
- Queuing DV referrals offline (intentionally excluded — security decision, not a gap)
- "Deferred referral" intent capture (future consideration — store only a non-PII reminder flag)
- Offline help page (`/offline-help` route — good idea from research, separate change)

## Design

**1. Request Referral button offline state:**

```tsx
// In OutreachSearch.tsx, where Request Referral buttons render:
const isOnline = useOnlineStatus(); // existing hook or navigator.onLine + event listeners

<button
  data-testid={`request-referral-${r.shelterId}-${a.populationType}`}
  aria-disabled={!isOnline}
  onClick={() => {
    if (!isOnline) {
      // Show inline message, do NOT open modal
      setOfflineReferralMessage(shelterId);
      return;
    }
    openReferralModal(shelterId, popType);
  }}
  style={{
    // Visual: muted when offline but still visible and focusable
    opacity: isOnline ? 1 : 0.5,
    cursor: isOnline ? 'pointer' : 'default',
  }}
>
  Request Referral
</button>
```

**2. Inline offline message (appears below the DV shelter card):**

Action-oriented, not explanatory (crisis UX principle):

> "Referral requests need a connection. Call [shelter phone] to request a referral by phone."

The shelter phone is already in the search result data (`r.phone`). Display it as a clickable `tel:` link so the worker can call directly from the message. This follows the "deferred referral" pattern — the worker completes the referral via phone call, no data stored on device.

If the shelter is a DV shelter and the phone is redacted (which it shouldn't be — phone is NOT redacted, only address is), show: "Referral requests need a connection. Move to an area with signal and try again."

**3. Offline banner update:**

Current: "You are offline. Cached searches are still visible. Bed holds and updates will be queued and sent when you reconnect."

Updated: "You are offline. Cached searches are still visible. Bed holds and updates will be queued and sent when you reconnect. DV referral requests require a connection."

**4. Online/offline state management:**

OutreachSearch.tsx already imports from offlineQueue.ts. Add a `useOnlineStatus()` hook or use the existing `navigator.onLine` pattern with `online`/`offline` event listeners (same pattern as OfflineBanner.tsx).

**5. i18n keys:**

```json
"search.referralOffline": "Referral requests need a connection. Call {phone} to request a referral by phone.",
"search.referralOfflineNoPhone": "Referral requests need a connection. Move to an area with signal and try again.",
"offline.banner": "You are offline. Cached searches are still visible. Bed holds and updates will be queued and sent when you reconnect. DV referral requests require a connection."
```

Spanish translations follow the same pattern.

**6. Accessibility:**

- `aria-disabled="true"` preserves keyboard focus (unlike `disabled` which removes from tab order)
- Inline message announced via `aria-live="polite"` region
- Muted visual state (opacity 0.5) provides visual cue without removing the element

**7. Second line of defense — captive portal / navigator.onLine lies:**

`navigator.onLine` reports `true` on captive portals and broken WiFi. The offline guard won't trigger, so the modal opens normally. When `submitReferral()` catches a network error:

- Current behavior: `setError()` renders behind the modal (z-index issue) — user sees nothing
- New behavior: detect network errors in the catch block and set a `referralError` state that renders INSIDE the modal, above the Submit button

```tsx
// In submitReferral():
} catch (err) {
  if (err instanceof TypeError || (err instanceof ApiError && err.status === 0)) {
    // Network error — show inside modal
    setReferralError(intl.formatMessage({ id: 'referral.networkError' }));
  } else {
    setError(intl.formatMessage({ id: 'search.error' }));
  }
}
```

This ensures every path — genuine offline, captive portal, flaky WiFi — gives the worker visible, actionable feedback.

## Risks

- **Phone number availability:** DV shelter phone IS included in search results (not redacted — only address is). Verified in BedSearchService.java. If this changes in the future, the fallback message ("Move to an area with signal") handles it.
- **False offline detection:** `navigator.onLine` can lie (captive portals). Mitigated by the second-line-of-defense: network errors in `submitReferral()` now show inside the modal, not behind it.
- **Render cascade on toggle:** `useOnlineStatus()` triggers re-render on online/offline. With 17 shelter cards, each with 1-2 referral buttons, this is ~34 button state recalculations. Trivial for modern React but worth profiling if shelter count grows significantly.
