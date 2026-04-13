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

**Schema (Flyway V46, renumbered from V40 post-v0.34.0):**

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

**Default policy seeded by Flyway** at V46 with `tenant_id = NULL` and the current hardcoded values `[1h, 2h, 3.5h, 4h]`. Existing tenants do NOT get individual rows on migration — they fall back to the platform default until they explicitly customize via PATCH (which inserts their first version=1 row).

**Frozen-at-creation pattern (Flyway V47, renumbered from V41):**

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

### D11: Cross-tenant guard at the service layer (war room round 3, Marcus Webb)

`referral_token` RLS only checks `app.dv_access='true'` — it does NOT isolate by `tenant_id`. The escalation batch job needs platform-wide visibility, so DB-level tenant isolation would break it. The consequence: every endpoint that mutates a referral by id MUST explicitly assert at the service layer that the referral belongs to the caller's tenant.

**Pattern (applied to T-13 escalated queue, T-17 reassign, and any future mutating endpoint):**

```java
ReferralToken token = repository.findById(tokenId)
        .orElseThrow(() -> new NoSuchElementException(...));
UUID callerTenant = TenantContext.getTenantId();
if (callerTenant == null || !callerTenant.equals(token.getTenantId())) {
    throw new AccessDeniedException("Referral does not belong to your tenant");
}
```

For read-only queries (T-13 `getEscalatedQueue`), the tenant filter is in the SQL itself: `WHERE tenant_id = ?`. This double-purpose: closes the cross-tenant leak AND lets the planner use the V47 partial index `idx_referral_token_pending_by_expiry (tenant_id, expires_at) WHERE status = 'PENDING'`.

**Why this is a recurring concern, not a one-off:** every new endpoint that takes a `referralId` URL parameter is at risk. T-13 caught it first; T-17 reassign would have shipped without the check until war-room round 3 surfaced the pattern. Documented here as a design invariant to enforce in code review for any future mutating endpoint.

### D12: Atomic conditional UPDATE for claim/release/auto-release (war room round 1+3)

The naive Java-level pattern (`findById` → check claim state → `updateClaim`) has a TOCTOU window: two admins can both pass the check, both write, and the last writer wins silently. The Session 3 round-1 review caught this; the fix is a single conditional UPDATE per operation, with `RETURNING *` so the caller gets the winning row in the same DB round-trip.

**`tryClaim` (atomic):**
```sql
UPDATE referral_token
   SET claimed_by_admin_id = ?, claim_expires_at = ?
 WHERE id = ?
   AND status = 'PENDING'
   AND (claimed_by_admin_id IS NULL
        OR claimed_by_admin_id = ?
        OR claim_expires_at < NOW()
        OR ?::boolean = true)  -- override
RETURNING *;
```

Returns 0 rows when the row is missing, no longer PENDING, or someone else holds an unexpired claim and override is false. The service layer translates "0 rows" to a `ClaimConflictException` mapped to `409 Conflict`.

**`tryRelease`** uses the same shape with `WHERE claimed_by_admin_id = ? OR ?::boolean = true`. Idempotent on no-op.

**`clearExpiredClaims`** (auto-release scheduler) uses `WHERE claimed_by_admin_id IS NOT NULL AND claim_expires_at < NOW() RETURNING id, tenant_id` so the V47 partial index `idx_referral_token_active_claim` is actually used (Sam Okafor catch — without the `IS NOT NULL` predicate the planner falls back to a full table scan).

**Load-bearing test:** `ClaimReleaseTest.concurrentClaimsExactlyOneWinner` races two HTTP claims through a `CountDownLatch`, asserting exactly one OK + one 409 + the row holds the winner. If `tryClaim` regresses to a non-atomic pattern, this test fails.

### D13: V48 — `audit_events.actor_user_id` nullable for system actors (war room round 3; renumbered from V42 post-v0.34.0)

The original V29 `audit_events` schema declared `actor_user_id NOT NULL` because every audit row was triggered by a human admin. The auto-release scheduler in `ReferralTokenService.autoReleaseClaims()` writes `DV_REFERRAL_RELEASED` rows with `actor_user_id = null` (system actor). The NOT NULL constraint caused these rows to fail at INSERT time and be silently swallowed by `AuditEventService.onAuditEvent`'s try/catch.

**Discovery path:** `ClaimReleaseTest.autoReleaseClearsExpiredClaims` ran green (the DB state was correct), but the test log showed `Failed to persist audit event: ... null value in column "actor_user_id" of relation "audit_events" violates not-null constraint`. The functional behavior was right but the audit trail was broken — Casey Drummond's chain-of-custody requires every claim transition to leave a row.

