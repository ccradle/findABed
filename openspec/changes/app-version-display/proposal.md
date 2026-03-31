## Why

There is no way for a user, evaluator, or operator to know which version of FABT is running without checking the server. Teresa (city official) wants to know what she's evaluating. Jordan (SRE) wants deployment verification at a glance. During the v0.22.1 SSE hotfix, we had no way to confirm the demo site was running the fixed version without SSH'ing in and checking git log.

## What Changes

- Backend: Expose version via `BuildProperties` bean + new public `GET /api/v1/version` endpoint
- Frontend: Display version string in the login page footer and admin panel footer
- Version sourced from `pom.xml` at build time — no manual updates needed

## Capabilities

### New Capabilities
- `app-version-display`: Public version endpoint, login page footer, admin panel footer

### Modified Capabilities
_None._

## Impact

- **Backend:** `VersionController.java` (new) — public GET endpoint returning `{"version": "0.23.0"}`
- **Frontend:** `LoginPage.tsx` — version string in footer
- **Frontend:** `AdminPanel.tsx` or `Layout.tsx` — version in footer/about section
- **Security:** Endpoint is public (no auth required) — version disclosure is intentional
- **No database changes**
