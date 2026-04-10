## Tasks

### Setup

- [x] T-0: Create branch `feature/coc-admin-escalation` in code repo (`finding-a-bed-tonight`) from main. **Session 1 (2026-04-10).**
- [x] T-1: Capture pre-change baseline. Tee to `logs/coc-escalation-baseline-pre.log`. Result: 38 tests green across `ReferralEscalationIntegrationTest` (3), `NotificationDiagnosticTest` (2), `NotificationPaginationTest` (6), `NotificationRlsIntegrationTest` (12), `SseNotificationIntegrationTest` (11), `SseStabilityTest` (4). **Session 1 (2026-04-10).** *(Playwright baseline deferred to a frontend session — backend-only chunk doesn't risk Playwright regressions yet.)*

### Backend — Schema (Flyway)

- [x] T-2: **V40 — `escalation_policy` table.** Created `backend/src/main/resources/db/migration/V40__create_escalation_policy.sql`. Append-only versioned per (tenant_id, event_type). UUID PK, tenant_id FK NULL (platform default), event_type VARCHAR(64), version INTEGER, thresholds JSONB, created_at, created_by FK with `ON DELETE SET NULL` (preserves audit-trail integrity if admin removed), `UNIQUE NULLS NOT DISTINCT (tenant_id, event_type, version)` to prevent duplicate platform-default rows. Index `idx_escalation_policy_current (tenant_id, event_type, version DESC)`. RLS enabled with `USING (true)` SELECT/INSERT, no UPDATE/DELETE policies (append-only enforced at DB layer). **Session 1 (2026-04-10)**, with Elena Vasquez round-table fixes F1 (NULLS NOT DISTINCT) and F2 (ON DELETE SET NULL). (D7)
- [x] T-3: **V40 seed — platform default policy.** Inserted as part of V40 migration. tenant_id=NULL, event_type='dv-referral', version=1, thresholds match the existing hardcoded values exactly: `[{PT1H, ACTION_REQUIRED, [COORDINATOR]}, {PT2H, CRITICAL, [COC_ADMIN]}, {PT3H30M, CRITICAL, [COORDINATOR, OUTREACH_WORKER]}, {PT4H, INFO, [OUTREACH_WORKER]}]`. **Session 1 (2026-04-10).** (D7)
- [x] T-4: **V41 — `referral_token.escalation_policy_id` column.** Added in `backend/src/main/resources/db/migration/V41__referral_token_admin_columns.sql`. Nullable UUID FK to escalation_policy(id). Existing rows NULL → batch job falls back to platform default policy. Backwards compatible by design. **Session 1 (2026-04-10).** (D7)
- [x] T-5: **V41 — `referral_token.claimed_by_admin_id` and `claim_expires_at` columns.** Added in V41. Both nullable. Two new partial indexes: `idx_referral_token_active_claim (claim_expires_at) WHERE claimed_by_admin_id IS NOT NULL` for the auto-release scheduler, and `idx_referral_token_pending_by_expiry (tenant_id, expires_at) WHERE status = 'PENDING'` for the admin queue endpoint (Session 3). **Session 1 (2026-04-10).** (D4) *(EXPLAIN ANALYZE verification at scale deferred to Session 3 per Sam Okafor's note about RLS+index interaction.)*
- [x] T-6: **V42 — Audit event types.** **SPEC DRIFT NOTE:** the spec assumed an `AuditEventType` enum existed. It does not — the codebase uses bare String literals (e.g. `"ROLE_CHANGED"`) passed to `AuditEventService`. To stay additive, created `backend/src/main/java/org/fabt/shared/audit/AuditEventTypes.java` as a `public final class` with 6 `public static final String` constants: `DV_REFERRAL_CLAIMED`, `DV_REFERRAL_RELEASED`, `DV_REFERRAL_REASSIGNED`, `DV_REFERRAL_ADMIN_ACCEPTED`, `DV_REFERRAL_ADMIN_REJECTED`, `ESCALATION_POLICY_UPDATED`. NO V42 SQL file (the spec said "no schema change"). NO refactor of existing String literals (deferred to a future cleanup change). The class javadoc documents the deviation. **Session 1 (2026-04-10).** (D8)

### Backend — Escalation Policy Service

- [ ] T-7: `EscalationPolicy` domain object (record) + `EscalationPolicyRepository` (Spring Data JDBC). Read methods: `findCurrentByTenantAndEventType(tenantId, eventType)`, `findById(id)`. Write methods: `insertNewVersion(...)`. No update or delete methods — append-only. (D7)
- [ ] T-8: `EscalationPolicyService` with two Caffeine caches:
  - `currentPolicyByTenant` — key=(tenantId, eventType), value=policy, max=200, TTL=5min — used by `ReferralTokenService.create()` to snapshot the policy on each new referral.
  - `policyById` — key=policyId, value=policy, max=500, TTL=10min — used by the batch job to look up the frozen policy for each referral.
  - Both caches invalidated programmatically on PATCH. (D7)
  - *Persona — Sam Okafor:* "5-min TTL is fine because policies change rarely. Don't query the DB on every batch run."
- [ ] T-9: Validation in `EscalationPolicyService.update(...)`: monotonically-increasing thresholds (`Duration.parse(t[i].at).compareTo(t[i+1].at) < 0`), valid roles in recipients (`COORDINATOR|COC_ADMIN|OUTREACH_WORKER|PLATFORM_ADMIN`), valid severities (`INFO|ACTION_REQUIRED|CRITICAL`). Reject invalid policies with 400 + structured error. (D7)
  - *Persona — Riley Cho:* "Validation must happen at the service layer, not just the controller, so direct service calls (e.g. tests) can't bypass it."

### Backend — Refactor Escalation Job

- [ ] T-10: Refactor `ReferralEscalationJobConfig.run()` to read thresholds from the **frozen** policy attached to each pending referral (`escalation_policy_id` FK lookup via `EscalationPolicyService.findById(...)`). Fall back to platform default if `escalation_policy_id IS NULL` (existing rows). (D7)
- [ ] T-11: Refactor `ReferralTokenService.create(...)` to call `EscalationPolicyService.getCurrentForTenant(tenantId, "dv-referral")` and snapshot the resulting `policy.id` into the new referral's `escalation_policy_id` column. (D7)
- [ ] T-12: Refactor recipient resolution in the batch job to read the recipient roles from the policy, not hardcoded role names. Each threshold can target one or more roles; resolve to user list via `userService.findActiveByRoles(tenantId, roles)`. Preserve the existing dedup pattern (`existsByTypeAndReferralId`). (D7)

### Backend — Admin Endpoints

- [ ] T-13: `GET /api/v1/dv-referrals/escalated` — returns pending DV referrals across the tenant. Auth: `@PreAuthorize("hasAnyRole('COC_ADMIN', 'PLATFORM_ADMIN')")`. Response: list of `EscalatedReferralDto(id, shelterId, shelterName, populationType, householdSize, urgency, createdAt, expiresAt, remainingMinutes, assignedCoordinatorId, assignedCoordinatorName, claimedByAdminId, claimedByAdminName, claimExpiresAt)`. NO PII (no callback_number, no client_name). Sorted by `expires_at ASC` (most-urgent first). (D3)
  - *Persona — Marcus Webb:* "Verify the response shape includes zero PII before merge. The DTO is the contract."
- [ ] T-14: `POST /api/v1/dv-referrals/{id}/claim` — sets `claimed_by_admin_id = current_user_id`, `claim_expires_at = NOW() + claim-duration-minutes`. Auth: `COC_ADMIN+`. Returns 200 with the updated DTO. Returns 409 if already claimed by another admin AND `Override-Claim: true` header is not present. Writes audit event `DV_REFERRAL_CLAIMED`. Publishes SSE `referral.claimed`. (D4, D8, D9)
- [ ] T-15: `POST /api/v1/dv-referrals/{id}/release` — manual release. Clears `claimed_by_admin_id` + `claim_expires_at`. Only the claiming admin can release (or any other admin with `Override-Claim: true`). Writes audit `DV_REFERRAL_RELEASED` with `reason: "manual"`. Publishes SSE `referral.released`. (D4, D8, D9)
- [ ] T-16: `@Scheduled` auto-release task — every `fabt.dv-referral.claim-cleanup-interval-seconds` (default 60), find referral_tokens where `claim_expires_at < NOW() AND claimed_by_admin_id IS NOT NULL`, clear the claim, write audit `DV_REFERRAL_RELEASED` with `actor_user_id = system`, `reason: "timeout"`, publish SSE. Use existing `@Scheduled` infrastructure (no new ShedLock). (D4)
- [ ] T-17: `POST /api/v1/dv-referrals/{id}/reassign` — body `{target_type: COORDINATOR_GROUP|COC_ADMIN_GROUP|SPECIFIC_USER, target_id: UUID, reason: STRING}`. For COORDINATOR_GROUP: re-fires the T+1h reminder notification to the shelter's coordinators. For COC_ADMIN_GROUP: re-fires T+2h CRITICAL to all CoC admins. For SPECIFIC_USER: notifies only that user (and breaks the escalation chain — documented in OpenAPI). Auth: `COC_ADMIN+`. Writes audit `DV_REFERRAL_REASSIGNED`. Publishes SSE `referral.queue-changed`. (D5, D8, D9)
- [ ] T-18: `GET /api/v1/admin/escalation-policy/{eventType}` — returns the current policy for the caller's tenant. Falls back to platform default if no tenant-specific policy exists. Response: `EscalationPolicyDto(id, eventType, version, thresholds, createdAt, createdBy)`. Auth: `COC_ADMIN+`. (D7)
- [ ] T-19: `PATCH /api/v1/admin/escalation-policy/{eventType}` — body is the new thresholds JSON. Calls `EscalationPolicyService.update(...)` which validates, inserts a new versioned row, and invalidates the cache. Returns 200 with the new policy DTO + 400 if validation fails. Auth: `COC_ADMIN+`. Writes audit `ESCALATION_POLICY_UPDATED`. Publishes SSE `referral.policy-updated`. (D7, D8, D9)

### Backend — Audit Events

- [ ] T-20: `AuditEventService.recordDvReferralAdminAction(...)` — wraps the existing `audit_events` insert path. Builds the structured detail blob per event type. Zero PII enforcement: only IDs, roles, and structured metadata. (D8)
- [ ] T-21: Wire all 6 new audit event types into the action endpoints (T-14, T-15, T-16, T-17, T-19) and into the existing `PATCH /accept` and `/reject` endpoints (when called by `COC_ADMIN+` actor — different audit type than coordinator actions). (D8)
  - *Persona — Casey Drummond:* "The actor's role distinguishes admin actions from coordinator actions in the audit trail. This is the chain-of-custody answer to a court subpoena."

### Backend — Tests

- [ ] T-22: `EscalationPolicyServiceTest` — unit tests for: monotonic threshold validation, role validation, severity validation, append-only versioning (each PATCH increments version), cache invalidation on PATCH, fallback to platform default when tenant has no policy.
- [ ] T-23: `ReferralEscalationFrozenPolicyTest` — integration test: create policy v1, create referral A, change policy to v2, create referral B, run batch job, verify referral A fires per v1 thresholds and referral B fires per v2 thresholds. **This is the load-bearing test for D7.**
  - *Persona — Casey Drummond + Riley Cho:* "If this test ever fails, the audit trail is compromised. Treat as critical."
- [ ] T-24: `EscalatedQueueEndpointTest` — integration test: create referrals across multiple shelters in tenant A and tenant B, assert that a tenant A admin sees only tenant A referrals, ordered by expires_at ASC, with zero PII fields in the response.
- [ ] T-25: `ClaimReleaseTest` — integration test: admin A claims a referral, admin B's queue shows it as claimed, admin B cannot claim without override header, auto-release after 10 min returns it to the queue. Verify SSE events fire with correct payloads.
- [ ] T-26: `ReassignTest` — integration test for all three target types (group, admin group, specific user). Verify audit_events row has the correct target_type and target_id. Verify SPECIFIC_USER reassign breaks the escalation chain (no further automatic escalation).
- [ ] T-27: `AdminAcceptRejectTest` — integration test: COC_ADMIN calls PATCH /accept on a pending referral, verify audit type is `DV_REFERRAL_ADMIN_ACCEPTED` (not `_ACCEPTED`), verify the referral is closed correctly. Same for /reject.
- [ ] T-28: `EscalationPolicyEndpointTest` — integration test for GET (fallback to platform default), PATCH (success path), PATCH with monotonic violation (400), PATCH with invalid role (400), authorization (COORDINATOR rejected with 403).
- [ ] T-29: `AuditEventCoverageTest` — for each of the 6 new audit event types, trigger the corresponding action and verify exactly one row is written to `audit_events` with the expected actor_user_id, target_id, and detail JSON shape.
- [ ] T-30: Re-run the baseline from T-1. Existing `ReferralEscalationIntegrationTest`, `NotificationServiceTest`, and `persistent-notifications.spec.ts` must all pass without modification (the new features are additive, not breaking).

### Frontend — Types & Routing

- [ ] T-31: Add `'dvEscalations'` to the `TabKey` union in `frontend/src/pages/admin/types.ts`. Add `EscalatedReferral`, `EscalationPolicy`, `EscalationPolicyThreshold` types matching the backend DTOs.
- [ ] T-32: Register the new tab in `frontend/src/pages/admin/AdminPanel.tsx` TABS array: `{key: 'dvEscalations', labelId: 'admin.dvEscalations'}`. Wire the route to load `DvEscalationsTab.tsx` (lazy-loaded per the v0.29.6 admin panel pattern).

### Frontend — DvEscalationsTab

- [ ] T-33: `DvEscalationsTab.tsx` — top-level component with two segmented sections: "Pending Queue" and "Escalation Policy". Default segment: Queue. Mobile (<768px) hides the segment switch and shows Queue only — Policy editor is desktop-only. (D2, D3)
- [ ] T-34: `EscalatedQueueTable.tsx` — desktop table component. Columns: Shelter, Time-to-expiry (live countdown), Population, Household, Urgency, Coordinator, Claim status. Default sort: ascending by time-to-expiry. Inline Claim button per row. Row click opens `EscalatedReferralDetailModal`. Row background subtle red when remainingMinutes < 15. Live SSE updates with row-highlight-then-fade via existing `useNotifications` hook + new `useDvEscalationQueue` hook. (D3)
- [ ] T-35: `EscalatedQueueCardList.tsx` — mobile card list component. One card per referral. Visible: Shelter, time-to-expiry, single primary CTA (Claim). "More" button opens detail modal. (D3)
- [ ] T-36: `EscalatedReferralDetailModal.tsx` — modal opened from row click or "More" button. Shows full referral context (zero PII). Four action buttons: Claim/Release, Reassign, Approve placement, Deny. Approve/Deny use the danger-variant confirmation pattern with specific verb text and 5-min undo ribbon. (D3, D6)
  - *Persona — Marcus Webb (added Session 1 round-table review):* the **Deny modal's reason text field SHALL display a prominent PII warning above it**, e.g. "Do not include client names, addresses, or other identifying information. This text is recorded in the audit trail." The audit event `DV_REFERRAL_ADMIN_REJECTED` stores the reason verbatim per `AuditEventTypes.java`; the admin is responsible for keeping it PII-free, but the UI must remind them. Tracked here so it doesn't get forgotten in Session 5.
- [ ] T-37: `ReassignSubModal.tsx` — three-tab sub-modal for reassign. Default tab: "To another coordinator" (searchable list). Second tab: "To CoC admin group". Third tab gated behind "Advanced" disclosure: "To specific user" with the warning that this breaks the escalation chain. (D5)
- [ ] T-38: `EscalationPolicyEditor.tsx` — desktop-only policy editor. Form fields per threshold: ISO duration input (e.g. "1h", "2h"), severity dropdown, recipients multi-select. Inline validation (monotonic ordering, valid roles, valid severities). Save button calls `PATCH /api/v1/admin/escalation-policy/dv-referral`. Mobile: shows a read-only message "Edit on a larger screen — this view is read-only on mobile." (D7)
- [ ] T-39: `useDvEscalationQueue.ts` — React hook subscribing to the four new SSE event types (`referral.claimed`, `referral.released`, `referral.queue-changed`, `referral.policy-updated`). Reconciles local queue state with row-highlight-then-fade. (D9)

### Frontend — Banner CTA

- [ ] T-40: Update `CriticalNotificationBanner.tsx` to add a primary CTA button: *"Review N pending escalations →"* (where N is the count of unread CRITICAL `escalation.*` notifications). Click navigates to `/admin#dvEscalations`. Banner is hidden when N = 0. i18n key: `notifications.criticalBanner.cta`. (D1)
  - *Persona — Keisha Thompson:* "Copy review before merge. The button text must center the work, not the urgency."
- [ ] T-41: Update React Router (or admin panel anchor handling) to interpret `#dvEscalations` and pre-select the new tab.

### Frontend — i18n

- [ ] T-42: Add ~25 new i18n keys to `frontend/src/i18n/locales/en.json` and `es.json`. Categories: tab label, queue column headers, action button labels (Claim, Release, Reassign, Approve, Deny), modal headers, validation messages, policy editor field labels, mobile read-only message. **Keisha Thompson reviews all keys before merge.** **Casey Drummond runs the legal language scan.**

### Frontend — Tests

- [ ] T-43: Playwright `coc-escalation-banner.spec.ts` — fixture creates a pending DV referral, fast-forwards the escalation timer (or waits for the batch job), verifies the CRITICAL banner appears with the CTA button, clicks the CTA, asserts navigation to `/admin#dvEscalations` and the queue table shows the referral.
- [ ] T-44: Playwright `coc-escalation-claim.spec.ts` — admin A claims a referral, admin B (in second browser context) sees the row update via SSE within 2s, admin B cannot claim without confirming the override, audit_events has both DV_REFERRAL_CLAIMED rows.
- [ ] T-45: Playwright `coc-escalation-reassign.spec.ts` — admin reassigns to coordinator group via the default tab, asserts the SSE `referral.queue-changed` event fires, the row status updates, audit event recorded.
- [ ] T-46: Playwright `coc-escalation-policy.spec.ts` — admin opens the policy editor, changes T+2h to T+3h, saves, verifies the SSE `referral.policy-updated` event fires, verifies a NEW referral fires CRITICAL at T+3h (not T+2h), verifies an EXISTING referral still fires per the OLD policy (frozen-at-creation).
- [ ] T-47: Playwright `coc-escalation-mobile.spec.ts` — mobile viewport (375x667), verifies the queue shows as a card list, the policy editor section shows the read-only message, claim works from a card.

### Documentation

- [ ] T-48: Create `docs/architecture.md` — Mermaid system overview replacing `docs/architecture.drawio` (which is preserved as a v0.21–v0.28 historical reference). Sections: System Overview (Cloudflare → nginx → Spring Boot → PostgreSQL), Module Map (modular monolith boundaries), DV Escalation Data Flow (referral_token → escalation_policy frozen FK → batch job → notification → SSE → admin queue). All diagrams in Mermaid for natural GitHub rendering. (D10)
  - *Persona — Alex Chen:* "Predates v0.31.0. The Mermaid replacement must accurately reflect the current modular monolith including persistent notifications, RLS simplification, and the new escalation policy module."
- [ ] T-49: Create `docs/business-processes/dv-referral-end-to-end.md` — **companion parent doc** establishing the full DV referral flow that the escalation doc branches from. Sections: actor inventory (outreach worker, coordinator, CoC admin, survivor) with persona links, Mermaid sequenceDiagram of the happy path from search → request → screen → accept → warm handoff → closure, role × phase matrix, Mermaid stateDiagram-v2 of the `referral_token` state machine (PENDING/ACCEPTED/REJECTED/EXPIRED — the base machine that escalation extends with CLAIMED), persona traceability. This is the parent reference that `dv-referral-escalation.md` (T-50) builds on. (D10)
- [ ] T-50: Create `docs/business-processes/dv-referral-escalation.md` — escalation branch of the parent flow (T-49). Sections: when escalation fires (the role × time matrix), Mermaid sequenceDiagram of the escalation timeline (T+1h reminder → T+2h CRITICAL → T+3.5h all-hands → T+4h expired) including the new admin claim/release/reassign/act actions, edge case section (coordinator offline, two admins claim simultaneously, survivor cancels mid-flow, expiry race conditions, mid-day policy change with frozen-at-creation answer), persona traceability. Cross-references the parent doc instead of inlining context. **Both T-49 and T-50 reviewed together by Devon Kessler (training), Marcus Okafor (CoC admin), and Keisha Thompson (dignity) before merge as a single ~60-minute joint walkthrough — schedule one session covering both files, do not request reviews independently.** (D10)
- [ ] T-51: Update `docs/FOR-DEVELOPERS.md` — new section "Escalation Policy and Frozen-at-Creation" documenting the data model, the policy versioning rule, the new endpoints, and the pattern for adding future event types beyond `dv-referral`.

### Performance / Operational

- [ ] T-52: Verify the escalation batch job p95 duration is unchanged after the policy lookup refactor. Add the policy lookup to the job's existing Micrometer timer. If p95 grows >10%, investigate (likely cache miss rate too high).
- [ ] T-53: New Micrometer metrics: `fabt.escalation.policy.cache.hit-rate`, `fabt.dv-referral.claim.duration` (histogram), `fabt.dv-referral.claim.auto-release.count` (counter). Add Grafana panels.

### Pre-Merge

- [ ] T-54: Run full backend test suite (`mvn clean test`). All tests green, no regressions, ArchUnit boundaries intact (escalation_policy stays in `notification` module). Tee to `logs/backend-full-coc-escalation.log`.
- [ ] T-55: Run full Playwright suite through nginx. All tests green. Tee to `logs/playwright-coc-escalation.log`.
- [ ] T-56: Open PR against main, link to issue #82 and this OpenSpec change. Hold for scans (memory: `feedback_release_after_scans`).
- [ ] T-57: After merge: bump `pom.xml` version to **v0.33.0**, promote CHANGELOG `[Unreleased]` → `[v0.33.0]` (which also bundles the v0.32.2 fix per the deploy plan), tag, GitHub release. Comment on issue #82 with the release link. Close #82.
- [ ] T-58: After release: `/opsx:verify coc-admin-escalation` → `/opsx:sync coc-admin-escalation` → `/opsx:archive coc-admin-escalation`.
