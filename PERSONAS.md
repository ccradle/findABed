# Finding A Bed Tonight — Personas

This file defines the personas used across the FABT project for UX evaluation,
accessibility auditing, QA decisions, and architectural reviews. Reference these
when evaluating feature design, writing tests, assessing accessibility, or
deciding what matters in a demo.

Two categories: **User Role Personas** (the people who use the platform) and
**Team Personas** (the people who build and advise on it).

---

## User Role Personas

These are the platform roles made human. Use these when evaluating UX,
writing Playwright tests, auditing accessibility, or deciding what to demo first.

**Post-G-4.4 (v0.53) role taxonomy:** `COC_ADMIN` (tenant-scoped admin),
`COORDINATOR`, `OUTREACH_WORKER`, plus `PLATFORM_OPERATOR` for cross-tenant
platform actions (separate identity backed by the `platform_user` table
with mandatory MFA). The legacy `PLATFORM_ADMIN` role is deprecated; the
V87 backfill grants `COC_ADMIN` to existing `PLATFORM_ADMIN`-bearing users
so historical persona descriptions referencing PLATFORM_ADMIN map cleanly
to today's COC_ADMIN.

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

### 🔓 Demetrius Holloway — Reentry Housing Navigator

**Real role:** `NAVIGATOR` (third-party hold model — holds on behalf of clients)
**Organization:** Trillium-contracted reentry organization (Johnston, Wilson, Nash counties, NC)
**Experience:** Certified Peer Support Specialist (CPSS); 7 years lived experience of incarceration; 3 years reentry housing navigation

**Who he is:**
Demetrius was released from North Carolina state prison in 2021 with $45, a bus ticket, and no verified home plan. He spent his first three nights in an emergency shelter, navigating bed availability through phone calls alone. That experience became his career. He now works as a CPSS and housing navigator for a Trillium-contracted reentry organization — placing people leaving incarceration into shelter, often on release day itself.

He sits on his county's Local Reentry Council. He has never used a bed availability platform because one has never existed in his world. He works the phone. His case is not unusual: 28% of people released from NC prisons in 2024 were released into homelessness (5,610 of 19,690 releases). Housing instability at release is the primary predictor of reincarceration.

**Device and environment:**
- Field mobile — often in a parking lot, on a bus, or from a shelter lobby
- Does not always have a smartphone available in the field
- Clients are sometimes given a phone at release; others are not
- Release day logistics create 2–4 hours of transport, paperwork, and transfer delays between hold and arrival

**The three blockers (core design requirements he surfaces):**

**Blocker 1 — Criminal record policy is invisible**
Shelter criminal record acceptance policies are not in any system he uses. They vary: some accept all felonies, some exclude violent felonies, some exclude sex offenses, some have blanket bans. A bed availability number is useless without knowing whether that shelter will accept his client's charge. Every shelter call starts: *"Do you accept someone with a felony?"* He learns policies by calling. Every time. There is no list.
- *Design implication:* Shelter records must expose criminal record acceptance policy as a structured field. All displays must carry a disclaimer: self-reported by shelter, verify directly before assuming eligibility.

**Blocker 2 — Supervision geography is invisible**
People on post-release supervision are restricted to an approved county or district by their supervision order. A bed in the wrong county is not a usable bed — accepting it triggers a supervision violation.
- *Design implication:* County must be a discrete indexed field on shelter records with a filter in bed search. Full DAC integration for automatic boundary enforcement is future scope; county filter is the MVP.

**Blocker 3 — Hold duration is too short for release day**
Prison bus drops at 8am. Transport to shelter may take 2–4 hours depending on location, paperwork delays, and transfer logistics. A 90-minute hold frequently expires before the client arrives.
- *Design implication:* Hold duration must be configurable at the tenant/deployment level with a UI-exposed setting in the admin panel. Reentry deployments set 180–240 minute holds.

**Additional requirements he surfaces:**
- **Third-party navigator hold** — he holds beds on behalf of clients who may not be platform users and may not have phones. Hold attribution requires `held_for_client_name` + `held_for_client_dob` — enough for the shelter to match the person at the door. PII nulled after 24h post-expiry (same pattern as DV referral tokens).
- **Hold notes** — free text on the reservation record, visible to the shelter coordinator. Example: *"Client on post-release supervision, must arrive by noon, contact PO [name/number] if questions."*
- **`requires_verification_call` flag** — boolean on the shelter record that surfaces to the navigator when this shelter requires a direct call to verify eligibility even when policy fields are populated.

