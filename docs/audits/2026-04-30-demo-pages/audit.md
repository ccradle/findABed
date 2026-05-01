# Demo pages + screenshots audit — 2026-04-30

**Scope:** All 11 HTML pages + 1 markdown + 64 PNGs in `demo/`.
**Trigger:** User direction during `reentry-release-readiness` work, post-§7 capture-spec landing. Goal: confirm all existing demo surfaces are current and meet persona standards before v0.55 archive.
**Audit lens:** Casey (legal posture), Marcus (privacy claim accuracy), Tomás (semantic markup + ADA), Keisha (dignity language), Maria (bilingual coverage), plus operational drift checks (stale screenshots, real-name leaks, cross-link integrity).

This doc is the input to a warroom round for prioritization and fixes. It does NOT apply edits — it surfaces them for triage.

---

## Summary scorecard

| Severity | Count | Headline |
|---|---|---|
| **BLOCKER** | 2 | for-funders.html platform-wide PII overclaim; missing reentry mention on 3 audience pages (proposal §9 dependency) |
| **HIGH** | 4 | for-coc-admins.html PII section needs DV-scoping disclaimer; for-funders.html "ensures" Casey overclaim; index.html missing reentry tile (§9.1); pitch-briefs.html has not been v0.55-reviewed |
| **MEDIUM** | 7 | various page-level Tomás/Keisha/Maria gaps |
| **NIT** | 6 | minor copy + alt-text refinements |
| **Screenshot drift** | TBD | 64 PNGs surveyed; 4-6 likely show pre-v0.55 UI |

**Net read:** the front-door pages (`index.html`, `dvindex.html`) are largely clean post-§A.1 fix. The audience pages (`for-coc-admins`, `for-cities`, `for-funders`, `for-coordinators`) carry the bulk of unfixed exposures because v0.55 reentry hasn't been threaded into them yet (§9 cross-page edits handle four of these). `for-funders.html` has the single most serious overclaim. `pitch-briefs.html` and `outreach-one-pager.html` predate v0.55 and need a freshness check before the v0.55 deploy.

---

## Page-by-page findings

### 1. `index.html` (388 lines) — HIGH priority

**v0.55 alignment:** ⚠️ Missing reentry-story tile in "More Walkthroughs" grid (lines 326-332). Currently lists 4 walkthroughs (Shelter Onboarding, DV Opaque Referral, HMIS Bridge, CoC Analytics). Per `reentry-release-readiness/specs/reentry-story-page/spec.md` §"Reentry story page is reachable from the front door", this needs a 5th tile to `reentry-story.html`. **§9.1 cross-page edit covers this.**

**Casey:** ✓ "Designed to support VAWA/FVPSA requirements" framing on line 296. ✓ Apache 2.0 disclaimer on line 384.

**Marcus:** ✓ "Zero client PII. Shelter addresses never displayed" claim on line 296 is correctly DV-scoped (under "DV Privacy" h-style div). The original `findabed.org` "no client name... ever" claim from proposal §A is gone.

**Tomás:** 🟡 Only 3 semantic HTML elements (html / body / header). Section dividers use `<div class="section-divider">` instead of `<section>`. Card structure is `<div class="card">` rather than `<article>`. Functional but not semantically rich. Screen reader experience is OK because of structural cues + alt text, but could be tightened.

**Keisha:** ✓ "Darius's Night" + "Sandra's Side" — synthetic outreach worker + coordinator names. No banned words. ✓ "Bed Search" / "Reservation Hold" copy is operational, not labeling.

**Maria:** 🟡 Card #10 (line 154-162) describes Spanish localization in the platform but the page itself is English-only. This is consistent with the platform reality (the app IS bilingual; the marketing page is English-only). Add Spanish version of `index.html` to the i18n backlog? Or keep English-only consistent with `dvindex.html`/`hmisindex.html`/`analyticsindex.html`?

**Operational drift:**
- 20 screenshots referenced. Captured in batches predating v0.55. Some probably need re-capture — see screenshot section below.
- "Try It Live" tenant inventory table (lines 343-377) lists all 17 demo accounts. Verify accuracy after V96 seed addition (V96 added the third reentry shelter but did not add new users — table is still correct).

