## Tasks

### Implementation
- [x] Task 0: Create feature branch — `git checkout -b dv-referral-offline-guard main`
- [x] Task 1: Import `useOnlineStatus()` hook in OutreachSearch.tsx (already exists in hooks/, used by OfflineBanner)
- [x] Task 2: Request Referral button — add `aria-disabled="true"` (NOT `disabled`) and opacity 0.5 when offline
- [x] Task 3: Request Referral button — prevent modal open when offline, show inline message with shelter phone `tel:` link in `aria-live="polite"` region
- [x] Task 4: Second line of defense — if `submitReferral()` catches a network error despite `navigator.onLine` lying (captive portal), show the error INSIDE the modal (not behind it via setError which renders under the modal z-index)
- [x] Task 5: Update offline banner i18n — append "DV referral requests require a connection" to `offline.banner` key (en.json + es.json)
- [x] Task 6: Add i18n keys: `search.referralOffline` (with `{phone}` placeholder), `search.referralOfflineNoPhone`, `referral.networkError` (en.json + es.json)
- [x] Task 7: Restore referral button state on `online` event (clear aria-disabled, dismiss inline messages)

### Positive tests (new behavior works)
- [x] Task 8: Playwright test — Request Referral button has `aria-disabled="true"` when offline (NOT `disabled` attribute)
- [x] Task 9: Playwright test — tapping offline referral button shows inline message with `tel:` link, `referral-modal` does NOT exist in DOM
- [x] Task 10: Playwright test — offline banner text includes "DV referral requests require a connection"
- [x] Task 11: Playwright test — connectivity restored: `aria-disabled` removed, inline messages dismissed, button clickable again
- [x] Task 12: Playwright test — captive portal fallback: online but network fails, submit referral shows error INSIDE modal (not behind it)

### Negative/regression tests (existing behavior preserved)
- [x] Task 13: Playwright test — online referral flow still works end-to-end after guard added (regression: modal opens, form fills, submit succeeds, modal closes)
- [x] Task 14: Playwright test — Hold This Bed buttons are NOT affected by offline guard (no aria-disabled, still queue offline as before)
- [x] Task 15: Playwright test — rapid online/offline toggle stabilizes (button state doesn't thrash, no stale inline messages)
- [x] Task 16: Verify existing offline-behavior.spec.ts test 1 ("offline banner appears") still passes with updated banner copy — uses regex `/offline/i` which still matches

### Documentation
- [x] Task 17: Update FOR-COORDINATORS.md — "What works offline" section: green/red checklist (holds queue offline, referrals need connection, phone fallback)
- [x] Task 18: ESLint + TypeScript check on all modified files
- [x] Task 19: Run full Playwright suite — 391 passed, 10 skipped, 1 unrelated failure (dv-referral coordinator badge: API latency under 300+ test load — passed in chromium, passed in isolation with trace, passed with our DV tests preceding it; screenshot shows "Loading shelters..." not error)
- [x] Task 20: Run backend tests — passed (exit code 0, no backend changes)
