## Why

Persistent notifications (v0.31.0) introduced DV referral escalation: at T+2h after a pending referral with no coordinator action, a CRITICAL banner fires for every CoC admin in the tenant. The banner reads *"N critical notifications require action."* The admin clicks the banner — and lands nowhere. The CoC admin panel has no view of pending referrals, no way to claim one, no way to reassign to a different coordinator, no way to act on a stalled placement. The escalation alarm is real and the response path is a dead end.

This is the canonical "alert fatigue" antipattern. Every CRITICAL banner the admin sees with no action path teaches them the alerts are noise. The Lin et al. 2024 clinical decision support study (PMC10830237) documented an 80% reduction in alert burden plus *improved* compliance when alerts moved from "interruptive with no resolution path" to "workflow-embedded actionable." The FABT system is currently in the failure state that study describes — and unlike a clinical trial, the cost of an ignored CRITICAL here is a survivor's safety.

The persona drivers are unanimous and span both halves of the gap (the action path AND the configurability):

- **📋 Marcus Okafor (CoC admin)** receives CRITICAL banners with no action path TODAY. Every alert without resolution erodes trust in the platform. He also cannot tune escalation thresholds for his 18 partner agencies — the hardcoded 1h/2h/3.5h/4h thresholds will put 60% of his volunteer-run faith partners in continuous CRITICAL state, training him to ignore real CRITICALs within 30 days.
- **🌐 Rev. Alicia Monroe (faith community)** has volunteer coordinators who check the system twice a day. Hardcoded 1h/2h thresholds make her shelters perpetually escalated. She would not deploy.
- **🏥 Dr. James Whitfield (hospital social worker)** has 2-3 hour discharge workflows. Hardcoded 1h/2h thresholds false-alarm on every legitimate hospital referral.
- **🙋 Riley Cho (QA)** — *"What happens to the person in crisis if this alert is ignored?"* The current dead-end trains the system's most senior responders to dismiss the most urgent signal it can produce.
- **🙋 Keisha Thompson (lived experience)** — the language and the destination of the banner are dignity surfaces. The current banner says "needs action" without warmth and goes nowhere; the new one must center the person waiting and offer the worker a path to help them.
- **⚖️ Casey Drummond (attorney)** — VAWA/FVPSA don't mandate specific thresholds, but state coalitions sometimes do. Hardcoded thresholds break the "designed to support compliance" claim the moment the platform ships to a state with different rules. Audit trail of who claimed/reassigned/acted on a referral is the chain-of-custody answer to the court subpoena question.
- **🤝 Maria Torres (PM)** — pilot sequencing requires multiple CoCs with different operational profiles. Without per-tenant configurability, every new pilot conversation hits the wall of *"why is your CRITICAL threshold 2 hours? Our policy is 4."*
- **🏗️ Alex Chen (principal engineer)** — the action path and the configurable policy share the same admin tab and the same data model. Doing them as one feature is ~30% more work than doing them separately and produces a coherent piece of software instead of two half-features.

This change closes issue #82 (CoC admin escalation navigation), unblocks Maria Torres's multi-CoC pilot pathway, and gives Devon Kessler a real business process to document and train on (a gap she has been waiting to fill).

## What Changes

**Backend — admin queue view**
- New endpoint `GET /api/v1/dv-referrals/escalated` — returns pending DV referrals across the tenant for `COC_ADMIN`/`PLATFORM_ADMIN`, ordered by ascending time-to-expiry. Shelter name, age, household size, urgency, assigned coordinator, claim status. Zero PII (no client name, no callback number).
- New endpoints for the claim/release/reassign/act actions (see below).

**Backend — claim/release pattern (PagerDuty acknowledge model)**
- `POST /api/v1/dv-referrals/{id}/claim` — admin claims a referral, soft-lock with `claimed_by_admin_id` + `claim_expires_at`. Visible to all other admins.
- `POST /api/v1/dv-referrals/{id}/release` — manual release.
- Auto-release after claim inactivity, via existing `@Scheduled` infrastructure.
- New columns on `referral_token`: `claimed_by_admin_id UUID`, `claim_expires_at TIMESTAMPTZ`.
- **Configurable timeouts** (D4): `fabt.dv-referral.claim-duration-minutes` (env `FABT_DV_REFERRAL_CLAIM_DURATION_MINUTES`, default `10`) controls the soft-lock window; `fabt.dv-referral.claim-cleanup-interval-seconds` (env `FABT_DV_REFERRAL_CLAIM_CLEANUP_INTERVAL_SECONDS`, default `60`) controls how often the auto-release scheduler runs. Defaults match the original recommendation; per-deployment overrides let CoCs with different operational rhythms tune both knobs.