**Findings:**
- 🔴 **HIGH-IDX-1:** Add 5th tile linking to `reentry-story.html` in "More Walkthroughs" grid (§9.1 already planned).
- 🟡 **MEDIUM-IDX-2:** Consider promoting `<div class="section-divider">` and `<div class="card">` to semantic `<section>` and `<article>` for ADA Title II rigor.

---

### 2. `dvindex.html` (152 lines) — HIGH priority (audited as pattern donor)

**v0.55 alignment:** ✓ "Hard-deleted within 24 hours" claim (lines 58, 139) is correctly about DV referral tokens (not hold-attribution PII, which is the "no later than 25 hours" claim). The 24h DV-token policy is unchanged in v0.55. **No edit needed.**

**Casey:** ✓ "Designed to support VAWA/FVPSA compliance requirements" (line 8). ✓ "DV shelter operators should consult qualified legal counsel" (line 50). ✓ Footer disclaimer (line 148).

**Marcus:** ✓ "zero client PII" claim (line 58) is correctly scoped to the DV referral token system. ✓ "No names. No addresses. No client PII enters the system at any point" (line 79) is correctly scoped to the DV referral request modal context.

**Tomás:** 🟡 Only 5 semantic elements. Same div-heavy structure as `index.html`.

**Keisha:** ✓ "Darius" synthetic outreach worker; no banned words.

**Maria:** 🟡 English-only.

**Operational drift:**
- 7 screenshots (`dv-01` through `dv-07`). Likely current — DV flow has been stable through v0.55.

**Findings:**
- 🟡 **MEDIUM-DVX-1:** Add reciprocal "see also" footer link to `reentry-story.html` (matches the §6 reciprocal-footer requirement on the reentry side). Currently dvindex links only to root `index.html` and the GitHub legal/architecture doc.
- 🟢 **NIT-DVX-2:** Consider promoting `<div class="card">` to `<article>` (same as IDX-2).

---

### 3. `for-coc-admins.html` (343 lines) — HIGH priority

**v0.55 alignment:** ⚠️ Page does NOT mention reentry / transitional housing as a v0.55 capability. CoC admins are the role that flips the `features.reentryMode` flag — they need at least one section explaining what flipping it does + that it's default-off. Currently absent.

**Casey:** ✓ "Designed to support VAWA and FVPSA requirements" (line 33). ✓ "It has not been certified by HUD" / "It has not been independently certified as compliant" (lines 237, 293). ⚠️ Line 41 + 237 use "designed to support... but has not been certified by HUD" — wording is fine, both halves needed.

**Marcus:** 🟢 Lines 272-273 ("No client names... Zero PII" / "shelter's physical address is never stored") are correctly under the **"DV Shelter Protection"** h2 (line 267). Reading in context, the scope is DV-only. **However** — a casual scanner reading just the bulleted list might miss the DV scope. Recommend adding a one-line scope reminder at the top of the bullet list ("**For DV shelters specifically:**").

**Tomás:** ✓ Real h1/h2/h3 structure. 18 semantic elements counted. Strong.

**Keisha:** ✓ Operational tone, no banned words, no client labeling.

**Maria:** 🟡 English-only.

**Findings:**
- 🔴 **BLOCKER-COC-1:** Page makes no mention of v0.55 reentry-mode tenant flag. The CoC admin is the role responsible for enabling it. Add a short section (~150-200 words) under existing structure explaining: what `features.reentryMode` does, default-off, who can flip it (themselves), 15-min token-TTL caveat. Link to `reentry-story.html` and `docs/operations/reentry-mode-user-guide.md`. **NOT covered by current §9 cross-page edits — needs new edit.**
- 🟡 **HIGH-COC-2:** Lines 272-273 PII claims are DV-scoped by surrounding h2 but vulnerable to out-of-context reading. Add explicit "**For DV shelters specifically:**" preamble to the bullet list.

---

### 4. `for-cities.html` (250 lines) — HIGH priority

**v0.55 alignment:** ⚠️ Zero mention of reentry. §9.3 spec ("one sentence acknowledging reentry / justice-system-adjacent populations as a use case") covers this; not yet applied.