**His aspirational workflow (FABT):**
1. Client release date confirmed — opens FABT on his phone
2. Filters by county (approved supervision geography), shelter type, `accepts_felonies: true`
3. Sees which shelters have available beds AND accept his client's charge category
4. Calls the top two or three to confirm — the platform reduced his call list from six to two
5. Places a hold with client name and hold notes for the shelter coordinator
6. Transports client — hold is still active when they arrive (180-minute default)
7. Shelter coordinator matches client name to hold record, completes intake

**His design review questions:**
1. Does the shelter accept people with felony records, and if so, which offense types are excluded?
2. How long can a hold be extended, and who can release it if the client is delayed?
3. What happens if the client doesn't have a phone? (Third-party model — the person seeking the bed is not always the person interacting with the platform)
4. Can I see historical fill rates for a shelter? (A shelter that lists available beds every Monday but is full by 10am is not the same as genuine availability)
5. What if the shelter's criminal record policy is wrong in the system? (He needs the disclaimer and the `requires_verification_call` flag — the platform reduces unnecessary calls, it does not replace verification)

**His canonical quote:**
*"The shelter might have a bed. But if they don't take his charge, that bed doesn't exist for us. I don't find that out until I call. And by then it's 9am and he's been standing outside for an hour."*

**Broader lens:**
Demetrius represents an entire practitioner category: CPSS workers, Local Reentry Council case managers, Trillium T-STAR Health Specialists, halfway house staff, and DPS community supervision officers who informally help clients find beds. All of them share the same three blockers. His use case makes FABT's value proposition legible to the NC Department of Adult Correction, Trillium Health Resources, and the state's Reentry 2030 initiative.

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

### 🗄️ Elena Vasquez — Senior PostgreSQL DBA / Database Reliability Engineer

**Real role:** External advisor — database architecture, RLS design, performance
**Background:** 14 years PostgreSQL administration, 4 years at Crunchy Data,
currently principal DBRE at a multi-tenant SaaS company (5,000+ tenants on
PostgreSQL with RLS-based isolation)
**Certifications:** EDB PostgreSQL Professional, AWS Database Specialty
**Community:** Speaks at PGConf US annually, maintains a popular blog on
PostgreSQL RLS patterns, contributor to pgaudit extension

**Who she is:**
Elena has seen every way PostgreSQL RLS can silently fail. She has debugged
cross-tenant data leaks at 3am, traced "zero rows returned" bugs to
connection pool session variable leakage, and written the incident reports
that changed how her company deploys RLS. She is methodical, precise, and
allergic to guessing. Her first response to any database issue is "show me
the actual state" — she trusts `pg_policies`, `pg_stat_activity`, and
`EXPLAIN ANALYZE` over hypotheses.

**What she reviews:**
- RLS policy design: USING vs WITH CHECK semantics, permissive vs restrictive
  policy composition, table owner bypass behavior
- Connection pool interaction: `set_config` scoping (transaction-local vs
  session-level), HikariCP connection lifecycle, state leakage between requests
- Spring Data JDBC + PostgreSQL: how `@Query`, `CrudRepository.save()`, and
  `INSERT RETURNING` interact with RLS policies
- Migration safety: Flyway + PostgreSQL transactional DDL, `ALTER DEFAULT
  PRIVILEGES` inheritance rules, `CREATE INDEX CONCURRENTLY` outside transactions
- Performance under RLS: LEAKPROOF function requirements, index usage through
  policy predicates, cascading subquery cost in policy USING clauses

**Her diagnostic approach (always in this order):**
1. **Reproduce, don't theorize.** Connect to the actual database. Never guess
   what the state is — query it.
2. **Check `pg_policies`** — are the policies what you think they are?
3. **Check grants** — does the role have the privilege? `ALTER DEFAULT PRIVILEGES`
   has subtle rules about which creating role triggers the default.
4. **Check `current_user`, `current_setting()`** — is the session state what you
   expect? Connection pooling can surprise you.
5. **Check `EXPLAIN`** — is the RLS predicate being applied? Is it using an index
   or forcing a sequential scan?
6. **Check the JDBC driver behavior** — Spring Data JDBC's `INSERT RETURNING *`
   triggers SELECT policy evaluation. This is documented PostgreSQL behavior but
   surprises every application developer the first time.

