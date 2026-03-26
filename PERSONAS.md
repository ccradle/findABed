# Finding A Bed Tonight — Personas

This file defines the personas used across the FABT project for UX evaluation,
accessibility auditing, QA decisions, and architectural reviews. Reference these
when evaluating feature design, writing tests, assessing accessibility, or
deciding what matters in a demo.

Two categories: **User Role Personas** (the people who use the platform) and
**Team Personas** (the people who build and advise on it).

---

## User Role Personas

These are the four roles defined in the platform (`PLATFORM_ADMIN`, `COC_ADMIN`,
`COORDINATOR`, `OUTREACH_WORKER`) made human. Use these when evaluating UX,
writing Playwright tests, auditing accessibility, or deciding what to demo first.

---

### 👤 Darius Webb — Outreach Worker

**Real role:** `OUTREACH_WORKER`
**Location:** Downtown Raleigh, mobile street outreach
**Experience:** 6 years in the field, works nights and weekends

**Who he is:**
Darius has driven more miles looking for shelter beds than he can count. He
carries two phones and has a mental map of which shelter coordinators answer at
midnight. He is skeptical of technology that promises to help but breaks when
he needs it most. If the app works reliably, he will be its loudest advocate.
If it doesn't, he goes back to his contact list and his memory.

**Device and environment:**
- Android phone, mid-range, 2-3 years old
- Inconsistent signal: sometimes one bar, sometimes none
- One-handed use while walking or driving
- Often in low-light conditions
- Spanish-speaking clients — he uses the Spanish toggle occasionally to show
  them the interface

**What he does in the app:**
1. Searches for available beds by population type (usually SINGLE_ADULT or
   FAMILY_WITH_CHILDREN)
2. Filters by constraints (pets, wheelchair access) when needed
3. Reads freshness badges — STALE data is a trust signal, not just a label
4. Holds a bed ("Hold This Bed") while transporting a client
5. Confirms or cancels the hold on arrival
6. Sometimes loses signal mid-hold — expects the hold to survive offline

**What he absolutely needs:**
- The offline queue to work — if he loses signal, the hold must persist
- The countdown timer to be visible without hunting for it
- STALE and FRESH badges to be immediately readable — he makes decisions on them
- Cancel hold to be easy and obvious — clients change their minds
- The app to be fast — he has 30 minutes before a client's motivation disappears

**What will make him distrust the platform:**
- A hold that disappears when he loses signal
- A STALE shelter that shows as fresh
- A bed that appears available but is actually full on arrival
- Any flow that requires more than 3 taps for a common action
- An error message he doesn't understand

**His test for the demo:**
"Show me: search for a bed, hold it, lose signal, come back online.
What happened to my hold? Is the countdown still running?"

**Accessibility considerations:**
- Touch targets must be large enough for outdoor, one-handed use
- High contrast needed — used in direct sunlight and poor lighting
- No reliance on color alone to convey status (freshness badges)
- Error messages must be immediate and specific, not generic

---

### 🏠 Sandra Kim — Shelter Coordinator

**Real role:** `COORDINATOR`
**Location:** Women's emergency shelter, Raleigh. 35 beds.
**Experience:** 8 years running shelter operations

**Who she is:**
Sandra manages a shelter that runs near capacity most nights. She is interrupted
constantly — by guests, by staff, by phone calls from outreach workers asking
questions she just answered. She does not have time for complicated software. If
updating the bed count takes more than 30 seconds, it will not happen consistently.
She is not hostile to technology — she uses it fine — but she has zero patience
for software that creates more work than it saves.

**Device and environment:**
- Shared desktop computer at the front desk
- Sometimes a personal iPhone when doing rounds
- Usually has 3-5 minutes between tasks to update bed counts
- Frequently interrupted mid-task
- Not a developer — knows how to use software, doesn't know how it works

**What she does in the app:**
1. Logs into the coordinator dashboard
2. Finds her shelter(s) in the list
3. Updates `beds_occupied` and occasionally `beds_total` when capacity changes
4. Reads the active holds indicator — sees which beds outreach workers have claimed
5. Updates availability after a client confirms or leaves

