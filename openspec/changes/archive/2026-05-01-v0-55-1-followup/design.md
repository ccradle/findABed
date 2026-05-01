## Context

v0.55.0 shipped to prod 2026-04-30 as the reentry-release-readiness slice. Warroom Round 5 + persona consensus during §12 validation accepted a set of carryover items as v0.55.1 work — none cleared the v0.55.0 release bar of "no real safety/a11y regression," but each is real operational hygiene, a real test gap, or a real reviewer gate.

The carryover memory `project_v055_1_backlog.md` (origin session 5335dd17) lists items by category: test-design fixes (T1+T2), capability deferrals (D1-D5), operational followups (O1-O2), demo follow-ups (S1-S2), and a 7-test pre-existing flake long-tail. This change formalizes a subset as the v0.55.1 slice; D1, D4, D5, O2, and the long-tail are explicitly out of scope (deferred or tracked separately).

Stakeholders: synthetic-Maria-with-web-grounded-research (Claude-as-Maria, per-key linguistic analysis with cited sources) for D2 — Q1 resolved 2026-05-01; Tomás for T2 split decision; Sam for T1 scope-fix; Simone (warroom 2026-04-30) for O1 contract-test gap; Devon for D3 capture.sh ergonomics.

## Goals / Non-Goals

**Goals:**

- Restore CI red-marker hygiene by fixing T1+T2 test-design regressions tickled by §10 page expansion (NOT prod regressions).
- Close a softened version of the D2 commitment: synthetic-Maria-with-web-grounded-research signs off the 5 warroom-drafted es.json keys, with citations + transparent methodology recorded in this slice's audit doc. Fully-real-native-reviewer remains a future option but is not the gate today.
- Close the operational gap on O1: an automated assertion (not just doc claim) that hold-attribution PII never leaves the backend via HMIS push.
- Land D3 capture.sh enumeration so capture-spec runs are scriptable and discoverable.
- Refresh dark-mode screenshots that predate §11 dialog reshape + §16.C frontend gates (S1).
- Promote `<div>` → semantic `<section>`/`<article>` on root index + dvindex (S2 — accessibility hygiene).

**Non-Goals:**

- **Seed-reentry-shelters `--fresh` fix.** Q5 resolved 2026-05-01: deferred. Recent seed-data changes already shipped in v0.55.0; another edit is not a priority. Operator workaround (manual V95+V96 SQL replay after `--fresh`) remains documented in `project_seed_reentry_shelters_gap.md` memory. A future slice can re-pick it up.
- D1 (§13.D detail-endpoint refinement). Superseded for default-off tenants by §16.B serialization gate; defer until an opt-in tenant accumulates read-traffic patterns warranting separate handling.
- D4 (§11.5a mobile + a11y multi-viewport spec). Significant separate scope; defer when shape stabilized.
- D5 (§13.C.3 >10K-row purge load test). Production safety cap (100 × 10K = 1M rows) is well above realistic backlog; bounded-loop is exercised by `purge_emitsAuditRowEvenOnZeroCount`.
- O2 (§13.A.4 audit-attribution refinement). Marcus + Riley + Alex accepted as design-correct; refinement candidate only if forensic queries show value.
- 7-test pre-existing flake long-tail. Triage in a separate v0.55.x stabilization slice if any block CI gating; this change is not the place to absorb them.
- Any new feature work, any backend image change beyond the O1 IT, any frontend code change beyond what D2's review surfaces (likely zero).

## Decisions

**D1 — T1 fix is a 2-line scope change at `screen-reader.spec.ts:65`, NOT a probe-window expansion.**

The test reads accumulated screen-reader output via `getPageDOM(outreachPage)` and asserts `/Fresh|Stale|Unknown/` matches somewhere in the first 100 steps. §10 added 7 shelter-type chips + 101-county dropdown + advanced-filters group + accepts-felonies toggle to the outreach page; the freshness badges (deep in shelter cards) now sit past step 100. The test file's own line-80 comment explicitly predicts the fix: scope `getPageDOM(outreachPage)` to `[role="region"][aria-label*="results"]`.

**Why scope-fix over expand-the-window?** AT users navigate by landmark, not sequentially. The probe should already be scoped; widening the accumulation window papers over a test-design oversight. Sam + Tomás verdict: NOT a real a11y regression. The scope-fix is also strictly cheaper to maintain (smaller window = faster runs).

**D2 — T2 fix is a 4-way split into per-page tests, NOT a test-timeout extension.**

`wcag-vpat-verification.spec.ts:187` creates 4 fresh contexts and runs full-page axe-core color-contrast on login + outreach + coordinator + admin within a 30s budget. Post-§10 outreach is large enough that the cumulative work no longer fits. The targeted color-contrast probe (`reentry-search-contrast-probe.spec.ts`, committed in `fccbbee`) confirms zero violations on the post-§10 search page — purely a budget regression.

