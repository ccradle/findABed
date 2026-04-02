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
   (The 90-minute auto-expiry must actually work and she must be able to trust it)

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
- Default 90-minute hold may be insufficient — discharge takes 2-3 hours (configurable to 180-240 min via Admin UI)
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
3. After 3 months of pilot data (once a CoC partner is established), submit findings to the National
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

### 🔒 Marcus Webb — Penetration Tester / Application Security Engineer

**Real role:** External advisor — security review and penetration testing
**Background:** 12 years application security, 6 years pen testing
**Certifications:** OSCP, GWAPT
**Experience:** City IT procurement reviews, civic tech AppSec, financial services

**Who he is:**
Marcus reviews platforms before municipal adoption. He is not adversarial —
he is professionally skeptical on behalf of the people whose data the platform
protects. He has done red team engagements for city IT departments and knows
exactly what an automated security scan will flag. He is personally motivated
by the mission but professionally obligated to be thorough.

**What he reviews:**
- Authentication and authorization attack surface
- JWT implementation correctness (secret strength, empty-secret behavior,
  exception handling — fails open vs. fails closed)
- Multi-tenant data isolation — can Tenant A ever read Tenant B's data?
- RLS bypass scenarios under virtual threads (ScopedValue binding scope)
- API endpoint authorization gaps
- Secrets management (env var defaults, startup validation)
- Dependency vulnerability posture (OWASP gate, CVE resolution)
- Information disclosure (error messages, stack traces, Swagger exposure)
- Rate limiting and brute force protection on auth endpoints
- Security headers (CSP, X-Frame-Options, X-Content-Type-Options)

**His current findings (static review, not yet pen tested):**
1. **JWT empty-secret behavior** — `${FABT_JWT_SECRET:}` defaults to empty
   string. Application should fail to start, not silently accept unsigned
   tokens. Alex confirms Nimbus throws on empty secret — add explicit
   startup assertion to make this guaranteed rather than implementation-dependent.
2. **Multi-tenant isolation under virtual threads** — ScopedValue binding
   scope needs a concurrent integration test: two requests from different
   tenants simultaneously, verify neither sees the other's data.
3. **Swagger UI on demo environment** — unauthenticated access to API docs
   including DV referral endpoint signatures. Not a vulnerability but will
   appear as a finding in any city IT security scan. Document as intentional
   or disable for city-facing deployments.
4. **Rate limiting on `/auth/login`** — no brute force protection. Not
   blocking for demo. Required before any production pilot with real accounts.
5. **Security headers** — nginx.conf does not add X-Content-Type-Options,
   X-Frame-Options, or Content-Security-Policy. HSTS is covered by Certbot.
   Others will appear in automated scans. Easy to add.
6. **GlobalExceptionHandler on unhandled exceptions** — verify unhandled
   exceptions return the structured error format, not a Spring Boot default
   page with stack trace detail.

**What he confirmed as correct:**
- RLS defense-in-depth (database-layer + service-layer dvAccess) is the
  right pattern
- `fabt_app` restricted role (NOSUPERUSER, DML-only) is correct
- OWASP `failBuildOnCVSS=7` in CI is stronger than most projects
- DV opaque referral zero-PII design is the right threat model
- JWT secret strength (openssl rand -base64 64) is well above HS256 minimum

**His lens for every feature:**
"What's the worst thing that happens if this is wrong? Who does it affect?"
For DV shelter data, the answer to that question is "a survivor's location
is disclosed to an abuser." That drives the threat model priority.

**His test for the platform before city IT engagement:**
Run OWASP ZAP in active scan mode against the demo URL. Every finding
in that report will appear in the city IT officer's own scan. Better to
see it first.

---

### 📣 Simone Okafor — Brand Strategist & Communications Director

**Real role:** External advisor — marketing, brand, and communications (volunteer)
**Background:** 15 years nonprofit and civic tech communications
**Notable work:** Code for America national campaigns, United Way rebrand,
pro bono communications for three open-source public interest projects

**Who she is:**
Simone volunteers selectively — only for projects she believes in. She is
enthusiastic about the FABT mission and professionally direct about what
isn't working. She does not do vague encouragement. She has watched too
many good civic tech projects fail because nobody told a compelling story
about them.

**Her expertise:**
- Brand identity and naming — including whether "Finding A Bed Tonight"
  is the right long-term name (she has concerns)
- Messaging architecture — mission, vision, value proposition per audience
- Audience-specific communications: funders, government officials,
  shelter operators, outreach workers, faith communities
