## 1. Pre-flight verification

- [x] 1.1 Mailbox provisioned + verified by operator pre-spec (per design.md context line 3: "the project provisioned a real contact mailbox routed through Cloudflare Email Routing"). Re-verify with a test email from Gmail in §11 deploy gate before flipping the env var on prod.
- [x] 1.2 Cloudflare Email Address Obfuscation: deferred to §11 deploy gate. Operator-side dashboard verification — flag with note in deploy log; rolls forward to v0.56 deploy step.
- [x] 1.3 Sequencing context (resolved 2026-05-01): v0.55.1 shipped 2026-05-01 ~20:50 UTC; v0.55.1 D2 closed as AI-synthetic linguistic review (Claude with web-citation grounding, NOT a native speaker — see `reference_es_json_ai_synthetic_reviewed.md`). This change ships the lang-aware `/contact.js` dict + Spanish admin-UI strings independently of any future real-native-reviewer pass. New ES strings introduced by this change should be reviewed by the same AI-synthetic process at minimum (or by a real native reviewer when one is available).
- [x] 1.4 Saved memory `reference_cloudflare_email_obfuscation_dependency.md` (2026-05-01) — describes the Cloudflare dashboard location, what can go wrong if it's silently disabled, and the verification path.

## 2. Backend: configuration plumbing

- [x] 2.1 Added `fabt.platform.contact-email: ${FABT_PLATFORM_CONTACT_EMAIL:}` to `application.yml` (line 145-152, under new `platform:` block) with inline comment documenting env-var source + anti-leak posture per `feedback_no_ip_in_repo`. Default empty string when env var unset.
- [x] 2.2 Documented in `application.yml` inline comment (§2.1) describing where the value is set (`FABT_PLATFORM_CONTACT_EMAIL` env var via `~/fabt-secrets/.env.prod`). No `.env.prod.example` template file exists in the repo today (the existing pattern is inline yaml comments + runbook env-var enumeration), and creating one solely for this property would set a precedent that contradicts `feedback_no_ip_in_repo`-style discipline. The deploy runbook (oracle-update-notes-v0.56.x.md, written when this slice deploys) enumerates the env var in §2 pre-deploy gates per the v0.55-style runbook template.
- [x] 2.3 Created `org.fabt.shared.platform.PlatformContactProperties` (record) `@ConfigurationProperties(prefix = "fabt.platform")` exposing `contactEmail` field. Canonical constructor normalizes null → empty string. Paired `PlatformContactConfig` (`@Configuration` + `@EnableConfigurationProperties`). Unit test `PlatformContactPropertiesTest` (3/3 pass) pins null-handling: null→empty, empty preserved, non-empty preserved verbatim (no trim — validation runs at controller boundary, not property level).
- [x] 2.4 `PlatformContactConfig.@PostConstruct logStartupState()` emits `"platform contact email configured: {present|absent}"` at INFO. Never echoes the literal value (defeats the anti-leak posture). Operators grep for "platform contact email configured: present" post-deploy to confirm `FABT_PLATFORM_CONTACT_EMAIL` is wired.

## 3. Backend: dedicated PATCH endpoint for per-tenant contact email

The endpoint mirrors `PATCH /api/v1/admin/tenants/{id}/hold-duration` (existing pattern; see `ReservationSettings.tsx` consumer + the corresponding backend controller). This pattern is preferred over the generic `PUT /tenants/{id}/config` because it gives Bean validation, audit emission, and tenant-scope enforcement at the boundary.

- [ ] 3.1 Update the existing `Tenant.config` JSONB schema documentation (DBML and AsyncAPI/OpenAPI doc snippets) to enumerate `contact.email` as a valid key with type `string` (RFC 5322 email format, max 254 chars) and default empty.
- [ ] 3.2 Author `ContactEmailRequest` typed Java record:
  ```java
  public record ContactEmailRequest(
      @Email @Size(max = 254) String email
  ) {}
  ```
  This is the typed-DTO shape that makes `@Valid` cascade work. Mirrors `HoldDurationRequest` exactly in style.