**Why split over `test.setTimeout(60_000)`?** Cleaner failure attribution (which page actually failed?), parallelizable, and the 30s-per-test contract is a healthier default than a 60s blanket. Sam recommends; Tomás concurs.

**D3 — D2 review pass is performed by Claude-as-Maria with web-grounded linguistic research. The disclosure marker is verbose and unambiguous: `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker)`.**

Q1 resolved 2026-05-01: real-native-reviewer isn't available; the operator accepts AI-synthetic-with-web-research as a softening of the prior commitment. Per `feedback_truthfulness_above_all` + `feedback_persona_transparency`, this softening is recorded transparently:
- Marker text in the reentry-release-readiness archive: `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker) — see openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md`. The verbose form (Q1=verbose) is non-negotiable; "synthetic-Maria-reviewed" alone could read as "the persona Maria reviewed it" and conflict with the no-personas-as-real-contributors rule.
- v0.55.1 CHANGELOG carries a NEW "Truthfulness disclosure" section header (Q2 resolved) with a one-line repeat of the same disclosure.
- Audit doc filename stays `synthetic-maria-pass.md` for internal continuity, but the doc's first-paragraph header explicitly states: "This audit was performed by Claude (AI) playing the Maria persona, with web-search grounded linguistic research. NOT a real native-speaker review."

Future real-native-reviewer pass remains an open option but is not the v0.55.1 gate.

The 5 keys are: `hold.help.clientName`, `hold.help.clientDob`, `hold.help.notes`, `shelter.eligibility.notes.help`, `hold.clientAttributionPrivacyNote`. They were warroom-drafted (Casey/Keisha voice constraints) and synthetic-Maria functionally validated for v0.55.0 ship.

**Methodology — per-key 8-dimension linguistic analysis with cited sources:**

For each key (apply ALL 8 dimensions; non-applicable dimensions get an explicit `N/A — <reason>` line, per Q3 resolution):

1. **Source-string semantic faithfulness** — does the Spanish render the English meaning, including any constraint or nuance (e.g., "as on government ID" must convey the formal-document specificity, not just "any name")?
2. **Anglicism risk** — flag any Spanish word that's a calque from English where a more natural Spanish term exists (common offenders: `aplicar` for "apply" — `solicitar` is preferred in formal social-services Spanish; `cita` for "appointment" is fine but `compromiso` is wrong; `fecha de nacimiento` not `cumpleaños`).
3. **Register appropriateness** — is the formality right for admin/coordinator-facing UI in social services? (Generally formal `usted` register, neutral diction, no colloquialisms.)
4. **Regional bias** — flag terms that are Castilian-only or US-Hispanic-only when the user base spans Latin America + US Hispanic. Prefer pan-Latin neutral terms; cite when a regional variant is acceptable (e.g., `archivo` vs `fichero` — `archivo` is universal). Cross-reference RAE (Castilian-leaning) AGAINST a Latin American academy source for any term where regional usage diverges.
5. **Gendered/inclusive considerations** — Spanish requires grammatical gender agreement. For role-neutral admin UI ("the client"), prefer gender-neutral constructions (`la persona`, `quien`) where possible without breaking grammar. Note any forced-binary cases.
6. **Domain-specific terminology** — social-services / housing terminology has conventional Spanish equivalents (`vivienda` for housing, `albergue`/`refugio` for shelter, `trabajador/a social` for caseworker, `coordinador/a de servicios` for coordinator). Cite glossary sources.
7. **Typography (H2)** — inverted opening punctuation (`¿`/`¡`) where applicable; quote-style consistency (Spanish-style `«»` vs US-style `""` — pick one and stay consistent across keys); non-breaking space between number + unit (`25 horas` should be `25 horas` with NBSP per most social-services style guides); em-dash usage in clauses; smart-quote vs straight-quote consistency. Cite RAE *Ortografía*, Fundéu, or Texas A&M Coastal Bend AHEC if a US-Hispanic context applies.
8. **Privacy/legal precision (H3, applied to ALL keys per Q3)** — does the Spanish preserve any privacy or legal claim with strict semantics? Soft-quantifiers ("about", "around", "approximately") MUST NOT replace strict ones ("no later than", "exactly", "at most"). For non-privacy keys, this dimension surfaces as `N/A — key carries no privacy or legal claim` with a brief justification. For privacy-bearing keys (most acutely `hold.clientAttributionPrivacyNote`, but apply discipline universally), provide a side-by-side semantic comparison: original English claim ↔ proposed Spanish ↔ explicit "this preserves the strict semantics because..." sentence.

