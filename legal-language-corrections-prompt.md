# Legal Language Corrections — Finding A Bed Tonight

**Author:** Legal Review (Casey Drummond)
**Date:** March 2026
**Purpose:** Pre-change prompt for Claude Code — correct legal language in public-facing
documents before first outreach conversations with DV shelter operators, city officials,
or the general public.
**Repos:** `ccradle/finding-a-bed-tonight` (code) · `ccradle/findABed` (docs)

---

## How to Use This Document

This document is a pre-`/opsx:new` prompt. Paste it into Claude Code, then run:

```
/opsx:new legal-language-corrections
```

Each correction below identifies the exact file, the problem language, and the
recommended replacement. All changes are additive or substitutive — no features
are removed, no architecture is changed. This is documentation and framing only.

Implementation is straightforward text editing. `/opsx:ff` should produce a
proposal, design, and task list of approximately 8–10 tasks. `/opsx:apply`
should be a single session.

---

## Context for Claude Code

We are doing spec-driven development using OpenSpec conventions.
Your job is to create and populate markdown specification files only.
Do not write implementation code.
You are working with a senior Java engineer named Corey Cradle.
Active repo: finding-a-bed-tonight (code) and findABed (docs)
Account: ccradle

This change makes targeted legal language corrections to public-facing documents
identified in a legal review. No functional changes. No architecture changes.
Documentation and public-facing text only.

---

## Correction 1 — DV Demo Page: Compliance Claim

**File:** `findABed/demo/dvindex.html`

**Location:** Opening tagline / subtitle area, visible at the top of the page

**Problem language:**
```
VAWA/FVPSA compliant. Human-in-the-loop safety screening.
```

**Why it's a problem:**
This is a bare compliance claim on a public-facing webpage. A DV shelter operator
reading this may treat it as a legal guarantee. VAWA has state-level implementation
variations — what satisfies the federal baseline may not satisfy all jurisdictions.
If a shelter deploys FABT relying on this claim and their state has stricter
requirements, the project has created legal exposure without providing legal
assurance it can actually give.

**Recommended replacement:**
```
Designed to support VAWA/FVPSA compliance requirements. Human-in-the-loop
safety screening. DV shelter operators should consult qualified legal counsel
regarding their specific compliance obligations.
```

**Notes for implementation:**
- Keep the same visual styling/placement as the existing tagline
- The qualifying sentence may be styled smaller or as a secondary line
  if that fits the layout better — the important thing is that it is visible
  and not hidden in fine print

---

## Correction 2 — DV Demo Page: Footer Disclaimer

**File:** `findABed/demo/dvindex.html`

**Location:** Footer of the page (alongside or below the existing
"Finding A Bed Tonight — DV Opaque Referral" footer line)

**Problem language:**
No disclaimer exists. The page has no warning that data may be inaccurate
or that this is not legal advice.

**Recommended addition:**
```
Finding A Bed Tonight is provided as-is under the Apache 2.0 License,
without warranty of any kind. This documentation does not constitute legal
advice. Organizations deploying FABT for DV referrals should consult
qualified legal counsel regarding applicable federal, state, and local
confidentiality requirements.
```

**Notes for implementation:**
- Style consistently with the existing footer text
- Place below or alongside the existing footer line, not above it

---

## Correction 3 — Main Demo Page: Footer Disclaimer

**File:** `findABed/demo/index.html`

**Location:** Footer of the page (alongside or below the existing
"Finding A Bed Tonight — Open-source shelter bed availability platform" footer line)

**Problem language:**
No disclaimer exists. The page has no warning that availability data may be
inaccurate or that the platform carries no warranty.

**Recommended addition:**
```
Finding A Bed Tonight is provided as-is under the Apache 2.0 License, without
warranty of any kind. Availability data is supplied by shelter operators and
may not reflect current conditions. This platform is not a guarantee of shelter
availability.
```

**Notes for implementation:**
- Style consistently with the existing footer text
- Same treatment as Correction 2 — placed below the existing footer line

---

## Correction 4 — DV-OPAQUE-REFERRAL.md: Missing Disclaimer Paragraph

**File:** `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`

**Location:** Immediately after the `## Purpose` section heading and its
existing paragraph, before the `## Legal Basis` section heading

**Problem language:**
No disclaimer exists. The document opens with a description of its purpose
and goes directly into a federal law compliance table. A DV shelter that
relied on this document as legal assurance — rather than as a technical
reference — could argue they were given legal advice.

**Recommended addition (insert as new section between Purpose and Legal Basis):**

```markdown
## Important Notice

This document describes the architectural and operational design of FABT's
DV referral feature as it relates to applicable federal and state
confidentiality requirements. It is intended as a technical reference for
evaluation purposes only.

**This document does not constitute legal advice.** Organizations deploying
FABT for domestic violence shelter referrals should consult qualified legal
counsel regarding their specific compliance obligations under applicable
federal, state, and local law. Confidentiality requirements vary by
jurisdiction and may be more stringent than the federal baseline described
here. The legal citations and statutory summaries in this document reflect
the authors' understanding at the time of writing and should be independently
verified before reliance.
```

**Notes for implementation:**
- Insert as a new `## Important Notice` section
- The bold sentence "This document does not constitute legal advice." is
  important — do not style it away
- Do not modify the existing Purpose section or Legal Basis section

---

## Correction 5 — DV-OPAQUE-REFERRAL.md: Consent Gap Explanation

**File:** `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`

**Location:** In the `## VAWA Compliance Checklist` section, after the
checklist item that reads:
`Consent is obtained verbally during the warm handoff call, not through FABT`

