## Why

v0.55.0 shipped to prod 2026-04-30 with a deliberate set of carryover items the warroom Round 5 + persona consensus accepted as v0.55.1 work. The bar for v0.55.0 was "no real safety/a11y regression"; the carryover bar for v0.55.1 is "operational hygiene + reviewer gates that don't block release." Items are recorded in `project_v055_1_backlog.md` (memory) and now consolidate here as the formal slice.

One spec-level requirement change is in scope: HMIS push must have an automated contract test asserting hold-attribution PII absence. The rest is task-level operational work (test-design fixes on screen-reader/wcag-vpat probes that fail post-§10 page expansion; **synthetic-Maria-with-web-grounded-research** review pass on the 5 warroom-drafted es.json keys — softens the prior "real native reviewer" commitment to "Claude-as-Maria with web-search-grounded linguistic research"; capture.sh enumeration; dark-mode screenshot re-captures; semantic-markup elevation on the docs index pages).

Explicitly deferred from this slice: the seed-reentry-shelters `--fresh` fix. Recent seed-data changes have already shipped in v0.55.0; another edit is not a priority. The gap remains tracked in `project_seed_reentry_shelters_gap.md` memory as a documented operator workaround (manual V95+V96 SQL replay after `--fresh`); a future slice can re-pick it up.

## What Changes

- **Test-design fix T1**: `screen-reader.spec.ts:65` scoped to the results region (`[role="region"][aria-label*="results"]`) so the freshness-badge probe fits within the 100-step accumulation window post-§10 page expansion. ~2-line fix; the test file's own line-80 comment predicts the fix.
- **Test-design fix T2**: `wcag-vpat-verification.spec.ts:187` split into 4 per-page tests (login + outreach + coordinator + admin). Reproducible failure post-§10 (cumulative full-page axe-core no longer fits the 30s budget). The targeted color-contrast probe (`reentry-search-contrast-probe.spec.ts`) confirms zero violations on the post-§10 search page; this is purely a test-budget regression.
- **D2 AI-synthetic linguistic review pass (NOT a native-speaker review)**: 5 warroom-drafted es.json keys (`hold.help.clientName`, `hold.help.clientDob`, `hold.help.notes`, `shelter.eligibility.notes.help`, `hold.clientAttributionPrivacyNote`) reviewed by Claude playing the Maria persona, with web-search-grounded citations. Methodology: per-key 8-dimension linguistic analysis covering source-string semantic faithfulness, anglicism risk, register appropriateness, regional bias (Castilian vs Latin American vs US Hispanic), gendered/inclusive considerations, domain-specific (social-services / housing) terminology, typography (inverted opening punctuation, NBSP between number+unit, quote-style consistency), and privacy/legal precision. Web research cites grounding for any non-obvious call (RAE, ASALE, Academia Mexicana de la Lengua, DPD, Linguee, Reverso Context, HUD-Spanish-materials, 211.org-Spanish, Wordreference forum). **Truthfulness disclosure (per `feedback_truthfulness_above_all` + `feedback_persona_transparency`):** this softens the prior "real native-Spanish reviewer" commitment. The reentry-release-readiness archive marker changes from `NATIVE-REVIEWER-PENDING` to `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker)` with a citation to this slice's audit doc. A new "Truthfulness disclosure" section in the v0.55.1 CHANGELOG repeats this disclosure to user-facing release notes.
- **O1 HMIS contract test**: backend integration test asserting an `OutboxRecord` for an HMIS push event has `null` for the 3 hold-attribution PII columns (`held_for_client_*_encrypted`) regardless of tenant `reentryMode` flag state. Doc claim is correct; this is the test gap that backs it.
- **D3 capture.sh enumeration**: `demo/capture.sh` updated with (a) explicit list of all 10 capture specs, (b) positional filter argument for "run only matching specs", (c) default `BASE_URL=http://localhost:8081`, (d) smoke-tested no-args + filter + non-match invocations.
- **S1 dark-mode screenshot re-captures**: re-run `dark-search.png`, `dark-admin.png`, `dark-coordinator.png` capture flow. These predate §11 Round 2 dialog reshape + §16.C frontend gates; current dark-mode screenshots show stale UI.
- **S2 semantic markup elevation**: promote `<div class="card">` → `<ol class="walkthrough-steps" role="list"> ... <li class="card">` on `demo/dvindex.html` (the 7 walkthrough cards are numbered procedural steps; W3C/MDN guidance says `<ol>/<li>` is the correct semantic shape, NOT `<article>` which is for self-contained independently-distributable content). `index.html` (root) has no eligible elements (its "card" elements are `<a class="card">` navigation links, which stay as anchors). `<div class="section-divider">` elements skipped — they're inline content holders, not section wrappers; converting to `<section>` would create empty-of-children landmarks. Future v0.55.2 candidate: convert section-dividers to `<h2 class="section-divider">` for real heading semantics. Tomás flagged the broader effort as nice-to-have, not ADA-blocking; lands here for hygiene.

## Capabilities

### New Capabilities

(None — this slice is operational follow-up to v0.55.0.)

### Modified Capabilities

- `hmis-push`: requirement that an automated contract test assert hold-attribution PII columns (`held_for_client_*_encrypted`) are absent from any HMIS outbox push payload, regardless of tenant `reentryMode`.

## Impact

- **Tests** — 2 Playwright test-design fixes (T1, T2) + 1 backend integration test added (O1). No new test infrastructure. Net effect: CI red-marker hygiene restored.
- **Backend** — no API changes. One new IT under `hmis/...HmisPushContractTest` (O1).
- **Frontend** — likely zero code changes for D2; if synthetic-Maria flags revisions, those revisions land in `frontend/src/i18n/es.json`.
- **Database** — no schema changes, no seed-data changes (seed-reentry-shelters `--fresh` fix is deferred per Q5 — operator workaround documented in `project_seed_reentry_shelters_gap.md` memory).
- **Static content (docs repo)** — 2 HTML files modified (`index.html` + `demo/dvindex.html`) for semantic markup elevation. New PNGs deployed for dark-mode (3 files).
- **Operator workflow** — `demo/capture.sh` enumeration removes "remember to type the long npx playwright command" friction. Post-this slice, `bash capture.sh` runs all; `bash capture.sh reentry` runs only the reentry spec.
- **Release vehicle** — v0.55.1 patch release. Backend rebuild is needed only if the O1 contract test should ride to production (test runs in CI either way; bundling to backend image is a release-shape decision — see Q5 in design.md). Frontend rebuild is needed only if D2 surfaces revisions to es.json. Static-only path covers S1 + S2 + (potentially) D2 if no revisions surface. Deploy mirrors the v0.55-style ops pattern.
- **Backward-compat** — purely additive. No deprecations, no API contract changes.