**Her current findings (static review):**
1. **`INSERT RETURNING *` triggers SELECT RLS** — Spring Data JDBC's
   `CrudRepository.save()` always uses `INSERT ... RETURNING *`. PostgreSQL
   evaluates the SELECT policy on the RETURNING clause. If `current_user_id`
   doesn't match the inserted row's `recipient_id`, the RETURNING is blocked
   and the JDBC driver reports it as an RLS violation. Fix: set `current_user_id`
   to the recipient's UUID (transaction-local) before INSERT.
2. **`set_config(name, value, true)` is transaction-local** — safe with connection
   pooling. `set_config(name, value, false)` is session-level — leaks across
   requests via HikariCP. The codebase correctly uses `false` at connection init
   (overwritten on every checkout) and `true` for mid-transaction overrides.
3. **`@Modifying @Query` DELETE without RETURNING** — should not trigger SELECT
   policy. If a DELETE appears to not work, check whether the `@Transactional`
   context is actually committing, and whether the cutoff parameter is binding
   correctly (Spring Data JDBC handles `Instant` → `TIMESTAMPTZ` via registered
   converters, but raw `JdbcTemplate` does not — use `Timestamp.from()`).
4. **`ALTER DEFAULT PRIVILEGES` only applies to the creating role** — if Flyway
   runs as `fabt_test` and sets defaults for `fabt_test`, then tables created by
   `fabt_test` get the grants. But if `SET ROLE` changes the creating role before
   the CREATE TABLE, the defaults don't apply. Verify with `\dp` or `relacl`.

**Her key positions:**
- Never guess database state. Query it. `pg_policies`, `pg_stat_activity`,
  `information_schema.table_privileges` — trust the catalog, not the code.
- RLS failures are silent by design (zero rows, not errors). This is a feature
  for security but a nightmare for debugging. Add explicit diagnostic queries
  in tests when RLS is involved.
- `EXPLAIN ANALYZE` is non-negotiable for any query that touches RLS-protected
  tables at scale. RLS predicates that prevent index usage will not show up
  until you have 10,000+ rows.
- Connection pool + RLS is the most common source of multi-tenant data bugs.
  Every connection checkout must explicitly set the session state. Never rely
  on leftover state from a previous request.

**Her lens for every RLS issue:**
"Show me the pg_policies output, the current_setting values, and the EXPLAIN
plan. I'll tell you in 30 seconds whether it's a policy issue, a grant issue,
or a session state issue."

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
the project team will ever find it."

---

### 📐 Dr. Yemi Okafor — Research Methodologist

**Real role:** External advisor — implementation science, measurement design,
pilot evaluation framework
**Background:** 15 years at the intersection of implementation science, housing
policy research, and homeless services system evaluation
**Publications:** *Housing Policy Debate*, *Journal of Social Distress and
Homelessness*, *Implementation Science*
**Experience:** Methodology consultant on three CoC-level technology pilots —
Houston (urban), Bay Area (mixed), and rural Appalachia (most relevant to FABT's
eastern NC target geography)

**Who they are:**
Dr. Okafor studies how interventions get implemented in the real world and
whether they produce the outcomes they claim. They have watched well-designed
platforms fail not because the technology was wrong, but because nobody defined
success before deployment — so nobody could demonstrate it afterward. Rural
implementations fail differently than urban ones: the information gaps are
wider, the staff are thinner, and the communities that most need the evidence
are least equipped to generate it. Dr. Okafor brings the rigor that connects
FABT's field performance to publishable, fundable, defensible evidence.

**What they bring to the team:**

**Measurement framework design.** The San Diego Shelter Ready data, the NAEH
outreach framework, the LA Controller audit — these are not just citations.
They are baselines against which FABT's outcomes will be evaluated. Dr. Okafor
translates existing evidence into pre-specified measurement frameworks before
deployment, so data collected from day one is publishable and defensible.

**Pilot validity standards.** A pilot that produces anecdotes is not a pilot —
it's a demonstration. A pilot that produces data that can be compared to
baseline, replicated in another community, and submitted to a peer-reviewed
journal is a pilot. The difference is in how the study is designed before it
starts.

**Connection to external research frameworks.** HUD's System Performance
Measures, Trillium's housing outcomes, Dr. Rong Bai's child welfare research,
Professor Hsu's data science methodology — FABT's data can speak to all of these
if the right variables are captured from the beginning.

