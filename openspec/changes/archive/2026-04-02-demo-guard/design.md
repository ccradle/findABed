## Context

The FABT demo at `findabed.org` runs v0.27.0 with 4 roles (PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER). The platform has ~60 destructive PLATFORM_ADMIN endpoints and ~40 destructive COC_ADMIN endpoints. Currently there is no public "Try the Demo" link because publishing admin credentials on a public site would allow visitors to break the demo for everyone — flipping DV flags, changing passwords, creating backdoor accounts, activating surge events.

The existing architecture exposes multiple ports on the Oracle VM:
- Port 443 (public via Cloudflare) → host nginx → container nginx :8081 → backend :8080
- Port 8081 (localhost) → container nginx → backend
- Port 8080 (localhost) → backend directly
- Port 9091 (localhost) → management/actuator

SSH tunnels are already used for Grafana (:3000) and Prometheus (:9090).

## Goals / Non-Goals

**Goals:**
- Allow visitors to explore all 4 roles (outreach, coordinator, cocadmin, admin) without risk
- Block destructive operations for public traffic while allowing full read access to all admin screens
- Provide a localhost-only bypass for real admin work via SSH tunnel
- Show friendly "disabled in demo" messaging in the UI (conversion opportunity, not just a wall)
- Add published credentials to the landing page and demo walkthrough

**Non-Goals:**
- New permission roles (no DEMO_ADMIN or READ_ONLY_ADMIN)
- Auto-resetting database (cron restore)
- Separate demo tenant or sandboxed data
- Rate limiting on demo accounts (separate concern)
- Read-only database user (too restrictive — safe mutations like holds must work)

## Decisions

### D1: Demo guard as Spring Boot filter, not nginx

**Decision:** Implement as a `OncePerRequestFilter` activated by `@Profile("demo")`, not as nginx `limit_except` blocks.

**Alternatives considered:**
- nginx `limit_except` — no code changes, but can't return proper JSON error bodies, requires 25+ verbose location blocks, and doesn't integrate with the frontend for friendly messaging
- Database-level read-only user — blocks ALL writes, including safe mutations (holds, referrals, login token refresh)
- Controller-level annotations — too scattered, easy to miss new endpoints

**Rationale:** The filter is a single file (~60-80 lines) that applies uniformly. It returns structured JSON errors that the frontend can intercept for friendly toasts. The `demo` profile keeps it completely invisible to production deployments.

### D2: Private-IP-chain bypass for admin access

**Decision:** The filter's `isInternalTraffic()` method checks if ALL IPs in the entire request chain — `request.getRemoteAddr()` plus every entry in `X-Forwarded-For` — are private or localhost. If so, the request is internal (SSH tunnel) and bypasses the guard. If any IP is public, it's external traffic and the guard applies.

**Alternatives considered:**
- Bypass header (`X-Demo-Admin: <secret>`) — works but can't be used from the browser UI easily
- Absent X-Forwarded-For check — failed because container nginx adds `X-Forwarded-For` even for tunnel traffic
- Separate port without the filter — requires custom Tomcat connector configuration, over-engineered

**Rationale:** Public traffic through Cloudflare always has a real public IP in the `X-Forwarded-For` chain. SSH tunnel traffic through container nginx has only private/localhost IPs (e.g., `X-Forwarded-For: 127.0.0.1` from the tunnel source, `remoteAddr: 172.18.0.x` from the Docker bridge). Checking the entire chain reliably distinguishes the two paths.

**Both tunnel paths work:**
- SSH tunnel to `:8080` (backend directly): `remoteAddr=127.0.0.1`, no XFF → all private → bypass ✓
- SSH tunnel to `:8081` (container nginx → backend): `remoteAddr=172.18.0.x`, `XFF=127.0.0.1` → all private → bypass ✓
- Public via Cloudflare: `remoteAddr=172.18.0.x`, `XFF=<real-public-IP>` → public IP found → guard applies ✓

**Lesson learned:** The initial design assumed container nginx would NOT add `X-Forwarded-For` for tunnel traffic. It does — `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for` is in the container nginx config. The private-IP-chain check was the fix discovered during deployment testing.

### D3: Allowlist safe mutations, blocklist everything else

**Decision:** The filter maintains an **allowlist** of safe mutation endpoints that are always permitted, and blocks all other POST/PUT/PATCH/DELETE requests when in demo mode.

Allowlisted safe mutations:
- `POST /api/v1/auth/login` — login
- `POST /api/v1/auth/refresh` — token refresh
- `POST /api/v1/auth/verify-totp` — 2FA verification
- `POST /api/v1/auth/enroll-totp` — TOTP enrollment (view QR code)
- `POST /api/v1/auth/confirm-totp-enrollment` — TOTP confirmation
- `POST /api/v1/queries/beds` — bed search
- `POST /api/v1/reservations` — hold a bed
- `PATCH /api/v1/reservations/*/confirm` — confirm hold
- `PATCH /api/v1/reservations/*/cancel` — cancel hold
- `POST /api/v1/dv-referrals` — request DV referral
- `PATCH /api/v1/dv-referrals/*/accept` — accept referral
- `PATCH /api/v1/dv-referrals/*/reject` — reject referral
- `PATCH /api/v1/shelters/*/availability` — update bed availability (coordinator demo)
- `POST /api/v1/subscriptions` — webhook registration
- `DELETE /api/v1/subscriptions/*` — webhook cancellation