- [ ] 3.3 Implement `PATCH /api/v1/admin/tenants/{tenantId}/contact-email` controller method:
  - Bind `@Valid @RequestBody ContactEmailRequest body` (Spring runs `@Email` + `@Size` at the boundary).
  - Tenant-scope guard: caller's JWT-claim tenant must equal the path tenantId; reject with 403 otherwise. Mirrors slice-2D verify-round-2 C1 cross-tenant scoping.
  - **DV-policy guard (Q4=B):** if `tenant.dv_policy_enabled = true` AND `body.email()` is non-empty, return 400 with structured error code `tenant.contactEmail.dvPolicyForbidden`. Empty-string PATCH (clearing) MUST still succeed for DV tenants — operators must always be able to revert to platform inheritance.
  - Persist the value to `tenant.config.contact.email`. Empty string clears the key (consistent with how `reentryMode` empty resolves to default).
  - Emit `TENANT_CONFIG_UPDATED` audit event with old + new values (mirrors slice-2D B1).
  - Do NOT annotate with `@PreAuthorize` for public-permitted; the SecurityConfig URL rule already handles the role gate (this is an admin-prefixed path so role gating is already in place).
- [ ] 3.4 Backend integration tests:
  - Happy path: PATCH valid email → 200, persisted, audit row exists.
  - Malformed email → 400 (Bean Validation).
  - Empty string → 200, key cleared.
  - >254 chars → 400 (`@Size`).
  - DV-policy tenant non-empty PATCH → 400 with `tenant.contactEmail.dvPolicyForbidden` code.
  - DV-policy tenant empty-string PATCH → 200 (clearing is allowed even on DV tenants).
  - Cross-tenant attempt (tenant A admin PATCHes tenant B) → 403.
  - COORDINATOR role attempt (non-admin) → 403.

## 4. Backend: public REST endpoint

- [ ] 4.1 Implement `ContactInfoController` exposing `GET /api/v1/public/contact-info`. Public, unauthenticated. Path under `/api/v1/public/*` follows the existing security-config pattern. Do NOT annotate with `@PreAuthorize` — rely on `requestMatchers("/api/v1/public/**").permitAll()` already in SecurityConfig.
- [ ] 4.2 Implement response-shape logic:
  - Unauthed: `{ "platform": { "email": "<value>" }, "tenant": null }`
  - Authed: `{ "platform": { "email": "<value>" }, "tenant": { "slug": "<caller-tenant-slug>", "email": "<value-or-null>" } }`
  - The `tenant` block is always returned for authed callers, even when `email` is null (signals "inherit platform").
- [ ] 4.3 **Cache headers split by auth state (B1):**
  - Unauthed 200: `Cache-Control: public, max-age=3600` + `ETag`. NO `Vary: Authorization` (unnecessary for public-cacheable response).
  - Authed 200: `Cache-Control: private, max-age=3600` + `Vary: Authorization` + `ETag`. `private` keeps tenant-varying body out of shared caches; `Vary` is belt-and-suspenders.
  - ETag derived from a cheap hash (SHA-256 truncated to 16 hex chars) of canonical JSON — never via an extra DB read per request.
  - Honor `If-None-Match` with 304 Not Modified.
- [ ] 4.4 **Per-IP rate limit (H2):** wire Bucket4j with default budget 60 req/min/IP, tunable via `fabt.bucket4j.public.contact-info.*`. Returns 429 + `Retry-After` on exhaustion (consistent with existing Bucket4j response shape).
- [ ] 4.5 Add Micrometer counter at the controller for hit volume (`fabt_contact_info_requests_total{auth_state=…,outcome=…}`). Bespoke dashboards out of scope for v1.
- [ ] 4.6 Unit tests covering:
  - Empty platform config → empty platform.email response.
  - Configured platform-only response (unauthed).
  - Authed-with-empty-tenant response.
  - Authed-with-set-tenant response.
  - **Unauthed has `Cache-Control: public` + ETag, no Vary.**
  - **Authed has `Cache-Control: private` + Vary: Authorization + ETag.**
  - **ETag for unauthed and authed responses differ (different bodies).**
  - 304 conditional GET when ETag matches.
