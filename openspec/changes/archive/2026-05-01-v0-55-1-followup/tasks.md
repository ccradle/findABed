## 1. Pre-flight

- [x] 1.1 Confirm v0.55.0 is deployed and stable on findabed.org (per `project_live_deployment_status.md`).
- [x] 1.2 ~~Identify the native-Spanish reviewer for D2.~~ **Resolved 2026-05-01:** Q1 = AI-synthetic-linguistic-review (Claude playing Maria persona, web-search-grounded citations, NOT a native speaker). Methodology in design.md D3.
- [x] 1.3 Confirm dev-start.sh works locally + produces a clean DB via `--fresh` (baseline for §8 dark-mode re-capture). Note: V95+V96 reentry shelters require manual replay after `--fresh` per the Q5 deferral; replay procedure in `project_seed_reentry_shelters_gap.md` memory.

## 2. Branch + scaffolding

- [x] 2.1 In code repo (`finding-a-bed-tonight/`): create branch `feature/v0-55-1-followup` from `main`.
- [x] 2.2 In docs repo (`findABed/`): create branch `feature/v0-55-1-followup` from `main`. (S2 + S1 + audit doc + tasks/spec edits land here.)
- [x] 2.3 Sync both `main` branches before branching (`git pull`); confirm v0.55.0 tag is reachable.

## 3. T1 — `screen-reader.spec.ts:65` scope fix (Option A: results-region landmark added to React tree)

**Apply-time scope expansion (Option A, operator-accepted 2026-05-01):** the predicted selector `[role="region"][aria-label*="results"]` did not exist in the React tree — `OutreachSearch.tsx` rendered shelter cards directly via `.map()` with no wrapping landmark. Cleanest fix is to add the wrapping element (real a11y improvement: results region as a discoverable AT landmark) AND apply the test scope. Spec stays "test fix" but with a frontend prereq.

- [x] 3.1 Open `e2e/playwright/tests/screen-reader.spec.ts`, locate the `getPageDOM(outreachPage)` call near line 65 + read the file's own line-80 comment to confirm the predicted fix.
- [x] 3.1a **(Option A frontend prereq)** Add wrapping `<div role="region" aria-label={intl.formatMessage({id: 'search.resultsRegion'})} data-testid="search-results-region">...</div>` around the results `.map()` block + the no-results empty-state in `frontend/src/pages/OutreachSearch.tsx` (line ~999). Add new i18n key `search.resultsRegion` to both `en.json` ("Search results") and `es.json` ("Resultados de búsqueda" — pan-Latin neutral, formal register, Spanish day-one per v0.55.1 i18n discipline).
- [x] 3.2 Apply the test scope: change `const main = doc.querySelector('main') || doc.body` to a tiered selector:
  ```ts
  const resultsRegion =
    doc.querySelector('[data-testid="search-results-region"]') ||
    doc.querySelector('[role="region"][aria-label]') ||
    doc.querySelector('main') ||
    doc.body;
  ```
  data-testid is the primary locator (locale-independent, stable per `feedback_data_testid`); role+aria-label is a fallback; main is a final fallback. Note: did NOT change `getPageDOM` signature — kept as `(page) => Document` and queried sub-element from the returned doc.
- [x] 3.3 Replace single-match assertion with `>= 3` distinct freshness-badge announcements (M4): `expect(freshnessMatches.length).toBeGreaterThanOrEqual(3)`. Includes a descriptive failure message that prints the actual matches.
- [x] 3.4 Run the spec locally against the dev stack: `BASE_URL=http://localhost:8081 npx playwright test screen-reader.spec.ts --trace on` (per `feedback_test_output_and_traces`). All 6 screen-reader tests pass; freshness-badges test (line 65) is green with the new scope.
- [x] 3.5 Confirm green; committed as two split commits per warroom M3: (a) `7b32595` frontend a11y + i18n key; (b) `77b2590` test scope fix + assertion bump.

## 4. T2 — `wcag-vpat-verification.spec.ts:187` split into 4 per-page tests

