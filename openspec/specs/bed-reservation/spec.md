## Purpose

Soft-hold bed reservation lifecycle. Prevents double-booking during outreach transport by temporarily claiming a bed with configurable auto-expiry.

## Requirements

### Requirement: reservation-lifecycle
The system SHALL allow outreach workers to create, confirm, and cancel soft-hold bed reservations. A reservation temporarily claims one bed for a specific population type at a shelter. The reservation lifecycle is: HELD → CONFIRMED (client arrived), CANCELLED (worker released), EXPIRED (timed out), or CANCELLED_SHELTER_DEACTIVATED (shelter deactivated by admin). Creating a reservation increments `beds_on_hold` via a new availability snapshot. Confirming converts to `beds_occupied`. Cancelling, expiring, or shelter-deactivation-cancelling decrements `beds_on_hold`. Only the reservation creator (or `COC_ADMIN`) can confirm or cancel. (Previously: `COC_ADMIN/PLATFORM_ADMIN`. PLATFORM_ADMIN is deprecated; backward-compat via V87 backfill.) Hold duration is configurable per tenant (default 90 minutes).

#### Scenario: Create a reservation
- **WHEN** an outreach worker sends POST `/api/v1/reservations` with `{"shelterId": "<uuid>", "populationType": "SINGLE_ADULT", "notes": "Family en route, ETA 20 min"}`
- **THEN** the system creates a reservation with status HELD and `expires_at` set to current time + tenant hold duration
- **AND** a new availability snapshot is created with `beds_on_hold` incremented by 1
- **AND** the response is 201 with the reservation including `id`, `status`, `expiresAt`, and derived `beds_available`
- **AND** a `reservation.created` event is published to the EventBus

#### Scenario: Create reservation fails when no beds available
- **WHEN** an outreach worker sends POST `/api/v1/reservations` for a shelter/population where `beds_available = 0`
- **THEN** the system returns 409 Conflict with message "No beds available for this population type"
- **AND** no reservation is created and no availability snapshot is modified

#### Scenario: Confirm a reservation
- **WHEN** the reservation creator sends PATCH `/api/v1/reservations/{id}/confirm`
- **THEN** the system transitions the reservation to CONFIRMED with `confirmed_at` set to current time
- **AND** a new availability snapshot is created with `beds_on_hold` decremented by 1 and `beds_occupied` incremented by 1
- **AND** a `reservation.confirmed` event is published

#### Scenario: Confirm an expired reservation returns 409
- **WHEN** a worker sends PATCH `/api/v1/reservations/{id}/confirm` for a reservation with status EXPIRED
- **THEN** the system returns 409 Conflict with message "Reservation has expired"
- **AND** the reservation status is not changed

#### Scenario: Cancel a reservation
- **WHEN** the reservation creator sends PATCH `/api/v1/reservations/{id}/cancel`
- **THEN** the system transitions the reservation to CANCELLED with `cancelled_at` set to current time
- **AND** a new availability snapshot is created with `beds_on_hold` decremented by 1
- **AND** a `reservation.cancelled` event is published

#### Scenario: List active reservations
- **WHEN** an outreach worker sends GET `/api/v1/reservations`
- **THEN** the system returns all HELD reservations for the current user within their tenant
- **AND** each reservation includes `id`, `shelterId`, `shelterName`, `populationType`, `status`, `expiresAt`, `createdAt`, and remaining seconds until expiry

#### Scenario: Only reservation creator can confirm or cancel
- **WHEN** a different outreach worker sends PATCH `/api/v1/reservations/{id}/confirm` for a reservation they did not create
- **THEN** the system returns 403 Forbidden
- **AND** `COC_ADMIN` can confirm or cancel any reservation in their tenant

#### Scenario: Holds cancelled when shelter is deactivated
- **WHEN** an admin deactivates a shelter that has active HELD reservations
- **THEN** all HELD reservations for that shelter are transitioned to `CANCELLED_SHELTER_DEACTIVATED`
- **AND** for each cancelled reservation, a new availability snapshot is created with `beds_on_hold` decremented by 1
- **AND** a `reservation.cancelled` event is published for each with cancellation reason `SHELTER_DEACTIVATED`

#### Scenario: Outreach worker notified of shelter-deactivation cancellation
- **WHEN** a reservation is cancelled due to shelter deactivation
- **THEN** the reservation creator receives a persistent notification: "Your bed hold at {shelter name} was cancelled because the shelter was deactivated"
- **AND** the notification type is `HOLD_CANCELLED_SHELTER_DEACTIVATED`

#### Scenario: Create reservation blocked for inactive shelter
- **WHEN** an outreach worker sends POST `/api/v1/reservations` for a shelter where `active=false`
- **THEN** the system returns 409 Conflict with message "Cannot hold a bed at an inactive shelter"

### Requirement: hold-invariant-enforcement
The system SHALL ensure reservation holds never produce negative bed availability. A hold must be rejected if no beds are available. Concurrent holds on the last bed must result in exactly one success and one rejection.

