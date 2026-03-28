## Why

The code repo README is 1,200+ lines serving four audiences simultaneously: developers, city officials, CoC administrators, and shelter operators. As evaluated through the Simone Okafor AI persona (Brand Strategist, defined in PERSONAS.md), this serves none of them well. Research into successful civic tech projects (CKAN, Open Path HMIS, GSA code-gov toolkit) confirms: effective READMEs are short routers (~200 lines) that link to audience-specific pages. A city official evaluating the platform shouldn't scroll past module boundaries and Flyway migrations to find the security posture. A shelter coordinator shouldn't see ArchUnit rules.

## What Changes

- Slim the code repo README from ~1,200 lines to ~200 lines (problem statement, quick start, project status, audience links)
- Move all technical content to `docs/FOR-DEVELOPERS.md`
- Create `docs/FOR-CITIES.md` — data ownership, WCAG, security posture, procurement path (draws from existing `government-adoption-guide.md`)
- Create `docs/FOR-COC-ADMINS.md` — HUD reporting, onboarding, DV protection, HMIS, deployment cost
- Create `docs/FOR-COORDINATORS.md` — plain-English guide for Sandra Kim and Reverend Monroe's volunteers
- Create `docs/FOR-FUNDERS.md` — story-first, theory of change, sustainability, what funding enables
- Add 90-second pitch briefs to docs repo as `docs/PITCH-BRIEFS.md`
- Lead both READMEs with the parking lot story and "No more midnight phone calls"

## Capabilities

### New Capabilities
- `audience-specific-docs`: Five audience-specific documentation pages with clear entry points from the README
- `readme-navigation-hub`: Slim README that routes each audience to their page within 10 seconds

### Modified Capabilities
- (none — existing capabilities unchanged, content is reorganized not rewritten)

## Impact

- **Code repo**: README.md restructured, 5 new docs/ files, existing technical content preserved in docs/FOR-DEVELOPERS.md
- **Docs repo**: README.md updated to match the story-first approach
- **No code changes, no tests to break** — pure documentation restructure
- **All existing links preserved** — content moves but anchors redirect
