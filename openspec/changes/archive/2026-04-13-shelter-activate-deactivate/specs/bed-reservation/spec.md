## MODIFIED Requirements

### Requirement: reservation-lifecycle
The system SHALL allow outreach workers to create, confirm, and cancel soft-hold bed reservations. A reservation temporarily claims one bed for a specific population type at a shelter. The reservation lifecycle is: HELD → CONFIRMED (client arrived), CANCELLED (worker released), EXPIRED (timed out), or CANCELLED_SHELTER_DEACTIVATED (shelter deactivated by admin). Creating a reservation increments `beds_on_hold` via a new availability snapshot. Confirming converts to `beds_occupied`. Cancelling, expiring, or shelter-deactivation-cancelling decrements `beds_on_hold`. Only the reservation creator (or COC_ADMIN/PLATFORM_ADMIN) can confirm or cancel. Hold duration is configurable per tenant (default 90 minutes).

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
