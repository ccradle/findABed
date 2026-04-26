# Pre-Demo Checklist — Finding A Bed Tonight

**Maintained by:** Project team
**Last updated:** March 2026
**Purpose:** Single source of truth for all known gaps, organized by when they
must be resolved. Items are checked off as closed. This file is meant to be
updated — unlike PERSONAS.md, it is expected to change frequently.

**How to use this in Claude Code:** Read this file at the start of any session
involving demo preparation, hardening, documentation, or outreach planning.
Cross-reference with PERSONAS.md for the persona context behind each item.

---

## Tier 1 — Blocking: Must Resolve Before Any External Demo

These items must be complete before showing the platform to anyone outside
the project team — including outreach workers, shelter coordinators, or
anyone at Oak City Cares, Street Reach, or Wake County.

---

### CODE / ARCHITECTURE

- [x] **HMIS small-cell suppression in DV aggregation**
  Fixed in v0.12.0 (Design D18). Dual threshold: suppress DV aggregate when
  fewer than 3 distinct DV shelters OR fewer than 5 beds. Applied to
  HmisTransformer, AnalyticsService, HIC/PIT exports. 5 integration tests.

- [x] **Verify `security-remediation-2026-03-20.md` is deleted**
  Confirmed via `git log --all --full-history` — file does not exist in any
  branch or commit. Closed 2026-03-25.

---

### TESTING

- [x] **WCAG 2.1 AA accessibility audit**
  Completed in v0.13.0. axe-core CI gate (8 pages, zero violations), focus
  management, color independence, touch targets (44px), ARIA remediation,
  session timeout warning (alertdialog), self-assessed ACR (VPAT 2.5 WCAG),
  virtual screen reader tests (6 automated). See docs/WCAG-ACR.md.

- [x] **Hospital PWA test — service worker blocked by IT policy**
  Playwright test added in `offline-behavior.spec.ts`. Unregisters all SWs,
  blocks future registration, then verifies search results load, filters
  work, and hold bed functions. Core flow works without service worker.
  Closed 2026-03-26.

---

### LEGAL / DOCUMENTATION

- [x] **Legal language corrections applied and live**
  Verified live on GitHub Pages 2026-03-26. dvindex.html shows "Designed to
  support VAWA/FVPSA compliance requirements" (correct). As-is disclaimer
  present in footer. Additional legal language review in v0.13.0 found and
  fixed 6 more "compliant" instances across both READMEs.

- [ ] **Sit with a person of lived experience before first demo**
  Before any external demo — even an informal outreach worker conversation —
  walk through the outreach worker flow with someone who has experienced
  homelessness. Not to find bugs. To ask: "Does this feel like it's on your side?"
  This cannot be completed by code. It requires a calendar invite.
  **Owner:** Maria Torres
  **Source:** Keisha Thompson (focus group)
  **Target:** Before first Oak City Cares or Street Reach conversation

---

## Tier 2 — Important: Must Resolve Before CoC Admin / City Conversation

These items can be deferred past the first informal outreach worker conversation,
but must be complete before sitting down with Marcus Okafor (CoC Admin) or
Teresa Nguyen (City Housing Official) personas.

---

### CODE / ARCHITECTURE

- [x] **CoC Analytics implementation (122 tasks)**
  Completed in v0.12.0. Analytics dashboard, Spring Batch jobs, HIC/PIT CSV
  export, unmet demand tracking, DV small-cell suppression (D18), separate
  HikariCP pool, BRIN index, Grafana dashboard. 13 integration tests, 7
  Playwright, 19 Karate scenarios, Gatling mixed-load test.

- [x] **SPM methodology mapping**
  Completed: `docs/coc-analytics-spm-mapping.md`. FABT metrics complement
  SPMs (system capacity vs individual outcomes). No conflict. AI-generated,
  flagged for SME review.

