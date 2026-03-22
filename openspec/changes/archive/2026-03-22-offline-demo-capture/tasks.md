## 1. Playwright Capture Script

- [x] 1.1 Create `demo/capture-screenshots.spec.ts` in the code repo's `e2e/playwright/` directory: import auth fixtures, navigate to login page, capture `01-login.png`
- [x] 1.2 Capture outreach views: search page (empty form), search results (after querying "individuals"), reservation hold (after clicking hold on first available shelter)
- [x] 1.3 Capture coordinator view: CoC admin dashboard with shelter list and availability
- [x] 1.4 Capture admin views: Users tab, Shelters tab, Surge tab, Observability tab (with config + temp status)
- [x] 1.5 Capture observability views (conditional): Grafana FABT Operations dashboard at `:3000`, Jaeger trace list at `:16686`. Skip gracefully if not running.
- [x] 1.6 All screenshots saved to `../../demo/screenshots/` (relative to e2e/playwright, landing in findABed docs repo `demo/screenshots/`)

## 2. HTML Walkthrough

- [x] 2.1 Create `demo/index.html` in the docs repo: dark header with "Finding A Bed Tonight — Demo Walkthrough", project description
- [x] 2.2 Add numbered screenshot cards with captions for each of the 11 views — responsive CSS grid, inline styles, no external dependencies
- [x] 2.3 Add footer with generation timestamp placeholder and link to GitHub repo

## 3. Capture Shell Script

- [x] 3.1 Create `demo/capture.sh`: check stack health (curl liveness), exit with error message if down
- [x] 3.2 Run `npx playwright test capture-screenshots.spec.ts` from the e2e/playwright directory, targeting output to `demo/screenshots/`
- [x] 3.3 Report success with list of captured files, or failure with error

## 4. Integration

- [x] 4.1 Add `demo/` directory reference to docs repo README
- [x] 4.2 Run capture against current running stack, verify all 11 screenshots generated
- [x] 4.3 Verify `index.html` opens in browser and displays all screenshots with captions
