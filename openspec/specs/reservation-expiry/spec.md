## Purpose

Auto-expiry logic for timed-out bed reservations. Dual-tier strategy: scheduled polling (Lite) and Redis TTL acceleration (Standard/Full).

## Requirements

### Requirement: reservation-auto-expiry
The system SHALL automatically expire reservations that exceed their hold duration. Expiry must work across all deployment tiers. In Lite tier (no Redis), a scheduled task polls for expired reservations every 30 seconds. In Standard/Full tier (Redis available), Redis TTL-based key expiry provides near-instant expiry with the scheduled task as a safety net.

#### Scenario: Reservation expires automatically (Lite tier)
- **WHEN** a reservation's `expires_at` timestamp has passed
- **THEN** within 30 seconds, the scheduled task transitions the reservation to EXPIRED
- **AND** a new availability snapshot is created with `beds_on_hold` decremented by 1
- **AND** a `reservation.expired` event is published

#### Scenario: Reservation expires via Redis TTL (Standard/Full tier)
- **WHEN** a reservation is created in a deployment with Redis available
- **THEN** a Redis key `reservation:{id}` is set with TTL equal to the hold duration
- **AND** when the key expires, the Redis keyspace notification triggers immediate expiry
- **AND** the reservation is transitioned to EXPIRED within 1 second of `expires_at`

#### Scenario: Double-expiry is idempotent
- **WHEN** both the Redis TTL listener and the scheduled task attempt to expire the same reservation
- **THEN** only one succeeds (the SQL update uses `WHERE status = 'HELD'` guard)
- **AND** the second attempt is a no-op with no error
- **AND** only one availability snapshot is created

### Requirement: reservation-hold-duration-config
The system SHALL allow tenant-level configuration of hold duration. The default hold duration is 45 minutes. CoC admins can adjust this via tenant configuration.

#### Scenario: Tenant configures hold duration
- **WHEN** a CoC admin sets the hold duration to 60 minutes in tenant config
- **THEN** all new reservations in that tenant have `expires_at` set to created_at + 60 minutes
- **AND** existing reservations retain their original `expires_at`

#### Scenario: Default hold duration used when not configured
- **WHEN** a tenant has no hold duration configuration
- **THEN** new reservations use the default hold duration of 45 minutes