Everything else (user CRUD, shelter CRUD, password resets, DV flag changes, surge events, imports, batch jobs, tenant management, OAuth2 providers, API keys) is blocked.

**Alternatives considered:**
- Blocklist approach (list specific endpoints to block) — risky; new endpoints added in future releases are unblocked by default
- Block all non-GET requests — too restrictive; blocks bed holds, search, login

**Rationale:** Allowlist is fail-secure. If a new destructive endpoint is added to the backend, it's automatically blocked in demo mode until explicitly allowlisted. This is Marcus Webb's preferred security posture — deny by default.

### D4: Frontend demo-restricted toast as conversion opportunity

**Decision:** When the API returns `{"error": "demo_restricted", ...}`, the frontend displays a friendly toast/notification instead of a generic error.

**Suggested copy:** "This feature is available in a full deployment. Contact us to set up a pilot."

**Rationale:** Simone's lens — a wall that explains what's behind it is a conversion tool, not a failure. Teresa sees the admin panel, clicks "Create User," and learns she can do this in her own deployment. The demo restriction builds trust by showing the feature exists and is responsibly protected.

## Risks / Trade-offs

**[Risk] `request.getRemoteAddr()` returns Docker bridge IP for public traffic** → Mitigation: Verify during implementation. If the backend sees Docker IPs for all traffic (both public and tunnel), the localhost exemption won't work. Fallback: check `X-Forwarded-For` header — public traffic has a real IP in the chain; tunnel traffic has `127.0.0.1`.

**[Risk] Allowlist becomes stale as new safe endpoints are added** → Mitigation: Add a test that verifies the allowlist covers the expected safe endpoints. Document in the filter's comments which endpoints are allowlisted and why.

**[Risk] Visitors change their own password (PUT /api/v1/auth/password)** → Mitigation: This is a self-service operation, not an admin operation. If a visitor changes the demo outreach user's password, other visitors can't log in with the published credentials. Decision: BLOCK self-password-change in demo mode. The published password must remain stable.

**[Risk] Coordinator updates bed availability to nonsense values** → Mitigation: Acceptable. Availability updates are allowlisted because they're core to the demo experience (Sandra's flow). The data is fictional and can be re-seeded if needed. Not blocking this preserves the demo's interactivity.

### D5: Fix swallowed error messages across the frontend

**Decision:** Fix all 29 catch blocks that discard API error messages, using the pattern `catch (err: unknown) { const apiErr = err as { message?: string }; setError(apiErr.message || intl.formatMessage({ id: 'fallback' })) }`. This ensures demo_restricted messages (and all other API errors) display their actual message to users.

**Root cause:** The anti-pattern `catch { setError(genericMessage) }` was copy-pasted across AdminPanel.tsx (20 instances), CoordinatorDashboard.tsx (8), and ShelterEditPage.tsx (1). Only 5 catch blocks in the entire frontend correctly use the error message (UserEditDrawer.tsx and ShelterForm.tsx). The correct pattern already exists — it just wasn't followed consistently.

**Scope:**
- AdminPanel.tsx: 20 catch blocks → use `apiErr.message` with intl fallback
- CoordinatorDashboard.tsx: 8 catch blocks → same pattern
- ShelterEditPage.tsx: 1 catch block → same pattern
- Silent catch blocks (e.g., `catch { /* ignore */ }`) are left as-is where the silence is intentional and documented

**Alternatives considered:**
- Centralized error hook (`useApiError`) — better architecture but too large a refactor for this change. Defer to a future cleanup.
- ESLint rule to flag `catch {` without parameter — good prevention but doesn't fix existing code. Recommend adding separately.

**Rationale:** The demo guard's value proposition (Simone's "conversion opportunity") only works if the frontend displays the actual message. Fixing these catch blocks also improves error UX for ALL API errors, not just demo_restricted.

### D6: E2E test strategy — verify full stack before deployment

**Decision:** Add Playwright E2E tests that verify the demo guard message appears in the browser for key admin operations. Run these LOCALLY against a dev instance with `demo` profile before deploying to the live demo site.

**Test coverage:**
- Admin creates user → sees "User management is disabled in the demo environment"
- Admin changes password → sees "Password changes are disabled"
- Outreach searches beds → succeeds (safe mutation allowed)
- Outreach holds bed → succeeds (safe mutation allowed)

**Lesson learned:** Backend unit/integration tests verified the filter returns the correct JSON. But the bug was at the frontend boundary — the component discarded the message. Full-stack E2E tests are the only way to verify the complete path: API response → error handler → component display → user sees the message.
