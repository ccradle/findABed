## Why

v0.55.0 (transitional-reentry-support) is on `main` at commit `6ad8ee6` but cannot be tagged or deployed because its public-facing surface — demo site, training docs, privacy posture statements — does not yet reflect the new optional PII collection capability (navigator hold attribution: client name + DOB + free-text notes, encrypted at rest, purged 24h post-resolution). The single load-bearing exposure is the live `findabed.org/index.html` claim that the platform stores "no client name, no address in the system, ever" — true pre-v0.55, false post-v0.55. Two warroom passes (PII doc-estate sweep with Casey/Marcus Webb/Alex Chen; reentry demo-story design with Simone/Devon/Tomás/Maria/Demetrius/Keisha) converged on the work below as the minimum public-facing readiness needed before tagging v0.55.0. This change is a release gate: tagging is forbidden until this change is `/opsx:archive`d.

## What Changes

**A — Live-site truthfulness (the "ever" cluster)**
- Root `findabed.org/index.html`: scope the "zero-PII" claim to the DV referral path only (one-line edit; **highest single exposure**)
- `docs/government-adoption-guide.md`: rewrite the zero-PII bullets and scope the VAWA-protection section to acknowledge non-DV opt-in PII
- `docs/hospital-privacy-summary.md`: rewrite the "What FABT Never Stores" table to two columns (DV path / navigator-hold path) and update the BAA framing — the hospital social worker IS a navigator-role audience, so the current "Never" entries for Name and DOB are factually wrong as applied to v0.55
- `docs/FOR-COC-ADMINS.md`, `FOR-CITIES.md`, `FOR-DEVELOPERS.md`: add one-sentence v0.55 scope addendum to each existing "zero PII" claim (DV-scoped in context, ambiguous in language)

**B — Architectural doc sync (the `feedback_update_docs_with_code` discipline violation)**
- `docs/asyncapi.yaml`: audit and edit the 12 sites of "ZERO client PII" — DV-event sites stay verbatim; reservation-event sites get a "may carry encrypted PII; never published over AsyncAPI by design" note
- `docs/erd.svg` + `docs/schema.dbml`: regenerate from current schema (V91-V95 not yet reflected)
- `docs/architecture.md`: add a transitional-reentry-support section parallel to the existing dv-opaque-referral section
- `docs/architecture/tenancy-model.md`: one paragraph on the new `tenant_dek.purpose='RESERVATION_PII'` tenant-scoped key

**C — Operational claim → verifiable signal**
- `docs/security/compliance-posture-matrix.md`: new "Hold-attribution PII" section + new "Purge SLA" row that **honestly discloses** the purge job's currently-unmonitored state (no metric, no alert wired yet — that's a follow-up; the doc fix is to be truthful about the gap, not to claim coverage that doesn't exist)
- `docs/oracle-update-notes-v0.55.0.md`: add §6.5 PII purge verification (operator commands to confirm the schedule registered + sample row honored the SLA + acknowledgement that no failure metric exists yet)
- `CHANGELOG.md` v0.55: add a Privacy/Security subsection so PII collection is not buried as a feature bullet

**D — Missing-but-cited doc**
- Author `docs/legal/right-to-be-forgotten.md` — currently referenced by `docs/security/compliance-posture-matrix.md:110` but **does not exist in the repo** (verified). The reference is asserting documentation that isn't there — a `feedback_truthfulness_above_all` violation.

**E — Demo story page + capture infrastructure**
- New `demo/reentry-story.html` — fifth capability deep-dive tile in the "See It Work" grid (analog to `demo/dvindex.html`). Design spec already authored by the story warroom (heading hierarchy, 5 sections, alt-text intent, screenshot list, cross-link map).
- New `e2e/playwright/tests/capture-reentry-screenshots.spec.ts` — six tests producing `reentry-01-*.png` through `reentry-06-*.png`. The sixth shot is the failure-path Demetrius said is the most important one (county-only shelter excludes the relevant offense type).
- Update `demo/capture.sh` — script currently invokes only one of nine existing capture specs; enumerate them all and add the new reentry spec.
- Cross-page edits: 5th tile in root `index.html` "See It Work" grid; cross-link paragraph in `demo/for-coordinators.html`; reentry-population sentences in `demo/for-cities.html` + `demo/for-funders.html`; reciprocal footer link in `demo/dvindex.html`.
- Screenshot drift check: re-capture and visually diff 3-4 high-traffic existing shots (login, search, coordinator dashboard, admin landing) — most existing shots predate the v0.55 merge.

**F — PII tooltips on UI surfaces**
- `HoldDialog`: always-visible help text below the client-name input, DOB input, and notes textarea — copy intent: "Optional. Encrypted at rest. Erased no later than 25 hours after the hold ends." (Keisha-voiced, not Casey-voiced; affirmative-bound per D10.)
- `EligibilityCriteriaSection`: tooltip on the notes textarea advising operators that free-text may capture client-identifying detail and is therefore subject to the same advisory framing
- New i18n keys for all tooltip strings (English + Spanish); npm build verifies no missing keys

