## Why

The project now has a real contact mailbox provisioned via Cloudflare Email Routing, but it is surfaced nowhere on findabed.org. The only public contact path is GitHub issues, which excludes journalists, partner CoC leads, funders, security researchers, and visitors who don't have GitHub accounts or who reasonably expect a project of this scope to publish an email. A working contact channel also sharpens the truthfulness posture per `feedback_truthfulness_above_all`: a project asking shelters and CoC admins to trust it with hold-attribution PII should be straightforwardly reachable.

Three constraints shape the design:

1. **The literal address must not appear in the git-tracked codebase**, in the same posture as the VM IP per `feedback_no_ip_in_repo`. Operational identifiers stay in operator-side secrets, not the repo.
2. **The static site and the React app must source the contact email from the same place** — divergent surfaces are a doc-drift problem we just spent v0.55 cleaning up; we are not going to introduce a new drift surface.
3. **Production multi-tenant deployments need separate contact emails per tenant.** A Buncombe County deployment shouldn't send tenant-specific operational inquiries to the FABT project team; the deployment owner's CoC admin needs to be reachable as their own contact. The demo site happens to use the same address everywhere because there's only one operator, but the architecture must support divergence.

## What Changes

- **New backend endpoint** `GET /api/v1/public/contact-info` (public, unauthenticated). Returns `{platform: {email}, tenant: null}` for unauthed callers; returns `{platform, tenant: {slug, email}}` for authenticated callers (with `tenant.email = null` when no per-tenant override is set, signalling "fall back to platform"). Cache headers split by auth state: unauthed gets `public, max-age=3600` (edge-cacheable); authed gets `private, max-age=3600` + `Vary: Authorization` (per-tenant body, never shared-cached). ETag for both. Per-IP rate limit via Bucket4j (default 60 req/min).
- **New configuration source** for the platform contact email: env var `FABT_PLATFORM_CONTACT_EMAIL`, surfaced via `application.yml` property `fabt.platform.contact-email`. Empty string in committed `application.yml`. Set in `~/fabt-secrets/.env.prod` on prod and in operator-local env for dev. Same anti-leak posture as `feedback_no_ip_in_repo`.
- **New per-tenant config key** `tenant.config.contact.email` (JSONB string under the existing `config` column). Default empty. Written via a **dedicated PATCH endpoint** `PATCH /api/v1/admin/tenants/{tenantId}/contact-email` mirroring the existing `PATCH .../hold-duration` pattern. Typed `ContactEmailRequest(@Email @Size(max=254) String email)` record gives Bean validation at the boundary. Empty string means "inherit platform contact"; non-empty means "use this tenant-specific address." DV-policy-enabled tenants are forbidden from setting non-empty values (must inherit platform); clearing is always allowed. Writes emit `TENANT_CONFIG_UPDATED` audit events.
- **Static-site integration**: every static HTML page gets a placeholder element (with `aria-live="polite"` for screen-reader announcement) + a `<noscript>` GH-issues fallback + a tiny shared JS fetcher (`/contact.js`). On page load, the snippet calls `/api/v1/public/contact-info`, populates the `<a href="mailto:…">` link; on failure (or empty platform email) it swaps the placeholder to a GH-issues fallback link. Bots without JS engines see no email at all (the `<noscript>` block renders the GH-issues link as the visible alternative).
- **React SPA integration**: a `ContactInfoProvider` context + `useContactInfo()` hook fetched on app mount, refetched on auth-state transitions (login/logout/tenant-claim change so the per-tenant override appears post-login). Used by login footer, Help menu, and any in-app contact CTA (forward-compatible with GH #67's "Report a Problem" surface).
- **New admin UI** `ContactSettings.tsx` admin component (mirrors the existing `ReservationSettings.tsx` pattern). Lives in `frontend/src/pages/admin/components/`, wired into `AdminPanel`. Reads the current value via GET-config, saves via the dedicated PATCH endpoint. Disables the field with a localized explanatory note when the tenant has `dv_policy_enabled = true`. Spanish translations day-one.
- **14 static HTML pages** get a footer placeholder element (root `index.html`, `404.html`, all 12 `demo/*.html`).
- **5 audience pages** (the 4 `for-*.html` plus `demo/outreach-one-pager.html`'s existing `.contact` block) get audience-appropriate CTAs that consume the same JS-injected email — no audience-specific hardcoded address.
- **CI guard** asserts every in-scope HTML page contains the placeholder element AND the `/contact.js` script tag. Catches future drift.
- **Honor truthfulness on response time**: no SLA claim adjacent to the email in v1. Future addition requires operational signal backing.

## Capabilities

### New Capabilities

- `contact-info-api`: defines the platform-contact-email config source (env var), the per-tenant JSONB key, the public endpoint shape, caching posture, and authentication-aware response rules.
- `public-contact-email`: defines where and how findabed.org surfaces a public contact email — placement (every static page footer + audience CTAs), spam-protection posture (JS-injected, no plain-text in HTML source), honesty constraint (no response-time claims that aren't operationally backed), project-team voice.

### Modified Capabilities

- `audience-specific-docs`: existing `for-*.html` and `outreach-one-pager.html` pages add a JS-driven contact CTA in their "next steps / get involved" sections, audience-appropriate framing.
- `story-landing-page`: root `index.html` footer adds the JS-driven contact placeholder.

## Impact

- **Backend** — new public REST endpoint + service + DTO + 4-6 unit/IT tests. New `application.yml` property + env var. No Flyway migration (the per-tenant key lives in the existing `tenant.config` JSONB column).
- **Frontend** — new React hook + provider + light vitest coverage. Used at minimum by login footer; forward-compatible with GH #67.
- **Static content** — 14 HTML files modified (placeholder element + script tag), 1 new shared JS file (`/contact.js`), 5 audience CTA edits.
- **Deploy path** — full v0.55-style deploy: backend rebuild + frontend rebuild + static-content scp + Cloudflare purge. NOT a static-only deploy because of the new API endpoint.
- **Configuration** — `~/fabt-secrets/.env.prod` on the VM gets `FABT_PLATFORM_CONTACT_EMAIL=<address>` added. Per-tenant emails are set via authenticated `PUT /tenants/{id}/config` calls; for the demo site, all 3 tenants stay at empty (inherit platform).
- **Spam-protection posture** — JS-injected `mailto:` links replace the previous Cloudflare-obfuscation-only path. Bots without JS see no address. Cloudflare obfuscation remains a useful belt-and-suspenders for the rare cases JS does run.
- **Backward-compat** — purely additive. No existing endpoint or schema changes.
- **Truthfulness** — the literal address never enters the repo. Sample/test fixtures use `info@example.org` or `info@test.local`. Documentation and runbooks reference `${FABT_PLATFORM_CONTACT_EMAIL}` placeholders consistent with `feedback_no_ip_in_repo`.
