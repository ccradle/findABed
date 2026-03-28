## Context

The walkthrough pages (`demo/index.html`, `dvindex.html`, `hmisindex.html`, `analyticsindex.html`) now have narrative captions telling a cohesive story through the personas of Darius (outreach worker) and Sandra (coordinator). But the screenshots show generic seed data that doesn't match the narrative. For example, the caption says "Three shelters have beds" but the FAMILY_WITH_CHILDREN search currently returns two shelters (Capital Boulevard Family Center and New Beginnings Family Shelter — plus DV shelter which is hidden from the outreach worker without dvAccess).

The seed data lives in two SQL files (`infra/scripts/seed-data.sql` and `demo-activity-seed.sql`), loaded during `dev-start.sh`. Screenshots are captured via 4 Playwright scripts. No application code changes are needed.

## Goals / Non-Goals

**Goals:**
- Every walkthrough caption matches what the screenshot shows
- Shelter names feel like a real Wake County network (warm, community-rooted)
- Bed counts, freshness timestamps, and constraint flags align precisely with narrative
- Analytics seed data produces the specific numbers referenced in captions (e.g., "47 zero-result searches")
- All 4 screenshot sets recaptured and committed

**Non-Goals:**
- Changing application code, API behavior, or database schema
- Changing the Playwright capture scripts beyond filter selections (no new screenshots)
- Changing the walkthrough HTML captions (the data aligns to the captions, not vice versa)
- Changing the user accounts or tenant configuration

## Decisions

### D1: Map captions to seed data requirements

Each caption makes a visual claim. The seed data must produce screenshots that satisfy these claims:

**Platform walkthrough (`demo/index.html`):**

| # | Caption claim | Seed data requirement |
|---|---|---|
| 2 | "filters by population type" — family of five | Capture script selects FAMILY_WITH_CHILDREN filter |
| 3 | "Three shelters have beds. Green badges" | Exactly 3 FAMILY_WITH_CHILDREN shelters with availability, all updated < 1 hour ago |
| 4 | "pets allowed, wheelchair accessible, updated 12 minutes ago" | The first result shelter has `pets_allowed=true`, `wheelchair_accessible=true`, snapshot ~12 min old |
| 5 | "holds the bed for 90 minutes" | Hold modal shows 90-minute countdown |
| 6 | Sandra sees "every shelter's occupancy" | Coordinator dashboard shows all assigned shelters with varied occupancy |
| 7 | "three taps — total, occupied, done" | Expanded shelter card with steppers visible |
| 8 | "Spanish-speaking families" | i18n switch works (no data change needed) |
| 14 | "Temperature drops below freezing" | Surge tab shows temperature context |

**DV walkthrough (`demo/dvindex.html`):**

| # | Caption claim | Seed data requirement |
|---|---|---|
| 1 | "a woman and her two children" | DV shelter has FAMILY_WITH_CHILDREN and DV_SURVIVOR beds available |
| 2 | "household size, urgency, special needs" | Referral form (no data change, UI-driven) |
| 4 | "can we serve this family tonight?" | DV coordinator sees pending referral with household data |

**Analytics walkthrough (`demo/analyticsindex.html`):**

| # | Caption claim | Seed data requirement |
|---|---|---|
| 1 | "utilization is at 78%, 47 bed searches returned zero results" | `demo-activity-seed.sql` must produce ~78% utilization and exactly 47 zero-result searches for the displayed period |
| 3 | "47 times last Tuesday night" | Zero-result search logs concentrated on a Tuesday |

**HMIS walkthrough (`demo/hmisindex.html`):** No specific numeric claims — current data works.

### D2: Add a third FAMILY_WITH_CHILDREN shelter

Currently only 2 non-DV shelters serve FAMILY_WITH_CHILDREN (Capital Blvd and New Beginnings). To show exactly 3 results, add FAMILY_WITH_CHILDREN as a secondary population type to one existing shelter, or add a new shelter. **Decision:** Add a new shelter "Crabtree Valley Family Haven" — keeps the Wake County feel and avoids complicating existing shelter constraint profiles.

**Alternative considered:** Make an existing shelter also serve families. Rejected because it would change that shelter's profile in other screenshots (admin detail, coordinator dashboard).

### D3: Shelter naming — warm, community-rooted

Rename shelters to feel more like real community organizations:
- Keep Raleigh/Wake County geographic references
- Use names that evoke care and community (not institutional)
- DV shelter name stays redacted in the UI (the seed name doesn't appear to outreach workers)

### D4: Freshness timestamp strategy

All FAMILY_WITH_CHILDREN snapshots must be `NOW() - INTERVAL '< 45 minutes'` to guarantee green freshness badges. The shelter Darius taps (screenshot 4) should be `NOW() - INTERVAL '12 minutes'` specifically.

### D5: Capture script changes — select FAMILY_WITH_CHILDREN filter

The capture script for screenshot 03 (search results) currently clicks "Search" without selecting a population filter. To show the family search, the script must:
1. Select FAMILY_WITH_CHILDREN from the population type dropdown
2. Click Search
3. Wait for results

This is a small change to `capture-screenshots.spec.ts` tests 02-04.

### D6: Analytics seed data — target specific numbers

Adjust `demo-activity-seed.sql` to produce:
- System utilization near 78% for the displayed period
- Exactly 47 zero-result searches in the prior week, concentrated on Tuesday evening
- Reservation conversion rate trending upward

This requires adjusting the occupancy baselines and search log generation parameters.

## Risks / Trade-offs

- **Risk:** Changing the population filter in capture scripts may break screenshot 04 (shelter detail) if the clicked shelter changes. → **Mitigation:** Pin the capture script to click a shelter by name, not position.
- **Risk:** Analytics numbers are generated by SQL with randomization — hitting exactly "47" may require tuning. → **Mitigation:** Use deterministic generation for zero-result searches (fixed count, not random range).
- **Risk:** Tests that rely on current seed data counts may break. → **Mitigation:** Run full test suite after seed data changes. Tests should use relative assertions (not hardcoded counts).
