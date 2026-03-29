# FABT Communications & Brand Recommendations

**Author:** Simone Okafor (Brand Strategist & Communications Director)
**Date:** March 2026
**Status:** Working document — recommendations for team discussion and action
**Commit to:** `findABed/COMMUNICATIONS-RECOMMENDATIONS.md`

---

## The One Thing Before Everything Else

Before naming, before messaging, before any document gets rewritten —
the team needs to answer one question and write it down:

> **"What are the three sentences you'd say to a shelter coordinator
> in a CoC meeting hallway with 90 seconds?"**

Maria Torres offered this in our first session:

> *"Right now, when a family needs an emergency shelter bed at midnight,
> outreach workers make phone calls — to shelters that may be full, may
> be closed, or may not serve that family's needs. We built a free,
> open-source platform that shows real-time bed availability across every
> shelter in a CoC. Outreach workers search on their phone, hold a bed
> in three taps, and the shelter knows they're coming. No more midnight
> phone calls."*

**That is the brief. Everything in this document flows from it.**

Specifically: *"No more midnight phone calls"* is a headline. It is
specific, emotional, and true. It should appear on the About page,
in the grant narrative, and in the first sentence of every pitch.

---

## Part 1 — The Naming Question

### Current State

The platform is called **Finding A Bed Tonight**. The GitHub repos are
`findABed` (docs) and `finding-a-bed-tonight` (code). The acronym FABT
is used internally throughout the codebase and documentation.

### What Works

- **Human and specific.** It puts the person in crisis at the center.
  "Tonight" creates urgency. You immediately understand what it does.
- **Mission-aligned.** The name reflects what the platform is for, not
  what it is made of. That's rare and valuable.

### What Doesn't Work

- **It doesn't abbreviate.** FABT is not speakable. No one will say
  "we use FABT" out loud and have it land. Compare: "we use Slack,"
  "we use Salesforce," "we use Shelter Ready."
- **It doesn't fit a URL.** `findingabedtonight.org` is 20 characters
  with no natural break. `findabed.org` is available and is already
  the name of the docs repo — but the inconsistency between repos
  signals an unresolved decision.
- **It doesn't scale.** If this platform expands to transitional housing,
  rapid rehousing, or other social services, "a bed tonight" becomes
  inaccurate. A name that constrains future scope is a liability.
- **It reads as temporary.** "Tonight" implies urgency but also
  impermanence. A city signing a three-year technology agreement wants
  a platform name that sounds like it will still be here in three years.

### The Decision Framework

There are three viable paths. The team must choose one before the first
external demo — not because the name is wrong, but because ambivalence
is worse than either option.

**Path A: Commit to "Finding A Bed Tonight" fully.**
- Register `findabed.org` as the canonical domain
- Align both repos under a consistent naming convention
- Develop a visual identity (wordmark, color palette)
- Use "Finding A Bed Tonight" on all external materials
- Adopt "Find A Bed" as the short form for spoken use
- Own it with conviction

**Path B: Rename before broader launch.**
- Naming exploration — working candidates below
- New domain registration
- Repo rename (can be done — GitHub preserves old URLs)
- Update all internal documentation

**Path C: Develop a product name distinct from the project name.**
- The open-source project is "Finding A Bed Tonight" (for developers,
  GitHub, technical audiences)
- The deployed product has a shorter brand name (for coordinators,
  outreach workers, city officials)
- Example: the open-source project is "Chromium," the product is "Chrome"

**My recommendation:** Path A or Path C. Path B (full rename) is
disruptive and the team has enough to do. If the name is a long-term
concern, Path C gives the flexibility to develop a product brand without
abandoning the project name that's already in the codebase.

### Naming Candidates (If Exploring Path B or C)

These are starting points for conversation, not final recommendations.
Each would need trademark search and domain availability check.

| Name | Strengths | Concerns |
|---|---|---|
| **Find A Bed** | Short form of current name, natural language | Generic, hard to trademark |
| **BedReady** | Action-oriented, echoes "Shelter Ready" (SD) | Too similar to competitor |
| **ClearPath** | Scalable, implies navigation to help | Abstract, less mission-specific |
| **NightLink** | Urgency + connection, short | "Night" limits scope |
| **HarborLink** | Warmth, shelter metaphor, scalable | Abstract |
| **ReachBed** | Action + outcome | Awkward |
| **BedBoard** | Dashboard metaphor, clear | Technical-feeling |
| **OpenShelter** | Open-source mission signaling | Implies the shelter is open, not the software |

**The best brand name for this type of platform:**
- 1–2 words
- Contains a verb or implies action
- Suggests connection or finding
- Doesn't use "bed," "shelter," or "homeless" (limits scope and can
  carry stigma in government procurement contexts)
