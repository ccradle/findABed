## Tasks

### Setup

- [ ] T-0: Create branch `feature/story-aligned-seed-data` in code repo (`finding-a-bed-tonight`)

### Seed Data — Shelters & Constraints

- [ ] T-1: Add "Crabtree Valley Family Haven" shelter (FAMILY_WITH_CHILDREN, pets_allowed, wheelchair_accessible) to `seed-data.sql` — 3rd family shelter for "three shelters have beds" caption
- [ ] T-2: Review shelter names — rename only if institutional-sounding; most are already warm (per design D3)
- [ ] T-3: Tune bed availability snapshots to day-in-the-life timeline (design D1): Crabtree ~12 min, Capital Blvd ~10 min, New Beginnings ~7 min. All family shelters green badges.
- [ ] T-4: Ensure DV shelter has both DV_SURVIVOR and FAMILY_WITH_CHILDREN beds available (supports DV walkthrough caption)
- [ ] T-5: Assign Crabtree Valley to CoC Admin coordinator so it appears in coordinator dashboard
- [ ] T-6: Assign admin user to DV shelter in coordinator_assignment (required for DV capture script coordinator views)

### Seed Data — Analytics

- [ ] T-7: Adjust `demo-activity-seed.sql` occupancy baselines to produce ~78% system utilization for the displayed analytics period
- [ ] T-8: Set zero-result search generation to produce exactly 47 zero-result searches in the prior week, concentrated on Tuesday evening (hours 18-23, deterministic not random)
- [ ] T-9: Create upward utilization trend over 28 days (65% → 78% → 85%) so analytics trend chart shows "climbing steadily for two weeks"
- [ ] T-10: Adjust reservation conversion rate to show upward trend in demand signals view

### Capture Script Changes

- [ ] T-11: Update `capture-screenshots.spec.ts` test 02 (bed search) to select FAMILY_WITH_CHILDREN from population type dropdown before screenshot
- [ ] T-12: Update test 03 (search results) to search with FAMILY_WITH_CHILDREN filter selected
- [ ] T-13: Update test 04 (shelter detail) to click Crabtree Valley Family Haven by name (not position)
- [ ] T-14: Update test 05 (reservation hold) to hold a bed at the selected family shelter

### Walkthrough Restructuring (docs repo — demo/index.html)

- [ ] T-15: Restructure `demo/index.html` — move bed search to position 1, login to admin section (design D5). Keep original screenshot filenames, change display order via HTML.
- [ ] T-16: Split walkthrough into visual sections: "Darius's Night" (core story, ~8 cards), "Behind the Scenes" (admin, ~7 cards), "Operations" (observability, 2 cards)
- [ ] T-17: Remove or relocate low-value admin screenshots (Add Shelter Form #12, Shelter Detail Admin #13) — they don't advance the story
- [ ] T-18: Add trust/proof closing section after last screenshot: WCAG 2.1 AA (link to ACR), DV privacy design (VAWA/FVPSA), Apache 2.0 license, deployment tiers (Lite/Standard/Full)
- [ ] T-19: Add audience-specific CTAs at end: "For Funders" → FOR-FUNDERS.md, "For City Officials" → for-cities.html, "For Implementers" → FOR-DEVELOPERS.md
- [ ] T-20: Update screenshot count badge to reflect new count after restructuring

### Person-First Language Audit

- [ ] T-21: Grep both repos for non-person-first language: "homeless individuals", "homeless families", "the homeless", "homeless person" (case-insensitive)
- [ ] T-22: Fix all instances to person-first: "individuals/families/people experiencing homelessness"
- [ ] T-23: Add "Language and Values" note to code repo README or a dedicated section explaining dignity-centered language commitment

### Cost Savings & Funder Documentation

- [ ] T-24: Add cost savings quantification to `docs/FOR-FUNDERS.md` citing Funders Together data ($31K+ per person housed)
- [ ] T-25: Frame cost savings honestly — FABT reduces time-to-placement, not a direct housing intervention. Name the basis, name the limitation.

### Verification

- [ ] T-26: Spin up stack with `dev-start.sh`, verify seed data produces correct search results (3 family shelters, green badges, correct constraints)
- [ ] T-27: Verify analytics dashboard shows ~78% utilization, 47 zero-result searches, upward trend
- [ ] T-28: Run full Playwright test suite (`npx playwright test`) — verify no existing tests break with new seed data
- [ ] T-29: Run all 4 capture scripts, visually verify each screenshot matches its caption
- [ ] T-30: Verify person-first language: grep confirms zero non-person-first instances in committed files
- [ ] T-31: Copy recaptured screenshots to `findABed/demo/screenshots/`, commit to both repos
- [ ] T-32: Run full backend test suite (mvn test) — verify seed data changes don't break integration tests
- [ ] T-33: CI green on all jobs
- [ ] T-34: Merge to main, tag
