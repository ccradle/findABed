## ADDED Requirements

### Requirement: Admin queue view of pending DV referrals

The system SHALL provide CoC administrators with a tenant-wide view of pending DV referrals across all shelters, ordered by ascending time-to-expiry. The view SHALL contain zero personally identifying information about clients.

#### Scenario: COC_ADMIN sees all pending referrals in tenant
- **WHEN** a COC_ADMIN sends `GET /api/v1/dv-referrals/escalated`
- **THEN** the response SHALL include all referrals in `PENDING` status across all shelters in the caller's tenant
- **AND** the response SHALL be ordered by `expires_at` ascending (most urgent first)
- **AND** each item SHALL include `id, shelterId, shelterName, populationType, householdSize, urgency, createdAt, expiresAt, remainingMinutes, assignedCoordinatorId, assignedCoordinatorName, claimedByAdminId, claimedByAdminName, claimExpiresAt`
- **AND** the response SHALL NOT include `callbackNumber`, `clientName`, or any free-text field that could identify a survivor

#### Scenario: COORDINATOR cannot access the escalated queue
- **WHEN** a COORDINATOR sends `GET /api/v1/dv-referrals/escalated`
- **THEN** the system SHALL return `403 Forbidden`

#### Scenario: Cross-tenant access returns empty list
- **WHEN** a COC_ADMIN from tenant A queries the escalated queue
- **AND** tenant B has 5 pending referrals
- **THEN** the response SHALL contain only tenant A's referrals
- **AND** tenant B's referrals SHALL NOT be visible

#### Scenario: Empty queue returns empty list
- **WHEN** there are no pending DV referrals in the tenant
- **THEN** the response SHALL be `200` with an empty array
- **AND** the CRITICAL banner SHALL be hidden in the frontend

### Requirement: Claim a referral (PagerDuty acknowledge soft-lock)

The system SHALL allow a CoC administrator to claim a pending DV referral as a soft-lock visible to other administrators. The claim SHALL auto-release after a configured timeout.

#### Scenario: Admin claims an unclaimed referral
- **WHEN** a COC_ADMIN sends `POST /api/v1/dv-referrals/{id}/claim` on a referral with `claimed_by_admin_id IS NULL`
- **THEN** the system SHALL set `claimed_by_admin_id` to the current user's ID
- **AND** SHALL set `claim_expires_at` to `NOW() + fabt.dv-referral.claim-duration-minutes` (default 10 minutes)
- **AND** SHALL return `200` with the updated referral DTO
- **AND** SHALL write an audit event of type `DV_REFERRAL_CLAIMED`
- **AND** SHALL publish an SSE event `referral.claimed` to all CoC admins in the tenant

#### Scenario: Second admin sees claim status in real time
- **WHEN** admin A claims a referral
- **AND** admin B has the escalated queue view open
- **THEN** admin B SHALL see the row update with "Claimed by [admin A name]" within 2 seconds via SSE

#### Scenario: Second admin cannot claim without override
- **WHEN** a referral is already claimed by admin A
- **AND** admin B sends `POST /api/v1/dv-referrals/{id}/claim` without the `Override-Claim: true` header
- **THEN** the system SHALL return `409 Conflict` with body `{"error": "already_claimed", "claimed_by": "<user id>"}`

