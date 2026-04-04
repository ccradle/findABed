## Context

Three issues block external demos and erode persona trust. The DV referral expiration bug (#31) is the highest-severity item — a safety-critical workflow gap. README inaccuracies (#40) and GitHub markdown links (#39) are credibility gaps for procurement and funder audiences.

Current state:
- `ReferralTokenService.expireTokens()` runs every 60s, updates DB status to EXPIRED, but publishes no SSE event
- `NotificationService` handles `dv-referral.requested` and `dv-referral.responded` but not expired
- `CoordinatorDashboard.tsx` displays `remainingSeconds` as static text — no countdown, no button disable logic
- README.md and FOR-DEVELOPERS.md have hardcoded test counts that drift after every change
- 3 of 4 "Who It's For" cards on index.html link to `github.com/.../docs/*.md`
- `demo/for-cities.html` is the established template for audience HTML pages

## Goals / Non-Goals

**Goals:**
- Coordinators see real-time countdown and disabled buttons when DV referral tokens expire
- SSE pushes expiration events so coordinators don't need to refresh
- READMEs reflect accurate test counts and migration numbers
- All 4 audience cards link to on-domain HTML pages on findabed.org
- Riley's test matrix: positive tests proving requirements met, negative tests proving nothing broke

**Non-Goals:**
- Auto-generating test counts from CI (future improvement — this release fixes hardcoded values)
- Refactoring SSE infrastructure (the existing pattern is sound; we add one event type)
- Adding "update available" toast for service worker staleness (separate concern)
- Converting FOR-DEVELOPERS.md or PITCH-BRIEFS.md to HTML (not audience-facing pages)

## Decisions

### D1: Client-side countdown timer + SSE event (belt and suspenders)

The frontend will run a `setInterval` timer that decrements `remainingSeconds` every second. Independently, the backend will publish `dv-referral.expired` via SSE when the scheduled task expires tokens.

**Why both:** The 60-second scheduled task creates a gap — a token could expire between task runs. The client-side timer provides immediate visual feedback. The SSE event provides authoritative state sync. If SSE is delayed (nginx buffering, reconnection), the timer still disables buttons. If the timer drifts, SSE corrects it.

**Alternative considered:** SSE-only. Rejected because the 60-second batch window means up to 60s of stale UI. Client-only timer also rejected because it can drift from server time.

### D2: Disable buttons, don't hide them

When a referral expires, buttons become disabled with an "Expired" badge. Buttons are NOT hidden.

**Why:** Smashing Magazine UX research (2024) and crisis UI guidance both recommend showing disabled state over hiding. Sandra Kim (coordinator) needs to see what happened, not wonder where the referral went. Keisha Thompson (lived experience) deserves transparency in the process.

### D3: Publish event from expireTokens() using UPDATE...RETURNING

The `expireTokens()` method will use PostgreSQL `UPDATE ... RETURNING id` to atomically update and retrieve expired token IDs in a single statement, then publish a `dv-referral.expired` event with the list.

**Why:** The current `repository.expirePendingTokens()` returns only a count. We need the IDs to tell the frontend which specific referrals expired. Using `UPDATE ... RETURNING` is atomic — no race condition where a coordinator could accept a token between a SELECT and UPDATE (which was the risk with a two-step query-then-update pattern). PostgreSQL natively supports `RETURNING`.

**Alternative considered:** SELECT FOR UPDATE then UPDATE — rejected because `UPDATE ... RETURNING` is simpler and equally safe within `@Transactional`. Database trigger or LISTEN/NOTIFY — rejected, adds infrastructure complexity for a simple use case.

### D4: Audience pages follow for-cities.html pattern exactly

New HTML pages replicate the structure of `demo/for-cities.html`: embedded CSS (no external stylesheet), FAQ structured data, OG tags, dark mode via `prefers-color-scheme`, skip link, semantic HTML.

**Why:** Consistency. The pattern is proven, WCAG-compliant, and SEO-optimized. No build step needed for a static site.

### D5: Test counts updated manually with verification comment

Each hardcoded count gets updated. A comment is NOT added (counts in prose don't take comments). Instead, the tasks include a verification step to grep-count before updating.

**Why:** Auto-generation would require CI pipeline changes — out of scope. Manual update with a documented verification command is sufficient and matches current workflow.

### D6: useNotifications.ts hook dispatches window event for expired referrals

The frontend SSE event flow is: `EventSource` → `useNotifications.ts` hook (switch on event type) → `window.dispatchEvent()` → page-level listener. The hook currently handles `dv-referral.responded`, `dv-referral.requested`, and `availability.updated`. A new case for `dv-referral.expired` will dispatch an `SSE_REFERRAL_EXPIRED` window event that `CoordinatorDashboard.tsx` listens for.

**Why:** This is the established pattern. Skipping the hook layer (listening directly in the dashboard) would break the single-responsibility model and miss the buffer/replay integration.

### D7: All user-facing text uses i18n message IDs

New UI text (expired badge, expiration error message, countdown format) uses `react-intl` `FormattedMessage` with IDs defined in both `en.json` and `es.json`. This follows the existing pattern for referral text (`referral.accept`, `referral.reject`).

**Why:** The app supports English and Spanish. Keisha Thompson (lived experience) and language-switching spec require all visible text to be internationalized. Hardcoded English strings would break the Spanish coordinator experience.

### D8: Audience page link text is audience-specific

Each "Who It's For" card gets intentional link text instead of generic "Read more": coordinators get "Quick Start Guide", CoC admins get "Admin Overview", funders get "Impact Report". City Officials already has "Evaluation Guide". This follows Simone Okafor's brand guidance for audience-differentiated messaging.

## Risks / Trade-offs

**[Risk] Client-side timer drifts from server time** → Mitigation: Timer is visual only. SSE event is authoritative. When SSE `dv-referral.expired` arrives, it overrides the timer state. Max drift is the 60-second batch interval.

**[Risk] SSE buffering in nginx hides expiration events** → Mitigation: Lesson learned from v0.22.1 — must test through nginx proxy, not just Vite dev server. The existing `proxy_buffering off` and `X-Accel-Buffering: no` headers should handle this, but we verify in testing.

**[Risk] Race between expiration and accept/reject** → Mitigation: Using `UPDATE ... RETURNING id` makes the expiration atomic — no window for a concurrent accept to slip in between a SELECT and UPDATE. The event is published inside the `@Transactional` method following the same pattern as `acceptToken()` and `rejectToken()` (lines 152, 192 of `ReferralTokenService.java`), which already successfully publish `dv-referral.responded` within their transactions.

**[Risk] Stale service worker caches old CoordinatorDashboard.tsx** → Mitigation: Lesson learned — test in incognito or clear site data after build. The `autoUpdate` SW config handles this for normal users within one navigation cycle.

**[Risk] Test counts become stale again after this release** → Mitigation: Accepted. A future change could add CI badges or auto-generation. For now, accurate-at-release is sufficient.