- [ ] 4.7 **Integration test asserting tenant-scoping:** issue an authed call with a JWT for tenant `dev-coc-east`, then a separate authed call with a JWT for tenant `dev-coc-west`. Assert each response's `tenant.slug` matches exactly the caller's tenant claim and that no field of the response leaks the *other* tenant's slug or email. Reason: tenant-enumeration sanity check.
- [ ] 4.8 **Integration test asserting rate-limit:** burst 70 requests from a single test-IP within one second, assert ≥10 are 429 with `Retry-After` set.

## 5. Frontend: React provider + hook + ContactSettings admin component

- [ ] 5.1 Create `ContactInfoProvider` context that fetches `/api/v1/public/contact-info` on app mount. Cache the response in component state.
- [ ] 5.2 Create `useContactInfo()` hook returning `{ platformEmail, tenantEmail, resolvedEmail, isLoading, error }` where `resolvedEmail = tenantEmail || platformEmail || null`.
- [ ] 5.3 **Provider refetches on auth-state transition (H3):** subscribe to AuthContext changes; refetch on login (anonymous → authed), logout (authed → anonymous), and tenant-claim change (e.g., admin switches tenant context if that exists later). Required because the response shape changes by auth state.
- [ ] 5.4 Wire `ContactInfoProvider` near the React app root (above the router). Wire `useContactInfo()` into the login page footer.
- [ ] 5.5 Vitest coverage:
  - Provider fetches once on mount.
  - Provider refetches on login (transition from anonymous to authed).
  - Provider refetches on logout.
  - Hook returns the right resolved email under each (platform-only, tenant-set) state.
  - Hook returns null `resolvedEmail` when fetch fails.
- [ ] 5.6 **New `ContactSettings.tsx` admin component (Q3 α-revised, mirrors `ReservationSettings.tsx`):**
  - File location: `frontend/src/pages/admin/components/ContactSettings.tsx`.
  - Reads existing value via `GET /api/v1/tenants/{tenantId}/config` and pulls `contact.email` (or empty string).
  - Saves via `PATCH /api/v1/admin/tenants/{tenantId}/contact-email` with body `{email: "<value>"}`.
  - Bean-validation 400 surfaces via `apiErr.context.detail` (same pattern as `ReservationSettings`).
  - **DV-policy gating:** read `tenant.dv_policy_enabled` from existing AuthContext (or fetch as part of initial GET-config); when true, the input field is disabled with a localized explanatory note keyed `admin.contactEmail.dvPolicyDisabled`. The Save button is also disabled.
  - Render a `loadFailed` banner if the GET-config call fails (defense-in-depth — same pattern as `ReservationSettings.tsx` warroom-H1).
  - Auto-dismiss the success toast at 4s; errors stay until next save.
  - Accessibility: `aria-label`, `role="alert"`/`role="status"` on the message banner, `aria-live="polite"` on the message.
  - i18n keys (Spanish day-one):
    - `admin.contactEmail.label` — field label.
    - `admin.contactEmail.description` — help text below the input.
    - `admin.contactEmail.savedWithValue` — success toast (with `{email}` placeholder).
    - `admin.contactEmail.saveError` — generic error fallback.
    - `admin.contactEmail.loadFailed` — read-side failure banner.
    - `admin.contactEmail.dvPolicyDisabled` — disabled-state explanation.
    - `admin.contactEmail.dvPolicyForbidden` — server-side rejection message (matches backend error code).
- [ ] 5.7 Wire `ContactSettings` into `AdminPanel.tsx` (alongside `ReservationSettings` in the panel header — same import + render position). Ensure the component is COC_ADMIN-gated by the existing AdminPanel access control.
- [ ] 5.8 Forward-compat check: confirm the `useContactInfo()` hook signature aligns with the consumption pattern GH #67 will use (Report-a-Problem footer + Help kebab + Feedback&Support landing). No additional UI in this change beyond the login footer and ContactSettings admin component.
- [ ] 5.9 Vitest for `ContactSettings`:
  - Renders input field with current value from GET.
  - PATCH success → success toast.
  - PATCH 400 with `tenant.contactEmail.dvPolicyForbidden` → renders the localized message.
  - When `tenant.dv_policy_enabled = true`, field is disabled and `dvPolicyDisabled` note is shown.
  - When GET fails → `loadFailed` banner + Save disabled.
  - Empty-string save clears the field (allowed even on DV tenants).

