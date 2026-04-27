## MODIFIED Requirements

### Requirement: reservation-lifecycle
The system SHALL allow outreach workers to create, confirm, and cancel soft-hold bed reservations. A reservation temporarily claims one bed for a specific population type at a shelter. The reservation lifecycle is: HELD → CONFIRMED (client arrived), CANCELLED (worker released), EXPIRED (timed out), or CANCELLED_SHELTER_DEACTIVATED (shelter deactivated by admin). Creating a reservation increments `beds_on_hold` via a new availability snapshot. Confirming converts to `beds_occupied`. Cancelling, expiring, or shelter-deactivation-cancelling decrements `beds_on_hold`. Only the reservation creator (or `COC_ADMIN`) can confirm or cancel. (Previously: `COC_ADMIN/PLATFORM_ADMIN`. PLATFORM_ADMIN is deprecated; backward-compat via V87 backfill.) Hold duration is configurable per tenant (default 90 minutes).

#### Scenario: Create a reservation
- **WHEN** an outreach worker sends POST `/api/v1/reservations` with `{"shelterId": "<uuid>", "populationType": "SINGLE_ADULT", "notes": "Family en route, ETA 20 min"}`
- **THEN** the system creates a reservation with status HELD and `expires_at` set to current time + tenant hold duration
- **AND** a new availability snapshot is created with `beds_on_hold` incremented by 1
- **AND** the response is 201 with the reservation including `id`, `status`, `expiresAt`, and derived `beds_available`

#### Scenario: Outreach worker confirms own reservation
- **WHEN** the creator of a HELD reservation sends `PATCH /api/v1/reservations/{id}/confirm`
- **THEN** status moves to CONFIRMED
- **AND** `beds_on_hold` decrements by 1 and `beds_occupied` increments by 1 via a new availability snapshot

#### Scenario: COC_ADMIN cancels another worker's reservation
- **WHEN** a `COC_ADMIN` sends `PATCH /api/v1/reservations/{id}/cancel` for a reservation created by a different user in the same tenant
- **THEN** the operation succeeds
- **AND** `beds_on_hold` decrements by 1 via a new availability snapshot

#### Scenario: Coordinator cannot confirm a reservation they did not create
- **WHEN** a non-admin `COORDINATOR` (not the original creator) sends `PATCH /api/v1/reservations/{id}/confirm`
- **THEN** the system returns 403 Forbidden
- **AND** `COC_ADMIN` can confirm or cancel any reservation in their tenant

#### Scenario: Holds cancelled when shelter is deactivated
- **WHEN** an admin deactivates a shelter that has active HELD reservations
- **THEN** all HELD reservations for that shelter are transitioned to `CANCELLED_SHELTER_DEACTIVATED`
- **AND** for each cancelled reservation, a new availability snapshot is created with `beds_on_hold` decremented by 1
- **AND** a `reservation.cancelled` event is published for each with cancellation reason `SHELTER_DEACTIVATED`