**H — `features.reentryMode` UI gate (Path Y scope expansion, warroom Round 5)**

The `transitional-reentry-support` slice intended `features.reentryMode` to gate the new reentry UI (per design D13 of that change), but the gate was never wired — the entire reentry surface ships visible to every tenant. Discovered 2026-04-30 during seed-data verification for screenshot capture. Per `feedback_truthfulness_above_all` and the user's explicit reasoning ("tenants that may not be ready to handle PII"), the release should not ship without honoring the design intent.

The gate is implemented in two layers (defense-in-depth):
- **API serialization gate (primary)** — `ReservationResponse` strips hold-attribution PII fields from responses when the calling tenant has `features.reentryMode=false`. Eliminates the parallel-path drift problem (a future component rendering PII without checking the flag would still be safe because the payload itself is empty).
- **Frontend conditional render (UX polish)** — four sites: `OutreachSearch.tsx` advanced filters, `ShelterForm.tsx` eligibility section + `requires_verification_call` toggle, `HoldDialog.tsx` PII fields, `CoordinatorDashboard.tsx` past-holds PII display.

The flag is baked into JWT claims at token issuance (matches the proven `dvAccess` pattern in this codebase). Token TTL = 15 min, so a CoC admin disabling reentryMode mid-incident hides PII surfaces within 15 min. Fail-safe: missing/undefined flag → falsy → reentry surface hidden. Existing tenants on prod (`dev-coc`, `blueridge`, `mountain`) default to off; the v0.55 deploy runbook §7 includes a step to flip the flag for the demo tenant(s) so the public reentry-story.html deep-dive page actually shows reentry UI to visitors.

Scope: see tasks.md §16 (~30 tasks across 7 sub-sections, ~5-6 hours of careful work).

**G — v0.55 implementation hardening (Path A scope expansion, post-warroom)**

After the 24-persona warroom round, three findings could not be closed by doc edits alone (audit events missing, DOB-in-logs, 24h ≠ 25h truthfulness). Five additional findings are best-effort during this implementation window. These land as code-side requirements under a new `reservation-pii-hardening` capability and a new tasks.md §15:
- Add three `AuditEventType` cases (`RESERVATION_HELD_FOR_CLIENT_RECORDED`, `RESERVATION_PII_DECRYPTED_ON_READ`, `RESERVATION_PII_PURGED`) and wire emitters at write, decrypt-on-read, and purge sites
- Sanitize the DOB-validation exception message at `backend/src/main/java/org/fabt/reservation/service/ReservationService.java:121-122` so user-supplied DOB never appears in logs or 400 response bodies (OWASP ASVS V16)
- Tighten the purge cadence at `backend/src/main/java/org/fabt/referral/service/ReferralTokenPurgeService.java:88` from `fixedRate=3_600_000` (1h) to `fixedRate=900_000` (15min) so worst-case PII lifetime is 24h15m and matches public copy
- Add `LIMIT` to the purge `UPDATE` at `backend/src/main/java/org/fabt/reservation/repository/ReservationRepository.java:135-153` so a backlog cannot lock the table on a small VM
- Drop plaintext PII fields from list-view `ReservationResponse`; return PII only on single-resource detail reads
- Annotate PII fields in `ReservationResponse` with `@Schema(description=...)` so OpenAPI consumers see the privacy posture
- Add `Cache-Control: no-store, private` to every endpoint returning `ReservationResponse`

**Out of scope (deferred to a later slice — target quarters)**
- `PRIVACY.md` (~800 words public privacy policy) — **Tier 2, target Q2-2026**
- `docs/security/threat-model.md` (STRIDE-lite, ~1500 words) — **Tier 2, target Q2-2026**
- `docs/security/dek-rotation-policy.md` — **Tier 2, target Q2-2026**
- `docs/security/zap-v0.55-baseline.md` — **Tier 2, target Q2-2026**
- `docs/security/audit-event-catalog.md` — **Tier 3, target Q3-2026**
- `for-navigators.html` audience card — deferred until lived navigator feedback validates the role term
- DEK-rotation-on-decrypt-fail (sentinel rendering instead of throw) — Riley R-RR-4 follow-up, v0.56 unless Riley confirms current code throws on read
- ReservationPiiPurgeService module relocation (cross-module call from referral → reservation) — Alex A-RR-1, v0.56
- `purgeExpiredHoldAttribution` access narrowing (currently public on service) — Alex A-RR-5, v0.56
- Stale "PLATFORM_ADMIN" reference in `ShelterReservationsController.java:79` Swagger description — Marcus M-RR-4, v0.56 doc-of-code cleanup

## Capabilities

