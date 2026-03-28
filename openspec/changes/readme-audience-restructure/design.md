## Overview

Restructure the 1,200-line code repo README into a ~200-line navigation hub with five audience-specific documentation pages. Content is reorganized, not rewritten — most material already exists.

## Design Decisions

### New README Structure (~200 lines)

```
# Finding A Bed Tonight

[Parking lot story — 3 sentences]
"No more midnight phone calls."

## What It Does [3 sentences]

## Who It's For
→ Outreach Workers & Coordinators — docs/FOR-COORDINATORS.md
→ CoC Administrators — docs/FOR-COC-ADMINS.md
→ City Officials & IT Departments — docs/FOR-CITIES.md
→ Developers & Contributors — docs/FOR-DEVELOPERS.md
→ Funders — docs/FOR-FUNDERS.md

## Quick Start [existing dev-start.sh, ~20 lines]

## Demo Walkthroughs [4 links to GitHub Pages]

## Project Status [current version, what's complete, what's next — 15 lines]

## Tech Stack [existing table, ~10 lines]

## License & Support [Apache 2.0, link to support-model.md]
```

### Content Migration Map

| Current README Section | Destination |
|---|---|
| Problem Statement & Business Value | Stays in README (condensed to 5 lines) |
| Guides & Policy Documents | README links to audience pages |
| Architecture, Module Boundaries, MCP-Ready | docs/FOR-DEVELOPERS.md |
| Database Schema, ERD, Documentation links | docs/FOR-DEVELOPERS.md |
| OpenSpec Workflow | docs/FOR-DEVELOPERS.md |
| Prerequisites, Starting the Stack, Manual Start | README Quick Start (condensed) + docs/FOR-DEVELOPERS.md (full) |
| UI Sanity Check, Running Tests | docs/FOR-DEVELOPERS.md |
| Observability, Grafana Dashboards | docs/FOR-DEVELOPERS.md |
| OAuth2 Single Sign-On | docs/FOR-DEVELOPERS.md (technical) + docs/FOR-CITIES.md (summary) |
| REST API Reference | docs/FOR-DEVELOPERS.md |
| Domain Glossary | docs/FOR-DEVELOPERS.md |
| Project Structure | docs/FOR-DEVELOPERS.md |
| Project Status | Stays in README (condensed) |
| Test Data Reset, Troubleshooting | docs/FOR-DEVELOPERS.md |
| Contributing, License | Stays in README |

### Audience Page Sources

| Page | Primary Source | Additional Sources |
|---|---|---|
| FOR-COORDINATORS.md | New content (plain English) | partial-participation-guide.md, what-does-free-mean.md |
| FOR-COC-ADMINS.md | New content | README Business Value, HMIS section, DV-OPAQUE-REFERRAL.md |
| FOR-CITIES.md | government-adoption-guide.md | WCAG-ACR.md, security posture from README, support-model.md |
| FOR-DEVELOPERS.md | Current README technical sections | Existing content, minimal rewriting |
| FOR-FUNDERS.md | theory-of-change.md, sustainability-narrative.md | Business Value section |

### Docs Repo README

Update to match story-first approach: parking lot story first, demo links, then OpenSpec workflow. Keep existing structure but lead with the human story, not CI badges.

## File Changes

| File | Change |
|---|---|
| `README.md` (code repo) | Restructure from ~1,200 to ~200 lines |
| New: `docs/FOR-DEVELOPERS.md` | All technical content from current README |
| New: `docs/FOR-CITIES.md` | City/government audience page |
| New: `docs/FOR-COC-ADMINS.md` | CoC administrator audience page |
| New: `docs/FOR-COORDINATORS.md` | Shelter coordinator/operator audience page |
| New: `docs/FOR-FUNDERS.md` | Funder/grantor audience page |
| `README.md` (docs repo) | Story-first lead, updated structure |
| New: `docs/PITCH-BRIEFS.md` (docs repo) | 90-second audience-specific pitch briefs |