#### Scenario: TC-2.6 — hold rejected when zero available
- **WHEN** `beds_available=0` and an outreach worker attempts a hold
- **THEN** the API returns 409 Conflict
- **AND** `beds_on_hold` is unchanged

#### Scenario: TC-2.2 — confirm does not change available (INV-6)
- **WHEN** a held reservation is confirmed
- **THEN** `beds_occupied` increments by 1, `beds_on_hold` decrements by 1
- **AND** `beds_available` is unchanged

#### Scenario: TC-2.3 — cancel increases available by 1 (INV-7)
- **WHEN** a held reservation is cancelled
- **THEN** `beds_on_hold` decrements by 1
- **AND** `beds_available` increases by exactly 1

#### Scenario: TC-2.4 — expiry increases available by 1 (INV-7)
- **WHEN** a held reservation expires
- **THEN** same behavior as cancel — `beds_available` increases by exactly 1

#### Scenario: TC-2.5 — hold on last bed
- **WHEN** `beds_available=1` and a hold is placed
- **THEN** `beds_on_hold=1`, `beds_available=0`
- **AND** no further holds can be placed

#### Scenario: TC-3.2 — concurrent double-hold on last bed
- **WHEN** two workers simultaneously attempt to hold the last available bed
- **THEN** exactly one succeeds (201), exactly one fails (409)
- **AND** `beds_on_hold=1`, `beds_available=0` (never -1, never hold=2)

### Requirement: coordinator-hold-protection
The system SHALL prevent coordinator availability updates from silently overwriting active reservation holds. When a coordinator submits an availability PATCH, the `beds_on_hold` value must not be reduced below the count of active HELD reservations.

#### Scenario: TC-2.7 — coordinator sends hold=0 while holds exist
- **WHEN** 1 active HELD reservation exists and coordinator submits `bedsOnHold=0`
- **THEN** the system overrides `bedsOnHold` to 1 (the active reservation count)
- **AND** `beds_available` is computed using the corrected `bedsOnHold`

#### Scenario: TC-2.8 — coordinator reduces total while holds exist
- **WHEN** `beds_total=10, beds_occupied=7, beds_on_hold=2` and coordinator submits `bedsTotal=8`
- **THEN** the API rejects with 422 because `7 + 2 > 8` (INV-5 violated)

### Requirement: reservation-concurrency
The system SHALL prevent double-booking by ensuring that creating a reservation atomically checks availability and creates the hold. If two workers attempt to reserve the last bed simultaneously, only one succeeds.

#### Scenario: Concurrent reservation for last bed
- **WHEN** Shelter A has `beds_available: 1` for SINGLE_ADULT and two outreach workers simultaneously send POST `/api/v1/reservations`
- **THEN** one request succeeds with 201 and the other returns 409 Conflict
- **AND** the successful reservation has `beds_on_hold: 1` and `beds_available: 0` in the resulting snapshot

### Requirement: navigator-hold-attribution
The system SHALL support third-party navigator hold attribution on reservation records. An outreach worker holding a bed on behalf of a client who is not a platform user MAY provide optional `heldForClientName`, `heldForClientDob`, and `holdNotes` fields when creating a reservation. These fields are visible to shelter coordinators viewing the hold.

**API / domain layer:** callers (and the `Reservation` Java entity) see plaintext — `heldForClientName` String, `heldForClientDob` LocalDate, `holdNotes` String.