**Backend — reassign (PagerDuty 3-tab model)**
- `POST /api/v1/dv-referrals/{id}/reassign` — admin reassigns to a different coordinator group / CoC admin / specific user. Specific-user mode is gated behind an "Advanced" disclosure in the UI per PagerDuty's documented warning that user-level reassign breaks the escalation chain.

**Backend — admin acts directly**
- Admins can use the existing `PATCH /api/v1/dv-referrals/{id}/accept` and `/reject` endpoints, currently authorized to `COORDINATOR+`. No endpoint changes — the new admin UI uses the same API. Different audit event type per actor role.

**Backend — per-tenant escalation policy (frozen-at-creation pattern)**
- New table `escalation_policy` (Flyway V46, renumbered from V40 post-v0.34.0 rebase): append-only, versioned per tenant + event_type. Each PATCH from admin creates a new row with `version+1`; old rows are never deleted (audit trail).
- New column `referral_token.escalation_policy_id` (Flyway V47, renumbered from V41): foreign key to the policy snapshot active when the referral was created. The escalation batch job looks up the *frozen* policy for each referral, not the current one. Mid-day policy changes apply only to new referrals.
- New endpoints `GET /api/v1/admin/escalation-policy/{eventType}` and `PATCH /api/v1/admin/escalation-policy/{eventType}` — `COC_ADMIN+` only.
- Validation: monotonically-increasing thresholds, valid roles for recipients, valid severities. PATCH rejects invalid policies.
- New service `EscalationPolicyService` with Caffeine cache (5-min TTL, programmatically evicted on PATCH).
- `ReferralEscalationJobConfig` refactored to read thresholds + recipients from the snapshotted policy instead of hardcoded constants. Backwards-compatible: a NULL `escalation_policy_id` falls back to the platform default policy (a tenant_id=NULL row seeded by Flyway).

**Backend — audit trail to existing `audit_events` table**
- Five new audit event types: `DV_REFERRAL_CLAIMED`, `DV_REFERRAL_RELEASED`, `DV_REFERRAL_REASSIGNED`, `DV_REFERRAL_ADMIN_ACCEPTED`, `DV_REFERRAL_ADMIN_REJECTED`, `ESCALATION_POLICY_UPDATED`. Each records actor_user_id, target_id (referralId or policyId), and a JSON detail blob. Zero PII — IDs only.
- Casey Drummond's lens: this is the chain-of-custody answer to "who acted on the survivor's referral, when, and from which IP."

**Frontend — new admin tab "DV Escalations"**
- New tab in `frontend/src/pages/admin/tabs/DvEscalationsTab.tsx`. Two sections: "Pending Queue" (the referral list) and "Escalation Policy" (the per-tenant config editor).
- Queue view: desktop = table; mobile = card list per Linear's documented progressive-disclosure pattern. Live SSE updates with row-highlight-then-fade. Inline Claim button. Detail view (modal) for Reassign / Approve / Deny actions.
- Policy editor: desktop-only (mobile shows a read-only message). JSON form for thresholds/severities/recipients with inline validation.
- New i18n keys (en + es) for all admin escalation strings, with Keisha Thompson's lens applied: warmth, person-first language, no anxiety-inducing imperative verbs.

**Frontend — actionable CRITICAL banner**
- `CriticalNotificationBanner.tsx` gains a primary CTA button: *"Review N pending escalations →"*. Click navigates to the new admin tab pre-filtered to "needs CoC admin attention." Banner is hidden when the queue is empty.

**Frontend — SSE event types**
- New SSE events: `referral.claimed`, `referral.released`, `referral.policy-updated`, `referral.queue-changed`. Existing send path (no dependency on `sse-backpressure-phase2` — see Out of Scope).

