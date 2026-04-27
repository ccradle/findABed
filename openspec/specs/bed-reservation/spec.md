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
