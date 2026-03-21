## MODIFIED Requirements

### Requirement: availability-snapshot-create
Reservation state changes (create, confirm, cancel, expire) now trigger availability snapshots through AvailabilityService. The coordinator manual update flow is unchanged, but snapshots may also be created automatically by the reservation system.

#### Scenario: Reservation creates availability snapshot
- **WHEN** a reservation is created, confirmed, cancelled, or expired
- **THEN** the system creates a new availability snapshot via AvailabilityService.createSnapshot() with the adjusted `beds_on_hold` and `beds_occupied` values
- **AND** the snapshot's `updated_by` field records the system actor (e.g., "reservation:create", "reservation:expire")
- **AND** cache invalidation and event publishing follow the same synchronous flow as coordinator updates
