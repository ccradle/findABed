## Context

The walkthrough pages now have narrative captions telling a cohesive story through the personas of Darius (outreach worker) and Sandra (coordinator). But the screenshots show generic seed data, the walkthrough leads with a login screen, and the demo is 19 screenshots long with no trust section or audience-specific calls to action. Research into nonprofit tech marketing (Code for America, Funders Together, Invisible People, SaaS demo frameworks) identified structural improvements alongside the seed data alignment.

## Goals / Non-Goals

**Goals:**
- Every walkthrough caption matches what the screenshot shows
- Walkthrough restructured: core story first, admin deep dive second, trust section at end
- Shelter names feel like a real Wake County network (warm, community-rooted)
- Bed counts, freshness timestamps, and constraint flags align precisely with narrative
- Analytics seed data produces the specific numbers referenced in captions
- Person-first language throughout all documentation
- Cost savings quantified for funder audiences
- All 4 screenshot sets recaptured and committed

**Non-Goals:**
- Changing application code, API behavior, or database schema
- Creating a formal VPAT (separate future change — higher priority than dark mode)
- Implementing dark mode in the application (separate change: color-system-dark-mode)
- Changing the walkthrough page visual design or CSS (structure only)

## Decisions

### D1: Day-in-the-life timeline as seed data backbone

Research confirms "day in the life" scenarios are the gold standard for demo narratives. Every seed data timestamp maps to Darius's night:

| Time | Event | Seed data implication |
|---|---|---|
| 6:00 PM | Sandra updates bed counts after evening intake | Sandra's shelters have snapshots at `NOW() - INTERVAL '5 hours'` |
| 10:45 PM | Sandra does a final update before shift change | Sandra's shelter snapshot at `NOW() - INTERVAL '30 minutes'` |
| 11:00 PM | Crabtree Valley coordinator updates | Crabtree snapshot at `NOW() - INTERVAL '12 minutes'` (matches caption 4) |
| 11:02 PM | Capital Blvd coordinator updates | Capital Blvd snapshot at `NOW() - INTERVAL '10 minutes'` |
| 11:05 PM | New Beginnings coordinator updates | New Beginnings snapshot at `NOW() - INTERVAL '7 minutes'` |
| 11:14 PM | Darius searches for FAMILY_WITH_CHILDREN beds | 3 results, all green badges |
| 11:15 PM | Darius holds a bed at Crabtree Valley | Hold modal shows 90-minute countdown |

This creates a coherent temporal narrative — the data tells the story of a real evening.

### D2: Add a third FAMILY_WITH_CHILDREN shelter

Currently only 2 non-DV shelters serve FAMILY_WITH_CHILDREN (Capital Blvd and New Beginnings). **Decision:** Add "Crabtree Valley Family Haven" — keeps the Wake County feel, pets_allowed=true, wheelchair_accessible=true (matches caption 4: "pets allowed, wheelchair accessible, updated 12 minutes ago").

**Alternative considered:** Make an existing shelter also serve families. Rejected because it would change that shelter's profile in other screenshots.

### D3: Shelter naming — warm, community-rooted

Research says "name every entity with narrative intent — each name should tell the audience something about what the shelter does." Current names are already mostly warm. Minimal changes:

| Current | Keep/Rename | Rationale |
|---|---|---|
| Oak City Emergency Shelter | Keep | Already evokes community |
| Capital Boulevard Family Center | Keep | Warm, family-focused |
| South Wilmington Haven | Keep | Warm |
| Wake County Veterans Shelter | Keep | Clear purpose |
| Youth Hope Center | Keep | Warm |
| Women of Hope Shelter | Keep | Warm |
| Helping Hand Recovery Center | Keep | Warm |
| New Beginnings Family Shelter | Keep | Warm |
| Safe Haven DV Shelter | Keep | Name is redacted in UI anyway |
| Downtown Warming Station | Keep | Evokes emergency purpose |
| NEW: Crabtree Valley Family Haven | Add | Geographic + purpose |

Most names are already strong. No unnecessary renames.

### D4: Freshness timestamp strategy

All FAMILY_WITH_CHILDREN snapshots must produce green freshness badges (< 1 hour old). Specific timestamps per D1 timeline:
- Crabtree Valley: `NOW() - INTERVAL '12 minutes'` (caption 4)
- Capital Blvd: `NOW() - INTERVAL '10 minutes'`
- New Beginnings: `NOW() - INTERVAL '7 minutes'`

Other shelters keep varied timestamps for visual interest on coordinator dashboard.

### D5: Walkthrough restructuring — core story first

Research: "The first screenshot is a login screen — the single biggest anti-pattern." And: "Keep it to 10 steps max for self-guided walkthroughs."

