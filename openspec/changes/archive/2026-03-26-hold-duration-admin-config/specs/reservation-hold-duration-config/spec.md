## MODIFIED Requirements

### Requirement: reservation-hold-duration-config
MODIFY: Add Admin UI for hold duration editing and change default from 45 to 90 minutes.

#### Scenario: Admin views current hold duration
- **WHEN** a COC_ADMIN or PLATFORM_ADMIN opens the Admin panel
- **THEN** the current hold duration is displayed with the configured value (default 90 minutes)

#### Scenario: Admin changes hold duration
- **WHEN** an admin sets hold duration to 120 minutes and saves
- **THEN** new reservations use the updated 120-minute hold duration
- **AND** existing active holds are unaffected (they keep their original expires_at)

#### Scenario: Validation prevents unreasonable values
- **WHEN** an admin enters a hold duration below 5 minutes or above 480 minutes
- **THEN** the UI prevents saving and shows a validation message

#### Scenario: Outreach worker sees configured hold duration
- **WHEN** an outreach worker holds a bed
- **THEN** the success message shows the actual configured hold duration (not a hardcoded value)

#### Scenario: Default is 90 minutes
- **WHEN** a new tenant is created with no explicit hold_duration_minutes
- **THEN** the default hold duration is 90 minutes

#### Scenario: Hospital deployment uses extended hold
- **WHEN** a tenant configures hold duration to 180 minutes (3 hours)
- **THEN** reservations hold beds for 180 minutes before auto-expiry
