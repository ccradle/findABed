## ADDED Requirements

### Requirement: beds_on_hold is server-managed only

The system SHALL treat `bed_availability.beds_on_hold` as a server-managed denormalized cache derived from the count of `reservation` rows with `status = 'HELD'` for the same shelter and population type. No application code path SHALL write `beds_on_hold` to a value that does not equal the actual count.

#### Scenario: reservation create increments beds_on_hold to actual count
- **GIVEN** a shelter with `beds_on_hold = 0` and zero HELD reservations
- **WHEN** a coordinator creates a new reservation for that shelter and population
- **THEN** the system SHALL recompute `beds_on_hold` from the reservation table
- **AND** the new `bed_availability` snapshot SHALL have `beds_on_hold = 1`
- **AND** the snapshot SHALL be tagged `updated_by = 'system:reservation'`

#### Scenario: reservation expiry decrements beds_on_hold to actual count
- **GIVEN** a shelter with `beds_on_hold = 3` and 3 HELD reservations, where one reservation is past `expires_at`
- **WHEN** the reservation expiry job runs and transitions the expired reservation to `EXPIRED`
- **THEN** the system SHALL recompute `beds_on_hold` from the reservation table
- **AND** the new `bed_availability` snapshot SHALL have `beds_on_hold = 2`

#### Scenario: reservation cancel decrements beds_on_hold to actual count
- **GIVEN** a shelter with `beds_on_hold = 1` and 1 HELD reservation
- **WHEN** the reservation creator cancels the reservation
- **THEN** the system SHALL recompute `beds_on_hold` from the reservation table
- **AND** the new `bed_availability` snapshot SHALL have `beds_on_hold = 0`

#### Scenario: invariant holds across the full reservation lifecycle
- **GIVEN** any shelter and population type
- **WHEN** any number of reservation create, cancel, expire, and confirm operations have been performed
- **THEN** the latest `bed_availability` snapshot's `beds_on_hold` value SHALL equal `SELECT COUNT(*) FROM reservation WHERE shelter_id = ? AND population_type = ? AND status = 'HELD'`
- **AND** this invariant SHALL be asserted by `BedHoldsInvariantTest` after every reservation lifecycle event in the integration test suite

### Requirement: Manual coordinator PATCH no longer accepts beds_on_hold

The `PATCH /api/v1/shelters/{id}/availability` endpoint SHALL ignore any non-null `bedsOnHold` value in the request body and SHALL log a WARN-level message when a non-zero value is received. The field is server-managed via the reservation lifecycle and the new offline-hold endpoint, not via this endpoint.

#### Scenario: coordinator PATCH with bedsOnHold is ignored
- **WHEN** a coordinator sends `PATCH /api/v1/shelters/{id}/availability` with `{"bedsTotal": 10, "bedsOccupied": 5, "bedsOnHold": 3, "populationType": "SINGLE_ADULT", "acceptingNewGuests": true}` and there are zero HELD reservations for that shelter+population
- **THEN** the system SHALL log a WARN-level message: `"Ignored coordinator-supplied beds_on_hold=3 for shelter X / SINGLE_ADULT — server-managed via reservation table"`
- **AND** the response snapshot SHALL have `beds_on_hold = 0` (the actual count, not the requested value)
- **AND** the response SHALL still be HTTP 200 (soft deprecation, not hard rejection)

#### Scenario: coordinator PATCH with bedsOnHold = 0 is silently accepted
- **WHEN** a coordinator sends `PATCH /api/v1/shelters/{id}/availability` with `bedsOnHold: 0`
- **THEN** the system SHALL NOT log a WARN message (zero is treated as a no-op, common in legacy clients)
- **AND** the response snapshot's `beds_on_hold` SHALL reflect the actual reservation count

#### Scenario: coordinator PATCH with null bedsOnHold is silently accepted
- **WHEN** a coordinator sends `PATCH /api/v1/shelters/{id}/availability` without a `bedsOnHold` field
- **THEN** the system SHALL NOT log a WARN message
- **AND** the response snapshot's `beds_on_hold` SHALL reflect the actual reservation count

### Requirement: Offline hold creation endpoint

The system SHALL provide a `POST /api/v1/shelters/{shelterId}/manual-hold` endpoint for coordinators to create an "offline hold" — a manually-created HELD reservation representing a phone reservation, expected guest, or other off-system bed allocation. The endpoint SHALL create a real `reservation` row through the existing reservation lifecycle so that all downstream invariants apply.

