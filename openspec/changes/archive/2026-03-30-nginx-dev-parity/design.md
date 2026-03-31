## Context

The FABT dev stack uses `dev-start.sh` which:
1. Starts PostgreSQL + optional observability containers via `docker-compose.yml`
2. Runs the backend via `mvn spring-boot:run` on the host (port 8080)
3. Runs the frontend via `npm run dev` (Vite dev server, port 5173)

Vite's dev server has a built-in proxy configured in `vite.config.ts` that forwards `/api/` requests to `localhost:8080`. This proxy handles SSE, WebSocket, and streaming correctly — it's designed for development.

Production uses the nginx container (`infra/docker/nginx.conf`) which serves the built React assets and proxies `/api/` to the backend. The nginx config has different behavior: it buffers responses by default, requires explicit `proxy_buffering off` for SSE, and applies security headers.

**The gap:** No dev workflow tests through the nginx container. The Playwright tests run against Vite's dev server. The CI pipeline builds the Docker images but doesn't run E2E tests against them.

## Goals / Non-Goals

**Goals:**
- Dev can optionally run the frontend through the real nginx proxy with a single flag
- Playwright tests can be run against the nginx proxy to catch proxy-specific bugs
- SSE stream connectivity has a dedicated test that would catch buffering issues
- Existing dev workflow (Vite HMR) is unchanged — nginx mode is opt-in

**Non-Goals:**
- Hot module replacement through nginx (not possible — nginx serves static files)
- Running ALL Playwright tests through nginx on every commit (too slow for normal dev)
- Replacing Vite dev server as the default (HMR is essential for frontend development)
- Changing the CI pipeline (can be added later as a separate gate)

## Design

### Architecture in nginx dev mode

```
Browser → localhost:8081 (nginx container)
              ├── Static assets from frontend/dist/
              ├── /api/v1/notifications/stream → host.docker.internal:8080 (SSE, unbuffered)
              └── /api/* → host.docker.internal:8080 (backend)
```

The nginx container uses `host.docker.internal` to reach the backend running on the host via `mvn spring-boot:run`. This avoids needing the backend in a container during dev.

### docker-compose.dev-nginx.yml

```yaml
services:
  frontend-nginx:
    image: nginx:alpine
    container_name: fabt-frontend-nginx
    ports:
      - "8081:80"
    volumes:
      - ../frontend/dist:/usr/share/nginx/html:ro
      - ../infra/docker/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    extra_hosts:
      - "backend:host-gateway"
    profiles:
      - nginx
```

Key decisions:
- **Volume mount** `frontend/dist` instead of COPY — no image rebuild needed after `npm run build`
- **Volume mount** `nginx.conf` — changes to nginx config are reflected immediately on container restart
- **`host-gateway`** maps `backend` hostname to the host machine so the existing `proxy_pass http://backend:8080` works without modification
- **Port 8081** — same as production, doesn't conflict with backend (8080) or Vite (5173)
- **Profile `nginx`** — only starts when explicitly requested

### dev-start.sh --nginx flag

When `--nginx` is passed:
1. Check Docker version >= 20.10 (required for `host-gateway`). Error with clear message if too old.
2. Run `npm run build` (production build, ~10 seconds) — unless `--no-build` also passed
3. Start the `frontend-nginx` container via `docker compose --profile nginx up -d`
4. Print: "Frontend (nginx): http://localhost:8081"
5. Do NOT start Vite dev server (port 5173 stays free)

When `--nginx --no-build` is passed:
- Skip `npm run build`, restart container only (for quick iteration on nginx.conf changes)

When `--nginx` is not passed (default):
- Existing behavior unchanged — Vite dev server on 5173

**Important:** `--nginx` mode is for integration testing, not active frontend development. Vite's HMR is essential for frontend dev — nginx serves static files with no hot reload.

### Playwright nginx profile

Add a `nginx` project to `playwright.config.ts`:
```typescript
{
  name: 'nginx',
  use: {
    baseURL: 'http://localhost:8081',
  },
}
```

Run with: `npx playwright test --project=nginx`

This runs the full E2E suite against the nginx proxy. Can be used:
- Before any release
- After nginx.conf changes
- When debugging proxy-specific behavior
- Optionally in CI as a separate job

### SSE connectivity test

A new test that verifies the EventSource connection stays open:

```typescript
test('SSE notification stream stays connected for 30 seconds', async ({ page }) => {
  // Login
  // Navigate to a page that establishes SSE (outreach search)
  // Monitor network for /api/v1/notifications/stream
  // Wait 30 seconds
  // Assert: only 1 SSE connection opened (no reconnects)
  // Assert: no rapid refetch of /queries/beds or /dv-referrals/mine
});
```

This test should run in both the default (Vite) and nginx profiles. It would have caught v0.22.1.

## Risks

- **`host.docker.internal` / `host-gateway`** — works on Docker Desktop (Windows/Mac) and Docker 20.10+ on Linux. Older Linux Docker may need `--add-host=backend:172.17.0.1` instead. Mitigated by version check in dev-start.sh.
- **Stale `frontend/dist`** — if dev uses `--no-build`, nginx serves old code. Mitigated by `--nginx` without `--no-build` always running `npm run build` first. Docs clearly state when to use each.
- **Port conflict** — 8081 could conflict if something else uses it. Same risk as production. Mitigated by clear error message.
- **Actuator exposed on port 8081** — nginx.conf proxies `/actuator/` to backend. In dev this is localhost-only (acceptable). Not a security concern since dev-nginx is for local testing only.
