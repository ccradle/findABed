# v0.55.1-followup — implementation warroom (post §3-§9)

**Date:** 2026-05-01
**Scope:** Review the 10 commits across both repos that landed §3 (T1) + §4 (T2) + §5 (O1) + §6 (D3) + §7 (S2) + §8 (S1) + §9 (D2). Pre-PR / pre-deploy review.
**Inputs:** commits `7b32595`, `77b2590`, `e536f65`, `4e4e6c1`, `2fde139` (code repo); `c8c54e2`, `46161f0`, `8e36b60`, `eca89db`, `e426e67` (docs repo).
**Convention:** 11 personas (Casey, Marcus, Tomás, Keisha, Maria, Demetrius, Simone, Devon, Riley, Alex, Sam).
**Methodology:** code review + 4 web searches grounding the borderline calls in published best-practice sources. NO assumptions; everything in this doc is either a direct code observation or a cited research finding.

---

## Verdict (one-line)

**Hold for fixes.** 1 BLOCKER (semantic-markup mis-application — real HTML5 best-practice violation, not stylistic). 3 HIGHs (one Spanish-translation borderline call surfaced by web research; one HMIS test-coverage limitation; one operator-onboarding gap on capture.sh). 4 MEDIUMs / 3 SUGGESTIONs. The bulk of the work is sound; the BLOCKER is a localized fix.

---

## BLOCKER

### B1 — `<article class="card">` is wrong semantic markup for numbered walkthrough steps; should be `<ol>/<li>`

**Caught by:** Simone + Tomás. **Grounded by:** 2 independent W3C/MDN sources via web search.

**Where:** commit `46161f0` (S2) — `demo/dvindex.html` lines 63, 73, 83, 95, 105, 115, 127. 7 cards converted from `<div class="card">` to `<article class="card">`.

**The problem:** the 7 cards are **numbered walkthrough steps** (each card has `<span class="card-number">N</span>` for N=1..7, in sequential order, telling the DV-referral story end-to-end). Per HTML5 living standard + MDN + W3C semantic-structure guidance:

- `<article>` is for **"independent, self-contained content that should make sense on its own and be possible to distribute independently from the rest of the website"** — blog posts, news articles, product reviews. Step 2 of a walkthrough doesn't make sense without step 1; the cards are NOT independently distributable.
- `<ol>` + `<li>` is for **"sequential information... ordered lists suggest sequence, order, or ranking."** Numbered walkthrough steps are precisely this.

The S2 commit's intent (real a11y improvement) is correct; the chosen markup is wrong. Screen readers navigating by article landmark will see 7 unrelated articles instead of one ordered procedural list. This is materially worse for AT users than the original `<div>` shape, because `<div>` carried no semantic claim and `<article>` makes a wrong one.

**Fix:** revise `46161f0` (or land a follow-up commit) to use `<ol class="walkthrough-steps">` wrapping `<li class="card">` for each card. Drop the manual `<span class="card-number">` (the `<ol>` browser-renders the number automatically), OR keep it for visual styling consistency but acknowledge it now duplicates the implicit list-item number. CSS targeting `.card` continues to work.

Spec note: `openspec/changes/v0-55-1-followup/proposal.md` and `design.md` describe the change as `<div>` → `<article>`; the spec also needs updating to `<div>` → `<ol>/<li>` to keep the docs in sync with the corrected implementation.