- Works as a .org domain

---

## Part 2 — Breaking Up the README

### The Problem

The current `finding-a-bed-tonight` README is **1,142 lines** serving
four different audiences simultaneously:

1. **Developers** evaluating the codebase
2. **City IT officers** doing security and procurement due diligence
3. **CoC administrators** evaluating functionality
4. **Shelter operators and outreach workers** trying to understand if
   this is for them

A 1,142-line README serves none of these audiences well. Each audience
has a different question when they arrive, a different amount of time,
and a different definition of "this is what I needed."

### The Solution: Audience-Specific Front Doors

The README becomes a navigation hub. Each audience gets their own page.

**New README structure (target: 200 lines):**

```markdown
# Finding A Bed Tonight

[The parking lot story — 3 sentences]
[The headline: "No more midnight phone calls"]

## What It Does (3 sentences)

## Who It's For
→ [Outreach Workers & Coordinators](docs/FOR-COORDINATORS.md)
→ [CoC Administrators](docs/FOR-COC-ADMINS.md)
→ [City Officials & IT Departments](docs/FOR-CITIES.md)
→ [Developers & Contributors](docs/FOR-DEVELOPERS.md)
→ [Funders](docs/FOR-FUNDERS.md)

## Quick Start (developers)
[Existing dev-start.sh instructions — 20 lines]

## Project Status
[Current version, what's complete, what's next — 10 lines]

## License & Support
[Apache 2.0, support model, contact]
```

### Documents to Create

**`docs/FOR-COORDINATORS.md`** — 1 page, plain English
*Audience: Sandra Kim, Reverend Monroe's volunteer coordinator*
- What does this do? (plain English, no jargon)
- What does it cost? (free, who pays for hosting)
- How do I update my bed count? (3-tap flow, with screenshots)
- What if my shelter doesn't have WiFi? (offline mode)
- Who do I call if something's wrong?
- How do I get my shelter added?

**`docs/FOR-COC-ADMINS.md`** — 2 pages
*Audience: Marcus Okafor*
- What problem does this solve for your CoC?
- What can you do with it right now?
- HUD reporting: what's available, what's coming
- How do you onboard a new shelter? (the 7-day workflow, plain English)
- DV shelter protection: what your shelter directors need to know
- What does it cost to deploy?
- How does it connect to HMIS?
- Support and maintenance: the honest answer