**First observation on the Pitt County pilot:**
One metric was missing from the initial pilot framework: **shelter staff time
spent on availability updates**, measured before and after FABT deployment.
This is the variable that answers Regina Rodgers' question — "how will you get
shelters to invest the time?" — with data rather than assertion. The platform
already logs `availabilitySummary.dataAgeSeconds` for every shelter. Time
between updates is in the data model. This can be surfaced as a research output
without any new code.

**Recommended pilot metrics (full set):**
1. Time to placement — from bed search initiation to confirmed hold
2. Holds initiated vs. completed — conversion rate, tracks adoption quality
3. Zero-result searches — quantifies unmet demand automatically
4. Coordinator update frequency — time between availability snapshots
   per shelter (already in `dataAgeSeconds`)
5. Outreach worker adoption — % of eligible workers with at least one
   field hold per week
6. DV referral completion rate — accepted, rejected, expired breakdown
7. **Shelter staff time on availability updates** — pre/post comparison,
   the adoption sustainability metric

**Definition of a valid pilot:**
Minimum 90 days. Minimum 2 shelters (one emergency, one DV). Minimum 5 active
outreach workers. Pre-specified baseline measurement of all 7 metrics before
go-live. Zero data incidents. Outcomes documented in a format that can be
submitted to the Journal of Social Distress and Homelessness or presented at
the NAEH annual conference.

**Connection to academic research partners:**
Dr. Okafor works directly with Professor Hsu (UNC) and Dr. Rong Bai (ECU) to
align FABT's measurement framework with their respective research agendas.
This is the bridge between a community pilot and a publishable study. The
prerequisite for journal publication is that the measurement framework was
established before deployment — not reconstructed from whatever data happened
to be collected.

**Non-negotiable principle:**
Speed and rigor are not opposites. The family in the parking lot does not
wait for a randomized controlled trial. But the first pilot must be designed
with enough rigor that it produces evidence, not just experience. These can
coexist if the framework is established before day one.

**Lens for every pilot and research decision:**
"Is this designed to produce evidence, or just experience?
If we can't answer that question before deployment, we are not ready to deploy."

---

### 💼 Nadia Osei — Social Enterprise Business Strategist

**Real role:** External advisor — business model, revenue strategy,
commercial path (volunteer engagement)
**Background:** 14 years building revenue models for mission-driven
organizations — open-source civic tech, nonprofit software, social enterprise
**Notable work:** 6 years advising Code for America network companies on
commercialization; 4 years as CSO at a municipal software company;
observed two civic tech projects successfully cross from open-source
project to sustainable business

**Who she is:**
Nadia believes mission and revenue are not in conflict if designed together
from the start — and are in conflict if revenue is bolted on afterward.
She is direct, experienced with government contracting, and has seen
exactly what kills civic tech commercialization attempts. She is here
because she thinks FABT could be the third open-source civic tech project
she has watched successfully make this transition — but only if specific
decisions are made at specific moments, most of which are now.

**The commercial model she recommends: Open Core SaaS**

Free self-hosted tier (what exists now) + paid managed tier (hosting,
updates, support, onboarding handled by the organization). The free tier
stays free forever — that is both a promise and a competitive moat.
The paid tier is the same software, managed for communities that cannot
or will not run their own infrastructure.

**Target market for the commercial tier:**
Rural counties, small towns, and regional CoCs that want the platform to
work — not to run the platform. Towns under 50,000 population with no IT
staff and no current shelter coordination system. The closest competitor
they currently have is a spreadsheet.

**Proposed pricing (opening position for discussion):**

| Tier | Target | Monthly | Annual |
|---|---|---|---|
| Community (free) | Any CoC, self-hosted | $0 | $0 |
| Managed Lite | Rural counties, small towns | $299 | $2,999 |
| Managed Standard | Mid-size cities, regional CoCs | $599 | $5,999 |
| Managed Pro | Metro areas, multi-CoC deployments | $1,499 | $14,999 |

Anchor framing for the bottom number: $299/month is less than one
coordinator's hourly wage for a month of midnight phone calls.

**The five questions this team must answer:**

1. **Legal entity** — Who invoices? Who holds contracts? Who employs
   support staff? Apache 2.0 means anyone can commercialize this,
   including competitors. The entity must exist before the first
   paid contract. Options: Open Source Collective fiscal sponsorship,
   LLC, nonprofit with for-profit subsidiary. Each has different
   implications for government contracting, grant eligibility, and
   investor interest. Casey Drummond owns this question.

2. **Support model for paid tier** — "Best-effort via GitHub Issues"
   is not a paid tier support model. A $299/month customer needs
   to know what happens at 2am during a White Flag event. This needs
   a specific answer before any commercial conversation.

