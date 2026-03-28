## Why

The GitHub Pages walkthrough captions now tell a cohesive story — Darius searching for beds at 11 PM, Sandra updating counts between tasks, a family of five in a parking lot. But the screenshots show generic seed data that doesn't match. "Three shelters have beds" should show exactly three results. "Pets allowed, wheelchair accessible, updated 12 minutes ago" should match the shelter detail on screen. When narrative and visual evidence are in lockstep, every screenshot becomes proof, not illustration.

## What Changes

- Rewrite `infra/scripts/seed-data.sql` shelter names, constraints, and bed counts to align with walkthrough captions across all 4 demo pages (platform, DV referral, HMIS bridge, analytics)
- Tune initial availability snapshots so filtered searches return the exact number of results described in captions
- Ensure freshness timestamps produce green badges during capture
- Adjust `demo-activity-seed.sql` occupancy baselines if needed to match analytics narrative (utilization climbing, 47 zero-result searches)
- Update Playwright capture scripts if any need specific filter selections to photograph the right state
- Recapture all screenshots across all 4 walkthrough sets
- No application code changes — seed data only

## Capabilities

### New Capabilities

_(None — this is a data and screenshot change, not a feature.)_

### Modified Capabilities

_(No spec-level behavior changes.)_

## Impact

- `finding-a-bed-tonight/infra/scripts/seed-data.sql` — shelter names, constraints, bed counts
- `finding-a-bed-tonight/infra/scripts/demo-activity-seed.sql` — occupancy baselines, search patterns
- `finding-a-bed-tonight/e2e/playwright/tests/capture-*.spec.ts` — filter selections if needed
- `findABed/demo/screenshots/` — all recaptured PNGs
- No API, schema, or application code changes