## 6. Static content: shared JS fetcher

- [ ] 6.1 Author `/contact.js` (lives in the static-content tree, served from findabed.org root). Behavior:
  - Embed a lang-aware i18n dict at the top of the file (per §7.15 + Q1). On script start, derive `lang = (document.documentElement.lang === 'es') ? 'es' : 'en'`; use `lang` to pick lead-in and noscript-fallback copy from the dict. Strings: `leadIn.en = "Contact the FABT project team:"`, `leadIn.es = "Contacte al equipo del proyecto FABT:"`, `ghFallback.en = "Contact via GitHub Issues"`, `ghFallback.es = "Contacte por GitHub Issues"`.
  - Find every element matching `a.contact-email[hidden]` on the page.
  - Find every element matching `span.footer-contact-leadin` and set its text content to `leadIn[lang]` (i18n the lead-in copy adjacent to the placeholder).
  - Fetch `/api/v1/public/contact-info` once.
  - On success with non-empty platform email: for each `a.contact-email[hidden]` element, set `href="mailto:<email>"`, set text content to the email, remove `hidden` attribute. The `aria-live="polite"` already on the element causes screen readers to announce.
  - **On failure (network, non-2xx, empty email):** for each element, replace the placeholder with the GH-issues fallback link — set `href="https://github.com/ccradle/finding-a-bed-tonight/issues"`, set text content to `ghFallback[lang]`, remove `hidden` attribute. Single console.warn for ops; no error spam.
- [ ] 6.2 Add the script reference (`<script defer src="/contact.js"></script>`) once per in-scope HTML page, near the `</body>` closing tag.

## 7. Static content: footer placeholder + noscript fallback on every in-scope HTML page

The footer markup is identical verbatim across every page:

```html
<p class="footer-contact">
  <span class="footer-contact-leadin"><!-- localized "Contact the FABT project team:" --></span>
  <a class="contact-email" href="#" hidden aria-live="polite">contact</a>
  <noscript>
    <a href="https://github.com/ccradle/finding-a-bed-tonight/issues">
      <!-- localized "Contact via GitHub Issues" -->
    </a>
  </noscript>
</p>
```

Insert above the existing footer tagline (or in an analogous footer slot if a page lacks the standard `<footer>` element). The literal email address MUST NOT appear in any of these files.

**Spanish footer support (Q1, ground-truthed 2026-05-01):** all 14 in-scope HTML pages currently render `<html lang="en">` and have NO existing Spanish-localized variants or runtime locale-toggle harness on the static-content tree. Per operator decision: add Spanish footer support via a lang-aware dict embedded in `/contact.js` (§6.1). The script reads `document.documentElement.lang || 'en'` and selects EN or ES copy from a small inline dict — no per-page Spanish HTML duplication, no build-time templating step. Pages keep `lang="en"` today; future Spanish-localized pages opt in by setting `lang="es"` on the `<html>` element. Both English and Spanish copy land day-one in `/contact.js`.

