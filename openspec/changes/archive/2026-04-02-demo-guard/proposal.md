## Why

`findabed.org` needs a "Try the Demo" link with published credentials so visitors (researchers, city officials, funders, shelter directors) can experience the platform without contacting us first. But PLATFORM_ADMIN has ~60 destructive endpoints (create/delete users, flip DV flags, change passwords, activate surge, import data) and COC_ADMIN has ~40. Publishing those credentials on a public website is a guaranteed abuse scenario — someone will flip a DV flag, change every password, and create backdoor accounts within hours. Meanwhile, the project maintainer needs frequent real admin access for demo preparation, data fixes, and testing new deployments.

The Snipe-IT pattern solves this: publish all role credentials, block destructive operations via a demo guard filter, and provide a localhost-only bypass for real admin work via SSH tunnel.

## What Changes

- Add a `DemoGuardFilter` (Spring Boot `OncePerRequestFilter`) activated by the `demo` Spring profile
- The filter blocks destructive API operations (POST/PUT/PATCH/DELETE on admin endpoints) for public traffic, returning `{"error": "demo_restricted", "message": "..."}` with 403 status
- The filter exempts requests from localhost (`127.0.0.1` / `::1`) — SSH tunnel traffic bypasses the guard
- Safe mutations remain functional: bed search (POST), bed holds, hold confirm/cancel, DV referral requests, login, TOTP verification
- Add `demo` to `SPRING_PROFILES_ACTIVE` on the Oracle VM
- Add "Try the Demo" section to the landing page and demo walkthrough with published credentials and disclaimer
- Update the React frontend to display a friendly toast when the API returns `demo_restricted`
- **Fix 29 swallowed error catch blocks** across AdminPanel.tsx (20), CoordinatorDashboard.tsx (8), and ShelterEditPage.tsx (1) — these discard API error messages, hiding demo_restricted and all other error detail from users
- Add Playwright E2E tests verifying demo guard messages appear in the browser for key admin operations
- Site cleanup (from SITE-CLEANUP.md): correct screenshot count (C-02), fix broken PITCH-BRIEFS.md link (C-03), remove developer note from demo walkthrough footer (C-05), capture and add TOTP 2FA screenshots (C-06), reorganize walkthrough account security section (C-07)

## Capabilities

### New Capabilities
- `demo-guard`: DemoGuardFilter that blocks destructive operations in demo mode with localhost exemption for real admin access
- `demo-access-ui`: "Try the Demo" section on static pages with credentials and disclaimer, plus frontend toast for demo-restricted responses
- `frontend-error-handling`: Fix 29 catch blocks that swallow API error messages, ensuring demo_restricted and all other API errors display their actual message to users

### Modified Capabilities
(none — the filter is additive, no existing specs change)

## Impact

- **Backend code:** One new filter class (`DemoGuardFilter.java`), activated by `@Profile("demo")`. ~60-80 lines.
- **Frontend code:** Fix 29 catch blocks across 3 files + `api.ts` demo_restricted enhancement. ~60 lines changed.
- **Oracle VM:** Add `demo` to `SPRING_PROFILES_ACTIVE` in `.env.prod` or `docker-compose.prod.yml`
- **Static site:** Add "Try the Demo" section to `index.html` and `demo/index.html` with credentials + disclaimer
- **Admin workflow:** SSH tunnel to `:8081` for full admin access (same pattern as Grafana tunnel)
- **No database changes, no permission model changes, no new roles**
