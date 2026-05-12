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

- [ ] 4.1 Add a "Feedback & Support" section to the landing page HTML (below existing content, above footer)
- [ ] 4.2 Add three links: Report a Problem → `report-a-problem.yml`, Request a Feature → `feature-request.yml`, Ask a Question → Discussions Q&A
- [ ] 4.3 All links open in new tab with `rel="noopener noreferrer"`
- [ ] 4.4 Ensure section works in dark mode (`prefers-color-scheme` media query)
- [ ] 4.5 Ensure section reflows at 320px with 44px minimum touch targets

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

- [ ] 6.1 Add CHANGELOG entry for the feedback links feature

## 7. Validation pass

- [ ] 7.1 Run `npm run build` (tsc + vite) — must exit 0.
- [ ] 7.2 Run `npx vitest run src/contact src/components/Layout.test.ts` — all green.
- [ ] 7.3 Run focused Playwright suite for the new specs against `dev-start.sh + nginx` per `feedback_check_ports_before_assuming` — covers: (a) footer "Report a Problem" link on outreach/coordinator/admin, (b) mobile kebab "Help" item, (c) landing page "Feedback & Support" section, (d) DV-policy fixture (footer + kebab → mailto), (e) mailto fallback rendered with non-empty contact-info, (f) mailto-absent regression guard when contact-info is empty, (g) noscript fallback with JavaScript disabled, (h) viewport overflow at 320×568 + 568×320.
- [ ] 7.4 Banned-word grep across the full diff (`git diff main..HEAD -- '*.tsx' '*.ts' '*.json' '*.html'`) — pattern: `always|every|guarantees|ensures|we'?ll respond|response time|will reply` — must return 0 hits in added lines.
- [ ] 7.5 axe-core scan via `accessibility.spec.ts` — zero new violations.
- [ ] 7.6 Verify all new `target="_blank"` links carry `rel="noopener noreferrer"` (grep test: `target=.\"_blank.\".*?rel=.\"noopener` must match every occurrence).
- [ ] 7.7 Real-stakeholder-name scan (`feedback_no_named_stakeholders_in_docs`): grep added lines for documented external-stakeholder names — must return 0 hits.
- [ ] 7.8 Mailto-injection grep: assert no `href="mailto:.*\?` patterns in any new `*.tsx` or HTML. Pattern: `mailto:[^"]*\?` must return 0 hits in added lines.

## 8. CI guard

- [ ] 8.1 Add a small CI script `scripts/ci/check-feedback-link-discipline.sh` (in code repo) that asserts: (a) any `target="_blank"` in `frontend/src/**/*.tsx` is paired with `rel="noopener noreferrer"`, (b) any new GH issue URL is constructed from the allowlisted builder, not inline `https://github.com/.../issues/new?` strings outside the builder file. Wire into `.github/workflows/ci.yml` as a fast lint step.
- [ ] 8.2 Run the guard locally; confirm it returns exit 0 on clean tree and exit 1 when an inline GH issue URL is introduced (mutation test).
- [ ] 8.3 Document the guard in `docs/FOR-DEVELOPERS.md` CI Guards section.

## 9. Deploy notes

- [ ] 9.1 No new env vars; no new Flyway migrations; no backend rebuild required. Static-content scp of the modified landing page + frontend rebuild for `Layout.tsx` changes. Per `feedback_runbook_compose_chain`, frontend rebuild forces frontend container recreate via standard 4-file compose chain.
- [ ] 9.2 Note in the next `oracle-update-notes-vX.Y.Z.md` that the DV-policy authenticated-surface gate is render-time conditional on `useContactInfo().tenant?.dvPolicyEnabled` (sourced from the public `/api/v1/public/contact-info` endpoint per §12, NOT from the JWT) — operators must verify the gate visibly via Playwright fixture before declaring smoke-pass.

## 10. Memory + docs follow-ups

- [ ] 10.1 Add a one-line note to `project_live_deployment_status.md` recording the ship release for issue-reporting-feedback.
- [ ] 10.2 Update `MEMORY.md` index entry for `project_resume_point.md` post-ship.
- [ ] 10.3 Update `FOR-DEVELOPERS.md` Recent Changes section with a brief Issue Reporting + Feedback Links entry.
- [ ] 10.4 Add CHANGELOG entry under the target version (`[v0.57.x]`) covering: footer "Report a Problem" link, mobile kebab "Help" item, landing page Feedback & Support section, DV-policy authenticated-surface mailto fallback, useContactInfo() reuse from info-email-contact.

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
