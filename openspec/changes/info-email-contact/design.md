## Context

The project provisioned a real contact mailbox routed through Cloudflare Email Routing. The static site at findabed.org currently exposes only seed-account emails (internal demo logins) and references to GitHub issues. The React SPA has no contact surface either.

Three constraints from the operator review:
1. The literal address must not be checked into git (same posture as `feedback_no_ip_in_repo`).
2. The static site and React SPA should source the contact from a single REST endpoint.
3. The architecture must support per-tenant contact emails for production multi-tenant deployments, with the demo site happening to use the same address everywhere.

Site shape (post-v0.55.0): 14 static HTML pages served from `/var/www/findabed-docs/` on the Oracle VM, fronted by Cloudflare. Backend is Spring Boot 4 + Spring Data JDBC modular monolith. React 19 + Vite + react-intl SPA. PostgreSQL 16 + Flyway, FORCE RLS on regulated tables. JWT-based auth with per-tenant DEK signing.

## Goals / Non-Goals

**Goals:**

- Public visitors can find a working contact email from any page on findabed.org with at most one scroll.
- The literal address never appears in the git-tracked source tree (placeholder pattern matches `feedback_no_ip_in_repo`).
- Static and SPA surfaces source the contact email from the same backend endpoint; if the email changes, only the env var or one DB row needs touching.
- Production deployments can configure per-tenant contact emails via the existing tenant-config PUT endpoint; demo deployment runs with all tenants empty (inheriting platform).
- Spam protection via JS-rendering — bots without JS engines see no address — is the primary defense; Cloudflare obfuscation is belt-and-suspenders.
- Audience pages carry context-appropriate CTAs that consume the same JS-injected email.

**Non-Goals:**

- A dedicated `contact.html` landing page with response-time copy + "what to include" guidance. v1 is footer + audience CTAs only; if inbound volume justifies a richer page later, that's a separate change.
- Programmatic email validation, CAPTCHAs, or web forms. Out of scope — `mailto:` link only.
- Migrating the existing seed-account emails (`outreach@dev.fabt.org` etc.) — those are demo login credentials, not contact addresses, and stay where they are.
- The full "Report a Problem" / "Help / Feedback & Support" UI from GH #67. This change provides the `useContactInfo()` hook and the public endpoint; #67 consumes them when it lands.
- Server-side analytics/metrics on contact-info-API hit volume in v1 (basic Micrometer counters at the controller layer are fine; bespoke dashboards are a v2 concern).

## Decisions

**D1 — Platform contact email lives in env var + `application.yml`, not a database row.**

`fabt.platform.contact-email` (Spring property) → `FABT_PLATFORM_CONTACT_EMAIL` (env var). Empty string by default in committed `application.yml`. Set in `~/fabt-secrets/.env.prod` on prod, operator local env for dev. Tested with Spring's standard `@ConfigurationProperties` or `@Value` injection.

**Why not a database row?** A new `platform_config` table for one field is overkill. Reusing `tenant.config` with a sentinel slug (`_platform`) violates the "tenants are tenants, not platform" boundary the platform-operator slice (v0.53/v0.54) drew. Env var is operationally familiar (matches `feedback_no_ip_in_repo`) and admits one source of truth per environment.

**Why not commit it to `application.yml` in git?** Same reasoning as the VM IP: anything an attacker could harvest from a public repo as ammunition stays out. Email scraping is less acute than IP origin discovery, but the discipline is identical and the operational cost is identical (one env var entry in `~/fabt-secrets/.env.prod`).

**D2 — Per-tenant email lives in `tenant.config.contact.email` JSONB key, written via a dedicated PATCH endpoint with a typed request DTO.**

The `config` JSONB column already carries `features.reentryMode`, `active_counties`, `observability.noaa_station_id`, etc. Adding a `contact.email` key fits the established pattern with zero schema migration.

**Write path:** the dedicated endpoint `PATCH /api/v1/admin/tenants/{tenantId}/contact-email`, mirroring the existing `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration` pattern (the consumer is `frontend/src/pages/admin/components/ReservationSettings.tsx`). The dedicated endpoint binds a typed Java record:

```java
public record ContactEmailRequest(
    @Email @Size(max = 254) String email
) {}
```