**New structure for `demo/index.html`:**

**Part 1: "Darius's Night" (core story, screenshots 1-8)**
1. Bed Search (was #2) — "He has a family of five and 30 minutes"
2. Search Results (was #3) — "Three shelters have beds"
3. Shelter Detail (was #4) — "pets allowed, wheelchair accessible"
4. Reservation Hold (was #5) — "One tap holds the bed for 90 minutes"
5. Coordinator Dashboard (was #6) — "Sandra checks her dashboard"
6. Bed Count Update (was #7) — "Sandra updates in three taps"
7. Spanish Language (was #8) — "Spanish-speaking families"
8. Change Password (was #17) — "If his phone is lost"

**Part 2: "Behind the Scenes" (administration, screenshots 9-15)**
9. Login (was #1) — moved here, reframed as "secure access"
10. User Management (was #9)
11. Create User Form (was #10)
12. Shelter Management (was #11)
13. Surge Mode (was #14)
14. Observability Settings (was #15)
15. OAuth2 Providers (was #16)

**Part 3: "Operations" (optional, screenshots 16-17)**
16. Grafana Dashboard (was #18)
17. Jaeger Traces (was #19)

**Removed from main walkthrough:** Add Shelter Form (#12), Shelter Detail Admin (#13) — these are admin detail views that don't advance the story. Move to admin deep dive or remove.

**Part 4: "Trust" (closing section, no screenshots)**
- WCAG 2.1 AA compliance statement with link to ACR
- DV privacy design alignment (VAWA/FVPSA)
- Apache 2.0 license — free forever
- Deployment tiers (Lite/Standard/Full)
- Audience-specific CTAs

### D6: Audience-specific CTAs

Three paths at the end of the walkthrough:
- **For Funders:** "Read the Theory of Change" → link to FOR-FUNDERS.md
- **For City Officials:** "Review the Government Adoption Guide" → link to for-cities.html
- **For Implementers:** "Read the Developer Docs" → link to FOR-DEVELOPERS.md

### D7: Capture script changes — select FAMILY_WITH_CHILDREN filter

The capture script for screenshots 02-04 must:
1. Select FAMILY_WITH_CHILDREN from the population type dropdown
2. Click Search
3. Click Crabtree Valley Family Haven by name (not position)

Pin to name using `data-testid` or text locator for reliability.

### D8: Analytics seed data — target specific numbers

Adjust `demo-activity-seed.sql` to produce:
- System utilization near 78% for the displayed period
- Exactly 47 zero-result searches in the prior week, concentrated on Tuesday evening (hours 18-23)
- Upward utilization trend over 28 days (65% → 78% → 85%)
- Reservation conversion rate trending upward

Use deterministic generation for the 47 zero-result searches (fixed count, not random range).

### D9: Person-first language audit

Research (Invisible People, NAEH, HUD guidance): Always use "people/person/family experiencing homelessness" — never "the homeless" or "homeless person/individuals."

Scan all `.md` files in both repos for:
- "homeless individuals" → "individuals experiencing homelessness"
- "homeless families" → "families experiencing homelessness"
- "the homeless" → "people experiencing homelessness"
- "homeless person" → "person experiencing homelessness"

### D10: Cost savings quantification

Funders Together to End Homelessness data: average cost savings of $31,545 per person housed (emergency services). Add to FOR-FUNDERS.md:

> "Research from Funders Together to End Homelessness shows average emergency services cost savings of $31,545 per person housed. While Finding A Bed Tonight does not directly house people, it is designed to reduce the time from crisis to shelter placement — the critical first step in the housing pathway."

Honest, specific, defensible — names the source, names the limitation.

### D11: DV shelter coordinator assignment

The DV capture script uses adminPage for coordinator screening views. Admin (b0000000-0000-0000-0000-000000000001) is not in coordinator_assignment for the DV shelter. Add the assignment so DV screenshots render correctly.

## Risks / Trade-offs

- **Risk:** Walkthrough restructuring changes screenshot numbers referenced elsewhere. → **Mitigation:** Update sitemap.xml, OG tags, and any cross-references.
- **Risk:** Renumbering screenshots breaks external links to specific images. → **Mitigation:** Keep original filenames (01-login.png etc.) even though the display order changes. The HTML `<img src>` references can point to any filename regardless of display order.
- **Risk:** Person-first language audit may miss instances. → **Mitigation:** Use grep across both repos, verify with manual review.
- **Risk:** Tests that rely on current seed data counts may break. → **Mitigation:** Run full test suite after seed data changes.
- **Risk:** Analytics numbers are generated by SQL with randomization — hitting exactly "47" may require tuning. → **Mitigation:** Use deterministic generation for zero-result searches (fixed count, not random range).
