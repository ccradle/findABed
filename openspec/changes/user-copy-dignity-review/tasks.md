## Tasks

### Setup

- [ ] T-0: Create branch `feature/user-copy-dignity-review` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`).

### DV Label Change

- [ ] T-1: Update `frontend/src/i18n/en.json` — change `search.dvSurvivor` from "DV Survivors" to "Safety Shelter" (REQ-COPY-1, REQ-COPY-5)
- [ ] T-2: Update `frontend/src/i18n/es.json` — change `search.dvSurvivor` from "Sobrevivientes de VD" to "Refugio Seguro" (REQ-COPY-6)
- [ ] T-3: Verify the population type dropdown in OutreachSearch.tsx reads the label from i18n (not hardcoded) (REQ-COPY-2)
- [ ] T-4: Verify the API request still sends `populationType: "DV_SURVIVOR"` regardless of display label

### Freshness Badge Enhancement

- [ ] T-5: Update `frontend/src/components/DataAge.tsx` — add relative time description next to badge text (e.g., "Fresh · Updated 12 min ago") (REQ-COPY-3)
- [ ] T-6: Add i18n keys for freshness descriptions in en.json and es.json (REQ-COPY-5, REQ-COPY-6)

### Offline Banner Enhancement

- [ ] T-7: Update `frontend/src/components/OfflineBanner.tsx` — add "your last search is still available" reassurance (REQ-COPY-4)
- [ ] T-8: Add i18n keys for offline reassurance in en.json and es.json

### Error Message Audit

- [ ] T-9: Audit all user-facing error messages across the frontend — verify they are human-readable and actionable, not technical
- [ ] T-10: Update any clinical error messages found (add i18n keys as needed)

### Playwright Tests

- [ ] T-11: Write `e2e/playwright/tests/copy-dignity.spec.ts` — verify "Safety Shelter" in dropdown, freshness description text, offline banner text (REQ-COPY-7)
- [ ] T-12: Add Spanish locale test — verify "Refugio Seguro" renders in Spanish mode
- [ ] T-13: Update any existing Playwright tests that assert on old label text ("DV Survivors")

### Verification

- [ ] T-14: Run full Playwright suite — all green
- [ ] T-15: Run `npm run lint` and `npx tsc --noEmit` — zero errors
- [ ] T-16: Frontend builds clean
- [ ] T-17: CI green on all jobs
- [ ] T-18: Merge to main, tag