This shape is what makes Spring's `@Valid` cascade actually run the `@Email` constraint. The generic `PUT /tenants/{id}/config` path takes a `Map<String, Object>` JSONB blob and `@Email` cannot bind to that — see warroom B2. Reusing the dedicated-endpoint pattern also gives Bean validation, `TENANT_CONFIG_UPDATED` audit emission, and tenant-scope enforcement at the boundary, all of which are inherited from the `hold-duration` precedent.

**Default value:** empty string (or absent key — both resolve identically). Empty/absent means "inherit the platform contact"; a non-empty value means "use this tenant-specific address." Empty-string PATCH is the canonical "clear the override" operation.

**Why not a generic config-edit form?** The codebase pattern is already "one dedicated PATCH endpoint per config key, one admin component per key" (only `hold-duration` exists today; `reentryMode` and `active_counties` have no UI surface yet — they're flipped via curl). Following this pattern keeps the change surface tight and consistent.

**D3 — API path: `/api/v1/public/contact-info`. Public, unauthenticated.**

Path under `/api/v1/public/` deliberately mirrors the implicit pattern (the runbook §5/§6 verification curls treat `/api/v1/public/*` as anonymously reachable). No auth required because the endpoint reveals what's already on the public-facing site — there's nothing to gate.

`GET` only (no PUT/POST). The platform email is set via env var (deploy-time); the per-tenant email is set via the existing tenant-config PUT, not via this read-only endpoint.

**Response shape:**
```json
// Unauthenticated:
{ "platform": { "email": "info@example.org" }, "tenant": null }

// Authenticated (tenant context):
{
  "platform": { "email": "info@example.org" },
  "tenant": { "slug": "dev-coc", "email": null }       // empty per-tenant → fall back
}
{
  "platform": { "email": "info@example.org" },
  "tenant": { "slug": "dev-coc-east", "email": "..." }  // per-tenant set
}
```

**Why always return the `tenant` block (even with `email: null`) when authed?** So the frontend can reason about it in one fetch without a second call. `null` email signals "inherit platform"; the frontend then uses `tenant.email ?? platform.email`. Cleaner than ambiguous `{tenant: null}` for "inherit."

**D4 — Cache headers split by auth state. Unauthed: `public, max-age=3600`. Authed: `private, max-age=3600` + `Vary: Authorization`. ETag for both.**

The platform email changes at most once per multi-month operator decision. The per-tenant email changes at most a few times per year per tenant. 1-hour cache absorbs the overwhelming majority of legitimate traffic.

**Why split by auth state?** The authed body varies by tenant (`tenant.slug` + `tenant.email`). With `Cache-Control: public`, Cloudflare edge cache (and any intermediary proxy) is allowed to serve the cached body to any later requester regardless of who they are — meaning tenant A's body could be served to tenant B. This is a cross-tenant data leak (warroom B1). The fix is to mark authed responses `private` (no shared-cache storage) and add `Vary: Authorization` belt-and-suspenders for downstream caches that respect it. Unauthed responses are identical for all unauthed callers and remain safely public-cacheable.

**ETag derivation:** SHA-256 of canonical JSON, truncated to 16 hex chars. Computed in-memory from the response body — never via an additional DB read per request.

**Trade-off considered:** shorter TTL (e.g., 15 minutes) would propagate operator changes faster but burns ~96 cache misses/day per active client per tenant. The infrequent-change profile makes the longer TTL the right call.

**D5 — Static-site spam protection: JS-injected, not plain `mailto:` + Cloudflare obfuscation.**

The static HTML's source contains a placeholder element (`<a class="contact-email" href="#" hidden>contact</a>`) and a script tag pointing to `/contact.js`. The shared JS fetches `/api/v1/public/contact-info`, sets the link's `href` to `mailto:<email>`, sets the visible text, and removes the `hidden` attribute. Bots without JS engines see no address at all in the rendered HTML — categorically better than Cloudflare's obfuscation-on-render approach.

**Why not also keep Cloudflare obfuscation enabled?** No reason not to. It remains belt-and-suspenders for the rare bot that does run JS. Tasks include verification but don't gate on it.

**D6 — Static-site fallback when `/api/v1/public/contact-info` is unreachable: replace placeholder with GH-issues link (and a `<noscript>` block does the same for JS-disabled visitors).**

Two failure modes need handling: (1) the API fetch fails (network, backend down, empty platform email), and (2) the visitor has JavaScript disabled.

For (1): `/contact.js` swaps the placeholder's `href` and text to a GH-issues fallback link rather than leaving it `hidden`. Visitors always see SOME working contact path.

For (2): an inline `<noscript>` block adjacent to the placeholder renders the same GH-issues fallback. Browsers natively show `<noscript>` content only when JS is disabled, so JS-enabled visitors never see it.

**Why swap-on-failure rather than hide-on-failure (warroom M4 + H5)?** Not every in-scope page has a GH-issues link in its existing footer (`pitch-briefs.html`, `dvindex.html`, etc.); hide-on-failure on those pages leaves a visitor with no path at all. The swap-and-noscript shape ensures coverage regardless of page composition.

**Accessibility (warroom H5):** the placeholder element carries `aria-live="polite"` so screen readers announce the late-injected text after JS hydration. The `<noscript>` fallback is accessible by default (it's just inline content that renders when JS is off).

**D7 — Audience-specific framing on the 4 for-*.html pages + outreach-one-pager.**

A funder reading `for-funders.html` and a coordinator reading `for-coordinators.html` are asking different things. Each audience page gets an audience-appropriate CTA in its existing "next steps / get involved" section that consumes the same JS-injected email but wraps it in audience-specific framing. Casey-review on the funder + cities copy before commit (matches `transitional-reentry-support`'s pattern of disclaimer-text legal review).

**D8 — React SPA integration: `ContactInfoProvider` context + `useContactInfo()` hook. Provider refetches on auth-state transitions.**

Single fetch on app mount via the provider; cached in component state. Components consume via `useContactInfo()`. The provider subscribes to AuthContext and **refetches on auth-state transitions** (anonymous → authed login, authed → anonymous logout, tenant-claim change). Required because the response shape changes by auth state — the unauthed response has `tenant: null`; the authed response has the per-tenant block. Without the refetch, a user who logs in mid-session keeps seeing the unauthed response (no per-tenant override) (warroom H3).

Forward-compatible with the `useContactInfo()` interface required by GH #67's Report-a-Problem footer + Help kebab + Feedback&Support landing — once #67 lands, it consumes this hook directly.

**D9 — DV-policy tenants forbidden from setting per-tenant contact email; clearing always allowed.**

For tenants with `dv_policy_enabled = true`, the dedicated PATCH endpoint rejects any non-empty write attempt with a 400 + structured error code `tenant.contactEmail.dvPolicyForbidden`. The frontend `ContactSettings` component disables the field with a localized explanatory note in this state. Empty-string PATCH (clearing the override and reverting to platform inheritance) MUST always succeed, even on DV-policy tenants — operators must always be able to revert.

**Why this policy?** DV shelter operators hold their direct contact lines closely to avoid traffickers/abusers calling shelters directly. A per-tenant `contact.email` for a DV CoC could end up being a real staffer's email exposed to coordinators in that tenant — wider blast radius than typical DV-directory disclosure (where the contact path is centralized to a hotline, not per-shelter). Forcing platform-inheritance on DV tenants matches existing operational discipline and avoids the failure mode entirely.

**Alternatives considered:**
- **A** — Leave as-is (per-tenant email visible to all authed tenant members). Lowest cost; trusts existing role boundary.
- **B** — Forbid per-tenant email on DV-policy-enabled tenants (this decision). Simplest policy, easiest to audit.
- **C** — Allow per-tenant email but role-gate the response (e.g., COC_ADMIN sees it, COORDINATOR doesn't). Adds a flag, new test surface, ongoing maintenance.

**B chosen** (operator decision, warroom Q4). The cost (DV CoCs cannot have a tenant-specific contact) matches existing DV-shelter operational discipline.

**D10 — Per-IP rate limit on the public endpoint via Bucket4j.**

The public contact-info endpoint is hit on every static page load (via `/contact.js`) and on every React app mount. The 1-hour edge cache absorbs anonymous traffic, but uncached-first-hit-per-cache-key and authed traffic still reach origin. Apply the existing Bucket4j integration with a default per-IP budget of **60 req/min** (tunable via `fabt.bucket4j.public.contact-info.*`). Returns 429 + `Retry-After` consistent with the rest of the public-API rate-limit shape (warroom H2).

## Risks / Trade-offs

**[Risk] Backend down → static-site contact link silently disappears.** *Mitigation:* hide-on-fail is the simpler shape (D6); the GitHub-issues link in most pages' footers remains as alternative path. Status of the contact-info endpoint is captured by the same actuator/health that gates the smoke gate.

**[Risk] Public endpoint becomes a scraping target.** *Mitigation:* 1-hour Cloudflare edge cache absorbs anonymous traffic. Endpoint reveals only what's already public on the site. Add a Bucket4j rate limit if scraping ever materializes (not v1 scope).

**[Risk] Operator forgets to set `FABT_PLATFORM_CONTACT_EMAIL` on prod env.** *Mitigation:* the static-site fallback (hide-on-fail) means visitors don't see a broken `mailto:`; they just don't see contact info. The runbook task includes a pre-deploy verification curl. Backend startup logs the resolved value (with the address itself redacted) at INFO so operator can grep for the config presence.

**[Risk] Per-tenant `contact.email` set to malformed value (e.g., missing `@`).** *Mitigation:* validation at the `PUT /tenants/{id}/config` boundary using the existing email-validation discipline (the same we use for `app_user.email`). The contact-info endpoint trusts validated state.

**[Risk] Cloudflare Email Address Obfuscation toggled off in dashboard.** *Mitigation:* JS-rendering (D5) is the primary defense; CF obfuscation is belt-and-suspenders. Less critical than the previous design's reliance on it. Pre-deploy verification still confirms it's on.

**[Risk] CSP blocks `/contact.js` or the `/api/v1/public/contact-info` fetch.** *Mitigation:* same-origin requests; existing CSP allows `connect-src 'self'`. `/contact.js` lives in static content and inherits the same CSP. Pre-deploy verification includes a browser console check.

**[Risk] Audience CTAs become marketing pitches.** *Mitigation:* tasks specify Casey-review on funder + cities copy with banned-phrase checklist; spec forbids any aspirational claim per `feedback_legal_claims_review`.

## Migration Plan

- **Deploy:** full v0.55-style deploy. Backend rebuild (new endpoint + config). Frontend rebuild (new provider/hook). Static-content scp (14 HTML edits + new `/contact.js`). Cloudflare Purge Everything. Run `oracle-update-notes-v0.55.0.md`-style §6 verification: API endpoint returns expected JSON, every in-scope page has placeholder + script tag, static load via browser populates email correctly.
- **Configuration:** add `FABT_PLATFORM_CONTACT_EMAIL=<address>` to `~/fabt-secrets/.env.prod` BEFORE the backend rebuild. Demo tenants stay at empty `tenant.config.contact.email` (inherit platform). Production tenants can set their own via the existing PUT endpoint.
- **Rollback:** revert backend image to v0.55.0-lastgood; revert frontend image; revert static HTML to pre-change. The platform mailbox stays live regardless. Per-tenant config rows are forward-compatible with v0.55.0 backend (it ignores the new key).
- **Verification:** post-deploy checks include `curl /api/v1/public/contact-info` returns expected shape, browser-load on `https://findabed.org/` populates the footer link, bot-User-Agent fetch returns no plain-text email in HTML body.

## Open Questions

1. **Should the React SPA's `ContactInfoProvider` be wired into v1's login page footer, or only made available for GH #67 to consume later?** Recommendation: wire into login footer in v1 — it's the same scope as the static footer and a clean validation of the hook's shape. (Resolved: include in scope.)
2. **Casey legal-language review on the funder + cities CTA copy** — explicit task, but no scope difference.
3. **Should `/contact.js` be served from the static site (`/contact.js`) or from the backend (`/api/v1/public/contact.js`)?** Recommendation: static site. Lower latency, less CSP friction, no backend dependency for the JS itself (only the JSON fetch is backend-dependent). Rolls into the same scp deploy.
4. **Validation library for the per-tenant `contact.email` JSONB key write path** — reuse the existing `app_user.email` validator? Most likely yes; deferred until the implementation slice surfaces the actual class name.
