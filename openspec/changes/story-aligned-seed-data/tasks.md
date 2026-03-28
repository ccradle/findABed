## Tasks

### Setup

- [ ] T-0: Create branch `feature/story-aligned-seed-data` in code repo (`finding-a-bed-tonight`)

### Seed Data — Shelters & Constraints

- [ ] T-1: Add "Crabtree Valley Family Haven" shelter (FAMILY_WITH_CHILDREN, pets_allowed, wheelchair_accessible) to `seed-data.sql` — 3rd family shelter needed for "three shelters have beds" caption
- [ ] T-2: Rename shelters to warm, community-rooted Wake County names (keep addresses/coordinates, update names only)
- [ ] T-3: Tune bed availability snapshots: all 3 family shelters updated < 45 min ago (green badges), the first result (Crabtree Valley) updated ~12 min ago with pets+wheelchair matching caption 4
- [ ] T-4: Ensure DV shelter has both DV_SURVIVOR and FAMILY_WITH_CHILDREN beds available (supports DV walkthrough caption "a woman and her two children")
- [ ] T-5: Assign new shelter to CoC Admin coordinator so it appears in coordinator dashboard

### Seed Data — Analytics

- [ ] T-6: Adjust `demo-activity-seed.sql` occupancy baselines to produce ~78% system utilization for the displayed analytics period
- [ ] T-7: Set zero-result search generation to produce exactly 47 zero-result searches in the prior week, concentrated on Tuesday evening
- [ ] T-8: Adjust reservation conversion rate to show upward trend in demand signals view

### Capture Script Changes

- [ ] T-9: Update `capture-screenshots.spec.ts` test 02 (bed search) to select FAMILY_WITH_CHILDREN from population type dropdown before screenshot
- [ ] T-10: Update test 03 (search results) to search with FAMILY_WITH_CHILDREN filter selected
- [ ] T-11: Update test 04 (shelter detail) to click shelter by name (not position) — click the shelter with pets+wheelchair that matches caption 4
- [ ] T-12: Update test 05 (reservation hold) to hold a bed at the selected family shelter

### Verification

- [ ] T-13: Spin up stack with `dev-start.sh`, verify seed data produces correct search results (3 family shelters, green badges, correct constraints)
- [ ] T-14: Run full Playwright test suite (`npx playwright test`) to verify no existing tests break with new seed data
- [ ] T-15: Run all 4 capture scripts, visually verify each screenshot matches its caption
- [ ] T-16: Copy recaptured screenshots to `findABed/demo/screenshots/`, commit to both repos