**`docs/FOR-CITIES.md`** — 2 pages
*Audience: Teresa Nguyen, her city attorney*
- Who owns the data? (you do — self-hosted)
- Is it WCAG 2.1 AA accessible? (yes, with ACR document link)
- What's the security posture? (link to security summary)
- Apache 2.0: what it means for city procurement
- What happens if we stop using it?
- What is the support model?
- How is this different from commercial alternatives?
- Government adoption guide (link to Casey's document)

**`docs/FOR-DEVELOPERS.md`** — the existing technical README content
- Architecture, module boundaries, API reference, running tests,
  troubleshooting — everything technical from the current README
- This audience is already well-served; just move the content

**`docs/FOR-FUNDERS.md`** — 1 page, story-first
*Audience: Priya Anand, her foundation board*
- The problem (parking lot story)
- The solution (platform overview)
- Theory of change ("designed to support" 2hr→20min framing)
- Who uses it (named pilot partner, when available)
- Sustainability model
- What your funding enables
- Contact for letters of support

---

## Part 3 — The GitHub Pages Site

### Current State

`ccradle.github.io/findABed` exists with 18 annotated screenshots
of the platform plus DV referral and HMIS walkthroughs. The content
is accurate and technically thorough.

### What It's Missing

The site reads like a product demo for someone who already knows why
they're there. A city official arriving cold will see "Coordinator
Dashboard" before they understand what a coordinator does or why that
dashboard matters.

### Recommended Structure

**Page 1: `index.html` — The story (currently a screenshot gallery)**

```
Opening: The parking lot story [3 sentences, large text]

The problem in numbers:
  [X] shelters in Wake County
  [X] outreach workers making phone calls every night
  [Average wait time — if measurable, use it]

The solution: [one paragraph, no jargon]

Who uses it: [3 user types with one sentence each]

[View the platform →] [Read the technical docs →] [Get in touch →]
```

**Page 2: `demo/index.html` — The platform walkthrough**
Keep the screenshots. Add context before each one:
- Before "Outreach Search" screenshot: "An outreach worker searches for
  a bed at 11pm. The platform shows what's available right now."
- Before "Hold This Bed" screenshot: "One tap holds the bed for 90 minutes —
  enough time to transport the client safely."

**Page 3: `for-cities.html`** — City and CoC adoption landing page
Distilled version of `docs/FOR-CITIES.md`, with a contact form or
email link at the bottom.

---

## Part 4 — The 90-Second Brief by Audience

The team needs to develop and practice these. I'll draft them; the
team should refine based on actual conversations.

### Version 1: For a Shelter Coordinator (Sandra Kim)

> "Right now, every time an outreach worker needs a bed, they call you.
> This platform lets them see your availability on their phone — so they
> only call when they have a specific question, not to ask if you have
> space. Updating your bed count takes about 30 seconds. And if a worker
> holds a bed for a client, you can see it so you're not caught off guard."

### Version 2: For a CoC Admin (Marcus Okafor)

> "We built a free, open-source platform that gives your whole CoC
> real-time bed availability across every participating shelter. Outreach
> workers search on their phones. Coordinators update in three taps.
> You get utilization data and demand signals that your current system
> can't give you. It connects to HMIS. And because it's open-source and
> self-hosted, you own your data."

### Version 3: For a City Official (Teresa Nguyen)

> "This is open-source infrastructure for emergency shelter coordination —
> free to use, self-hosted, so the city owns its data. It's WCAG 2.1 AA
> accessible, Apache 2.0 licensed, and it's been built from day one for
> government adoption. We're piloting it in the Raleigh area and looking
> for a city partner who wants to be part of shaping it."

### Version 4: For a Funder (Priya Anand)

> "A family in crisis waits two hours to find a shelter bed because
> outreach workers are making phone calls in the dark. We built a free,
> open-source platform that makes real-time availability visible across
> an entire region — designed for communities that can't afford commercial
> software. We're in pilot in Wake County and looking for funding to
> support adoption in additional communities."

---

## Part 5 — User-Facing Copy Review

This connects directly to Keisha Thompson's concern about dignity and
person-centered language. The platform's user-facing copy is part of
the brand. These are starting points for a systematic review.

### Items for Review

**"Hold This Bed"**
- Current: worker-centric action button
- Question: Does this phrase land differently if you're the person
  being held for? Consider: "Reserve This Bed," "Save This Bed,"
  or "Secure This Bed" — any of these is slightly more neutral
- Recommendation: Test with outreach workers and at least one person
  with lived experience before changing. Keisha's input is essential here.

**Population Type Labels (displayed in UI)**
`SINGLE_ADULT`, `FAMILY_WITH_CHILDREN`, `WOMEN_ONLY`, `VETERAN`,
`YOUTH_18_24`, `YOUTH_UNDER_18`, `DV_SURVIVOR`

- These are operational categories that are also displayed in the
  outreach worker's search interface
- `DV_SURVIVOR` as a visible label in a search results interface is
  a dignity concern — the outreach worker selects this to find beds
  for a person who may be sitting next to them
- Consider whether the display label in the UI can be different from
  the internal enum value: display "Safety Shelter" instead of
  "DV_SURVIVOR" in the outreach search interface
- Recommendation: Keisha and Simone should review display labels
  together before pilot

**Error Messages**
- "Insufficient permissions" (403) — clinical but acceptable
- "access_denied" — JSON key, not user-facing, fine
- Any error message that reaches an outreach worker's phone at midnight
  should be human and actionable, not technical

**"STALE" Freshness Badge**
- Accurate but slightly clinical
- Consider: "Last updated 9 hours ago" as plain text alongside the
  badge, so the meaning is immediate without knowing what "STALE" means
- This is already partially done via `data_age_seconds` — the badge
  and the age together are good

**Offline Banner: "You are offline"**
- Clear and correct
- Consider adding: "Your last search is still available" — reassurance
  that Darius hasn't lost his work

**"Warm Handoff"**
- This is internal/professional terminology
- Fine for coordinator-facing UI; not appropriate for any user-facing
  text that a client or family member might see

### Review Process Recommendation

Before pilot, convene a 2-hour copy review session:
- Simone (communications lens)
- Keisha Thompson (lived experience lens)
- Maria Torres (user outcomes lens)
- One outreach worker from the pilot organization
- Walk through every user-facing string in the application

The copy review session should happen before the WCAG audit findings
are closed — accessible language and dignified language are related.

---

## Part 6 — The One-Page Outreach Document

This is the document Maria needs before the first conversation with
Regina Rodgers or Tosheria Brown. It should be:

- **One page. Printable. No QR codes that won't scan.**
- **Story-first, not feature-first.** Lead with the parking lot.
  Follow with what the platform does for the specific person reading it.
- **Written for the coordinator, not the technologist.**
- **Honest about what's not done yet.** (CoC Analytics note, support model)

### Suggested Structure

```
[Title — 6 words or fewer]
[Subhead — what problem this solves]

[The parking lot story — 2 sentences]

For outreach workers:
  [3 bullet points — what they can do]

For shelter coordinators:
  [3 bullet points — what changes for them]

What it costs:
  [1 paragraph — free software, hosting costs, who typically pays]

How to get started:
  [2–3 sentences — contact, pilot process]

[Contact information / website]
```

This document does not exist yet. It should be the first deliverable
from the communications workstream — before the GitHub Pages rewrite,
before any naming decision, before anything else.

---

## Part 7 — The Naming and Tagline Decision

### If Committing to "Finding A Bed Tonight" (Path A)

Develop a proper brand identity around it:

**Tagline options:**

| Tagline | Tone | Best For |
|---|---|---|
| "No more midnight phone calls." | Direct, emotional | Coordinator outreach |
| "Real-time shelter, for every community." | Aspirational, scalable | City and funder |
| "Open-source. Free forever. Built for communities that need it." | Values-based | Developer and funder |
| "A bed. Tonight." | Minimal, urgent | General public |
| "When every minute counts." | Urgency | Outreach worker |

**My recommendation for the primary tagline:**
*"Real beds. Right now."*

Short. True. No jargon. Works across every audience. Contrasts with the
current reality (making phone calls, uncertain availability) without
using the word "problem."

**Visual identity (minimum for pilot):**
- Wordmark: "Finding A Bed Tonight" in a clean, accessible sans-serif
- Color palette: 2 colors — one warm (trust, human), one for action/CTA
- Apply to: GitHub Pages site, one-page document, email signature
- Do not commission custom illustration or photography for the pilot —
  it's not the right investment at this stage

### If Exploring a Product Name (Path C)

Criteria for the product name:
1. 1–2 words
2. Available as a .org domain
3. Passes a basic trademark search (USPTO)
4. Works in English and Spanish (Darius uses the Spanish toggle)
5. Does not use "bed," "shelter," "homeless," or "tonight"
6. A non-English speaker could approximate the pronunciation

Timeline: If exploring Path C, the naming decision should be made within
60 days — before any printed materials or press mentions.

---

## Part 8 — Priority Order

Everything above is a recommendation. Not everything can happen at once.
Here's the sequence that makes sense given where the project is:

**This week (before first external demo):**
- [ ] Write the one-page outreach document (Section 6)
- [ ] Develop the three 90-second briefs per audience (Section 4) —
  the team refines Maria's draft; Simone edits

**Before first city conversation:**
- [ ] Break up the README into audience-specific pages (Section 2)
- [ ] Rewrite GitHub Pages `index.html` as a story page (Section 3)
- [ ] Conduct copy review session for user-facing strings (Section 5)

**Before grant application:**
- [ ] Develop the `docs/FOR-FUNDERS.md` page (Section 2)
- [ ] Naming and tagline decision — Path A, B, or C (Section 1)
- [ ] Finalize theory of change language with Priya Anand

**Before pilot launch:**
- [ ] Visual identity minimum (wordmark, color palette) — if committing
  to current name
- [ ] Press/media strategy — one paragraph explaining what story to tell
  when the first journalist asks

---

## Appendix — Copy Principles for FABT

These apply to every piece of external communications the project produces.

**1. Person first, technology second.**
The platform is the means. The family in the parking lot is the point.
Every document should make the technology invisible and the person visible.

**2. Plain language, always.**
If Reverend Monroe's 67-year-old volunteer coordinator can't understand it,
rewrite it. If a city attorney has to read a sentence twice, shorten it.

**3. Honest about limitations.**
Don't claim WCAG compliance — cite the ACR document. Don't claim HUD
reporting is complete — note that CoC Analytics is live as of v0.12.0.
Don't promise support that doesn't exist — describe the actual model.
Funders and city officials have seen enough overpromising. Honesty is
a differentiator.

**4. Lead with the problem, not the solution.**
The parking lot story comes first. The feature list comes much later,
if at all. People fund and adopt solutions to problems they recognize,
not technology they admire.

**5. The technology should have one voice.**
The README, the demo site, the one-pager, and the 90-second pitch should
all use the same words for the same things. "Outreach worker" not "social
worker" or "field staff." "Shelter coordinator" not "shelter admin" or
"staff member." Consistency builds trust.

---

*Finding A Bed Tonight — Communications & Brand Recommendations*
*Simone Okafor · Brand Strategist & Communications Director*
*March 2026 · Volunteer engagement*
*"No more midnight phone calls."*