3. **What "turnkey" means operationally** — Hosting, automatic updates,
   and what else? Onboarding assistance? Coordinator training? Data
   migration from 211 systems? Phone support? Each addition increases
   cost and operational complexity. Each removal makes the offer less
   compelling to a town with no IT staff. Must be defined before pricing.

4. **Competitive landscape honesty** — Almost no one competes in the
   small-town, low-budget, turnkey managed service market for shelter
   coordination. That's an opportunity and a warning — markets with no
   competitors sometimes have no competitors because there's no money.
   Needs validation with real small-town conversations.

5. **The open-core line** — The managed tier means "we run it for you"
   not "we built something better for paying customers." The moment the
   managed tier has features the free tier doesn't eventually get, the
   community fractures and foundation trust is destroyed. This line must
   be stated explicitly and held permanently.

**Her first recommended concrete actions:**

1. Team alignment: commercial path or mission-only path? Both are valid.
   Ambivalence is not.
2. Identify 3-5 small NC towns (under 50,000 population) as first
   commercial pilot candidates. Johnston County / Smithfield is already
   on the outreach list and is a natural first managed-service conversation.
3. One session with Casey Drummond to narrow the legal entity options
   to the right structure for this specific situation.

**Her non-negotiable principle:**
The open-source community version and the commercial managed version
must never diverge on features — only on who operates the infrastructure.
The paying customer gets reliability and support. The self-hosted community
gets the same software. GitLab learned this the hard way. Mattermost
navigated it correctly. FABT must follow Mattermost's path.

**Her lens for every commercial decision:**
"Does this decision serve the communities that can pay AND protect the
communities that cannot? If it harms the second group to benefit the
first, it is the wrong decision."

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

### ♿ Tomás Herrera — Accessibility Engineer

**Background:** 8 years doing accessibility engineering in government and civic
tech. IAAP CPACC-certified. Former accessibility lead at GSA 18F, where he
shipped WCAG 2.1 AA remediation for several federal benefits portals under
Section 508 audit pressure. Runs NVDA and VoiceOver daily as part of his testing
practice, not as an afterthought. Co-authored internal guidance used by two
state Medicaid agencies.

**Lens:** "Every violation has a name — somebody who hits a wall the moment
we ship it." The ADA Title II April 24, 2026 deadline for large government
entities is a non-negotiable gate for any city adoption conversation — Teresa
Nguyen's procurement path runs directly through his approval. Cares equally
about the reader using NVDA in a hospital discharge office, the coordinator
with presbyopia zooming to 200%, and the outreach worker using voice control
while driving. Accessibility is a release gate, a peer to QA and performance,
not a polish pass.

**Key positions:**
- WCAG 2.1 AA is the baseline, not the ceiling — the project should target AA
  and spot-check AAA on critical flows (bed search, hold, DV referral)
- Every color token in `global.css` must ship with a contrast annotation
  (`/* on X bg = Y:Z ✓ */`) — unannotated tokens are how dark-mode contrast
  bugs ship. The `--color-error-mid` regression on 2026-04-12 is the
  reference incident.
- `aria-hidden="true"` does not excuse insufficient contrast on visible
  decoration — users who zoom to 400% or use Windows High Contrast still
  see the element, and axe-core correctly flags it
- axe-core must run on every persona-critical page in CI, not just the
  home page — the color-system spec is the pattern to copy
- Keyboard-only traversal of every core flow must be part of the Playwright
  regression suite, not a manual QA checklist item
- NVDA + VoiceOver spot-check before every tagged release — 20 minutes of
  screen reader time catches things axe cannot
- Focus indicators must be visible in both light and dark modes (dark mode
  is where focus rings quietly disappear into the background)
- Error messages live in Keisha's lane as much as his — plain English, no
  jargon, dignity-preserving. A technically-accessible error that shames
  the user is still an accessibility failure.
- Skip links, landmark regions, and heading hierarchy are load-bearing for
  screen reader users — treat them like API contracts, not decoration
- Motion-reduced media query respected everywhere: any animation longer
  than 200ms needs a `prefers-reduced-motion` guard

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

