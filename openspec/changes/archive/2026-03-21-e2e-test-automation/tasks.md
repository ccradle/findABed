## 1. Playwright Setup

- [x] 1.1 Create `e2e/playwright/` directory with `package.json` (Playwright + TypeScript dependencies)
- [x] 1.2 Create `playwright.config.ts`: baseURL from env (default http://localhost:5173), headless in CI, 3 workers in CI / 1 local, retries 2 in CI / 0 local, HTML reporter
- [x] 1.3 Create auth fixture (`fixtures/auth.fixture.ts`): global setup that logs in as each role and saves storageState to `auth/{role}.json`
- [x] 1.4 Create Page Object Model base: `pages/LoginPage.ts`, `pages/OutreachSearchPage.ts`, `pages/CoordinatorDashboardPage.ts`, `pages/AdminPanelPage.ts`

## 2. Playwright Tests — Auth

- [x] 2.1 Test: successful login as outreach worker → redirects to /outreach with "Find a Bed" header
- [x] 2.2 Test: successful login as coordinator → redirects to /coordinator with "Shelter Dashboard" header
- [x] 2.3 Test: successful login as admin → redirects to /admin with "Administration" header
- [x] 2.4 Test: failed login with wrong password → shows error, stays on /login

## 3. Playwright Tests — Outreach Search

- [x] 3.1 Test: search page loads with shelter results showing name, address, availability
- [x] 3.2 Test: population type filter refreshes results
- [x] 3.3 Test: pets filter and wheelchair filter toggle and refresh results
- [x] 3.4 Test: clicking shelter card opens detail modal with availability, constraints, call/directions buttons
- [x] 3.5 Test: closing modal returns to search results

## 4. Playwright Tests — Coordinator Dashboard

- [x] 4.1 Test: dashboard loads with shelter cards showing name, address, data age
- [x] 4.2 Test: expanding shelter shows availability update form with occupied/on-hold steppers
- [x] 4.3 Test: submitting availability update shows success indicator
- [x] 4.4 Test: capacity stepper adjusts bed counts and saves

## 5. Playwright Tests — Admin Panel

- [x] 5.1 Test: admin panel loads with tabs (Users, Shelters, API Keys, Subscriptions)
- [x] 5.2 Test: create user form submits and user appears in list
- [x] 5.3 Test: shelter list displays shelters with basic info

## 6. Karate Setup

- [x] 6.1 Create `e2e/karate/pom.xml` with Karate dependencies (standalone Maven project)
- [x] 6.2 Create `karate-config.js`: baseUrl from env (default http://localhost:8080), tenant slug, auth helper functions (login, getToken)
- [x] 6.3 Create `KarateRunner.java` JUnit 5 runner with parallel execution
- [x] 6.4 Create auth helper: reusable login function that returns JWT for a given role

## 7. Karate Tests — Auth API

- [x] 7.1 Test: POST /api/v1/auth/login with valid credentials returns 200 + tokens
- [x] 7.2 Test: POST /api/v1/auth/login with invalid credentials returns 401
- [x] 7.3 Test: POST /api/v1/auth/refresh with valid refresh token returns new access token
- [x] 7.4 Test: protected endpoint without auth header returns 401
- [x] 7.5 Test: API key authentication works for shelter endpoints

## 8. Karate Tests — Shelter API

- [x] 8.1 Test: POST /api/v1/shelters creates shelter, GET returns it with constraints and capacities
- [x] 8.2 Test: PUT /api/v1/shelters/{id} updates shelter fields
- [x] 8.3 Test: GET /api/v1/shelters returns list with availability summary
- [x] 8.4 Test: GET /api/v1/shelters?petsAllowed=true filters correctly
- [x] 8.5 Test: GET /api/v1/shelters/{id}?format=hsds returns HSDS 3.0 structure
- [x] 8.6 Test: outreach worker cannot POST /api/v1/shelters (403)

## 9. Karate Tests — Availability API

- [x] 9.1 Test: PATCH /api/v1/shelters/{id}/availability creates snapshot with derived beds_available
- [x] 9.2 Test: POST /api/v1/queries/beds returns ranked results with availability data
- [x] 9.3 Test: POST /api/v1/queries/beds with populationType filter returns filtered results
- [x] 9.4 Test: POST /api/v1/queries/beds with constraint filters excludes non-matching shelters
- [x] 9.5 Test: outreach worker cannot PATCH availability (403)
- [x] 9.6 Test: shelter detail includes availability array after PATCH

## 10. Karate Tests — Subscriptions API

- [x] 10.1 Test: POST /api/v1/subscriptions creates subscription, GET lists it
- [x] 10.2 Test: DELETE /api/v1/subscriptions/{id} deactivates subscription (204)

## 11. CI Pipeline

- [x] 11.1 Create `.github/workflows/e2e-tests.yml`: trigger on push to main and PRs
- [x] 11.2 CI job: start PostgreSQL service, build + start backend, load seed data, start frontend
- [x] 11.3 CI job: run Karate tests (mvn test in e2e/karate/)
- [x] 11.4 CI job: run Playwright tests (npx playwright test in e2e/playwright/)
- [x] 11.5 Upload Karate + Playwright HTML reports as build artifacts
- [x] 11.6 Configure PR status check to require E2E tests passing