#### Scenario: Override claim succeeds with header
- **WHEN** admin B sends `POST /api/v1/dv-referrals/{id}/claim` with `Override-Claim: true`
- **THEN** the system SHALL replace `claimed_by_admin_id` with admin B's ID
- **AND** SHALL write a new audit event `DV_REFERRAL_CLAIMED` (the previous claim's audit event is preserved)

#### Scenario: Concurrent claims — exactly one wins atomically
- **WHEN** admin A and admin B send `POST /api/v1/dv-referrals/{id}/claim` simultaneously on an unclaimed referral, neither with the override header
- **THEN** exactly one request SHALL receive `200 OK`
- **AND** the other SHALL receive `409 Conflict`
- **AND** the row SHALL hold the winning admin's id (not silently overwritten)
- **AND** the underlying SQL SHALL be a single atomic conditional `UPDATE ... RETURNING *` (no Java-level read-then-write window)

#### Scenario: Auto-release after timeout
- **WHEN** a claim's `claim_expires_at < NOW()`
- **AND** the auto-release scheduled task runs
- **THEN** the system SHALL clear `claimed_by_admin_id` and `claim_expires_at`
- **AND** SHALL write an audit event `DV_REFERRAL_RELEASED` with `actor_user_id = system` and `reason: "timeout"`
- **AND** SHALL publish an SSE event `referral.released`

### Requirement: Manual release of a claim

The system SHALL allow the admin who currently holds a claim to release it manually. Other admins SHALL NOT be able to release a claim they do not hold without an explicit override header. Manual releases SHALL be recorded in the audit trail and broadcast via SSE.

#### Scenario: Claiming admin releases their own claim
- **WHEN** admin A sends `POST /api/v1/dv-referrals/{id}/release` on a referral they currently claim
- **THEN** the system SHALL clear the claim
- **AND** SHALL write audit `DV_REFERRAL_RELEASED` with `reason: "manual"`
- **AND** SHALL publish SSE `referral.released`

#### Scenario: Non-claiming admin cannot release without override
- **WHEN** admin B (who did not claim the referral) sends `POST /release` without `Override-Claim: true`
- **THEN** the system SHALL return `403 Forbidden`

### Requirement: Reassign a referral to a different responder

The system SHALL allow a CoC administrator to reassign a pending DV referral to a coordinator group, the CoC admin group, or a specific user. Reassigning to a specific user SHALL break the escalation chain and the API SHALL document this behavior.

#### Scenario: Reassign to coordinator group (default tab)
- **WHEN** an admin sends `POST /api/v1/dv-referrals/{id}/reassign` with `{target_type: "COORDINATOR_GROUP", target_id: <shelter_id>, reason: "..."}`
- **THEN** the system SHALL re-fire the T+1h reminder notification to all coordinators assigned to that shelter
- **AND** SHALL write an audit event `DV_REFERRAL_REASSIGNED`
- **AND** SHALL publish SSE `referral.queue-changed`

#### Scenario: Reassign to CoC admin group
- **WHEN** the request body has `target_type: "COC_ADMIN_GROUP"`
- **THEN** the system SHALL re-fire the T+2h CRITICAL notification to all CoC admins in the tenant

#### Scenario: Reassign to specific user breaks the escalation chain
- **WHEN** the request body has `target_type: "SPECIFIC_USER", target_id: <user_id>`
- **THEN** the system SHALL notify only that user
- **AND** future automatic escalations of this referral SHALL be suppressed
- **AND** the OpenAPI documentation SHALL warn that this option breaks the escalation chain

#### Scenario: Reassign requires reason
- **WHEN** the request body omits `reason` or sends an empty string
- **THEN** the system SHALL return `400 Bad Request`

#### Scenario: Cross-tenant referral access denied
- **WHEN** a CoC admin in tenant A sends `POST /api/v1/dv-referrals/{id}/reassign` (or `/claim`, `/release`) for a referral that belongs to tenant B
- **THEN** the system SHALL return `403 Forbidden`
- **AND** SHALL NOT mutate the referral
- **AND** SHALL NOT publish any SSE event
- **AND** the service-layer guard SHALL be the enforcement point because `referral_token` RLS only checks `dvAccess`, not `tenant_id`

#### Scenario: SPECIFIC_USER targeting a different-tenant user is rejected
- **WHEN** an admin in tenant A sends a SPECIFIC_USER reassign with `targetUserId` belonging to tenant B
- **THEN** the system SHALL return `404 Not Found` (target user not in caller's tenant)
- **AND** SHALL NOT set `escalation_chain_broken = true` on the referral
- **AND** SHALL NOT write any audit event

#### Scenario: SPECIFIC_USER reassign sets escalation_chain_broken
- **WHEN** an admin reassigns to SPECIFIC_USER successfully
- **THEN** the system SHALL set `referral_token.escalation_chain_broken = TRUE`
- **AND** the escalation batch tasklet SHALL skip this referral on subsequent runs (return early before threshold checks)

#### Scenario: COORDINATOR_GROUP reassign clears chain-broken state
- **WHEN** a referral has `escalation_chain_broken = TRUE` from a prior SPECIFIC_USER reassign
- **AND** an admin reassigns it via COORDINATOR_GROUP
- **THEN** the system SHALL clear `escalation_chain_broken` to FALSE
- **AND** the audit row's `details` SHALL contain `chainResumed: true`
- **AND** the escalation batch tasklet SHALL resume escalating this referral on subsequent runs

#### Scenario: COC_ADMIN_GROUP reassign also clears chain-broken state
- **WHEN** a chain-broken referral is reassigned via COC_ADMIN_GROUP
- **THEN** the same chain-resume behavior SHALL apply (flag cleared, `chainResumed: true` audit, escalation resumes)

#### Scenario: Reason field is in audit row only — never in notification payload
- **WHEN** an admin reassigns with a free-text reason
- **THEN** the audit row's `details.reason` SHALL contain the verbatim reason text
- **AND** the broadcast `referral.reassigned` notification's payload SHALL contain ONLY `referralId` and `targetType`
- **AND** the reason text SHALL NOT appear in any recipient's `notification.payload` JSONB
- **AND** the frontend Reassign modal SHALL display a prominent PII warning above the reason field (the backend cannot enforce content)

### Requirement: Admin can act directly on a pending DV referral

The system SHALL allow a CoC administrator to accept or reject a pending DV referral directly via the existing referral endpoints, with the audit trail distinguishing admin actions from coordinator actions.

#### Scenario: COC_ADMIN accepts a referral
- **WHEN** a COC_ADMIN sends `PATCH /api/v1/dv-referrals/{id}/accept`
- **THEN** the referral status SHALL change to `ACCEPTED`
- **AND** the audit event type SHALL be `DV_REFERRAL_ADMIN_ACCEPTED` (not `DV_REFERRAL_ACCEPTED`)
- **AND** SHALL publish SSE `referral.queue-changed`

#### Scenario: COC_ADMIN rejects a referral with reason
- **WHEN** a COC_ADMIN sends `PATCH /api/v1/dv-referrals/{id}/reject` with `{reason: "..."}`
- **THEN** the referral status SHALL change to `REJECTED`
- **AND** the audit event type SHALL be `DV_REFERRAL_ADMIN_REJECTED`
- **AND** SHALL publish SSE `referral.queue-changed`

### Requirement: CRITICAL banner has a primary action

The CriticalNotificationBanner SHALL render a primary action button that navigates to the admin escalation queue. The banner SHALL be hidden when there are no actionable escalations.

#### Scenario: Banner shows CTA when escalations exist
- **WHEN** a CoC admin has at least one unread CRITICAL notification of type `escalation.*`
- **THEN** the banner SHALL render
- **AND** SHALL contain a primary button labeled "Review N pending escalations →" where N is the count
- **AND** clicking the button SHALL navigate to `/admin#dvEscalations`

#### Scenario: Banner is hidden when queue is empty
- **WHEN** the count of unread CRITICAL escalation notifications is zero
- **THEN** the banner SHALL NOT render
- **AND** the page layout SHALL not reserve space for it

#### Scenario: Banner copy is reviewed for warmth
- **WHEN** a translator reviews the banner copy
- **THEN** the English string SHALL be "Review N pending escalations →"
- **AND** the Spanish string SHALL be "Revisar N escalaciones pendientes →"
- **AND** neither string SHALL use anxiety-inducing imperative verbs

### Requirement: Per-tenant escalation policy with append-only versioning

The system SHALL store escalation thresholds in a per-tenant append-only versioned table. Each policy update SHALL create a new row; existing rows SHALL never be modified or deleted.

#### Scenario: Default policy seeded for all tenants
- **WHEN** the application starts after Flyway V46 has run
- **THEN** there SHALL be exactly one row in `escalation_policy` with `tenant_id IS NULL`, `event_type = 'dv-referral'`, `version = 1`
- **AND** that row's thresholds SHALL match the historical hardcoded values: `[1h ACTION_REQUIRED COORDINATOR, 2h CRITICAL COC_ADMIN, 3h30m CRITICAL COORDINATOR+OUTREACH_WORKER, 4h INFO OUTREACH_WORKER]`

#### Scenario: Tenant inherits platform default if no custom policy
- **WHEN** a CoC admin queries `GET /api/v1/admin/escalation-policy/dv-referral` for a tenant with no custom policy
- **THEN** the response SHALL be the platform default policy with a flag `isDefault: true`

#### Scenario: PATCH creates a new version row
- **WHEN** a CoC admin sends `PATCH /api/v1/admin/escalation-policy/dv-referral` with new thresholds
- **THEN** the system SHALL insert a new row with `tenant_id = caller's tenant`, `event_type = 'dv-referral'`, `version = (max existing version for tenant) + 1`
- **AND** SHALL NOT update or delete any existing row
- **AND** SHALL return `200` with the new policy DTO

#### Scenario: Validation rejects non-monotonic thresholds
- **WHEN** the PATCH body contains thresholds with `t[i].at >= t[i+1].at`
- **THEN** the system SHALL return `400 Bad Request` with a structured error message naming the offending indices
- **AND** SHALL NOT insert any row

#### Scenario: Validation rejects invalid roles in recipients
- **WHEN** the PATCH body contains a recipient role not in `{COORDINATOR, COC_ADMIN, OUTREACH_WORKER}`
- **THEN** the system SHALL return `400 Bad Request`
- **AND** the error body includes `{"error":"validation_failed","field":"recipients[*].role","rejected_value":"<role>"}`

#### Scenario: Validation rejects PLATFORM_ADMIN as recipient
- **WHEN** the PATCH body contains `recipients[*].role = "PLATFORM_ADMIN"`
- **THEN** the system SHALL return `400 Bad Request`
- **AND** the error message includes "PLATFORM_ADMIN is deprecated; escalation policies cannot route to platform operators"

#### Scenario: Validation rejects PLATFORM_OPERATOR as recipient
- **WHEN** the PATCH body contains `recipients[*].role = "PLATFORM_OPERATOR"`
- **THEN** the system SHALL return `400 Bad Request`
- **AND** the error message includes "Escalation policies are tenant-scoped; platform operators are not in tenant escalation chains"

#### Scenario: Validation rejects invalid severity
- **WHEN** the PATCH body contains a severity not in `{INFO, ACTION_REQUIRED, CRITICAL}`
- **THEN** the system SHALL return `400 Bad Request`

#### Scenario: COORDINATOR cannot edit policy
- **WHEN** a COORDINATOR sends `PATCH /api/v1/admin/escalation-policy/dv-referral`
- **THEN** the system SHALL return `403 Forbidden`

#### Scenario: Threshold count cap prevents OOM via huge JSONB
- **WHEN** a PATCH request body contains more than 50 thresholds
- **THEN** the system SHALL return `400 Bad Request` (Bean Validation `@Size(max = 50)` on the request DTO)
- **AND** SHALL NOT insert any row
- **AND** the cap exists to prevent a malicious or buggy admin from OOMing the JSONB serializer and policy cache

### Requirement: Frozen-at-creation policy lookup for escalation

The escalation batch job SHALL apply the policy version that was active when each referral was created, not the current tenant policy. Mid-day policy changes SHALL only affect new referrals.

#### Scenario: New referral records the current policy snapshot
- **WHEN** a referral_token is created via `ReferralTokenService.create(...)`
- **THEN** the `referral_token.escalation_policy_id` column SHALL be set to the ID of the tenant's current policy (or platform default if no tenant policy exists)

#### Scenario: Batch job reads frozen policy per referral
- **WHEN** the escalation batch job processes a referral
- **THEN** the job SHALL look up `escalation_policy` by `referral_token.escalation_policy_id` (not by current tenant policy)
- **AND** SHALL apply the thresholds from that snapshot

#### Scenario: Mid-day policy change does not affect existing referrals
- **WHEN** a tenant has policy version 1 active
- **AND** referral A is created at 9:00am with `escalation_policy_id = policyV1.id`
- **AND** the admin PATCHes a new policy version 2 at 10:00am
- **AND** referral B is created at 11:00am with `escalation_policy_id = policyV2.id`
- **THEN** referral A SHALL continue to fire escalations per policy v1's thresholds
- **AND** referral B SHALL fire escalations per policy v2's thresholds

#### Scenario: Backwards compatibility for pre-V47 referrals
- **WHEN** the batch job processes a referral with `escalation_policy_id IS NULL` (existing rows from before V47)
- **THEN** the job SHALL fall back to the platform default policy (`tenant_id IS NULL, event_type = 'dv-referral'`)
- **AND** SHALL NOT raise an error

### Requirement: All admin escalation actions are recorded in the audit trail

The system SHALL write to the existing `audit_events` table for every CoC admin action on a DV referral or escalation policy. Audit detail blobs SHALL contain zero personally identifying information about clients.

#### Scenario: Each admin action produces exactly one audit event
- **WHEN** a CoC admin performs claim, release, reassign, accept, reject, or policy update
- **THEN** the system SHALL write exactly one row to `audit_events`
- **AND** the row's `event_type` SHALL be one of: `DV_REFERRAL_CLAIMED`, `DV_REFERRAL_RELEASED`, `DV_REFERRAL_REASSIGNED`, `DV_REFERRAL_ADMIN_ACCEPTED`, `DV_REFERRAL_ADMIN_REJECTED`, `ESCALATION_POLICY_UPDATED`
- **AND** the `actor_user_id` SHALL be the acting CoC admin's user ID
- **AND** the detail JSON SHALL contain only IDs, roles, and structured metadata

#### Scenario: Audit detail contains zero PII
- **WHEN** any of the 6 new audit events is written
- **THEN** the `detail` JSON SHALL NOT contain `callback_number`, `client_name`, free-text reason fields, or any field that could identify a survivor
- **AND** the `reason` field for reassign/reject SHALL be limited to admin-supplied text that the admin is responsible for keeping PII-free (the admin UI SHALL display a warning above the reason field)

#### Scenario: Auto-release records system actor
- **WHEN** the auto-release scheduled task clears an expired claim
- **THEN** the audit event `DV_REFERRAL_RELEASED` SHALL be written with `actor_user_id = NULL` (representing the system actor)
- **AND** the `audit_events.actor_user_id` column SHALL be nullable (V48 schema change, or V44 for deployments running v0.34.0+ bed-hold-integrity — was previously NOT NULL, which silently dropped these rows)
- **AND** the detail JSON SHALL contain `reason: "timeout"`
- **AND** application code reading audit rows SHALL treat NULL `actor_user_id` as "system" for display purposes

#### Scenario: Reassign audit details include shelterId and actorRoles
- **WHEN** any reassign action writes a `DV_REFERRAL_REASSIGNED` audit row
- **THEN** the `details` JSON SHALL include `shelterId` (the shelter this referral was for, so subpoena queries are single-table)
- **AND** SHALL include `actorRoles` (the acting admin's role list at action time, frozen so a later role change does not rewrite history)
- **AND** SHALL include `recipientCount` (operational fan-out scale)

#### Scenario: Policy update audit details include previousVersion
- **WHEN** a PATCH inserts policy version N where N > 1
- **THEN** the `ESCALATION_POLICY_UPDATED` audit row's `details` SHALL include `previousVersion: N - 1`
- **AND** when N = 1 (first tenant version), `previousVersion` SHALL be omitted from the details
- **AND** the previousVersion value is computed as `version - 1` because `EscalationPolicyRepository.insertNewVersion` uses an atomic `MAX(version) + 1` subquery (race-free)

#### Scenario: Group reassign that resumes a broken chain records chainResumed
- **WHEN** a referral has `escalation_chain_broken = TRUE` from a prior SPECIFIC_USER reassign
- **AND** an admin reassigns it via COORDINATOR_GROUP or COC_ADMIN_GROUP
- **THEN** the resulting `DV_REFERRAL_REASSIGNED` audit row's `details` SHALL include `chainResumed: true`
- **AND** the SPECIFIC_USER reassign that originally broke the chain SHALL NOT have `chainResumed` in its details

### Requirement: SSE live updates on the escalation queue

The system SHALL push real-time updates to the escalation queue view via Server-Sent Events using the existing notification SSE path.

#### Scenario: Claim update propagates within 2 seconds
- **WHEN** admin A claims a referral
- **AND** admin B has the queue view open
- **THEN** admin B's view SHALL show the claim within 2 seconds
- **AND** the row SHALL animate (highlight, then fade) to draw attention to the change

#### Scenario: New event types are pushed via existing SSE path
- **WHEN** a claim, release, reassign, or policy update occurs
- **THEN** the system SHALL publish an SSE event of type `referral.claimed`, `referral.released`, `referral.queue-changed`, or `referral.policy-updated` respectively
- **AND** the event SHALL be sent via the existing `NotificationService.pushNotification()` path
- **AND** SHALL NOT require any new SSE infrastructure

#### Scenario: Disconnected admin catches up via REST on reconnect
- **WHEN** admin B's SSE connection drops and reconnects
- **THEN** admin B's queue view SHALL re-fetch the current state via `GET /api/v1/dv-referrals/escalated`
- **AND** any events missed during the disconnect SHALL be reflected in the new state

### Requirement: Mobile-responsive escalation queue

The escalation queue view SHALL be usable on mobile screens via progressive disclosure. The escalation policy editor SHALL be desktop-only.

#### Scenario: Desktop renders a table
- **WHEN** the viewport width is ≥768px
- **THEN** the queue SHALL render as a table with all columns visible
- **AND** inline Claim buttons SHALL be present in each row

#### Scenario: Mobile renders a card list
- **WHEN** the viewport width is <768px
- **THEN** the queue SHALL render as a card list (one card per referral)
- **AND** each card SHALL show shelter, time-to-expiry, and a single primary CTA (Claim)
- **AND** other actions SHALL be hidden behind a "More" button that opens the detail modal

#### Scenario: Policy editor is desktop-only
- **WHEN** the viewport width is <768px
- **AND** the user navigates to the policy editor section
- **THEN** the editor SHALL display a read-only message: "Edit on a larger screen — this view is read-only on mobile"
- **AND** the form fields SHALL be disabled (not interactive)
- **AND** the Save button SHALL NOT be present in the DOM (preventing tap-to-submit on a form full of disabled values)

### Requirement: Frontend tab conforms to archived UI specs

The new `DvEscalationsTab` and its sub-components SHALL conform to the project's existing frontend conventions established by previously archived OpenSpec changes, so the new tab does not regress dark mode, WCAG, typography, or admin-panel-extraction patterns.

#### Scenario: Color tokens, no hardcoded hex
- **WHEN** any new component is created under `frontend/src/pages/admin/tabs/` or its sub-components for this change
- **THEN** all color values SHALL come from `theme/colors.ts` tokens (e.g. `color.bg`, `color.text`, `color.dv`, `color.primary`)
- **AND** SHALL NOT contain hardcoded hex values (audit by Playwright `typography.spec.ts` extension or visual diff)
- **AND** SHALL use `color.dv` family (purple — the project's safety color) for DV escalation accents, NOT `color.error` red (red is reserved for severity)

#### Scenario: Typography tokens, no hardcoded font sizes
- **WHEN** any new component sets a font size, weight, or line-height
- **THEN** the value SHALL come from `theme/typography.ts` tokens (`text.xs/sm/base/md/lg/xl/2xl/3xl`, `weight.normal/medium/semibold/bold/extrabold`)
- **AND** SHALL NOT contain numeric pixel font sizes (`fontSize: 14`)
- **AND** SHALL NOT use fixed `height` / `max-height` / `-webkit-line-clamp` on text containers (WCAG 1.4.12)

#### Scenario: SSE hook extension, not parallel stream
- **WHEN** the `useDvEscalationQueue` hook subscribes to the four new SSE event types (`referral.claimed`, `referral.released`, `referral.queue-changed`, `referral.policy-updated`)
- **THEN** it SHALL extend the existing `useNotifications` hook (one SSE connection per session)
- **AND** SHALL NOT open a parallel `EventSource` or second `fetchEventSource` connection
- **AND** SHALL use cross-component coordination via `window` custom events (matching the existing `SSE_REFERRAL_UPDATE`/`SSE_REFERRAL_EXPIRED` pattern)

#### Scenario: Disclosure pattern, not menu pattern
- **WHEN** the SPECIFIC_USER reassign tab is presented in the Reassign sub-modal
- **THEN** it SHALL use a disclosure (`<details>` or equivalent expandable) pattern, NOT `role="menu"`
- **AND** SHALL be gated behind an "Advanced" label per PagerDuty's documented warning convention
- **AND** the persona review (sse-notifications change) explicitly rejected `role="menu"` for similar patterns

#### Scenario: 44×44px minimum touch targets
- **WHEN** any new interactive element (button, link, action trigger) is rendered
- **THEN** its rendered size SHALL be at least 44×44 CSS pixels
- **AND** the existing `accessibility.spec.ts` axe-core CI gate SHALL remain green

#### Scenario: data-testid on every interactive element
- **WHEN** any new component renders an interactive element that Playwright will need to locate
- **THEN** it SHALL include a `data-testid` attribute with a stable, semantic id
- **AND** Playwright tests SHALL prefer `data-testid` selectors over fragile DOM/style selectors (memory: `feedback_data_testid`)

#### Scenario: Tab is lazy-loaded as a default export
- **WHEN** the new `DvEscalationsTab` is registered in `AdminPanel.tsx`
- **THEN** it SHALL be a `default export` from `frontend/src/pages/admin/tabs/DvEscalationsTab.tsx`
- **AND** SHALL be lazy-loaded via `React.lazy(() => import(...))` per the existing extracted-admin-panel pattern
- **AND** tab-specific types (`EscalatedReferral`, `EscalationPolicy`, `EscalationPolicyThreshold`) SHALL stay in the tab file, NOT in the shared `types.ts`
- **AND** only the `'dvEscalations'` `TabKey` union member SHALL be added to the shared `types.ts`

#### Scenario: Person-centered notification language
- **WHEN** any new i18n key is added for notification text
- **THEN** the English copy SHALL center the person being served, not the system action
- **AND** SHALL avoid anxiety-inducing imperative verbs ("Take action now" → "A new referral needs your attention")
- **AND** the Spanish copy SHALL preserve the warmth-vs-urgency balance, not literally translate
- **AND** Keisha Thompson's review SHALL be required before merge

### Requirement: Documentation deliverables

This change SHALL produce two new documentation files plus an update to FOR-DEVELOPERS.md as merge-blocking deliverables, not afterthoughts.

#### Scenario: Mermaid architecture diagram replaces drawio
- **WHEN** the change is merged
- **THEN** `docs/architecture.md` SHALL exist as a Mermaid-based system overview
- **AND** SHALL accurately reflect the post-v0.31.0 modular monolith including persistent notifications, the new escalation policy module, and the SSE flow
- **AND** the legacy `docs/architecture.drawio` SHALL be preserved alongside as a v0.21–v0.28 historical reference

#### Scenario: Business process doc series begins with two companion docs
- **WHEN** the change is merged
- **THEN** `docs/business-processes/dv-referral-end-to-end.md` SHALL exist as the parent doc covering the happy path
- **AND** `docs/business-processes/dv-referral-escalation.md` SHALL exist as the child doc covering the escalation branch
- **AND** the parent doc SHALL contain an actor inventory linked to PERSONAS.md, a Mermaid sequenceDiagram of search → request → screen → accept → warm handoff → closure, a role × phase matrix, and a Mermaid stateDiagram-v2 of the base `referral_token` state machine (PENDING → ACCEPTED|REJECTED|EXPIRED)
- **AND** the child doc SHALL contain a Mermaid sequenceDiagram of the escalation timeline (T+1h → T+2h → T+3.5h → T+4h) with admin claim/release/reassign/act actions, a role × time matrix, a Mermaid stateDiagram-v2 extending the base machine with the CLAIMED superstate, an edge case section (coordinator offline, two admins claim simultaneously, survivor cancels mid-flow, expiry race, mid-day policy change), persona traceability, and a back-reference to the parent doc
- **AND** both docs SHALL be reviewed together by Devon Kessler, Marcus Okafor, and Keisha Thompson before merge

#### Scenario: FOR-DEVELOPERS.md documents the policy data model
- **WHEN** the change is merged
- **THEN** `docs/FOR-DEVELOPERS.md` SHALL contain a new section "Escalation Policy and Frozen-at-Creation"
- **AND** that section SHALL describe the append-only versioning, the FK on referral_token, the cache layers, the validation rules, and the pattern for adding new event types beyond `dv-referral`
