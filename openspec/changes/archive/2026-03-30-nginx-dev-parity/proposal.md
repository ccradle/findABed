## Why

The SSE proxy buffering bug (v0.22.1) caused constant page refreshing on the demo site but was invisible in dev. The root cause: dev uses Vite's built-in dev proxy which handles streaming correctly, while production uses the nginx container which buffers SSE responses by default. No test or dev workflow exercised the actual nginx proxy path.

This is a class of bugs, not a one-off. Any behavior that depends on proxy configuration — SSE streaming, WebSocket upgrade, large file uploads, request timeouts, header manipulation, CORS in proxy mode — will differ between Vite's dev proxy and the nginx container. We need the ability to test through the real nginx proxy in dev.

## What Changes

- **Add nginx frontend container to dev stack** as an optional `--nginx` flag on `dev-start.sh`. When enabled, the frontend is served through the same `nginx.conf` used in production instead of Vite's dev server. Vite remains the default for fast HMR during development.
- **Add a `docker-compose.dev-nginx.yml` override** that starts the frontend nginx container pointing to Vite's build output (or a production build), proxying `/api/` to the backend on the host.
- **Add Playwright test profile** (`--nginx`) that runs the E2E suite through the nginx proxy instead of Vite's dev server. This catches proxy-specific bugs like SSE buffering.
- **Add SSE-specific Playwright test** that verifies the notification stream stays connected for 30+ seconds without dropping (the test that would have caught v0.22.1).
- **Update `dev-start.sh`** usage docs to explain when to use `--nginx` (before any release, after nginx.conf changes, when debugging proxy behavior).

## Capabilities

### New Capabilities
- `dev-nginx-parity`: Optional nginx frontend proxy in dev, Playwright test profile for nginx mode, SSE connectivity test

### Modified Capabilities
_None — existing dev workflow unchanged by default._

## Impact

- **`dev-start.sh`** — new `--nginx` flag: builds frontend, starts nginx container on port 8081, proxies to backend
- **`docker-compose.dev-nginx.yml`** (new) — dev override that adds the frontend nginx container
- **`e2e/playwright/playwright.config.ts`** — new project config for nginx base URL
- **`e2e/playwright/tests/sse-connectivity.spec.ts`** (new) — SSE stream stays connected test
- **No changes to production code** — this is dev infrastructure only
- **No changes to existing dev workflow** — `--nginx` is opt-in, Vite remains default