- [ ] 7.1 **`index.html` (root)** — add placeholder + noscript above the existing "No more midnight phone calls." tagline at lines ~540-541.
- [ ] 7.2 **`demo/index.html`** — add to footer.
- [ ] 7.3 **`demo/dvindex.html`** — add to footer.
- [ ] 7.4 **`demo/hmisindex.html`** — add to footer.
- [ ] 7.5 **`demo/analyticsindex.html`** — add to footer.
- [ ] 7.6 **`demo/reentry-story.html`** — add to footer.
- [ ] 7.7 **`demo/for-cities.html`** — add placeholder to footer (additional CTA edit in §8).
- [ ] 7.8 **`demo/for-coc-admins.html`** — add placeholder to footer (additional CTA edit in §8).
- [ ] 7.9 **`demo/for-coordinators.html`** — add placeholder to footer (additional CTA edit in §8).
- [ ] 7.10 **`demo/for-funders.html`** — add placeholder to footer (additional CTA edit in §8).
- [ ] 7.11 **`demo/outreach-one-pager.html`** — add placeholder to footer (additional CTA edit in §8).
- [ ] 7.12 **`demo/pitch-briefs.html`** — add to footer.
- [ ] 7.13 **`demo/shelter-onboarding.html`** — add to footer.
- [ ] 7.14 **`404.html`** — add to footer.
- [ ] 7.15 **Spanish footer support — lang-aware /contact.js dict (H4 + Q1, ground-truthed 2026-05-01):** all 14 pages stay `lang="en"` today. The Spanish copy lives in `/contact.js` (§6.1) inside a small dict keyed by `document.documentElement.lang` (`en` or `es`; default `en`). The `<noscript>` fallback in HTML stays in the page's primary language (English on all current pages). When a future change Spanish-localizes a page (sets `lang="es"`), that change is responsible for swapping the `<noscript>` copy to Spanish for that page; the JS-injected lead-in copy already supports it. Strings to add to the JS dict in this change:
  - EN lead-in: `"Contact the FABT project team:"`
  - ES lead-in: `"Contacte al equipo del proyecto FABT:"`
  - EN noscript-fallback link text (matches HTML default): `"Contact via GitHub Issues"`
  - ES noscript-fallback link text (for JS-rendered swap on lang=es pages): `"Contacte por GitHub Issues"`
  Spanish copy reviewed by the same AI-synthetic process used for v0.55.1 D2, OR by a real native-Spanish reviewer when one is available — not a release gate.

## 8. Audience-page CTA upgrades

Each audience page gets a context-specific CTA in its existing "next steps" / "get involved" / `.contact` section that consumes the same `class="contact-email"` placeholder. The audience-specific framing is in the *surrounding* copy; the link itself uses the canonical placeholder. Casey-review on funder + cities copy before commit (per `feedback_legal_claims_review`).

- [ ] 8.1 **`demo/for-cities.html`** — add a CTA framed for "municipal or county-government pilot inquiries". Place in the existing CTA block (search for "next steps" or similar header). Include the canonical placeholder + noscript fallback.
- [ ] 8.2 **`demo/for-coc-admins.html`** — add a CTA framed for "pilot CoC inquiries" or "request a deployment-readiness conversation". Place near the existing v0.55 "Reentry-Mode Tenant Flag" section's call-to-action paragraph (cross-link from there to the new contact line).
- [ ] 8.3 **`demo/for-coordinators.html`** — add a CTA framed for "questions your CoC admin can't answer" or "for the project itself, not platform support". Position so it does NOT undercut the existing FAQ entry directing coordinators to their CoC admin for shelter setup (line 65 area).
- [ ] 8.4 **`demo/for-funders.html`** — add a CTA framed for "funding inquiries" or "to schedule a project briefing". Casey-review on the surrounding copy before commit (no "we partner with...", no "every community", per `feedback_legal_claims_review`).
- [ ] 8.5 **`demo/outreach-one-pager.html`** — populate the existing `.contact` div at lines 207-213 ("Contact us to set up a pilot conversation. We'll walk through the platform...") with the canonical placeholder element. Preserve the existing surrounding framing.
- [ ] 8.6 **Casey legal-language review pass** — re-read the diff for #8.1 + #8.4 (cities + funders). Banned phrases checklist: no "guarantees", no "every community", no "always", no real organization names, no fictional pilot citations.
- [ ] 8.7 **Spanish translation keys (Q1 = yes, day-one):** for any audience page that already has Spanish localization, add the new CTA copy keys in the same PR (no English-only fallback to the Spanish locale).

## 9. CI guard against drift

