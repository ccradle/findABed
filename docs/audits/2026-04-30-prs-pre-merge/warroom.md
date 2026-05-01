# Pre-merge warroom review — v0.55.0 PRs (docs#8 + code#168)

## Round opener

The pair of PRs is broadly mergeable. The v0.55.0 release gate (transitional-reentry-support truthfulness + code-side hardening + reentry capability deep-dive) is materially in place: the §16.B serialization gate at `ReservationResponse.from(...)` is at the right architectural layer, the §13.A audit triplet emits no plaintext, the §13.C purge has a 100-iteration safety cap with `fixedDelay=900_000`, the strict axe-core spec on `reentry-story.html` is appropriately strict, the runbook §5.0 + §6 are commendably ground-truthed, and the new `for-coc-admins.html` Reentry-Mode section is operator-actionable. **Verdict: FIX-AND-MERGE.** Findings: **2 BLOCKER, 4 HIGH, 7 MEDIUM, 5 NIT.** The two blockers are both quick fixes (one missing tile in the docs repo, one stale tasks.md note that contradicts shipped code).

## Persona positions

### Casey

**Verdict: FIX-AND-MERGE.** The legal-language posture across the PR pair is unusually clean. `for-coc-admins.html:236` ("designed to support HUD reporting requirements but has not been certified by HUD"), `:294` ("It has not been independently certified as compliant"), and `for-funders.html:286` ("Designed to support VAWA and FVPSA requirements") are all the affirmative-disclosure pattern. The reentry-story.html footer (lines 167, 184) uses "Designed to support reentry coordination" + "does not constitute legal advice." `feedback_no_named_stakeholders` is honored — "Onslow County" is a geographic identifier (V95 seed), not a CoC/hospital/program name. **One finding (NIT-C1):** `ReservationService.java:231` and `ReservationRepository.java:80` carry inline comments asserting "plaintext never touches disk" — true of the code path but absolute-bound; recommend "plaintext is not persisted by this code path" framing per `feedback_legal_scan_in_comments`. Defer to v0.55.1.

### Marcus

**Verdict: FIX-AND-MERGE.** The §16.B serialization gate is correctly defense-in-depth: `ReservationResponse.from(r, ...)` lines 80-92 read `TenantContext.getReentryMode()` and force `clientName/clientDob/holdNotes = null` regardless of underlying ciphertext, with `getReentryMode()` returning false when unbound (TenantContext.java:73-75). That closes the parallel-path drift Round 5 was worried about. The 60s `reentryModeCache` TTL on `JwtService` is a good ceiling on flag-flip latency given a 15min token TTL. **One finding (HIGH-M1):** the runbook §6 "PII purge verification" subsection (lines 600-625) is honest about the metric gap, but the public claim in `for-funders.html:285` says "encrypted at rest with a per-tenant key, erased no later than 25 hours after the hold ends. Default-off." That's correct — but the runbook's §6.5 step 2 SQL probe (line 630-645) is the only post-deploy verification operators have, and it requires a candidate row that's already 25h old. Recommend adding a "first-run waiver" sentence: the probe will return 0 rows on a fresh deploy because no resolved-and-aged rows exist yet. Without that, an operator running step 2 immediately post-deploy will see "0 rows = pass" without actually exercising the purge.

### Tomás

