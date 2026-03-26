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

- [ ] **HMIS small-cell suppression in DV aggregation**
  `HmisTransformer.java` aggregates individual DV shelter occupancy into a
  combined count before pushing to HMIS. If a CoC has only one DV shelter,
  the aggregate count *is* the identifying information. HUD's small-cell
  suppression guidance requires a minimum threshold (n≥3 or n≥5). This is a
  compliance defect, not a feature request.
  **Owner:** Alex Chen / Engineering
  **Source:** Dr. Kenji Watanabe (focus group), Casey Drummond (legal review)
  **OpenSpec change:** `hmis-dv-cell-suppression` (new, not yet created)

- [ ] **Verify `security-remediation-2026-03-20.md` is deleted**
  File appears in the root-level repo listing across multiple reads despite
  Jordan confirming deletion at commit `297fb21`. Verify it is actually gone
  and not reintroduced by a later commit.
  **Owner:** Jordan Reyes
  **Source:** Jordan's ACTION-1, flagged in multiple status checks
  **Action:** `git log --all --full-history -- security-remediation-2026-03-20.md`

---

### TESTING

- [ ] **WCAG 2.1 AA accessibility audit**
  No systematic accessibility audit has been conducted on the frontend.
  City procurement (Teresa Nguyen) requires WCAG 2.1 AA compliance.
  Darius uses the app one-handed in low light. Sandra uses it on interrupted
  desktop sessions. An audit using the running application is required.
  **Owner:** Alex Chen + Riley Cho (Claude Code with running instance)
  **Source:** Teresa Nguyen (focus group), Alex Chen (team review)
  **Approach:** Run axe-core / Playwright accessibility snapshots against
  live dev stack. Produce findings report with persona-mapped severity ratings
  per the guide in PERSONAS.md. Fix Critical and High findings before demo.