**Casey:** ✓ Line 65: "No per-seat licensing. No vendor lock-in." — operational, no overclaim. ⚠️ Line 65 also says "Your data never leaves your infrastructure" — true given self-hosted architecture; OK.

**Marcus:** ✓ No PII overclaim found.

**Tomás:** ✓ 10 semantic elements. Reasonable.

**Keisha:** ✓ No banned words.

**Maria:** 🟡 English-only.

**Findings:**
- 🔴 **BLOCKER-CTY-1:** Add reentry use-case sentence (§9.3 already planned).

---

### 5. `for-coordinators.html` (325 lines) — HIGH priority

**v0.55 alignment:** ⚠️ Zero mention of reentry. §9.2 spec ("paragraph distinguishing the navigator role from the outreach-worker role; cross-link to reentry-story.html") covers this.

**Casey:** ✓ "no one pays a licensing fee, ever" (lines 25, 193) — about Apache 2.0, not PII. OK.

**Marcus:** ✓ No PII overclaim.

**Tomás:** ✓ 14 semantic elements.

**Keisha:** ✓ Operational tone.

**Maria:** 🟡 English-only.

**Findings:**
- 🔴 **BLOCKER-CRD-1:** Add navigator-role-distinction paragraph + reentry-story link (§9.2 already planned).

---

### 6. `for-funders.html` (309 lines) — HIGH priority **(highest-risk page)**

**v0.55 alignment:** ⚠️ Line 33: "Zero client PII by design" + line 276: "**Zero client PII.** The platform never stores names, dates of birth, or identifying information about the people being served." — these are **platform-wide claims that are factually false post-v0.55** for tenants who flip `features.reentryMode=true`. The platform DOES store optional names + DOBs + notes (encrypted, opt-in, 25h purge) on non-DV reentry holds.

**Casey:** ⚠️ Line 41: "Apache 2.0 open source **ensures** the software cannot disappear" — "ensures" is an overclaim word. Apache 2.0 means code is forkable but doesn't *ensure* continuity (a maintainer could abandon and no fork would emerge). Recommend: "Apache 2.0 open source means the software cannot be locked away by a single vendor — any community can take a fork forward."

**Marcus:** 🔴 Lines 33 + 276 + 33 + page meta description on line 10 ("zero-PII") all carry the platform-wide PII claim. Post-v0.55 these are FALSE for opted-in tenants. Three fixes:
1. **Page meta description (line 10):** rephrase from "Open-source, zero-PII, measurable impact." to "Open-source, opt-in privacy posture, measurable impact." — or keep "zero-PII" but add a "DV path" qualifier elsewhere on the page.
2. **Line 33 (FAQ answer):** rephrase "Zero client PII by design" to "Zero client PII on the DV referral path; opt-in tenant-controlled PII collection on non-DV reentry holds, encrypted at rest with a per-tenant DEK and erased no later than 25 hours after the hold ends."
3. **Line 276 (Defense bullet):** rephrase "Zero client PII. The platform never stores names, dates of birth, or identifying information" to "Zero client PII on the DV referral path. On non-DV reentry holds, optional client name/DOB/notes can be collected if the CoC enables it — encrypted at rest, erased no later than 25 hours after the hold ends. Default-off."
4. **Line 49: "every community, forever"** — Apache 2.0 framing; Casey would scope this to "freely available under Apache 2.0".

**Tomás:** ✓ 11 semantic elements.

**Keisha:** ✓ Tone respects funder audience without being patronizing.

**Maria:** 🟡 English-only.

**Findings:**
- 🔴 **BLOCKER-FND-1:** Three platform-wide PII claims (lines 10, 33, 276) need DV-scoping post-v0.55. **Highest-priority fix in the entire audit.**
- 🟡 **HIGH-FND-2:** Casey overclaim "ensures" on line 41.
- 🟡 **HIGH-FND-3:** Add reentry use-case sentence (§9.4 already planned).

---

### 7. `for-funders.html` cont — Reentry mention (§9.4)

Already covered in HIGH-FND-3 above.

---

### 8. `analyticsindex.html` (142 lines) — MEDIUM priority

