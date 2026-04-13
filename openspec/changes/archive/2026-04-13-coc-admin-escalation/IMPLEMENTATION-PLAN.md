# Implementation Plan — coc-admin-escalation

**Drafted:** 2026-04-10
**Updated:** 2026-04-11 (post-v0.34.0 rebase — see v0.35.0 retargeting note below)
**Status:** Session 6 complete, Session 7 in progress (post-rebase)
**Total scope:** 59 tasks across 14 sections (~30-50 hours focused work)
**Target release:** **v0.35.0** (originally planned as v0.33.0 before v0.34.0 bed-hold-integrity shipped first; v0.32.2 webhook fix was already bundled into v0.34.0, not this release)
**Deploy:** held per project decision; will go out as a v0.35.0 release

## v0.35.0 retargeting note (2026-04-11)

The original plan targeted **v0.33.0**, bundling this change with the v0.32.2 webhook read-timeout fix. That plan was superseded when GH issue #102 (phantom `beds_on_hold` drift, RCA) was discovered on 2026-04-11 and the founder prioritized it as production-blocking. bed-hold-integrity was implemented and shipped as **v0.34.0** before coc-admin-escalation could complete Session 7. The v0.32.2 fix also shipped earlier as part of v0.32.2/v0.32.3/v0.34.0 rolling deploys and is no longer bundled with coc-admin-escalation.

**Changes from the original v0.33.0 plan:**