**Documentation**
- New `docs/architecture.md` — Mermaid system overview replacing the legacy `architecture.drawio`. Captures persistent notifications, the new admin escalation flow, the escalation policy module, the SSE flow, the modular monolith boundaries. The drawio file is preserved alongside as a v0.21–v0.28 historical reference.
- New `docs/business-processes/dv-referral-end-to-end.md` (parent) and `dv-referral-escalation.md` (child) — **two companion docs** establishing the new business-process documentation series. The **parent** doc captures the full happy-path flow (search → request → screen → accept → warm handoff → closure) with the base referral_token state machine; the **child** doc is the branch from that parent showing what happens when the escalation timeline fires (T+1h reminder → T+2h CRITICAL → T+3.5h all-hands → T+4h expired) including the new admin claim/release/reassign/act actions and extending the base state machine with a CLAIMED superstate. The child cross-references the parent rather than inlining context. Both contain Mermaid sequence diagrams, role × time matrices, state machines, edge case sections, and persona traceability. Together they serve Devon Kessler's training material foundation, Marcus Okafor's board presentation, and Keisha Thompson's "is this person being centered?" review. Reviewed in a single ~60-minute joint walkthrough.
- `docs/FOR-DEVELOPERS.md` — new section documenting the escalation policy data model, the frozen-at-creation pattern, the new endpoints, and how to add new event types.

## Capabilities

### New Capabilities

- `coc-admin-escalation`: admin queue view of pending DV referrals across tenant, claim/release/reassign/act actions, audit trail.
- `escalation-policy`: per-tenant configurable escalation thresholds with frozen-at-creation versioning.
- `business-process-docs`: new documentation series capturing time-based multi-actor workflows.

### Modified Capabilities

- `persistent-notification-store`: `CriticalNotificationBanner` becomes actionable with a primary CTA. Banner is hidden when queue is empty (alert-fatigue discipline).
- `sse-notifications`: new event types for queue updates, claim/release, policy changes. Uses existing send path.
- `dv-referral-token`: new columns `claimed_by_admin_id`, `claim_expires_at`, `escalation_policy_id`. Existing rows backwards-compatible (NULL = use platform default policy).
- `audit-events`: 5 new event types covering admin escalation actions.

## Out of Scope