**For accessibility engineering (WCAG conformance and assistive tech):**
Ask: "Would Tomás sign off on this before ship?" Specifically: does every color
token in `global.css` carry a contrast annotation? Does the Playwright suite
include an axe-core run on this page? Is the keyboard-only path tested through
nginx, not just via click selectors? Has NVDA been run over the flow within
the last tagged release? Before any ADA Title II-sensitive conversation with
Teresa or a city IT team, run the checklist: color-system spec green, keyboard
traversal green, focus rings visible in dark mode, motion-reduced guards on
animations, skip links present. `aria-hidden` never excuses insufficient
contrast — zoom and Windows High Contrast still see it.

**For accessibility auditing (user-experience lens):**
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

**For commercial and revenue decisions:**
Ask: "What would Nadia say about this?" Specifically: does this decision
serve communities that can pay AND protect communities that cannot? Before
any conversation that involves money — pricing, contracts, government
agreements, or grant sustainability — run it through Nadia's five questions:
legal entity, support model, turnkey definition, competitive validation,
and the open-core line. These are sequential gates, not optional questions.

**For research and pilot design:**
Ask: "What would Dr. Okafor say about this?" Specifically: is this pilot
designed to produce evidence or just experience? Are the metrics pre-specified
before deployment? Is the baseline captured? Is the measurement framework
aligned with HUD SPM, NAEH standards, and the academic research partners?
Before any pilot launch conversation — with Pitt County, Trillium, or anyone
else — run the 7-metric framework and confirm all baselines are established.
"Designing it right before day one" is the non-negotiable principle.
Ask: "What would Devon say about this?" Specifically: is this the right
format for the actual user, or just the right content? Would Reverend
Monroe's 67-year-old volunteer coordinator complete this task correctly
using only what we've given them? Before any pilot onboarding conversation,
share the demo URL with Devon for a gap analysis of in-app help text,
empty states, and error messages.

**For reentry housing navigation:**
Ask: "Does Demetrius know before he calls whether this shelter will accept his client's charge? Can he filter by supervision-approved county? Will the hold still be active when the transport arrives?" Apply to every change touching shelter search filters, hold duration configuration, and shelter eligibility fields. His three blockers are non-negotiable for any reentry deployment: criminal record policy visibility, supervision geography filtering, and hold duration long enough for release-day transport. The third-party navigator model also applies — hold attribution must support placing a bed for a client who is not a platform user and may not have a phone.

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
| 🔓 Demetrius Holloway | Reentry Navigator | Criminal record policy filter, supervision geography, hold duration for release day |
| 🌐 Rev. Alicia Monroe | Faith Shelter | Zero training, partial participation, plain-language cost |
| 📊 Dr. Kenji Watanabe | Policy Researcher | HMIS compliance, SPM alignment, small-cell suppression |
| 🙋 Keisha Thompson | Lived Experience | Dignity, person-centered language, human impact |
| 🔒 Marcus Webb | Pen Tester / AppSec | Auth surface, multi-tenant isolation, security headers |
| 🗄️ Elena Vasquez | PostgreSQL DBA / DBRE | RLS policy design, connection pool state, JDBC+PG interaction |
| 📣 Simone Okafor | Brand & Communications | Naming, messaging, audience-specific materials, copy review |
| 📋 Devon Kessler | Instructional Designer | Job aids, coordinator quick-start card, onboarding formats |
| 🔍 Nadia Petrova | SEO Strategist | Crawlability, structured data, local SEO, new domain authority |
| 📐 Dr. Yemi Okafor | Research Methodologist | Pilot design, measurement frameworks, implementation science |
| 💼 Nadia Osei | Business Strategist | Commercial model, pricing, legal entity, managed-service path |
| 🏗️ Alex Chen | Principal Engineer | Architecture, module boundaries, correctness |
| 🤝 Maria Torres | Product Manager | User outcomes, adoption sequencing, outreach strategy |
| 🔧 Jordan Reyes | SRE | Deployment, security posture, CI integrity |
| 🧪 Riley Cho | QA Engineer | Test coverage, invariant enforcement, DV canary |
| ♿ Tomás Herrera | Accessibility Engineer | WCAG 2.1 AA, ADA Title II, color contrast, screen reader, keyboard |
| ⚡ Sam Okafor | Performance | SLO compliance, cache behavior, load testing |
| ⚖️ Casey Drummond | Attorney | Legal compliance, data governance, procurement path |

---

*Finding A Bed Tonight — Personas Reference*
*Used by: Claude Code (CLAUDE-CODE-BRIEF.md), design reviews, accessibility audits,
QA planning, demo preparation, funding conversations, pilot design*
*Last updated: April 23, 2026 — v22 (added Demetrius Holloway, reentry housing navigator)*
