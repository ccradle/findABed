## ADDED Requirements

### Requirement: hmis-export-admin-tab
The system SHALL provide an HMIS Export tab in the Admin panel for COC_ADMIN and PLATFORM_ADMIN users.

#### Scenario: Admin sees export status
- **WHEN** an admin opens the HMIS Export tab
- **THEN** they see: last push time per vendor, status (success/failed), next scheduled push

#### Scenario: Admin previews export data
- **WHEN** an admin views the data preview section
- **THEN** they see a table: shelter name, population type, beds_total, beds_occupied, utilization %
- **AND** DV shelters appear as a single aggregated row
- **AND** filters are available for shelter, population type, and DV/non-DV

#### Scenario: Admin views export history
- **WHEN** an admin views the export history section
- **THEN** they see past pushes: timestamp, vendor, record count, status
- **AND** filters are available for date range, vendor, and status

#### Scenario: PLATFORM_ADMIN triggers manual push
- **WHEN** a PLATFORM_ADMIN clicks "Push Now" and confirms
- **THEN** a push is initiated immediately to all enabled vendors
- **AND** the export status updates to reflect the push

#### Scenario: COC_ADMIN cannot trigger manual push
- **WHEN** a COC_ADMIN views the HMIS Export tab
- **THEN** the "Push Now" button is not visible

#### Scenario: Outreach worker cannot see HMIS Export tab
- **WHEN** an OUTREACH_WORKER navigates to the admin panel
- **THEN** the HMIS Export tab is not visible

### Requirement: hmis-vendor-configuration
The system SHALL allow PLATFORM_ADMIN users to configure HMIS vendor connections.

#### Scenario: Add a vendor
- **WHEN** a PLATFORM_ADMIN adds a new vendor (type, base URL, API key)
- **THEN** the vendor appears in the configuration list as enabled
- **AND** the API key is stored encrypted and displayed masked

#### Scenario: Disable a vendor
- **WHEN** a PLATFORM_ADMIN disables a vendor
- **THEN** no pushes are sent to that vendor until re-enabled

#### Scenario: API key is write-once
- **WHEN** a vendor's API key has been set
- **THEN** the Admin UI shows the key as masked (e.g., "****ab3f")
- **AND** the key cannot be read back, only replaced

#### Scenario: Manual retry of dead-letter entry
- **WHEN** a PLATFORM_ADMIN selects a dead-letter entry and clicks "Retry"
- **THEN** the entry is moved back to PENDING and reprocessed
