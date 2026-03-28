## Overview

Redesign GitHub Pages site from a screenshot gallery to a story-first entry point. Create a printable outreach one-pager. All work in the docs repo `demo/` directory.

## Design Decisions

### Landing Page (`index.html` or new root page)

Structure:
1. **Hero**: Parking lot story (large text, 3 sentences) + "No more midnight phone calls"
2. **Problem in numbers**: shelters in Wake County, outreach workers, the gap
3. **Solution**: one paragraph, no jargon
4. **Who uses it**: 3 cards (Outreach Workers, Coordinators, Administrators) with one sentence each
5. **Call to action**: View the platform demo → Read the docs → Get in touch
6. **Demo walkthroughs**: links to existing screenshot galleries (with new contextual intros)

Design approach: clean, accessible, system fonts (matches the app's typography system), minimal color palette. Use the `frontend-design` skill for high-quality output.

### Demo Walkthrough Enhancement

Add a narrative sentence before each screenshot section:
- Before search: "An outreach worker searches for a bed at 11pm..."
- Before hold: "One tap holds the bed for 90 minutes — enough time to transport the client safely."
- Before coordinator: "Sandra updates her shelter's bed count in three taps between tasks."

### Outreach One-Pager (`demo/outreach-one-pager.html`)

Printable HTML page (A4/Letter, `@media print` styles):
- Title (6 words or fewer)
- Parking lot story (2 sentences)
- For outreach workers: 3 bullets
- For shelter coordinators: 3 bullets
- What it costs: 1 paragraph
- How to get started: 2-3 sentences
- Contact info

### City Landing Page (`demo/for-cities.html`)

Distilled version of `docs/FOR-CITIES.md` with story framing and contact link.

## File Changes

| File | Change |
|------|--------|
| `demo/index.html` | Redesign as story-first landing page (or create new root `index.html`) |
| `demo/index.html` (existing) | Rename to `demo/walkthrough.html` if landing page takes the root |
| New: `demo/outreach-one-pager.html` | Printable one-page outreach document |
| New: `demo/for-cities.html` | City/CoC adoption landing page |
| Existing walkthrough HTMLs | Add contextual narrative before screenshot sections |
