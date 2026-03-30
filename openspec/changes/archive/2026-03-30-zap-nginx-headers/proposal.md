## Why

OWASP ZAP baseline scan against the live deployment (`https://150.136.221.232.nip.io`) returned 0 FAIL but 9 WARN findings. Seven are actionable security header gaps in the nginx layer. The frontend container nginx sets some headers (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`) but is missing HSTS, CSP, COEP, and server version suppression. The host nginx (certbot-managed) adds none. Before sharing the demo URL with city IT evaluators, these headers must be present — they are exactly what a compliance scanner will flag.

## What Changes

- Add `Strict-Transport-Security` header to host nginx (HSTS — only meaningful on the TLS-terminating layer)
- Add `Content-Security-Policy` header to frontend nginx (CSP for React SPA)
- Add `Cross-Origin-Embedder-Policy` header to frontend nginx
- Suppress nginx server version (`server_tokens off`) in both nginx configs
- Ensure `X-Content-Type-Options` and `Permissions-Policy` are applied to all responses (currently missing on some static asset routes due to nginx `add_header` in nested location blocks overriding parent headers)
- Add `Cache-Control: no-cache` for HTML responses (SPA entry point) to prevent stale deploys
- Update the oracle-demo-runbook to include these headers in the host nginx template

## Capabilities

### New Capabilities
- `nginx-security-headers`: Security header configuration for both the frontend container nginx and the host (TLS-terminating) nginx, covering OWASP ZAP baseline findings

### Modified Capabilities
_None — no existing spec-level requirements change._

## Impact

- **Frontend nginx config** (`infra/docker/nginx.conf`): Header additions, `server_tokens off`
- **Host nginx template** (`oracle-demo-runbook-v0.21.0.md` Part 8.1): Header additions
- **Docker image rebuild required** for frontend container after nginx.conf changes
- **No backend code changes** — Spring Security already sets defense-in-depth headers on API responses
- **No breaking changes** — headers are additive