**Web-research grounding:** when a call is non-obvious, cite a source. Acceptable sources include:
- **RAE** (Real Academia Española dictionary) — definitive for word meaning + form. Note: Castilian-leaning normative authority.
- **ASALE** (Asociación de Academias de la Lengua Española — RAE + 22 Latin American academies, joint normative authority). Use when pan-Latin neutrality matters more than RAE alone.
- **Academia Mexicana de la Lengua** + the *Diccionario del español de México* (DEM). For terms with significant Mexican-Spanish usage (largest Spanish-speaking population).
- **DPD** (Diccionario panhispánico de dudas, joint RAE+ASALE) — disambiguates regional + register questions.
- **Banco de Datos de la Academia / CORPES XXI** — corpus query for real frequency of regional variants.
- **Linguee** + **Reverso Context** — corpus-based; show real bilingual usage in social-services / legal / privacy contexts.
- **HUD Spanish-language materials** + **211.org Spanish pages** + **Texas A&M Coastal Bend AHEC Spanish health-literacy guides** — domain-specific social-services glossaries.
- **Wordreference Spanish-English forum** — crowd-sourced register/usage from real bilingual speakers; useful for borderline calls.
- **Fundéu BBVA** — style guidance, especially for typography + register questions in journalistic/formal Spanish.

Cite at least one source per non-obvious call, with URL + accessed-on date. For terms with regional variation, cite at least one Castilian source AND at least one Latin American source.

**Deliverable:** `docs/audits/2026-05-01-v0-55-1-spanish-review/synthetic-maria-pass.md` containing per-key analysis (English source, current Spanish, all 8 dimensions reviewed, citations, recommendation: keep / revise / flag-for-future-real-native-reviewer). The doc's first-paragraph header carries the AI-synthetic disclosure (above). Any "revise" recommendations land in `frontend/src/i18n/es.json` in this slice. Any "flag-for-future-real-native-reviewer" items go to v0.55.2 backlog with the rationale.

**Why not auto-translate?** Auto-translation lacks register and domain-terminology grounding. The methodology above is closer to a real linguistic review than a black-box translation API.

**Why is this acceptable as a softening?** Per the operator's framing and Q1 resolution: AI-synthetic-with-citations is a real linguistic effort with a transparent paper trail. It is materially better than synthetic-Maria-with-no-grounding (which served v0.55.0 ship). It is materially worse than a real native-reviewer signoff. The spec marker + audit doc preserve the option to upgrade to a real-reviewer pass later without re-doing the work — the citations make a future real reviewer's job faster.

**D4 — O1 HMIS contract test asserts column-level absence on the OutboxRecord, not payload-level absence after deserialization.**