- [x] **HMIS Data Standards version pinned in documentation**
  Pinned to FY 2026 HMIS Data Standards (effective October 1, 2025) in
  SPM mapping document. Element 2.07 alignment confirmed.

---

### TESTING

- [x] **CoC Analytics test coverage**
  Shipped with v0.12.0: 13 backend integration tests, 7 Playwright UI tests,
  19 Karate API scenarios, Gatling mixed-load (bed search p99 152ms under
  concurrent analytics). HIC/PIT CSV format validated. DV suppression tested.

---

### LEGAL / DOCUMENTATION

- [x] **Government adoption guide**
  Completed: `docs/government-adoption-guide.md`. Covers data ownership,
  Apache 2.0 procurement, security posture, support model, data portability,
  DV liability, FAQ. AI-generated, flagged for legal review.

- [x] **Hospital privacy one-pager**
  Completed: `docs/hospital-privacy-summary.md`. Zero PHI stored, no BAA
  required, all 18 HIPAA identifiers listed as "Never stored", social worker
  workflow described. AI-generated, flagged for privacy officer review.

- [x] **"What does free mean" plain-language document**
  Completed: `docs/what-does-free-mean.md`. $15-30/month breakdown, Netflix
  comparison, partial participation, seasonal shelter FAQ. AI-generated,
  flagged for project team review.

- [x] **Support model description**
  Completed: `docs/support-model.md`. Honest "best-effort" answer, path to
  SLA via systems integrator, comparison table (PostgreSQL, Metabase, Signal,
  CKAN). AI-generated, flagged for project team review.

- [x] **Theory of change — qualify the 2hr→20min claim**
  Completed: `docs/theory-of-change.md`. Claim qualified as "target outcome
  for pilot measurement" with workflow analysis table. Recommended grant
  language provided. AI-generated, flagged for project team review.

- [x] **Sustainability narrative**
  Completed: `docs/sustainability-narrative.md`. 4-stage path: community →
  fiscal sponsor → shared consortium → institutional host. Funding
  opportunities listed. AI-generated, flagged for advisor review.

- [x] **Partial participation guide**
  Completed: `docs/partial-participation-guide.md`. Level 1/2/3
  participation, seasonal shelter FAQ, 30-second update workflow.
  AI-generated, flagged for project team review.
  **Owner:** Maria Torres
  **Source:** Reverend Alicia Monroe (focus group)

---

### OUTREACH / RELATIONSHIPS

- [ ] **Named pilot partner — at least one letter of intent**
  Before any funding conversation, have at least one organization willing to
  be named as a pilot participant. Tosheria Brown at Oak City Cares is the
  primary target. An informal email saying "we participated in a demo and
  see potential" is sufficient at this stage.
  **Owner:** Maria Torres
  **Source:** Priya Anand (focus group)

- [ ] **Domain name registered**
  Register a real domain (e.g., `findabed.org`) before the first external
  demo to anyone outside the project team. A real URL is a credibility signal
  in any meeting with a city official or CoC director.
  **Owner:** Corey Cradle
  **Source:** Maria Torres, Jordan Reyes

---

## Tier 3 — Future: Post-Pilot or Post-Phase-1

These items are not blocking for the pilot but must be addressed before
broader adoption or replication.

---

### CODE / ARCHITECTURE

- [x] **Configure hold duration for hospital use case (2-3 hours)**
  Default changed from 45 to 90 minutes (v0.13.1). Admin UI now exposes
  hold duration configuration (5-480 min range). Hospital deployments can
  set 180-240 minutes via Admin panel. Documentation updated across both repos.

- [ ] **Verify app functions in locked-down hospital Chrome**
  Beyond the Playwright test (Tier 1), verify through manual testing on an
  actual hospital-equivalent locked-down Chrome instance that the core flow
  (login, search, hold) works without service worker or push notification
  permissions. Document any limitations.
  **Owner:** Riley Cho
  **Source:** Dr. James Whitfield (focus group)

