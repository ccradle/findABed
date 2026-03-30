## ADDED Requirements

### Requirement: HSTS header on TLS-terminating nginx

The host nginx server block must include `Strict-Transport-Security` with `max-age=31536000; includeSubDomains` on all HTTPS responses.

**Acceptance criteria:**
- ZAP scan returns PASS for rule 10035 (Strict-Transport-Security Header Not Set)
- Header present on HTML, CSS, JS, and all other responses served via HTTPS
- Header NOT present on plain HTTP responses (only on the 443 listener)

### Requirement: Content Security Policy header

The frontend nginx must set a `Content-Security-Policy` header on all HTML responses that permits the React SPA to function without violations.

**Policy:**
```
default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; manifest-src 'self'; worker-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

**Acceptance criteria:**
- ZAP scan returns PASS for rule 10038 (Content Security Policy Header Not Set)
- Login page loads without console CSP violations
- Bed search, admin panel, analytics, and dark mode function without CSP violations
- Service worker registers successfully

### Requirement: Cross-Origin-Embedder-Policy header

The frontend nginx must set `Cross-Origin-Embedder-Policy: require-corp` on all responses.

**Acceptance criteria:**
- ZAP scan returns PASS for rule 90004 (Cross-Origin-Embedder-Policy Header Missing)

### Requirement: Server version suppression

Both the host nginx and frontend container nginx must include `server_tokens off` to suppress the nginx version in the `Server` response header.

**Acceptance criteria:**
- ZAP scan returns PASS for rule 10036 (Server Leaks Version Information)
- `Server` header shows `nginx` without version number

### Requirement: Security headers on static asset responses

The frontend nginx static assets location block must include all security headers (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`) alongside the `Cache-Control` header. This fixes the nginx `add_header` inheritance issue where child location blocks override parent headers.

**Acceptance criteria:**
- ZAP scan returns PASS for rule 10021 (X-Content-Type-Options Header Missing) on `.css`, `.js`, `.svg` responses
- ZAP scan returns PASS for rule 10063 (Permissions Policy Header Not Set) on `.js` responses

### Requirement: Cache-Control for HTML responses

The frontend nginx must set `Cache-Control: no-cache, no-store, must-revalidate` on HTML responses (the SPA entry point) to prevent browsers from serving stale versions after deployments.

**Acceptance criteria:**
- ZAP scan returns PASS for rule 10015 (Re-examine Cache-control Directives)
- `index.html` response includes `Cache-Control: no-cache, no-store, must-revalidate`
- Static assets (JS, CSS) retain `Cache-Control: public, immutable` with 1-year expiry

### Requirement: Runbook host nginx template updated

The oracle-demo-runbook Part 8.1 nginx template must include all host-level security headers so new deployments get them automatically.

**Acceptance criteria:**
- Part 8.1 template includes `server_tokens off`, `Strict-Transport-Security`, and any other host-level headers
- A fresh deployment following the runbook produces zero ZAP WARN findings for host-layer headers
