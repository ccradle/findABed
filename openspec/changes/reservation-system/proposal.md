## Why

Two outreach workers can currently find the same available bed via the search API and both attempt to transport clients to it — there is no mechanism to temporarily hold a bed during the placement process. A family en route to a shelter may arrive to find the bed already taken. Soft-hold reservations prevent double-booking and give outreach workers confidence that the bed they found will still be there when their client arrives.

## What Changes

- New `reservation` table: tracks soft-holds with configurable duration, auto-expiry, and status lifecycle (HELD → CONFIRMED / CANCELLED / EXPIRED)
- Reservation API: `POST /api/v1/reservations` (create hold), `PATCH /api/v1/reservations/{id}/confirm` (client arrived), `PATCH /api/v1/reservations/{id}/cancel` (release hold), `GET /api/v1/reservations` (list active holds for user)
- Creating a reservation increments `beds_on_hold` in a new availability snapshot; confirming converts to `beds_occupied`; cancelling/expiring decrements `beds_on_hold`
- Auto-expiry: scheduled task checks for expired holds (Lite tier), Redis TTL key with expiry listener (Standard/Full tier)
- Bed search results now show `beds_held` count alongside `beds_available` so outreach workers see real contention
- EventBus events: `reservation.created`, `reservation.confirmed`, `reservation.cancelled`, `reservation.expired`
- Frontend: "Hold This Bed" button in outreach search results, active reservations panel, confirmation/cancel flow
- Coordinator dashboard shows active holds on their shelters

## Capabilities

### New Capabilities
- `bed-reservation`: CRUD lifecycle for soft-hold bed reservations (create, confirm, cancel, list)
- `reservation-expiry`: Auto-expiry logic for timed-out reservations (scheduled task + Redis TTL acceleration)

### Modified Capabilities
- `bed-availability-query`: Search results include `beds_held` count; held beds reduce `beds_available`
- `shelter-availability-update`: Reservation confirm/cancel triggers new availability snapshot with adjusted `beds_occupied` / `beds_on_hold`

## Impact

- **New database table**: `reservation` (status lifecycle, FK to shelter + user + tenant)
- **New module**: `org.fabt.reservation` (api/, domain/, repository/, service/) — modular monolith boundary
- **Modified modules**: availability (snapshot creation on reservation state changes), shelter (dashboard shows holds)
- **New API endpoints**: `POST /api/v1/reservations`, `PATCH /api/v1/reservations/{id}/confirm`, `PATCH /api/v1/reservations/{id}/cancel`, `GET /api/v1/reservations`
- **Modified API endpoints**: `POST /api/v1/queries/beds` (includes beds_held in response)
- **Frontend**: Hold button in search, active reservations panel, coordinator hold visibility
- **Events**: reservation.created, reservation.confirmed, reservation.cancelled, reservation.expired
- **Redis** (Standard/Full): TTL-based hold expiry keys with keyspace notification listener
- **Scheduled task** (Lite): Periodic sweep for expired reservations (every 30 seconds)
