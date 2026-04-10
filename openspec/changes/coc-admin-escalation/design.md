## Context

Issue #82 ("CoC admin escalation navigation — admin panel referral view") was filed as a gap report against v0.31.0. The persistent notifications work (#77, v0.31.0) introduced DV referral escalation: a `@Scheduled` batch job (`ReferralEscalationJobConfig`) scans pending referrals every 5 minutes and fires notifications at hardcoded thresholds (T+1h reminder → coordinators, T+2h CRITICAL → CoC admins, T+3.5h CRITICAL → all hands, T+4h expired). The CRITICAL banner (`CriticalNotificationBanner.tsx`) renders the count for any user with unread CRITICAL notifications. There is no click handler, no CTA, no destination — the banner is static text.

The 2026-04-10 codebase audit confirmed the gap is purely UI/UX plus one missing backend endpoint. The data already exists and is queryable: a CoC admin with `dvAccess=true` can SELECT all DV referrals in their tenant via the existing shelter RLS chain. The `referral_token` table has `status`, `expires_at`, `created_at`, `shelter_id`, `referring_user_id` — everything needed for an admin queue view. What's missing is (a) an endpoint that exposes "all pending across all shelters in the tenant" (the existing `/pending?shelterId=X` requires a shelter filter and is coordinator-scoped), (b) a frontend admin tab to display and act on the queue, and (c) — a separate but converging concern from business-SME consultation — per-tenant configurability of the escalation thresholds themselves.

The configurability concern came out of the SME round-table (2026-04-10). Marcus Okafor's 18 partner agencies, Rev. Monroe's volunteer-run faith shelters, and Dr. Whitfield's hospital discharge workflows all have operationally different escalation profiles. Hardcoding `[1h, 2h, 3.5h, 4h]` locks the platform to a single CoC's profile and breaks the multi-CoC pilot pathway. Maria Torres (PM) made the decisive case: configurability is not a future enhancement, it is a precondition for any pilot conversation beyond the first deployment.

External research on admin alert UX (2026-04-10, see proposal.md sources) converged on six patterns: (1) actionable banners with explicit CTAs (Carbon, NN/g, Atlassian, GOV.UK), (2) queue + claim soft-lock (PagerDuty acknowledge), (3) confirmation modals with specific-verb CTAs and undo windows (GitLab Pajamas, NN/g), (4) SSE-driven live updates (project already has SSE wired), (5) mobile = card list with progressive disclosure (Linear), (6) PagerDuty's three-tab reassign with the "specific user" option de-emphasized as Advanced.

