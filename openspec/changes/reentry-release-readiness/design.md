## Context

The `transitional-reentry-support` change shipped backend, schema (V91-V95), and frontend code for an opt-in PII collection capability (navigator hold attribution). The change is `/opsx:apply` complete on `main` at commit `6ad8ee6`. **It cannot be `/opsx:archive`d or v0.55-tagged** because two warroom passes surfaced that the public-facing surface (live demo site, audience docs, privacy posture statements, AsyncAPI contract, ERD, runbook) is still operating under the pre-v0.55 "zero PII" framing — which was true of every prior release and is now materially false.

The most cited evidence: the live root `findabed.org/index.html` says *"protects domestic violence shelter locations through zero-PII referral design — no client name, no address in the system, ever."* The "ever" was a defensible marketing claim when the architecture matched it. As of v0.55 the architecture optionally collects `held_for_client_name`, `held_for_client_dob`, and free-text `hold_notes`, encrypted at rest with a per-tenant DEK (`tenant_dek.purpose='RESERVATION_PII'`) and purged 24 hours after the hold reaches a terminal status. Twelve sites in `docs/asyncapi.yaml` carry the same "zero client PII" assertion; `docs/hospital-privacy-summary.md`'s "What FABT Never Stores" table lists Name and DOB as "Never" — incorrect once a hospital social worker uses the navigator hold path; `docs/architecture.md` has no entry for transitional-reentry-support; `docs/erd.svg` has no V91-V95 columns; `docs/legal/right-to-be-forgotten.md` is referenced by `docs/security/compliance-posture-matrix.md:110` but does not exist in the repo (verified).

Two warroom passes (story warroom: Simone, Devon, Tomás, Maria, Demetrius, Keisha; PII doc warroom: Casey, Marcus Webb, Alex Chen) converged on the change scope in `proposal.md`. The agreed posture: **honest documentation that the surface optionally collects PII, that the 24h purge is the contract, and that operational monitoring of the purge SLA is currently a gap explicitly disclosed in the compliance matrix** — rather than back-pedaling the feature or waiting for monitoring to land.

Stakeholders: project lead (release decision), the synthesized warroom personas (review surfaces), no external pilots or named partners (per `feedback_no_named_stakeholders_in_docs`).

## Goals / Non-Goals

**Goals:**
- Make the public-facing surface match deployed v0.55 reality, end-to-end (live site, audience docs, architecture docs, AsyncAPI, ERD, runbook, CHANGELOG)
- Ship a public reentry capability deep-dive (`demo/reentry-story.html`) so v0.55's user-facing capability has a story page, not just a feature bullet
- Disclose the 24-hour PII purge as the contract AND honestly disclose that the operational signal (metric/alert) for the purge SLA is not yet wired
- Add UI tooltips on the new PII fields so a navigator placing a hold encounters the privacy framing in-context, not buried in the user guide
- Establish a release-readiness gate: the `transitional-reentry-support` change cannot archive without this one, and v0.55 cannot tag without both archives
- Keep all language "designed to support," not "compliant"; keep all stakeholder names synthetic; keep the doc estate truthful per `feedback_truthfulness_above_all`

**Non-Goals:**
- Authoring `PRIVACY.md` (full ~800-word public privacy policy) — Tier 2, deferred
- Authoring `docs/security/threat-model.md` (STRIDE-lite) — Tier 2, deferred
- Authoring `docs/security/dek-rotation-policy.md` — Tier 2, deferred
- Re-running ZAP and committing `zap-v0.55-baseline.md` — Tier 2, depends on dev-stack uptime
- Authoring `docs/security/audit-event-catalog.md` — Tier 3, deferred
- Authoring `for-navigators.html` audience card — defers until lived navigator feedback validates the role term
- Wiring the actual purge-SLA metric / alert — implementation follow-up; this change documents the gap, not closes it
- Modifying any Flyway migration, schema, controller, or service — backend code is frozen at `6ad8ee6` for v0.55
- Translating `demo/reentry-story.html` into Spanish — English-only at v0.55 ship; Spanish demo coverage is a separate i18n change