**Fix (Flyway V48; no-op on deployments that already ran v0.34.0's V44 which did the same thing — V48 preserved for lineage per Elena Vasquez, see V48 file header):**
```sql
ALTER TABLE audit_events
    ALTER COLUMN actor_user_id DROP NOT NULL;
```

Reads MUST treat `actor_user_id IS NULL` as "system" (e.g. display "System (auto-release)" in admin audit log UI). The application layer is responsible for that mapping; the schema just allows the value. The `AuditEventCoverageTest.timeoutReleaseWritesAuditRowWithNullActor` test pins the contract.

### D14: V49 — `escalation_chain_broken` column + chain-resume on group reassign (war room round 4, Marcus Okafor; renumbered from V43 post-v0.34.0)

**The semantic question:** when a CoC admin reassigns a referral via `SPECIFIC_USER`, the system should stop auto-escalating it because the named user owns it now. But what if that user goes on PTO and the admin needs to "give the referral back to the group"?

**Solution:** a new boolean column `referral_token.escalation_chain_broken` (Flyway V49, default FALSE) tracked alongside the existing `escalation_policy_id` snapshot. Three reassign target types interact with it differently:

| Target type | Effect on `escalation_chain_broken` | Rationale |
|---|---|---|
| `SPECIFIC_USER` | Set to TRUE via `markEscalationChainBroken(id)` | Named user owns it; no auto-escalation |
| `COORDINATOR_GROUP` | Cleared to FALSE via `markEscalationChainResumed(id)` IF previously TRUE | Admin "gives back" to the group; per-user accountability is gone |
| `COC_ADMIN_GROUP` | Cleared to FALSE via `markEscalationChainResumed(id)` IF previously TRUE | Same as COORDINATOR_GROUP — broadcast = no single owner |

The escalation batch tasklet checks `token.isEscalationChainBroken()` at the top of `checkAndEscalate(...)` and `return 0;` early if set. This is the load-bearing invariant tested by `ReassignTest.chainBrokenReferralIsSkippedByTasklet`.

**Why a new column instead of repurposing `escalation_policy_id IS NULL`:** setting `escalation_policy_id = NULL` falls back to the platform default which still escalates. We need an EXPLICIT "escalation paused by admin" signal that the tasklet can branch on.

**Why this matters operationally (Marcus Okafor):** without chain-resume, the chain-broken state is sticky and silent — an admin who reassigns to Maria, then later realizes Maria is on PTO, has no way to re-enable auto-escalation. They'd reassign to a group expecting "the system takes over again," and instead the referral would silently stop escalating until human intervention. Round 4 fix.

### D15: URL prefix `/api/v1/admin/...` is a deliberate exception to project convention

The project's other controllers use module-prefixed paths: `/api/v1/dv-referrals`, `/api/v1/notifications`, `/api/v1/shelters`, `/api/v1/users`. There is no existing `/api/v1/admin/...` controller. The escalation policy controller is the first.

**Why the exception is allowed:**

1. The auth gate (`@PreAuthorize("hasAnyRole('COC_ADMIN', 'PLATFORM_ADMIN')")`) is what makes the endpoint admin-only — the URL prefix is a hint, not the enforcement.
2. The frontend grouping (admin tab) makes the `admin` segment a useful semantic signal for the OpenAPI spec and for any future admin-facing tooling.
3. Adding a single exception is cheaper than retroactively adding `/api/v1/admin/...` prefixes to every existing admin-only endpoint, which would break frontend URL configuration in two dozen places.

**Documented in the controller javadoc** so a future reviewer doesn't "fix" the inconsistency. The Java location of the controller (`org.fabt.notification.api.EscalationPolicyController`) follows the modular monolith — the URL path is just a string.

### D16: UserService boundary primitives (war room rounds 3+4, Alex Chen)

The referral module is forbidden from importing `org.fabt.auth.domain.User` (ArchUnit rule `referral_should_not_access_other_domain_entities`). Session 3 review caught Gemini's code touching `User.getId()`, `User.getRoles()`, and `User.getDisplayName()` directly. The fix: add primitive accessor methods on `UserService` that return `boolean`, `List<UUID>`, `List<String>`, or `Map<UUID, String>` instead of `User` objects.

| Accessor | Returns | Used by |
|---|---|---|
| `existsByIdInCurrentTenant(UUID)` | `boolean` | `reassignToken` SPECIFIC_USER target check |
| `getRolesByUserId(UUID)` | `List<String>` | `reassignToken` audit `actorRoles` enrichment |
| `findActiveUserIdsByRole(UUID, String)` | `List<UUID>` | Batch tasklet recipient resolution + COC_ADMIN_GROUP fan-out |
| `findDvCoordinatorIds(UUID)` | `List<UUID>` | Batch tasklet DV-only coordinator filter |
| `findDisplayNamesByIds(Collection<UUID>)` | `Map<UUID, String>` | Controller queue rendering for admin display names |
| `isAdminActor(UUID)` | `boolean` | Role-aware audit type selection on accept/reject |

**Pattern to preserve in future work:** when the referral (or any non-auth) module needs to know something about a user, add a primitive accessor to `UserService` rather than exposing `Optional<User>` and reading fields from the returned object. The boundary smell of "I need just one primitive but the only API gives me the whole entity" is a reliable signal.

### D17: Audit details enrichment policy (Casey Drummond rounds 3, 4, 5)

Beyond the basic `{actor_user_id, target_user_id, action, details, ip_address}` shape that audit_events provides, the `details` JSON for escalation events is enriched to support court-bound subpoena queries without table joins.

**`DV_REFERRAL_REASSIGNED` details:**
- `targetType` — COORDINATOR_GROUP / COC_ADMIN_GROUP / SPECIFIC_USER
- `targetUserId` — when SPECIFIC_USER (omitted otherwise)
- `reason` — verbatim admin text (PII responsibility on admin via UI warning per D18)
- `recipientCount` — operational fan-out scale
- `shelterId` — single-table subpoena queries: "show me all reassigns for shelter X" without joining `audit_events.target_user_id → referral_token.shelter_id`
- `actorRoles` — frozen-at-action-time so a later role change doesn't rewrite history. The roles are read inside the same `@Transactional` as the audit publish.
- `chainResumed: true` — when a group reassign cleared a previously broken chain (D14). The audit row tells the story without requiring adjacent-row inference.

**`ESCALATION_POLICY_UPDATED` details:**
- `tenantId`, `eventType`, `version`
- `previousVersion` — when version > 1. Computed as `version - 1` because `EscalationPolicyRepository.insertNewVersion` uses an atomic `MAX(version)+1` subquery — no race. Subpoena answers "what changed?" without joining back to escalation_policy.

**`DV_REFERRAL_CLAIMED` / `_RELEASED` details:**
- `claimed_until` (CLAIMED), `reason: "manual"|"timeout"` (RELEASED), `override: true|false`

**The audit_events table is append-only, so once written you cannot enrich** — every detail field that might matter for chain of custody must be present at write time. This is why the war-room rounds focused on getting the enrichment right before mass-writing rows.

### D18: PII reduction — reason in audit only, not notification payload (Keisha Thompson round 3)

The admin's free-text reason for reassign is potentially PII-leaky despite the modal warning. The original Session 3 implementation included it in BOTH the audit row AND the broadcast notification payload — meaning every recipient's `notification.payload` JSONB column held a copy of the reason text.

**Round 3 decision:** the reason lives in the `audit_events.details` row only. The notification payload contains `referralId + targetType` only — neutral metadata that an admin can share verbally if context is needed. Even if an admin slips PII into the reason despite the modal warning, the audit trail is the only sink, not every recipient's notification table row.

**Frontend obligation (carry-forward to T-37 ReassignSubModal):** the reason text field MUST display a prominent PII warning identical to the Deny modal's warning. The backend cannot enforce content. The frontend modal is the only PII checkpoint.

**Test lock-in:** `ReassignTest.coordinatorGroupReassignPagesShelterCoordinators` uses a recognizable reason string and asserts it appears in the audit row's details but NOT in any recipient's notification payload.

### D19: R6 batch tasklet guardrail (war room round 4, Sam Okafor + Riley Cho)

The escalation tasklet holds the entire result of `findAllPending()` in heap plus per-tenant lookup caches. Without a guardrail, a runaway pending count would OOM the `@Scheduled` thread.

**Fix:** new `findAllPending(int limit)` repository method with `LIMIT 5000` and `ORDER BY expires_at ASC`. Sized for ~10 active tenants × 500 referrals each — well above realistic operational load. Tasklet logs WARN on cap hit.

**Why `expires_at ASC` not `created_at`:** if the cap is hit, the cap-truncated set should be the most-urgent half (about-to-expire), not the oldest-created half. A referral past the cap would miss its escalation threshold by at most one batch interval (5 minutes) — picked up on the next run. Sam Okafor + Riley Cho war-room round 4 call.

**The cap-hit case is paging-grade**, not a normal condition. A `TODO(riley)` comment on `PENDING_BATCH_LIMIT` documents the deferred cap-hit unit test (high fixture cost; revisit if production WARNs ever fire).

### D20: Frontend conformance to archived UI specs (Session 5 carry-forward)

The new `DvEscalationsTab` and its sub-components MUST conform to the existing frontend conventions established by these archived OpenSpec changes:

| Archived change | What to honor |
|---|---|
| `2026-03-26-wcag-accessibility-audit` | W3C APG tabs pattern (already in `AdminPanel.tsx`); 44×44px touch targets; color independence (text + icon, not color alone); modal focus trap, Escape close, focus returns to trigger; `lang` attribute via react-intl; axe-core CI gate must remain green |
| `2026-03-27-font-consistency-audit` | NEVER hardcode font sizes — use `text.xs/sm/base/md/lg/xl/2xl/3xl` from `theme/typography.ts`; no fixed `height`/`max-height` on text containers; no `-webkit-line-clamp` |
| `2026-03-29-color-system-dark-mode` | NEVER hardcode hex — use `color.*` tokens from `theme/colors.ts`; split tokens (`primary` for fills, `primaryText` for links/labels) diverge in dark mode; WCAG 4.5:1 contrast already verified for all token pairs in both modes; use `color.dv` family for DV escalation accents (purple — the project's safety color), NOT `color.error` red (red is for severity, not for "this is a DV referral") |
| `2026-03-29-sse-notifications` | Disclosure pattern, NOT `role="menu"`; `aria-live="polite"` for dynamic count updates; person-centered language ("A new referral needs your attention," not "New referral assigned") |
| `2026-03-31-sse-stability` | Use `@microsoft/fetch-event-source` (already wired in `useNotifications`), NOT native `EventSource`; never reintroduce query-param token auth |
| `2026-04-07-admin-panel-extraction` | Each tab is a `default export` from `src/pages/admin/tabs/`; lazy-loaded with `<Suspense fallback={<Spinner/>}>`; tab-specific types stay in tab files (NOT in `types.ts`); shared imports: `api`, `color`, `text/weight`, `react-intl`, `tableStyle/thStyle/tdStyle/inputStyle/primaryBtnStyle`, `StatusBadge/ErrorBox/Spinner/NoData` |
| `2026-04-09-persistent-notifications` | Three severity tiers (CRITICAL/ACTION_REQUIRED/INFO); zero-PII payloads (frontend resolves names from REST); CRITICAL banner stays until acted on |
| `feedback_data_testid` (memory) | Every interactive element gets `data-testid` for Playwright stability |
| `feedback_build_before_commit` (memory) | `npm run build` (tsc + vite) MUST pass before any frontend commit |

**Implementation consequence for `useDvEscalationQueue` hook (T-39):** EXTEND `useNotifications` rather than open a parallel SSE stream. Add 4 new `case` branches to the existing `onmessage` switch (`referral.claimed`, `referral.released`, `referral.queue-changed`, `referral.policy-updated`) that dispatch new `window` custom events. The new hook is a thin wrapper that listens for those custom events and exposes `{queue, loading, error, refresh}`. SSE connection budget matters — one connection per session, not two.

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
3. **Version bundling?** Ship as v0.33.0 BEFORE `sse-backpressure-phase2` (Q3=before). #82 is the higher-priority current bug; sse-backpressure-phase2 ships separately in a later release. → no code impact, release planning only. **Post-v0.34.0 update (2026-04-11):** the answer to this question was overtaken by events. GH issue #102 (phantom `beds_on_hold` drift, bed-hold-integrity) was discovered and prioritized ahead of both coc-admin-escalation and sse-backpressure-phase2. bed-hold-integrity shipped as v0.34.0; this change retargets to **v0.35.0** (see IMPLEMENTATION-PLAN.md's "v0.35.0 retargeting note" for the full chronology). sse-backpressure-phase2 remains queued for a future release, still after this change.
4. **Audit trail to `audit_events` table?** Yes (Q4=yes). Five new event types covering claim, release, reassign, admin accept, admin reject, plus policy update. → D8.
5. **Policy update semantics?** Frozen-at-creation (Q5=c). Each referral records the policy version active at creation time; mid-day policy changes apply only to new referrals. → D7.
6. **Sequencing vs `sse-backpressure-phase2`?** Independent ship, no hard dependency (Q6=independent). New SSE events use existing send path and refactor cleanly when Phase 2 lands. → D9 + Out of Scope.
