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

- [x] 3.1 Updated `docs/schema.dbml` line 677 `tenant.config` note to enumerate `contact.email` (string, RFC 5322 max 254 chars, default empty, DV-policy-forbidden when non-empty, empty-PATCH always allowed). AsyncAPI doc surface unchanged because `tenant.config` is internal-only — no async event publishes the JSONB blob; the public `GET /api/v1/public/contact-info` surface (§4) gets its own OpenAPI annotations on `ContactInfoController`.
- [x] 3.2 Authored `org.fabt.tenant.api.ContactEmailRequest`:
  ```java
  public record ContactEmailRequest(
      @Email(message = "email must be a well-formed RFC 5322 address")
      @Size(max = 254, message = "email must be <= 254 characters")
      String email
  ) {}
  ```
  Mirrors `HoldDurationRequest` in style. Hibernate-Validator's `@Email` permits null + empty string by default, so the controller treats both as "clear." Validation messages set explicitly so the GlobalExceptionHandler 400 carries readable text rather than the default `{javax.validation.constraints.Email.message}` placeholder.
- [x] 3.3 Implemented `org.fabt.tenant.api.ContactEmailController` with `PATCH /api/v1/admin/tenants/{tenantId}/contact-email`. **Spec correction:** the original §3.3 instruction to "Do NOT annotate with @PreAuthorize" assumed the SecurityConfig had a role-gating rule for `/api/v1/admin/**`. Ground-truth: SecurityConfig has no such rule — the catch-all is `.anyRequest().authenticated()`, which only requires authentication, not COC_ADMIN. The controller therefore uses `@PreAuthorize("hasRole('COC_ADMIN')")` matching the canonical pattern from `ReservationConfigController` and `DvPolicyController`. Without it, any authenticated role (COORDINATOR, OUTREACH_WORKER) would reach the method body.
  Implementation follows DvPolicyController's STEP 1–5 ordering verbatim:
  - STEP 1: Tenant-scope guard with defense-in-depth audit row on cross-tenant attempt (rejection_code = `tenant.crossTenantAccess`, target_tenant_id captured).
  - STEP 2: Read current value + dv_policy_enabled state once via `tenantService.findById` + `Tenant.isDvPolicyEnabled` (conservative: corrupt config → false).
  - STEP 3: DV-policy guard. Audit emitted FIRST, then `StructuredErrorException(TENANT_CONTACT_EMAIL_DV_POLICY_FORBIDDEN, ...)`. Empty-string normalization (`null` and blank both treated as clear) happens before the guard so empty-PATCH on DV-flagged tenant succeeds.
  - STEP 4: `tenantService.setContactEmail(tenantId, newValue)` — new method handling the nested `contact.email` write (preserves sibling `contact.*` keys; removes `contact` subtree when empty).
  - STEP 5: Applied audit with `value_changed` field distinguishing real flips from idempotent re-sets.
  New error code `ErrorCodes.TENANT_CONTACT_EMAIL_DV_POLICY_FORBIDDEN = "tenant.contactEmail.dvPolicyForbidden"` registered.
- [x] 3.4 Backend integration tests (`ContactEmailControllerTest` — 8/8 green, 29s):
  - `happyPathValidEmail` — 200, persisted, audit row's `new_value` matches.
  - `malformedEmailRejected` — 400, persisted state unchanged.
  - `emptyStringClears` — 200, `contact.email` removed AND `contact` subtree removed (single-key cleanup).
  - `oversizeEmailRejected` — 400 (`@Size`).
  - `dvPolicyForbidsNonEmpty` — 400 with structured `errorCode` + `dv_policy_enabled: true` context + audit row with rejection_code.
  - `dvPolicyAllowsEmptyClear` — 200 (uses direct-JDBC seed via `||`-concat to model "stale override set before flag was enabled").
  - `crossTenantProbe` — 403 + cross-tenant audit row in caller's tenant chain.
  - `coordinatorForbidden` — 403 (`@PreAuthorize` enforces role).

## 4. Backend: public REST endpoint