### New Capabilities
- `pii-disclosure-public`: public-facing privacy posture documents and claims that scope the PII surface accurately. Owns `findabed.org/index.html` truthfulness, `docs/government-adoption-guide.md` PII bullets, `docs/hospital-privacy-summary.md` table semantics, and the to-be-authored `docs/legal/right-to-be-forgotten.md`. Distinct from `dignity-centered-copy` (which owns user-facing UI copy) and `audience-specific-docs` (which owns audience-specific narrative docs).
- `reentry-story-page`: the new `demo/reentry-story.html` capability deep-dive page, plus its capture spec, cross-page links, and screenshot inventory. Distinct from `story-landing-page` (root `index.html`) and `demo-capture` (the cross-cutting capture infrastructure).
- `pii-purge-sla-disclosure`: the contract between the public 24-hour PII purge claim and the operational signal (or honestly-disclosed absence of one) that proves the claim. Owns the relevant rows in `docs/security/compliance-posture-matrix.md` and the verification section in the v0.55 runbook.
- `reservation-pii-hardening`: code-side hardening of the v0.55 reservation PII surface so the deployed implementation matches the public posture. Owns the new `AuditEventType` cases for hold-attribution write/read/purge, DOB-validation exception message sanitization, purge cadence tightening (1h → 15min), purge `UPDATE LIMIT`, list-view PII drop, `@Schema` PII annotations, and `Cache-Control: no-store, private` on PII-bearing endpoints. This capability exists because three warroom blockers (audit events missing, DOB-in-logs, 24h ≠ 25h) cannot be closed by doc edits alone.

### Modified Capabilities
- `story-landing-page`: root `index.html` gets the "ever" claim hotfix and the 5th tile in the "See It Work" grid. Requirement change: the front-door page must scope its PII claims to specific paths, not make platform-wide assertions.
- `audience-specific-docs`: `FOR-COC-ADMINS.md` / `FOR-CITIES.md` / `FOR-DEVELOPERS.md` get DV-scope sentences after each "zero PII" claim. Requirement change: every "zero PII" claim in audience docs must be path-scoped.
- `demo-capture`: `capture.sh` learns to enumerate all capture specs (currently runs one of nine; soon to be ten with reentry). Requirement change: capture script must include every `capture-*.spec.ts` in the e2e directory.
- `runbook-template`: the v0.55 runbook gets a PII purge verification section pattern that future runbooks should follow when they ship operational PII claims. Requirement change: runbook template must include a verification section for any operationally-claimed retention SLA.

## Impact

- **Affected files (docs repo `C:\Development\findABed\`):** root `index.html`, `demo/reentry-story.html` (new), `demo/index.html`, `demo/for-coordinators.html`, `demo/for-cities.html`, `demo/for-funders.html`, `demo/dvindex.html`, `demo/capture.sh`
- **Affected files (code repo `finding-a-bed-tonight/`):** `docs/government-adoption-guide.md`, `docs/hospital-privacy-summary.md`, `docs/FOR-COC-ADMINS.md`, `docs/FOR-CITIES.md`, `docs/FOR-DEVELOPERS.md`, `docs/asyncapi.yaml`, `docs/erd.svg`, `docs/schema.dbml`, `docs/architecture.md`, `docs/architecture/tenancy-model.md`, `docs/security/compliance-posture-matrix.md`, `docs/legal/right-to-be-forgotten.md` (new), `docs/oracle-update-notes-v0.55.0.md`, `CHANGELOG.md`, `frontend/src/components/HoldDialog.tsx`, `frontend/src/components/EligibilityCriteriaSection.tsx`, `frontend/src/i18n/en.json`, `frontend/src/i18n/es.json`, `e2e/playwright/tests/capture-reentry-screenshots.spec.ts` (new)
- **Affected files post-Path-A scope expansion (code repo, backend):** `backend/src/main/java/org/fabt/shared/audit/AuditEventType.java` (3 new enum cases), `backend/src/main/java/org/fabt/reservation/service/ReservationService.java` (DOB exception sanitize + write-side audit emit), `backend/src/main/java/org/fabt/reservation/api/ReservationResponse.java` (drop list-view PII + `@Schema` annotations), `backend/src/main/java/org/fabt/reservation/api/ShelterReservationsController.java` (cache headers + read-side audit emit + Swagger description fix), `backend/src/main/java/org/fabt/reservation/repository/ReservationRepository.java` (purge `UPDATE LIMIT`), `backend/src/main/java/org/fabt/referral/service/ReferralTokenPurgeService.java` (cadence 1h → 15min + purge-side audit emit), plus their corresponding `*Test.java` peers.
- **No new Flyway migration. No new dependencies.** Backend code changes are localized hardening of the v0.55 surface that already shipped in `transitional-reentry-support`.
- **Release gate:** v0.55.0 git tag is forbidden until this change is `/opsx:archive`d. The `transitional-reentry-support` change cannot be `/opsx:archive`d before this one — they must archive together as a paired release. Tasks here include the combined-tag step.
- **APIs:** none changed.
- **Tests:** new Playwright capture spec; existing accessibility / Playwright suites must remain green.
- **Hard constraints:** "designed to support" not "compliant" (Casey); no fictional pilots/partnerships/stakeholder names (`feedback_no_named_stakeholders_in_docs`); 24h purge SLA must be honestly disclosed as currently-unmonitored (truthfulness over claim).
