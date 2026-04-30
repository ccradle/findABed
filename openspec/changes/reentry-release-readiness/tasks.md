## 1. Branch + warroom audit gate

- [x] 1.1 Create branch `feature/reentry-release-readiness` in BOTH repos (docs repo + code repo). Per `feedback_branch_correct_repo`, do not cross-commit. **Done 2026-04-30:** docs repo branched off main `12d10ab` (origin/main pre-this-session); code repo branched off main `6ad8ee6` (post-PR-167 merge of transitional-reentry-support).
- [x] 1.2 ~~Convene a warroom round on proposal/design/specs~~ — **completed 2026-04-30 as Warroom Round 3** (24-persona pass + web-grounded PII research). Findings synthesized into Decisions D9, D10, D11; three new Risks; new `reservation-pii-hardening` capability spec; new tasks.md §13 hardening section; thirteen direct edits applied to existing artifacts. Lineage captured in `design.md` "Warroom rounds" section.
- [x] 1.3 **`/opsx:verify` mode=pre-implementation** on the change after the Round 3 + Round 4 edits. **Done 2026-04-30:** verify ran clean — 4/4 artifacts done, 8/8 capabilities have spec files, 29 requirements / 64 scenarios, every requirement has ≥1 scenario, all scenarios use exactly 4 hashtags, legal-language scan clean, stakeholder-name scan clean, section heading order §1→§15 sequential, no active "24 hours" claims (only historical/comparison context), all 10 Round 4 edits (E1-E10) applied. Spec ready for /opsx:apply.

## 2. Live-site truthfulness (the "ever" cluster)

- [x] 2.1 **Root `index.html` (docs repo)** — scope the "no client name… ever" claim to the DV referral path only. One paragraph edit. Verify post-edit that no platform-wide zero-PII assertion remains.
- [x] 2.2 **`docs/government-adoption-guide.md` (code repo) :73** — rewrite the DV-zero-PII bullet to distinguish DV path (zero-PII opaque-token, 24h hard delete) from non-DV opt-in path (encrypted, scoped, 24h purge).
- [x] 2.3 **`docs/government-adoption-guide.md` (code repo) :117–130** — add scoping sentence to VAWA-protection section stating v0.55 hold-attribution PII is NOT used in the DV referral path; cite the V91 `shelter_dv_implies_dv_type` CHECK constraint by name.
- [x] 2.4 **`docs/government-adoption-guide.md` (code repo) :121** — rewrite the "Zero client PII" bullet as three explicit bullets: (a) DV path = zero PII, (b) non-DV opt-in path = encrypted, scoped, purged, (c) operator chooses.
- [x] 2.5 **`docs/hospital-privacy-summary.md` (code repo) lines 28–46** — rewrite the "What FABT Never Stores" table from one-column "Never" to two-column DV-path / navigator-hold-path. Hospital social worker is a navigator-role audience.
- [x] 2.6 **`docs/hospital-privacy-summary.md` (code repo) BAA section** — update to state: no BAA needed if hospital workflow does not use the optional fields; using them is a HIPAA conversation the hospital privacy officer must own.
- [x] 2.7 **`docs/FOR-COC-ADMINS.md` (code repo) :84, :108** — append one-sentence DV-scope addendum to each existing zero-PII claim.
- [x] 2.8 **`docs/FOR-CITIES.md` (code repo) :108** — append one-sentence DV-scope addendum.
- [x] 2.9 **`docs/FOR-DEVELOPERS.md` (code repo) :849** — append one-sentence DV-scope addendum after the "Zero client PII in the database" claim.

## 3. Architectural doc sync

- [x] 3.1 **`docs/asyncapi.yaml` (code repo)** — audit all 12 sites of "ZERO client PII" (lines 152, 170, 184, 405, 659, 1092, 1093, 1103, 1139, 1223, 1430, 1461 — verify still current at edit time). DV-event sites stay verbatim. Reservation-event-related sites get an explicit note that hold-attribution PII is server-side-only and not emitted over AsyncAPI by design.
- [x] 3.2 **`docs/schema.dbml` (code repo)** — regenerate from the live schema reflecting V91-V95 (shelter_type, county, requires_verification_call, eligibility_criteria GIN index, reservation `_encrypted` columns, tenant_dek.purpose extension). Add comment to the reservation entity noting the `_encrypted` columns are crypto-shred-managed.
- [x] 3.3 **`docs/erd.svg` (code repo)** — regenerate from the updated DBML (use `@softwaretechnik/dbml-renderer` per the convention from `feedback_update_docs_with_code`).
- [x] 3.4 **`docs/architecture.md` (code repo)** — add a `transitional-reentry-support` section parallel to the existing dv-opaque-referral section. ~200 words. Cover taxonomy, encrypted-reservation-pii sub-module, feature flag, purge job. Cite the OpenSpec change archive path.
- [x] 3.5 **`docs/architecture/tenancy-model.md` (code repo)** — add one paragraph (~50 words) on the new `tenant_dek.purpose='RESERVATION_PII'` tenant-scoped key.

## 4. Operational claim → verifiable signal

