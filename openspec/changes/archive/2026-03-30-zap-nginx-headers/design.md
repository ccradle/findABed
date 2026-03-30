## Context

The FABT live deployment uses two nginx instances:

1. **Host nginx** — TLS termination via certbot, proxies to frontend container on `127.0.0.1:8081`. Managed by certbot (auto-modifies the config). Currently sets zero security headers.
2. **Frontend container nginx** (`infra/docker/nginx.conf`) — serves React SPA, proxies `/api/` to backend. Sets `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` at server level.

**Key nginx behavior:** `add_header` in a child `location` block **replaces** all parent-level `add_header` directives. The static assets block (`location ~* \.(js|css|...)$`) only sets `Cache-Control`, so ZAP correctly reports missing `X-Content-Type-Options` and `Permissions-Policy` on those responses.

Spring Boot also sets these headers on API responses (defense-in-depth), so the `/api/` proxy responses already carry them.

## Goals / Non-Goals

**Goals:**
- Zero WARN findings on OWASP ZAP baseline scan against the live nip.io deployment
- Headers applied correctly at the right layer (HSTS at TLS terminator, CSP at frontend)
- No functional regression (CSP must not break React SPA, service worker, or API calls)

**Non-Goals:**
- Backend header changes (Spring Security already handles API responses)
- CSP `report-uri` or `report-to` (no reporting endpoint exists)
- Subresource Integrity (SRI) on JS/CSS (Vite hashed filenames already provide integrity)

## Design

### Layer assignment

| Header | Host nginx | Frontend nginx | Why |
|--------|-----------|----------------|-----|
| `Strict-Transport-Security` | Yes | No | Only meaningful at TLS termination layer |
| `Content-Security-Policy` | No | Yes | CSP must match the SPA's asset structure |
| `X-Content-Type-Options` | No | Yes (fix inheritance) | Frontend serves the static assets |
| `Permissions-Policy` | No | Yes (fix inheritance) | Same |
| `Cross-Origin-Embedder-Policy` | No | Yes | Applies to document loading |
| `server_tokens off` | Yes | Yes | Both nginx instances leak version |
| `Cache-Control` for HTML | No | Yes | SPA index.html must not be stale-cached |

### nginx `add_header` inheritance fix

Move security headers into an `include` snippet or repeat them in every `location` block that uses `add_header`. The cleanest approach: use `include` with a shared snippet file. However, since the frontend Dockerfile copies a single `nginx.conf`, the simpler approach is to repeat the security headers in the static assets location block alongside `Cache-Control`.

### CSP for React SPA

```
default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; manifest-src 'self'; worker-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

- `'unsafe-inline'` for `style-src`: Vite injects inline styles for critical CSS
- `data:` for `img-src`: SVG icons may use data URIs
- `connect-src 'self'`: API calls and service worker fetch
- `frame-ancestors 'none'`: replaces X-Frame-Options functionally

### Host nginx — certbot-managed config

Certbot auto-modifies the server block. Headers must go inside the `server` block but outside location blocks, placed before the certbot-managed lines. The runbook template in Part 8.1 must be updated.

## Risks

- **CSP too restrictive**: If any inline script or external resource is missed, the SPA will break. Mitigation: test login flow, bed search, admin panel, and dark mode after applying.
- **COEP `require-corp`**: Could break cross-origin resource loading. Using `credentialless` instead of `require-corp` is safer for a SPA that loads no cross-origin resources. However, since FABT loads everything from `'self'`, `require-corp` is safe.
