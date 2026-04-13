## ADDED Requirements

### Requirement: Shelter deactivation with cascade
The system SHALL allow COC_ADMIN and PLATFORM_ADMIN users to deactivate a shelter via `PATCH /api/v1/shelters/{id}/deactivate`. Deactivation SHALL set `active=false`, record deactivation metadata (`deactivated_at`, `deactivated_by`, `deactivation_reason`), expire all active bed holds for the shelter, and create a SHELTER_DEACTIVATED audit event. The deactivation reason SHALL be one of: TEMPORARY_CLOSURE, SEASONAL_END, PERMANENT_CLOSURE, CODE_VIOLATION, FUNDING_LOSS, OTHER.

#### Scenario: Deactivate a shelter with no active holds
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/deactivate` with `{"reason": "TEMPORARY_CLOSURE"}`
- **THEN** the shelter's `active` flag is set to `false`
- **AND** `deactivated_at` is set to current timestamp, `deactivated_by` is set to the admin's user ID, `deactivation_reason` is set to `TEMPORARY_CLOSURE`
- **AND** the shelter no longer appears in bed search results
- **AND** a SHELTER_DEACTIVATED audit event is recorded with shelter ID, reason, and actor

#### Scenario: Deactivate a shelter with active holds
- **WHEN** an admin deactivates a shelter that has 3 active HELD reservations
- **THEN** all 3 reservations are transitioned to `CANCELLED_SHELTER_DEACTIVATED`
- **AND** each affected outreach worker receives a persistent notification: "Your bed hold at {shelter name} was cancelled because the shelter was deactivated"
- **AND** the audit event records the count of cancelled holds

#### Scenario: Deactivate a shelter with invalid reason
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/deactivate` with `{"reason": "INVALID"}`
- **THEN** the system returns 400 Bad Request listing valid reason values

#### Scenario: Deactivate an already-inactive shelter
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/deactivate` for a shelter where `active=false`
- **THEN** the system returns 409 Conflict with message "Shelter is already inactive"

#### Scenario: Non-admin cannot deactivate
- **WHEN** a COORDINATOR or OUTREACH_WORKER sends `PATCH /api/v1/shelters/{id}/deactivate`
- **THEN** the system returns 403 Forbidden

### Requirement: DV shelter deactivation safety gate
The system SHALL require enhanced confirmation when deactivating a DV shelter. If PENDING DV referrals exist for the shelter, the initial deactivation request SHALL return a confirmation-required response. Deactivation notifications for DV shelters SHALL be restricted to users with `dvAccess=true` and SHALL NOT include the shelter address.

#### Scenario: DV shelter deactivation with pending referrals
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/deactivate` for a DV shelter with 2 PENDING referrals
- **AND** the request does not include `"confirmDv": true`
- **THEN** the system returns 409 with `{"confirmationRequired": true, "pendingDvReferrals": 2, "message": "This DV shelter has 2 pending referrals. Confirm to proceed."}`

#### Scenario: DV shelter deactivation confirmed
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/deactivate` with `{"reason": "PERMANENT_CLOSURE", "confirmDv": true}`
- **THEN** the shelter is deactivated
- **AND** PENDING DV referrals are NOT bulk-cancelled (they remain PENDING and will be flagged as SHELTER_CLOSED by the existing safety check on next access)
- **AND** deactivation notifications are sent only to users with `dvAccess=true`
- **AND** the notification text does not include the shelter address

#### Scenario: DV shelter deactivation with no pending referrals
- **WHEN** an admin deactivates a DV shelter that has zero PENDING referrals
- **THEN** deactivation proceeds without requiring `confirmDv`
- **AND** DV-restricted notification rules still apply

#### Scenario: Hold cancellation notification always reaches hold creator
- **WHEN** a shelter is deactivated and active holds are cancelled
- **THEN** each hold creator receives a "bed hold cancelled" notification regardless of dvAccess (this is operational, not a DV event)
- **AND** the DV notification restriction applies only to the admin-facing "shelter deactivated" event broadcast, NOT to per-worker hold cancellation notifications

### Requirement: Shelter reactivation
The system SHALL allow COC_ADMIN and PLATFORM_ADMIN users to reactivate an inactive shelter via `PATCH /api/v1/shelters/{id}/reactivate`. Reactivation SHALL set `active=true`, clear deactivation metadata, and create a SHELTER_REACTIVATED audit event. Reactivation SHALL NOT restore previous bed availability — the coordinator must update availability after reactivation.

#### Scenario: Reactivate an inactive shelter
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/reactivate`
- **THEN** the shelter's `active` flag is set to `true`
- **AND** `deactivated_at`, `deactivated_by`, and `deactivation_reason` are cleared (set to null)
- **AND** the shelter reappears in bed search results (with current availability data, which may be stale)
- **AND** a SHELTER_REACTIVATED audit event is recorded

#### Scenario: Reactivate an already-active shelter
- **WHEN** an admin sends `PATCH /api/v1/shelters/{id}/reactivate` for a shelter where `active=true`
- **THEN** the system returns 409 Conflict with message "Shelter is already active"

### Requirement: Admin shelter list status display
The admin shelter list SHALL display an active/inactive status indicator for each shelter and provide a toggle action for deactivation and reactivation.

#### Scenario: Admin sees status badge on shelter list
- **WHEN** an admin views the shelter list in the admin panel
- **THEN** each shelter row displays an "Active" or "Inactive" status badge
- **AND** inactive shelters are visually distinct (reduced opacity, muted text)

#### Scenario: Admin toggles shelter to inactive
- **WHEN** an admin clicks the deactivate action on an active shelter row
- **THEN** a confirmation dialog appears with a reason selector (TEMPORARY_CLOSURE, SEASONAL_END, PERMANENT_CLOSURE, CODE_VIOLATION, FUNDING_LOSS, OTHER)
- **AND** for DV shelters, the dialog includes an additional safety warning and pending referral count

#### Scenario: Admin toggles shelter to active
- **WHEN** an admin clicks the reactivate action on an inactive shelter row
- **THEN** a confirmation dialog appears: "Reactivate {shelter name}? The coordinator will need to update bed availability."
- **AND** on confirmation, the shelter is reactivated

### Requirement: Coordinator inactive shelter visibility
Coordinators assigned to an inactive shelter SHALL see it in their dashboard with a visual indicator and disabled bed update controls.

#### Scenario: Coordinator sees inactive shelter in dashboard
- **WHEN** a coordinator logs in and one of their assigned shelters is inactive
- **THEN** the shelter appears in their dashboard with reduced opacity and an "Inactive" badge
- **AND** bed update controls (stepper, availability form) are disabled
- **AND** a tooltip or message displays: "This shelter was deactivated on {date}. Contact your CoC admin to reactivate."

#### Scenario: Coordinator cannot update availability for inactive shelter
- **WHEN** a coordinator sends `PATCH /api/v1/shelters/{id}/availability` for an inactive shelter
- **THEN** the system returns 409 Conflict with message "Cannot update availability for an inactive shelter"

### Requirement: Deactivation audit trail
The system SHALL record SHELTER_DEACTIVATED and SHELTER_REACTIVATED audit events with structured metadata.

#### Scenario: Deactivation audit event
- **WHEN** a shelter is deactivated
- **THEN** an audit event is created with type SHELTER_DEACTIVATED, shelter ID, reason, actor user ID, and count of cancelled holds

#### Scenario: Reactivation audit event
- **WHEN** a shelter is reactivated
- **THEN** an audit event is created with type SHELTER_REACTIVATED, shelter ID, actor user ID, and previous deactivation reason