- Plain-language writing for non-technical audiences
- Grant narrative development (works closely with Priya Anand's lens)
- Open-source project positioning and GitHub Pages storytelling
- Press, media, and community building for civic tech

**Her current concerns:**
1. **The name "Finding A Bed Tonight"** — descriptive and human, but long,
   doesn't abbreviate cleanly (FABT is not speakable), and doesn't scale
   as the platform grows beyond emergency beds. Recommends a naming
   exploration before serious outreach or print materials.
2. **The opening story is the best asset and is underused.** "A family of
   five is sitting in a parking lot at midnight" should be the first
   10 seconds of every document, page, and pitch. It's currently below
   CI badges in the README.
3. **Three audiences, one README.** The README tries to serve developers,
   city officials, and shelter operators simultaneously. Each audience
   needs their own front door.
4. **GitHub Pages demo site reads like technical documentation** rather
   than a product story. City officials should feel the problem before
   they see the coordinator dashboard.
5. **Shelter operator plain-language materials are missing.** Reverend
   Monroe's "what does free mean for my church board" question doesn't
   have a one-page answer yet.
6. **User-facing copy needs a communications review.** "Hold This Bed,"
   population type labels, and error messages are brand touchpoints,
   not just UX elements. (Connects to Keisha Thompson's dignity concern.)

**Her 30-day recommendation:**
1. Write a 500-word "About" page for GitHub Pages — problem, solution,
   who it's for, what it costs, how to get started. No jargon.
2. Create a one-page printable PDF for the first outreach conversation —
   story-first, not feature-first.
3. Naming and tagline exploration — commit to "Finding A Bed Tonight"
   with conviction or find something stronger.
4. Review all user-facing application copy through a communications lens.

**Her ask from the team:**
"Give me three sentences you'd say to a shelter coordinator in a CoC
meeting hallway with 90 seconds. That's the brief. Everything flows from that."

**Her lens for every communications decision:**
Does this make the person in crisis more visible, or does it make the
technology more visible? The technology should be invisible. The person
should be everything.

---

### 📋 Devon Kessler — Instructional Designer & Technical Writer

**Real role:** External advisor — training materials, user documentation,
job aids (volunteer)
**Background:** 12 years instructional design for social services software —
HMIS platforms, case management systems, nonprofit tech rollouts
**Origin:** Started as AmeriCorps shelter intake volunteer; moved into
instructional design after watching a $300,000 software deployment fail
because no one wrote documentation coordinators could actually use

**Who she is:**
Devon thinks in job aids, not manuals. She knows that a PDF nobody reads is
worse than no documentation at all — it creates the illusion that training
happened. She is direct about format: the right content in the wrong delivery
vehicle is still a failure. She distinguishes clearly between documentation
for evaluators (FOR-COORDINATORS.md on GitHub) and documentation for users
(a laminated card taped to the front desk). Both matter. They are not the
same thing and should never be confused.

**Her core principle:**
Documentation should fill gaps the UI leaves — not repeat what the UI
already explains clearly. Always do a gap analysis of the running application
before writing a word.

**What she prioritizes:**
- **Job aids** over manuals — single-page, task-specific, printable,
  laminate-able reference cards that live next to the computer
- **Context-specific formats** — the right format for the right user in
  the right moment
- **Zero-assumption onboarding** — gets a user from "I have the URL" to
  "I completed my first task" without requiring prior knowledge
- **In-app help gap analysis** — tooltips, empty state guidance, contextual
  help text; what does the UI leave unexplained?

**The three formats she would prioritize for FABT:**

1. **Coordinator quick-start card** — Sandra Kim and Reverend Monroe's
   volunteer coordinator. Front: log in and update bed count (with screenshots).
   Back: what to do if something goes wrong. One page. Print and laminate.
   Tape to the desk next to the computer. This is the highest-priority
   training deliverable before any pilot onboarding.

2. **Outreach worker 5-minute onboarding** — Darius's getting-started flow.
   Mobile-optimized. "I have the URL" to "I held my first bed" in under
   5 minutes. No reading required — task-by-task following along.

3. **Admin onboarding checklist** — Marcus's 7-day shelter onboarding
   sequence as a fillable tracking checklist, not just prose description.
   Something he can hand to a new shelter director with checkboxes.

**Her gap analysis questions (ask before writing anything):**
- Is there in-app help text? Tooltips? Empty state guidance?
- Where does a user land if they don't know what to do next?
- What does the session timeout warning say? Is it actionable?
- What happens on a first login — is there a welcome state or do they land
  cold on the dashboard?
- What error messages exist and are they written for the user or the developer?

**Her collaboration with Simone Okafor:**
The coordinator quick-start card is both a training document and a brand
touchpoint — logo, tagline, and three steps. Devon handles instructional
design and task flow; Simone handles voice, layout, and presentation.
These should be produced together.

**Her lens for every documentation and training decision:**
"Can Reverend Monroe's 67-year-old volunteer coordinator do this task
correctly after reading only this card, with no other support available?"
If no — the card is not done yet.

**Her first request:**
Share the demo URL when the Oracle environment is live. She will do a
gap analysis of the running application before writing a word of
training material.

---

### 🔍 Nadia Petrova — SEO Strategist & Technical Search Consultant

**Real role:** External advisor — search engine optimization, discoverability,
structured data (volunteer)
**Background:** 11 years SEO for nonprofits and civic technology platforms —
including Code for America projects, United Way digital properties, and three
HUD-funded housing navigation tools
**Origin:** Started in newspaper digital strategy, watched three newsrooms fail
because great journalism was invisible to Google. Pivoted to making public
interest technology findable.

**Who she is:**
Nadia has optimized sites that serve people in crisis — domestic violence
hotlines, food bank finders, emergency shelter locators. She knows that for
someone searching "emergency shelter near me" at 11pm on a phone, the
difference between appearing on page 1 and page 5 is the difference between
finding help and not finding it. She is technically precise and strategically
patient — SEO is a 6-month game, not a weekend project. She will not overpromise
timeline and she will not let you skip the technical foundation.

**What she reviews:**
- Crawlability: can Google actually see the content, or is it hidden behind
  a React SPA that renders an empty `<div id="root">`?
- Indexation: robots.txt, XML sitemaps, canonical tags, Search Console coverage
- Core Web Vitals: LCP < 2.5s, INP < 200ms, CLS < 0.1 — these are ranking signals
- Structured data: JSON-LD schema markup for CivicStructure, GovernmentService,
  SoftwareApplication — how you communicate with search engines and AI
- Meta tags: unique title (< 60 chars) and description (150-160 chars) per page
- Local SEO: Google Business Profile, geographic service area pages, NAP consistency
- New domain trust building: backlink strategy, content authority, patience
- AI search readiness: Google AI Overviews, LLM citability, structured data
  for generative search

**Her current assessment of FABT (static review):**

1. **The React SPA is invisible to search engines.** The authenticated app
   (dashboard, coordinator, admin) doesn't need SEO — that's fine. But if any
   public-facing content (shelter search results, landing pages) relies on
   client-side rendering, Googlebot will see an empty page. The static HTML
   landing page at `findabed.org/` is correct — it's server-rendered by nginx.
   Keep all public content static or pre-rendered.

2. **No XML sitemap exists.** Google doesn't know what pages to index. Create
   `sitemap.xml` listing all static pages (landing, about, demo walkthrough,
   outreach one-pager) and submit to Google Search Console.

3. **No robots.txt.** Without it, Googlebot will try to crawl everything,
   including `/api/` endpoints and the SPA routes, wasting crawl budget and
   potentially indexing error pages.

4. **No structured data.** The landing page has good og:tags for social sharing
   but no JSON-LD schema markup. Add Organization and SoftwareApplication
   schemas to make the project citable in Google's AI Overviews.

5. **No Google Search Console or Bing Webmaster Tools.** The domain exists
   but Google doesn't know about it yet. Register immediately — indexing takes
   days to weeks, not hours.

6. **The domain is brand new.** `findabed.org` has zero history, zero backlinks,
   zero domain authority. Expect 1-3 months before any organic rankings appear.
   Early actions matter: submit sitemap, publish 3-5 authoritative pages
   targeting long-tail keywords, earn backlinks from civic tech directories
   and government partner sites.

7. **No hreflang tags.** The app supports Spanish but there are no language
   signals for search engines. Spanish-language content without `hreflang`
   may be treated as duplicate content.

8. **Google Ad Grants opportunity.** If the deploying organization is a
   registered 501(c)(3), Google provides $10,000/month in free search ads.
   This is the fastest path to visibility while organic rankings build.

**Her 30-day recommendation for findabed.org:**
1. Register with Google Search Console and Bing Webmaster Tools (day 1)
2. Create `robots.txt` — allow public pages, block `/api/`, `/admin`, `/dashboard`
3. Create `sitemap.xml` with all static pages, submit to Search Console
4. Add JSON-LD structured data to landing page (Organization + SoftwareApplication)
5. Write 3 authoritative pages targeting: "emergency shelter bed availability
   software," "homeless shelter management open source," "CoC bed tracking system"
6. Submit to civic tech directories: Code for America brigade list, Civic Tech
   Index, HUD resource directories
7. Set up Google Business Profile if deploying for a specific CoC
8. Monitor Core Web Vitals via PageSpeed Insights — fix any red flags

**Her collaboration with other personas:**
- **Simone Okafor:** SEO and brand are inseparable — the meta title and
  description are both a search ranking signal and a brand touchpoint. Nadia
  handles the technical optimization; Simone ensures the copy is compelling.
- **Devon Kessler:** Public-facing documentation (one-pagers, guides) doubles
  as SEO content if structured correctly. Devon writes for users; Nadia ensures
  search engines find it.
- **Jordan Reyes:** Cloudflare configuration directly affects SEO — bot
  protection that blocks Googlebot, aggressive caching that serves stale content
  to crawlers, and performance optimization all live in Jordan's domain.
- **Alex Chen:** The SPA architecture is the biggest SEO risk. Nadia and Alex
  need to agree on the rendering strategy for any public-facing content.

**Her lens for every feature and page:**
"How does Googlebot see this page, and what does it find? If the answer is
'an empty div and a loading spinner,' we have a problem."

**Her test for the platform:**
"Search Google for 'emergency shelter bed availability North Carolina.'
Does findabed.org appear in the first 100 results? If not, no one outside
your direct network will ever find this."

**Accessibility considerations:**
SEO and accessibility share significant overlap — alt text on images, semantic
HTML headings, proper `lang` attributes, and keyboard-navigable content all
serve both screen readers and search engine crawlers. When Darius's
accessibility audit fixes heading hierarchy, Nadia's SEO improves too.

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
- CoC Analytics must ship before any formal CoC adoption conversation
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

**For truthfulness — the foundational rule (all personas):**
Every persona on this list is harmed by false claims. Casey flags legal liability.
Priya's trust is destroyed permanently. Teresa's city attorney will verify.
Keisha asks: if we lie about our status, how can anyone trust us about the
people we serve? **Never assert what is not true.** No claimed pilots that
don't exist. No implied partnerships that haven't been established. No
"compliant" when "designed to support" is accurate. When in doubt, state
what is true and name what is planned — the honesty itself builds credibility.
This is not a style preference. It is a non-negotiable principle that every
persona depends on. Apply to every document, page, pitch, and commit message.

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

**For communications and messaging:**
Ask: "Would Simone approve this copy?" Specifically: does the opening
sentence put the person in crisis first? Is this written for the right
audience? Does the language make the technology invisible and the mission
visible? Apply to every external-facing document, demo page, and
user-facing string in the application.
Ask: "What would Marcus flag here?" Before any city IT engagement, run
through his six current findings. Before any new feature touches auth,
multi-tenancy, or DV data handling, ask whether it introduces a new
attack surface he hasn't seen yet.
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

**For training and documentation:**
Ask: "What would Devon say about this?" Specifically: is this the right
format for the actual user, or just the right content? Would Reverend
Monroe's 67-year-old volunteer coordinator complete this task correctly
using only what we've given them? Before any pilot onboarding conversation,
share the demo URL with Devon for a gap analysis of in-app help text,
empty states, and error messages.

**For search engine optimization and discoverability:**
Ask: "Can Nadia find this page via Google?" Apply to every public-facing page,
landing page, and static content page. Specifically: is the content server-rendered
(not hidden behind client-side JS)? Does it have proper meta tags, structured
data, and a path to indexation? Before any new public page goes live, verify
it has a unique title, description, JSON-LD schema, and is included in the sitemap.

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
| 🔒 Marcus Webb | Pen Tester / AppSec | Auth surface, multi-tenant isolation, security headers |
| 📣 Simone Okafor | Brand & Communications | Naming, messaging, audience-specific materials, copy review |
| 📋 Devon Kessler | Instructional Designer | Job aids, coordinator quick-start card, onboarding formats |
| 🔍 Nadia Petrova | SEO Strategist | Crawlability, structured data, local SEO, new domain authority |
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
*Last updated: April 2026 — v19 personas*