**Verdict: FIX-AND-MERGE.** `reentry-story.html` is structurally sound: real `<h1>` + 5 `<h2>` (lines 65, 75, 81, 106, 143, 159), `<section aria-labelledby="...">` per section, `<nav aria-label="See also">` (line 173), explicit skip-link (line 62), 6 `<img>` with semantic alt text (e.g., line 91 "Outreach search with shelter-type chips for Transitional Housing... filled-solid; county dropdown shown but not narrowed" — describes what's *shown*, which is the right call for screenshot a11y), and the §10 contrast probe is GREEN (0 violations). The strict-zero `reentry-story-a11y.spec.ts` test (line 56) is appropriately strict given the inaugural release of this page. **One finding (MEDIUM-T1):** the skip-link on `reentry-story.html:62` uses inline `onfocus`/`onblur` to position it at `left:16px,top:16px`. That works but is a non-standard pattern; the rest of the audience pages use a CSS `.skip-link:focus { top: 0; }` pattern (e.g., `index.html:99-105`). Strict axe is silent on this, but a future regression is more likely if the patterns drift. Defer to v0.55.1 styling-consistency pass.

### Keisha

**Verdict: MERGE AS-IS.** The banned-words grep across all 12 demo HTML files returns **zero matches** for ex-offender, returning citizen, justice-involved, formerly incarcerated, reentering population, individuals with criminal histories, person-noun "felon", or person-noun "offender". The terms "felony" / "felonies" appear strictly as offense-category nouns ("excluding sex offenses, accepts pending charges, and requires sobriety on intake" — `reentry-story.html:115`), never as person-labelling. `for-coc-admins.html:301` says "people returning from incarceration or other institutional settings" — exactly the dignity-preserving framing. `reentry-story.html:72` introduces Andre as "Andre is getting out" (not "an inmate"); :77 frames the work as "Just the bed... which shelter in this county can hold a bed for Andre tonight" — the person is named, the offense is contextual to eligibility filtering, never to identity. No findings.

### Maria

**Verdict: FIX-AND-MERGE.** The 5 new ES keys (`hold.help.clientName`, `hold.help.clientDob`, `hold.help.notes`, `shelter.eligibility.notes.help`, plus the reconciled `hold.clientAttributionPrivacyNote`) are functionally correct on lexical comparison vs. their EN counterparts at en.json:723-727 / es.json:723-727. "A más tardar 25 horas" is the right rendering of "no later than 25 hours" (it's the same affirmative-bound pattern). "Después de que la reserva termine" (es.json:724-726) is colloquial-natural for "after the hold ends." `shelter.eligibility.notes.help` (es.json:727) is well-rendered: "Texto libre que se muestra a los trabajadores de extensión que reservan camas. No pegue información específica del cliente aquí — este campo describe la política de ingreso del refugio, no a una persona en particular." **One finding (MEDIUM-MA1):** `hold.help.notes` (es.json:726) translates "navigator phone number" as "número de teléfono del navegador" — "navegador" is technically correct but "navegador de reentrada" or "trabajador de reingreso" is more concrete; the bare "navegador" is also browser/web-navigator in Spanish technical contexts. Real-Maria review (filed v0.55.1) should resolve. Functionally serviceable for v0.55 ship.

### Demetrius

**Verdict: MERGE AS-IS.** `reentry-story.html` voice respects navigators and clients. The Andre framing ("his navigator has worked toward this day for weeks", "The release paperwork is in. The bus ticket is in." — lines 72, 76) puts the navigator's labor and Andre's personhood ahead of any system framing. The pivotal quote on line 145 — "the platform is honest about 'no.' That's most of what I need it to be honest about. The rest of the work is mine." — does the right thing: it puts the platform in its place (a tool), and the human relationship outside it. The §4 failure-path framing on line 153 ("The platform's job ends here; the navigator's job continues outside it") is the dignity-respecting truth, not a marketing claim. The new `for-coc-admins.html` reentry section (lines 299-339) uses "people returning from incarceration" once and otherwise stays operational. No findings.

### Simone

**Verdict: FIX-AND-MERGE.** The runbook §5.0 (lines 229-321) is unusually well-grounded — file lists are exact (1 root + 11 demo HTML + 18 PNGs), the Cloudflare "Purge Everything" operator decision is documented with the rationale, the `curl ... %{size_download}` post-purge verification probe is concrete (~18376 bytes vs the 592-byte SPA fallback), and the SW caveat from `feedback_stale_sw_on_deploy` is called out. §6 verification curls (lines 430-645) are reasonable and the rollback matrix (assumed §7) covers the static-only failure path implicitly via the bundled-deploy posture. The honest-disclosure of the purge-SLA metric gap (line 612-625, "log-parse fallback (preferred for v0.55)") is exactly the truthfulness-over-claim pattern the Round 3 warroom committed to. **One finding (HIGH-S1):** runbook §6.5 step 1 (line 607) `curl /actuator/scheduledtasks` will fail unless `management.endpoints.web.exposure.include` is configured to expose `scheduledtasks` — the runbook needs a one-line precondition check or a clear "if 404, fall through to log-parse." A reviewer using only step 1 would interpret a 404 as "purge not registered."

### Devon

**Verdict: FIX-AND-MERGE.** `for-coc-admins.html:299-339` is a substantive ~250-word new section that gives a CoC admin onboarding cold the right shape: (1) what flipping `reentryMode` does, two surfaces enumerated, (2) default-off + admin-controlled + no-developer-needed, (3) privacy posture for hold-attribution PII with the "no later than 25 hours" affirmative-bound and the explicit unmonitored-SLA disclosure, (4) two cross-links — the operator walkthrough (`reentry-story.html`) and the user guide. That's enough to act on. The §15.5-15.7 demo flow walkthrough steps (tasks.md:236-237) name the exact account (`outreach@blueridge.fabt.org` / `cocadmin@blueridge.fabt.org` / `admin123`) and the exact actions — operator-followable. **One finding (MEDIUM-D1):** §15.6 says "filter for a county where the only reentry shelter excludes a specific offense type" but the reentry-06 capture spec was actually re-implemented as an empty-state path (TRANSITIONAL + Buncombe + accepts-felonies → 0 results, per tasks.md §7.1). The runbook §15.6 wording will lead an operator down a path that doesn't match what the screenshot actually shows. Recommend rewording to match: "filter for TRANSITIONAL + Buncombe + accepts-felonies and verify the empty-state banner renders."

### Riley

**Verdict: FIX-AND-MERGE.** R-RR-1 (the @Scheduled wrapper concern) is closed by the §13.A.4 + §13.C.2 architecture: the scheduler `ReferralTokenPurgeService.purgeExpiredHoldAttribution()` (lines 110-124) calls `reservationService.purgeExpiredHoldAttribution(cutoff)` and the service-layer method does ALL the work (loop, count, audit emit). The integration test in §12.5.5 (tasks.md line 98) is unchecked but the existing `HoldAttributionIntegrationTest` already exercises the service-layer entry point per tasks.md §13.A.5 ("4 tests"). Cross-page cohesion is good: each audience page mentions reentry in a tone fitting its audience (`for-coordinators.html:234-251` operational, `for-funders.html:246-253` strategic, `for-coc-admins.html:299-339` administrative). **One finding (MEDIUM-R1):** tasks.md §12.5.5 is unchecked but the runbook §15.x assumes scheduled-invocation correctness. If the §12.5.5 IT was intended as the gate, it needs to land before merge OR the spec needs to acknowledge the existing IT coverage explicitly so reviewers don't trip.

### Alex

**Verdict: FIX-AND-MERGE — one HIGH.** §16.B is at the right layer: `ReservationResponse.from(Reservation r, String shelterName, String shelterPhone)` at lines 80-92 is the single DTO factory both single-resource and list endpoints route through (line 72-74 single-arg delegates to three-arg). Future controllers building responses cannot bypass it without bypassing `ReservationResponse` entirely. The §13.A audit payloads at `ReservationService.java:265-277` (write-side) and lines 600-614 (read-side) emit `reservation_id` + `fields_recorded` array OR `shelter_id` + `throttle_key` + `first_seen_at` — **zero plaintext, zero ciphertext** per design D11. `recordPiiReadIfPresent` (line 579) deliberately omits `reservation_id` from the detail blob to preserve the throttle (lines 668-674 explain). The §13.C purge bounded-loop at `ReservationService.java:457-473` has the explicit `if (batches >= 100) { log.warn(...); break; }` safety cap with operator-meaningful detail. No infinite-loop on misconfig. **One finding (HIGH-A1):** tasks.md §11.3 says "`<details open>` so help text + inputs render visible without click" but `HoldDialog.tsx:241` ships `<details data-testid="hold-attribution-toggle">` with **no `open` attribute**. The dialog ships collapsed-by-default. That's a genuine architectural choice (warroom Round 2 "privacy note OUTSIDE collapsed details, per-input help text inside"), and it is what `reentry-04` screenshot in the story page captures (the screenshot must have been taken after a click). Either tasks.md §11.3 needs to be corrected, or `<details open>` needs to be re-added; ship-as-is leaves the spec wording lying about the code.

### Sam

**Verdict: FIX-AND-MERGE — one BLOCKER.** `HoldDialog.tsx:218` (`{user?.reentryMode && (...)}`) and `AuthContext.tsx:60` (`reentryMode: payload.reentryMode === true`) are both strict-true semantics; the parser test pinning is correct. The Playwright specs are reasonably scoped — `reentry-mode-gate.spec.ts` keys off `[data-testid="reentry-advanced-filters"]`, `[data-testid="reentry-pii-fields"]`, `[data-testid="reentry-eligibility-section"]` (not DOM-shape brittleness), and the strict axe spec on the new HTML page exercises file:// loading correctly with FABT_DOCS_ROOT override. **BLOCKER-S1:** the **root `index.html` "See It Work" grid (lines 424-445) does NOT contain a 5th tile for `demo/reentry-story.html`** — the four tiles are Platform Walkthrough, DV Referral Flow, HMIS Bridge, CoC Analytics. tasks.md §9.1 says "add the 5th tile to the See It Work grid pointing to demo/reentry-story.html" and is unchecked. Runbook §15.4a calls for verifying "5th 'Reentry Walkthrough' tile" post-deploy. **The static-content scp will succeed but the live site will be missing the front-door entry point to the new capability.** This is the load-bearing miss because the OG tags + canonical on `reentry-story.html` are excellent (lines 9-17) but the index has no path TO the page from the front door.

## Consensus prioritization

| # | Severity | Finding | File / loc | Persona consensus | Action | Block merge? |
|---|---|---|---|---|---|---|
| 1 | BLOCKER | "See It Work" grid missing 5th tile for `reentry-story.html` | `index.html:424-445` | Sam, Riley, Devon | Add 5th tile + cross-link before merge; tasks.md §9.1 already names this | YES |
| 2 | BLOCKER | tasks.md §11.3 claims `<details open>` but code ships collapsed | `tasks.md:82` vs `HoldDialog.tsx:241` | Alex, Sam | Either reopen the details OR amend tasks.md to match shipped behavior | YES (tasks/code drift breaks `/opsx:archive`) |
| 3 | HIGH | Runbook §6.5 step 1 fails open if `actuator/scheduledtasks` not exposed | `oracle-update-notes-v0.55.0.md:607` | Simone, Marcus | Add precondition check or "if 404, fall through to log-parse" | No (HIGH but fixable on branch) |
| 4 | HIGH | Runbook §6.5 step 2 returns 0 rows on fresh deploy = false-positive pass | `oracle-update-notes-v0.55.0.md:630-645` | Marcus, Simone | Add "first-run waiver" sentence — probe confirms invariant, not purge execution | No |
| 5 | HIGH | Runbook §15.6 reentry-06 walkthrough wording mismatches actual capture | `tasks.md:236` vs `tasks.md:51` | Devon, Riley | Match the runbook to "TRANSITIONAL + Buncombe + accepts-felonies → empty state" | No |
| 6 | HIGH | tasks.md §12.5.5 scheduled-invocation IT marked unchecked | `tasks.md:98` | Riley | Land or explicitly cite existing HoldAttributionIntegrationTest coverage | No |
| 7 | MEDIUM | `reentry-story.html` skip-link uses inline onfocus/onblur, not CSS class | `reentry-story.html:62` | Tomás | v0.55.1 styling pass | No |
| 8 | MEDIUM | ES `hold.help.notes` "navegador" ambiguous (browser vs navigator) | `es.json:726` | Maria | Real-Maria review (already filed v0.55.1) | No |
| 9 | MEDIUM | `for-coc-admins.html:328` says "15-minute decryption token" but no such concept exists in the §16.B gate | `for-coc-admins.html:328` | Marcus | Either remove or scope to "JWT TTL bounds the gate at 15 min"; current wording invents a token type that isn't in the code | No |
| 10 | MEDIUM | `for-coc-admins.html:307` claims hold-attribution "are not displayed on DV referral flows" but the actual code gate is reentryMode tenant flag | `for-coc-admins.html:307` | Marcus | Restate as "are gated by the reentryMode flag and are independent of the DV referral flow"; current wording suggests a code-level interlock that isn't there | No |
| 11 | MEDIUM | `<details open>` was tasks.md §11.3 but spec language vs code conflict | (see #2) | Alex, Sam | Resolve in lockstep with #2 | No |
| 12 | MEDIUM | Spanish translations: 5/5 new keys differ from EN counterparts; §12.4.5 lexical-distinct check unchecked | `tasks.md:97` | Maria | Confirm (already passes manual lex-diff above) | No |
| 13 | MEDIUM | Runbook §6.5 step 3 cut off at line 648 in my reading window | runbook | Simone | Confirm step 3 exists in the file (likely OK; tail of read truncated) | No |
| 14 | NIT | "plaintext never touches disk" absolute-bound in code comment | `ReservationService.java:231`, `ReservationRepository.java:80` | Casey | v0.55.1 wording pass | No |
| 15 | NIT | `for-funders.html:285` "Default-off." sentence is incomplete; could read as orphaned | `for-funders.html:285` | Casey | Defer | No |
| 16 | NIT | `reentry-story.html:184` "without warranty of any kind" — minor: the Apache 2.0 license boilerplate doesn't need a separate footer; intent fine | `reentry-story.html:184` | Casey | Defer | No |
| 17 | NIT | `dvindex.html` see-also footer points to `reentry-story.html` but no narrative cross-link in body | `dvindex.html:146` | Riley | Defer; reciprocal link exists which is the spec ask | No |
| 18 | NIT | `for-coc-admins.html:309` JSON `<code>REENTRY_TRANSITIONAL</code>` wrapped in `<code>` is good; but `:317-318` mixes `features.reentryMode = false` and `reentryMode` interchangeably | `for-coc-admins.html` | Devon | Tidy in v0.55.1 | No |

## Three-bucket assignment

**Must fix before merge (BLOCKERS):**
- **#1** Add 5th "Reentry Walkthrough" tile to `index.html` See It Work grid (lines 424-445); reference `demo/reentry-story.html` per tasks.md §9.1. The runbook §15.4a verification depends on it.
- **#2** Resolve the `<details open>` drift between tasks.md §11.3 and `HoldDialog.tsx:241`. Recommended action: amend tasks.md to match the shipped warroom-Round-2 design (collapsed by default, privacy note above, help text inside). Code is correct; spec needs to follow.

**Fix on the branch but not blocking (HIGHs):**
- **#3** Runbook §6.5 step 1: add 404-fallback note for actuator/scheduledtasks.
- **#4** Runbook §6.5 step 2: add the first-run waiver sentence ("On a fresh deploy, expect 0 rows = no candidate data; this confirms the invariant, not purge execution. The 25h gate fires its first real run ~25h after the first resolved hold post-deploy.").
- **#5** Runbook §15.6: align the demo walkthrough wording with the actual reentry-06 capture (TRANSITIONAL + Buncombe + accepts-felonies empty state).
- **#6** tasks.md §12.5.5: either land the IT or cite existing `HoldAttributionIntegrationTest` coverage so `/opsx:verify` doesn't snag.

**v0.55.1 follow-ups (MEDIUMs/NITs):**
- **#7** `reentry-story.html` skip-link CSS-class consistency.
- **#8** Native-Maria review (already filed).
- **#9** `for-coc-admins.html:328` "15-minute decryption token" wording.
- **#10** `for-coc-admins.html:307` "DV referral flows" interlock framing.
- **#12** §12.4.5 lexical-distinct script — pass manually verified above.
- **#14** Code-comment "never touches disk" softening.
- **#15-18** Cosmetic.

## Open questions for the operator

1. **#1 tile fix in docs repo or code repo?** The `index.html` is in the **docs repo** (root). Fix lands on `feature/reentry-release-readiness` of the docs repo. Confirm before merging code-repo PR #168.
2. **#2 direction:** keep `<details>` collapsed-by-default (warroom Round 2 design intent) and amend tasks.md, OR add `open` to match tasks.md? The Round 2 warroom output was the deciding voice — collapsed-by-default with the privacy note OUTSIDE was the explicit fix to avoid burying the privacy framing. **Recommended: keep code, amend tasks.md.**
3. **§12.5.5 IT scope:** is the existing `HoldAttributionIntegrationTest` (tasks.md §13.A.5, "4 tests") sufficient coverage for the @Scheduled-wrapper concern, or does Riley specifically want an `@SpringBootTest` that calls `purgeExpiredHoldAttribution()` (no args, the wrapper) and asserts a row was purged? If the latter, ship that test before merge; if the former, mark §12.5.5 with the cross-reference and check the box.
4. **Static-content order:** the runbook §5.0 says "ship the v0.55 demo + audit fixes FIRST" (before backend). Confirm that interpretation matches operator preference at deploy time — bundled-with-backend was the design D3 choice, but §5.0 reads as a separate scp step. Both are correct interpretations; just clarify in chat at deploy time.

## Recommended next action

In the AM, fix the two BLOCKERs first: **(1) add the 5th tile to `index.html` and verify the link target matches the `demo/reentry-story.html` filename**, and **(2) update tasks.md §11.3 to read "the dialog defaults to collapsed; privacy note renders OUTSIDE the disclosure (always-visible above), per-input help text renders INSIDE the disclosure" so the spec matches the shipped warroom-Round-2 code**. Then push the four HIGHs to the branch, re-run `/opsx:verify`, archive, tag, deploy. The MEDIUM/NIT carry list is small enough to roll into v0.55.1 without churn.

---

## Round 2 amendment — 2026-05-01 operator decisions

**Open question #2 resolved.** Direction confirmed: **keep code, amend `tasks.md` §11.3** to match shipped collapsed-by-default `<details>` per Round 2 design (privacy note OUTSIDE the disclosure, help text INSIDE).

**Open question #3 resolved.** §12.5.5 IT scope: a dedicated `@Scheduled`-wrapper test was added — `HoldAttributionIntegrationTest.scheduledEntryPoint_purgesAgedRow_endToEnd` (`backend/src/test/java/org/fabt/reservation/HoldAttributionIntegrationTest.java:738`) calls `referralTokenPurgeService.purgeExpiredHoldAttribution()` with no args and no outer `WithTenantContext`, exercising the full scheduler entry point Riley R-RR-1 was concerned about. tasks.md §12.5.5 marked `[x]` with the cross-reference. 23/23 tests in the class GREEN.

**MEDIUM-9 + MEDIUM-10 promoted to fix-before-merge** per `feedback_truthfulness_above_all` (operator decision):

- **MEDIUM-9 (now FIXED on branch)** — `for-coc-admins.html:326` rewritten. The original "15-minute decryption token gates read access" invented a token type that doesn't exist in code; the actual mechanism is a serialization-layer gate on the `reentryMode` JWT claim (60s `JwtService.reentryModeCache` TTL, bounded by 15min JWT TTL ceiling). New wording names the actual mechanism without inventing concepts.

- **MEDIUM-10 (now FIXED on branch)** — `for-coc-admins.html:313` rewritten. The original "are not displayed on DV referral flows" suggested a code-level interlock; in fact the gate is the `reentryMode` flag on the requesting session, and the DV referral flow is a separate code path that does not collect or display these fields. New wording reflects both truths without conflating them.

**Other HIGHs landed in this pass:**
- HIGH-3 (runbook §6.5 step 1): added explicit precondition note that `actuator/scheduledtasks` is not in the v0.55 management exposure default; 404 is expected, fall through to log-parse.
- HIGH-4 (runbook §6.5 step 2): added "first-run waiver" sentence — on a fresh deploy, 0 rows confirms the invariant, not the purge execution path; schedule a re-run ~26-30h after the first reentry-mode hold lands.
- HIGH-5 (`tasks.md` §15.6): rewritten to match the actual reentry-06 capture — TRANSITIONAL + Buncombe + accepts-felonies → empty-state banner.

**Bonus (out of warroom scope but caught by CI on PR #168):** `docs/legal/right-to-be-forgotten.md:31` "compliant with" → "conforming to" (real rewrite, not allowlist); `docs/legal/right-to-be-forgotten.md:90` self-referential meta-disclaimer added to `.legal-allowlist` ("is a deployment-owner determination" pattern). Same shape as existing `not certified` / `not "CSP compliant"` entries.

**Net status after this pass:** all 2 BLOCKERs and all 4 HIGHs addressed; MEDIUM-9 + MEDIUM-10 promoted-and-landed. v0.55.1 carry-list now reduced to MEDIUM-7 (skip-link CSS-class consistency), MEDIUM-8 (native-Maria review, already filed), and the NITs.
