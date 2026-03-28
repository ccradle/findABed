## Tasks

### Setup

- [x] T-0: Create branch `feature/story-aligned-seed-data` in code repo (`finding-a-bed-tonight`)

### Seed Data — Shelters & Constraints

- [x] T-1: Add "Crabtree Valley Family Haven" shelter (FAMILY_WITH_CHILDREN, pets_allowed, wheelchair_accessible) to `seed-data.sql` — 3rd family shelter for "three shelters have beds" caption
- [x] T-2: Review shelter names — rename only if institutional-sounding; most are already warm (per design D3)
- [x] T-3: Tune bed availability snapshots to day-in-the-life timeline (design D1): Crabtree ~12 min, Capital Blvd ~10 min, New Beginnings ~7 min. All family shelters green badges.
- [x] T-4: Ensure DV shelter has both DV_SURVIVOR and FAMILY_WITH_CHILDREN beds available (supports DV walkthrough caption)
- [x] T-5: Assign Crabtree Valley to CoC Admin coordinator so it appears in coordinator dashboard
- [x] T-6: Assign admin user to DV shelter in coordinator_assignment (required for DV capture script coordinator views)

### Seed Data — Analytics

- [x] T-7: Adjust `demo-activity-seed.sql` occupancy baselines to produce ~78% system utilization for the displayed analytics period
- [x] T-8: Set zero-result search generation to produce exactly 47 zero-result searches in the prior week, concentrated on Tuesday evening (hours 18-23, deterministic not random)
- [x] T-9: Create upward utilization trend over 28 days (65% → 78% → 85%) so analytics trend chart shows "climbing steadily for two weeks"
- [x] T-10: Adjust reservation conversion rate to show upward trend in demand signals view

### Capture Script Changes

- [x] T-11: Update `capture-screenshots.spec.ts` test 02 (bed search) to select FAMILY_WITH_CHILDREN from population type dropdown before screenshot
- [x] T-12: Update test 03 (search results) to search with FAMILY_WITH_CHILDREN filter selected
- [x] T-13: Update test 04 (shelter detail) to click Crabtree Valley Family Haven by data-testid (not position)
- [x] T-14: Update test 05 (reservation hold) to hold a bed at the selected family shelter

### Walkthrough Restructuring (docs repo — demo/index.html)

- [x] T-15: Restructure `demo/index.html` — move bed search to position 1, login to admin section (design D5). Keep original screenshot filenames, change display order via HTML.
- [x] T-16: Split walkthrough into visual sections: "Darius's Night" (8 cards), "Behind the Scenes" (5 cards), "Operations" (2 cards)
- [x] T-17: Remove low-value admin screenshots (Add Shelter Form, Shelter Detail Admin, Create User, Observability) — don't advance the story. Reduced from 19 to 15.
- [x] T-18: Add trust/proof closing section: WCAG 2.1 AA (link to ACR), DV privacy (VAWA/FVPSA), Apache 2.0, deployment tiers
- [x] T-19: Add audience-specific CTAs: For Funders, For City Officials, For Developers + More Walkthroughs links
- [x] T-20: Update screenshot count badge (19 → 15)

### Person-First Language Audit

- [x] T-21: Grep both repos for non-person-first language (7 instances found across 4 files)
- [x] T-22: Fix all instances to person-first: "individuals/families experiencing homelessness"
- [x] T-23: Add "Language and Values" section to code repo README

### Cost Savings & Funder Documentation

- [x] T-24: Add cost savings to FOR-FUNDERS.md — $31,545 per person housed, sourced with link to NAEH Housing First resource page
- [x] T-25: Framed honestly — FABT reduces time-to-placement, not direct housing. Named basis ("over two years"), named limitation, linked original source

### Verification

- [x] T-26: Spin up stack with `dev-start.sh --fresh`, verify seed data (3 family shelters, green badges, pets+wheelchair on Crabtree, 79.3% utilization, 47 zeros on Tuesday)
- [x] T-27: Verify analytics dashboard shows ~78% utilization, upward trend, zero-result searches
- [x] T-28: Run full Playwright test suite — 127 passed, 0 failures
- [x] T-29: Run all 4 capture scripts (36 screenshots), visually verified against captions
- [x] T-30: Person-first language grep: zero non-person-first instances in committed files
- [x] T-31: Recaptured screenshots committed and pushed to docs repo
- [x] T-32: Backend 267 passed, Karate 26 passed, Gatling 0 KO (p50=29-61ms, p95=54-117ms)
- [x] T-33: CI green on all jobs
- [x] T-34: Merged to main via PR #17
