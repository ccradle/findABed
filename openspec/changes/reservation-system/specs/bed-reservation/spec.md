## ADDED Requirements

### Requirement: reservation-lifecycle
The system SHALL allow outreach workers to create, confirm, and cancel soft-hold bed reservations. A reservation temporarily claims one bed for a specific population type at a shelter. The reservation lifecycle is: HELD → CONFIRMED (client arrived), CANCELLED (worker released), or EXPIRED (timed out). Creating a reservation increments `beds_on_hold` via a new availability snapshot. Confirming converts to `beds_occupied`. Cancelling or expiring decrements `beds_on_hold`. Only the reservation creator (or COC_ADMIN/PLATFORM_ADMIN) can confirm or cancel. Hold duration is configurable per tenant (default 45 minutes).

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
- **AND** COC_ADMIN and PLATFORM_ADMIN can confirm or cancel any reservation in their tenant

### Requirement: reservation-concurrency
The system SHALL prevent double-booking by ensuring that creating a reservation atomically checks availability and creates the hold. If two workers attempt to reserve the last bed simultaneously, only one succeeds.

#### Scenario: Concurrent reservation for last bed
- **WHEN** Shelter A has `beds_available: 1` for SINGLE_ADULT and two outreach workers simultaneously send POST `/api/v1/reservations`
- **THEN** one request succeeds with 201 and the other returns 409 Conflict
- **AND** the successful reservation has `beds_on_hold: 1` and `beds_available: 0` in the resulting snapshot