## Decisions

### D1 — Capability deep-dive first; audience card deferred
**Decision:** Ship `demo/reentry-story.html` as the fifth capability deep-dive in the "See It Work" grid (analog to `demo/dvindex.html`). Do NOT add a fifth audience card to the "Who It's For" grid yet.

**Rationale:** An audience card requires a stable role-term ("navigator" vs "reentry case manager" vs "reentry housing worker") and a `for-navigators.html` page that takes lived feedback to write authentically. Demetrius and Keisha both flagged language risk. The capability deep-dive lets us ship the v0.55 story with synthetic-but-accurate copy that's reversible if real-world reentry orgs push back on the framing. The audience card lands in a future change once language is validated.

**Alternative considered:** Ship both deep-dive AND audience card now — rejected because it locks in language we haven't validated.

### D2 — Honest SLA disclosure over silent claim
**Decision:** `docs/security/compliance-posture-matrix.md` gets a new Hold-attribution PII section that names the 24h purge as the contract AND **explicitly discloses** that the metric (`fabt.reservation.pii_purge.success.count`, `fabt.reservation.pii_purge.lag_seconds`) and alert (`fabt.reservation.pii_purge.failure.count > 0` for 5m) are NOT YET WIRED at v0.55. Same disclosure goes in `docs/oracle-update-notes-v0.55.0.md` §6.5.

**Rationale:** Three personas (Casey C-5, Marcus M-2, Alex A-4) converged on this. The 24h claim appears in CHANGELOG, runbook, and government-adoption-guide. Closing the metric gap is implementation work and not in v0.55's scope. The doc fix is to be truthful about the current operational state, not to assert coverage that doesn't exist. `feedback_truthfulness_above_all` is the dominant memory.

**Alternative considered:** Hold the v0.55 release until the metric and alert ship — rejected because it expands the release scope into observability work that has its own design considerations (alert thresholds, on-call routing). Better to ship v0.55 with honest disclosure and follow up.

### D3 — Live-site hotfix scope
**Decision:** The root `findabed.org/index.html` "ever" claim is fixed in this change as part of the v0.55 release commit, NOT as a separate today-hotfix.

**Rationale:** The live site's "ever" claim is currently true — the v0.55 code is on `main` but not deployed. Until v0.55 deploys, the public claim still matches reality. Hotfixing the static HTML before deploying the backend would temporarily make the public surface MORE conservative than reality (claims PII collection that isn't yet active in production), which is also a misalignment. Bundling the doc edits with the v0.55 deploy keeps the public surface and the deployed code in lockstep. Casey + Marcus would have voted today-hotfix but the rationale assumed the deploy was imminent and uncertain — bundling is cleaner.

**Alternative considered:** Today-hotfix on the docs repo + delayed bundle in code repo — rejected because it splits the truthfulness work across two release moments and creates a window where the doc estate is partially-honest.