**Problem language:**
The checklist asserts that verbal consent during the warm handoff is the
correct approach but does not explain *why* it satisfies VAWA's consent
requirements. An auditor or city attorney reading this needs to understand
the legal reasoning, not just the design decision.

**Recommended addition (insert as an indented note or paragraph
immediately after that checklist item):**

```markdown
  > **Why verbal consent at warm handoff satisfies VAWA:** VAWA's written
  > consent requirements apply to disclosures of victim information to
  > outside entities. The FABT warm handoff is not such a disclosure —
  > the shelter's intake phone number is shared with the outreach worker
  > who is actively facilitating the client's placement, not forwarded to
  > a third party. The outreach worker then calls the shelter directly,
  > equivalent to the worker calling the shelter without any platform
  > intermediary. No survivor-identifying information is shared in either
  > direction through the FABT system. Consent for shelter placement is
  > obtained by the outreach worker and shelter staff during the warm
  > handoff call itself, consistent with standard coordinated entry
  > practice. Organizations with specific consent policy requirements
  > should consult their VAWA administrator or legal counsel.
```

**Notes for implementation:**
- Use blockquote (`>`) formatting or an indented note style —
  the goal is to visually associate this explanation with the
  checklist item above it
- Do not modify other checklist items

---

## Correction 6 — DV-OPAQUE-REFERRAL.md: Free-Text PII Risk Note

**File:** `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`

**Location:** In the `## What FABT Stores vs. What It Never Stores` section,
in the row for "Special needs (free text — wheelchair, pets, medical)"
OR as a note below the table

**Problem language:**
The table lists "Special needs (free text)" as stored data. Free-text fields
are a PII risk because coordinators or outreach workers may inadvertently type
identifying information (a client name, a specific medical condition, something
that could identify the individual). The document acknowledges the advisory
label shown to shelter staff, but does not document what technical controls
exist on this field or honestly note the residual risk.

**Recommended addition (insert as a note below the table, before the
"Even if the database is compromised" paragraph):**

```markdown
> **Free-text field risk note:** The "Special needs" field accepts free text.
> While the UI displays an advisory — "Do not include client identifying
> information" — no automated scrubbing or validation prevents a coordinator
> from typing PII into this field. CoC administrators should include this
> field in staff training: only operational descriptors (e.g., "wheelchair,"
> "service dog," "requires ground floor") should be entered. FABT does not
> guarantee that this field is PII-free at the time of token purge. The
> 24-hour hard deletion mitigates the exposure window, but does not
> eliminate the risk entirely if PII is entered contrary to the advisory.
```

**Notes for implementation:**
- Use blockquote formatting for visual distinction from the table
- Place this note directly below the stored/not-stored table
- Do not modify the table itself

---

## Correction 7 — Project Documentation Site: Disclaimer Footer

**File:** `findABed/` — the GitHub Pages site (`ccradle.github.io/findABed/`)

**Location:** The main `README.md` or the Jekyll/static site layout that
generates the GitHub Pages site — wherever the global footer or page
bottom content is controlled

**Problem language:**
The main docs site (`ccradle.github.io/findABed/`) has no disclaimer.
A city official reading the site has no visible indication of the
as-is warranty posture.

**Recommended addition (in the License section at the bottom of README.md,
after the Apache 2.0 license link):**

```markdown
> Finding A Bed Tonight is provided as-is, without warranty of any kind.
> Availability data is supplied by shelter operators and may not reflect
> current conditions. This platform is not a guarantee of shelter
> availability. See the [Apache 2.0 License](LICENSE) for full warranty
> disclaimer and limitation of liability terms.
```

**Notes for implementation:**
- The Apache 2.0 license already contains a full warranty disclaimer —
  this note simply makes it visible on the public page rather than
  buried in the LICENSE file
- Blockquote formatting (`>`) keeps it visually distinct from
  the surrounding content without requiring a new section heading

---

## What This Change Does NOT Address

The following items are identified for future OpenSpec changes — they are
out of scope for this correction change because they require new document
creation rather than text corrections:

| Item | Future Change |
|---|---|
| Privacy policy document | `legal-privacy-policy` |
| Government adoption legal guide (addendum to city playbook) | `legal-government-adoption-guide` |
| Developer Certificate of Origin (DCO) in CONTRIBUTING.md | `legal-contributor-dco` |

These three items should be specced after this correction change is
archived. They are not blocking for initial outreach conversations with
outreach workers, but should be in place before formal conversations
with city attorneys or CoC legal staff.

---

## Summary of Files Changed

| File | Repo | Change |
|---|---|---|
| `demo/dvindex.html` | `findABed` | Qualify compliance claim (Correction 1) |
| `demo/dvindex.html` | `findABed` | Add disclaimer footer (Correction 2) |
| `demo/index.html` | `findABed` | Add disclaimer footer (Correction 3) |
| `docs/DV-OPAQUE-REFERRAL.md` | `finding-a-bed-tonight` | Add disclaimer section (Correction 4) |
| `docs/DV-OPAQUE-REFERRAL.md` | `finding-a-bed-tonight` | Add consent explanation (Correction 5) |
| `docs/DV-OPAQUE-REFERRAL.md` | `finding-a-bed-tonight` | Add free-text risk note (Correction 6) |
| `README.md` | `findABed` | Add disclaimer to License section (Correction 7) |

**Total files:** 4 files across 2 repos
**Estimated implementation time:** 1 Claude Code session, under 30 minutes
**Blocking:** YES — items 1–4 should be applied before any outreach
conversation with DV shelter operators or city officials

---

*Finding A Bed Tonight — Legal Review*
*Casey Drummond*
*Pre-`/opsx:new legal-language-corrections` prompt*