- [x] 4.1 **`docs/security/compliance-posture-matrix.md` (code repo)** — add a new "Hold-attribution PII" section naming the `_encrypted` columns, the per-tenant DEK envelope, and the 24h purge contract. State explicitly what survives the purge (the row sans ciphertext; auditing-relevant metadata).
- [x] 4.2 **`docs/security/compliance-posture-matrix.md` (code repo)** — add Purge SLA row honestly disclosing that `fabt.reservation.pii_purge.success.count`, `fabt.reservation.pii_purge.lag_seconds`, and the failure alert are NOT YET WIRED in v0.55. Include the manual / log-parsing alternative an operator can use today.
- [x] 4.3 **`docs/oracle-update-notes-v0.55.0.md` (code repo)** — add §6.5 PII purge verification section. At least one command confirms the `@Scheduled` purge bean is registered. At least one SQL/container command confirms a purged row's ciphertext columns are NULL beyond the SLA window. Acknowledge the metric gap.
- [x] 4.4 **`CHANGELOG.md` (code repo) v0.55 entry** — add a `### Privacy / Security` subsection. Three sentences: opt-in PII collection, per-tenant DEK encryption, "no later than 25 hours" purge contract (per D10), pointer to government-adoption-guide.md and hospital-privacy-summary.md updates.
- [x] 4.5 **`docs/operations/reentry-mode-user-guide.md` (code repo)** — update §5 "PII purge behavior for hold-attribution columns" to use "no later than 25 hours" wording (consistent with D10 + §11.1a). Add a paragraph naming the three new audit-event types from §13.A.1 (`RESERVATION_HELD_FOR_CLIENT_RECORDED`, `RESERVATION_PII_DECRYPTED_ON_READ`, `RESERVATION_PII_PURGED`) and how an operator running forensic queries grep them out of `audit_event`. Verify §6 (or whichever section names the schedule) is consistent with the post-D11 15-minute cadence; no stale "1-hour" references. (Per Round 4 Devon DK-RR-1 — without this update, the operator-training doc and the UI ship contradictory SLAs.)

## 5. Missing-but-cited doc

- [x] 5.1 **Verify** `docs/legal/right-to-be-forgotten.md` does not exist (already verified — confirm at edit time).
- [x] 5.2 **Author** `docs/legal/right-to-be-forgotten.md` (~400 words minimal version per design D5, Open Question 3). Sections: self-hosted-vs-SaaS scope; the 24h hold-attribution PII purge as automated retention; deferral statement directing data-subject access requests to the deployment owner; explicit "no GDPR/CCPA position taken at v0.55" sentence.
- [x] 5.3 **Update** `docs/security/compliance-posture-matrix.md:110` reference to confirm the now-existing file path.

## 6. Demo story page (`reentry-story.html`)

- [ ] 6.1 **Author `demo/reentry-story.html` (docs repo)** — follow story-warroom Part 3 outline. Heading hierarchy: one h1 + five h2 (the morning, what the navigator sees, the hold, when the answer is no, what this changes — and what it doesn't). Lede paragraph names a synthetic client + synthetic navigator (NOT Demetrius — Demetrius's quote may be cited anonymously). No platform/system jargon before second h2.
- [ ] 6.2 **Casey-voice scrub** — every claim about the platform's reentry capability uses "designed to support" or equivalent; no "compliant with," no "guarantees," no "ensures."
- [ ] 6.3 **Keisha-voice scrub** — banned words list per story warroom: ex-offender, returning citizen, felon, offender, justice-involved, individuals with criminal histories, formerly incarcerated individuals, reentering population. Use: people leaving incarceration, people on supervision, people with a record, the client.
- [ ] 6.4 **Tomás-voice scrub** — heading hierarchy uses real `<h2>`/`<h3>`, not styled divs. Alt text on every screenshot describes what the navigator LEARNS, not what the rectangle shows. Color-coded chip states have a text label rendered in-screenshot.
- [ ] 6.5 **No fictional pilots/partnerships/stakeholders** — grep the page for real NC reentry organization names, real city names, real CoC names. Zero matches.

## 7. Reentry capture spec + screenshot capture

- [ ] 7.1 **Verify V95 seed includes failure-path conflict** for `reentry-06` (a county where the only reentry shelter excludes a specific offense type). If absent, decide between: (a) add V96 seed amendment, OR (b) construct the conflict dynamically in the test. Decision in capture-spec implementation per design D7 + Open Question 4.
- [ ] 7.2 **Author `e2e/playwright/tests/capture-reentry-screenshots.spec.ts` (code repo)** — six tests, one per screenshot: `reentry-01-advanced-search-filters`, `reentry-02-search-results-filtered`, `reentry-03-shelter-detail-eligibility`, `reentry-04-hold-dialog-attribution`, `reentry-05-admin-reservation-settings`, `reentry-06-no-match-failure-path`. Output dir `../../../../demo/screenshots/`. Mirror the auth fixture + seed setup pattern from `capture-dv-screenshots.spec.ts`.
- [ ] 7.3 **Run capture spec end-to-end** against local dev stack with V95 reentry seed loaded + `features.reentryMode=true` for `dev-coc`. Expect 6 PNGs produced.
- [ ] 7.4 **Verify Tomás-critical capture conditions** — `reentry-03` must have `CriminalRecordPolicyDisclaimer` rendered ABOVE the eligibility data; `reentry-04` must show the hold-dialog with synthetic name/DOB/notes filled (no real persona data); `reentry-06` must show the policy-conflict failure path.

## 8. Capture script update (`capture.sh`)

- [ ] 8.1 **`demo/capture.sh` (docs repo)** — enumerate all ten capture specs explicitly (one invocation or one entry per spec): the existing nine + the new `capture-reentry-screenshots.spec.ts`.
- [ ] 8.2 **`demo/capture.sh` (docs repo)** — add a positional filter argument that runs only the matching spec(s); exit 0 if at least one matched, non-zero if none matched.
- [ ] 8.3 **`demo/capture.sh` (docs repo)** — set `BASE_URL=http://localhost:8081` (nginx) as the default; honor explicit overrides.
- [ ] 8.4 **Smoke-test the updated capture.sh** — run with no args; verify all ten specs invoke. Run with `reentry`; verify only the reentry spec invokes. Run with a non-matching string; verify non-zero exit.

## 9. Cross-page edits (consolidated per design D5)