#### Scenario: coordinator creates an offline hold for a phone reservation
- **GIVEN** a coordinator authenticated and assigned to shelter X
- **WHEN** the coordinator sends `POST /api/v1/shelters/{shelterX}/manual-hold` with `{"populationType": "SINGLE_ADULT", "reason": "Phone call from intake"}`
- **THEN** the system SHALL create a new `reservation` row with `status = 'HELD'`, `user_id` = the requesting coordinator's id, `shelter_id` = X, `population_type = 'SINGLE_ADULT'`, `expires_at = NOW() + tenant.hold_duration_minutes`, `notes = 'Manual offline hold: Phone call from intake'`
- **AND** the system SHALL recompute `beds_on_hold` for shelter X / SINGLE_ADULT, increasing the snapshot value by 1
- **AND** the response SHALL include the new reservation id and `expires_at`

#### Scenario: COORDINATOR role is authorized
- **GIVEN** a coordinator with the COORDINATOR role assigned to shelter X
- **WHEN** the coordinator sends `POST /api/v1/shelters/{shelterX}/manual-hold` with a valid request
- **THEN** the system SHALL succeed with HTTP 201

#### Scenario: COORDINATOR not assigned to the shelter is rejected
- **GIVEN** a coordinator with the COORDINATOR role NOT assigned to shelter X
- **WHEN** the coordinator sends `POST /api/v1/shelters/{shelterX}/manual-hold`
- **THEN** the system SHALL reject the request with HTTP 403

#### Scenario: offline hold expires through normal reservation lifecycle
- **GIVEN** an offline hold reservation with `expires_at` in the past
- **WHEN** the `ReservationExpiryService` scheduled task runs
- **THEN** the system SHALL transition the offline hold to `EXPIRED`
- **AND** the next `recomputeBedsOnHold()` call SHALL decrement the snapshot value
- **AND** no special handling SHALL be required for offline holds vs. regular reservations

### Requirement: Spring Batch reconciliation tasklet

The system SHALL run a Spring Batch reconciliation job every 5 minutes that detects and corrects any drift between `bed_availability.beds_on_hold` and the actual count of HELD reservations for each shelter+population pair. The job SHALL be implemented as a Spring Batch tasklet matching the existing `ReferralEscalationJobConfig` pattern. The job SHALL be wrapped in `TenantContext.runWithContext(null, true, ...)` so that DV shelter rows are visible to its query.

#### Scenario: drift is detected and corrected
- **GIVEN** a shelter with `beds_on_hold = 5` in the latest snapshot and zero HELD reservations
- **WHEN** the reconciliation tasklet runs
- **THEN** the tasklet SHALL detect the drift
- **AND** the tasklet SHALL call `recomputeBedsOnHold()` for that shelter+population
- **AND** a new snapshot SHALL be inserted with `beds_on_hold = 0`, `updated_by = 'system:reconciliation'`, `notes = 'reconciliation: drift corrected'`
- **AND** an audit row SHALL be written with `action = 'BED_HOLDS_RECONCILED'`, `actor_user_id = NULL`, payload `{shelter_id, population_type, snapshot_value_before: 5, actual_count: 0, delta: -5}`

#### Scenario: no drift means no work
- **GIVEN** all shelter+population pairs where `beds_on_hold === COUNT(HELD)` for every pair
- **WHEN** the reconciliation tasklet runs
- **THEN** the tasklet SHALL complete without inserting any snapshots
- **AND** the tasklet SHALL NOT write any audit rows
- **AND** the tasklet SHALL log "Bed holds reconciliation complete: 0 corrections" at INFO level (the "Bed holds" prefix disambiguates from other batch jobs in the codebase)

#### Scenario: tasklet sees DV shelter rows under RLS
- **GIVEN** a DV shelter with `beds_on_hold = 2` in the latest snapshot and zero HELD reservations
- **WHEN** the reconciliation tasklet runs (without TenantContext set externally)
- **THEN** the tasklet SHALL set `app.dv_access = 'true'` via `TenantContext.runWithContext(null, true, ...)` before the reconciliation query
- **AND** the DV shelter row SHALL be visible to the query
- **AND** the drift SHALL be detected and corrected per the standard scenario

#### Scenario: tasklet emits Micrometer metrics
- **WHEN** the reconciliation tasklet runs
- **THEN** the system SHALL increment `fabt.bed.hold.reconciliation.batch.runs.total` Counter
- **AND** the system SHALL record `fabt.bed.hold.reconciliation.batch.duration` Timer with the run duration
- **AND** the system SHALL increment `fabt.bed.hold.reconciliation.corrections.total` Counter by the number of corrections written

### Requirement: BED_HOLDS_RECONCILED audit event type

The system SHALL define a new audit event type constant `BED_HOLDS_RECONCILED` in `AuditEventTypes.java`. Every reconciliation correction SHALL write one `audit_events` row with this action.

#### Scenario: audit event constant is defined
- **WHEN** developer code references `AuditEventTypes.BED_HOLDS_RECONCILED`
- **THEN** the constant SHALL exist with value `"BED_HOLDS_RECONCILED"`
- **AND** the constant SHALL be tested for non-null and non-empty in the existing `AuditEventTypesTest` (or equivalent contract pin)