- [x] 4.1 Implemented `org.fabt.tenant.api.ContactInfoController` exposing `GET /api/v1/public/contact-info`. **Spec correction:** §4.1 assumed SecurityConfig had a `requestMatchers("/api/v1/public/**").permitAll()` rule already; ground-truth showed only `.anyRequest().authenticated()` on the catch-all. Added the `/api/v1/public/**` permitAll rule with this slice — establishes the convention for any future public endpoints. Controller therefore safely lives without `@PreAuthorize` per the spec's intent.
- [x] 4.2 Response shape implemented per spec: unauthed → `{platform, tenant:null}`; authed → `{platform, tenant:{slug, email}}`. Empty/null `email` on either block signals inheritance. Note: in the serialized JSON, an unauthed body's `tenant` key may be elided by Jackson rather than rendered as explicit `null` — frontend consumers (§5.2's `tenantEmail || platformEmail || null` hook) treat absent and null identically.
- [x] 4.3 Cache headers split by auth state implemented per B1:
  - Unauthed 200: `Cache-Control: public, max-age=3600` + ETag, no Vary added by controller (Spring CorsFilter independently adds `Origin, Access-Control-Request-*` Vary entries; controller MUST NOT add `Authorization`).
  - Authed 200: `Cache-Control: private, max-age=3600` + `Vary: Authorization` + ETag.
  - ETag computed as SHA-256 of canonical JSON body, truncated to 16 hex chars (64 bits — sufficient for cache validation; collision threat is accidental, not adversarial). Computed AFTER body assembly; no extra DB read.
  - Spring's MVC `If-None-Match` machinery handles 304 — controller emits 304 Not Modified (no body) when match.