- [ ] 9.1 **Root `index.html` (docs repo)** — add the 5th tile to the "See It Work" grid pointing to `demo/reentry-story.html`. Headline + 1-line description per story warroom Part 6.
- [ ] 9.2 **`demo/for-coordinators.html` (docs repo)** — add a paragraph (post-FAQ, pre-footer) distinguishing the navigator role from the outreach-worker role; cross-link to `reentry-story.html`. ~60 words.
- [ ] 9.3 **`demo/for-cities.html` (docs repo)** — add a sentence acknowledging reentry / justice-system-adjacent populations as a use case the platform supports. ~30 words. No real-stakeholder names.
- [ ] 9.4 **`demo/for-funders.html` (docs repo)** — add a sentence acknowledging reentry as a distinct use case. ~25 words. No real-stakeholder names.
- [ ] 9.5 **`demo/dvindex.html` (docs repo)** — add reciprocal "see also" link in footer pointing to `demo/reentry-story.html`.

## 10. Screenshot drift check on existing high-traffic shots

- [ ] 10.1 **Re-capture** `01-login.png`, `02-bed-search.png`, `06-coordinator-dashboard.png`, `09-admin-users.png` against current main + nginx (BASE_URL=http://localhost:8081). Use the updated `capture.sh` from §8.
- [ ] 10.2 **Visual-diff** each new shot against the committed PNG. Per design Open Question 6, threshold = "operator judgment" — replace any with meaningful semantic drift (new tabs, new buttons, layout shifts).
- [ ] 10.3 **Document** which shots were replaced and why in the change commit message. If none, document that no drift was found.

## 11. PII help text on UI surfaces (per D6 + D9 + D10)

- [ ] 11.1 **`frontend/src/i18n/en.json` (code repo)** — add help-text keys: `hold.help.clientName`, `hold.help.clientDob`, `hold.help.notes`, `shelter.eligibility.notes.help`. Copy intent per D6 + D10 (Keisha-voiced, affirmative-bound truthful per Round 4 C-RR-2): e.g., "Optional. The shelter coordinator will see this so they know who to expect. Erased automatically no later than 25 hours after the hold ends." Adapt per field.
- [ ] 11.1a **Update existing `hold.clientAttributionPrivacyNote` key** (`frontend/src/i18n/en.json:723` + `frontend/src/i18n/es.json:723`) — replace "within 24 hours" / "dentro de 24 horas" with "no later than 25 hours" / "a más tardar 25 horas" (per D10 + Round 4 C-RR-1 + C-RR-2). Per Round 4 C-RR-1, the existing key already ships with the OLD wording; without this edit, the user would see contradictory copy (existing privacy note "within 24 hours" alongside new help text "no later than 25 hours") inside the same HoldDialog. Verify no other i18n key carries the old "within 24 hours" wording — grep both en.json and es.json for "24 hours" / "24 horas" and reconcile.
- [ ] 11.2 **`frontend/src/i18n/es.json` (code repo)** — add the same four keys with Spanish translations. Verify against Spanish-language reviewer (block on real review pre-tag if available; otherwise mark for v0.55.1 follow-up rather than ship machine-translated).
- [ ] 11.3 **`frontend/src/components/HoldDialog.tsx` (code repo)** — add **always-visible help text** (per D9, NOT hover tooltips) BELOW each PII input (client name, DOB, notes textarea). Each input gets `aria-describedby="<id>-help"`, and the `<p id="<id>-help">` carries the i18n string. Keyboard reachable; screen-reader announces on focus.
- [ ] 11.4 **`frontend/src/components/EligibilityCriteriaSection.tsx` (code repo)** — add always-visible help text below the notes textarea advising operators that free-text may capture client-identifying detail. Same `aria-describedby` pattern as §11.3.
- [ ] 11.5 **`npm run build` (code repo `frontend/`)** — must pass; no missing i18n keys.
- [ ] 11.5a **Mobile + a11y Playwright spec** — author `e2e/playwright/tests/hold-dialog-mobile-pii.spec.ts` exercising 320×568, 375×667, and 768×1024 viewports. Assert per Round 4 X3 convergence: (a) all three help-text elements render visible without opening any `<details>` disclosure (DK-RR-4 — help text MUST NOT be hidden behind disclosure); (b) at 320×568, the `hold-dialog-confirm-button` SHALL be `inViewport` after opening any `<details>`, filling all three PII fields, and scrolling to the bottom of the dialog (Devon DK-RR-2); (c) `aria-describedby` on each PII input resolves to a present help-text node with non-empty text content (Riley R-RR-4); (d) help-text element has the `data-testid` attribute per `feedback_data_testid` (e.g., `data-testid="hold-help-client-name"`).
- [ ] 11.6 **Add `data-testid` to each help-text element** per `feedback_data_testid` so future Playwright tests can assert presence without brittle DOM selectors.
- [ ] 11.7 **`backend/src/main/java/org/fabt/reservation/api/ReservationResponse.java` (code repo)** — add `@Schema(description="Optional PII; encrypted at rest with per-tenant DEK (purpose RESERVATION_PII); purged no later than 25h after terminal status. Returned only on detail-view endpoints.")` on each of the three PII fields. **Mirror the same `@Schema` description onto the detail-view DTO** produced by §13.D.1 (e.g., `ReservationDetailResponse.java` or whatever name the implementer chooses for the new type). Per Round 4 Alex A-RR-3: this single task subsumes what was previously §13.D.5; do not duplicate the @Schema work in two places.

## 12. Validation pass — pre-archive

- [ ] 12.1 **Live-site claim audit** (script-driven if possible, manual grep otherwise) — fetch `https://findabed.org/` after the §2.1 fix lands locally + check that no platform-wide "ever" / "never client name" / "zero PII" claim remains unscoped. Repeat for `for-cities.html`, `for-coc-admins.html`, `for-funders.html`, `for-coordinators.html`.
- [ ] 12.2 **Screenshot drift check** completed (§10) and documented.
- [ ] 12.3 **Capture spec runs green** end-to-end via updated `capture.sh` (§7.3 + §8.4).
- [ ] 12.4 **ZAP-baseline note** — document that `docs/security/zap-v0.55-baseline.md` is deferred to a follow-up slice (it's in proposal Out of Scope). Confirm the deferral is captured in v0.56 backlog.
- [ ] 12.5 **Backend test suite** runs green (`mvn -B test -q` in code repo) — backend code is unchanged but verify the doc-only edits didn't break any test that grep's documentation files.
- [ ] 12.6 **Frontend build + Playwright suite** runs green (`npm run build` + `npx playwright test --reporter=list` in code repo `e2e/playwright`).
- [ ] 12.4.5 **Spanish translations non-identical to English** — for every new i18n key added in §11.1 / §11.2, assert the `es.json` value differs from the `en.json` value (catches "translation forgotten" silent failures).
- [ ] 12.5.5 **Scheduled-invocation integration test** — add a backend Spring integration test that calls the `@Scheduled` purge entry point (no args) and asserts a non-DV tenant's row is nulled. This catches the `TenantContext` wiring issue Riley flagged (R-RR-1).
- [ ] 12.6.5 **axe-core run on `demo/reentry-story.html`** — run via Playwright; zero violations required (ADA Title II, Tomás TO-RR-2).
- [ ] 12.7 **Legal language scan** runs clean (per `feedback_legal_claims_review` + `feedback_legal_scan_in_comments`) — grep all touched files for "compliant," "ensures," "guarantees," "equivalent to," "secure," "fully," "complete," "comprehensive," "certified," "audited" — replace with "designed to support" or specific factual statements. **Scan code comments + JavaDoc**, not just user-facing prose; `Reservation.java:22` JavaDoc currently says "plaintext is never persisted to disk" — verify or revise.
- [ ] 12.7.5 **Banned-words automated grep** (per Keisha K-RR-1) — script-level grep across `demo/reentry-story.html` AND every doc touched in §2 / §3 / §4 / §5 / §9 for the banned-words list: ex-offender, returning citizen, felon, offender, justice-involved, individuals with criminal histories, formerly incarcerated individuals, reentering population. Zero matches required. Suggested: add as a CI guard script under `scripts/ci/` so future changes can't reintroduce.
- [ ] 12.8 **Stakeholder-name scan** runs clean — grep all touched files for the names of real NC cities, real CoCs, real reentry programs, real hospitals. Zero matches.

## 13. v0.55 implementation hardening (Path A scope expansion per D11)

> Per Decision D11 + warroom Round 3, three blockers (audit events missing, DOB-in-logs, 24h ≠ 25h) cannot be closed by doc edits alone. Five SHOULD-FIX items ride along. This section MUST complete before §14 archive.

### 13.A — Audit events for hold-attribution PII (BLOCKER I-1, capability `reservation-pii-hardening`)

- [ ] 13.A.1 **`backend/src/main/java/org/fabt/shared/audit/AuditEventType.java` (code repo)** — add three enum cases: `RESERVATION_HELD_FOR_CLIENT_RECORDED`, `RESERVATION_PII_DECRYPTED_ON_READ`, `RESERVATION_PII_PURGED`. JavaDoc each with the audit-payload contract (reservation id + tenant id + actor user id only; no plaintext, no ciphertext).
- [ ] 13.A.2 **`backend/src/main/java/org/fabt/reservation/service/ReservationService.java` (code repo)** — wire emitter at `doCreateReservation`: when any of `heldForClientName / heldForClientDob / holdNotes` is non-null on the create request, emit `RESERVATION_HELD_FOR_CLIENT_RECORDED` (after the row commit but inside the same transaction context, per existing audit pattern).
- [ ] 13.A.3 **Read-side emitter (throttled)** — wire emitter at the decryption site (likely `ReservationRepository` row mapper or a service-layer wrapper). Throttle to one audit row per `(coordinator user id, shelter id, hour)` tuple via a Caffeine cache or equivalent. Emit `RESERVATION_PII_DECRYPTED_ON_READ`.
- [ ] 13.A.4 **Wire emitter inside `ReservationService.purgeExpiredHoldAttribution(Instant)` (code repo)** — emit `RESERVATION_PII_PURGED` AFTER the bounded-loop in §13.C.2 completes for the current cutoff (not inside the `@Scheduled` wrapper in `ReferralTokenPurgeService`). Emitting at the service layer ensures the audit row's `purgedCount` reflects the total across all sub-runs of the LIMIT-bounded UPDATE. One audit event per scheduled invocation, payload `{purgedCount, cutoff}`.
- [ ] 13.A.5 **Backend tests** — for each of the three emitters, add an integration test that exercises the trigger and asserts the audit row appears with the expected payload shape AND no plaintext.

### 13.B — Sanitize DOB-validation exception (BLOCKER I-2)

- [ ] 13.B.1 **`backend/src/main/java/org/fabt/reservation/service/ReservationService.java:121-122` (code repo)** — replace the exception message `"heldForClientDob must be after " + floor + "; got " + dob` with `"heldForClientDob must be on or after 1900-01-01"` (drop user-supplied input from the message). Verify the 400 response body and the JSON log line both omit the offending DOB.
- [ ] 13.B.2 **Backend test** — add a unit test asserting that the exception message for an invalid DOB does NOT contain the user-supplied DOB string. Grep guard if needed.
- [ ] 13.B.3 **Sweep `ReservationService` for other PII concatenation** — grep for `+ heldFor`, `+ holdNotes`, etc. in any string-concat that could flow into log messages or exception messages. Convert to structured logging or generic messages.

### 13.C — Tighten purge cadence + bound UPDATE (BLOCKER I-10 + SHOULD-FIX I-4 + I-5)

- [ ] 13.C.1 **`backend/src/main/java/org/fabt/referral/service/ReferralTokenPurgeService.java:88` — `purgeExpiredHoldAttribution` method ONLY** (code repo) — change THIS method's `@Scheduled(fixedRate=3_600_000)` to `@Scheduled(fixedDelay=900_000)` (15 minutes, see §13.C.1a for the fixedRate→fixedDelay rationale). Update the JavaDoc to state the rationale per D10 (worst-case 24h15m, well under the public "no later than 25 hours" claim). **Do NOT change line 47's `purgeTerminalTokens` method** — that's the DV referral_token purge; its 1-hour cadence is independent (VAWA retention design) and out of scope for this change. A literal find-and-replace of `fixedRate = 3_600_000` would catch both — name the method explicitly when editing.
- [ ] 13.C.1a **Overlapping invocation guard** — the chosen annotation is `@Scheduled(fixedDelay=900_000)` rather than `fixedRate=900_000`. Per Round 4 Sam S-RR-2: `fixedRate` does NOT prevent a new run from spawning while a prior run is still executing. On Oracle Always Free's 1 vCPU, a 50K-row backlog could keep a prior invocation running 10-25 seconds, and a `fixedRate` scheduler would launch a second invocation overlapping the first — both holding row locks on the same `UPDATE ... LIMIT 10000` batch. `fixedDelay` measures the interval between the END of one run and the START of the next, eliminating overlap. JavaDoc on the method MUST state the choice and the rationale.
- [ ] 13.C.2 **`backend/src/main/java/org/fabt/reservation/repository/ReservationRepository.java:135-153` (code repo)** — add `LIMIT 10000` to the purge `UPDATE` (e.g., `UPDATE reservation SET ... WHERE id IN (SELECT id FROM reservation WHERE ... LIMIT 10000)`). Wrap the call in a service-layer loop that re-runs until `purgedCount=0` for the current cutoff, accumulating into a single audit event per scheduled run (per §13.A.4).
- [ ] 13.C.3 **Backend test** — load-style integration test with >10,000 candidate rows; assert all are purged within a single scheduled invocation; assert exactly one `RESERVATION_PII_PURGED` audit row is emitted with `purgedCount` matching the total.

### 13.D — Drop list-view PII; cache headers; @Schema annotations (SHOULD-FIX I-3 + I-8 + I-9)

- [ ] 13.D.0 **`backend/src/main/java/org/fabt/reservation/api/ShelterReservationsController.java:78-80` Swagger description rewrite** (code repo, was §13.E.1, moved here per Round 4 Alex A-RR-4 because this edit must land WITH §13.D.2 to keep the description coherent) — remove the stale "PLATFORM_ADMIN" reference (deprecated G-4.4) and stop enumerating `heldForClientName`/`heldForClientDob`/`holdNotes` field names because per §13.D.2 the list view will return null for those fields. Use the current role taxonomy from G-4.4 (COORDINATOR-assigned-to-shelter or COC_ADMIN-in-tenant). Operation description SHOULD describe semantics ("list of held reservations for the shelter"), NOT the PII payload shape (which is now empty on list).
- [ ] 13.D.1 **Implement detail endpoint per design D12** — NEW `GET /api/v1/reservations/{id}/detail` on `ReservationController`. Authorization: COORDINATOR-assigned-to-shelter OR COC_ADMIN-in-tenant. The endpoint decrypts and returns the PII fields under the read-side audit emitter (§13.A.3) and the cache headers (§13.D.4).
- [ ] 13.D.2 **`backend/src/main/java/org/fabt/reservation/api/ReservationResponse.java` (code repo)** — modify the list-view response factory (`from(r)` or equivalent) to set `heldForClientName / heldForClientDob / holdNotes` to `null` regardless of underlying ciphertext. Add `hasHoldAttribution: boolean` indicator.
- [ ] 13.D.3 **`backend/src/main/java/org/fabt/reservation/api/ShelterReservationsController.java` (code repo)** — confirm list endpoint uses the list-view DTO; the chosen detail endpoint (per §13.D.1) returns the detail-view DTO with PII + the read-side audit emitter (§13.A.3).
- [ ] 13.D.4 **Cache headers** — add `Cache-Control: no-store, private` response headers on the detail-view endpoint(s) chosen in §13.D.1. Use `ResponseEntity.ok().header(...)` or a `@CacheControl` filter.
<!-- 13.D.5 STRUCK per Round 4 Alex A-RR-3 — duplicate of §11.7. The @Schema annotation work lives entirely under §11.7; if §13.D.1 produces a separate detail-view DTO type, §11.7's update SHALL mirror onto that type. -->
- [ ] 13.D.6 **Frontend cascade for list-view PII drop** — per Round 4 Alex A-RR-2, this is a multi-file change, not one bullet. Affected files (verify each at edit time; some names may differ slightly):
    1. `frontend/src/api/types/ReservationResponse.ts` (or equivalent type file) — make `heldForClientName`, `heldForClientDob`, `holdNotes` OPTIONAL; add `hasHoldAttribution: boolean`; add a separate `ReservationDetailResponse` type for the new detail-view endpoint (per design D12) that carries the PII fields as required strings.
    2. `frontend/src/pages/OutreachSearch.tsx` — "My Holds" section: stop reading PII fields from list responses; show `hasHoldAttribution` indicator + click-to-detail behavior.
    3. `frontend/src/pages/CoordinatorDashboard.tsx` — hold-list rendering: same change as outreach.
    4. New data-fetch path (likely a new hook or service method, e.g., `useReservationDetail`) that calls `GET /api/v1/reservations/{id}/detail` and renders the PII payload in a detail-modal or detail-route.
    5. Playwright tests — grep `e2e/playwright/tests/` for `heldForClientName`, `heldForClientDob`, `holdNotes` assertions on list responses; convert each to either (a) an indicator assertion (`hasHoldAttribution: true`) on list, OR (b) a click-to-detail flow that reads PII from the detail endpoint.
- [ ] 13.D.6a **Verify no orphan PII reads remain** — after §13.D.6 lands, grep the entire frontend for `heldForClientName` / `heldForClientDob` / `holdNotes` references and confirm each is either (a) on the detail-view path, or (b) explicitly typed as optional + null-safe.
- [ ] 13.D.7 **Backend + frontend tests** — assert list endpoints return `null` for PII fields; assert detail endpoint returns plaintext under the read-side audit emitter; assert `Cache-Control: no-store, private` on detail responses.

### 13.E — Module boundary + Swagger description cleanup (SHOULD-FIX, in-scope as low-cost wins)

<!-- 13.E.1 MOVED to §13.D.0 per Round 4 Alex A-RR-4 — the Swagger description rewrite must land WITH §13.D.2 to keep the description coherent (which now claims null PII fields on list view). Section §13.E now has no tasks; if a future fix in this category emerges before tag, it lands here. -->
- [ ] 13.E.1 ~~Moved to §13.D.0.~~ This bullet remains as a placeholder to preserve task numbering; the work itself is now §13.D.0.

### 13.F — Verification of hardening before §14 archive

- [ ] 13.F.1 **`mvn test`** runs green in the code repo with all new §13 tests included. No skipped tests; no flake suppressions.
- [ ] 13.F.2 **`docs/security/compliance-posture-matrix.md` re-review** — confirm the now-existing audit events are documented in the matrix's audit-events section; the metric-gap row is preserved (the metric is still pending — only the audit emitter ships in v0.55).
- [ ] 13.F.3 **Live-stack smoke** — local dev-start.sh, place a hold with attribution, decrypt-on-read via coordinator dashboard detail, force purge via the scheduled invocation; verify all three audit rows appear in `audit_events` with payloads matching §13.A contract.

## 16. `features.reentryMode` UI gating (D13 implementation, Path Y per warroom Round 5)

> Path-Y scope expansion landed via warroom Round 5 (Marcus Webb + Alex + Riley + Tomás + Casey + Maria, 2026-04-30). Three BLOCKERs raised vs initial plan: (B1) refresh path strips claim, (B2) `CoordinatorDashboard.tsx` was a 4th unguarded PII surface, (B3) prod demo tenants would show no reentry UI post-deploy. Revised approach: API-serialization gate (defense-in-depth) + frontend gates (UX polish) + post-deploy runbook step. See warroom output and `transitional-reentry-support/design.md` D13 for context.

### 16.A — Backend: JwtService claim emission (BLOCKER B1)

- [x] 16.A.1 **Add `TenantService` dep to `JwtService`** — constructor injection. Use `tenantService.getConfig(UUID)` (line 166) which returns merged-with-defaults `Map<String, Object>` and centralises JSONB null-safety. Do NOT inject `TenantRepository` directly.
- [x] 16.A.2 **Private helper `loadReentryMode(UUID tenantId): boolean`** — reads `config.get("features")` cast safely as Map; reads `features.get("reentryMode")` and coerces to boolean (`Boolean.TRUE.equals(...)` so non-boolean values produce false; missing key produces false). Wrap in Caffeine cache, `expireAfterWrite=Duration.ofSeconds(60)`, `maximumSize=10_000`.
- [x] 16.A.3 **Centralise claim emission** — emitted at every JWT-issuance site: both `generateAccessToken` overloads + `generateAccessTokenWithPasswordChange` call `loadReentryMode(user.getTenantId())` directly when building the payload. Refresh path in `AuthController` is covered because it calls one of the existing methods.
- [x] 16.A.4 **Verify `PlatformJwtService` is unaffected** — separate class; platform users have no tenant.config. Pinning tests in `PlatformJwtServiceTest` (3 cases — access, mfa-setup, mfa-verify) decode each platform-token payload and assert `reentryMode` key is absent. Regression guard per warroom N3.
- [x] 16.A.5 **Backend tests** for `JwtService` claim emission — `JwtServiceReentryModeClaimTest` (8 cases): flag=true → true; flag=false → false; features-without-reentryMode-key → false; config-without-features-map → false; tenantService throws → false (fail-safe); null tenantService (legacy wiring) → false; password-change variant carries claim; second call hits cache (single getConfig invocation).
- [x] 16.A.6 **OAuth2AccountLinkService** (`backend/src/main/java/org/fabt/auth/service/OAuth2AccountLinkService.java:55, :76`) — calls `jwtService.generateAccessToken(user)`, so picks up the helper change for free; no source change needed.

### 16.B — Backend: API serialization gate (BLOCKER B2 — defense-in-depth)

- [ ] 16.B.1 **`ReservationResponse.java` serialization** — modify `from(Reservation)` factory (or wherever PII fields are populated) to read `reentryMode` from request context (e.g., `TenantContext` or a new `ReservationResponseContext`). When false → `heldForClientName`, `heldForClientDob`, `holdNotes` SHALL be null in the response regardless of underlying ciphertext. The §13.D list-view-PII-drop work (already in spec) composes with this — same gate, broader scope.
- [ ] 16.B.2 **Pass `reentryMode` to serialization** — likely simplest: a request-scoped Spring bean reads from JWT claims (already in `Authentication.principal`) and `ReservationResponse.from()` consults it. Alternative: add a parameter to `from(Reservation, boolean reentryMode)` and update all callers — preferred IF callers are localized.
- [ ] 16.B.3 **Backend tests** — `ReservationResponseTest`: (a) reentryMode=true → PII fields populated from ciphertext; (b) reentryMode=false → PII fields null even if ciphertext present; (c) decrypt-on-read path still works for navigator detail-view IFF reentryMode=true.

### 16.C — Frontend: AuthContext + four gating sites (BLOCKER B2 second half)

- [ ] 16.C.1 **`frontend/src/auth/AuthContext.tsx`** — add `reentryMode: boolean` to `DecodedUser` interface (lines 3-11). Update `decodeJwtPayload` (line 32-56) to parse `payload.reentryMode === true` (default false on missing/non-bool).
- [ ] 16.C.2 **`frontend/src/pages/OutreachSearch.tsx`** — wrap the advanced-filters section (county dropdown + shelter-type chips + accepts-felonies tri-state) in `{user?.reentryMode && (<section data-testid="reentry-advanced-filters">...</section>)}`. Confirm conditional-render pattern (NOT `display:none` / `aria-hidden` per warroom N1).
- [ ] 16.C.3 **`frontend/src/pages/ShelterForm.tsx`** — wrap the `EligibilityCriteriaSection` invocation AND the `requires_verification_call` toggle in `{user?.reentryMode && (...)}`. Add `data-testid="reentry-eligibility-section"`.
- [ ] 16.C.4 **`frontend/src/components/HoldDialog.tsx`** — wrap the `<details>` element containing the PII fields. Add `data-testid="reentry-pii-fields"`.
- [ ] 16.C.5 **`frontend/src/pages/CoordinatorDashboard.tsx`** (lines 142, 1216, 1247-1252) — fourth gating site missed by initial plan, surfaced by warroom B2. Wrap `hold.heldForClientName` renders in `{user?.reentryMode && (...)}`. This is defense-in-depth — the API gate at §16.B is the primary control; this prevents the rendering layer from being a parallel-path leak surface.
- [ ] 16.C.6 **Vitest tests** per gating site: render with mock context flag=true vs flag=false, assert presence/absence via `data-testid`.

### 16.D — Playwright E2E matrix (HIGH H1)

- [ ] 16.D.1 **New spec `e2e/playwright/tests/reentry-mode-gate.spec.ts`** — happy-path matrix. Test 1: login as outreach@blueridge.fabt.org (reentry tenant after seed flip in §16.E) → assert `[data-testid="reentry-advanced-filters"]` visible. Test 2: login as outreach@dev.fabt.org (non-reentry tenant) → assert same selector NOT visible. Test 3: login as cocadmin@blueridge.fabt.org → admin shelter-edit → assert eligibility section visible. Test 4: cocadmin@dev.fabt.org → eligibility section hidden.
- [ ] 16.D.2 **Existing reentry-* Playwright specs** — review `reentry-search-filters.spec.ts`, `reentry-eligibility-display.spec.ts`, `reentry-hold-dialog.spec.ts`, `reentry-integrated-navigator.spec.ts`. Each may break post-gate if their seed user's tenant doesn't have reentryMode=true. Either update the auth fixture's seed setup OR have each spec call `PATCH /api/v1/admin/tenants/{id}/config` to flip the flag in `beforeAll`. Recommend the latter — per `feedback_isolated_test_data` tests should create their own state.

### 16.E — Seed + tenant config (BLOCKER B3 — prod-tenant flip)

- [ ] 16.E.1 **Local dev seed UPDATE** — `UPDATE tenant SET config = jsonb_set(config, '{features,reentryMode}', 'true'::jsonb) WHERE slug IN ('dev-coc-east','dev-coc-west');`. Apply to running DB; reentry UI surfaces for these two tenants. Also set `holdDurationMinutes=180` on dev-coc-east for shot 05.
- [ ] 16.E.2 **`dev-coc` stays unset** — original demo tenant continues to behave as v0.54 did. This is intentional — demonstrates the gate works; ungated tenants are a known shape.
- [ ] 16.E.3 **`docs/oracle-update-notes-v0.55.0.md` new §7 step (BLOCKER B3)** — add post-deploy task: identify which prod demo tenants should have reentryMode=true (likely `blueridge` and `mountain` per `project_live_demo_seed_inventory`); apply `UPDATE tenant SET config = jsonb_set(coalesce(config,'{}'::jsonb), '{features,reentryMode}', 'true'::jsonb) WHERE slug IN ('blueridge','mountain');`. Without this, the demo site will look broken (no reentry UI for any visitor). Alternative: a Flyway V96 conditional migration — deferred per "data, not schema" rationale.

### 16.F — Spec + doc updates (HIGH H4)

- [ ] 16.F.1 **`reentry-release-readiness/proposal.md`** — adjust scope statement: change is no longer doc-only; add a §G.X "v0.55 implementation hardening + UI gating" item summarizing §16.
- [ ] 16.F.2 **`reentry-release-readiness/design.md`** — add D14 "reentryMode UI gate (Path Y, warroom Round 5)" citing the JWT-claim pattern matching `dvAccess`, the API-serialization defense-in-depth, fail-safe-default-off, 15-min token-TTL-bounded propagation, and prod-tenant flip in runbook §7.
- [ ] 16.F.3 **`transitional-reentry-support/design.md` D13** — update with implementation status: was "design intent"; becomes "implemented at code:<sha> as part of reentry-release-readiness §16; JWT-claim + API-serialization-gate + frontend-conditional-render".
- [ ] 16.F.4 **`docs/operations/reentry-mode-user-guide.md` §1** — rewrite to be ACCURATE post-implementation. Remove misleading "enables UI features" framing if any; describe the actual behavior: enabling the flag surfaces advanced filters, eligibility section, and PII fields; CoC-administrator-level decision; default off.
- [ ] 16.F.5 **`docs/security/compliance-posture-matrix.md` Hold-attribution PII section** — add a row noting "Default tenant configuration does not surface PII fields; CoC administrator must affirmatively enable `features.reentryMode` to expose them."
- [ ] 16.F.6 **`CHANGELOG.md` v0.55 Privacy/Security subsection** — add one sentence: "Reentry-specific UI (advanced filters, eligibility, hold-attribution PII fields) is now gated behind the `features.reentryMode` tenant configuration flag; default off."
- [ ] 16.F.7 **`docs/government-adoption-guide.md`** — strengthen the "may optionally collect" wording to "PII fields are not surfaced in the UI unless the CoC administrator enables `features.reentryMode`."

### 16.G — Verification + commit gate

- [ ] 16.G.1 **`mvn test`** GREEN — all backend tests including §16.A.5 + §16.B.3.
- [ ] 16.G.2 **`npm run build`** GREEN — frontend compiles; no missing types.
- [ ] 16.G.3 **Live-stack manual verification** — login as outreach@dev.fabt.org → no reentry UI; login as outreach@blueridge.fabt.org (after §16.E.1 UPDATE) → reentry UI visible. Confirm advanced filters, eligibility section, HoldDialog PII fields, CoordinatorDashboard past-holds list ALL gated correctly.
- [ ] 16.G.4 **API-gate verification** — direct REST call as outreach@dev.fabt.org against `GET /api/v1/shelters/{id}/reservations` → assert PII fields are null in response (defense-in-depth confirmed). Repeat as outreach@blueridge.fabt.org → assert PII present (when reentryMode=true).
- [ ] 16.G.5 **Playwright matrix** (§16.D.1) GREEN.

## 14. Archive and tag (the release gate)

- [ ] 14.1 **Open PR for `feature/reentry-release-readiness`** in BOTH repos (docs repo + code repo). Cross-link the two PRs in their descriptions. Reference both this OpenSpec change AND `transitional-reentry-support` in commit messages.
- [ ] 14.2 **CI green** on both PRs. E2E may have pre-existing failures per the v0.55 long-tail triage (memory: post-merge CI on `6ad8ee6`); confirm no new regressions vs that baseline. **Backend tests must include all new §13.A / §13.B / §13.C / §13.D tests.**
- [ ] 14.2.5 **Pre-archive `/opsx:verify`** on BOTH `transitional-reentry-support` AND `reentry-release-readiness`. Per Alex A-RR-4: archive sequence aborts if either is failing. If `reentry-release-readiness` archive fails after `transitional-reentry-support` is archived, immediately un-archive transitional-reentry-support manually and surface in chat.
- [ ] 14.3 **Merge code-repo PR to main** — doc edits, schema.dbml, erd.svg, asyncapi.yaml, tooltips, capture spec.
- [ ] 14.4 **Merge docs-repo PR to main** — index.html edits, demo HTML pages, capture.sh, OpenSpec change directory.
- [ ] 14.5 **`/opsx:archive transitional-reentry-support`** — paired-archive prerequisite. Per design D4, this archives FIRST because it's the underlying capability.
- [ ] 14.6 **`/opsx:archive reentry-release-readiness`** — archives second. Per design D4, this is the readiness gate that depends on the underlying capability.
- [ ] 14.7 **Post-archive smoke** — grep both `openspec/changes/` directories to verify both changes have moved to `archive/`.
- [ ] 14.8 **Tag `v0.55.0`** on code repo `main`. Per design Open Question 7, code repo tag is canonical; docs repo gets a corresponding commit but no tag.

## 15. Combined deploy + post-deploy validation

- [ ] 15.1 **Pre-deploy gates** — re-run all pre-deploy gates from `docs/oracle-update-notes-v0.55.0.md` §4 against the v0.55.0 tag. Per `feedback_runbook_groundtruth_vm`, ground-truth on the live VM, not from memory.
- [ ] 15.2 **Deploy** per `docs/oracle-update-notes-v0.55.0.md` §5. Single-stage; 5-file compose chain.
- [ ] 15.3 **Post-deploy smoke** per `docs/oracle-update-notes-v0.55.0.md` §6 mandatory smoke gate.
- [ ] 15.4 **§6.5 PII purge verification** (the new section authored in §4.3) — run the operator commands; document the output in the deploy log.
- [ ] 15.5 **Live-site claim verification** — fetch `https://findabed.org/` post-deploy; verify the "ever" claim is gone; verify the new `demo/reentry-story.html` is reachable and renders; verify all cross-page links work.
- [ ] 15.6 **Demo flow walkthrough** as `outreach@blueridge.fabt.org` — exercise the reentry advanced filters, hold dialog with attribution, verify tooltips render, confirm the failure-path scenario (filter for a county where the only reentry shelter excludes a specific offense type) renders the expected UI state.
- [ ] 15.7 **Demo flow walkthrough** as `cocadmin@blueridge.fabt.org` — open Reservation Settings, verify the hold-duration field is editable and persists.
- [ ] 15.8 **Update memory** — `project_resume_point.md` + `project_live_deployment_status.md` per `feedback_periodic_resume_save`. Mark v0.55 deployed; record the paired-archive sequence; capture the metric-gap follow-up as a v0.56 backlog item with explicit memo.
- [ ] 15.9 **Surface follow-ups** — Tier 2 deferred docs (PRIVACY.md, threat-model.md, dek-rotation-policy.md, zap-v0.55-baseline.md) added to v0.56 backlog tracker; Tier 3 (audit-event-catalog.md) too; the for-navigators.html audience card filed as a future change pending lived feedback.