- [ ] **Hospital PWA test — service worker blocked by IT policy**
  Current offline behavior tests use `page.context().setOffline()` which
  tests the service worker path. A separate test is needed for the scenario
  where service worker registration is blocked by hospital IT policy
  (Dr. James Whitfield's use case). Does the app function — at minimum for
  bed search and hold — when the service worker cannot register?
  **Owner:** Riley Cho
  **Source:** Dr. James Whitfield (focus group)
  **Karate/Playwright:** New test in `offline-behavior.spec.ts`

---

### LEGAL / DOCUMENTATION

- [ ] **Legal language corrections applied and live**
  Seven corrections identified by Casey Drummond in the `legal-language-corrections`
  OpenSpec change. Commits `e61e41d` (findABed) and `04c72cc` (finding-a-bed-tonight)
  confirmed applied. **Verify these are live on the GitHub Pages site** — earlier
  reads showed the Pages site serving cached pre-correction content.
  **Owner:** Corey Cradle
  **Source:** Casey Drummond (legal review)
  **Verify:** Load `ccradle.github.io/findABed/demo/dvindex.html` and confirm
  "Designed to support VAWA/FVPSA compliance requirements" (not "VAWA/FVPSA compliant")

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

- [ ] **CoC Analytics implementation (115 tasks)**
  The last Phase 1 feature. Marcus Okafor's hard question — "Can I generate
  HUD-compliant HIC and PIT reports right now?" — cannot be answered yes
  until CoC Analytics ships. Do not have the formal CoC adoption conversation
  without this complete.
  **Owner:** Engineering
  **Source:** Marcus Okafor (focus group), findABed README (active change)
  **OpenSpec:** `coc-analytics` — specced, 115 tasks, ready for implementation
  **Note:** Before starting implementation, complete the SPM methodology mapping
  task below.

- [ ] **SPM methodology mapping before CoC Analytics begins**
  HUD's System Performance Measures have specific rules about bed-nights,
  project types, and date ranges. Write a mapping document (one day of work)
  that maps each planned FABT CoC Analytics metric to its precise HUD SPM
  definition. A custom aggregation that's close but not precisely aligned
  creates a permanent discrepancy between FABT reports and HUD submissions.
  **Owner:** Alex Chen (with Kenji Watanabe advisory input)
  **Source:** Dr. Kenji Watanabe (focus group)
  **Deliverable:** `docs/coc-analytics-spm-mapping.md` in code repo

- [ ] **HMIS Data Standards version pinned in documentation**
  HUD updates HMIS Data Standards annually. The HMIS Bridge implementation
  must specify which version it targets (2024.1 or later). This must appear
  in the HMIS Bridge documentation and be maintained with each HUD update.
  **Owner:** Alex Chen
  **Source:** Dr. Kenji Watanabe (focus group)

---

### TESTING

- [ ] **CoC Analytics test coverage**
  When CoC Analytics ships, it needs full integration test coverage including
  HIC/PIT export format validation against HUD field definitions, and
  unmet demand tracking accuracy tests.
  **Owner:** Riley Cho
  **Source:** Standard QA practice + Kenji Watanabe's SPM alignment concern

---

### LEGAL / DOCUMENTATION

- [ ] **Government adoption guide**
  The document a city attorney needs before any formal adoption conversation.
  Must cover: data ownership in self-hosted deployments, support model
  (including the honest "best-effort" answer), procurement path for Apache 2.0
  software, indemnification posture, and what happens to data on platform exit.
  **Owner:** Casey Drummond
  **Source:** Teresa Nguyen (focus group), Casey's deferred list
  **Format:** Single document, plain English, city-attorney audience
  **Note:** Can be written as one source with three audience-specific versions:
  city attorney, CoC board, faith community board

- [ ] **Hospital privacy one-pager**
  A one-page document for hospital privacy officers stating explicitly:
  "No patient-identifying information is stored in this system." Lists what
  is stored (household size, population type, urgency, worker callback number)
  and what is never stored (name, DOB, SSN, address, medical information).
  References the DV-OPAQUE-REFERRAL.md for full technical detail.
  **Owner:** Casey Drummond
  **Source:** Dr. James Whitfield (focus group)

- [ ] **"What does free mean" plain-language document**
  Written for faith community board members and volunteer shelter operators
  who have never encountered open-source software. Explains: free to use the
  software, the CoC or city pays for hosting (Lite tier: $15-30/month),
  no per-seat licensing, no vendor lock-in, data stays with you.
  **Owner:** Maria Torres (with Casey Drummond review)
  **Source:** Reverend Alicia Monroe (focus group)

- [ ] **Support model description**
  The honest answer to "who do you call at 2am?" Frames the current reality
  (open-source, best-effort, GitHub issues) and the path to something more
  formal for cities that need an SLA. This is a trust-building document,
  not a liability document. Honesty is better than silence here.
  **Owner:** Maria Torres + Casey Drummond
  **Source:** Sandra Kim, Teresa Nguyen, Reverend Monroe (focus group)

- [ ] **Theory of change — measure or qualify the 2hr→20min claim**
  "Reduce time from crisis to placement from 2 hours to 20 minutes" is the
  project's headline metric. It is a grant claim and a demo claim. Has it
  been measured, even in a simulated environment? If not, it must be qualified:
  "estimated based on [methodology]" or "target outcome for pilot measurement."
  Funders (Priya Anand) will ask. City officials (Teresa Nguyen) will ask.
  **Owner:** Maria Torres
  **Source:** Priya Anand (focus group)
  **Action:** Either time a simulated placement end-to-end, or add qualifying
  language to the README and proposal documents

- [ ] **Sustainability narrative**
  A paragraph or section in project documentation addressing: what keeps this
  project alive in year 3? Options to address: fiscal sponsor, nonprofit host,
  consortium of CoCs sharing maintenance costs, city-funded deployment.
  Required before any foundation grant conversation.
  **Owner:** Maria Torres + Priya Anand (advisory)
  **Source:** Priya Anand (focus group)

- [ ] **Partial participation guide**
  Documentation for shelter operators who want to use only the availability
  update feature — no reservations, no DV referrals, no surge. Covers: how to
  configure a minimal deployment, what features can be disabled or hidden,
  and how a volunteer-run seasonal shelter participates without committing
  to the full platform. Reverend Monroe's use case.
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

- [ ] **Configure hold duration for hospital use case (2-3 hours)**
  The default 45-minute hold is insufficient for hospital discharge workflows.
  Hold duration is already configurable per tenant — this is a documentation
  and onboarding task, not a code change. Add a hospital/institutional
  deployment note to the tenant configuration documentation.
  **Owner:** Engineering / Documentation
  **Source:** Dr. James Whitfield (focus group)

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

- [ ] **Oracle demo environment live**
  The deployment runbook is complete (`oracle-demo-runbook.md`). Pending:
  Srinivasan Nallagounder review (weekends only), domain registration,
  and VM provisioning. Can proceed in parallel with Tier 1 items.
  **Owner:** Jordan Reyes (runbook) / Corey Cradle (execution) /
  Srinivasan Nallagounder (Oracle review)
  **Source:** Jordan Reyes, Maria Torres

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

---

## Summary Counts

| Tier | Total | Open | Closed |
|---|---|---|---|
| Tier 1 — Blocking | 5 | 5 | 0 |
| Tier 2 — Important | 11 | 11 | 0 |
| Tier 3 — Future | 10 | 10 | 0 |
| Closed | 12 | — | 12 |
| **Total** | **38** | **26** | **12** |

---

*Finding A Bed Tonight — Pre-Demo Checklist*
*Commit to: `findABed/PRE-DEMO-CHECKLIST.md`*
*Read alongside: `PERSONAS.md` (for persona context behind each item)*
*Update as items close — do not delete closed items, move them to Closed section*