- [ ] **`bed_availability` query plan review at scale**
  The `DISTINCT ON (shelter_id, population_type) ORDER BY snapshot_ts DESC`
  query is clean at current scale. At 6 months of production data with 15+
  active shelters updating twice daily, the table will have 50,000+ rows.
  Profile the query plan before that threshold is reached.
  **Owner:** Sam Okafor
  **Source:** Sam Okafor (standing concern from e2e-hardening session)

- [ ] **Self-referral consideration (future feature)**
  Keisha Thompson raised: can the person being placed eventually see their
  own hold status or self-refer? The San Diego Shelter Ready team mentioned
  self-referral as a future goal. Design future features with this in mind.
  Not an immediate change — a design constraint to carry forward.
  **Owner:** Maria Torres (product decision)
  **Source:** Keisha Thompson (focus group)

---

### LEGAL / DOCUMENTATION

- [ ] **Privacy policy document**
  A public-facing privacy policy for the platform. Easy to write given the
  zero-PII design — but must exist before broad public use.
  **Owner:** Casey Drummond
  **Source:** Casey's deferred list

- [ ] **DCO in CONTRIBUTING.md**
  Developer Certificate of Origin before first external contributor.
  A lightweight mechanism — `Signed-off-by` in commit messages — that
  creates a clear record of contributor rights.
  **Owner:** Engineering
  **Source:** Casey Drummond (initial legal review)

- [ ] **Explore fiscal sponsor / nonprofit host path**
  For funding conversations to succeed at the foundation level, the project
  needs a sustainability answer. Explore: Code for America, Open Referral
  Initiative, a local NC nonprofit as fiscal sponsor, or a consortium of
  CoCs formalizing shared maintenance. No commitment required at this stage —
  just documented options.
  **Owner:** Maria Torres + Priya Anand (advisory)
  **Source:** Priya Anand (focus group)

---

### OUTREACH / RELATIONSHIPS

