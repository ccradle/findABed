## Why

The GitHub Pages walkthrough captions tell a cohesive story — Darius searching for beds at 11 PM, Sandra updating counts between tasks, a family of five in a parking lot. But the screenshots show generic seed data that doesn't match. "Three shelters have beds" should show exactly three results. "Pets allowed, wheelchair accessible, updated 12 minutes ago" should match the shelter detail on screen. When narrative and visual evidence are in lockstep, every screenshot becomes proof, not illustration.

Research into nonprofit tech marketing, civic tech storytelling, and SaaS demo best practices (Code for America, Invisible People, Funders Together, industry demo frameworks) identified additional gaps and opportunities:

1. **The first screenshot is a login screen** — the single biggest anti-pattern in product demo walkthroughs. The login communicates nothing about value. The bed search should be the entry point.
2. **19 screenshots is too many for a single walkthrough.** Research consistently says 10 max for self-guided engagement. The walkthrough should split into a "core story" (Darius's night, ~8 screenshots) and an "admin deep dive."
3. **No trust/proof section at the end.** After the demo, there's no compliance callout, no deployment options, no call-to-action. Funders and government reviewers need a closing that builds confidence.
4. **Person-first language gaps.** "Homeless individuals" appears in documentation — should be "individuals experiencing homelessness" throughout. This is not style preference; it's the standard adopted by HUD, NAEH, and every major homelessness organization.
5. **No cost savings quantification.** Funders Together data shows $31K+ per person housed in emergency services savings. The README and funder docs don't cite this.
6. **Audience-specific CTAs missing.** The walkthrough ends the same way for everyone. A funder needs "Read the theory of change." A city official needs "Review the government adoption guide." An implementer needs "Read the developer docs."
7. **DV shelter not assigned to admin for capture.** The DV capture script uses adminPage as coordinator, but admin isn't in coordinator_assignment for the DV shelter.

## What Changes

### Seed Data (code repo)
- Rewrite `infra/scripts/seed-data.sql` shelter names, constraints, and bed counts to align with walkthrough captions across all 4 demo pages
- Add 3rd FAMILY_WITH_CHILDREN shelter for "three shelters have beds" caption
- Tune initial availability snapshots so filtered searches return exact results described in captions
- Ensure freshness timestamps produce green badges during capture
- Assign admin to DV shelter for DV capture script
- Adjust `demo-activity-seed.sql` occupancy baselines to match analytics narrative (78% utilization, 47 zero-result searches, upward trend)

### Walkthrough Restructuring (docs repo)
- Restructure `demo/index.html` — move login out of position 1, lead with bed search
- Split into "Core Story" (Darius's night, ~8 screenshots) and "Administration & Operations" sections with clear visual separation
- Add trust/proof closing section (WCAG, VAWA design alignment, Apache 2.0, deployment tiers)
- Add audience-specific CTAs at the end (funder / city official / implementer paths)

### Language & Documentation (both repos)
- Person-first language audit across all docs — replace "homeless individuals" with "individuals/families experiencing homelessness"
- Add cost savings quantification to FOR-FUNDERS.md citing Funders Together data
- Add "Language and Values" section to documentation signaling dignity-centered design

### Capture Scripts (code repo)
- Update capture scripts for FAMILY_WITH_CHILDREN filter selection
- Click shelters by name, not position
- Recapture all screenshots across all 4 walkthrough sets

## Capabilities

### New Capabilities
- `walkthrough-structure`: Restructured demo walkthrough with core story / admin split, trust section, audience CTAs

### Modified Capabilities
- `story-landing-page`: REQ-STORY-4 (narrative sentences) enhanced with walkthrough restructuring
- `demo-seed-data`: New capability tracking seed data narrative alignment

## Impact

- `finding-a-bed-tonight/infra/scripts/seed-data.sql` — shelter names, constraints, bed counts, coordinator assignments
- `finding-a-bed-tonight/infra/scripts/demo-activity-seed.sql` — occupancy baselines, search patterns, utilization trend
- `finding-a-bed-tonight/e2e/playwright/tests/capture-*.spec.ts` — filter selections, click by name
- `findABed/demo/index.html` — walkthrough restructuring, trust section, audience CTAs
- `findABed/demo/dvindex.html`, `hmisindex.html`, `analyticsindex.html` — minor caption adjustments if needed
- `finding-a-bed-tonight/docs/FOR-FUNDERS.md` — cost savings quantification
- `finding-a-bed-tonight/README.md`, `docs/*.md` — person-first language audit
- `findABed/demo/screenshots/` — all recaptured PNGs
- No API, schema, or application code changes