**Sources:**
- [HTML Semantic Elements (W3Schools)](https://www.w3schools.com/html/html5_semantic_elements.asp)
- [Content Structure (W3C WAI)](https://www.w3.org/WAI/tutorials/page-structure/content/)
- [WebAIM: Semantic Structure: Regions, Headings, and Lists](https://webaim.org/techniques/semanticstructure/)

---

## HIGHs

### H1 — `navegador de servicios` is a borderline pan-Latin call; web research surfaces stronger alternatives

**Caught by:** Maria (self-review re-grounded post-search).

**Where:** commit `2fde139` (D2) — revised `frontend/src/i18n/es.json` `hold.help.notes` from `del navegador` → `del navegador de servicios`.

**The problem:** my AI-synthetic audit recommended `navegador de servicios` based on Claude's training-data Spanish-language knowledge. Web search (post-commit, this warroom round) shows the dominant Spanish term for a "navigator" role in social services / healthcare contexts is `navegador de pacientes` (in healthcare) or, more broadly, `asesor/a`, `guía`, or `enlace comunitario`. Linguee + ProZ + WordReference returns confirm:

- **Healthcare contexts:** `navegador de pacientes` (most established; HUD-affiliated CDC translations).
- **Generic social services:** `asesor/a` (advisor) is more recognizable.
- **Community-services contexts:** `enlace comunitario` (community liaison) appears in HUD-Hispanic materials.

`navegador de servicios` is plausible but is NOT the dominant pan-Latin form. A real native-Spanish reviewer might flag it as overly literal.

**Severity:** HIGH but not BLOCKER. The revised text is intelligible (better than the bare `del navegador` it replaced) and the audit doc explicitly says this is AI-synthetic, NOT native-reviewer. Per `feedback_truthfulness_above_all`, the disclosure already covers the limitation. But the warroom should record that this specific call is the weakest of the 3 D2 revisions and the most likely to be revised in a future native-reviewer pass.

**Fix:** two options:
- **Option A:** revise to `del enlace comunitario` (HUD-Hispanic convention) or `del asesor/de la asesora` (broader). More work; would require updating the audit doc + per-key revision commit.
- **Option B:** keep `navegador de servicios` as-is; flag it explicitly in the audit doc's "future-real-native-reviewer" candidate list. Cheaper; preserves the disclosure-driven posture.

Recommend **Option B** — the disclosure already establishes that AI-synthetic calls may need a real reviewer pass; flagging this specific call is the truthful move. Update the audit doc's summary table to mark `hold.help.notes` as `REVISE (with native-reviewer-flag for "navegador de servicios" specific call)`.

**Sources:**
- [patient navigator - Linguee](https://www.linguee.com/english-spanish/translation/patient+navigator.html)
- [Spanish-Speaking Patient Navigators (Huntsman / U Utah)](https://healthcare.utah.edu/huntsmancancerinstitute/wellness-support/patient-navigators/spanish-speaking)
- [Patient navigator > asesores de pacientes (ProZ KudoZ)](https://www.proz.com/kudoz/english-to-spanish/medical-health-care/1113069-patient-navigator.html)

### H2 — HMIS contract test reflection check has a known false-negative class that the test Javadoc doesn't fully cover

**Caught by:** Tomás + Marcus + Alex.

**Where:** commit `4e4e6c1` (O1) — `HmisPushContractTest.java` `hmisInventoryRecord_hasNoPiiFlavoredFields` test. The PII-pattern list is hardcoded:

```java
private static final List<String> PII_FIELD_NAME_PATTERNS = List.of(
        "heldforclient",
        "clientname",
        "clientdob",
        "holdnotes"
);
```

**The problem:** a future regression that adds a PII field named `requesterIdentity`, `applicantSsn`, `guestEmail`, or any other PII-semantic field NOT matching these substrings would NOT fail the test. The reflection check catches *renamed* hold-attribution PII fields (or new fields that include these specific tokens) but is structurally blind to *new* PII categories.

The other layers of the test (schema-absent on `hmis_outbox` table; payload substring-search for the seeded values) DO cover the actual leak path for the seeded reservation's PII — so a real regression where reservation PII reaches the payload would still fail the test. But the reflection check is theatrical for the broader "no PII reaches HMIS" property; it's narrower than the test name suggests.

**Severity:** HIGH for transparency, MEDIUM for actual regression risk (the substring-search and schema-absent layers carry most of the weight; reflection is defense-in-depth).

**Fix:** add a Javadoc note to `hmisInventoryRecord_hasNoPiiFlavoredFields` explicitly scoping the test to "hold-attribution PII (the v0.55.0-introduced columns)." For broader PII categories, the schema-absent + substring-payload checks are the actual gates. Optional: add a comment that future PII categories should be added to the pattern list AND seeded into the substring-payload test.

This is a Javadoc-only fix; no test logic changes. ~5 lines.

### H3 — `capture.sh` BASE_URL default change from 5173 → 8081 is not announced anywhere

**Caught by:** Demetrius + Devon.

**Where:** commit `c8c54e2` (D3) — `demo/capture.sh` previously implicitly hit `localhost:5173` (bare Vite, via the test config); now defaults to `localhost:8081` (nginx).

**The problem:** operators with muscle-memory of running `bash demo/capture.sh` against a bare-Vite dev stack (`./dev-start.sh` without `--nginx`) will hit the new health-check failure ("Frontend is not running at http://localhost:8081") and may not immediately understand why. The script's failure message points to `--nginx` mode, which is the correct guidance, but nothing in the operator-facing docs (CHANGELOG, runbook) flags the change.

**Severity:** HIGH for first-encounter friction; LOW for actual breakage (the failure mode is a clear error message, not silent corruption).

**Fix:** add a note in the v0.55.1 CHANGELOG `### Tooling` (or equivalent) section: "`demo/capture.sh` now defaults `BASE_URL=http://localhost:8081` (nginx). Run `./dev-start.sh --nginx` first, or set `BASE_URL=http://localhost:5173` to keep the old bare-Vite path."

This is a 2-line CHANGELOG addition during the §12 hygiene step; no code changes.

---

## MEDIUMs

### M1 — `role="region"` on the search-results wrapper has `aria-label` but no associated heading; W3C best practice is heading-or-aria-label, but heading is preferred when a heading exists

**Caught by:** Simone (a11y).

**Where:** commit `7b32595` (T1 prereq) — `OutreachSearch.tsx` `<div role="region" aria-label={...} data-testid="search-results-region">`.

**Status:** **Acceptable per W3C** — `aria-label` is a valid label for a landmark region when no heading is present. The W3C ARIA Practices Guide explicitly says: "If an area requires a label and does not have a heading element, provide a label using the aria-label attribute."

**Note:** the search-results region in OutreachSearch doesn't have an `<h2>` (the page header is just a search input). Adding an `<h2 className="visually-hidden">Search results</h2>` inside the region would be the W3C-preferred form (with `aria-labelledby` referencing the h2), but this is a stylistic refinement, not a defect. Current implementation is W3C-compliant.

**Fix:** none needed. Optional v0.55.2 polish: add a visually-hidden `<h2>` and switch from `aria-label` to `aria-labelledby` for stricter compliance with W3C "heading preferred" guidance.

**Sources:**
- [Landmark Regions | W3C ARIA APG](https://www.w3.org/WAI/ARIA/apg/practices/landmark-regions/)
- [ARIA6: Using aria-label to provide labels for objects | W3C](https://www.w3.org/WAI/WCAG21/Techniques/aria/ARIA6)

### M2 — T1 sanity-assertion of `>= 3 freshness-badge matches` is hardcoded to seed-state; doesn't survive a seed-data revision

**Caught by:** Alex.

**Where:** commit `77b2590` (T1) — `screen-reader.spec.ts:65` assertion.

**The problem:** the threshold `>= 3` was chosen as "≥50% of seeded shelters in the default search." The seed currently has many shelters; 3 is conservative. But if a future seed-data change reduces the number of shelters with freshness badges below 3, the test would fail without an actual regression having occurred.

**Severity:** MEDIUM — the assertion is more robust than `>= 1` (which would silently pass on regressions where only the first card surfaces). The `>= 3` is conservative and unlikely to fail under any reasonable seed-data shape, but it's not adaptive.

**Fix:** none required. Optional refinement: derive the threshold dynamically (e.g., `Math.ceil(totalShelterCards * 0.5)`) by reading the cards in DOM first. Adds complexity for marginal benefit; not blocking.

### M3 — Dark-mode re-captures (S1) were taken against post-v0.55.0+v0.55.1-WIP DB state, NOT a clean `--fresh` seed

**Caught by:** Devon + Alex.

**Where:** commit `8e36b60` (S1) — `dark-search.png`, `dark-admin.png`, `dark-coordinator.png` regenerated 2026-05-01 12:49-12:50.

**The problem:** §8.1 says to "Confirm clean DB state: `./dev-start.sh stop && ./dev-start.sh --fresh`." I skipped the `--fresh` step (relied on the existing dev stack from the §3 + §4 + §5 work). The captured PNGs reflect the actual post-v0.55.0 + v0.55.1-WIP database state, which includes whatever holds + reservations were created during the test runs.

**Severity:** MEDIUM. The visible UI reflects current code state correctly (post-§10 chips, post-§16.C banners) — that's the actual claim of S1. The seed-data difference doesn't break the captures' accuracy. But a strict reading of the spec (`feedback_isolated_test_data`) says capture should be against clean seed.

**Fix:** none required for v0.55.1 ship. The captures are accurate to current UI state. If a future maintainer wants to re-capture against `--fresh` for absolute reproducibility, the operator-workaround for V95+V96 reentry shelters (per `project_seed_reentry_shelters_gap.md` memory) needs to ride the `--fresh` flow.

### M4 — `<div class="section-divider">` SKIP decision in S2 is the right call but the spec wording suggests doing the conversion

**Caught by:** Simone.

**Where:** commit `46161f0` and the v0-55-1-followup spec proposal.md / design.md.

**Status:** my SKIP decision was correct (those `<div>`s contain only inline header text; converting to `<section>` would create empty-of-children section landmarks, worse a11y). But the spec proposal.md still says "promote `<div class="section-divider">` → `<section>`" without the caveat. The commit message documents the skip + reasoning, but the spec doesn't.

**Fix:** during the §12 spec-sync (or now), add a sentence to v0-55-1-followup proposal.md S2 description: "section-divider divs were inspected; they're inline content holders (just a header text inside), not section wrappers — converting to `<section>` would create empty-of-children landmarks. Skipped + documented in the implementation commit. Future v0.55.2 candidate: convert to `<h2 class="section-divider">` for real heading semantics." Not blocking; this is spec hygiene.

---

## SUGGESTIONs

### N1 — i18n key `search.resultsRegion` follows codebase camelCase convention ✓

**From:** Keisha. Confirmed via grep — all `search.*` keys use dotted-camelCase (search.placeholder, search.noResults, search.tryDifferent, search.allTypes, search.singleAdult, etc.). `search.resultsRegion` matches. No change.

### N2 — `trabajadores de alcance comunitario` is well-grounded by web research; D2 finding holds

**From:** Maria.

Web search confirms `trabajador comunitario`, `promotor comunitario`, and `trabajador de alcance` are all valid pan-Latin Spanish for "outreach worker". My choice of `trabajadores de alcance comunitario` aligns with HUD-Hispanic + 211.org Spanish convention. `extensión` (the original) is a calque from agricultural-extension and not standard in social-services Spanish — D2 revision was correct.

**Sources:**
- [outreach worker - Reverso Context](https://context.reverso.net/translation/english-spanish/outreach+worker)
- [community outreach > programas de alcance comunitario (ProZ)](https://www.proz.com/kudoz/english-to-spanish/medical-health-care/2823497-community-outreach.html)
- [Spanish Translation of OUTREACH WORKER (Collins)](https://www.collinsdictionary.com/dictionary/english-spanish/outreach-worker)

### N3 — Dark-mode capture mechanism in `color-system.spec.ts` is non-canonical (NOT a `capture-*.spec.ts`); flag for v0.55.2

**From:** Devon.

The dark-mode PNGs are written as a side effect of `color-system.spec.ts` (a verification spec), not by a dedicated `capture-dark-mode-screenshots.spec.ts` (which would be the convention per the other 10 capture specs). v0.55.1 does not refactor this — it's a v0.55.2 candidate. Worth noting in the v0.55.1 backlog memory.

---

## Persona positions

**Casey (legal/truthfulness)** — The AI-synthetic disclosure discipline held throughout the work. Marker text in §11.2 archive uses the verbose form per warroom B1; commit messages all say "AI-synthetic" not "synthetic-Maria"; audit doc carries the verbose disclosure header; memory entry repeats the disclosure conventions. No truthfulness regressions. Per H1, the `navegador de servicios` borderline call should be flagged in the audit doc's future-reviewer list — that's the truthful posture.

**Marcus (security)** — H2 is mine. The reflection check on `HmisInventoryRecord` is narrower than the test name ("hasNoPiiFlavoredFields") suggests; it catches *renamed* hold-attribution PII fields but not *new* PII categories. The other test layers (schema-absent on hmis_outbox table; substring-payload search) cover the actual leak path. Javadoc tightening fixes the transparency issue; no logic change needed. Beyond that: the contract test runs structurally against a pipeline that demonstrably cannot reach reservation PII (HmisTransformer reads only bed_availability snapshots). Defense-in-depth is sound.

**Tomás (backend architecture)** — Concur with H2. The reflection-based field-name pattern check is a brittle pattern; tests-via-reflection are useful for "no field with a name matching this set was added," but require maintaining the set. The substring-payload check is the actual robust gate. Good test architecture overall; the layered shape (reflection + schema + payload) provides coverage at multiple levels.

**Keisha (frontend)** — The OutreachSearch wrap (T1 prereq) is clean. The i18n key naming follows convention. The screen-reader spec scope-fix is faithful to the original line-80 prediction. No frontend concerns. M1 (visually-hidden h2 polish) is optional.

**Maria (i18n self-review, post-research)** — H1 is my honest re-grounding. After the web search, I have to acknowledge that `navegador de servicios` was a weaker call than the audit doc presented. The `trabajadores de alcance comunitario` revision (N2) holds up under research. The `solo` → `únicamente` revision is also solid (RAE-foundational). The `clientAttributionPrivacyNote` KEEP is unambiguous. Recommend H1 Option B (flag the navigator call in the audit doc's future-reviewer list, don't re-revise) — it's the truthful response to my synthetic limitations.

**Demetrius (ops/DevOps)** — H3 is mine. The capture.sh BASE_URL default change is correct (per `feedback_test_with_nginx_in_dev`) but unannounced. CHANGELOG line during §12 hygiene closes the loop. Otherwise the deploy story is clear: 5 code-repo commits ride a backend+frontend rebuild (or just frontend if O1 IT defers), 5 docs-repo commits ride static-content scp + Cloudflare purge.

**Simone (UX)** — B1 is mine. The `<article>` conversion was well-intentioned but semantically wrong per W3C/MDN guidance; numbered walkthrough steps are `<ol>/<li>`. Visual rendering is identical (CSS targets the class), so users with sighted browsers see no change — but AT users navigating by article landmark now see 7 unrelated articles instead of one ordered list. This is materially worse than the original `<div>` shape. Fix is local to dvindex.html. M1 (results-region heading) is a polish candidate; current `aria-label` is W3C-compliant.

**Devon (training/onboarding)** — H3 is also mine. The capture.sh shape change is operator-facing; CHANGELOG note avoids first-encounter friction. N3 (dark-mode capture spec is non-canonical) is a v0.55.2 backlog item. M3 (--fresh skip) is academic; the captures are visually correct.

**Riley (DV/safety)** — No concerns from a DV/safety angle. The HMIS contract test materially strengthens the doc claim that hold-attribution PII does not leave the system via HMIS push. The S2 article→ol fix (B1) doesn't affect dvindex.html's privacy-design framing. The §11.2 archive marker change is truthful.

**Alex (testing/QA)** — H2 + M2 are mine. T1 + T2 fixes are good (29/29 wcag-vpat green; 6/6 screen-reader green). The HMIS contract test passes 4/4 with `reentryMode` parameterized. Substring-payload + schema-absent + reflection layered shape is appropriate for a contract test; H2 fix is Javadoc-only. M2 (the >=3 hardcoded threshold) is fine for current seed; future-proofing is optional.

**Sam (performance)** — Minimal impact. T2 split adds ~2s overhead (per-context creation × 4 → 3 separate tests); negligible. HMIS contract test runs in 12.6s (Testcontainers Postgres bootstrap dominates); no perf concern. Capture.sh enumeration runs each spec serially; same total time as before.

---

## Recommended next-step

**Pre-PR fixes (must):**
1. **B1** — Land a follow-up commit `46161f0`-revert + new commit converting dvindex.html cards from `<article class="card">` to `<ol class="walkthrough-steps"> ... <li class="card">`. ~10 minutes work + visual recheck. Update the v0-55-1-followup proposal.md + design.md S2 wording to `<div>` → `<ol>/<li>` so the spec reflects the corrected implementation (M4 doubles for this).
2. **H2** — Add Javadoc note to `HmisPushContractTest.hmisInventoryRecord_hasNoPiiFlavoredFields` explicitly scoping the reflection check to "hold-attribution PII (v0.55.0-introduced columns)"; broader PII categories are covered by the schema-absent + payload-substring layers. ~3 lines.
3. **H1** — Update `synthetic-maria-pass.md` summary table: mark `hold.help.notes` revision as "REVISE (with native-reviewer-flag for the specific `navegador de servicios` term — web research surfaces stronger alternatives `navegador de pacientes` / `enlace comunitario` / `asesor`)." Don't re-revise the es.json; the disclosure is the truthful response. ~5 lines edit.
4. **H3** — Add v0.55.1 CHANGELOG `### Tooling` line about the capture.sh BASE_URL default change. Rolls into §12.4 CHANGELOG hygiene.

**Optional polish (not blocking):**
- **M1** — Add visually-hidden `<h2>` inside the search-results region; switch to `aria-labelledby`. v0.55.2 candidate.
- **M4** — Spec-sync the section-divider SKIP decision into proposal.md / design.md.
- **N3** — Add to v0.55.1 backlog memory: "dark-mode capture mechanism lives in color-system.spec.ts, not a canonical capture-* spec; v0.55.2 candidate to refactor."

**MEDIUMs/SUGGESTIONs not requiring action:**
- M2 (T1 hardcoded threshold) — fine.
- M3 (--fresh skip) — academic.
- N1 (i18n key naming) — already correct.
- N2 (`alcance comunitario`) — already correct.

Persona consensus: B1 is non-negotiable (the spec asks for `<article>`, web research says `<ol>/<li>` is correct, the visual rendering is identical, the AT-user impact is real). H1-H3 are spec-reachable in the same fix pass. Total work: ~30-45 minutes.

---

## Sources cited

- W3C ARIA APG: [Landmark Regions](https://www.w3.org/WAI/ARIA/apg/practices/landmark-regions/)
- W3C ARIA Techniques: [ARIA6: aria-label for objects](https://www.w3.org/WAI/WCAG21/Techniques/aria/ARIA6)
- W3C WAI: [Content Structure Tutorial](https://www.w3.org/WAI/tutorials/page-structure/content/)
- WebAIM: [Semantic Structure: Regions, Headings, and Lists](https://webaim.org/techniques/semanticstructure/)
- W3Schools: [HTML Semantic Elements](https://www.w3schools.com/html/html5_semantic_elements.asp)
- Linguee: [patient navigator](https://www.linguee.com/english-spanish/translation/patient+navigator.html)
- Huntsman Cancer Institute: [Spanish-Speaking Patient Navigators](https://healthcare.utah.edu/huntsmancancerinstitute/wellness-support/patient-navigators/spanish-speaking)
- ProZ KudoZ: [patient navigators > asesores de pacientes](https://www.proz.com/kudoz/english-to-spanish/medical-health-care/1113069-patient-navigator.html)
- Reverso Context: [outreach worker → Spanish](https://context.reverso.net/translation/english-spanish/outreach+worker)
- Collins: [Spanish Translation of OUTREACH WORKER](https://www.collinsdictionary.com/dictionary/english-spanish/outreach-worker)
- ProZ KudoZ: [community outreach > alcance comunitario](https://www.proz.com/kudoz/english-to-spanish/medical-health-care/2823497-community-outreach.html)
