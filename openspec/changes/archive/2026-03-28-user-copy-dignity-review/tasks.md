## Tasks

### Setup

- [x] T-0: Create branch `feature/user-copy-dignity-review` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`).

### DV Label Change

- [x] T-1: Update `frontend/src/i18n/en.json` — change `search.dvSurvivor` from "DV Survivors" to "Safety Shelter" (REQ-COPY-1, REQ-COPY-5)
- [x] T-2: Update `frontend/src/i18n/es.json` — change `search.dvSurvivor` from "Sobrevivientes de VD" to "Refugio Seguro" (REQ-COPY-6)
- [x] T-3: Verified — dropdown uses labelId from i18n, not hardcoded (OutreachSearch.tsx:15)
- [x] T-4: Verified — value: 'DV_SURVIVOR' sent to API is separate from labelId (OutreachSearch.tsx:15)

### Freshness Badge Enhancement

- [x] T-5: Refactored DataAge.tsx to use i18n — "Fresh · Updated 12 minutes ago" format, translates to Spanish — add relative time description next to badge text (e.g., "Fresh · Updated 12 min ago") (REQ-COPY-3)
- [x] T-6: Added 7 i18n keys each in en.json + es.json (fresh, aging, stale, unknown, justNow, minutesAgo, hoursAgo) in en.json and es.json (REQ-COPY-5, REQ-COPY-6)

### Offline Banner Enhancement

- [x] T-7: Updated offline.banner i18n — "your last search is still available" reassurance (EN + ES)
- [x] T-8: i18n keys already exist — updated in-place in en.json and es.json

### Error Message Audit

- [x] T-9: Audited all error i18n strings — 2 outreach-facing messages updated (search.error, coord.error), admin errors acceptable as-is. "Hold This Bed" deferred per Simone's user testing recommendation.
- [x] T-10: Updated search.error and coord.error in both en.json + es.json — human, actionable, connection-focused

### Playwright Tests

- [x] T-11: Write `copy-dignity.spec.ts` — 4 tests: Safety Shelter dropdown, no-DV-terminology, freshness age, Spanish locale
- [x] T-12: Spanish locale test included — verifies "Refugio Seguro" after language switch
- [x] T-13: No existing tests assert on "DV Survivors" — no updates needed

### Verification

- [x] T-14: Playwright 122 passed (118 + 4 new copy-dignity), 0 failures
- [x] T-15: ESLint 0 errors, TypeScript 0 errors
- [x] T-16: Frontend build clean
- [x] T-17: CI green (CI, E2E Tests, CodeQL)
- [x] T-18: Merged to main, tagged v0.15.2, GitHub Release created