**Storage (Option A — issue #152):** the database persists these fields as `held_for_client_name_encrypted TEXT`, `held_for_client_dob_encrypted TEXT`, `hold_notes_encrypted TEXT` — all nullable, all storing the base64 v1 `EncryptionEnvelope` produced by `SecretEncryptionService.encryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, plaintext)`. The V93 migration bundles the `tenant_dek.purpose` CHECK-constraint update to add `RESERVATION_PII` to the allowed set.

**Two-layer PII posture (defense in depth):**

1. **At-rest ciphertext via `tenant_dek`.** A `pg_dump` captured at any time exports ciphertext that is unreadable without both the master KEK and the tenant's `tenant_dek` row. Inherits the crypto-shred property from Phase F-6: `TenantLifecycleService.hardDelete(tenantId)` CASCADE-destroys the tenant's wrapped DEKs, rendering any surviving ciphertext unrecoverable.
2. **24h post-resolution purge via Spring Batch.** All three `_encrypted` fields SHALL be nulled 24 hours after the reservation's resolution time (expiry, confirmation, or cancellation). The purge applies to the ciphertext columns; the plaintext was never persisted. `hold_notes_encrypted` is explicitly in scope for the purge — hold notes may contain names and contact information of supervision officers. The cleanup job is a scope extension of the existing DV referral token purge job; it must be null-safe on pre-V93 databases.

**UI labeling (dignity-centered, per Keisha Thompson warroom):**
- `heldForClientName` → field label: "Who is this hold for?" / sub-label: "Name (for shelter check-in)"
- `heldForClientDob` → field label: "Date of birth" / sub-label: "For shelter to confirm arrival"
- `holdNotes` → field label: "Note for shelter coordinator"

#### Scenario: Navigator creates a hold with client attribution
- **WHEN** an outreach worker sends POST `/api/v1/reservations` with `heldForClientName: "A. Johnson"`, `heldForClientDob: "1985-03-15"`, and `holdNotes: "Client on post-release supervision, must arrive by noon"`
- **THEN** the reservation is created with status HELD
- **AND** the service encrypts each field via `SecretEncryptionService.encryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, plaintext)` before persisting
- **AND** the database columns `held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `hold_notes_encrypted` contain base64 v1 envelopes
- **AND** the response plaintext-level fields `heldForClientName`, `heldForClientDob`, `holdNotes` round-trip the original values

#### Scenario: Navigator hold without attribution (backward compatible)
- **WHEN** an outreach worker sends POST `/api/v1/reservations` without attribution fields
- **THEN** the reservation is created normally with all three `_encrypted` columns null
- **AND** the response has `heldForClientName`, `heldForClientDob`, and `holdNotes` as null
- **AND** all existing reservation behavior is unchanged

#### Scenario: Shelter coordinator sees hold attribution on their dashboard
- **WHEN** a shelter coordinator views active holds for their shelter
- **THEN** the row mapper decrypts the `_encrypted` columns via `decryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, ciphertext)` transparently
- **AND** holds with `heldForClientName` populated display the client name alongside hold information
- **AND** holds without attribution show no client name field (not "null" or empty string — the field is absent)

#### Scenario: PII fields nulled 24h after hold resolution
- **WHEN** a reservation transitions to EXPIRED, CONFIRMED, CANCELLED, or CANCELLED_SHELTER_DEACTIVATED
- **AND** 24 hours have elapsed since `updated_at`
- **THEN** the Spring Batch cleanup job sets `held_for_client_name_encrypted = null`, `held_for_client_dob_encrypted = null`, `hold_notes_encrypted = null`
- **AND** the cleanup job performs NO decryption — it nulls ciphertext columns directly
- **AND** the reservation record and its other fields (status, expiresAt, shelterId, etc.) are preserved

#### Scenario: PII cleanup job is null-safe pre-V93
- **WHEN** the Spring Batch cleanup job runs on a database before V93 migration is applied
- **THEN** the job completes without error (null-safe logic; the `_encrypted` columns do not exist yet)

#### Scenario: heldForClientDob validation rejects implausible dates (plaintext-layer validation)
- **WHEN** an outreach worker sends `heldForClientDob` with a date in the future or before 1900-01-01
- **THEN** the service rejects with 400 Bad Request BEFORE any encryption attempt (validation is a plaintext-layer concern)

#### Scenario: Hold creation form displays PII purge notice
- **WHEN** an outreach worker opens the hold creation dialog and expands the "Add client details (optional)" section
- **THEN** a non-dismissable context note (`hold.clientAttributionPrivacyNote`) is visible adjacent to the client attribution fields
- **AND** the note states that client name, date of birth, and notes will be automatically removed 24 hours after the hold is resolved

#### Scenario: pg_dump during the 24h window exports ciphertext, not plaintext
- **WHEN** a `pg_dump` is captured while a hold is still active (within the 24h purge window)
- **AND** the dump is restored to an independent Postgres instance WITHOUT access to the master KEK
- **THEN** the `held_for_client_name_encrypted` / `_dob_encrypted` / `_notes_encrypted` columns contain base64 ciphertext
- **AND** no plaintext `heldForClientName` / `heldForClientDob` / `holdNotes` values are recoverable from the dump alone
- **AND** recovery requires both the master KEK and the tenant's `tenant_dek` row

#### Scenario: Cross-tenant ciphertext rejection (inherits Phase F-6 kid check)
- **WHEN** Tenant A creates a hold with `heldForClientName` populated (ciphertext persisted, kid bound to Tenant A in `tenant_dek`)
- **AND** a decrypt attempt is made with Tenant B's context on Tenant A's ciphertext
- **THEN** `SecretEncryptionService.decryptForTenant` raises `CrossTenantCiphertextException`
- **AND** no plaintext is leaked

#### Scenario: Hard-delete crypto-shreds reservation PII
- **WHEN** Tenant A is hard-deleted via `TenantLifecycleService.hardDelete(...)`
- **AND** Tenant A had reservations with `_encrypted` columns populated prior to deletion
- **THEN** the CASCADE chain destroys Tenant A's `tenant_dek` rows including the `RESERVATION_PII` DEK
- **AND** any surviving ciphertext (e.g., in a pre-shred backup) is unrecoverable — the wrapping DEK for that tenant no longer exists in the live database or in any application cache

#### Scenario: Cross-tenant: navigator hold PII not accessible from other tenants
- **WHEN** Tenant A's outreach worker creates a hold with `heldForClientName` populated
- **AND** a request from Tenant B's session queries reservations
- **THEN** Tenant B receives no reservation data from Tenant A (enforced by existing RLS on reservation; ciphertext-at-rest is defense in depth, not the primary control)
