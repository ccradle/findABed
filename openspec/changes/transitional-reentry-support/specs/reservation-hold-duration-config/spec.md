## MODIFIED Requirements

### Requirement: reservation-hold-duration-config
The system SHALL expose hold duration configuration in the admin panel via the `ReservationSettings` component. The component is wired to `tenant.config.holdDurationMinutes`. Range: 30–480 minutes. COC_ADMIN role required to change. Hold duration changes apply to **new holds only** — in-flight reservations retain their original `expires_at`. The default is 90 minutes for new tenants.

Reentry deployments configure 180–240 minutes to accommodate release-day transport logistics (prison bus drop + transport to shelter + paperwork delays). Hospital discharge deployments configure 180 minutes. The 30–480 range covers both use cases.

#### Scenario: Admin views current hold duration
- **WHEN** a COC_ADMIN or PLATFORM_ADMIN opens the Admin panel Reservation Settings section
- **THEN** the current hold duration is displayed with the configured value (default 90 minutes)
- **AND** the section is wired to the live `tenant.config.holdDurationMinutes` value

#### Scenario: Admin changes hold duration
- **WHEN** an admin sets hold duration to 240 minutes and saves
- **THEN** new reservations created after the change use the 240-minute hold duration
- **AND** existing active holds are unaffected (they keep their original `expires_at`)

#### Scenario: In-flight hold retains original duration after config change
- **WHEN** a reservation is created with hold duration 90 minutes
- **AND** an admin changes hold duration to 240 minutes
- **AND** the original reservation is checked 91 minutes after creation
- **THEN** the original reservation has status EXPIRED (its 90-minute window closed)
- **AND** a new reservation created after the config change uses 240 minutes

#### Scenario: Validation prevents values outside 30–480 range
- **WHEN** an admin enters a hold duration below 30 minutes or above 480 minutes
- **THEN** the UI prevents saving and shows a validation message: "Hold duration must be between 30 and 480 minutes"

#### Scenario: Hold duration change applies immediately to new holds
- **WHEN** an admin changes hold duration to 180 minutes via PATCH `/api/v1/admin/tenants/{tenantId}/hold-duration`
- **THEN** the next reservation created by any outreach worker in that tenant uses the 180-minute window
- **AND** no restart or cache invalidation is required

#### Scenario: Outreach worker sees configured hold duration in hold confirmation
- **WHEN** an outreach worker successfully creates a reservation
- **THEN** the success message shows the actual configured hold duration (not a hardcoded value)

#### Scenario: Default is 90 minutes
- **WHEN** a new tenant is created with no explicit `holdDurationMinutes` in tenant.config
- **THEN** the default hold duration is 90 minutes

#### Scenario: Hold duration endpoint requires COC_ADMIN role
- **WHEN** an OUTREACH_WORKER or COORDINATOR calls PATCH `/api/v1/admin/tenants/{tenantId}/hold-duration`
- **THEN** the response is 403 Forbidden

#### Scenario: Hold duration endpoint scoped to caller's tenant
- **WHEN** a COC_ADMIN from Tenant A calls PATCH `/api/v1/admin/tenants/{tenantId}/hold-duration` using Tenant B's tenantId
- **THEN** the response is 403 Forbidden
- **AND** Tenant B's hold duration configuration is unchanged
