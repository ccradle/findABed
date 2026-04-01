## Why

There is no way for a user, evaluator, or operator to know which version of FABT is running without checking the server. Teresa (city official) wants to know what she's evaluating. Jordan (SRE) wants deployment verification at a glance. During the v0.22.1 SSE hotfix, we had no way to confirm the demo site was running the fixed version without SSH'ing in and checking git log.

Marcus Webb (pen tester) notes: OWASP WSTG-INFO-02 flags version disclosure as information leakage that aids CVE fingerprinting. For an open-source project the risk is lower (changelog is public), but the endpoint should still be rate-limited at nginx and return only major.minor to avoid pinpoint version matching.

## What Changes

- Backend: Expose version via `BuildProperties` bean + new public `GET /api/v1/version` endpoint
- Frontend: Display version string in the login page footer and admin panel footer
- Nginx: Add rate limiting zone for `/api/v1/version` (10 req/min/IP) — reusable for future public endpoints
- Version sourced from `pom.xml` at build time — no manual updates needed
- Returns major.minor only (e.g., `"0.25"`) — sufficient for display, less useful for pinpoint CVE matching

## Capabilities

### New Capabilities
- `app-version-display`: Public version endpoint (rate-limited), login page footer, admin panel footer

### Modified Capabilities
_None._

## Impact

- **Backend:** `VersionController.java` (new) — public GET endpoint returning `{"version": "0.25"}`
- **Frontend:** `LoginPage.tsx` — version string in footer
- **Frontend:** `Layout.tsx` — version in admin/coordinator footer
- **Nginx:** `nginx.conf` — `limit_req_zone` for public API rate limiting
- **Security:** Endpoint is public (no auth required) — version disclosure is intentional, rate-limited, major.minor only
- **No database changes**
