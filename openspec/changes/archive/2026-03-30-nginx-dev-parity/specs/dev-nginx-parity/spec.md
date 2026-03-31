## ADDED Requirements

### Requirement: Nginx dev mode via --nginx flag

`dev-start.sh --nginx` SHALL build the frontend and start the nginx container on port 8081, serving the production nginx.conf with the built React assets. The backend continues to run on the host via `mvn spring-boot:run`.

**Acceptance criteria:**
- `./dev-start.sh --nginx` checks Docker >= 20.10, builds frontend, and starts nginx container
- `./dev-start.sh --nginx --no-build` skips the frontend build (for quick nginx.conf iteration)
- `http://localhost:8081` serves the React app through nginx
- `/api/` requests proxy to the backend on the host
- SSE stream (`/api/v1/notifications/stream`) works without buffering
- `./dev-start.sh --nginx --observability` works (both flags combined)
- `./dev-start.sh` without `--nginx` is unchanged (Vite dev server)

### Requirement: Docker Compose dev nginx override

A `docker-compose.dev-nginx.yml` file SHALL define a `frontend-nginx` service that volume-mounts `frontend/dist` and `infra/docker/nginx.conf` and uses `host-gateway` to reach the backend on the host.

**Acceptance criteria:**
- Service uses `nginx:alpine` image (same as production Dockerfile base)
- `frontend/dist` mounted read-only (no image rebuild needed)
- `nginx.conf` mounted read-only (config changes applied on container restart)
- `backend` hostname resolves to host machine via `host-gateway`
- Port 8081:80 matches production frontend container
- Service only starts with `--profile nginx`

### Requirement: Playwright nginx test profile

`playwright.config.ts` SHALL include a `nginx` project that runs tests against `http://localhost:8081` instead of the Vite dev server.

**Acceptance criteria:**
- `npx playwright test --project=nginx` runs the full E2E suite against nginx
- `npx playwright test` (default) still runs against Vite dev server
- Both profiles use the same test files and fixtures

### Requirement: SSE connectivity test

A Playwright test SHALL verify that the SSE notification stream stays connected without reconnecting for at least 15 seconds (sufficient to detect the v0.22.1 reconnect-every-5-seconds pattern).

**Acceptance criteria:**
- Test uses `test.slow()` to triple the default timeout
- Test logs into the app and navigates to a page that establishes SSE (outreach search)
- Test monitors network requests for 15 seconds
- Asserts only 1 connection to `/api/v1/notifications/stream` (no reconnects)
- Asserts no rapid-fire requests to `/api/v1/queries/beds` or `/api/v1/dv-referrals/mine` (max 1 each during the window, excluding the initial load)
- Verifies connection status indicator shows connected state (if visible in UI)
- Test runs in both default (Vite) and nginx profiles
- Test would have caught the v0.22.1 SSE buffering bug

### Requirement: Dev-start usage documentation

`dev-start.sh` header comments and `FOR-DEVELOPERS.md` SHALL document when to use `--nginx` mode.

**Guidance:**
- Before any release: run Playwright through nginx to catch proxy-specific bugs
- After any change to `infra/docker/nginx.conf`: verify behavior through the real proxy
- When debugging SSE, WebSocket, or streaming behavior
- When testing security headers (CSP, HSTS) that are set at the nginx layer