The 3 hold-attribution PII columns (`held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `held_for_client_notes_encrypted`) live on the `reservation` table. HMIS push payloads are projected from a query that JOINs `reservation`. The contract test asserts the OutboxRecord rows for an `HMIS_BED_INVENTORY_PUSH` event type carry `null` for the 3 columns when projected — not after deserialization, not after wire-level inspection. Reason: the JOIN-projection layer is the single point where the PII fields are either included or excluded; testing column-level absence proves the projection is correct without depending on JSON-shape brittleness.

The test runs with both `tenant.config.features.reentryMode = true` and `= false` to prove the absence is unconditional (the spec says "regardless of tenant flag state").

**Alternative considered:** assert payload-level absence post-serialization. Rejected because (a) it's downstream of the actual gate (the projection), and (b) it depends on JSON shape brittleness — a Jackson `@JsonIgnore` move could mask a projection regression.

**D5 — D3 capture.sh enumeration: explicit positional filter, default BASE_URL, no glob discovery.**

The 10 capture specs are enumerated by name in a bash array. No-args = run all. One positional arg = filter; only specs containing the substring run. No-match = exit non-zero with a helpful "no specs matched" message. Default `BASE_URL=http://localhost:8081` if unset (per `feedback_smoke_spec_default_target` — never default to findabed.org).

**Why not glob the test directory?** Glob discovery is fragile when capture specs and verification specs share the directory; explicit enumeration documents which specs are capture-purpose.

## Risks / Trade-offs

**[Risk] Synthetic-Maria pass missesa real native-speaker idiomatic call and a reviewer would have caught.**
*Mitigation:* per-key analysis with cited sources (per D3 methodology) is the floor; any borderline call is documented + flagged. The audit doc preserves the citation chain so a future real-native-reviewer can scan only the flagged items, not redo the whole pass. Acceptance is explicit per Q1 resolution; the softening is recorded transparently in proposal + design + spec marker.

**[Risk] AI-synthetic signoff is mistaken later for a real-native-reviewer signoff (truthfulness regression).**
*Mitigation:* per Q1 (verbose marker), the marker text in the reentry-release-readiness archive is the unambiguous form `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker) — see openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md`. Per Q2 (new section), the v0.55.1 CHANGELOG carries a NEW "Truthfulness disclosure" section header (NOT folded into "Localization") with a one-line repeat of the disclosure. The audit doc itself opens with an explicit AI-synthetic header note. Per `feedback_truthfulness_above_all` + `feedback_persona_transparency`, anyone reading the marker, the CHANGELOG, or the audit doc can trace the actual review methodology and decide whether a real-native-reviewer pass is still warranted.

**[Risk] T2 split increases total test runtime by 3× the per-context-creation overhead.**
*Mitigation:* per-context creation is ~500ms; 4 tests = ~2s overhead. Negligible against the ~30s budget per test.

**[Risk] O1 contract test passes locally but the production HMIS adapter actually projects PII (tenant-config-driven adapter selection).**
*Mitigation:* the contract test runs against the canonical `hmis-push` projection layer, NOT a tenant-specific adapter. If a tenant configures a custom adapter that projects PII, that's a separate spec violation captured by `hmis-vendor-adapters` requirements. Document the test scope clearly in the test class Javadoc.

**[Risk] Dark-mode re-captures (S1) drift visually from light-mode screenshots → demo inconsistency.**
*Mitigation:* re-capture happens on the same clean-DB state used for light-mode captures (matching `feedback_isolated_test_data`). Operator visually compares dark + light pairs on the screenshot warroom step before deploy.

**[Risk] T1 scope-fix masks a real probe coverage gap if the result-region selector excludes shelter cards we want to assert on.**
*Mitigation:* a paired sanity test asserts the scoped probe still finds at least one freshness-badge match on the seed dataset. If the scope is too narrow, the sanity test catches it.

## Migration Plan

- **Static-only path (S1, S2):** scp updated `index.html` + `dvindex.html` + 3 dark-mode PNGs to `/var/www/findabed-docs/`. Cloudflare Purge Everything. ~5 min.
- **Code-repo path (T1, T2, O1, D3):** lands in code repo. Backend image rebuild needed only if the O1 IT should ride to production-bundle. Test-fix items (T1, T2, D3) ride CI — no production deploy required.
- **Synthetic-Maria path (D2):** audit doc filed, any es.json revisions committed, archive marker updated to `SYNTHETIC-MARIA-REVIEWED`. Frontend rebuild needed only if revisions land.
- **Sequencing:** ship S1 + S2 + T1 + T2 + D3 first as a static-content + CI-fix bundle (no backend rebuild, no frontend rebuild). O1 IT can ride v0.55.1 (with backend rebuild) or v0.56.0 (without) — Q5-style release-shape decision per slice. D2 lands as part of the same slice; revisions (if any) ride frontend rebuild.
- **Rollback:** static-content rollback = scp lastgood. Test-fix rollback = git revert + push. O1 IT rollback = revert the test class (no production-runtime impact). D2 es.json revisions rollback = revert the i18n edit (no functional impact; users see the previous Spanish strings).

## Open Questions

1. **D2 — who is the reviewer?** ~~Operator commitment is "real Maria or any native-Spanish reviewer."~~ **Resolved 2026-05-01:** synthetic-Maria-with-web-grounded-research (Claude-as-Maria with cited sources). Marker text changes to `SYNTHETIC-MARIA-REVIEWED`. Real-native-reviewer pass remains a future option.
2. **O1 — should the contract test be marked `@TenantUnscoped` or run twice (once per reentryMode flag value)?** Recommendation: run twice in the same test method via parameterized `@ValueSource(booleans = {true, false})`. Cleaner attribution than a single test that flips state mid-run.
3. **S1 — capture flow for dark-mode screenshots: does it use the existing `dark-mode-capture.spec.ts` or do we need a new spec?** Confirm during implementation; if existing spec works, no new code; if not, scope a new spec or extend.
4. **D3 — should `capture.sh` also run against the live findabed.org for verification captures?** Recommendation: NO. Per `feedback_smoke_spec_default_target`, capture.sh is local-default. Live-site captures are a separate operator workflow.
5. **Sequencing — do we ship as one v0.55.1 release or split into v0.55.1 (static + CI-fix) + v0.55.2 (backend with O1 + seed-reentry)?** ~~Recommendation: ship as one v0.55.1...~~ **Resolved 2026-05-01:** seed-reentry-shelters fix is deferred (Q5). Question reduces to "ship O1 as part of v0.55.1 with backend rebuild, or as v0.56.0?" — pick at deploy time per the design Migration Plan.
