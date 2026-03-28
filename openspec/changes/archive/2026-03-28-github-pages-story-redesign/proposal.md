## Why

The GitHub Pages site (ccradle.github.io/findABed) currently serves as a screenshot gallery — technically thorough but story-free. As evaluated through the Simone Okafor AI persona (Brand Strategist, defined in PERSONAS.md), a city official arriving cold sees "Coordinator Dashboard" before understanding what a coordinator does or why that dashboard matters. The site needs a story-first landing page that makes the person in crisis visible before the technology becomes visible. Additionally, Maria Torres (AI persona, Product Manager) needs a printable one-page outreach document for her first conversation with shelter partners — this doesn't exist yet.

## What Changes

- Redesign `index.html` on GitHub Pages as a story-first landing page: parking lot story, problem in numbers, solution summary, audience cards routing to appropriate pages
- Add contextual narrative before each screenshot in the demo walkthroughs — "An outreach worker searches for a bed at 11pm" before the search screenshot
- Create a printable one-page outreach document (`outreach-one-pager.html`) — story-first, not feature-first, for the first conversation with shelter partners
- Add a city/CoC adoption landing page (`for-cities.html`) with contact info

## Capabilities

### New Capabilities
- `story-landing-page`: GitHub Pages index.html as a story-first entry point with audience routing
- `outreach-one-pager`: Printable one-page HTML document for first outreach conversations

### Modified Capabilities
- (none)

## Impact

- **Docs repo only** — all changes in `demo/` directory served by GitHub Pages
- **No code repo changes, no tests to break**
- **Uses `frontend-design` skill** for the landing page and one-pager design