**What she absolutely needs:**
- The update flow to be 3-5 taps maximum, start to finish
- On Hold count to be read-only and clearly labeled — she should not accidentally
  overwrite it
- Confirmation that her update saved — a visible success state, not silence
- The shelter card to pre-populate with her current values — no starting from zero
- Shelter phone number to be easily editable when it changes

**What will make her stop updating consistently:**
- Any flow that takes more than 5 taps
- Confusing math — if the form shows numbers that don't add up to what she expects
- No confirmation that the save worked
- Having to scroll past irrelevant shelters to find hers
- A form that loses her work if she's interrupted and the session expires

**Her question for the demo:**
"Walk me through every tap. Log in, find my shelter, update occupied count, save.
How many taps? What does success look like?"

**Her practical questions before recommending to her director:**
1. Can I mark the shelter temporarily closed without deleting it?
2. What happens to active holds if the system goes down?
3. Who do we call if something breaks at 2am?
4. What if an outreach worker holds a bed but the client never shows?
   (The 45-minute auto-expiry must actually work and she must be able to trust it)

**Accessibility considerations:**
- Desktop use: standard keyboard navigation must work
- Mobile use: form inputs must be thumb-reachable in portrait mode
- Success/error states must be unambiguous — not subtle color changes
- Session timeout must warn her before it happens, not log her out silently

---

### 📋 Marcus Okafor — CoC Administrator

**Real role:** `COC_ADMIN`
**Location:** Wake County Continuum of Care
**Experience:** 12 years in homeless services administration, 4 years as CoC lead

**Who he is:**
Marcus coordinates the whole system. He onboards new shelters, manages user
accounts, pulls reports for HUD, and fields calls when something goes wrong. He
needs the platform to be reliable, auditable, and explainable to a county
commissioner. He is technically competent — can read documentation, understands
APIs at a conceptual level — but he is not an engineer.

**Device and environment:**
- Laptop, Windows, Chrome
- Occasionally mobile when visiting partner agencies
- Manages 18 partner organizations with different levels of technical capability
- Regular meetings with county staff, funders, and shelter directors

**What he does in the app:**
1. Creates and manages shelter profiles for partner agencies
2. Creates and manages user accounts for coordinators and outreach workers
3. Assigns coordinators to shelters
4. Reviews availability data across all shelters
5. Activates surge events (White Flag) during emergencies
6. Pulls reports for HUD (HIC, PIT) — *CoC Analytics change required*
7. Manages DV shelter configuration and access controls
8. Onboards new agencies using the 7-day workflow

**What he absolutely needs:**
- Onboarding a new shelter to be doable without a developer
- HUD-format HIC and PIT exports (blocked until CoC Analytics ships)
- Enough audit trail to answer "what happened on the night of X"
- The ability to explain DV shelter protection to a DV shelter director in plain
  English — not with schema diagrams
- Surge activation to be fast and obvious during an emergency

**His hard questions before bringing this to partner agencies:**
1. Can I generate HUD-compliant HIC and PIT reports right now?
   *(Honest answer today: CoC Analytics is specced but not yet implemented)*
2. What happens to shelter data if Wake County stops using the platform?
3. Can multiple CoCs share one deployment, or does each CoC need its own?
4. Is there a staging/test environment so I can train coordinators without
   affecting live data?
5. How do software updates get deployed — and who does it?
6. How do I explain DV shelter protection to a shelter director?

**His test for the demo:**
"Show me: add a new shelter from scratch, assign a coordinator, activate a surge
event. Then explain to me, in plain English, how the DV shelter works — what
an outreach worker sees, what they don't see, and why."

**Accessibility considerations:**
- Admin panel must be fully keyboard navigable — many power users
- Tables and lists must have proper sort/filter accessibility
- Confirmation dialogs for destructive actions (delete user, deactivate key)
  must be screen-reader friendly

---

### 🏛️ Teresa Nguyen — City Housing Official

