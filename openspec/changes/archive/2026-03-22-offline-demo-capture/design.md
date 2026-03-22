## Context

The platform runs locally via `dev-start.sh` but has no public demo site. Screenshots and a static HTML walkthrough in the docs repo allow stakeholders to see the app without installing anything. The capture must be automated so it stays current as the UI evolves.

## Goals / Non-Goals

**Goals:**
- Automated screenshot capture via Playwright against a running local stack
- Browsable offline HTML walkthrough with navigation and captions
- Regenerable on demand via a single shell script
- Covers all key user journeys: login, search, reservations, coordinator, admin (all tabs), observability (Grafana, Jaeger)

**Non-Goals:**
- Interactive demo (this is static screenshots, not a hosted app)
- Video recording (screenshots are simpler to maintain and share)
- CI integration (manual capture for now — CI can be added later)

## Decisions

### D1: Playwright for capture

Use a dedicated Playwright spec (`capture-screenshots.spec.ts`) that navigates each view and calls `page.screenshot({ fullPage: true })`. Reuses the existing `auth.fixture.ts` for pre-authenticated pages. Playwright is already a project dependency.

### D2: Screenshot inventory

| # | View | Filename | Auth | Notes |
|---|------|----------|------|-------|
| 1 | Login page | `01-login.png` | None | Empty form with tenant slug |
| 2 | Outreach search (empty) | `02-outreach-search.png` | Outreach | Search form before query |
| 3 | Bed search results | `03-bed-results.png` | Outreach | After searching "individuals" |
| 4 | Reservation hold | `04-reservation-hold.png` | Outreach | After clicking "Hold This Bed" |
| 5 | Coordinator dashboard | `05-coordinator-dashboard.png` | CoC Admin | Shelter list with availability |
| 5b | Coordinator availability update | `05b-coordinator-update.png` | CoC Admin | Expanded shelter card with bed count steppers |
| 6 | Admin — Users tab | `06-admin-users.png` | Admin | User management table |
| 7 | Admin — Shelters tab | `07-admin-shelters.png` | Admin | Shelter list |
| 8 | Admin — Surge tab | `08-admin-surge.png` | Admin | Surge activation form + history |
| 9 | Admin — Observability tab | `09-admin-observability.png` | Admin | Config toggles + temp status |
| 10 | Create User form | `10-create-user.png` | Admin | Role selection, DV access toggle |
| 11 | Add Shelter form | `11-add-shelter.png` | CoC Admin | Name, address, constraints, capacity by population type |
| 12 | Shelter detail (admin) | `12-shelter-detail.png` | Admin | Profile, constraints, availability from admin panel |
| 13 | Shelter detail (search) | `13-search-shelter-detail.png` | Outreach | Availability + hold buttons from bed search results |
| 14 | Spanish language | `14-spanish.png` | Outreach | Full i18n — all labels switch via locale selector |
| 15 | Grafana dashboard | `15-grafana-dashboard.png` | N/A | FABT Operations panels (requires --observability) |
| 16 | Jaeger traces | `16-jaeger-traces.png` | N/A | Trace list for finding-a-bed-tonight service (requires --observability) |

### D3: HTML walkthrough structure

A single `index.html` with:
- Dark header with project name and description
- Numbered screenshot cards with captions explaining what each view shows
- Responsive layout (works on desktop and mobile)
- No external dependencies (inline CSS, no JS frameworks)
- Footer with generation timestamp and link to repo

### D4: Capture script

`demo/capture.sh`:
1. Verifies the stack is running (curl health check)
2. Runs `npx playwright test demo/capture-screenshots.spec.ts`
3. Reports success/failure and lists captured screenshots

### D5: File location

All demo files live in the **docs repo** (`findABed/demo/`), not the code repo. Screenshots are committed directly (not gitignored) so the demo works when cloning the docs repo without running anything.
