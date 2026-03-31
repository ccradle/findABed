## Tasks

### Setup

- [x] Task 0: Create feature branch in code repo
  **Repo:** `finding-a-bed-tonight/`
  **Action:** `git checkout -b nginx-dev-parity main`

### Infrastructure

- [x] Task 1: Create docker-compose.dev-nginx.yml
  **File:** `docker-compose.dev-nginx.yml` (new, repo root)
  **Action:** Define `frontend-nginx` service: `nginx:alpine`, port `8081:80`, volume mount `frontend/dist` and `infra/docker/nginx.conf`, `extra_hosts: backend:host-gateway`, profile `nginx`. Verify nginx.conf's `proxy_pass http://backend:8080` resolves to the host.

- [x] Task 2: Add --nginx flag to dev-start.sh
  **File:** `dev-start.sh`
  **Action:** Parse `--nginx` flag alongside existing `--observability` and `--fresh`. When set:
  1. Check Docker version >= 20.10 (required for `host-gateway`). Error with clear message if too old.
  2. Run `cd frontend && npm run build && cd ..` (unless `--no-build` flag is also passed — see below)
  3. Start nginx container: `docker compose -f docker-compose.yml -f docker-compose.dev-nginx.yml --profile nginx up -d frontend-nginx`
  4. Print "Frontend (nginx): http://localhost:8081"
  5. Skip Vite dev server startup
  When `--nginx` combined with `--observability`, start both profiles.
  Also support `--no-build` with `--nginx` to skip the `npm run build` step (for quick container restart without rebuild).
  Update the script's header usage comments with new flags and guidance: "Use `--nginx` for integration testing, not active frontend development. For frontend dev, use the default Vite mode."

- [x] Task 3: Add stop support for nginx container
  **File:** `dev-start.sh`
  **Action:** In the `stop` path, also stop the nginx container if running: `docker compose -f docker-compose.yml -f docker-compose.dev-nginx.yml --profile nginx down` alongside existing stop logic.

### Playwright Configuration

- [x] Task 4: Add nginx project to playwright.config.ts
  **File:** `e2e/playwright/playwright.config.ts`
  **Action:** Add a `nginx` project with `baseURL: 'http://localhost:8081'`. Default project keeps `baseURL: 'http://localhost:5173'`. Both share the same test directory and fixtures.

### Tests

- [x] Task 5: Create SSE connectivity test
  **File:** `e2e/playwright/tests/sse-connectivity.spec.ts` (new)
  **Action:** Test that SSE stream stays connected without reconnecting. Use `test.slow()` to triple the timeout. Wait 15 seconds (sufficient to detect the v0.22.1 pattern which reconnected every 5 seconds):
  1. Login as outreach worker
  2. Navigate to outreach search (establishes SSE)
  3. Track all requests to `/api/v1/notifications/stream` via `page.on('request')`
  4. Track all requests to `/api/v1/queries/beds` and `/api/v1/dv-referrals/mine`
  5. Wait 15 seconds
  6. Assert: only 1 SSE connection (no reconnects)
  7. Assert: max 1 bed search request and 1 referral request (initial load only, no refetch storm)
  8. Also verify the connection status indicator shows connected state (if visible in UI)

- [x] Task 6: Run Playwright through Vite (default) and verify SSE test passes
  **Action:** `npx playwright test tests/sse-connectivity.spec.ts` — should pass (Vite handles SSE correctly)

- [x] Task 7: Run Playwright through nginx and verify SSE test passes
  **Action:** Start stack with `./dev-start.sh --nginx --observability`, then `npx playwright test --project=nginx tests/sse-connectivity.spec.ts` — should pass with our nginx.conf SSE location block. If it fails, the nginx config has a regression.

- [x] Task 8: Run full Playwright suite through nginx
  **Action:** `npx playwright test --project=nginx 2>&1 | tee /tmp/playwright-nginx.log` — all 173+ tests should pass through the nginx proxy. Investigate any failures as real issues, not flaky tests — they represent dev/prod parity gaps. Each failure is a bug that only appears behind nginx.

### Documentation

- [x] Task 9: Update FOR-DEVELOPERS.md
  **File:** `docs/FOR-DEVELOPERS.md`
  **Action:** Add section "Testing with nginx proxy" explaining:
  - `./dev-start.sh --nginx` for nginx mode
  - `./dev-start.sh --nginx --no-build` to restart nginx without rebuilding
  - When to use it (before release, after nginx.conf changes, SSE/streaming debugging, security header testing)
  - When NOT to use it (active frontend development — use default Vite mode for HMR)
  - `npx playwright test --project=nginx` to run E2E through nginx
  - Why this matters (v0.22.1 SSE bug was invisible in dev because Vite's proxy handles streaming differently than nginx)
  - Future recommendation: consider adding nginx profile to CI as a weekly or pre-release job

### Verification

- [x] Task 10: Run full test suite (both profiles)
  **Action:** Backend tests (`mvn test`), Playwright default (`npx playwright test`), Playwright nginx (`npx playwright test --project=nginx`). All must pass.

### Merge and Deploy

- [x] Task 11: Merge to main, tag, push
  **Action:** Merge, create tag (version TBD), push.