### D4 — Two repos, paired archive
**Decision:** This change lives in the docs repo (`C:\Development\findABed\openspec\changes\reentry-release-readiness\`) per `feedback_openspec_in_docs_repo.md`. Tasks span both repos (docs repo for `demo/*.html`, `index.html`, `capture.sh`; code repo for `docs/*.md`, `frontend/src/**/*`, `e2e/playwright/tests/*`). The final task is a coordinated archive: `transitional-reentry-support` archives first (it's the prerequisite capability), then `reentry-release-readiness` archives, then the v0.55.0 git tag goes on the code-repo `main`.

**Rationale:** The OpenSpec CLI sees changes only in the docs repo, but the implementation work touches both repos. The archive-then-archive-then-tag sequence is the gate the user explicitly directed.

**Alternative considered:** Archive `reentry-release-readiness` first then `transitional-reentry-support` — rejected because the reentry-spec is the underlying capability; archiving it after its readiness gate would invert the dependency.

### D5 — Two-warroom-output reconciliation
**Decision:** Where the two warrooms overlap (e.g., the story page Part 6 says to add a sentence to `for-cities.html`; the PII warroom Part 3 Tier 1 says to scope the PII claim in `for-cities.html`), tasks consolidate the edits so each file is touched once with both intents addressed.

**Rationale:** Treating the two warrooms as independent task lists would result in `for-cities.html` being edited twice in different commits — pure churn. Consolidating respects `feedback_periodic_resume_save` (one coherent edit, one commit) and reduces review burden.

### D6 — Tooltip copy belongs to Keisha's voice, not Casey's
**Decision:** `HoldDialog` and `EligibilityCriteriaSection` tooltips are written in dignity-preserving plain language ("Optional. Encrypted at rest. Erased no later than 25 hours after the hold ends.") not legal language ("Personally identifiable information (PII) is encrypted at rest using AES-256 with per-tenant key derivation and is purged no later than 25 hours of resolution per the project retention policy"). The "no later than 25 hours" affirmative bound aligns with D10.

**Rationale:** The tooltip lands in front of a navigator placing a hold for a person on release day. Per Keisha's lens (`PERSONAS.md:498-548`), copy that shames or jargons-up the user is an accessibility failure. Casey's framing belongs in `compliance-posture-matrix.md` and `right-to-be-forgotten.md`, not in the UI.

### D7 — Architecture doc adds a section, doesn't restructure
**Decision:** `docs/architecture.md` gets a new transitional-reentry-support section parallel to the existing dv-opaque-referral section. Tenancy-model.md gets one paragraph. ERD/DBML regenerate from the live schema.

**Rationale:** Architecture docs already have a per-capability section pattern. Following the pattern is cheaper than restructuring. The DBML regeneration is a tooling step, not authorship. Per Alex A-2: this is the `feedback_update_docs_with_code` discipline catching up — not a new architectural design.

### D14 — `features.reentryMode` UI gate (Path Y, warroom Round 5)
**Decision:** The `features.reentryMode` tenant config flag — declared in V91 and intended by `transitional-reentry-support` design D13 to gate the new reentry UI surface — is wired in this change. Implementation has two layers (defense-in-depth):

1. **API serialization gate (primary).** `ReservationResponse.from()` reads `tenant.config.features.reentryMode` from the request context. When false, the three PII fields (`heldForClientName`, `heldForClientDob`, `holdNotes`) are returned as null regardless of underlying ciphertext. This composes with the §13.D list-view-PII-drop work — same gate, broader scope. Per `feedback_contract_gap_in_parallel_paths` (Round 4 + Round 5 lessons): a future component rendering PII without the gate is still safe because the payload itself is empty.

2. **Frontend conditional render (UX polish).** Four sites — `OutreachSearch.tsx` advanced filters, `ShelterForm.tsx` eligibility section + `requires_verification_call` toggle, `HoldDialog.tsx` PII fields, `CoordinatorDashboard.tsx` past-holds PII display. Use `{user?.reentryMode && (...)}` conditional render, not `display:none` or `aria-hidden` (per Tomás N1: keeps the tab order clean and prevents AT confusion).

**Claim transport:** JWT claim, matching the `dvAccess` precedent in this codebase. JwtService injects `TenantService.getConfig(UUID)` and emits the boolean alongside `dvAccess` at token issuance. A 60s Caffeine cache keyed by tenant id avoids per-token DB roundtrips. Token TTL bounds flag-flip latency at 15 min.

**Centralization (warroom B1 fix):** flag-load helper called from EVERY token-issuance site in JwtService (`generateAccessToken(User)`, `generateAccessToken(User, String)`, `generateAccessTokenWithPasswordChange(User)`). Refresh + TOTP-verify + OAuth2 paths all flow through these methods → no caller needs to know about the new claim. `PlatformJwtService` is a separate class for platform users (no tenant.config) and remains untouched; a no-op assertion test guards against future regression.

**Fail-safe default:** missing `features` key, missing `reentryMode` key, non-boolean values, null tenant.config — all coerce to false. The default protects tenants not ready to handle PII.

**Prod-tenant flip (warroom B3 fix):** v0.55 deploy runbook §7 adds a post-deploy step to flip `features.reentryMode=true` for the demo tenant(s) (`blueridge`, `mountain`) via UPDATE on `tenant.config`. Without it, the new `demo/reentry-story.html` deep-dive page would link to a "live demo" with the reentry UI hidden — appearing broken to public visitors.

**Rationale:** discovered 2026-04-30 during seed-data verification for screenshot capture. The `transitional-reentry-support` slice shipped the UI but not the gate; this change ships the gate. The user's framing: "tenants that may not be ready to handle PII" should not see PII fields by default. Defense-in-depth (API + frontend) is the right architecture because parallel-path drift in render code (the Round 5 B2 finding — `CoordinatorDashboard.tsx` was a 4th unguarded surface) would otherwise re-emerge in any future component touching reservation data.

**Alternative considered:** frontend-only gate — rejected per warroom Round 5 B2; eliminates parallel-path drift only if API enforces. PII in API response → present in browser dev tools → present in service-worker cache → renderable by any future component → leak surface that grows over time.

**Alternative considered:** `/api/v1/me/features` endpoint + `useTenantFeatures` hook — rejected. Adds an HTTP roundtrip + loading state + risk of FOUC (flash of PII before flag evaluates). JWT-borne pattern matches `dvAccess` and is synchronous on render.

### D9 — Tooltip implementation uses always-visible help text + `aria-describedby`, not hover tooltips
**Decision:** PII-field tooltips on `HoldDialog` and `EligibilityCriteriaSection` render as always-visible help text below each input (or inside the existing `<details>` disclosure where applicable), with `aria-describedby` linking the input to the help text. NO hover-only or `title`-attribute tooltips.

**Rationale:** Per Tomás (TO-RR-1) and WCAG 2.1.1: hover-only tooltips are not keyboard-accessible. The ADA Title II April 24, 2026 deadline has passed; release-gate quality demands keyboard-reachable disclosure. Always-visible text also lands consistently with screen readers (NVDA/VoiceOver announce on focus via `aria-describedby`).

**Alternative considered:** Native `title` attribute — rejected as non-accessible. Hover-only popover — same.

### D10 — User-facing copy reports "no later than 25 hours," not "24"
**Decision:** Tooltip copy, the `hold.clientAttributionPrivacyNote` i18n key, the `compliance-posture-matrix.md` purge-SLA row, and any user-facing claim about the PII purge SLA SHALL state the lifetime as **"no later than 25 hours"** (affirmative bound, not range). The 24-hour figure is the floor; the actual operational worst case with the post-D11 15-min cadence is 24h15m, comfortably under 25h. The affirmative phrasing ("no later than 25") is preferred over the range phrasing ("within 24-25") because per Casey-voice the user-facing claim must be a clear ceiling rather than ambiguous about the floor.

**Rationale:** Per `feedback_truthfulness_above_all` and the Round 3 + Round 4 warroom convergence (Casey + Marcus + Demetrius + Tomás + Casey C-RR-2): the public claim must be at least as conservative as the operational floor, with affirmative-bound phrasing. Casey-voice + Keisha-voice both prefer "automatic, no later than a day" framing for navigators while the matrix uses precise minute-bound language.

**Alternative considered:** Keep "24 hours" copy and document the 1h gap in compliance-posture-matrix.md only — rejected because the user-facing privacy note is the doc landing in front of a navigator placing a hold; that's where truthfulness lands or fails. Range phrasing ("within 24-25 hours") was the Round 3 choice; Round 4 C-RR-2 superseded it with affirmative-bound phrasing.

### D12 — Detail-view endpoint shape resolved (per Round 4 A-RR-1)
**Decision:** The PII detail-view endpoint is a NEW `GET /api/v1/reservations/{id}/detail` on `ReservationController` (NOT extending `ShelterReservationsController.GET /{shelterId}/reservations` and NOT overloading any existing detail route). Authorization mirrors the list-shelter check: COORDINATOR-assigned-to-shelter OR COC_ADMIN-in-tenant.

**Rationale:** Round 4 surfaced that §13.D.1 left this decision to the implementer. The existing `ShelterReservationsController` has no `/{id}` route to extend; option (b) "extend existing" was hand-waving. A new dedicated endpoint can adopt the read-side audit + `Cache-Control: no-store, private` posture cleanly without overloading list-controller semantics. Authorization mirrors the existing list endpoint to keep the access-control surface coherent.

**Alternative considered:** Add the `/{id}` route to `ShelterReservationsController` instead — rejected because it conflates list and detail concerns on a controller named for the list capability.

### D11 — Implementation hardening included in this change (Path A)
**Decision:** Per the 24-persona warroom round, three blockers (I-1 audit events missing, I-2 DOB-in-logs, I-10 24h ≠ 25h) cannot be closed by doc edits alone. The change scope expands to include code-side hardening under a new `reservation-pii-hardening` capability and tasks.md §13. Five additional warroom items (I-3 list-view PII, I-4 cadence tightening, I-5 purge LIMIT, I-8 `@Schema` annotations, I-9 Cache-Control) ride along as best-effort SHOULD-FIX. Four warroom items (I-6, I-7, I-11, I-12) defer to v0.56.

**Rationale:** The user explicitly directed "everything is on the table" when escalating from doc concerns to implementation concerns. Shipping a doc gate that names a 24h purge claim while the underlying code leaks DOB into logs and emits no audit events would be a contradictory posture per `feedback_truthfulness_above_all`. The scope expansion is bounded — three BLOCKERs are 1-line fixes (I-2, I-4, I-10 copy) plus three new `AuditEventType` cases with emitters. The five SHOULD-FIX items are similarly localized.

**Alternative considered:** Path B (strict doc-only scope, carve hardening into a `reentry-release-readiness-followup` for v0.55.1) — rejected because two release events back-to-back creates a window where the doc estate is honest about a code surface that hasn't yet been hardened to match.

### D8 — Capture script enumerates rather than greps
**Decision:** `demo/capture.sh` enumerates the ten capture-spec files explicitly (with comments per spec) rather than globbing `capture-*.spec.ts`.

**Rationale:** Glob matching is one bug away from running specs we didn't intend (e.g., `capture-platform-operator-screenshots.spec.ts` requires a different fixture than the others). Explicit enumeration also self-documents the intent.

**Alternative considered:** Auto-glob with a deny-list — rejected as more complex than enumeration for ten items.

## Risks / Trade-offs

- **[Truthfulness vs marketing posture]** → The "designed to support DV protection" framing is less punchy than "zero-PII forever." Mitigation: keep the DV-specific zero-PII claim verbatim where it applies; only scope the platform-wide assertions. Casey-reviewed.
- **[Drift between docs repo edits and code repo edits]** → Two-repo change risks inconsistency at archive time. Mitigation: tasks identify which repo each edit lands in; archive sequence is documented in §Decisions D4; final validation step diffs the two repos for terminology.
- **[Hospital privacy summary table rewrite]** → Marcus suggested pulling the doc from circulation; Casey suggested rewriting in place. We rewrite in place but flag the doc as the highest BAA-conversation exposure. Mitigation: the rewrite includes a clear scope statement at the top; the audience-specific table makes the DV/non-DV distinction visible.
- **[Honest SLA disclosure could read as immaturity]** → External reviewers may read "metric not yet wired" as a project not ready for production. Mitigation: pair the disclosure with the explicit follow-up note that the metric is a v0.56 work item, and document the alternative (server-side log parsing) operators can use today.
- **[Spanish coverage gap on the new story page]** → Most user-facing surfaces are bilingual; the story page is English-only at v0.55. Mitigation: explicit non-goal; track as a separate i18n change. Risk surface: a navigator audience that disproportionately serves Spanish-first communities.
- **[Screenshot drift on existing pages]** → Most existing screenshots predate v0.55. Mitigation: drift check on 3-4 high-traffic shots before tag; regenerate as needed. Acceptance: not all 58 PNGs need re-capture for v0.55 — only those whose UI moved.
- **[Failure-path screenshot (`reentry-06`) seed dependency]** → The most important screenshot per Demetrius requires V95 to seed a county where the only reentry shelter excludes the navigator's offense type. Mitigation: verify V95 seed includes this configuration, or amend the seed (V96) before capture.
- **[Tooltip i18n key sprawl]** → Adding ~5 new i18n keys × 2 locales × 2 components risks merge conflicts with concurrent work. Mitigation: namespace the keys (`hold.tooltip.*`, `shelter.eligibility.notes.tooltip`) so they're easy to grep.
- **[Audit events missing for PII surface]** → Per warroom T1 (Marcus + Riley + Casey + Kenji): hold-attribution writes, decryption-on-read, and purge events leave no audit row, so the public 24h purge claim is forensically unverifiable. Mitigation: D11 expands scope to add three `AuditEventType` cases under `reservation-pii-hardening` and wire emitters at all three sites. Audit payloads themselves carry only reservation id + tenant + actor (NEVER the encrypted columns) so the audit log does not become a secondary PII store.
- **[Coordinator list-view PII exposure]** → Per warroom T5 (Marcus + Sandra + Riley + Casey): any coordinator assigned to a shelter sees plaintext PII for every HELD hold via `ShelterReservationsController.listHeldForShelter`, with no per-row audit. Mitigation: D11 expands scope to drop PII from list-view DTO and serve it only on single-resource detail reads. Operators still see the hold rows on the dashboard; PII is on the detail-view click-through.
- **[24h claim mismatch]** → Per warroom T4 (Casey + Marcus + Demetrius + Tomás) + Round 4 C-RR-1/C-RR-2: purge runs hourly so worst-case PII lifetime was 25h, while public copy said "within 24 hours" (and Round 3 first revised it to "within 24-25 hours" before Round 4 surfaced that range phrasing was weaker than affirmative bound). Mitigation: D10 sets all user-facing copy to **"no later than 25 hours"** (affirmative bound, not range) AND D11 tightens cadence to 15min so worst case is 24h15m, comfortably under 25h. Both fixes ride together because tightening cadence alone leaves prose copy lying; revising prose alone leaves operational headroom uncomfortably tight.

## Migration Plan

This change is doc-only and UI-tooltip-only. There is no Flyway migration, no controller change, no service change, no schema change. Migration is the **release sequence**:

1. Implement all tasks (proposal/design/specs/tasks files for this change live in docs repo; implementation work spans docs repo + code repo)
2. Run `/opsx:verify` on this change to confirm task completeness
3. Run `/opsx:archive transitional-reentry-support` (docs repo)
4. Run `/opsx:archive reentry-release-readiness` (docs repo)
5. Tag `v0.55.0` on code repo `main`
6. Deploy per `docs/oracle-update-notes-v0.55.0.md` (now updated with §6.5 PII purge verification)
7. Post-deploy: live-site smoke (verify the "ever" claim is gone; verify the new `reentry-story.html` is reachable and renders; verify the `for-coordinators.html` cross-link works)

**Rollback strategy:** This change is doc + tooltip only. Rollback is `git revert` on the relevant commits. No data migration, no service restart required for rollback. The harder rollback case is v0.55 backend rollback, which is governed by `docs/oracle-update-notes-v0.55.0.md` §7 Rollback Matrix and is unchanged by this change.

## Warroom rounds (decision lineage)

This change was authored from the synthesis of three internal warroom rounds. Findings were aggregated and contradictions resolved into the Decisions and Risks above; the rounds themselves are captured here for traceability, not as external attribution.

- **Round 1 — story-page warroom (six lenses):** brand/comms, instructional design, accessibility, product strategy, navigator-protagonist, lived-experience. Output: structural decision (capability deep-dive vs audience card; D1), heading hierarchy, alt-text policy, screenshot list (including the failure-path shot), banned-words list. See `proposal.md §E` and `specs/reentry-story-page/spec.md` for what landed.
- **Round 2 — PII doc-estate warroom (three lenses):** legal posture, application security, principal architecture. Output: the truthfulness cluster (the live "ever" claim, hospital-privacy-summary's "Never" table, asyncapi's 12 zero-PII sites, government-adoption-guide's PII bullets), the 24h-purge-SLA-without-monitoring honest-disclosure pattern (D2), the missing `right-to-be-forgotten.md`, and the architecture sync (DBML/ERD/architecture.md).
- **Round 3 — full 24-lens audit + web-grounded PII best practices:** every persona's lens reviewed the spec; OWASP ASVS V16, HIPAA BAA 2026 guidance, IAPP/Houseblend RTBF patterns, and 2026 crypto-shred best-practice articles informed challenges to the spec's assumptions. Round 3 surfaced the three Path-A blockers (audit events missing, DOB-in-logs, 24h ≠ 25h truthfulness) that drove D11. Many findings were independently raised by 3-4 different lenses, increasing confidence.

The contributors were synthetic personas (`PERSONAS.md`) not real external advisors, per `feedback_persona_transparency`. The findings stand on their own merit + the cited public sources; this section records *that the rounds happened*, not *who* attended.

## Future considerations

- **`reservation-pii-hardening` capability is wide.** It bundles 7 requirements covering audit events + exception sanitize + cadence + LIMIT + list-view PII drop + cache headers + `@Schema` annotations. Bundled because they all ship in v0.55 and share a single test surface; if the surface grows in v0.56+, consider splitting into narrower sub-capabilities (`pii-audit-events`, `pii-purge-cadence`, `pii-list-view-protection`) for maintainability. Not a coherence issue today.

## Open Questions

1. **Demetrius quote attribution.** `PERSONAS.md:398` is a verbatim canonical quote attributed to Demetrius (a synthetic persona). The story page uses the quote with attribution to "a North Carolina reentry navigator" — anonymized. Should this be reviewed for lived-experience-community comfort before tag, or is anonymized attribution sufficient? Default: anonymized.

2. **Live-site hotfix timing if deploy slips.** D3 bundles the live-site fix with the deploy. If v0.55 deploy slips by more than 1 week from this change archiving, the bundled approach delays the truthfulness fix. Should the change include a contingency clause that converts to a today-hotfix after a fixed delay? Default: no — re-evaluate at archive time.

3. **`docs/legal/right-to-be-forgotten.md` scope.** The file is referenced by `compliance-posture-matrix.md:110`. The minimal version is ~400 words clarifying that the platform is self-hosted and data-rights requests go to the deployment owner, not the FABT project. The maximal version covers GDPR/CCPA framing. Default: ship the minimal version; track GDPR/CCPA framing as a Tier 2 doc gap.

4. **Capture spec failure-path seeding.** The `reentry-06` failure-path shot requires a deliberately-seeded conflict. Does V95 already include this, or do we need a V96 seed amendment? Default: verify before capture; amend V95 in place if blocked (V95 is data-only seed, not a structural migration). **NOTE:** `feedback_flyway_immutable_after_apply` says don't modify applied migrations. V95 is applied locally and on demo. Either the seed must be amended via V96 or the test must dynamically construct the conflict. Decision deferred to capture-spec implementation.

5. **OpenAPI spec field annotations for the PII payload.** Alex A-6 wants the OpenAPI schema for the hold-create payload to annotate `heldForClientName`, `heldForClientDob`, `holdNotes` with privacy callouts. Is this code-repo work that fits in this change, or does it belong with the backend code that already shipped? Default: include in this change — it's documentation of code that already shipped, not code surgery.

6. **Drift check methodology.** "Re-capture and visually diff 3-4 high-traffic existing shots" is loose. What's the diff tool? What's the acceptance threshold (any pixel diff? semantic diff?) Default: re-run the existing `capture.sh` for the four shots, eyeball-diff against committed PNGs, replace any that show meaningful drift. Document threshold as "operator judgment" in tasks.md.

7. **Tag commit hosting.** The v0.55.0 tag goes on code repo `main`. The doc repo also has a parallel commit history — does the docs repo also get a tag, or is the code repo tag the canonical reference? Default: code repo tag is canonical; docs repo gets a corresponding commit but no tag.