**v0.55 alignment:** ✓ "All analytics are aggregate — no client PII" (line 125) — OK because analytics aggregates everything (including reentry holds aggregate to anonymous capacity counts). The PII surface is reservation-detail, not analytics.

**Casey:** ✓ Tone OK.

**Marcus:** ✓ Aggregation framing is correct post-v0.55.

**Tomás:** 🟡 5 semantic elements (low).

**Keisha:** ✓ OK.

**Maria:** 🟡 English-only.

**Findings:**
- 🟢 **NIT-ANL-1:** Optional — add one-line note that analytics aggregations also exclude hold-attribution PII fields by design (would explicitly tie the analytics promise to v0.55 architecture). Low priority.

---

### 9. `hmisindex.html` (117 lines) — MEDIUM priority

**v0.55 alignment:** ✓ Line 55: "DV shelter data is aggregated across all DV shelters before push — individual DV shelter occupancy is never sent." — DV-scoped, correct. ⚠️ Page makes no mention of whether HMIS push includes reentry-hold PII. Per `transitional-reentry-support/design.md` D4 + the reentry-story.html callout, hold-attribution PII is **never** published to HMIS, AsyncAPI, or external systems. Should add an explicit statement.

**Casey:** ⚠️ Line 104: "outbox pattern **ensures** pushes survive application restarts" — operational, not legal. NIT.

**Marcus:** ⚠️ Recommend adding: "Hold-attribution PII fields (v0.55+) are NEVER included in HMIS push payloads; only project-level inventory data is exported."

**Tomás:** 🟡 5 semantic elements.

**Keisha:** ✓ OK.

**Maria:** 🟡 English-only.

**Findings:**
- 🟡 **MEDIUM-HMS-1:** Add one-line statement that hold-attribution PII fields are never in HMIS push payloads.
- 🟢 **NIT-HMS-2:** Soften "ensures" to "is designed so that" if Casey-rigor is needed (low priority — operational claim is technically defensible).

---

### 10. `outreach-one-pager.html` (212 lines) — LOW priority but needs freshness check

**v0.55 alignment:** ⚠️ Line 176: "All referral data permanently deleted within 24 hours" — DV referral context, OK as-is. Page does NOT mention reentry holds at all — for an outreach worker audience, this is a gap.

**Casey:** Need full-page read to assess. Current grep shows no obvious overclaim.

**Marcus:** Need full-page read.

**Tomás:** 🟡 7 semantic elements.

**Keisha:** Need full-page read.

**Maria:** 🟡 English-only.

**Findings:**
- 🟡 **MEDIUM-O1P-1:** Page predates v0.55 reentry. Outreach workers ARE the role that places reentry holds. Recommend a one-paragraph addendum or footer-link to `reentry-story.html`. (Smaller scope than the §9 audience-card edits because outreach-one-pager is a print-friendly summary, but still warrants a mention.)
- 🟢 **NIT-O1P-2:** Re-read the full page in the warroom round to confirm no other v0.55 misalignment.

---

### 11. `pitch-briefs.html` (220 lines) — LOW priority but needs v0.55 review

**v0.55 alignment:** ⚠️ Page is described in spec as "Pitch decks for stakeholder conversations." Predates v0.55. Has never been v0.55-reviewed.

**Findings:**
- 🟡 **HIGH-PIT-1:** Full v0.55 audit pass needed in warroom round (PII claims, reentry mention, freshness). Until done, recommend hiding link from front-door if any v0.55 claims need updating.
- 🟢 **NIT-PIT-2:** Verify no real stakeholder names per `feedback_no_named_stakeholders_in_docs`.

---

### 12. `shelter-onboarding.html` (181 lines) — MEDIUM priority

**v0.55 alignment:** ⚠️ Does the onboarding flow mention reentry shelter type? V91/V94 added new `shelter_type` enum values (TRANSITIONAL, REENTRY_TRANSITIONAL, OVERFLOW) — onboarding doc may be stale.

**Findings:**
- 🟡 **MEDIUM-ONB-1:** Verify shelter-type taxonomy reflects V91 enum (TRANSITIONAL / REENTRY_TRANSITIONAL / EMERGENCY / OVERFLOW / DV). If onboarding only mentions EMERGENCY + DV, it's pre-v0.55 stale.