- [ ] 9.1 Author `scripts/ci/check-contact-placeholder.sh` with a **canonical in-scope page list** baked in (not a glob). The list:
  ```
  index.html
  404.html
  demo/index.html
  demo/dvindex.html
  demo/hmisindex.html
  demo/analyticsindex.html
  demo/reentry-story.html
  demo/for-cities.html
  demo/for-coc-admins.html
  demo/for-coordinators.html
  demo/for-funders.html
  demo/outreach-one-pager.html
  demo/pitch-briefs.html
  demo/shelter-onboarding.html
  ```
  For each file, the guard MUST:
  - Confirm the file contains `class="contact-email"`.
  - Confirm the file contains `aria-live="polite"` on the placeholder.
  - Confirm the file contains `/contact.js` (script tag).
  - Confirm the file contains a `<noscript>` block with a GH-issues link.
  - Confirm the file does NOT contain any string matching `/[A-Za-z0-9._%+-]+@findabed\.org/` (catches accidental literal-email check-in).
  - Exit non-zero with a descriptive message naming the offending file and which check failed.
- [ ] 9.2 Run the guard locally; confirm green on a clean tree post-§7 + §8.
- [ ] 9.3 Document the guard in the docs-repo `README.md` or equivalent landing doc.
- [ ] 9.4 (Optional) Wire into a precommit hook or GH Actions workflow on the docs repo. Not blocking for v1; can ship as a follow-up.

## 10. Validation pass — pre-deploy