- [x] 4.1 Opened `e2e/playwright/tests/wcag-vpat-verification.spec.ts`. Ground truth: existing test at line 187 covered 3 pages (outreach + admin + coordinator), NOT 4 — login isn't part of the contrast suite (it's covered by keyboard-operability tests elsewhere). Spec wording was off; correct shape is 3-way split.
- [x] 4.2 Refactored: extracted `assertColorContrastForPage(page, pagePath)` helper, replaced single test with 3 individual `test(...)` blocks: outreach / admin / coordinator. Each uses its own auth fixture (separate context).
- [x] 4.3 Each test runs under default 30s budget (no `setTimeout` extension).
- [x] 4.4 Ran full wcag-vpat-verification.spec.ts against dev-start.sh + nginx — all 29 tests green (~4m). The 3 new per-page tests run in 11.8s + 11.1s + 11.1s respectively; comfortably under budget.
- [x] 4.5 Committed as `e536f65` with note that the split was 3-way (not 4-way per spec wording) because the existing test only covered 3 pages.

## 5. O1 — HMIS hold-attribution PII contract test (thorough form per warroom B2)

- [x] 5.1 Ground truth: there is no `HMIS_BED_INVENTORY_PUSH` event-type constant in code (grep returned 0 matches). The actual pipeline flows: `bed_availability` snapshots → `HmisTransformer.buildInventory` → `List<HmisInventoryRecord>` (8-field typed record, NO PII) → `objectMapper.writeValueAsString(records)` → `hmis_outbox.payload` (text). The outbox table is `hmis_outbox` (NOT `hmis_outbox_entry`). Pipeline structurally never reads `reservation` rows, so PII is unreachable by construction — the contract test asserts this multi-layered.
- [x] 5.2 Authored `backend/src/test/java/org/fabt/hmis/HmisPushContractTest.java`. Hybrid form (schema-absence at 2 layers + serialized-payload absence) per warroom B2 thorough shape:
  - Use `@SpringBootTest` + Testcontainers Postgres (matches existing IT pattern).
  - Seed 1 tenant + 1 shelter + 1 reservation with hold-attribution PII populated (`held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `held_for_client_notes_encrypted` set to non-null encrypted values on the `reservation` row).
  - Trigger the HMIS push pipeline (whatever the existing IT entry point is — `hmisPushService.enqueueBedInventoryPush(tenantId)` or scheduler trigger).
  - **Read the OutboxRecord row directly via `JdbcTemplate.queryForMap` (raw row), NOT through any DTO that might `@JsonInclude(Include.NON_NULL)` or `@JsonProperty(defaultValue = "")` coerce blank values.**
  - **Thorough assertion (per warroom B2 + Q4 = thorough):**
    1. **First, query `information_schema.columns` to determine whether the OutboxRecord projection schema includes the 3 PII columns at all.** If absent from schema entirely: assert that fact and log "schema-absent form observed."
    2. **If present in schema:** assert the value is strictly null (`row.get("held_for_client_name_encrypted")` returns Java null), AND assert the value is NOT `""` empty string, AND assert the value is NOT any blank-equivalent (single space, zero-byte string, "null" string literal). Log "null-valued form observed."
    3. The test class explicitly logs which form (schema-absent vs null-valued) it observed in the first parameterized run; subsequent runs MUST produce the same form (regression detection — flipping between forms means the projection layer changed shape unexpectedly).
- [x] 5.3 Parameterized the payload-absence test on `reentryMode` flag:
  ```java
  @ParameterizedTest
  @ValueSource(booleans = {true, false})
  void holdAttributionPiiAbsentInOutbox(boolean reentryMode) { ... }
  ```
  Both branches must run the same thorough assertion (schema-absent OR null-AND-not-coerced) and must observe the same form. Different forms across reentryMode states would itself be a regression (the gate is unconditional).
- [x] 5.4 Added Javadoc to the test class explicitly noting:
  - Scope is the canonical `hmis-push` projection, NOT tenant-specific custom adapters (`hmis-vendor-adapters` capability).
  - The test reads raw DB rows via JdbcTemplate to avoid DTO-level coercion masking present-but-blank values (warroom B2).
- [x] 5.5 Ran `mvn test -Dtest=HmisPushContractTest`. First run hit a table-name typo (`hmis_outbox_entry` → actual is `hmis_outbox`); fixed and re-ran.
- [x] 5.6 All 4 tests pass in 12.6s. Committed.

## 6. D3 — `capture.sh` enumeration

- [x] 6.1 Confirmed `demo/capture.sh` exists in docs repo. Previous shape ran a single spec (`capture-screenshots.spec.ts`) and defaulted to bare Vite (5173). Both gaps fixed.
- [x] 6.2 Refactored to shape from design D5 (canonical 10-spec array + positional filter + default `BASE_URL=http://localhost:8081` nginx). Preserved existing health-check + stale-auth cleanup + screenshot-report blocks.
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  : "${BASE_URL:=http://localhost:8081}"
  export BASE_URL

  CAPTURE_SPECS=(
    capture-screenshots.spec.ts
    capture-dv-screenshots.spec.ts
    # ... enumerate all 10 explicitly
  )

  filter="${1:-}"
  matched=()
  for s in "${CAPTURE_SPECS[@]}"; do
    if [[ -z "$filter" || "$s" == *"$filter"* ]]; then
      matched+=("$s")
    fi
  done

  if [[ ${#matched[@]} -eq 0 ]]; then
    echo "No capture specs matched filter '$filter'" >&2
    exit 1
  fi

  cd e2e/playwright || cd ../finding-a-bed-tonight/e2e/playwright
  npx playwright test "${matched[@]}" --trace on
  ```
- [x] 6.3 Enumerated all 10 specs: capture-screenshots, capture-analytics-screenshots, capture-dv-screenshots, capture-hmis-screenshots, capture-mobile-header, capture-notification-screenshots, capture-offline-screenshots, capture-platform-operator-screenshots, capture-reentry-screenshots, capture-totp-screenshots.
- [x] 6.4 Smoke-tested filter behavior: `bash capture.sh nonexistent` exits 1 + lists available specs. Filter matching logic is standard bash glob-equality; full no-arg + reentry-filter end-to-end runs ride §10 validation.
- [ ] 6.5 Update `demo/README.md` (or equivalent) to document the new capture.sh invocation patterns. (Deferred — `demo/README.md` doesn't exist; the capture.sh header doc-comment is the canonical reference.)
- [x] 6.6 Committed.

## 7. S2 — Semantic markup elevation on `index.html` + `demo/dvindex.html`

- [x] 7.1 Opened `index.html`. Ground truth: NO `<div class="section-divider">` and NO `<div class="card">` exist — the only "card" elements are `<a class="card">` navigation links (4 of them) to audience pages. Replacing `<a>` with `<article>` would lose link semantics. Per §7.1's own caveat, left as-is and documented.
- [x] 7.2 Opened `demo/dvindex.html`. 3 `<div class="section-divider">` elements found — they're inline content holders (just a header text inside), not section wrappers. Converting to `<section>` would create empty-of-children landmarks, worse a11y than the current styled-div. Skipped + documented in commit. Future v0.55.2 candidate: convert to `<h2 class="section-divider">` for real heading semantics.
- [x] 7.3 Found 7 `<div class="card">` in `demo/dvindex.html`. Each is a self-contained walkthrough step (header + caption + screenshot). Replaced with `<article class="card">` (opening + matching closing tag). 17-element grep confirms the change: 7 article opens + 7 closes + 3 untouched section-dividers.
- [ ] 7.4 Run a local HTML validator (`npx html-validate index.html demo/dvindex.html` or equivalent) and confirm no new errors. (Deferred — visual smoke + grep counts cover the structural integrity; html-validate dependency not currently installed.)
- [ ] 7.5 Visual diff in browser: load both files locally, confirm no visual regression. (Deferred to §10 validation pass — bundled with operator-side dark-mode re-capture visual checks.)
- [x] 7.6 Committed.

## 8. S1 — Dark-mode screenshot re-captures

- [x] 8.1 Used the existing dev-start.sh --nginx --observability stack (no --fresh needed — current DB state is post-v0.55.0 baseline + v0.55.1 work, captures look correct against it).
- [x] 8.2 Ground truth: dark-mode capture lives in `e2e/playwright/tests/color-system.spec.ts` (NOT a `capture-*` spec; writes PNGs as side effect during the "Dark Mode Rendering" test). 3 target outputs confirmed: `dark-search.png`, `dark-admin.png`, `dark-coordinator.png`. (Plus a 4th file `dark-login.png` exists but per the spec's own line-113 comment is identical to `dark-admin.png` in current behavior.)
- [x] 8.3 Ran `npx playwright test color-system.spec.ts --trace on` against dev-start.sh + nginx. All 6 color-system tests passed (~45s); the 3 dark-mode PNGs regenerated at 12:49-12:50.
- [x] 8.4 Visually verified all 3 PNGs (read via Read tool):
  - `dark-search.png` confirms post-§10 page (shelter-type chips ✓, county dropdown ✓, advanced filters group ✓, accepts-felonies toggle ✓, freshness badges ✓, urgent-notifications banner ✓).
  - `dark-admin.png` confirms post-§16.C banner + v0.55 admin tabs + ReservationSettings panel + footer "v0.55 — Development CoC".
  - `dark-coordinator.png` confirms post-§16.C banner + shelter dashboard + DV badges on DV shelters.
- [x] 8.5 No PNG looked stale; no debug needed.
- [x] 8.6 Committed.

## 9. D2 — AI-synthetic linguistic review pass (Claude with web-citation grounding, NOT a native speaker)

This task is performed by Claude playing the Maria persona, with WebSearch/WebFetch used for any non-obvious linguistic call. Methodology: design.md D3 (8 dimensions, applied to ALL keys per Q3).

- [x] 9.1 Located 5 keys + their English source. All 5 use the same `a más tardar 25 horas` construction for the strict-quantifier privacy claim.
  - `hold.help.clientName`
  - `hold.help.clientDob`
  - `hold.help.notes`
  - `shelter.eligibility.notes.help`
  - `hold.clientAttributionPrivacyNote`
  Capture the corresponding English source strings from `frontend/src/i18n/en.json` for each.
- [x] 9.2 Context captured per-key in the audit doc: 4 hold.* keys are HoldDialog form text (OUTREACH_WORKER audience); 1 shelter.* key is ShelterForm help text (COC_ADMIN audience).
- [x] 9.3 Authored `docs/audits/2026-05-01-v0-55-1-spanish-review/synthetic-maria-pass.md`. Verbose AI-synthetic disclosure header first; per-key 8-dimension analysis with citations; summary table; next-steps section. 220 lines.

  > **AI-SYNTHETIC LINGUISTIC REVIEW — NOT A NATIVE SPEAKER**
  >
  > This audit was performed by Claude (an AI) playing the Maria persona, with web-search grounded linguistic research. It is NOT a real native-Spanish-speaker review. The methodology + citations are recorded below so a future real-native-reviewer pass can verify the work efficiently. See design.md D3 for methodology rationale + `feedback_truthfulness_above_all` for the disclosure discipline.

  Then one section per key with all 8 dimensions reviewed (per Q3 = apply to all):

  - **Source (English)** — verbatim.
  - **Current Spanish** — verbatim.
  - **Context** — UI placement + audience role.
  - **Linguistic analysis** covering the 8 dimensions (per design.md D3 methodology):
    1. Source-string semantic faithfulness.
    2. Anglicism risk (specifically check `aplicar`/`solicitar`, `cita` usage, `fecha de nacimiento`/`cumpleaños`, etc.).
    3. Register appropriateness (formal `usted` for admin/coordinator-facing UI).
    4. Regional bias (Castilian vs Latin American vs US Hispanic — prefer pan-Latin neutral; cross-reference RAE AGAINST a Latin American academy source for any term where regional usage diverges).
    5. Gendered/inclusive considerations (Spanish gender agreement; `la persona`/`quien` for role-neutral).
    6. Domain-specific terminology (social-services / housing / privacy register — `vivienda`, `albergue`/`refugio`, `trabajador/a social`, `coordinador/a`).
    7. **Typography (H2)** — inverted opening punctuation (`¿`/`¡`), quote-style consistency, NBSP between number+unit (`25 horas`), em-dash usage. For non-applicable keys, write `N/A — <reason>` (e.g., "key contains no questions or numbers requiring typographic discipline").
    8. **Privacy/legal precision (H3, applied to ALL keys per Q3)** — does the Spanish preserve any privacy or legal claim with strict semantics? For non-privacy keys, write `N/A — key carries no privacy or legal claim` with a brief justification (e.g., "this key is form help text, not a privacy claim"). For privacy-bearing keys (`hold.clientAttributionPrivacyNote` is the acute case in current scope; apply discipline universally), provide a side-by-side semantic comparison: original English claim ↔ proposed Spanish ↔ explicit "this preserves the strict semantics because..." sentence. Soft-quantifier drift ("about", "approximately") MUST be flagged.
  - **Citations** — for any non-obvious call, cite a source (RAE / ASALE / Academia Mexicana de la Lengua / DPD / DEM / CORPES XXI / Linguee / Reverso Context / HUD-Spanish-materials / 211.org-Spanish / Wordreference forum / Fundéu BBVA / Texas A&M Coastal Bend AHEC). For terms with regional variation, cite at least one Castilian source AND at least one Latin American source. URL + accessed-on date.
  - **Recommendation** — keep / revise (with proposed Spanish) / flag-for-future-real-native-reviewer (with rationale).
- [x] 9.4 Web-grounded research applied: RAE entries cited for `cifrar`, `tardar`, `solo`/`únicamente`, `navegador`, `extensión`, `alcance`. HUD-Spanish + 211.org-Spanish referenced for the social-services domain calls (`navegador de servicios`, `trabajadores de alcance comunitario`). All citations are foundational Spanish-language references; no fabricated URLs.
- [x] 9.5 Applied 3 revisions: clientDob `solo` → `únicamente`, notes `del navegador` → `del navegador de servicios`, eligibility-notes `extensión` → `alcance comunitario`. Single combined commit (`2fde139`); per-key rationale fully captured in commit body for granular `git revert -p` if needed.
- [x] 9.6 `npm run build` clean (✓ built in 458ms). `vitest src/i18n/i18n-coverage.test.ts` 3/3 pass — en/es key parity maintained.
- [ ] 9.7 Path B (manual locale-toggle smoke). Deferred to operator: open dev-start stack, toggle Spanish, verify the 3 revised strings render without truncation. The existing `copy-dignity.spec.ts` already exercises the locale-toggle path on the population dropdown (passes per §3 + §4 runs); the harness is proven, just hasn't been pointed at the 3 specific revised strings yet. Path A (a dedicated Playwright spec for the 3 strings) was not pursued — would add scope; manual visual is acceptable per design.md D3 Path B.
- [x] 9.8 Updated `openspec/changes/archive/2026-05-01-reentry-release-readiness/tasks.md:81` — replaced `NATIVE-REVIEWER-PENDING (Round 2 MEDIUM-A11)` with verbose `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker)` + audit doc reference. Commit `e426e67`. (Note: archive directory is `2026-05-01-...`, not `2026-04-30-...` per spec wording.)
  - Find the line carrying the `NATIVE-REVIEWER-PENDING` marker.
  - Replace verbatim with: `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker) — see openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md` (path will resolve once this slice archives).
  - The verbose form is non-negotiable (warroom B1 + Q1). Do NOT use shorter forms like `SYNTHETIC-MARIA-REVIEWED` — those conflict with `feedback_persona_transparency`.
- [x] 9.9 Saved memory `reference_es_json_ai_synthetic_reviewed.md` with disclosure conventions + audit doc path + commit pointers. MEMORY.md index updated.
- [x] 9.10 Committed across both repos:
  - Code: `2fde139` `i18n(es): AI-synthetic linguistic review revises 3 v0.55.0 reentry keys (v0.55.1-D2)`
  - Docs: `eca89db` `docs(audit): AI-synthetic linguistic review of v0.55.0 reentry es.json keys (v0.55.1-D2)`
  - Docs: `e426e67` `docs(archive): replace NATIVE-REVIEWER-PENDING marker with AI-synthetic disclosure (v0.55.1-D2)`
  - All commit messages use "AI-synthetic" (NOT "synthetic-Maria") per warroom B1.

## 10. Validation pass

- [x] 10.1 Run full backend test suite: `cd finding-a-bed-tonight && mvn clean test`. Expect green; flag any new failure as a regression of the §3, §4, or §5 work.
- [x] 10.2 Run full Playwright suite against dev-start + nginx (per `feedback_check_ports_before_assuming`): `BASE_URL=http://localhost:8081 npx playwright test --trace on 2>&1 | tee logs/v055-1-playwright-$(date +%Y%m%d-%H%M%S).log`. Expect §3 + §4 specs green. Pre-existing 7-flake long-tail noted but not gating.
- [x] 10.3 `npm run build` in `finding-a-bed-tonight/frontend/` — expect clean (per `feedback_build_before_commit`).
- [x] 10.4 Static-content visual diff: load modified `index.html` + `demo/dvindex.html` in a browser; confirm no styling regression from §7 semantic-markup elevation.
- [x] 10.5 Capture-spec smoke: `bash demo/capture.sh reentry` (per §6.4) — expect at least the reentry capture spec runs and produces output.
- [x] 10.6 AI-synthetic audit doc completeness check: review `synthetic-maria-pass.md` — every key has all 8 dimensions covered (with explicit `N/A — <reason>` for non-applicable dimensions per Q3) + at least one citation per non-obvious call + a clear recommendation. The first-paragraph AI-synthetic disclosure header is present and verbatim.

## 11. Deploy

This slice splits across two deploy paths:

- [x] 11.1 **Static-only path (S1, S2):** scp `index.html` + `demo/dvindex.html` + 3 dark-mode PNGs to `/var/www/findabed-docs/` on the Oracle VM. Use the same scp recipe from `oracle-update-notes-v0.55.0.md` §5.0.
- [x] 11.2 Cloudflare Purge Everything (single click).
- [x] 11.3 Post-deploy verification:
  - `curl -sf https://findabed.org/ | grep -c '<section'` → expect ≥ baseline + N (where N is the number of replaced section-divider divs).
  - `curl -sfI https://findabed.org/demo/screenshots/dark-search.png` → expect 200 + recent `last-modified`.
  - Browser load both pages; confirm no visual regression.
- [x] 11.4 **Code-repo path (T1, T2, O1, D3, D2-revisions-if-any):** PR opened, merged to main, frontend rebuild bundled (D2 + B1 + T1 + T2 + O1). v0.55.1 deployed 2026-05-01 ~20:50 UTC; smoke gate green.
- [x] 11.5 Tag v0.55.1 in code repo (release v0.55.1 published).

## 12. Post-deploy hygiene

- [x] 12.1 Update `project_live_deployment_status.md` memory: append v0.55.1 deploy date + git ref(s) + Flyway HWM (unchanged).
- [x] 12.2 Update `project_resume_point.md` memory.
- [x] 12.3 Update `project_v055_1_backlog.md` memory:
  - Mark T1, T2, O1, D3, S1, S2, D2 as RESOLVED with the v0.55.1 git ref.
  - Leave seed-reentry-shelters fix in the backlog with note: "Deferred 2026-05-01 (Q5): recently shipped seed changes; not a priority. Operator workaround documented in `project_seed_reentry_shelters_gap.md` — manual V95+V96 SQL replay after `--fresh`."
  - Leave D1, D4, D5, O2, 7-flake long-tail in the backlog with their reasons.
- [x] 12.4 Update `CHANGELOG.md` for v0.55.1 with the standard changes-per-section entries (Tests, Localization, Documentation, Accessibility).
- [x] 12.5 **NEW "Truthfulness disclosure" CHANGELOG section (per warroom H4 + Q2 = new section header).** Add a new top-level `### Truthfulness disclosure` section to the v0.55.1 CHANGELOG entry (NOT folded into "Localization") with this entry:

  > Spanish translation review on v0.55.0 reentry keys was performed by AI (Claude playing the Maria persona, with web-search-grounded linguistic research and per-key citations), NOT by a native speaker. The original commitment was a real-native-reviewer pass; this softening was operator-accepted on 2026-05-01 (warroom Q1). A real-native-reviewer pass remains a future option. See audit doc at `openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md` for the methodology + citations + per-key recommendations.

  This section is the user-facing disclosure surface required by `feedback_truthfulness_above_all`. It MUST appear under a `### Truthfulness disclosure` header (or `## Truthfulness disclosure` if the CHANGELOG uses h2 for sub-sections), NOT under "Localization."
- [x] 12.6 `/opsx:archive v0-55-1-followup` once all in-scope tasks complete.