1. **Version number:** v0.33.0 → **v0.35.0**. Sequential release order (v0.32.3 → v0.34.0 → v0.35.0). v0.33.0 is skipped — there is no and will be no v0.33.0.
2. **Flyway migrations renumbered:** V40-V43 → **V46-V49**, plus a **new V50** for the cocadmin dv_access flip (originally planned as V44 before bed-hold-integrity claimed V44/V45).
3. **V48 is a no-op on v0.34.0+ deployments** (drops `NOT NULL` on `audit_events.actor_user_id` — v0.34.0's V44 already did this). Preserved for lineage per Elena Vasquez (see V48 header comment).
4. **Rebase conflicts resolved during the rebase itself:** the main `AuditEventTypes.java` file (created by v0.34.0 bed-hold-integrity) now contains both the `BED_HOLDS_RECONCILED` constant AND the 6 DV referral constants from Session 1 of this change. `AuditEventTypesTest` pins all 7. `SecurityConfig.java` gained a block comment documenting the filter-vs-controller authorization invariant that emerged from the v0.34.0 war room (the regression guard for the `/manual-hold` bug).
5. **Task #3 and Task #6** from the v0.34.0 work queue are rolled into Session 7 as part of T-55 and a new **T-55a** (API-level Playwright coverage for `/manual-hold`).

Full rebase plan preserved in memory `project_coc_admin_escalation_post_v034_resume_plan.md` (superseded by `project_v033_deploy_plan.md`).

---

## Overview

This plan breaks the 59-task change into **7 sessions**, each with a clean milestone commit and a verifiable deliverable. Every session ends in a state where the repo is committable, tests pass, and the next session has clear pickup context.

| # | Session | Tasks | Effort | Risk | Deliverable | Independently deployable? |
|---|---------|-------|--------|------|-------------|---------------------------|
| **1** | Foundation + Schema | T-0..T-6 (7) | 1-2h | Low | 3 Flyway migrations + enum constants. Schema in place, no code uses it yet. | ✅ Yes — additive, no behavior change |
| **2** | Policy service + escalation job refactor | T-7..T-12, T-22, T-23 (8) | 4-6h | **Medium** | EscalationPolicyService with caches + refactored escalation job using frozen-at-creation lookup. Behavior unchanged because seeded default policy matches old hardcoded values. | ✅ Yes — behavior identical until policies are tuned |
| **3** | Admin queue + claim/release endpoints | T-13..T-16, T-20, T-21(partial), T-24, T-25, T-29 (~9) | 4-5h | Medium | `GET /escalated`, `POST /claim`, `POST /release`, auto-release scheduler, audit wiring | ✅ Yes — backend-only, no UI consumer yet |
| **4** | Reassign + admin act + policy endpoints | T-17..T-19, T-21(rest), T-26, T-27, T-28 (7) | 4-5h | Low-Medium | `POST /reassign`, admin direct accept/reject differentiation, `GET/PATCH /escalation-policy` | ✅ Yes — full backend feature complete, testable via curl |
| **5** | Frontend tab + components | T-31..T-39, T-42 (10) | 6-8h | Medium | DvEscalationsTab with queue table, mobile cards, detail modal, reassign sub-modal, policy editor, SSE hook | ⚠️ **No** — UI without E2E tests is risky |
| **6** | Banner CTA + Playwright tests | T-40, T-41, T-43..T-47, T-30 (8) | 4-6h | Medium | Critical banner CTA + 5 Playwright scenarios + backend regression re-run | ✅ Yes — full feature with E2E coverage |
| **7** | Documentation + performance + pre-merge | T-48..T-58 (11) | 4-6h | Low | Mermaid architecture, 2 business process docs, FOR-DEVELOPERS, perf verification, PR + release | ✅ Yes — release-ready |

**Total estimated effort:** 27-38 hours focused work.
**Total tasks:** 60 (one task fits in two sessions: T-21 audit wiring spans Sessions 3 and 4)

---

## Pre-flight checklist (do once before Session 1)

- [ ] Verify code repo is on main and up to date: `git checkout main && git pull origin main`
- [ ] Verify v0.32.2 is the current released version: `gh release view --repo ccradle/finding-a-bed-tonight`
- [ ] Confirm no in-flight PRs that would conflict
- [ ] Confirm local dev stack works: `./dev-start.sh` runs cleanly through nginx on :8081
- [ ] Verify openspec change is verify-clean: `openspec status --change coc-admin-escalation` reports `isComplete: true`
- [ ] Verify tracking issue is open: `gh issue view 82 --repo ccradle/finding-a-bed-tonight`

---

## Session 1 — Foundation + Schema

**Goal:** Get the database schema in place with seed data. No application code uses the new tables/columns yet, so behavior is unchanged.

**Tasks:**
- T-0: Create branch `feature/coc-admin-escalation` from main in code repo
- T-1: Capture pre-change baseline (run `ReferralEscalationIntegrationTest`, `NotificationServiceTest`, existing Playwright SSE/notification tests; tee to `logs/coc-escalation-baseline-pre.log`)
- T-2: V46 (renumbered from V40) — `escalation_policy` table (UUID PK, tenant_id FK NULL, event_type VARCHAR, version INT, thresholds JSONB, created_at, created_by, UNIQUE constraint, partial index)
- T-3: V46 seed — platform default policy (tenant_id=NULL, event_type='dv-referral', version=1, current hardcoded thresholds)
- T-4: V47 (renumbered from V41) — `referral_token.escalation_policy_id` UUID FK column (nullable)
- T-5: V47 — `referral_token.claimed_by_admin_id` UUID + `claim_expires_at` TIMESTAMPTZ columns + partial index
- T-6: Add 6 new constants to `AuditEventTypes.java` (the file was created by v0.34.0 bed-hold-integrity; this task adds DV_REFERRAL_CLAIMED, _RELEASED, _REASSIGNED, _ADMIN_ACCEPTED, _ADMIN_REJECTED, ESCALATION_POLICY_UPDATED alongside the existing BED_HOLDS_RECONCILED). No separate SQL migration — the audit_events.actor_user_id nullable change lives in V48.

**Verification:**
- `mvn -q test-compile` clean
- `mvn -q test -Dtest=BaseIntegrationTest` (or similar) — Flyway must apply all 3 migrations cleanly against the Testcontainer
- Run T-1 baseline tests again post-migration → no regressions
- Manual check: `psql` into the test container, run `\d escalation_policy` and `\d referral_token` to confirm schema
- ArchUnit: confirm new migration files don't violate module boundaries (`ArchitectureTest`)

**Commit milestone:** `Add escalation_policy table + referral_token columns + audit event types (Session 1/7)`

**Pause check:** confirm the platform-default policy seed matches the existing hardcoded thresholds exactly. Any mismatch here = silent behavior change in Session 2.

---

## Session 2 — Policy service + escalation job refactor

**Goal:** Wire the new policy lookup into the escalation batch job using frozen-at-creation. Behavior must be identical because the seeded platform default matches old hardcoded values.

**Tasks:**
- T-7: `EscalationPolicy` domain record + `EscalationPolicyRepository` (find current by tenant, find by id, insert new version)
- T-8: `EscalationPolicyService` with two Caffeine caches (`currentPolicyByTenant` for new referrals, `policyById` for batch job lookups)
- T-9: Validation in `EscalationPolicyService.update()` (monotonic thresholds, valid roles, valid severities)
- T-10: Refactor `ReferralEscalationJobConfig.run()` to read from frozen policy via `escalation_policy_id` FK
- T-11: Refactor `ReferralTokenService.create()` to snapshot the current policy ID on new referrals
- T-12: Refactor recipient resolution in batch job to read roles from policy
- T-22: `EscalationPolicyServiceTest` — unit tests for validation, versioning, cache invalidation, fallback to platform default
- T-23: **`ReferralEscalationFrozenPolicyTest` — load-bearing test:** create policy v1, create referral A, change policy to v2, create referral B, run batch job, verify each referral fires per its frozen policy

**Verification:**
- `mvn test -Dtest=EscalationPolicyServiceTest,ReferralEscalationFrozenPolicyTest` → all green
- Re-run baseline tests from Session 1 → still green (no behavior change)
- Manually verify: insert old referral with `escalation_policy_id IS NULL`, run batch job, confirm fallback to platform default works

**Commit milestone:** `EscalationPolicyService + frozen-at-creation policy lookup in escalation job (Session 2/7)`

**Pause check:** the frozen-at-creation test (T-23) is the audit-trail load-bearing piece. Casey Drummond + Riley Cho approval. If this test passes for the wrong reason (e.g., both referrals happen to fire identically), the test is flawed — verify by manual SQL inspection of `escalation_policy_id` on both referrals.

---

## Session 3 — Admin queue + claim/release endpoints

**Goal:** First admin-facing API endpoint goes live. Marcus Okafor's queue view is queryable via curl.

**Tasks:**
- T-13: `GET /api/v1/dv-referrals/escalated` — returns pending DV referrals across tenant for COC_ADMIN+, sorted by expires_at ASC, zero PII
- T-14: `POST /api/v1/dv-referrals/{id}/claim` — soft-lock with auto-release window
- T-15: `POST /api/v1/dv-referrals/{id}/release` — manual release
- T-16: `@Scheduled` auto-release task (every 60s, find expired claims, clear, audit, SSE)
- T-20: `AuditEventService.recordDvReferralAdminAction(...)` wrapper
- T-21 (partial): wire claim, release, auto-release into audit_events
- T-24: `EscalatedQueueEndpointTest` — cross-tenant isolation, ordering, zero PII
- T-25: `ClaimReleaseTest` — claim/override/auto-release SSE event verification
- T-29 (partial): `AuditEventCoverageTest` — verify CLAIMED, RELEASED audit rows

**Verification:**
- All new tests green
- Manual `curl` test: get JWT for COC_ADMIN, hit `/escalated`, verify response shape
- SSE test: open EventSource on `/notifications/stream`, claim a referral, verify `referral.claimed` event arrives with correct payload
- Re-run Session 1 + 2 baselines → no regressions

**Commit milestone:** `Admin escalated queue endpoint + claim/release with audit trail and SSE (Session 3/7)`

**Pause check:** Claim concurrency. Test the override-claim header path AND verify two simultaneous claims (e.g., via `parallel` curl) don't both succeed without override.

---

## Session 4 — Reassign + admin act + policy endpoints

**Goal:** All backend endpoints complete. Full feature is testable via API without UI.

**Tasks:**
- T-17: `POST /api/v1/dv-referrals/{id}/reassign` with 3 target types (COORDINATOR_GROUP, COC_ADMIN_GROUP, SPECIFIC_USER)
- T-18: `GET /api/v1/admin/escalation-policy/{eventType}` — current policy for caller's tenant, fallback to platform default
- T-19: `PATCH /api/v1/admin/escalation-policy/{eventType}` — insert new versioned row, validate, invalidate cache, audit
- T-21 (rest): wire reassign, admin accept/reject, policy update into audit_events with role-differentiated event types
- T-26: `ReassignTest` — all 3 target types, audit verification
- T-27: `AdminAcceptRejectTest` — verify admin actions get `_ADMIN_ACCEPTED`/`_ADMIN_REJECTED` audit types
- T-28: `EscalationPolicyEndpointTest` — GET fallback, PATCH success/validation/auth

**Verification:**
- All new tests green
- Manual test: PATCH a new policy via curl, run the batch job manually, verify a NEW referral fires per the new policy and an OLD referral fires per the old (frozen-at-creation working end-to-end)
- Marcus Webb sign-off opportunity: pen test the new admin write surfaces

**Commit milestone:** `Reassign, admin direct accept/reject, escalation policy CRUD (Session 4/7)`

**Pause check:** This is the **backend-complete** milestone. Could be its own PR if you want to ship backend before frontend. Recommended: stop here, run full backend suite (`mvn clean test`), check it's green, decide whether to PR-and-merge backend separately or wait.

---

## Session 5 — Frontend tab + components

**Goal:** UI consumes the backend API. Marcus Okafor can click and see the queue.

**Tasks:**
- T-31: Add `'dvEscalations'` to TabKey + types for `EscalatedReferral`, `EscalationPolicy`, `EscalationPolicyThreshold`
- T-32: Register tab in `AdminPanel.tsx` TABS array, lazy-load
- T-33: `DvEscalationsTab.tsx` top-level component (Queue + Policy segments, mobile shows Queue only)
- T-34: `EscalatedQueueTable.tsx` desktop table with live SSE updates
- T-35: `EscalatedQueueCardList.tsx` mobile card list
- T-36: `EscalatedReferralDetailModal.tsx` with Claim, Reassign, Approve, Deny actions + 5-min undo ribbon
- T-37: `ReassignSubModal.tsx` with 3-tab pattern (Advanced disclosure for SPECIFIC_USER)
- T-38: `EscalationPolicyEditor.tsx` desktop-only with inline validation
- T-39: `useDvEscalationQueue.ts` hook subscribing to 4 SSE event types
- T-42 (partial): i18n keys for everything in this session (en + es)

**Verification:**
- `npm run build` clean (TypeScript + Vite, per `feedback_build_before_commit`)
- ESLint clean
- Manual smoke through nginx (`http://localhost:8081/admin#dvEscalations`):
  - Queue loads
  - Click row opens detail modal
  - Claim button works (visible to second admin in second browser via SSE)
  - Reassign sub-modal opens, all 3 tabs functional
  - Policy editor saves successfully
  - Mobile viewport (DevTools 375x667): queue is card list, policy editor is read-only

**Commit milestone:** `DvEscalationsTab UI with queue, detail modal, reassign, policy editor (Session 5/7)`

**Pause check:** **Do NOT deploy after this session.** UI without Playwright tests is the riskiest state. Do not merge to main until Session 6 adds the tests.

---

## Session 6 — Banner CTA + Playwright tests

**Goal:** End-to-end coverage for the full feature. Safe to merge to main.

**Tasks:**
- T-40: Update `CriticalNotificationBanner.tsx` — add CTA button "Review N pending escalations →", hide when N=0
- T-41: React Router anchor handling for `#dvEscalations`
- T-43: Playwright `coc-escalation-banner.spec.ts` — fixture creates pending DV referral, verifies banner+CTA, click navigates to tab
- T-44: Playwright `coc-escalation-claim.spec.ts` — admin A claims, admin B sees update via SSE within 2s, override flow
- T-45: Playwright `coc-escalation-reassign.spec.ts` — coordinator group reassign, SSE event, audit
- T-46: Playwright `coc-escalation-policy.spec.ts` — edit policy, frozen-at-creation verification (existing referral keeps old policy)
- T-47: Playwright `coc-escalation-mobile.spec.ts` — mobile viewport, card list, policy editor read-only
- T-30: Re-run **all** existing escalation/notification baseline tests → zero regressions allowed

**Verification:**
- Full Playwright suite through nginx (`BASE_URL=http://localhost:8081`, per `feedback_check_ports_before_assuming`)
- Tee to `logs/playwright-coc-escalation.log`
- Backend full suite (`mvn clean test`) — 0 failures, ArchUnit intact

**Commit milestone:** `Critical banner CTA + Playwright E2E coverage + backend regression check (Session 6/7)`

**Pause check:** **This is the merge-safe milestone.** All tests green, full backend + frontend feature complete. Could open PR here if you want to ship before docs.

---

## Session 7 — Documentation + performance + pre-merge

**Goal:** Documentation deliverables + release.

**Tasks:**
- T-48: Create `docs/architecture.md` — Mermaid system overview replacing legacy `architecture.drawio`
- T-49: Create `docs/business-processes/dv-referral-end-to-end.md` — parent doc, happy path
- T-50: Create `docs/business-processes/dv-referral-escalation.md` — child doc, escalation branch (joint review with T-49)
- T-51: Update `docs/FOR-DEVELOPERS.md` — Escalation Policy and Frozen-at-Creation section
- T-52: Verify batch job p95 unchanged (Micrometer timer review)
- T-53: New Micrometer metrics + Grafana panels
- T-54: Full backend suite final run, tee log
- T-55: Full Playwright suite final run, tee log
- T-56: Open PR against main, link #82, link openspec change, hold for scans
- (After scans green) merge PR
- T-57: Bump pom.xml to v0.35.0, promote CHANGELOG, tag, GitHub release, comment on #82
- T-58: After release: `/opsx:verify` → `/opsx:sync` → `/opsx:archive coc-admin-escalation`

**Verification:**
- All 11 CI checks green on the PR (CI, E2E Playwright + Karate, all 3 CodeQL, DV Access Control Canary, Legal Language Scan, Backend Java 25 Maven, Frontend Node 20 Vite, Docker Build, Performance Gatling)
- v0.35.0 release page published
- Issue #82 closed with reference to release
- OpenSpec archived to `openspec/changes/archive/2026-04-XX-coc-admin-escalation/`

**Commit milestones:**
1. `Documentation + performance verification (Session 7/7 prep)`
2. `Bump to v0.35.0 — coc-admin-escalation + webhook read timeout fix`
3. `Archive coc-admin-escalation (Nth change), sync 12 reqs to main specs`

---

## PR strategy: one big PR or many small ones?

**Two viable approaches:**

### Approach A — One PR per session (~6-7 PRs total)

**Pros:**
- Smaller, focused review surfaces
- Easier to revert if a session introduces a problem
- CI runs catch regressions session-by-session
- Each session's commit is in main quickly, reducing rebase pain
- Marcus Webb / Alex Chen can review the policy service in isolation from the UI

**Cons:**
- More overhead (7 PR descriptions, 7 release-cycles for the verify-and-merge dance)
- The bundled v0.35.0 release at the end is harder to coordinate
- Some sessions are not independently shippable (Session 5 specifically)

### Approach B — One big PR after Session 6, docs PR after Session 7

**Pros:**
- Single review pass
- Clean v0.35.0 release at the end
- Matches how `platform-hardening` originally shipped (one big PR)

**Cons:**
- ~30+ hours of work in one PR is hard to review thoroughly
- Higher risk of "almost there" syndrome stretching into extra sessions

### My recommendation: hybrid

- **Sessions 1-4 (backend):** one PR. Backend-complete, fully tested via integration tests, ready to merge before any UI work begins. Marcus Webb can pen test the API surface.
- **Sessions 5-6 (frontend + Playwright):** second PR. Frontend depends on backend being merged. Playwright tests need both.
- **Session 7 (docs + release):** third PR (small, mostly markdown).

3 PRs total, each with a clear scope. v0.35.0 ships from the third merge.

---

## Contingencies

| Risk | Mitigation |
|------|------------|
| A session takes 2x estimated time | Stop at the natural sub-checkpoint inside the session. Each session has internal rollback points (e.g., Session 3 could land just T-13/T-14/T-24 if claim is harder than expected). Better to ship a working subset than a half-broken superset. |
| Frozen-at-creation test (T-23) fails for subtle reasons | Pause Session 2. Inspect actual `escalation_policy_id` values on test referrals via `\d` and `SELECT`. Don't guess — trust the catalog (memory: `feedback_no_guessing`). |
| `@ConcurrencyLimit` from Spring Framework 7 doesn't behave as expected (this is a relatively new feature) | This isn't in coc-admin-escalation (it's in sse-backpressure-phase2). Not a risk for this change. |
| Mobile responsive policy editor is harder than estimated | Cut scope: ship the desktop-only editor with a "mobile not supported" message. Acceptable per the spec scenario. |
| Playwright SSE timing flakes in CI | Add `await page.waitForResponse(...)` instead of fixed sleeps. Per memory `feedback_facts_over_guessing` — use traces, not guessing. |
| Frontend build fails on commit (per memory `feedback_build_before_commit`) | This is a hard rule: `npm run build` (tsc + vite) MUST succeed before every frontend commit. Build into the workflow. |
| Spec drift discovered mid-implementation | Pause, update the spec artifacts in the openspec change directory, get sign-off, then continue. Don't ship implementation that doesn't match the spec. |

---

## Persona traceability per session

| Session | Primary persona |
|---------|----------------|
| 1 (Schema) | 🏗️ Alex Chen — schema correctness, ArchUnit boundaries |
| 2 (Policy + frozen) | ⚖️ Casey Drummond — frozen-at-creation is the audit-trail load-bearing piece; 🙋 Riley Cho — load-bearing test |
| 3 (Queue + claim) | 📋 Marcus Okafor — first admin-visible feature; 🔒 Marcus Webb — admin write surface review |
| 4 (Reassign + policy) | 📋 Marcus Okafor — full backend feature; ⚡ Sam Okafor — perf gate (cache hit rate, batch job p95) |
| 5 (Frontend) | 📋 Marcus Okafor — UI; 🙋 Keisha Thompson — copy review (will happen in Session 6 with i18n) |
| 6 (Banner + Playwright) | 🙋 Keisha Thompson — banner copy en+es review; 🙋 Riley Cho — E2E coverage |
| 7 (Docs + release) | 📋 Devon Kessler — business process docs review; 📋 Marcus Okafor — docs review; 🙋 Keisha Thompson — final dignity pass |

---

## What's NOT in this plan (intentionally)

- **Per-shelter policy overrides** — deferred to a future change per design D7
- **Rule engine for compound conditions** — over-engineering for MVP
- **Email/SMS escalation channels** — out of scope, would be its own change
- **Generalization beyond DV referrals to other event types** — schema supports it, MVP does not wire it
- **Replacing `docs/architecture.drawio`** — preserved as v0.21–v0.28 historical reference; new Mermaid file lives alongside
- **Hard dependency on `sse-backpressure-phase2` (#97)** — this change uses the existing SSE send path; will refactor cleanly when Phase 2 lands
- **Deploy** — held per project decision; will go out as v0.35.0 bundle (with v0.32.2 webhook fix)

---

## Approval to start Session 1

When you're ready to start Session 1:

1. Reply to confirm you want to start *(or modify the plan first)*
2. I'll commit this `IMPLEMENTATION-PLAN.md` to the docs repo first (so it's durable across sessions)
3. Then `git checkout main && git pull` in the code repo
4. Then T-0 (branch creation)
5. Then T-1 (baseline) and onward through Session 1

Until you give the go-ahead, I won't touch any code or create any branches.
