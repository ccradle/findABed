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

- [x] 6.1 **`demo/reentry-story.html`** authored at v1 (1,446 visible words). h1 + 5 h2 (the morning Andre walks out / what the navigator sees / placing the hold / when no shelter in the county matches / what this changes — and what it doesn't) + reciprocal "see also" footer. Synthetic protagonist Andre; navigator unnamed. NO platform/system jargon before §2 (verified). Two warroom rounds applied.
- [x] 6.2 **Casey-voice scrub** — pass. "Designed to support reentry coordination with explicit privacy posture and a default-off PII surface." No "compliant with," no "guarantees," no "ensures." HIGH-C1 fixed: "shares the optional PII fields only with the shelter coordinator the navigator placed the hold with, plus the CoC's admin staff who are authorized to read those fields" replaced overclaim.
- [x] 6.3 **Keisha-voice scrub** — pass. Banned-words grep returns zero. "felony"/"felonies" appear as offense-category nouns (in operational chip language, never as person-labeling); "felon" / "offender" / "ex-offender" / "returning citizen" / "justice-involved" / "individuals with criminal histories" / "formerly incarcerated" / "reentering population" all absent. HIGH-Dm1 quote tightened with friction beat ("The rest of the work is mine."). MEDIUM-K1 fixed: "for someone like Andre" → "for Andre" (Andre is a person, not a category).
- [x] 6.4 **Tomás-voice scrub** — pass. Real `<h2>` elements (not styled divs). `<section aria-labelledby>` per section. Six `<img>` elements with alt text describing what the navigator LEARNS not what the rectangle shows. `<nav aria-label="See also">` wrapping footer links. MEDIUM-T1 fixed: `<strong>` moved to "two hours left" (operational stake) from "a confirmed bed for tonight". MEDIUM-T2 fixed: §4 transition paragraph added. MEDIUM-T3 fixed: "Active chips render filled-solid; inactive chips render outline-only" — non-color cue for colorblind users.
- [x] 6.5 **No fictional pilots/partnerships/stakeholders** — pass. The only NC-specific name is "Onslow County" (a real NC county that matches the V95 seed-data shelter "Onslow Womens Reentry"). No real CoC names, no real reentry-org names, no fictional pilots, no fictional partnerships. Andre is a synthetic first name; the navigator and the shelter coordinator are unnamed.

## 7. Reentry capture spec + screenshot capture

- [x] 7.1 **V95 seed verified to support reentry-06 failure path.** Onslow Womens Reentry has `excluded_offense_types=[SEX_OFFENSE, ARSON]` + Henderson Reentry House has `[SEX_OFFENSE, ARSON, VIOLENT_FELONY]`. No V96 amendment needed. The actual reentry-06 capture uses an even cleaner empty-state path: TRANSITIONAL + Buncombe + accepts-felonies → 0 results because Mountain View Transitional has no eligibility data, triggering the §8/§9 H4 empty-state banner ("No matching shelters. The 'accepts felonies' filter excludes shelters with no eligibility data on file.").
- [x] 7.2 **`e2e/playwright/tests/capture-reentry-screenshots.spec.ts`** authored (313 lines, 6 tests). Inline tenant-scoped login + storage-state injection so the spec targets `dev-coc-east` (where the V95 reentry shelters live with `features.reentryMode=true` seeded). Auth pattern: outreach@pamlico.fabt.org for navigator-perspective shots (1-4, 6); cocadmin@pamlico.fabt.org for admin shot (5).
- [x] 7.3 **Capture spec runs 6/6 GREEN** end-to-end against `dev-start.sh --nginx` with V95 seed loaded. Six PNGs produced in `../../../../demo/screenshots/`.
- [x] 7.4 **Tomás-critical capture conditions verified visually**: reentry-03 shows the CriminalRecordPolicyDisclaimer rendered ABOVE the criminal_record_policy section (accepts_felonies=Yes + excluded_offense_types=Sex offense, Arson + VAWA notice + policy notes). reentry-04 shows the §11 Round 2 dialog shape: privacy note OUTSIDE the disclosure (always visible), per-input help text INSIDE the disclosure with "Andre Synthetic" / 1985-06-15 / synthetic note pre-filled. reentry-06 shows the empty-state banner ("No matching shelters") + "0 shelters found" + the active-filter chips visible.

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

- [x] 11.1 **`frontend/src/i18n/en.json`** — added 4 help-text keys: `hold.help.clientName`, `hold.help.clientDob`, `hold.help.notes`, `shelter.eligibility.notes.help`. Keisha-voiced, "no later than 25 hours" wording per D10 + C-RR-2.
- [x] 11.1a **Reconciled existing `hold.clientAttributionPrivacyNote`** (en + es) from "within 24 hours" / "dentro de 24 horas" to "no later than 25 hours" / "a más tardar 25 horas". `apiKey.rotateConfirmMessage` "24 hours" reference is unrelated (API-key rotation grace window) and intentionally untouched.
- [x] 11.2 **`frontend/src/i18n/es.json`** — Spanish translations for all 4 new keys + the privacy-note reconciliation. Spanish copy was warroom-output drafted (Casey/Keisha voice), not machine translation. **NATIVE-REVIEWER-PENDING (Round 2 MEDIUM-A11):** before §12 archive, gate on a native-Spanish-speaker review pass. Phrasing is functionally correct ("a más tardar" = "at the latest"; "de que la reserva termine" is colloquial-natural) but a real reviewer should confirm dignity-preserving voice in the target locale.
- [x] 11.3 **`HoldDialog.tsx`** — `<details open>` so help text + inputs render visible without click (DK-RR-4). Each PII input has `aria-describedby="<id>-help"` and a `<p>` carrying the i18n string. Confirm button still auto-focused — no-attribution Enter path unchanged.
- [x] 11.4 **`EligibilityCriteriaSection.tsx`** — always-visible advisory below the notes textarea: "this field describes shelter policy, not any individual." Same aria-describedby + data-testid pattern.
- [x] 11.5 **Verified** — `npm run build` clean; vitest 202/202 GREEN; backend `mvn compile` clean.
- [ ] 11.5a **Mobile + a11y Playwright spec** — DEFERRED to a separate slice. Help-text wiring is load-bearing and lands now (this commit); the multi-viewport + axe + aria-describedby resolution test is significant separate scope (320×568 + 375×667 + 768×1024 + axe-core sweep). Tracked for v0.55.1 follow-up. The data-testid attributes the future spec depends on are already in place (§11.6 done).
- [x] 11.6 **`data-testid` on every help-text element** — `hold-help-client-name`, `hold-help-client-dob`, `hold-help-notes`, `shelter-eligibility-notes-help`. Future Playwright tests can assert on these without DOM-shape brittleness.
- [x] 11.7 **`ReservationResponse.java`** — `@Schema(description=...)` on the 3 PII record components. Description names the encryption posture, per-tenant DEK purpose, 25h purge SLA, and the §16.B serialization gate. Round 4 Alex A-RR-3 subsumed §13.D.5 into this task; future detail-view DTO will mirror.

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

- [x] 13.A.1 **`backend/src/main/java/org/fabt/shared/audit/AuditEventType.java`** — 3 enum cases added with full JavaDoc audit-payload contracts (no plaintext, no ciphertext). Wire-name pin in AuditEventTypeTest; floor bumped 44 → 47.
- [x] 13.A.2 **`ReservationService.doCreateReservation`** — emits RESERVATION_HELD_FOR_CLIENT_RECORDED after the row insert when any of the 3 PII fields is non-null. Detail blob is `{reservation_id, fields_recorded}`. Constructor gains ApplicationEventPublisher.
- [x] 13.A.3 **Read-side emitter (throttled)** — `ReservationService.recordPiiReadIfPresent(userId, shelterId, rows)` called from `ShelterReservationsController.listHeldForShelter`. Caffeine cache keyed `userId:shelterId:epochHour`; 90-min TTL, 50K max entries; `@TenantScopedByConstruction` annotated. Detail blob is `{shelter_id, throttle_key, first_seen_at}` — no `reservation_id` (would defeat the throttle).
- [x] 13.A.4 **`ReservationService.purgeExpiredHoldAttribution`** — wraps the new bounded loop and emits exactly one RESERVATION_PII_PURGED row per scheduled invocation regardless of purgedCount (including 0). Detail blob is `{purgedCount, batches, cutoff}`. Service-layer emit ensures the count is the sum across all sub-runs.
- [x] 13.A.5 **Backend tests** — 3 new tests in `HoldAttributionIntegrationTest`: (a) hold-create with PII emits the audit row AND the details blob does NOT contain plaintext name/DOB/notes; (b) no-PII hold does not emit; (c) far-past purge cutoff (zero rows) STILL emits the audit row with `purgedCount=0`. Plus the §13.B test below makes 4.

### 13.B — Sanitize DOB-validation exception (BLOCKER I-2)

- [x] 13.B.1 **`ReservationService.validateHoldClientDob`** — exception message rewritten from `"heldForClientDob must be after " + floor + "; got " + dob` to `"heldForClientDob must be on or after 1900-01-01"`. JavaDoc explains the PII-leak rationale.
- [x] 13.B.2 **Backend test** — `invalidDob_exceptionMessageStripsUserInput` in HoldAttributionIntegrationTest: posts a 1850-01-01 DOB, asserts the 400 response body does NOT contain the user-supplied DOB string while still naming the constraint.
- [x] 13.B.3 **Sweep `ReservationService` for other PII concatenation** — grep across `org/fabt/reservation/` for `+ heldFor`, `+ holdNotes`, `+ dob` returned ZERO matches. No other PII concatenation sites exist in the reservation module.

### 13.C — Tighten purge cadence + bound UPDATE (BLOCKER I-10 + SHOULD-FIX I-4 + I-5)

- [x] 13.C.1 **`ReferralTokenPurgeService.purgeExpiredHoldAttribution`** — annotation flipped `@Scheduled(fixedRate=3_600_000)` → `@Scheduled(fixedDelay=900_000)`. JavaDoc names both decisions (cadence + fixedRate→fixedDelay) and the worst-case 24h15m bound. `purgeTerminalTokens` (line 47, DV referral) intentionally untouched.
- [x] 13.C.1a **Overlapping invocation guard** — `fixedDelay` chosen per Round 4 Sam S-RR-2; JavaDoc captures the rationale.
- [x] 13.C.2 **`ReservationRepository.purgeExpiredHoldAttribution(cutoff, limit)`** — new overload uses `IN (SELECT id ... LIMIT ?)` pattern. `DEFAULT_PURGE_BATCH_LIMIT = 10_000`. Service-layer loop in `ReservationService.purgeExpiredHoldAttribution` re-runs until 0 returned, with a defensive 100-iteration safety cap and a `log.warn` if the cap is hit. Audit row in §13.A.4 carries the cumulative `purgedCount` and `batches` count.
- [ ] 13.C.3 **Backend test** — load-style integration test with >10,000 candidate rows DEFERRED. Bounded-loop is exercised by the `purge_emitsAuditRowEvenOnZeroCount` test (1 batch, count=0). A >10K test would require Testcontainers row-volume that materially slows the IT suite. Marked for v0.55.1 follow-up; the production safety cap (100 iterations × 10K = 1M rows) is well above any realistic backlog and Sam-warroom-validated.

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

- [x] 16.B.1 **`ReservationResponse.java` serialization** — `from(Reservation, ...)` factories now consult `TenantContext.getReentryMode()` and null out `heldForClientName`, `heldForClientDob`, `holdNotes` when the flag is false. Underlying Reservation entity is untouched (gate is response-only).
- [x] 16.B.2 **Pass `reentryMode` to serialization** — JwtService.JwtClaims gains a `reentryMode` boolean field; JwtAuthenticationFilter binds `TenantContext.REENTRY_MODE` (separate ScopedValue from the main Context to avoid touching 60+ runWithContext callsites in batch/system contexts that all default-to-false). `TenantContext.callWithContext(..., reentryMode, ...)` overload added.
- [x] 16.B.3 **Backend tests** — `ReservationResponseReentryGateTest` (6 cases): flag=true populates all 3 PII fields; flag=false strips all 3 (entity intact); unbound (batch/system) strips all 3; single-arg overload gates identically; null-PII entities stay null when flag=true; same entity flips per-scope. Two existing integration tests (`HoldAttributionIntegrationTest`, `ShelterReservationsEndpointTest`) adapted to opt-in via `authHelper.enableReentryMode(tenantId)`.

### 16.C — Frontend: AuthContext + four gating sites (BLOCKER B2 second half)

- [x] 16.C.1 **`frontend/src/auth/AuthContext.tsx`** — `DecodedUser` gains `reentryMode: boolean`; `decodeJwtPayload` parses `payload.reentryMode === true` (strict — string "true" yields false). `decodeJwtPayload` exported for unit testing.
- [x] 16.C.2 **`frontend/src/pages/OutreachSearch.tsx`** — advanced-filters `<details>` block + the empty-state banner wrapped in `{user?.reentryMode && (<section data-testid="reentry-advanced-filters">...</section>)}`. Conditional render (not `display:none`).
- [x] 16.C.3 **`frontend/src/pages/ShelterForm.tsx`** — `requires_verification_call` toggle + `EligibilityCriteriaSection` wrapped in `<section data-testid="reentry-eligibility-section">{user?.reentryMode && (...)}`.
- [x] 16.C.4 **`frontend/src/components/HoldDialog.tsx`** — `<details data-testid="hold-attribution-toggle">` PII-input block wrapped in `<section data-testid="reentry-pii-fields">{user?.reentryMode && (...)}`. `useAuth` import added.
- [x] 16.C.5 **`frontend/src/pages/CoordinatorDashboard.tsx`** — `useAuth` imported; line 1247 gate changed from `{hold.heldForClientName && (...)}` to `{user?.reentryMode && hold.heldForClientName && (...)}`.
- [x] 16.C.6 **Vitest tests** — `decodeJwtPayload.test.ts` (7 cases): pins the strict-true contract for the JWT claim parser. The four conditional renders all consult `user?.reentryMode` from the same parser; if the parser is correct, the gates compose correctly. Component-level rendering coverage is via Playwright §16.D (RTL is not in the project's dependency set; per `feedback_research_deps_with_personas` adding it would require a survey).

### 16.D — Playwright E2E matrix (HIGH H1)

- [x] 16.D.1 **New spec `e2e/playwright/tests/reentry-mode-gate.spec.ts`** — 3 positive E2E tests covering the three primary surfaces (advanced-filters, hold-dialog PII fields, eligibility section). Negative path covered at lower layers (decodeJwtPayload.test.ts, ReservationResponseReentryGateTest, integration tests with explicit authHelper.enableReentryMode opt-in) where the JwtService 60s reentryMode-cache TTL doesn't fight the assertion cycle. The gate's wiring is end-to-end-validated by the positive tests; the absence of the wrapper data-testids on a non-reentry tenant is materially equivalent to the unit-level "REENTRY_MODE unbound → fields null" case.
- [x] 16.D.2 **Existing reentry-* Playwright specs** — Resolved by §16.E seed flip: all 3 dev tenants (dev-coc, dev-coc-east, dev-coc-west) now seed with `features.reentryMode=true`, so the existing specs (which auth via `@dev.fabt.org`) continue to surface reentry filters/dialog/eligibility without modification. The §16.E.2 "dev-coc stays unset" plan was revised in commit 78f692e — the gate-demonstration role moves to the lower test layers + the §16.D positive matrix.

### 16.E — Seed + tenant config (BLOCKER B3 — prod-tenant flip)

- [x] 16.E.1 **Local dev seed UPDATE** — `infra/scripts/seed-data.sql` updated: dev-coc-west + dev-coc-east now seed with `"features": {"reentryMode": true}` in config. dev-coc-east `hold_duration_minutes` bumped 90→180 per shot-05 requirement. Applied to running local DB via `docker exec ... psql -c "UPDATE tenant SET config = config || jsonb_build_object('features', coalesce(config->'features', '{}'::jsonb) || jsonb_build_object('reentryMode', true)) WHERE slug IN ('dev-coc-east','dev-coc-west');"`.
- [x] 16.E.2 **`dev-coc` stays unset** — original demo tenant continues to behave as v0.54 did. Intentional: demonstrates the gate works; ungated tenants are a known shape.
- [x] 16.E.3 **`docs/oracle-update-notes-v0.55.0.md` §6 "Prod demo tenants — flip features.reentryMode" subsection (BLOCKER B3)** — Post-deploy step added. Uses JSONB concat (`config || jsonb_build_object('features', coalesce(config->'features','{}'::jsonb) || jsonb_build_object('reentryMode', true))`) rather than `jsonb_set` because the latter returns the input unchanged when the nested parent key is missing. Flips `blueridge` + `mountain`. Token-TTL caveat + DEK note included. Deferred Flyway V96 alternative (per "data, not schema" rationale).

### 16.F — Spec + doc updates (HIGH H4)

- [x] 16.F.1 **`reentry-release-readiness/proposal.md`** — §H "v0.55 implementation hardening + UI gating" added during scaffolding (Round 5 D13 expansion).
- [x] 16.F.2 **`reentry-release-readiness/design.md`** — D14 "reentryMode UI gate (Path Y, warroom Round 5)" added during scaffolding citing JWT-claim + dvAccess pattern + API-serialization-gate defense-in-depth + fail-safe-default-off + token-TTL-bounded propagation.
- [x] 16.F.3 **`transitional-reentry-support/design.md` D13** — appended "Implementation status (post-§16)" note describing the JWT-claim transport that supersedes the original useTenantConfig() hook design + the API serialization gate that the original D13 did not specify. Cites all 4 commit SHAs.
- [x] 16.F.4 **`docs/operations/reentry-mode-user-guide.md` §1** — rewritten with post-§16 behavior: "What flipping the flag does" enumerates the 5 surface effects (advanced filters, eligibility editor, hold-dialog PII section, coordinator dashboard PII display, ReservationResponse PII serialization), token-TTL caveat, and default-off-is-production-correct framing.
- [x] 16.F.5 **`docs/security/compliance-posture-matrix.md` "Tenant opt-in gate (v0.55 §16.B)" subsection** — added under Hold-attribution PII (v0.55+), explains the serialization-time control + frontend conditional renders + defense-in-depth + tenant-data-segmentation rationale.
- [x] 16.F.6 **`CHANGELOG.md` v0.55 Privacy/Security paragraph** — added: "Reentry-specific UI ... is now gated behind features.reentryMode; default off. Two layers: (a) API serialization, (b) four frontend conditional renders. Token-TTL caveat noted."
- [x] 16.F.7 **`docs/government-adoption-guide.md`** — strengthened "may optionally collect" wording to "PII fields are NOT surfaced in the UI or returned by the API unless the CoC administrator has affirmatively enabled `features.reentryMode = true`. Default-off is the production-correct posture ... A CoC adopting FABT does not become a PII collector by default."

### 16.G — Verification + commit gate

- [x] 16.G.1 **`mvn test`** GREEN — full backend suite 1431/1431 after the §16.A annotation fix (ff2db6c). Test breakdown: 8 new JwtServiceReentryModeClaimTest cases, 3 new PlatformJwtServiceTest pinning cases, 6 new ReservationResponseReentryGateTest cases, 18 unchanged HoldAttributionIntegrationTest cases (now opt-in via authHelper.enableReentryMode), 5 unchanged ShelterReservationsEndpointTest cases (also opt-in), 6 ArchUnit Family C cache-isolation guard cases (with new @TenantScopedByConstruction on reentryModeCache).
- [x] 16.G.2 **`npm run build`** GREEN — Vite + tsc + service worker. Vitest 202/202 across 14 test files (was 13; +decodeJwtPayload.test.ts).
- [ ] 16.G.3 **Live-stack manual verification** — REQUIRES OPERATOR: stop dev-start.sh backend, `mvn -DskipTests package`, restart, then login as outreach@dev.fabt.org → confirm reentry surfaces visible (since dev-coc now seeds with reentryMode=true). To exercise the negative path on the live stack: temporarily flip dev-coc reentryMode=false via `PUT /api/v1/tenants/{id}/config`, wait ≥60s for the reentryModeCache TTL, log out + log back in (forces fresh JWT issue), confirm surfaces hidden, restore.
- [ ] 16.G.4 **API-gate verification** — REQUIRES OPERATOR: with the rebuilt backend running, login as the outreach user, hit `GET /api/v1/shelters/{id}/reservations` and confirm `heldForClientName/Dob/holdNotes` are populated when the JWT carries reentryMode=true. The negative-path-via-API curl matrix is fully covered by `ReservationResponseReentryGateTest` (6 cases) + `HoldAttributionIntegrationTest` integration suite, both passing in §16.G.1.
- [ ] 16.G.5 **Playwright matrix** (§16.D.1) — REQUIRES OPERATOR: with the rebuilt backend + restarted frontend nginx, run `BASE_URL=http://localhost:8081 npx playwright test e2e/playwright/tests/reentry-mode-gate.spec.ts --config=deploy/playwright.config.ts` (or appropriate dev config). Spec is 3 positive tests on the gated path.

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