- [ ] 10.1 Run the §9 CI guard. Expect green (every in-scope file has placeholder + aria-live + script tag + noscript fallback, none has literal address).
- [ ] 10.2 Run the backend test suite (unit + integration). Expect all new tests in §2.3, §3.4, §4.6, §4.7, §4.8 green.
- [ ] 10.3 Run frontend `npm run build` + `npm test` (vitest). Expect §5.5 + §5.9 tests green and the build clean (per `feedback_build_before_commit`).
- [ ] 10.4 Visual diff review — load each modified static HTML page locally with the dev backend running. Confirm placeholder hydrates correctly, footer renders, no styling regression. Also load `/admin` and confirm `ContactSettings` panel renders and saves correctly. ~20 minutes manual.
- [ ] 10.5 **Automated JS-disabled Playwright check (M2):** new spec that loads the root + a few demo pages with `page.context().setJavaScriptEnabled(false)`, asserts no plain-text email in DOM AND that the noscript GH-issues link is visible.
- [ ] 10.6 Banned-words grep across the diff (per `feedback_legal_claims_review` + `feedback_truthfulness_above_all`): zero matches against `/24[ -]?hours?|reply within|respond within|we['']?ll get back|always reply|guarantee|every community/i`.
- [ ] 10.7 Real-name scan: zero matches against the `feedback_no_named_stakeholders_in_docs` real-name list adjacent to any contact placeholder.
- [ ] 10.8 **Lang-aware dict smoke (Q1, replaces the prior `?lang=es` harness check that didn't apply — no static page is currently Spanish):** in a test fixture (or via DevTools), set `document.documentElement.lang = "es"` on a copy of an in-scope page, load `/contact.js`, confirm the JS-injected lead-in renders the ES string. Repeat with `lang="en"` (or unset) — confirm EN renders. Lightweight smoke; not a release gate. The existing audience pages stay `lang="en"` after this change.

## 11. Deploy

- [ ] 11.1 Add `FABT_PLATFORM_CONTACT_EMAIL=<address>` to `~/fabt-secrets/.env.prod` on the Oracle VM **before running `docker compose up --force-recreate`** (H6 wording fix). The compose chain reads the var from `env_file:` at container start; rebuilding the image does NOT bake it in. Without this, the static fallback (D6) renders the GH-issues link instead of the mailto.
- [ ] 11.2 Backend rebuild + redeploy using the v0.55-style Docker compose chain (per `feedback_runbook_compose_chain` — all 4 override files). Verify startup log line confirms `"platform contact email configured: present"`.
- [ ] 11.3 Frontend rebuild + redeploy.
- [ ] 11.4 Static-content scp using the `oracle-update-notes-v0.55.0.md` §5.0 pattern, scoped to:
  - 14 modified HTML files (root `index.html` + `404.html` + 12 `demo/*.html`)
  - 1 new file: `/contact.js`
- [ ] 11.5 Cloudflare Purge Everything (single click in dashboard, 1-2 min refill).
- [ ] 11.6 Post-deploy verification:
  - `curl -sf https://findabed.org/api/v1/public/contact-info | jq` → expect non-empty `platform.email` and `tenant: null`.
  - `curl -sfI https://findabed.org/api/v1/public/contact-info` → expect `Cache-Control: public, max-age=3600`, an `ETag` header, NO `Vary: Authorization`.
  - `curl -sfI -H "Authorization: Bearer $FABT_TEST_JWT" https://findabed.org/api/v1/public/contact-info` → expect `Cache-Control: private, max-age=3600` AND `Vary: Authorization` AND ETag (different from unauthed).
  - `curl -sf https://findabed.org/contact.js` → expect 200 with the shared script.
  - For each of the 14 in-scope HTML URLs: `curl -sf <url> | grep -c 'class="contact-email"'` → expect ≥ 1.
  - Bot-User-Agent test: `curl -sf -A "GoogleBot" https://findabed.org/ | grep -E '@findabed\.org'` → expect zero hits (no plain email in rendered HTML for JS-less requests).
  - Manual click-through: open `https://findabed.org/` in a browser, confirm footer link populates and `mailto:` opens the local mail client.
  - Admin UI smoke: log in as a COC_ADMIN, navigate to `/admin`, confirm `ContactSettings` panel renders and a test save (with a throwaway email) returns a success toast and a TENANT_CONFIG_UPDATED audit row appears.
  - DV-policy admin smoke: switch to a DV-classified tenant; confirm the field is disabled with the localized `dvPolicyDisabled` copy.

## 12. Memory + docs follow-ups

- [ ] 12.1 Save `reference_cloudflare_email_obfuscation_dependency.md` (already enumerated in §1.4 — fold into the same memory write).
- [ ] 12.2 Add a one-line note to `project_live_deployment_status.md` recording the contact-info-API deploy date + git ref + Flyway HWM (unchanged — no new migration).
- [ ] 12.3 (Optional) Add a brief "Contact" entry to the `FOR-DEVELOPERS.md` Recent Changes section noting the email is now public via the `/api/v1/public/contact-info` endpoint and admin-able via `/admin` ContactSettings.
- [ ] 12.4 Update `project_planned_changes_post_analytics.md` to mark `info-email-contact` as shipped and remove from the queue.
- [ ] 12.5 CHANGELOG entry — include a brief security-fixes section (per Q5 = brief security mention). Wording: B1 cache-control split (caught pre-ship by Marcus + Casey + Sam in spec review): the prior draft of the cache-control header would have allowed Cloudflare edge to serve one tenant's authenticated contact-info body to other callers; the shipped design splits cache headers by auth state (`public` for unauthed, `private` + `Vary: Authorization` for authed) to prevent cross-tenant exposure through shared caches. Caught at spec review, never deployed. Sets the cache-control discipline reviewers should apply to future tenant-varying public endpoints. Routine release notes also cover: dedicated PATCH endpoint + ContactSettings UI + DV-policy guard.

## 13. Post-deploy hygiene (within 7 days)

- [ ] 13.1 Monitor inbound `info@` traffic for the first 7 days. Note: spam volume, legitimate inquiry volume, response-time achievable.
- [ ] 13.2 Monitor `fabt_contact_info_requests_total` Micrometer counter to see actual edge-cache hit rate vs origin hits.
- [ ] 13.3 Monitor Bucket4j 429 rate; if zero hits and no scraping pattern emerges, no action. If hits >1% of traffic, investigate whether a legitimate consumer (e.g., a CDN warmup) is hitting the limit.
- [ ] 13.4 If response-time copy becomes operationally backed (e.g., "we respond within 2 business days" is true 95%+ of the time), draft a follow-up change to add `contact.html` with that response-time claim. Otherwise, don't.
- [ ] 13.5 If GH #67 (in-app issue reporting) lands during this window, expand the scope of that change to consume `useContactInfo()` in the React app's Help menu + Report-a-Problem footer (forward-compatibility validated by §5.8).
- [ ] 13.6 Forward-looking: if a survivor-facing authed role is added in a future change, the contact-info endpoint must role-gate the `tenant.email` field (currently visible to all authed tenant members). Add to v0.5x backlog memory if such a role is on the horizon.
