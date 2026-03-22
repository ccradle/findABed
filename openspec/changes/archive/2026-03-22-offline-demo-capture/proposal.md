## Why

The platform has no demo site online yet. Stakeholders, potential adopter cities, and contributors need to see the application without running the full stack locally. A set of automated Playwright-captured screenshots wrapped in a browsable HTML walkthrough provides an offline demo that can be shared via the docs repo, opened in any browser, and regenerated on demand as the UI evolves.

## What Changes

- **Playwright capture script**: Automated script navigates every key view (login, search, results, reservations, coordinator dashboard, admin tabs including Observability, Grafana dashboard, Jaeger traces) and captures full-page screenshots
- **HTML walkthrough**: Static `index.html` with navigation, captions, and responsive image display — opens offline in any browser
- **Capture automation**: Shell script (`demo/capture.sh`) runs the Playwright capture against a running stack and regenerates all screenshots
- **Docs repo integration**: `demo/` folder committed to the findABed docs repo with `.gitignore` for regenerable screenshots (or committed directly for offline sharing)

## Capabilities

### New Capabilities
- `demo-capture`: Automated Playwright screenshot capture and static HTML walkthrough generation

### Modified Capabilities
(none)

## Impact

- **New directory**: `demo/` in the findABed docs repo root
- **New files**: `demo/index.html`, `demo/capture.sh`, `demo/capture-screenshots.spec.ts`, `demo/screenshots/*.png`
- **Dependencies**: Requires running stack (dev-start.sh) + Playwright installed
- **No code changes**: No backend or frontend modifications — capture-only