#### Scenario: reconciliation correction writes audit row with system actor
- **WHEN** the reconciliation tasklet writes a corrective snapshot
- **THEN** the system SHALL insert one `audit_events` row with `action = 'BED_HOLDS_RECONCILED'`, `actor_user_id = NULL`, `target_id` = the affected shelter id, payload as JSON containing `shelter_id`, `population_type`, `snapshot_value_before`, `actual_count`, `delta`
- **AND** the audit row SHALL be queryable via the standard audit endpoint

### Requirement: Seed data backs every beds_on_hold > 0 with real reservations

The `infra/scripts/seed-data.sql` file SHALL ensure that every `bed_availability` row inserted with `beds_on_hold = N > 0` has N matching `reservation` rows with `status = 'HELD'` for the same shelter and population type. The seed SHALL produce a clean baseline where the runtime invariant holds at startup.

#### Scenario: fresh seed produces zero drift
- **GIVEN** a fresh database after `seed-data.sql` has been applied
- **WHEN** the reconciliation tasklet runs immediately after seed application
- **THEN** zero drift SHALL be detected
- **AND** zero corrective snapshots SHALL be inserted
- **AND** zero `BED_HOLDS_RECONCILED` audit rows SHALL be written

#### Scenario: seeded HELD reservations have realistic expires_at
- **WHEN** reading the seed file
- **THEN** the seeded HELD reservations SHALL have `expires_at` values varying across the hold lifecycle (some near expiry, some mid-window, some early in window)
- **AND** the demo SHALL visually show the natural progression of reservation lifecycle states without requiring the demo operator to create new reservations

### Requirement: One-time backfill migration

The system SHALL include a Flyway migration that performs a one-time backfill correcting any existing drift in the `bed_availability` table on first deployment. The migration SHALL be append-only (INSERT only, no UPDATE, no DELETE) and idempotent (re-running on a clean database inserts zero rows).

#### Scenario: migration runs at deploy time
- **GIVEN** a database with N drifted shelter+population pairs in `bed_availability`
- **WHEN** Flyway applies the bed-hold-integrity backfill migration
- **THEN** N corrective snapshots SHALL be inserted, tagged `updated_by = 'V<N>-rca-backfill'`
- **AND** the migration SHALL appear in `flyway_schema_history` as successful

#### Scenario: migration is idempotent
- **GIVEN** a database where the bed-hold-integrity backfill migration has already been applied and zero drift exists
- **WHEN** the migration is re-run (in a hypothetical disaster recovery scenario)
- **THEN** zero rows SHALL be inserted (the WHERE clause matches no drifted rows)

### Requirement: BedHoldsInvariantTest is gating

The `BedHoldsInvariantTest` integration test class SHALL exist and SHALL assert the load-bearing invariant `beds_on_hold === COUNT(reservation WHERE shelter_id=X AND population_type=Y AND status='HELD')` after every reservation lifecycle event. The test SHALL be required to pass for the change to merge and SHALL be required for every subsequent change that touches `ReservationService` or `AvailabilityController`.

#### Scenario: invariant holds after reservation create
- **GIVEN** a shelter X / SINGLE_ADULT with the latest snapshot in any state
- **WHEN** a coordinator creates a new reservation
- **THEN** `BedHoldsInvariantTest.invariant_after_create` SHALL pass
- **AND** the assertion SHALL fail loudly with a clear error message if a future refactor reintroduces delta math

#### Scenario: invariant holds after reservation cancel
- **WHEN** a reservation is cancelled
- **THEN** `BedHoldsInvariantTest.invariant_after_cancel` SHALL pass

#### Scenario: invariant holds after reservation expire
- **WHEN** a reservation is expired by the auto-expiry job
- **THEN** `BedHoldsInvariantTest.invariant_after_expire` SHALL pass

#### Scenario: invariant holds after offline hold creation
- **WHEN** a coordinator creates an offline hold via `POST /api/v1/shelters/{id}/manual-hold`
- **THEN** `BedHoldsInvariantTest.invariant_after_offline_hold` SHALL pass

#### Scenario: invariant holds after reconciliation tasklet runs
- **GIVEN** a shelter with seeded drift
- **WHEN** the reconciliation tasklet runs and writes a corrective snapshot
- **THEN** `BedHoldsReconciliationJobTest.reconciliation_corrects_seeded_drift` SHALL pass, verifying the corrective snapshot exists with `beds_on_hold = COUNT(HELD)` (the invariant by construction)
- **AND** the underlying recompute code path — which the tasklet delegates to via `ReservationService.recomputeBedsOnHold` — SHALL be covered by `BedHoldsInvariantTest.invariant_after_recompute_via_public_api`