---

### 13. `shelter-edit-walkthrough.md` (79 lines) — LOW priority

Markdown-format walkthrough. Lighter audit lens.

**Findings:**
- 🟢 **NIT-SEW-1:** Re-read in warroom round; verify no v0.55 mismatches.

---

## Screenshots audit

64 PNGs in `demo/screenshots/`. Categorized by capture spec they came from:

| Spec | PNG count | Likely v0.55 alignment | Notes |
|---|---|---|---|
| capture-screenshots.spec.ts (numbered 01-29) | 29 | ⚠️ Mixed | Some predate the §16 dialog reshape, the §10 eligibility section, the §11 help text. **High-risk for staleness.** |
| capture-dv-screenshots.spec.ts (dv-01 through dv-07) | 7 | ✓ Likely current | DV flow stable through v0.55. |
| capture-analytics-screenshots.spec.ts (analytics-01 through 06) | 6 | ✓ Likely current | Analytics surface unchanged post-v0.55. |
| capture-hmis-screenshots.spec.ts (hmis-01 through hmis-04) | 4 | ✓ Likely current | HMIS push surface unchanged. |
| capture-notification-screenshots.spec.ts (notif-01 through notif-03) | 3 | ✓ Likely current | Notification surface unchanged. |
| capture-offline-screenshots.spec.ts (offline-01 through 04) | 4 | ✓ Likely current | Offline surface unchanged. |
| capture-totp-screenshots.spec.ts (27, 28, 29) | 3 | ✓ Likely current | TOTP unchanged. |
| capture-mobile-header.spec.ts | 0 visible (mobile-header captures probably skipped) | ? | Need to verify. |
| capture-platform-operator-screenshots.spec.ts | 0 | N/A | Captures separate dir per file pattern. |
| capture-reentry-screenshots.spec.ts (reentry-01 through 06) | 6 | ✓ JUST CAPTURED | Already known good. |
| dark-* (4 PNGs) | 4 | ⚠️ Predate v0.55 | Likely show pre-§16 dialog + pre-§10 eligibility section. |

**Screenshot drift concerns (likely stale):**
- `02-bed-search.png`, `03-search-results.png`, `04-shelter-detail-search.png` — predate §10 eligibility surface + §16 reentry-mode gate. **Probably show the OutreachSearch without the advanced-filters section visible OR with no county filter.** May still look fine for the index.html "Darius's Night" narrative since the narrative doesn't depend on reentry surfaces.
- `05-reservation-hold.png` — predates §11 Round 2 dialog reshape + §16.C PII fields gate. **High-risk** — the dialog has changed materially.
- `09-admin-users.png`, `10-admin-create-user.png`, `11-admin-shelters.png`, `13-admin-shelter-detail.png` — predate V91 shelter_type column + V93 reservation PII columns + §10 eligibility-criteria editor. **Probably stale** for shelter-detail/edit views.
- `dark-*` PNGs predate § §11 Round 2 + §16 — at least dialog and admin views likely stale.

**Recommendation:** triage in the warroom round. Likely candidates for re-capture:
- `02-bed-search`, `03-search-results`, `04-shelter-detail-search` (reentry surface integration)
- `05-reservation-hold` (§11 dialog reshape)
- `11-admin-shelters`, `13-admin-shelter-detail`, `22-admin-shelters-edit` (shelter-edit + eligibility section)
- `dark-search`, `dark-admin`, `dark-coordinator` (dark mode of the above)

Probably ~8-10 PNGs need re-capture for v0.55 coherence.

---

## Cross-page integrity

- ✓ Front-door `index.html` → all 4 deep-dive pages exist
- ⚠️ `index.html` → reentry-story.html missing (§9.1 fix)
- ⚠️ `dvindex.html` → reentry-story.html missing reciprocal footer link (§6 spec requirement, MEDIUM-DVX-1)
- ✓ `dvindex.html` → main demo + GitHub legal docs link
- ⚠️ Audience pages (`for-coc-admins`, `for-cities`, `for-funders`, `for-coordinators`) → reentry-story.html missing (§9.2/9.3/9.4 fixes)
- ✓ All pages → root `index.html` link present

