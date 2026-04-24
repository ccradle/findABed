## ADDED Requirements

### Requirement: navigator-hold-attribution
The system SHALL support third-party navigator hold attribution on reservation records. An outreach worker holding a bed on behalf of a client who is not a platform user MAY provide optional `heldForClientName`, `heldForClientDob`, and `holdNotes` fields when creating a reservation. These fields are visible to shelter coordinators viewing the hold.

`heldForClientName` VARCHAR(100), `heldForClientDob` DATE, `holdNotes` TEXT — all nullable. These fields are stored on the `reservation` table (V81 migration).

**PII lifecycle:** All three fields SHALL be nulled by the Spring Batch cleanup job 24 hours after the reservation's resolution time (expiry, confirmation, or cancellation). `holdNotes` is explicitly in scope for PII purge — hold notes may contain names and contact information of supervision officers. The cleanup job is a scope extension of the existing DV referral token purge job; it must be null-safe on pre-V81 databases.

**UI labeling (dignity-centered, per Keisha Thompson warroom):**
- `heldForClientName` → field label: "Who is this hold for?" / sub-label: "Name (for shelter check-in)"
- `heldForClientDob` → field label: "Date of birth" / sub-label: "For shelter to confirm arrival"
- `holdNotes` → field label: "Note for shelter coordinator"

#### Scenario: Navigator creates a hold with client attribution
- **WHEN** an outreach worker sends POST `/api/v1/reservations` with `heldForClientName: "A. Johnson"`, `heldForClientDob: "1985-03-15"`, and `holdNotes: "Client on post-release supervision, must arrive by noon"`
- **THEN** the reservation is created with status HELD and all three fields stored
- **AND** the response includes `heldForClientName`, `heldForClientDob`, and `holdNotes`

#### Scenario: Navigator hold without attribution (backward compatible)
- **WHEN** an outreach worker sends POST `/api/v1/reservations` without attribution fields
- **THEN** the reservation is created normally with `heldForClientName`, `heldForClientDob`, and `holdNotes` as null
- **AND** all existing reservation behavior is unchanged

#### Scenario: Shelter coordinator sees hold attribution on their dashboard
- **WHEN** a shelter coordinator views active holds for their shelter
- **THEN** holds with `heldForClientName` populated display the client name alongside hold information
- **AND** holds without attribution show no client name field (not "null" or empty string — the field is absent)

#### Scenario: PII fields nulled 24h after hold resolution
- **WHEN** a reservation transitions to EXPIRED, CONFIRMED, CANCELLED, or CANCELLED_SHELTER_DEACTIVATED
- **AND** 24 hours have elapsed since `updated_at`
- **THEN** the Spring Batch cleanup job sets `heldForClientName = null`, `heldForClientDob = null`, `holdNotes = null`
- **AND** the reservation record and its other fields (status, expiresAt, shelterId, etc.) are preserved

#### Scenario: PII cleanup job is null-safe pre-V81
- **WHEN** the Spring Batch cleanup job runs on a database before V81 migration is applied
- **THEN** the job completes without error (null-safe logic; the columns do not exist yet)

#### Scenario: heldForClientDob validation rejects implausible dates
- **WHEN** an outreach worker sends `heldForClientDob` with a date in the future or before 1900-01-01
- **THEN** the response is 400 Bad Request

#### Scenario: Hold creation form displays PII purge notice
- **WHEN** an outreach worker opens the hold creation dialog and expands the "Add client details (optional)" section
- **THEN** a non-dismissable context note (`hold.clientAttributionPrivacyNote`) is visible adjacent to the client attribution fields
- **AND** the note states that client name, date of birth, and notes will be automatically removed 24 hours after the hold is resolved

#### Scenario: Cross-tenant: navigator hold PII not accessible from other tenants
- **WHEN** Tenant A's outreach worker creates a hold with `heldForClientName` populated
- **AND** a request from Tenant B's session queries reservations
- **THEN** Tenant B receives no reservation data from Tenant A