- **Per-shelter policy overrides.** The data model is designed (per Alex Chen) to allow `escalation_policy.shelter_id` later without disruptive migration, but MVP only ships per-tenant. Wait for pilot data.
- **Rule engine for compound conditions** (e.g. "if pop_type=DV_SURVIVOR AND household_size>3 then T+1h CRITICAL"). Deferred. Drools-class complexity is over-engineering for MVP.
- **Generalization beyond DV referrals.** The schema supports `event_type` as a parameter, but MVP only wires `dv-referral`. Other event types (`bed-availability-stale`, `surge-activation`) are future work.
- **Email or SMS escalation channels.** SSE + persistent notification table only. Adding email is deferred to a future change once the in-app flow is validated by pilot.
- **Hard dependency on `sse-backpressure-phase2` (#97).** This change uses the existing SSE send path. When `sse-backpressure-phase2` lands, all existing send sites refactor to the new `NotificationEmitter.enqueue()` API; the new event types added here will refactor identically. No coordination required between the two changes other than awareness during the eventual Phase 2 PR review.
- **Capacitor / native app changes** (#53). Native app does not exist yet.
- **Replacing the existing `architecture.drawio`.** The new Mermaid file lives alongside; drawio is preserved as a v0.21–v0.28 historical reference and is not edited in this change.

## Impact

- **Backend:** **5 Flyway migrations** (V46 escalation_policy + thresholds seed; V47 referral_token claim/escalation_policy columns; **V48 audit_events.actor_user_id nullable** to allow system-actor rows from auto-release per war-room round 3 — no-op on v0.34.0+ deployments where V44 already dropped the constraint, preserved for lineage per Elena Vasquez; **V49 referral_token.escalation_chain_broken** for SPECIFIC_USER reassign chain-break + group reassign chain-resume per war-room round 4 / Marcus Okafor; **V50 fix_cocadmin_dv_access** surgical one-user flip for the Oracle demo per the old v0.33.0 deploy plan, renumbered from the originally-planned V44). Migrations renumbered from V40-V43 → V46-V49 + V50 during the post-v0.34.0 rebase because bed-hold-integrity took V44/V45. New `EscalationPolicyService` with two Caffeine caches (currentPolicyByTenant, policyById) plus a `clearCaches_testOnly()` accessor for cross-test cleanup. Refactored `ReferralEscalationJobConfig` reads frozen policy via FK with per-run local caches and a `PENDING_BATCH_LIMIT=5000` guardrail (war-room R6, sort by `expires_at ASC`). Six new audit event types in `AuditEventTypes` constants class. New admin endpoints (escalated queue, claim, release, reassign, policy GET/PATCH); claim/release use **atomic conditional `UPDATE ... RETURNING *`** SQL to close the TOCTOU window (war-room round 1+3, load-bearing concurrency test). **Cross-tenant guards** at the service layer for every endpoint that mutates a referral by id (war-room round 3, Marcus Webb — `referral_token` RLS only checks `dvAccess` not tenant). **Boundary-clean primitive accessors** added to `UserService` (`existsByIdInCurrentTenant`, `getRolesByUserId`, `findActiveUserIdsByRole`, `findDvCoordinatorIds`, `findDisplayNamesByIds`, `isAdminActor`) so the referral module never imports `auth.domain.User` (Alex Chen ArchUnit boundary). **Audit details enriched** per Casey Drummond rounds 3-5: `shelterId` for single-table subpoena queries, `actorRoles` frozen-at-action, `chainResumed:true` on group reassigns that cleared a broken chain, `previousVersion` on policy updates beyond v1. **PII reduction (Keisha Thompson round 3):** the reassign reason lives in the audit row only, NEVER in the broadcast notification payload — recipients see `referralId + targetType` only. **109 backend tests** + **22 ArchUnit assertions** across Sessions 1-4. ArchUnit boundary: escalation_policy stays in `notification` module; referral module touches no auth/User fields directly.
- **Frontend:** new admin tab (`DvEscalationsTab.tsx`) lazy-loaded as a `default export` from `pages/admin/tabs/`, updated `CriticalNotificationBanner` with CTA, tab-specific types in the tab file (NOT `types.ts`), `useDvEscalationQueue` hook that **EXTENDS** existing `useNotifications` (one SSE connection per session, not parallel streams), ~5 Playwright scenarios. Responsive (table → card list on mobile). Policy editor desktop-only. **Conformance to archived UI specs (D20):** `theme/colors.ts` tokens only (no hex), `theme/typography.ts` tokens only (no numeric font sizes), W3C APG tabs pattern, disclosure pattern not menu, 44×44px touch targets, modal focus trap, person-centered i18n, `data-testid` on every interactive element, `npm run build` hard gate before commit.
- **i18n:** ~30 new keys in `i18n/en.json` + `i18n/es.json` (note: flat locale files at `i18n/`, not `i18n/locales/`). Keisha Thompson reviews all user-facing copy before merge with warmth-vs-urgency lens. Casey Drummond runs the legal language scan. Spanish translation by a native speaker familiar with social-services terminology, not a literal translation.
- **Documentation:** new `docs/architecture.md` (Mermaid), new `docs/business-processes/dv-referral-end-to-end.md` (parent) + `dv-referral-escalation.md` (child), updated `docs/FOR-DEVELOPERS.md` with the Escalation Policy + Frozen-at-Creation section.
- **Operations:** zero new infrastructure. No new services, no new external dependencies, no deployment changes. ShedLock TODO comment on `autoReleaseClaims` matching project convention for future multi-instance scale-out.
- **Performance:** policy lookup is cached (Caffeine, 5-min TTL programmatically invalidated on PATCH); the escalation batch job runs every 5 minutes with per-run local caches eliminating N+1 hits. The new admin queue endpoint uses the V47 partial index `idx_referral_token_pending_by_expiry (tenant_id, expires_at) WHERE status = 'PENDING'` exploited by the tenant-filtered SQL. The auto-release scheduler uses the V47 `idx_referral_token_active_claim` partial index via the explicit `claimed_by_admin_id IS NOT NULL` predicate.
- **Security:** new endpoints are `COC_ADMIN+` only. RLS unchanged (CoC admin already had `dvAccess=true` access to referral_token via the existing shelter RLS chain). Service-layer cross-tenant guards on every mutating endpoint by referral id. `@Size(min=1, max=50)` on the threshold list prevents OOM via huge JSONB (Marcus Webb war-room round 3). Marcus Webb sign-off on the policy PATCH endpoint completed during the war-room rounds.