- [x] 4.4 Wired the YAML-declared `rate-limit-public-contact-info` filter in `application.yml` (cap 60 req/min/IP, 1-minute bandwidth window, X-Real-IP-aware cache key per Marcus's B1 fix from `rate-limit-dv-referral-create`). JCache cache name registered in `application.conf` with `after-write=1m` eviction matching the bucket bandwidth window. **Spec correction:** §4.4 requested literal `Retry-After` header; bucket4j-spring-boot-starter 0.14.0 emits `X-Rate-Limit-Retry-After-Seconds` per its convention — kept the platform convention rather than diverging just for this endpoint.
- [x] 4.5 Micrometer counter `fabt.contact_info.requests_total{auth_state, outcome}` emitted on every served request (auth_state ∈ anonymous|authenticated; outcome ∈ 200|304). 429 is owned by the bucket4j filter and not counted at this controller (filter-served responses never reach the method).
- [x] 4.6 - 4.8 Integration tests across two classes (12 tests total, ~30s + 8s):
  - `org.fabt.tenant.api.ContactInfoControllerTest` (10 tests, ~30s):
    - `unauthedPlatformOnly` — unauthed callers see no tenant block.
    - `authedWithNoTenantOverride` — authed callers receive tenant block with email=null (inherit platform).
    - `authedWithTenantOverride` — authed callers see tenant override email (test pre-clears `dv_policy_enabled` so the round-1 H1-Casey suppression does not fire).
    - `unauthedCacheHeaders` — public + max-age + ETag; Vary list does NOT contain Authorization (CORS Vary entries allowed).
    - `authedCacheHeaders` — private + max-age + Vary: Authorization + ETag.
    - `etagDiffersByAuthState` — unauthed ETag != authed ETag.
    - `conditionalGet304` — If-None-Match with current ETag → 304 + ETag echo.
    - `dvPolicyTenantSuppressesContactEmail` (round-1 H1-Casey) — DV-flagged tenant with stale `contact.email` writes returns `tenant.email=null` on read; persisted DB row is unchanged (read-only suppression).
    - `tenantScopingNoCrossTenantLeak` — tenant A and tenant B authed reads each see only their own slug + email; cross-tenant strings absent. Both tenants pre-cleared of `dv_policy_enabled` so the H1-Casey suppression does not mask the test signal.
    - `rateLimitOnBurst` — 70-request burst from one IP yields ≥10 × 429 (60-budget bucket).
    - Test ordering: `@TestMethodOrder(OrderAnnotation)` keeps `rateLimitOnBurst` last (`@Order(99)`); other tests `@Order(1)`. Without ordering, alphabetical default ran the burst BEFORE `unauthed*` and `tenant*` tests, which then hit 429 from the still-empty bucket.
  - `org.fabt.tenant.api.ContactInfoControllerEmptyPlatformTest` (1 test, ~8s, round-1 M1-Riley):
    - `emptyPlatformConfigReturnsEmptyEmail` — `@TestPropertySource(fabt.platform.contact-email=)` exercises the not-yet-deployed branch (operator hasn't set FABT_PLATFORM_CONTACT_EMAIL); response carries `platform.email=""` and `tenant=null`. Lives in a separate class because `@TestPropertySource` is class-scoped.

- [x] 4.W ArchUnit guard `org.fabt.architecture.PublicEndpointAllowlistTest` (round-1 M3-Alex) — enumerates classes permitted to declare `@RequestMapping("/api/v1/public/...")` mappings. Verified to catch a missing-allowlist regression by temporarily removing `ContactInfoController` from the allowlist (test failed with the expected violation message); allowlist restored once verified. Adding a new public endpoint requires both a code change and a paired warroom-approved allowlist entry.

- [x] 4.X DV-policy read-side suppression (round-1 H1-Casey) — `ContactInfoController.buildResponseBody` now returns `tenant.email=null` when `Tenant.isDvPolicyEnabled() == true` regardless of the persisted JSONB value. Defends the temporal-window inconsistency where a tenant set `contact.email` BEFORE enabling `dv_policy_enabled`; the §3 PATCH guard prevents new such writes but does NOT sanitize existing values. Read-side suppression is belt-and-suspenders for the §3 write-side guard.

- [x] 4.Y `Tenant.readContactEmail(JsonString config, ObjectMapper mapper)` shared helper (round-1 M2-Sam) — extracted from controller-private `readContactEmailFromConfig` methods that had drifted into both `ContactEmailController` (audit `old_value` capture) and `ContactInfoController` (response body read). One source of truth eliminates the divergence risk where one method gets a fix the other misses. Mirrors `Tenant.isDvPolicyEnabled` static-helper pattern.

## 5. Frontend: React provider + hook + ContactSettings admin component

- [x] 5.1 Implemented `ContactInfoProvider` in `frontend/src/contact/ContactInfoContext.tsx`. Fetches `/api/v1/public/contact-info` on mount via `api.get`. State stored in `useState<ContactInfoState>` initialized to `{platformEmail:'', tenantEmail:null, resolvedEmail:null, isLoading:true, error:null}`. Loading flag held without clobbering previous values during refetch (prevents email flicker on auth transitions).
- [x] 5.2 Implemented `useContactInfo()` in `frontend/src/contact/useContactInfo.ts` (separate file mirrors `useAuth.ts` pattern). Returns the same `ContactInfoState` shape. The §4 warroom round 1 N2-Riley note about Jackson eliding the unauthed `tenant` key is implemented in `deriveContactInfoState` via `body?.tenant?.email ?? null` — covered by 8 vitest cases pinning both absent-tenant-key and explicit-null-tenant variants identically.
- [x] 5.3 Refetch-on-auth-state-transition: provider's `useEffect` dependency array is `[fetchContactInfo, isAuthenticated, tenantId]`. `fetchContactInfo` is `useCallback([])` so stable; reactivity is on `isAuthenticated` (login/logout transitions) and `tenantId` (future admin-switch-tenant). **Test-coverage boundary:** effect-trigger lives in Playwright, not vitest — explicit javadoc note in `ContactInfoContext.tsx` (round-2 N1-Riley-r2) documents that `decodeJwtPayload.test.ts` is the codebase precedent. Same posture as `AuthContext`.
- [x] 5.4 Wired `<ContactInfoProvider>` in `App.tsx` inside `<AuthProvider>` (so `useContext(AuthContext)` resolves), outside `<BrowserRouter>` (so contact-info state is available on every route). `useContactInfo()` consumed in `LoginPage.tsx` footer; renders `<a href="mailto:${contactEmail}">` line above the version footer when `resolvedEmail` is truthy. Localized prefix `login.contactEmail.prefix`.
- [x] 5.5 Vitest in `frontend/src/contact/ContactInfoContext.test.ts` (8 cases, ~17ms). Pure-helper coverage of `deriveContactInfoState`: elided tenant key, explicit-null tenant key, authed with override, authed with null tenant.email (covers the §4 H1-Casey DV-suppression shape), empty-platform-only (GH-issues fallback case), empty-platform-with-tenant, undefined-body-defensive, missing-platform-email-field. Provider-level effect tests live in Playwright per codebase convention; explicit javadoc note in §5.1 file documents the boundary (round-2 N1-Riley-r2).
- [x] 5.6 Implemented `frontend/src/pages/admin/components/ContactSettings.tsx`. Mirrors `ReservationSettings.tsx` shape verbatim (state: `email`, `dvPolicyEnabled`, `loaded`, `loadFailed`, `saving`, `message`). Reads `tenant.config` via existing `GET /api/v1/tenants/{id}/config` and extracts BOTH `contact.email` AND `dv_policy_enabled` from one fetch. Saves via `PATCH /api/v1/admin/tenants/{id}/contact-email`. **DV-policy gating:** input AND save button disabled when `dv_policy_enabled === true`; localized `admin.contactEmail.dvPolicyDisabled` note rendered (italicized small-print) explaining the path forward. **Defense-in-depth:** `handleSave` has explicit `if (dvPolicyEnabled) return;` guard against any code path bypassing the disabled prop. Auto-dismiss success at 4s, errors persist until next save. Accessibility: `aria-label`, `aria-disabled`, `aria-live="polite"`, `role="alert"`/`role="status"`. **Spec correction:** AuthContext does NOT carry `dv_policy_enabled` (the original spec's "or fetch as part of initial GET-config" branch is the only viable path); implementation reads it from the GET-config payload.
- [x] 5.6 i18n keys (Spanish day-one): 9 `admin.contactEmail.*` keys + 1 `login.contactEmail.prefix` key in BOTH `en.json` AND `es.json`. ES register matches the v0.55+v0.56 admin clusters (`VD` for Violencia Doméstica). The 10 new ES keys are AI-synthetic-reviewed only and logged in `reference_es_json_ai_synthetic_reviewed.md` for the future native-reviewer pass; same posture as the prior 22 admin-facing keys. Added `admin.contactEmail.savedCleared` (not in original spec) so the empty-clear success toast distinguishes from the value-set toast.
- [x] 5.7 Wired `<ContactSettings />` in `AdminPanel.tsx` after `<DvPolicySettings />`, before the tab bar. Exported from `frontend/src/pages/admin/components/index.ts`. AdminPanel access control already gates COC_ADMIN-only; no additional gating needed.
- [x] 5.8 Forward-compat verification: the `useContactInfo()` return shape (`{platformEmail, tenantEmail, resolvedEmail, isLoading, error}`) is the single subscription point for the future GH #67 (Report-a-Problem footer + Help kebab + Feedback&Support landing). Documented as such in the `ContactInfoContext.tsx` javadoc. No additional UI shipped in this change beyond LoginPage footer + ContactSettings admin component, per spec.
- [x] 5.9 Vitest in `frontend/src/pages/admin/components/ContactSettings.test.ts` (8 cases). Pure-helper coverage of `parseContactEmailError` (extracted for vitest per `parseDvPolicyError` precedent): dvPolicyForbidden errorCode match, two beanValidation detail variants (malformed email + >254 chars), generic ApiError without context, empty-string detail (treats as no detail to avoid blank-banner UX), TypeError network failure, non-Error throwables (string, undefined, number defensive), regression guard against a different `tenant.contactEmail.*` errorCode being mistaken for the DV-policy branch. Component-rendering tests (input disabled state, success toast, etc.) are Playwright per codebase convention. The "Empty-string save clears the field (allowed even on DV tenants)" item from the original spec — clarification: the backend allows empty-PATCH on DV tenants per §3, but the admin UI disables the Save button entirely when DV is on; the operator-friendly clearing path requires first disabling DV-policy via DvPolicySettings (5-step path documented for §11 runbook FAQ).

## 6. Static content: shared JS fetcher

- [x] 6.1 Authored `/contact.js` at the docs-repo root (`findABed/contact.js`; served from `findabed.org/contact.js` via the existing static-content nginx rule). Behavior matches spec:
  - Embedded EN/ES i18n dict at the top of the file. `lang` derived from `document.documentElement.lang` with `.toLowerCase().startsWith('es')` matching (defaults to `en`).
  - `hydrateLeadIns(text)` called BEFORE the fetch so the lead-in copy appears even during the fetch window.
  - Single `fetch()` to `/api/v1/public/contact-info` with `Accept: application/json` and `credentials: omit` (this is a public anonymous endpoint; no need to send cookies/auth).
  - On success with non-empty `body.platform.email`: every `<a.contact-email[hidden]>` gets `href="mailto:<email>"`, textContent = email, hidden removed. The `aria-live="polite"` on the element causes screen readers to announce.
  - On any failure (network throw, non-2xx, missing/empty email): all placeholders swap to the GH-issues link with `ghFallback[lang]` text. Single `console.warn` for ops; no spam.
  - IIFE-wrapped + 'use strict'; DOMContentLoaded gated. `defer` script tag handles ordering at the source. Belt-and-suspenders DOMContentLoaded gate covers any browser that ignores `defer` semantics for whatever reason.
- [x] 6.2 Added `<script defer src="/contact.js"></script>` to all 14 in-scope HTML pages near the `</body>` closing tag.

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

- [x] 7.1 `index.html` (root) — placeholder added above the `footer-tagline`. Script tag added before `</body>`.
- [x] 7.2 `demo/index.html` — placeholder added before `</footer>`. Script tag added between `</footer>` and `</body>`.
- [x] 7.3 `demo/dvindex.html` — placeholder + script added.
- [x] 7.4 `demo/hmisindex.html` — placeholder + script added.
- [x] 7.5 `demo/analyticsindex.html` — placeholder + script added.
- [x] 7.6 `demo/reentry-story.html` — placeholder + script added.
- [x] 7.7 `demo/for-cities.html` — placeholder + script added (CTA edit deferred to §8.1).
- [x] 7.8 `demo/for-coc-admins.html` — placeholder + script added (CTA edit deferred to §8.2).
- [x] 7.9 `demo/for-coordinators.html` — placeholder + script added (CTA edit deferred to §8.3).
- [x] 7.10 `demo/for-funders.html` — placeholder + script added (CTA edit deferred to §8.4).
- [x] 7.11 `demo/outreach-one-pager.html` — placeholder added above `footer-tagline` (page has no `<footer>` element). Script tag added before `</body>`. CTA edit deferred to §8.5.
- [x] 7.12 `demo/pitch-briefs.html` — placeholder + script added.
- [x] 7.13 `demo/shelter-onboarding.html` — placeholder + script added.
- [x] 7.14 `404.html` — placeholder added inside `<main>` (page has no `<footer>` element; placeholder placed after the existing tagline). Script tag added before `</body>`.
- [x] 7.15 Spanish footer support — lang-aware `/contact.js` dict landed (§6.1). All 14 pages stay `lang="en"` today. ES strings (`leadIn.es`, `ghFallback.es`) live inside `/contact.js` and only render when a future change sets `lang="es"` on the `<html>` element. The 4 dict strings (2 EN + 2 ES) are AI-synthetic-reviewed only and logged in `reference_es_json_ai_synthetic_reviewed.md` for future native-reviewer pass.

Verification (§6+§7 wrap):
- All 14 pages have exactly 1 `footer-contact-leadin` placeholder + 1 `/contact.js` script reference.
- Precise regex search for actual platform-contact email literals in any of the 14 pages → 0 hits. (The demo seed credentials displayed on `index.html` and `demo/index.html` — `admin@dev.fabt.org`, `coordinator@blueridge.fabt.org`, etc. — are intentional demo-user documentation and are NOT the platform contact email this change is surfacing.)
- All 14 pages have the canonical `<a class="contact-email" href="#" hidden aria-live="polite">contact</a>` placeholder verbatim.

## 8. Audience-page CTA upgrades

Each audience page gets a context-specific CTA in its existing "next steps" / "get involved" / `.contact` section that consumes the same `class="contact-email"` placeholder. The audience-specific framing is in the *surrounding* copy; the link itself uses the canonical placeholder. Casey-review on funder + cities copy before commit (per `feedback_legal_claims_review`).

- [x] 8.1 `demo/for-cities.html` — added new `<h2>Pilot Inquiries</h2>` section before the back-link with copy framed for "municipal or county-government pilot inquiries". Includes the canonical `footer-contact` paragraph with placeholder + noscript fallback. Honest framing: "There is no fixed pilot program today — each conversation starts from the requesting jurisdiction's needs."
- [x] 8.2 `demo/for-coc-admins.html` — added cross-link sentence to the existing reentry-mode CTA paragraph ("For pilot CoC inquiries or to request a deployment-readiness conversation about reentry-mode (or any feature on this page), the project team contact is in the section below.") AND a new `<h2>Pilot CoC Inquiries</h2>` section between the reentry-mode block and the HMIS Connectivity section with the canonical placeholder.
- [x] 8.3 `demo/for-coordinators.html` — added new `<h2>Questions for the Project Team</h2>` section AFTER the Quick Reference table (positioned after the FAQ guidance directing coordinators to their CoC admin, so the project-team CTA does NOT undercut the existing CoC-admin-first message). Lead-in explicitly says "Project-team contact (not for platform support — ask your CoC admin first)".
- [x] 8.4 `demo/for-funders.html` — added new `<h2>Funding Inquiries</h2>` section before the back-link with copy framed for "funding inquiries or to schedule a project briefing". Honest framing: "There are no committed funders or pilot partners to cite today; funding decisions and partnerships will be disclosed transparently as they land."
- [x] 8.5 `demo/outreach-one-pager.html` — restructured the existing `.contact` div at lines 213-217 to host the canonical placeholder INSIDE the div (lead-in + placeholder + noscript fallback + the original 3 reference links preserved as a 4th-line group). Removed the duplicate `footer-contact` paragraph that §6.2 had originally added at this location since the placeholder now lives inside the `.contact` div per §8.5 spec wording.
- [x] 8.6 Casey legal-language review pass — banned-phrase grep across the §8 diff shows 0 hits for `guarantees`, `every community`, `always`, `partner with`, `partnered`, `ensures`. Both for-cities and for-funders explicitly disclose the absence of partnerships and committed pilots. No real organization names introduced. No fictional pilot citations.
- [x] 8.7 Spanish translation keys — verified by `grep` that none of the 5 audience pages currently set `lang="es"` on `<html>`. All 14 in-scope HTML pages stay `lang="en"` per §7.15 ground-truth. §8.7 reduces to no-op verification today; the lang-aware /contact.js dict already carries ES leadIn/ghFallback strings for any future Spanish-localized audience page.

## 9. CI guard against drift

- [x] 9.1 Authored `scripts/ci/check-contact-placeholder.sh` with the canonical 14-page list baked in (not a glob). All 5 per-file checks implemented:
  - `class="contact-email"` placeholder
  - `aria-live="polite"`
  - `/contact.js` script reference
  - `<noscript>` block with a GitHub Issues link (multi-line awk match across the noscript span)
  - forbidden-email regex `[A-Za-z0-9._%+-]+@findabed\.org` returns 0 hits
  - Exit codes: 0 = all checks pass, 1 = check failure (message names file + check + offending line if applicable), 2 = invocation error (canonical-list file missing from filesystem). The exit-2 case catches "page removed without updating the script" drift; the exit-1 case catches the per-page content regression.
  - Bash with `set -eu`. `${BASH_SOURCE[0]}` resolution makes the script work regardless of cwd.
- [x] 9.2 Ran `bash scripts/ci/check-contact-placeholder.sh` on the clean post-§7+§8 tree → exit 0 with `OK: 14 pages pass all 5 checks`. Verified the failure path catches a regression by temporarily mutating `class="contact-email"` → `class="CONTACT_BROKEN"` in `index.html`; the guard reported `FAIL: index.html: missing  class="contact-email"  placeholder element` and returned exit 1. Tree restored.
- [x] 9.3 Added a "CI Guards" section to `README.md` describing the guard, how to run it, and the three exit codes. Updated the Repository Structure tree to enumerate `scripts/ci/check-contact-placeholder.sh` and `contact.js`.
- [ ] 9.4 (Optional, deferred per spec) Wire the guard into a precommit hook or GH Actions workflow. Not blocking for v1; can ship as a follow-up. Today the guard runs manually before any commit that touches the in-scope pages.

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
- [ ] 13.7 (§9 warroom round 1 N1-Riley follow-up) Consider adding a `--selftest` mode to `scripts/ci/check-contact-placeholder.sh` that synthesizes a temp file, mutates it to violate each check in turn, and asserts the guard returns exit 1 with the expected message. Today the failure path was verified manually during §9.2 by mutating `index.html` and restoring; a self-test mode would automate that verification per `feedback_diagnose_dont_iterate`. Not blocking; the manual verification covered the same surface and is documented in the §9.2 as-shipped notes.