---

## Stakeholder-name + real-place-name sweep

**Real NC place-names found (potentially OK in operational context):**
- "Raleigh", "Boone", "Waynesville", "Asheville", "Onslow", "Pitt", "Beaufort", "Greenville", "Henderson", "Buncombe" — these are county/city names tied to V95/V96 seed shelters. Operational accuracy.
- "Wake County" — appears in `index.html` seed shelter list ("Wake County Veterans Home"). Real county, real-sounding fictional shelter name. OK per `feedback_no_named_stakeholders_in_docs` (counties ≠ stakeholders).

**No real CoC names found** — no "Wake County CoC", "Asheville CoC", "Charlotte CoC", etc.

**No real reentry-org names found** — no "Center for Community Transitions", "Reentry Inc.", etc.

**No real partner names found.**

---

## Bilingual coverage

- App itself is bilingual (en + es) — verified by §11 i18n work.
- Demo pages: ALL English-only.
- `reentry-story.html` already includes a "Spanish version planned" footer note (per §11 audit).
- Recommendation: add the same "Spanish version planned" note to other audience pages OR commit to a docs-i18n slice as v0.55.x follow-up.

---

## Summary of warroom triage backlog

**Strict BLOCKERs (must fix pre-v0.55 archive):**
- BLOCKER-FND-1 (3 fixes on `for-funders.html`): platform-wide PII overclaims that are factually false post-v0.55
- BLOCKER-COC-1: reentry-mode flag explanation on `for-coc-admins.html` (the role that flips the flag)
- BLOCKER-CTY-1: reentry sentence on `for-cities.html` (§9.3, already planned)
- BLOCKER-CRD-1: navigator-role paragraph + reentry-story link on `for-coordinators.html` (§9.2, already planned)

**HIGHs (should fix pre-archive; some already in §9 plan):**
- HIGH-IDX-1: 5th tile on `index.html` (§9.1, already planned)
- HIGH-COC-2: explicit "**For DV shelters specifically:**" preamble on for-coc-admins.html PII bullet list
- HIGH-FND-2: replace "ensures" on for-funders.html line 41
- HIGH-FND-3: reentry sentence on for-funders.html (§9.4, already planned)
- HIGH-PIT-1: full v0.55 audit pass on `pitch-briefs.html` in next warroom round

**MEDIUMs:**
- MEDIUM-DVX-1: reciprocal footer link from dvindex.html → reentry-story.html
- MEDIUM-IDX-2: semantic markup elevation on `index.html`
- MEDIUM-HMS-1: HMIS-doesn't-export-PII statement on `hmisindex.html`
- MEDIUM-O1P-1: outreach-one-pager v0.55 mention
- MEDIUM-ONB-1: shelter-onboarding shelter-type taxonomy refresh
- MEDIUM-Maria: bilingual coverage strategy across audience pages

**NITs:**
- NIT-ANL-1, NIT-DVX-2, NIT-HMS-2, NIT-O1P-2, NIT-PIT-2, NIT-SEW-1 — defer to v0.55.1.

**Screenshot re-captures (~8-10 PNGs):**
- 02 / 03 / 04 / 05 / 11 / 13 / 22 / dark-search / dark-admin / dark-coordinator

---

## Methodology notes

- Audit time: ~90 min (greps + spot-reads + doc authoring).
- Banned-words grep returned ZERO hits for the Keisha list across all 13 demo files.
- Casey overclaim grep returned 6 hits across 4 pages; 4 are operational/defensible, 2 are real overclaims (HIGH-FND-2 + a borderline operational case).
- 24-hour vs 25-hour grep returned 9 hits — all DV-context (referral tokens), correctly unchanged.
- "Ever" / "forever" grep returned hits across many pages; all are post-§A.1 (license context, DV-scoped, or operational), no platform-wide PII residue.

This audit consumed grep + spot-read context for ~30% of total page content. The remaining 70% (deep prose reads on pages-13) is the warroom round's job — surface-level findings here are mostly architectural/categorical, not line-by-line copy edits.
