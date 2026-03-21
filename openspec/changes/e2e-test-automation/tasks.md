## 1. Playwright Setup

- [ ] 1.1 Create `e2e/playwright/` directory with `package.json` (Playwright + TypeScript dependencies)
- [ ] 1.2 Create `playwright.config.ts`: baseURL from env (default http://localhost:5173), headless in CI, 3 workers in CI / 1 local, retries 2 in CI / 0 local, HTML reporter
- [ ] 1.3 Create auth fixture (`fixtures/auth.fixture.ts`): global setup that logs in as each role and saves storageState to `auth/{role}.json`
- [ ] 1.4 Create Page Object Model base: `pages/LoginPage.ts`, `pages/OutreachSearchPage.ts`, `pages/CoordinatorDashboardPage.ts`, `pages/AdminPanelPage.ts`

## 2. Playwright Tests — Auth

- [ ] 2.1 Test: successful login as outreach worker → redirects to /outreach with "Find a Bed" header
- [ ] 2.2 Test: successful login as coordinator → redirects to /coordinator with "Shelter Dashboard" header
- [ ] 2.3 Test: successful login as admin → redirects to /admin with "Administration" header
- [ ] 2.4 Test: failed login with wrong password → shows error, stays on /login

## 3. Playwright Tests — Outreach Search

- [ ] 3.1 Test: search page loads with shelter results showing name, address, availability
- [ ] 3.2 Test: population type filter refreshes results
- [ ] 3.3 Test: pets filter and wheelchair filter toggle and refresh results
- [ ] 3.4 Test: clicking shelter card opens detail modal with availability, constraints, call/directions buttons
- [ ] 3.5 Test: closing modal returns to search results

## 4. Playwright Tests — Coordinator Dashboard

- [ ] 4.1 Test: dashboard loads with shelter cards showing name, address, data age
- [ ] 4.2 Test: expanding shelter shows availability update form with occupied/on-hold steppers
- [ ] 4.3 Test: submitting availability update shows success indicator
- [ ] 4.4 Test: capacity stepper adjusts bed counts and saves

## 5. Playwright Tests — Admin Panel

- [ ] 5.1 Test: admin panel loads with tabs (Users, Shelters, API Keys, Subscriptions)
- [ ] 5.2 Test: create user form submits and user appears in list
- [ ] 5.3 Test: shelter list displays shelters with basic info

## 6. Karate Setup

- [ ] 6.1 Create `e2e/karate/pom.xml` with Karate dependencies (standalone Maven project)
- [ ] 6.2 Create `karate-config.js`: baseUrl from env (default http://localhost:8080), tenant slug, auth helper functions (login, getToken)
- [ ] 6.3 Create `KarateRunner.java` JUnit 5 runner with parallel execution
- [ ] 6.4 Create auth helper: reusable login function that returns JWT for a given role

## 7. Karate Tests — Auth API

- [ ] 7.1 Test: POST /api/v1/auth/login with valid credentials returns 200 + tokens
- [ ] 7.2 Test: POST /api/v1/auth/login with invalid credentials returns 401
- [ ] 7.3 Test: POST /api/v1/auth/refresh with valid refresh token returns new access token
- [ ] 7.4 Test: protected endpoint without auth header returns 401
- [ ] 7.5 Test: API key authentication works for shelter endpoints

## 8. Karate Tests — Shelter API

- [ ] 8.1 Test: POST /api/v1/shelters creates shelter, GET returns it with constraints and capacities
- [ ] 8.2 Test: PUT /api/v1/shelters/{id} updates shelter fields
- [ ] 8.3 Test: GET /api/v1/shelters returns list with availability summary
- [ ] 8.4 Test: GET /api/v1/shelters?petsAllowed=true filters correctly
- [ ] 8.5 Test: GET /api/v1/shelters/{id}?format=hsds returns HSDS 3.0 structure
- [ ] 8.6 Test: outreach worker cannot POST /api/v1/shelters (403)

## 9. Karate Tests — Availability API

- [ ] 9.1 Test: PATCH /api/v1/shelters/{id}/availability creates snapshot with derived beds_available
- [ ] 9.2 Test: POST /api/v1/queries/beds returns ranked results with availability data
- [ ] 9.3 Test: POST /api/v1/queries/beds with populationType filter returns filtered results
- [ ] 9.4 Test: POST /api/v1/queries/beds with constraint filters excludes non-matching shelters
- [ ] 9.5 Test: outreach worker cannot PATCH availability (403)
- [ ] 9.6 Test: shelter detail includes availability array after PATCH

## 10. Karate Tests — Subscriptions API

- [ ] 10.1 Test: POST /api/v1/subscriptions creates subscription, GET lists it
- [ ] 10.2 Test: DELETE /api/v1/subscriptions/{id} deactivates subscription (204)

## 11. CI Pipeline

- [ ] 11.1 Create `.github/workflows/e2e-tests.yml`: trigger on push to main and PRs
- [ ] 11.2 CI job: start PostgreSQL service, build + start backend, load seed data, start frontend
- [ ] 11.3 CI job: run Karate tests (mvn test in e2e/karate/)
- [ ] 11.4 CI job: run Playwright tests (npx playwright test in e2e/playwright/)
- [ ] 11.5 Upload Karate + Playwright HTML reports as build artifacts
- [ ] 11.6 Configure PR status check to require E2E tests passing
