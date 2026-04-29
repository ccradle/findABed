## ADDED Requirements

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

#### Scenario: PII cleanup job fails fast on pre-V93 databases
*(Revised 2026-04-29 verify-round-2 S1 — earlier draft asserted the job "completes without error / null-safe logic." Slice 2C ships SQL that references the `_encrypted` columns by name; on a pre-V93 DB the column does not exist and the SQL fails with a column-not-found error. This is the safer ops posture: a silent no-op would mask a deployment-order regression where a v0.55+ JAR is started against a pre-V93 schema. The loud failure surfaces the migration-order error in the operator's logs immediately.)*
- **WHEN** the Spring Batch cleanup job runs on a database before V93 migration is applied
- **THEN** the job throws a `DataAccessException` (column-not-found) and the operator's monitoring sees a failed run
- **AND** the deploy runbook for v0.55+ requires V91-V94 to ship in the same release as the slice-2C JAR (so this code path never legitimately fires in production)

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
