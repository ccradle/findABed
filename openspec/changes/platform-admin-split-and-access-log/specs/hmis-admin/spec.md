## MODIFIED Requirements

### Requirement: hmis-export-admin-tab
The system SHALL provide an HMIS Export tab in the Admin panel for `COC_ADMIN` users (read-only) and `PLATFORM_OPERATOR` users (write — manual triggers, gated by `@PlatformAdminOnly`). (Previously: `COC_ADMIN and PLATFORM_ADMIN`. Now split: read-only for tenant admins; write requires platform operator + audited unseal.)

#### Scenario: Admin sees export status
- **WHEN** a `COC_ADMIN` opens the HMIS Export tab
- **THEN** they see: last push time per vendor, status (success/failed), next scheduled push
- **AND** the "Push Now" and "Add Vendor" controls are NOT visible

#### Scenario: PLATFORM_OPERATOR triggers manual push
- **WHEN** a `PLATFORM_OPERATOR` clicks "Push Now" with header `X-Platform-Justification: monthly compliance push - vendor X`
- **THEN** a push is initiated immediately to the targeted tenant's enabled vendors
- **AND** the export status updates to reflect the push
- **AND** rows are written to `platform_admin_access_log` and to `audit_events` (with `tenant_id = <target tenant>`, chained per Phase G-1)

#### Scenario: COC_ADMIN cannot trigger manual push
- **WHEN** a `COC_ADMIN` attempts POST to the manual-push endpoint
- **THEN** the system returns HTTP 403 Forbidden
- **AND** no log rows are written

### Requirement: hmis-vendor-configuration
The system SHALL allow `PLATFORM_OPERATOR` users (gated by `@PlatformAdminOnly`) to configure HMIS vendor connections. Vendor configuration affects pushes for an entire tenant; per VAWA H4 posture this requires the audited unseal channel rather than tenant-scoped admin authority.

#### Scenario: Add a vendor
- **WHEN** a `PLATFORM_OPERATOR` adds a new vendor (type, base URL, API key) for tenant T with valid `X-Platform-Justification` header
- **THEN** the vendor appears in the configuration list as enabled
- **AND** the API key is stored encrypted and displayed masked
- **AND** rows are written to `platform_admin_access_log` and `audit_events` (`tenant_id = T`)

#### Scenario: Disable a vendor
- **WHEN** a `PLATFORM_OPERATOR` disables a vendor for tenant T with justification
- **THEN** no pushes are sent to that vendor until re-enabled
- **AND** both log tables receive rows

#### Scenario: API key is write-once
- **WHEN** a vendor's API key has been set
- **THEN** the system returns the API key masked in subsequent GET responses
- **AND** updating requires a fresh PUT with a new API key (no read-back)

#### Scenario: COC_ADMIN cannot configure vendors
- **WHEN** a `COC_ADMIN` attempts to add, update, or delete a vendor
- **THEN** the system returns HTTP 403 Forbidden