This change is the bundled implementation of the action path (issue #82) and the configurability concern (Maria Torres's pilot blocker). The two halves share the same admin tab and the same RBAC; doing them as one feature is ~30% more work than doing them separately and produces a coherent piece of software instead of two half-features that step on each other's PRs.

## Goals / Non-Goals

**Goals:**
- Eliminate the dead-end CRITICAL banner. Every CRITICAL alert leads to an actionable admin queue view.
- Provide CoC admins with a working chain: see → claim → reassign or act → audit trail.
- Enable per-tenant configurable escalation thresholds without adding deployment infrastructure.
- Produce business-process documentation (Mermaid) that Devon Kessler can use for training and Marcus Okafor can use for board presentations.
- Replace the stale `architecture.drawio` (last updated 2026-03-26, predates v0.31.0) with a Mermaid diagram living in markdown.

**Non-Goals:**
- Per-shelter policy overrides (data model supports it, MVP does not ship it).
- Rule engine for compound conditions.
- Generalization beyond DV referrals.
- Email or SMS escalation channels.
- Hard dependency on `sse-backpressure-phase2`.
- Rewriting the persistent notification system (it works correctly; the gap is purely the missing action path).

## Decisions

### D1: Banner becomes actionable with a primary CTA (NN/g + IBM Carbon)

`CriticalNotificationBanner.tsx` gains a primary action button. The button text is **"Review N pending escalations →"** where N is the count of unread CRITICAL notifications matching `type LIKE 'escalation.%'`. Click navigates to `/admin#dvEscalations` (the new admin tab anchor). The banner is **hidden when the count is zero** — alert-fatigue discipline per the Lin et al. 2024 CDS study (PMC10830237) and NN/g's "do not cry wolf."

Keisha Thompson's lens on the copy: "Review pending escalations" is task-language without anxiety verbs. Not "Take action" (puts burden on the worker), not "Critical: act now" (urgency without warmth). Spanish: *"Revisar N escalaciones pendientes →"*. Reviewed by Keisha + Casey (legal language scan) before merge.

### D2: New admin tab "DV Escalations" with two sections (Queue + Policy)

`frontend/src/pages/admin/tabs/DvEscalationsTab.tsx`. Two top-level sections:

- **Pending Queue** — the referral list, the primary work surface. Sorted by ascending time-to-expiry. Live SSE updates with row-highlight-then-fade.
- **Escalation Policy** — the per-tenant configuration editor. Hidden behind a secondary tab/segment within the admin tab to keep the queue prominent.

Tab key in `types.ts`: `'dvEscalations'`. Added to the existing 10-tab list (becomes 11). i18n key: `admin.dvEscalations`.

Authorization at the URL level remains `.authenticated()` per the existing admin panel pattern; the tab is server-side gated by `@PreAuthorize("hasAnyRole('COC_ADMIN', 'PLATFORM_ADMIN')")` on the underlying endpoints.

### D3: Queue view — desktop table, mobile card list (Linear progressive-disclosure pattern)

**Desktop (≥768px):** table with columns:

| Shelter | Time-to-expiry | Population | Household | Urgency | Coordinator | Claim status |

- Time-to-expiry is a live countdown; row background is subtle red when <15 min remaining (per Five Rights "right format").
- Claim status: empty / "Claimed by Jane (2m ago)" with the claim auto-releasing after 10 min inactivity.
- Inline action: **Claim** button (cheap, single click). All other actions go to the detail view.
- Default sort: ascending by time-to-expiry. Secondary sort: shelter name.
- Pagination: not in MVP — the queue is bounded by realistic operational scale (~10-20 items at peak per the issue body). If a CoC routinely shows >50, paginate later.

**Mobile (<768px):** card list, one card per referral. Visible fields: shelter, time-to-expiry, single primary CTA (Claim). All other actions hidden in a "More" menu that opens the detail view. Per Linear's documented mobile pattern: progressive disclosure beats trying to fit a wide table.

**Detail view (modal):** opened by clicking a row. Shows the full referral context (population, household, urgency, special needs at the row level — no PII like callback number or client name), claim status, and four action buttons:

1. **Claim** (or **Release** if already claimed by current admin)
2. **Reassign** (opens reassign sub-modal — see D5)
3. **Approve placement** (consequential, danger-variant, with confirmation — see D6)
4. **Deny** (with required reason text field — see D6)

### D4: Claim/release as soft-lock (PagerDuty acknowledge model)

When an admin clicks **Claim**:

1. `POST /api/v1/dv-referrals/{id}/claim` — sets `referral_token.claimed_by_admin_id` and `claim_expires_at = NOW() + 10 minutes`.
2. SSE emits `referral.claimed` event tagged with `claimed_by_admin_id` so other admins' queue views update in real-time.
3. The row in other admins' queue views shows "Claimed by Marcus (just now)" and the Claim button becomes disabled.
4. The other admin can still **override the claim** with an extra confirmation modal — soft-lock, not hard-lock. PagerDuty's acknowledge pattern is deliberately soft because hard-lock creates deadlock if the claiming admin closes their laptop.

When the claim auto-releases (10 min of inactivity, no follow-up action):

1. A `@Scheduled` task (every minute) finds tokens with `claim_expires_at < NOW()` and clears `claimed_by_admin_id` + `claim_expires_at`.
2. SSE emits `referral.released` so other admins see the row become available again.
3. The auto-release event writes to `audit_events` as `DV_REFERRAL_RELEASED` with `actor_user_id = system`.

`@Scheduled` cleanup interval is 60 seconds. Configurable via `fabt.dv-referral.claim-cleanup-interval-seconds` (default 60). Default 10-min claim duration via `fabt.dv-referral.claim-duration-minutes` (default 10). Both exposed via env var.

### D5: Reassign — PagerDuty three-tab pattern (role > group > user)

`POST /api/v1/dv-referrals/{id}/reassign` with body `{target_type: COORDINATOR_GROUP|COC_ADMIN_GROUP|SPECIFIC_USER, target_id: <UUID>}`.

Frontend: a sub-modal with three tabs:

1. **To another coordinator** *(default tab)* — searchable list of coordinators assigned to the same shelter, plus optionally the shelter's coordinator group.
2. **To CoC admin group** — escalates back into the same `COC_ADMIN` recipient group, useful when the current admin is going off-shift.
3. **To specific user** — gated behind an "Advanced" disclosure expander. Per PagerDuty's documented warning: reassigning to an individual breaks the escalation chain because future escalations of this referral are no longer governed by the policy.

Reassign writes to `audit_events` as `DV_REFERRAL_REASSIGNED` with the target type and target ID in the JSON detail blob.

### D6: Approve / Deny — confirmation modal with specific verb + 5-min undo (GitLab Pajamas + NN/g)

The admin's direct accept/reject path uses the existing `PATCH /api/v1/dv-referrals/{id}/accept` and `/reject` endpoints (already authorized to `COC_ADMIN+` via the existing role hierarchy). The new behavior is the **frontend confirmation flow**:

- **Approve placement** — modal opens, shows the survivor's referral context (population, household, urgency — NO PII), primary button labeled with the specific verb *"Approve placement at [Shelter Name]"* (not "Confirm"). Uses Carbon's `danger` variant. After click, the action is committed but a 5-minute undo ribbon appears at the top of the page: *"Approved 0:00 ago — Undo"*. The undo window is 5 minutes per the GitLab Pajamas + NN/g + Smashing 2024 synthesis. After 5 minutes the action is final.
- **Deny** — modal opens with a **required reason text field** (per existing reject endpoint contract). Same specific-verb pattern: *"Deny placement at [Shelter Name]"*. Same 5-min undo.

Why undo and not type-to-confirm: the action is reversible within a short window, and type-to-confirm would train admins to copy-paste past the friction. NN/g is explicit: do not use confirmation friction for routine high-frequency actions; prefer undo.

Audit events: `DV_REFERRAL_ADMIN_ACCEPTED` and `DV_REFERRAL_ADMIN_REJECTED` (distinct from the existing `DV_REFERRAL_ACCEPTED`/`_REJECTED` which are coordinator actions). The actor's role distinguishes them — Casey Drummond's chain-of-custody requires knowing who acted.

### D7: Per-tenant escalation policy with append-only versioning + frozen-at-creation

**Schema (Flyway V40):**

```sql
CREATE TABLE escalation_policy (
    id              UUID PRIMARY KEY,
    tenant_id       UUID REFERENCES tenant(id),  -- NULL = platform default
    event_type      VARCHAR(64) NOT NULL,
    version         INTEGER NOT NULL,
    thresholds      JSONB NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID REFERENCES app_user(id),
    UNIQUE(tenant_id, event_type, version)
);

CREATE INDEX idx_escalation_policy_current
  ON escalation_policy(tenant_id, event_type, version DESC);
```

The table is **append-only**. Each PATCH from the admin creates a new row with `version = current+1`. Old rows are never UPDATEd or DELETEd — they are the audit trail and the source of truth for the frozen-at-creation lookup.

**Policy JSONB shape:**

```json
{
  "thresholds": [
    {"at": "PT1H",   "severity": "ACTION_REQUIRED", "recipients": ["COORDINATOR"]},
    {"at": "PT2H",   "severity": "CRITICAL",        "recipients": ["COC_ADMIN"]},
    {"at": "PT3H30M","severity": "CRITICAL",        "recipients": ["COORDINATOR","OUTREACH_WORKER"]},
    {"at": "PT4H",   "severity": "INFO",            "recipients": ["OUTREACH_WORKER"]}
  ]
}
```

ISO 8601 durations (`Duration.parse(...)`). Validation enforces monotonic ordering: `t[i].at < t[i+1].at`. Recipients must be valid role enum values. Severities must be `INFO|ACTION_REQUIRED|CRITICAL`.

**Default policy seeded by Flyway** at V40 with `tenant_id = NULL` and the current hardcoded values `[1h, 2h, 3.5h, 4h]`. Existing tenants do NOT get individual rows on migration — they fall back to the platform default until they explicitly customize via PATCH (which inserts their first version=1 row).

**Frozen-at-creation pattern (Flyway V41):**

```sql
ALTER TABLE referral_token
  ADD COLUMN escalation_policy_id UUID REFERENCES escalation_policy(id);
```

`ReferralTokenService.create()` looks up the **current** policy for the tenant (`SELECT id FROM escalation_policy WHERE tenant_id = ? AND event_type = 'dv-referral' ORDER BY version DESC LIMIT 1`, falling back to `tenant_id IS NULL` if no tenant-specific policy exists) and stores the FK on the new referral. Existing rows have `escalation_policy_id = NULL` and the batch job falls back to the platform default for them — backwards compatible.

**Why frozen-at-creation:** Casey Drummond's audit lens. If a tenant changes their escalation policy at noon, a referral created at 11am follows the OLD policy until it terminates. The court subpoena answer is unambiguous: "this referral was governed by escalation_policy version X, here are the thresholds, here are the audit events."

**Service:** `EscalationPolicyService` with Caffeine cache (max 100 entries, 5-min TTL, programmatically invalidated on PATCH). Cache key: `(tenant_id, event_type, policy_id)` because the lookup pattern is "give me the policy this referral was frozen against." A separate cache for "current policy by tenant" used by `ReferralTokenService.create()`.

**Endpoints:**

- `GET /api/v1/admin/escalation-policy/{eventType}` — returns the **current** policy for the caller's tenant. `COC_ADMIN+` only.
- `PATCH /api/v1/admin/escalation-policy/{eventType}` — body is the new thresholds JSON. Inserts a new row with `version+1`. Validates monotonicity, recipients, severities. `COC_ADMIN+` only. Writes to `audit_events` as `ESCALATION_POLICY_UPDATED`.

### D8: All admin escalation actions write to audit_events

Six new audit event types in the existing `audit_events` table (the table introduces six rows even though the original count said five — the seventh action `auto-release` reuses the `DV_REFERRAL_RELEASED` type with `actor_user_id = system`):

| Type | Trigger | Detail blob |
|---|---|---|
| `DV_REFERRAL_CLAIMED` | `POST /claim` | `{referral_id, claimed_until}` |
| `DV_REFERRAL_RELEASED` | `POST /release` or auto-release (`actor_user_id = system` for auto) | `{referral_id, reason: "manual\|timeout"}` |
| `DV_REFERRAL_REASSIGNED` | `POST /reassign` | `{referral_id, target_type, target_id, previous_assignee_id}` |
| `DV_REFERRAL_ADMIN_ACCEPTED` | `PATCH /accept` by COC_ADMIN+ | `{referral_id, shelter_id}` |
| `DV_REFERRAL_ADMIN_REJECTED` | `PATCH /reject` by COC_ADMIN+ | `{referral_id, shelter_id, reason}` |
| `ESCALATION_POLICY_UPDATED` | `PATCH /escalation-policy` | `{policy_id, event_type, version, previous_version}` |

Zero PII in the detail blob — only IDs, roles, and structured metadata. The actor_user_id, IP address, and timestamp are recorded by the existing audit infrastructure. Casey Drummond's chain-of-custody is satisfied.

**Implementation form (added Session 1, 2026-04-10 — tech-lead round-table review):** the 6 type strings live in `org.fabt.shared.audit.AuditEventTypes` as `public static final String` constants on a `final class` with a private constructor (Effective Java Item 4 utility-class pattern). The original tasks.md T-6 wording assumed an `AuditEventType` Java `enum` already existed; investigation in Session 1 confirmed it does not — the existing codebase passes audit type strings as bare `String` literals (e.g. `"ROLE_CHANGED"` in `UserService:100`). The constants-class form was chosen consciously over a true enum because:

1. **Additive Session 1 scope.** A true enum would require migrating every existing `String` call site at once, refactoring `AuditEventRecord` (whose `action` field is `String`), and touching `UserService`, `AuthController`, `PasswordController`, etc. Out of scope for the schema-only first chunk.
2. **New code in Sessions 3-4 still gets compile-time discoverability** by referencing `AuditEventTypes.DV_REFERRAL_CLAIMED` instead of bare strings.
3. **Riley Cho's contract-pin test** (`AuditEventTypesTest`) locks the string values against accidental refactor — guards against the "someone shortens the constant value and breaks every audit query" failure mode that constants alone don't prevent.
4. **A future cleanup change** should migrate all audit type strings (not just these six) from `String` to a true enum. Tracked as a separate follow-up issue, not in this change. Alex Chen's "do it for real or don't bother" stance acknowledged but explicitly deferred.

Trade-offs accepted:
- Constants do NOT enforce that `AuditEventService.publish(actorId, targetId, "TYPO", null, ip)` is rejected at compile time. Existing call sites with bare strings remain typo-vulnerable until the future enum migration.
- The class lives in `org.fabt.shared.audit` (cross-cutting infrastructure), not in `org.fabt.dv.audit` or similar. This is correct because `audit_events` is a cross-module concern; coupling shared infrastructure to a single domain would constrain future audit consumers.

### D9: SSE event types and live queue updates

Four new SSE event types pushed via the existing `NotificationService.pushNotification()` path:

- `referral.claimed` — sent to all CoC admins in the tenant when a claim happens. Payload: `{referralId, claimedByUserId, claimedUntil}`.
- `referral.released` — sent on manual or auto-release. Payload: `{referralId, reason}`.
- `referral.queue-changed` — sent when a referral's status changes (accepted, rejected, expired, or a new pending referral appears). Payload: `{referralId, status, shelterId}`.
- `referral.policy-updated` — sent when the tenant policy is PATCHed. Payload: `{policyId, version, eventType}`. The frontend uses this to invalidate any cached policy view.

The frontend's `useDvEscalationQueue` hook subscribes to these events and reconciles the queue state with row-highlight-then-fade per NN/g's change-awareness pattern.

**No new SSE infrastructure.** These events use the existing send path. When `sse-backpressure-phase2` (#97) lands, the new events refactor identically to all the existing events — they will be enqueued through `NotificationEmitter.enqueue()` instead of called directly. Forward-compatible by design.

### D10: Documentation deliverables — Mermaid architecture + business process

Two new docs are deliverables of this change, not afterthoughts:

**`docs/architecture.md`** — Mermaid system overview replacing the legacy `architecture.drawio` (which was last touched 2026-03-26 and predates v0.31.0). Contains:

1. **System overview** — Cloudflare → nginx → Spring Boot → PostgreSQL, with the persistent notification table, the SSE flow, the escalation batch job, and the new admin escalation queue all visible.
2. **Module map** — the modular monolith boundaries (`auth`, `availability`, `shelter`, `dv`, `notification`, `subscription`, `admin`, `escalation-policy`).
3. **DV escalation data flow** — from `referral_token` → `escalation_policy` (frozen-at-creation FK) → `ReferralEscalationJobConfig` → `notification` table → SSE → CoC admin queue view.

The legacy `architecture.drawio` is preserved alongside as a v0.21–v0.28 historical reference. Future architecture updates use Mermaid in markdown for natural GitHub rendering and PR diffability.

**`docs/business-processes/dv-referral-end-to-end.md`** *(parent doc)* — captures the full DV referral happy path. Contains:

1. **Actor inventory** — outreach worker, coordinator, CoC admin, survivor — each linked to its persona in PERSONAS.md.
2. **Sequence diagram** (Mermaid `sequenceDiagram`) of the happy path: search → request → screen → accept → warm handoff → closure.
3. **Role × phase matrix** — who does what at each phase.
4. **State machine** (Mermaid `stateDiagram-v2`) of the base `referral_token` machine: `PENDING → ACCEPTED|REJECTED|EXPIRED`. The escalation doc extends this with the `CLAIMED` superstate.
5. **Cross-reference to escalation doc** for the unhappy-path branch.

**`docs/business-processes/dv-referral-escalation.md`** *(child doc)* — the escalation branch of the parent flow. Contains:

1. **Sequence diagram** (Mermaid `sequenceDiagram`) of the escalation timeline: T+1h reminder → T+2h CRITICAL → T+3.5h all-hands → T+4h expired, including the new admin claim/release/reassign/act actions.
2. **Role × time matrix** — what role gets what notification at what threshold. Frozen-at-creation note.
3. **State machine extension** (Mermaid `stateDiagram-v2`) — `PENDING → CLAIMED → ACCEPTED|REJECTED|REASSIGNED|EXPIRED` showing how `CLAIMED` plugs into the parent's base machine.
4. **Edge cases** — coordinator offline, two admins claim simultaneously, survivor cancels mid-flow, expiry race conditions, policy update mid-flow (frozen-at-creation answer).
5. **Persona traceability** — which persona drives which step.
6. **Back-reference** to the parent doc instead of inlining context.

**Both docs are reviewed together** by Devon Kessler (training), Marcus Okafor (CoC admin), and Keisha Thompson (dignity) before merge. Establishing two companion docs (not one) sets the precedent that the business-process documentation series is multi-doc by default — each major feature gets its own happy-path + edge-case pairing.

## Risks / Trade-offs

- **Soft-lock vs hard-lock on Claim.** Soft-lock can produce duplicate admin actions if both admins ignore the visible "claimed by" indicator. Mitigated by SSE real-time push + the second admin needing an extra confirmation modal to override. PagerDuty deliberately chose soft-lock for the same reason — hard-lock creates deadlocks. Accepted trade-off.

- **Frozen-at-creation policy versioning** is more complex than prospective-only. Adds an FK column on `referral_token` and an append-only versioned table. The audit benefit is decisive: a court subpoena answer must be "this referral was governed by exactly this policy." Casey Drummond's lens is non-negotiable. The added complexity is bounded — one extra column, one extra table, no per-row policy snapshot duplication.

- **Append-only `escalation_policy` table grows unbounded.** Realistic growth: ~12 versions per tenant per year (one per month if the admin tunes monthly). At 100 tenants × 12 versions × 10 years = 12,000 rows. Trivial. No cleanup needed. Documented for future reference if cleanup ever becomes necessary.

- **Queue view does not paginate in MVP.** The issue body says ~10-20 items at peak. At 100 items the table becomes unwieldy. If pilot data shows queue lengths >50, paginate in a follow-up. Don't pre-pay for complexity.

- **Mid-day policy change has mixed semantics.** Old referrals follow old policy (frozen-at-creation), new referrals follow new policy. This is deliberate. But it means the admin must understand that "I just changed the threshold to 4 hours and there are still referrals firing CRITICAL at 2 hours" is correct behavior. The policy editor UI must explicitly say "This change applies to NEW referrals only — existing referrals follow the policy in effect when they were created."

- **Claim duration of 10 minutes is a guess.** Too short = constant re-claiming friction. Too long = if an admin closes their laptop, the referral is stuck for 10 minutes. The CDS literature gives no authoritative number. 10 min is a starting value; instrument the auto-release rate and tune.

- **Banner CTA navigation requires `/admin#dvEscalations` anchor handling.** If the user is not currently on the admin panel, the click navigates and pre-opens the tab. If they are on the admin panel but on a different tab, the click switches tabs. React Router needs to handle the anchor change.

- **The escalation policy cache must be programmatically invalidated on PATCH.** A 5-min TTL is insurance, but the PATCH handler must call `cache.invalidate(...)` to make policy changes visible immediately. Tested in `EscalationPolicyServiceTest`.

- **Forward compatibility with `sse-backpressure-phase2` (#97).** New SSE event types added in this change use the existing direct-send path. When Phase 2 lands, all send sites refactor to `NotificationEmitter.enqueue()`. The new event types added here will refactor identically, but the Phase 2 PR must touch these call sites too. Documented in proposal.md "Out of Scope" so the Phase 2 implementer is aware.

- **The 5-minute undo ribbon is UI state, not server state.** If the admin closes the tab during the undo window, the action is committed and not undoable. This is a deliberate trade-off — server-side undo would require a "pending action" table that adds significant complexity. NN/g's undo guidance is OK with this for short windows.

- **Spanish translation of person-centered language.** Keisha Thompson's lens applies in en AND es. The translator must understand the warmth-vs-urgency balance, not literally translate "Take action" → "Tomar acción." Reviewed by a native Spanish speaker familiar with social services language before merge.

## Open Questions Resolved Before Design

The six questions resolved with the project lead on 2026-04-10 are baked into the decisions above:

1. **Architecture diagram update format?** Mermaid replacement (Q1=c). New `docs/architecture.md`, drawio preserved alongside as legacy. → D10.
2. **Tracking issue?** Reuse #82 (Q2=reuse). The implementation comment will be added to #82 after this spec is committed. → no code impact, workflow only.
3. **Version bundling?** Ship as v0.33.0 BEFORE `sse-backpressure-phase2` (Q3=before). #82 is the higher-priority current bug; sse-backpressure-phase2 ships separately as v0.34.0. → no code impact, release planning only.
4. **Audit trail to `audit_events` table?** Yes (Q4=yes). Five new event types covering claim, release, reassign, admin accept, admin reject, plus policy update. → D8.
5. **Policy update semantics?** Frozen-at-creation (Q5=c). Each referral records the policy version active at creation time; mid-day policy changes apply only to new referrals. → D7.
6. **Sequencing vs `sse-backpressure-phase2`?** Independent ship, no hard dependency (Q6=independent). New SSE events use existing send path and refactor cleanly when Phase 2 lands. → D9 + Out of Scope.