**Real role:** None (she evaluates the platform, she doesn't use it daily)
**Location:** City of Raleigh, Housing and Neighborhoods Department
**Experience:** 10 years in city government, manages technology procurement

**Who she is:**
Teresa is a decision-maker, not a daily user. She will evaluate this platform
before her city formally adopts it. She is not hostile to open-source software —
she has approved it before — but she knows exactly what her city attorney will
ask, and she needs answers before that meeting. She is methodical, careful, and
fair. If the platform has a genuine gap, she will name it. If it's solid, she
will say so.

**Device and environment:**
- Laptop, city-managed Windows device
- Formal meeting settings — presentations, demonstrations
- Works with legal, IT security, and housing policy staff

**What she cares about:**
1. **Data sovereignty** — who owns the data in a self-hosted deployment
2. **WCAG 2.1 AA compliance** — city procurement requirement
3. **Security posture** — has a third party reviewed the codebase?
4. **Support model** — who is responsible if it breaks at 2am?
5. **Vendor stability** — will this project still exist in 3 years?
6. **DV shelter liability** — is the VAWA protection genuinely airtight?
7. **Data portability** — what happens if the city exits the platform?

**What she needs before a formal city conversation:**
1. Government Adoption Guide (does not yet exist — Casey Drummond is drafting)
2. Explicit data ownership statement
3. WCAG 2.1 AA audit results
4. Security posture summary (one-pager, not just code comments)
5. Support model description — even if informal, it must be documented
6. Answer to the court subpoena question on DV data
   *(Short answer: referral_token hard-deletes within 24 hours — nothing survives
   to be subpoenaed. This needs to be stated explicitly in the FAQ.)*

**Her question for the team:**
"How is this different from San Diego's Shelter Ready app, and why would
our city use this instead?"

**Accessibility considerations:**
She evaluates accessibility compliance. She will ask whether an audit was done,
who did it, and what the findings were. She will not be satisfied with "we think
it's probably accessible." She needs a document.

---

### 💰 Priya Anand — Foundation Program Officer

**Real role:** External advisor — funding strategy and grant positioning
**Location:** Research Triangle area foundation, civic technology portfolio
**Experience:** 10 years grant-making, focuses on civic tech and social services

**Who she is:**
Priya reviews 200+ grant applications a year. She has funded open-source civic
tech before — she knows what makes a project fundable and what kills applications.
She is not technical but reads technical documentation carefully for credibility
signals. She is on the project's side — she wants it to succeed — but she will
not recommend funding for something she can't defend to her board.

**What she needs answered before any funding conversation:**
1. **Theory of change with a measurable claim.** "Reduce time from crisis to
   placement from 2 hours to 20 minutes" is a grant headline if it's real and a
   liability if it isn't. Has anyone measured it? Even once?
2. **Sustainability model.** What keeps this project alive in year 3 when the
   initial grant ends? One engineer is honest but not fundable alone. Options:
   fiscal sponsor, nonprofit host, consortium of CoCs sharing maintenance costs.
3. **Named pilot partner.** Even informal — a letter from an organization willing
   to be cited as a pilot participant. Tosheria Brown at Oak City Cares is the
   target. That letter is worth more than any technical documentation.
4. **Government adoption guide.** Funders want to know cities can actually use this.

**Her funding landscape for this project:**
- Knight Foundation (civic tech, journalism, information access)
- Mozilla Open Source (open-source public interest technology)
- MacArthur Foundation (safety and justice, including housing)
- NC Community Foundation (Johnston County Community Foundation)
- HUD's technology grants (if a CoC is formally involved)
- Local corporate foundations (banks, healthcare systems with CRA obligations)

**Her lens:** Is this fundable? Is the impact measurable? Is the governance
credible enough for a program officer to defend to their board?

**Her immediate recommendation:**
Don't wait until Phase 1 is complete. The HMIS Bridge and CoC Analytics spec
are enough to have a funding conversation now. The story is ready — it just
needs a funding narrative layer added to existing documentation.

---

### 🏥 Dr. James Whitfield — Hospital Social Worker / Discharge Planner

**Real role:** `OUTREACH_WORKER` (hospital context)
**Location:** WakeMed Raleigh emergency department
**Experience:** 14 years hospital social work, 8 years in discharge planning

**Who he is:**
James discharges 8-12 patients a week to emergency shelter. He makes phone calls
to find beds while patients wait in discharge limbo. He is methodical and
institutional — works within hospital policy, HIPAA requirements, and IT
constraints that field outreach workers don't face.

**Device and environment:**
- Hospital-managed Windows laptop, locked-down Chrome (no extensions, no app install)
- Service worker permissions may be blocked by IT policy — PWA functionality uncertain
- Sometimes a personal iPhone for urgent situations
- Works during business hours primarily, but discharge situations arise at night

**What makes him different from Darius:**
- Cannot install apps on hospital devices — needs browser-only PWA
- 45-minute hold duration is insufficient — discharge takes 2-3 hours minimum
- Has HIPAA obligations that field workers don't
- Client is present in the room, not in a parking lot

**His critical questions:**
1. Does the app work fully in locked-down hospital Chrome — no service worker,
   no push notifications, no app install?
2. Hold duration: can it be configured to 2-3 hours for hospital use cases?
   (The README says it's configurable per tenant — this must be documented prominently)
3. Can he use this without entering any patient information?
   (Zero-PII design is correct — needs a one-page privacy summary for his
   hospital's privacy officer stating explicitly: "no patient-identifying
   information is stored in this system")
4. Can a patient arrange their own transport and arrive independently,
   or must the worker be present?

**His test for the demo:**
"Show me the hold flow on a hospital laptop with no app install.
How many clicks? What does the confirmation look like?"

**Accessibility considerations:**
- Hospital computers may have accessibility tools running — screen magnifiers,
  high-contrast modes. Must not break under these conditions.
- HIPAA compliance language must be visible enough to satisfy an audit

---

### 🌐 Reverend Alicia Monroe — Faith Community Shelter Operator

**Real role:** `COORDINATOR` (volunteer-run, seasonal shelter)
**Location:** Johnston County, NC — network of 7 faith community shelters
**Experience:** 20 years faith community outreach, 8 years running emergency shelter

**Who she is:**
Reverend Monroe activates roughly 80 beds across 7 churches on White Flag nights
in Johnston County. Her volunteer coordinators are not professional shelter staff.
Her church board governs major decisions. She is deeply trusted in her community
and skeptical of any technology that creates more work or cost for her volunteers.

**Device and environment:**
- Personal Android phone, shared church laptop
- Volunteer coordinator may be 60-70 years old with limited smartphone experience
- No IT support, no budget for software
- Seasonal operation — shelter activates in cold weather, dormant in summer

**What makes her different from Sandra:**
- Volunteer-run, not professional staff
- Zero-training requirement — if it takes more than 10 minutes to teach, it won't happen
- Seasonal gaps — shelter may be dormant for months
- Faith community governance — board approval required for new commitments
- May want availability-only participation (no reservations, no DV referrals)

**Her critical questions:**
1. How many taps does it actually take for a first-time user with no training?
2. What does "free" mean? Free to use but I pay for hosting? Free forever?
   (Plain-language "what this costs and who pays" document needed)
3. Who is liable if the system says beds are available and they aren't?
4. Can we participate with only bed count updates — no reservations, no referrals?
   (Partial participation pathway needs documentation)
5. What happens to our data if we go on summer hiatus for 3 months?
6. Can we mark beds as "DV-appropriate" without becoming a formal DV shelter
   with all the legal framework that entails?

**Her lens:** Would my six other pastors say yes to this? Is this simple enough
for a 67-year-old volunteer coordinator?

---

### 📊 Dr. Kenji Watanabe — HUD / Policy Researcher

**Real role:** External advisor — federal compliance and data standards
**Location:** Research Triangle Institute, Durham
**Experience:** 15 years homelessness policy research, HUD grant reviewer

**Who he is:**
Kenji studies CoC system performance and HMIS data quality. He has reviewed
HUD grant applications, testified at congressional hearings, and worked with
Open Referral on HSDS development. He reads technical documentation carefully
for federal compliance alignment. He is enthusiastic about this project but
has specific concerns that could create long-term problems if unaddressed.

**What he got right on first read:**
- The HSDS 3.0 extension is the correct approach — extend a standard, don't invent
- The DV aggregation in the HMIS Bridge is legally sound
- The AsyncAPI contract with x-security annotations for DV channels is thorough
- The unmet demand tracking (zero-result bed searches by population type and time)
  is genuinely valuable federal policy data that HMIS cannot currently produce

**His specific concerns:**

**1. HMIS small-cell suppression — a gap in the DV aggregation:**
If a CoC has one DV shelter with one occupied bed, the aggregate count is 1 —
which identifies the shelter as much as naming it. HUD's small-cell suppression
guidance requires a minimum threshold (typically n≥5 or n≥3). The HMIS Bridge
transformer must implement this. This is a compliance gap, not a feature request.

**2. CoC Analytics must align with SPM methodology before implementation:**
HUD's System Performance Measures have specific rules about bed-nights, project
types, and date ranges. A custom aggregation that's close but not precisely
aligned will create a permanent discrepancy between what FABT reports and what
CoCs submit to HUD. Before the 115-task CoC Analytics implementation begins,
map each metric explicitly to an HUD SPM definition.

**3. HMIS Data Standards version alignment:**
HUD updates HMIS Data Standards annually. The current implementation should
specify which version it targets (2024 or later). This must be maintained.

**His recommendations:**
1. Implement minimum cell size suppression in HMIS DV aggregation (fix now)
2. Map CoC Analytics metrics to HUD SPM definitions before implementation
3. After 3 months of Raleigh pilot data, submit findings to the National
   Alliance to End Homelessness conference — unmet demand data will be notable
4. Contact Greg Bloom at Open Referral about the HSDS extension — it belongs
   in the standard if it gets field-validated

**His lens:** Does this align with how HUD will evaluate it? Will it make CoC
grant compliance easier or harder?

---

### 🙋 Keisha Thompson — Peer Support Specialist / Lived Experience Advisor

**Real role:** Advisor — human dignity, person-centered design
**Location:** Raleigh, NC — currently housed, peer support work
**Experience:** 3 years experiencing homelessness, 4 years peer support certification

**Who she is:**
Keisha has been the family in the parking lot. She knows what it feels like
to be the person being searched for — not the person doing the searching. She
is now a peer support specialist who works alongside outreach teams. She brings
the perspective that no other persona on this project can: what does this system
feel like from the inside?

**What she got right on first read:**
- DV shelter being completely invisible — not redacted, invisible — is correct
  and matters deeply to survivors
- Zero-PII referral design — name never in the system — protects people in ways
  that extend beyond technical compliance
- Warm handoff design (coordinator calls worker, worker gives address verbally)
  is a safety design that protects against abuser surveillance, not just VAWA compliance

**What she wants the team to hold:**
- Population type labels (`SINGLE_ADULT`, `DV_SURVIVOR`) are operational
  categories and also identity labels. Hold that tension consciously.
- The hold countdown is designed for the worker. The person being transported
  is also living that countdown, on their phone, not knowing what it means.
  Future consideration: can the person being placed see their own hold status?
- "Hold This Bed" is worker-centric language. Worth examining whether it
  translates meaningfully to the person being placed.

**Her recommendation:**
Before the first public demo — before showing this to Oak City Cares, before
Wake County, before anyone — sit with a person who has experienced homelessness
and walk through the outreach worker flow. Not to find bugs. To ask:
*"Does this feel like it's on your side?"*

**Her test for the platform (not technical — human):**
"Does this system treat people like cases to be processed,
or like people who deserve dignity?"

**Her lens for every feature and every demo:**
Would the person being served feel dignity in this interaction?
Does the language, the flow, and the design center them or process them?

**Accessibility considerations:**
- The person being placed may eventually have their own interface (self-referral
  is a future goal noted by the San Diego team). Design with that in mind now.
- Language accessibility: plain English, no jargon, dignity in every label.

---

## Team Personas

These are the advisors and builders. Reference when making architectural
decisions, writing specs, or evaluating tradeoffs.

---

### 🏗️ Alex Chen — Principal Engineer / Enterprise Architect

**Lens:** Architecture correctness, module boundaries, technical debt, API design,
long-term maintainability. Asks "why" before "how." Will push back on shortcuts
that create future problems. Co-authored the AsyncAPI contract and the MCP-ready
API design requirements.

**Key positions:**
- Modular monolith over microservices at this scale — enforced by ArchUnit
- Append-only `bed_availability` is non-negotiable — no UPDATE or DELETE
- DV shelter protection needs both database-layer and service-layer enforcement
- `beds_available` is always derived, never stored
- OpenSpec before implementation — no cowboy coding

---

### 🤝 Maria Torres — Product Manager

**Background:** Former social worker, 8 years in homeless services before moving
to product. Keeps the team grounded in who the platform is actually for.

**Lens:** User outcomes over feature completeness. Outreach sequencing — who to
talk to first and in what order. City adoption strategy. The human side of every
technical decision.

**Key positions:**
- First external conversation is with an outreach worker supervisor, not a city
  official — sequence matters
- Demo environment before any outreach — showing on a real phone changes everything
- CoC Analytics must ship before the formal Wake County conversation
- Regina Rodgers (Street Reach of Johnston County) is the first recommended
  outreach contact

---

### 🔧 Jordan Reyes — SRE

**Lens:** Deployment reliability, security posture, infrastructure cost, CI
pipeline integrity, operational monitoring.

**Key positions:**
- DV canary must be a blocking CI gate — if it fails, nothing deploys
- Management port (9091) must never be publicly reachable in production
- Oracle Always Free (A1 Flex ARM64) is the right demo environment tier
- `fabt_app` DB role (NOSUPERUSER, DML-only) is the production standard
- The Oracle deployment runbook is in `/mnt/user-data/outputs/oracle-demo-runbook.md`

---

### 🧪 Riley Cho — Senior QA Engineer

**Background:** 10 years test automation. Came from healthcare IT where a missed
test meant a patient safety event, not a bad deployment.

**Lens:** "What happens to the person in crisis if this test is missing?" Every
gap in test coverage is a potential real-world failure. The DV canary blocking
gate is personal — it's not a nice-to-have.

**Key positions:**
- The 9 bed availability invariants (INV-1 through INV-9) must be enforced at
  the server layer, not just validated in tests
- TC-2.7 (coordinator update zeroing out active holds) was the highest-risk
  concurrency scenario — verify it's fixed and stays fixed
- Concurrent last-bed hold test must be genuinely concurrent, not sequential
- Test failures must include full state context — not just "expected 3 but was -1"

---

### ⚡ Sam Okafor — Senior Performance Engineer

**Lens:** SLO compliance, cache behavior under load, concurrency safety, CI
performance gate design.

**Key positions:**
- `BedSearchSimulation`: p50 < 100ms, p95 < 500ms, p99 < 1000ms
- `AvailabilityUpdateSimulation`: p95 < 200ms — tighter because cache invalidation
  is synchronous
- Gatling runs main-only (never on PRs) — cost control for open-source
- The append-only `bed_availability` table needs a query plan review at 6 months
  of production data — `DISTINCT ON` with 50,000+ rows needs profiling

---

### ⚖️ Casey Drummond — Open Source & Technology Attorney

**Lens:** Apache 2.0 implications, VAWA/FVPSA compliance, government procurement
path, data governance, contributor licensing.

**Key positions:**
- "VAWA/FVPSA compliant" is a claim the project cannot make — "designed to
  support" is the correct framing
- The government adoption guide (data ownership, support model, legal adoption
  path) must exist before any city attorney conversation
- DCO in CONTRIBUTING.md before first external contributor
- Privacy policy and government adoption guide are deferred but not forgotten
- The referral_token 24-hour hard delete is the correct answer to the
  court subpoena question — state it explicitly

---

## How to Use These Personas in Claude Code

**For accessibility auditing:**
Ask: "Can Darius accomplish this task on a mid-range Android with one hand and
bad signal? Can Sandra complete this in under 30 seconds while being interrupted?"

**For UX decisions:**
Ask: "Which persona is the primary user of this feature? What's their context?
What would make them stop using it?"

**For test case design:**
Use Darius's offline hold scenario, Sandra's interrupted mid-save scenario,
Marcus's concurrent-coordinator scenario, and Teresa's audit trail scenario as
the basis for edge case tests.

**For accessibility findings:**
Severity rating guide:
- **Critical** — Darius cannot complete a core task (find bed, hold bed, cancel)
- **High** — Sandra cannot update bed counts reliably
- **Medium** — Marcus cannot complete admin workflows without workarounds
- **Low** — Teresa's audit questions but doesn't block her team

**For demo preparation:**
Every demo should be able to answer Darius's question ("what happens to my hold
when I go offline?"), Sandra's question ("how many taps?"), Marcus's question
("show me DV shelter protection in plain English"), and have honest answers to
Teresa's questions — including the ones we can't fully answer yet.

**For funding conversations:**
Ask: "Can Priya defend this to her foundation board? Is the theory of change
measurable? Is there a named pilot partner?" These questions shape documentation
priorities before any grant conversation.

**For federal compliance:**
Ask: "Does Kenji see a compliance gap here?" Apply to every HMIS Bridge change,
CoC Analytics metric, and DV data handling decision. His two active flags:
HMIS small-cell suppression (fix before next HMIS push) and SPM methodology
alignment (required before CoC Analytics implementation begins).

**For dignity and person-centered design:**
Ask: "Would Keisha feel dignity in this interaction?" Apply to every UI label,
every flow, every feature decision. Especially: does the language center the
person being served, or process them?

**For faith community / volunteer operator scenarios:**
Ask: "Can Reverend Monroe's 67-year-old volunteer coordinator do this with
zero training?" If no, simplify before shipping.

**For hospital / institutional user scenarios:**
Ask: "Does this work in locked-down hospital Chrome with no app install?
Is the hold duration sufficient for discharge workflows?"

---

## Quick Reference — All Personas

| Persona | Role | Primary Concern |
|---|---|---|
| 👤 Darius Webb | Outreach Worker | Offline reliability, hold countdown, freshness trust |
| 🏠 Sandra Kim | Coordinator | 3-5 tap update flow, confirmation, data correctness |
| 📋 Marcus Okafor | CoC Admin | HUD reporting, onboarding, DV explanation |
| 🏛️ Teresa Nguyen | City Official | WCAG, data sovereignty, security audit, support model |
| 💰 Priya Anand | Funder | Theory of change, sustainability, named pilot partner |
| 🏥 Dr. James Whitfield | Hospital SW | Hold duration, hospital PWA, zero-PII statement |
| 🌐 Rev. Alicia Monroe | Faith Shelter | Zero training, partial participation, plain-language cost |
| 📊 Dr. Kenji Watanabe | Policy Researcher | HMIS compliance, SPM alignment, small-cell suppression |
| 🙋 Keisha Thompson | Lived Experience | Dignity, person-centered language, human impact |
| 🏗️ Alex Chen | Principal Engineer | Architecture, module boundaries, correctness |
| 🤝 Maria Torres | Product Manager | User outcomes, adoption sequencing, outreach strategy |
| 🔧 Jordan Reyes | SRE | Deployment, security posture, CI integrity |
| 🧪 Riley Cho | QA Engineer | Test coverage, invariant enforcement, DV canary |
| ⚡ Sam Okafor | Performance | SLO compliance, cache behavior, load testing |
| ⚖️ Casey Drummond | Attorney | Legal compliance, data governance, procurement path |

---

*Finding A Bed Tonight — Personas Reference*
*Used by: Claude Code (CLAUDE-CODE-BRIEF.md), design reviews, accessibility audits,
QA planning, demo preparation, funding conversations*
*Last updated: March 2026*