- [x] **Oracle demo environment live** (resolved — live at findabed.org
  since v0.45). Each release ships its own deploy runbook at
  `finding-a-bed-tonight/docs/oracle-update-notes-vX.Y.Z.md`; the older
  one-shot `oracle-demo-runbook.md` is obsolete and queued for archival
  along with the v0.14.1 / v0.21.0 historical copies in the docs-repo
  root. Current live version: v0.52.0; v0.53.0 in PR review (PR #164).

- [ ] **Contact Open Referral re: HSDS extension**
  After the Raleigh pilot produces 3 months of real data, contact Greg Bloom
  at the Open Referral Initiative about contributing the FABT HSDS bed
  availability extension to the standard. Field validation makes it credible.
  **Owner:** Alex Chen
  **Source:** Dr. Kenji Watanabe (focus group)

- [ ] **Submit findings to National Alliance conference**
  After 3 months of pilot data, the unmet demand tracking (zero-result bed
  searches by population type, time, location) is notable research that the
  homeless services field does not currently have from any system. Submit a
  brief or paper to the National Alliance to End Homelessness annual conference.
  **Owner:** Maria Torres + Dr. Kenji Watanabe (advisory)
  **Source:** Dr. Kenji Watanabe (focus group)

- [ ] **Language / dignity review of UI copy**
  Before broader rollout (not for first pilot), review all user-facing labels,
  button copy, and error messages with Keisha Thompson's lens:
  "Does this center the person being served or process them?"
  Specific items flagged: "Hold This Bed" (worker-centric), population type
  label display in outreach-facing UI.
  **Owner:** Maria Torres
  **Source:** Keisha Thompson (focus group)

---

## Closed Items

*Items that were identified as gaps and have since been resolved.
Move items here when completed — do not delete them.*

- [x] **Legal language corrections — dvindex.html compliance claim**
  "VAWA/FVPSA compliant" → "Designed to support VAWA/FVPSA compliance"
  Commit `e61e41d` (findABed). Pending Pages cache verification (see Tier 1).

- [x] **Legal language corrections — disclaimer footers on demo pages**
  As-is warranty disclaimer added to `dvindex.html`, `index.html`, `README.md`
  Commit `e61e41d` (findABed).

- [x] **Legal language corrections — DV-OPAQUE-REFERRAL.md**
  Important Notice, consent reasoning, free-text PII risk note added.
  Commit `04c72cc` (finding-a-bed-tonight).

- [x] **security-remediation-2026-03-20.md deleted**
  Commit `297fb21` — "Remove security-remediation-2026-03-20.md"
  *(Note: file still appearing in some repo listings — see Tier 1 verify item)*

- [x] **DynamoDB deletion protection**
  `deletion_protection_enabled = true` on bootstrap stack.

- [x] **OWASP CVE gate**
  `failBuildOnCVSS=7` in `pom.xml` + CI. `owasp-suppressions.xml` committed.

- [x] **Terraform security posture**
  ECS role separation, RDS not public, Secrets Manager for credentials,
  SG chain verified. Plaintext env vars for JWT secret and DB password removed.

- [x] **RLS enforcement fix**
  `RlsDataSourceConfig` wraps HikariCP. `fabt_app` restricted DB role (V16).
  `set_config('app.dv_access')` on every connection. DV canary 5/5 passing.

- [x] **Bed availability calculation hardening**
  9 invariants enforced server-side. Single source of truth (`shelter_capacity`
  table dropped, V20). Concurrent hold safety via PostgreSQL advisory locks.
  27 integration tests. 10 Playwright math verification tests.

- [x] **DV opaque referral**
  Zero-PII token lifecycle, warm handoff, 24-hour hard delete, RLS D14.
  12 integration tests, 7 Playwright tests, 6 Karate scenarios. v0.10.0.

- [x] **DV address redaction**
  Configurable tenant policy, API-level redaction. 13 tests, 6 Karate. v0.10.1.

- [x] **HMIS Bridge**
  Async push to Clarity/WellSky/ClientTrack. Outbox pattern, DV aggregation
  (pending small-cell suppression fix). Admin UI. 10 tests. v0.11.0.

- [x] **E2E test automation + hardening**
  82 Playwright, 54 Karate, 3 Gatling. DV canary blocking CI gate.
  RLS enforcement tests. Worker fixture. Offline queue tests. v0.5.0/v0.6.0.

- [x] **HMIS small-cell suppression (D18)**
  Dual threshold: ≥3 shelters AND ≥5 beds. Applied to HmisTransformer,
  AnalyticsService, HIC/PIT exports. 5 integration tests. v0.12.0.

- [x] **security-remediation-2026-03-20.md deleted**
  Confirmed via git log --all --full-history. File does not exist.

- [x] **WCAG 2.1 AA accessibility audit**
  axe-core CI gate (8 pages, zero violations), ARIA, focus management,
  color independence, session timeout, ACR document (VPAT 2.5), virtual
  screen reader tests. 113 Playwright tests. v0.13.0.

- [x] **CoC Analytics**
  Dashboard, Spring Batch, HIC/PIT export, demand tracking, DV suppression.
  122 tasks, 13 integration + 7 Playwright + 19 Karate. v0.12.0.

- [x] **CoC Analytics test coverage**
  Full coverage shipped with v0.12.0. Gatling mixed-load verified.

---

## Summary Counts

| Tier | Total | Open | Closed |
|---|---|---|---|
| Tier 1 — Blocking | 5 | 1 | 4 |
| Tier 2 — Important | 11 | 2 | 9 |
| Tier 3 — Future | 10 | 10 | 0 |
| Closed | 12 | — | 12 |
| **Total** | **38** | **13** | **25** |

---

*Finding A Bed Tonight — Pre-Demo Checklist*
*Commit to: `findABed/PRE-DEMO-CHECKLIST.md`*
*Read alongside: `PERSONAS.md` (for persona context behind each item)*
*Update as items close — do not delete closed items, move them to Closed section*
