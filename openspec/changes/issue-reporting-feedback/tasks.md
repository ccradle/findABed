## 1. i18n Messages

- [x] 1.1 Added `feedback.reportProblem` to `en.json:795` + `es.json:795`.
- [x] 1.2 Added `feedback.help` to `en.json:797` + `es.json:797`.
- [x] 1.3 Added `feedback.requestFeature` to `en.json:798` + `es.json:798`.
- [x] 1.4 Added `feedback.askQuestion` to `en.json:799` + `es.json:799`.

## 2. Footer "Report a Problem" Link

- [x] 2.1 Added `<FooterReportProblemLink>` inside the `Layout.tsx` footer (`Layout.tsx:622-641`), below the version text + tenant-name line. Footer un-gated so it renders even when `appVersion` is null (per warroom H5).
- [x] 2.2 URL constructed via `buildReportProblemUrl(appVersion)` in `ReportProblemLink.tsx:45-53` using `URLSearchParams` with `template=report-a-problem.yml` + `labels=triage` (privacy allowlist enforced).
- [x] 2.3 `appVersion` is null-guarded in `buildReportProblemUrl`: when truthy → `fabt_version={value}` appended; when null/undefined → param omitted entirely. Tests will cover both branches in §5.
- [x] 2.4 Primary link sets `target="_blank"` + `rel="noopener noreferrer"` (conditional — omitted on DV-policy mailto branch since mailto: doesn't need them).
- [x] 2.5 `<FormattedMessage id="feedback.reportProblem" />` rendered on the primary link.
- [x] 2.6 Link uses `<a href>` semantic (focusable by default), inherits browser focus ring + theme color, has descriptive text via `feedback.reportProblem` ("Report a Problem"). WCAG 2.4.4 + 2.4.7 met.
- [x] 2.7 `useContactInfo()` consumed in `FooterReportProblemLink`. Secondary `mailto:{resolvedEmail}` link renders below the primary GitHub link when `resolvedEmail` is non-empty AND DV-policy is OFF (on DV-policy ON, primary IS the mailto so no second).
- [x] 2.8 `<noscript>` fallback added to `frontend/index.html:10-21` outside `#root` so React mounting does NOT touch it. Shows a static GitHub issues index link when JavaScript is disabled.
- [x] 2.9 Added `feedback.reportProblem.email` i18n key to en.json:796 + es.json:796 ("Email the project team" / "Enviar correo al equipo del proyecto").
- [x] 2.10 `shouldRouteToMailto(tenant?.dvPolicyEnabled, resolvedEmail)` in `ReportProblemLink.tsx:80-84` gates the primary link `href`. When DV-policy ON + resolvedEmail present → `mailto:{resolvedEmail}`; otherwise → GitHub URL. Sourced from `useContactInfo()`, NOT from JWT.
- [ ] 2.11 Add Playwright fixture for a DV-policy-on tenant; mock `useContactInfo()` to return `{dvPolicyEnabled: true, resolvedEmail: '...'}`; verify the footer link href is `mailto:`, not `github.com`.
- [x] 2.12 Vitest cases for `deriveContactInfoState.dvPolicyEnabled` true/false/absent/anon shipped in Phase 1-2 commit `c886ffc` (4 new tests at `ContactInfoContext.test.ts:106-160`). 12/12 green.

## 3. Mobile Kebab Menu "Help" Item

- [x] 3.1 Added `<a>` element with `data-testid="header-overflow-help"` in `Layout.tsx:541-565`, positioned between Security and Sign Out items.
- [x] 3.2 Primary `href` builds from `buildIssueChooserUrl()` (`https://github.com/ccradle/finding-a-bed-tonight/issues/new/choose`) when DV-policy OFF.
- [x] 3.3 `data-testid="header-overflow-help"` on the `<a>` element.
- [x] 3.4 `role="menuitem"` + `minHeight: '44px'` + `boxSizing: 'border-box'` mirrors the existing menu-item button style.
- [x] 3.5 `onClick={() => setKebabOpen(false)}` closes the kebab on tap.
- [x] 3.6 `<FormattedMessage id="feedback.help" />` rendered as the link text.
- [x] 3.7 DV-policy gate via `shouldRouteToMailto(tenant?.dvPolicyEnabled, resolvedEmail)` at `Layout.tsx:92-94`. When DV-policy ON + resolvedEmail present, kebab `href` is `mailto:{resolvedEmail}` and `target/rel` are omitted; otherwise the GH issue chooser opens in a new tab with `noopener noreferrer`.
- [ ] 3.8 Playwright test (mobile viewport, DV-policy tenant): kebab Help item href is mailto:.
- [ ] 3.9 Playwright test (platform-operator session): kebab Help item href falls through to GitHub (not mailto).

## 4. Landing Page "Feedback & Support" Section

- [x] 4.1 Added `<section class="section section-alt" aria-labelledby="feedback-heading">` to root `index.html`, positioned between the Open Source section and `</main>` (above the footer).
- [x] 4.2 Three links wired: Report a Problem → `report-a-problem.yml` template; Request a Feature → `feature-request.yml` template; Ask a Question → `discussions/categories/q-a`. Each carries `data-testid="landing-feedback-{...}"` for Playwright selectors.
- [x] 4.3 All three links use `target="_blank"` + `rel="noopener noreferrer"`.
- [x] 4.4 Section uses `var(--accent)` for link border/text — picks up the existing `@media (prefers-color-scheme: dark)` block at `index.html:68` automatically (root-level CSS variables are theme-aware).
- [x] 4.5 `display: flex; flex-wrap: wrap; gap: 12px; justify-content: center;` on the link container; each link has `min-height: 44px; min-width: 44px; box-sizing: border-box`. Reflows to single-column stacking on 320px viewports. Verified existing placeholder CI guard `bash scripts/ci/check-contact-placeholder.sh` → `OK: 14 pages pass all 5 checks` post-edit.

## 5. Tests (10 Playwright + 1 axe + 1 build)

- [ ] 5.1 Playwright test: footer "Report a Problem" link exists on outreach, coordinator, and admin pages
- [ ] 5.2 Playwright test: footer link href contains `report-a-problem.yml` and `target="_blank"`
- [ ] 5.3 Playwright test: footer link includes app version in URL
- [ ] 5.4 Playwright test: mobile kebab menu includes "Help" item with `data-testid="header-overflow-help"`
- [ ] 5.5 Playwright test: Help menu item opens correct URL in new tab
- [ ] 5.6 Playwright test: landing page "Feedback & Support" section has 3 links with correct hrefs
- [ ] 5.7 axe-core scan: verify zero new violations after changes (existing accessibility.spec.ts)
- [ ] 5.8 Run `npm run build` to verify frontend compiles clean
- [ ] 5.9 Playwright test: mailto fallback renders when API returns non-empty email (mock fixture).
- [ ] 5.10 Playwright test: mailto link absent when API returns empty email (regression guard against broken mailto:).
- [ ] 5.11 Playwright test (javaScriptEnabled: false): noscript fallback renders the GH issues index link.
- [ ] 5.12 Playwright test: at viewport 320×568 and 568×320, the kebab dropdown opens, all 6 items are reachable, and the dropdown does not push beyond the visible viewport. If overflow occurs, the dropdown SHALL scroll internally.

## 6. Documentation

- [x] 6.1 Added `[v0.57.4]` CHANGELOG entry (`CHANGELOG.md` top) covering all surfaces (footer link, kebab Help, landing-page section, DV-policy gate, backend dvPolicyEnabled field, noscript fallback, i18n keys, CI guard). Includes the 3-rounds-of-warroom process disclosure.

## 7. Validation pass

- [x] 7.1 `npm run build` (tsc + vite) → exit 0, 67 modules built in 1.31s during Phase 3.
- [x] 7.2 `npx vitest run src/contact` → 12/12 green in 554ms during Phase 1-2 (4 new dvPolicyEnabled cases + 8 pre-existing). Layout.test.ts not used in this codebase — vitest scope is `src/contact` per existing convention.
- [ ] 7.3 Run focused Playwright suite for the new specs against `dev-start.sh + nginx` per `feedback_check_ports_before_assuming` — covers: (a) footer "Report a Problem" link on outreach/coordinator/admin, (b) mobile kebab "Help" item, (c) landing page "Feedback & Support" section, (d) DV-policy fixture (footer + kebab → mailto), (e) mailto fallback rendered with non-empty contact-info, (f) mailto-absent regression guard when contact-info is empty, (g) noscript fallback with JavaScript disabled, (h) viewport overflow at 320×568 + 568×320. **DEFERRED to §5 testing phase** (next session) — requires dev-start.sh + nginx running.
- [x] 7.4 Banned-word grep across diff (both repos) for `always|every|guarantees|ensures|we'?ll respond|response time|will reply` — **0 hits** in added lines (verified Phase 5).
- [ ] 7.5 axe-core scan via `accessibility.spec.ts` — zero new violations. **DEFERRED to §5 testing phase** alongside other Playwright work.
- [x] 7.6 `target="_blank"` + `rel="noopener noreferrer"` pairing verified by the new `scripts/ci/check-feedback-link-discipline.sh` guard (Python multi-line JSX-element-aware). Local run + mutation test confirm exit 0 / exit 1 contract.
- [x] 7.7 Real-stakeholder-name scan (`feedback_no_named_stakeholders_in_docs`): grep added lines for `Dickerson|Whitfield|Monroe|Sandra Kim|Devon Kessler` → **0 hits** (verified Phase 5).
- [x] 7.8 Mailto-injection grep: `mailto:[^"]*\?` against diff → **0 hits** (verified Phase 5).

## 8. CI guard

- [x] 8.1 `scripts/ci/check-feedback-link-discipline.sh` written + wired into `.github/workflows/ci.yml` as the new `feedback-link-discipline` job alongside `legal-language`. Bash entry point delegates to Python for multi-line JSX-element-aware matching (bash/grep handled per-line, which gave false positives on properly-paired multi-line JSX attributes).
- [x] 8.2 Local clean-tree run → exit 0 with "ok: all feedback-link-discipline assertions pass". Mutation test (injected inline `https://github.com/.../issues/new?...` URL into Layout.tsx) → exit 1 with `FAIL: ... inline GitHub issue URL — must use buildReportProblemUrl()` message. Restore → exit 0. Both assertions verified end-to-end.
- [x] 8.3 Documented in `docs/FOR-DEVELOPERS.md` Recent Changes "In-app Issue Reporting + Feedback Links (v0.57.4)" entry — explicit mention of `scripts/ci/check-feedback-link-discipline.sh` enforcing both URL-builder discipline AND target/noopener pairing.

## 9. Deploy notes

- [x] 9.1 Verified scope: no new env vars; no Flyway migration (HWM stays V98); backend `ContactInfoController` IS rebuilt (small delta — `dvPolicyEnabled` field on response); frontend rebuilds for `Layout.tsx` + new `ReportProblemLink.tsx` + `index.html` `<noscript>` block. Per `feedback_runbook_compose_chain`, frontend + backend rebuild forces both containers recreate via standard 4-file compose chain. Documented in CHANGELOG `[v0.57.4]` Added section.
- [ ] 9.2 **DEFERRED to release-runbook drafting** — next `oracle-update-notes-vX.Y.Z.md` (when this change is grouped into a release) must include the DV-policy authenticated-surface gate verification step: operators visit a DV-policy-on tenant in a browser and confirm the footer "Report a Problem" link has `href="mailto:..."`, not `github.com/.../issues/new?...`. Playwright fixture (§3.8) automates the same check in CI.

## 10. Memory + docs follow-ups

- [ ] 10.1 **DEFERRED to post-ship** — `project_live_deployment_status.md` one-liner records the ship release after `oracle-update-notes-vX.Y.Z.md` deploy lands. Cannot land pre-ship because the version + commit ref are not known yet.
- [ ] 10.2 **DEFERRED to post-ship** — `MEMORY.md` index entry refresh happens during the post-ship memory-update step (`project_resume_point.md` gets a new state stanza).
- [x] 10.3 "In-app Issue Reporting + Feedback Links (v0.57.4, planned)" section added to `docs/FOR-DEVELOPERS.md` Recent Changes (above the existing v0.57 Platform + Per-Tenant Contact Email entry). Covers URL allowlist + DV-policy gate sourcing + small backend delta + JS-disabled fallback + 3-rounds-of-warroom process disclosure.
- [x] 10.4 `[v0.57.4]` entry added to `CHANGELOG.md` top — see §6.1 above for content summary. Identical entry serves both §6.1 and §10.4 per Keep-a-Changelog convention.

## 11. 7-day post-deploy hygiene

- [ ] 11.1 Monitor inbound mailto traffic at the platform contact email for the first 7 days: DV-tenant-origin volume vs GH-link-origin volume. (No instrumentation needed; operator-side mailbox observation.)
- [ ] 11.2 If GH-link click volume is observed to be non-trivial (e.g., via referrer headers landing on the FABT GH org), confirm no PII has leaked into the public issue corpus via a sample audit of issues filed in the 7-day window.
- [ ] 11.3 If the kebab "Help" item shows zero or near-zero use vs the footer link in any operator anecdote during the 7-day window, consider deprecating the kebab item in a follow-up change to reduce the mobile-menu item count.

## 12. Backend: extend ContactInfoController response

(per round-2 B1 — required so the DV-policy gate has a source-of-truth readable by OUTREACH and COORDINATOR roles, not just COC_ADMIN)

**EXECUTION ORDER:** §12 backend tasks (12.1–12.7) land BEFORE the §9 deploy notes / §10–§11 post-deploy work. This section is appended at the file's end for diff readability; treat it as a §5-adjacent prerequisite during /opsx:apply.

- [x] 12.1 `ContactInfoController.buildResponseBody` now puts `dvPolicyEnabled` (boolean) into the tenant block. Refactored the DV-policy evaluation to compute once and use both for read-side email suppression AND the new render-time signal. Source: `ContactInfoController.java:188-194`.
- [x] 12.2 Verified: unauthed callers receive `tenant: null` (existing behavior preserved — `callerTenantId == null` branch at line 166-169 returns early without populating the tenant block). Platform-operator with no bound tenant takes the same branch. New regression test `unauthedHasNoTenantBlock` asserts the response body string never contains "dvPolicyEnabled" for anon callers.
- [x] 12.3 Added 3 new tests to `ContactInfoControllerTest`: `authedDvPolicyOnIncludesDvPolicyEnabledTrue` (lines 273-292), `authedDvPolicyOffIncludesDvPolicyEnabledFalse` (lines 294-307), `unauthedHasNoTenantBlock` (lines 309-329). All placed in the new "DV-policy render-time signal" section between the existing DV-suppression test and tenant-scoping.
- [x] 12.4 `ContactInfoContext.tsx`: extended `ContactInfoState` with a nested `tenant: { slug, email, dvPolicyEnabled } | null` matching the response shape; extended `ContactInfoResponse` interface; updated `deriveContactInfoState` to construct the tenant object with `dvPolicyEnabled === true` strict-check (defaults absent/non-boolean to false for stale-response defense); updated `INITIAL_STATE` + fetch-error fallback to include `tenant: null`.
- [x] 12.5 OpenAPI/response-shape docs: backend `@Operation` description and `getContactInfo` Javadoc already enumerate the response shape; no explicit OpenAPI YAML lives in-tree (Swagger UI introspects at runtime). DBML confirmed no-op at `docs/schema.dbml:677` per round-3 N1.
- [ ] 12.6 Backend mvn test re-verify (`mvn test -Dtest=ContactInfoControllerTest,ContactInfoControllerEmptyPlatformTest`) — **DEFERRED to CI on the PR**: requires Postgres via dev-start.sh which is not running in this session per `feedback_use_dev_start_script`. Code-repo CI runs the full backend suite on every PR push and will catch any regression.
- [x] 12.7 Frontend vitest re-verify: `npx vitest run src/contact` → 12/12 tests green in 554ms (8 original + 4 new dvPolicyEnabled cases). Verified 2026-05-12.
