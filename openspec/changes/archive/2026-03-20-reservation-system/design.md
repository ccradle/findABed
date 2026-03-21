## Context

Bed-availability gives outreach workers real-time bed counts, but two workers can target the same bed simultaneously. This change adds soft-hold reservations — a time-limited claim on a bed that prevents double-booking during the transport window (typically 30-60 minutes).

Key constraints:
- Hold duration is configurable per tenant (default 45 minutes)
- Auto-expiry must work without Redis (Lite tier uses scheduled task)
- Redis TTL acceleration in Standard/Full tiers for near-instant expiry
- Reservation state changes must produce availability snapshots (beds_on_hold / beds_occupied adjustments)
- Must integrate with existing append-only availability model (no UPDATE on bed_availability)

## Goals / Non-Goals

**Goals:**
- Soft-hold reservation lifecycle (create → confirm/cancel/expire)
- Configurable hold duration per tenant
- Auto-expiry that works across all deployment tiers
- Availability integration (holds affect beds_available in real-time)
- EventBus integration for webhook delivery of reservation events
- Frontend hold flow (search → hold → transport → confirm)

**Non-Goals:**
- Hard reservations or guaranteed placement (this is a soft-hold, not a booking)
- Waitlists or queuing when all beds are held
- Multi-bed reservations (one reservation = one bed for one population type)
- Hold transfer between outreach workers

## Decisions

### D1: Reservation table with status lifecycle

```sql
CREATE TABLE reservation (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shelter_id      UUID NOT NULL REFERENCES shelter(id),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    population_type VARCHAR(50) NOT NULL,
    user_id         UUID NOT NULL REFERENCES app_user(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'HELD',
    expires_at      TIMESTAMPTZ NOT NULL,
    confirmed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes           VARCHAR(500)
);
```

Status lifecycle: `HELD → CONFIRMED | CANCELLED | EXPIRED`. Terminal states are immutable — once confirmed/cancelled/expired, the row is never updated again.

**Rationale:** Simple lifecycle with clear terminal states. The `expires_at` column enables both scheduled-task polling (Lite) and Redis TTL (Standard/Full) expiry strategies.

### D2: Reservation creates availability snapshots

When a reservation state changes, the system creates a new availability snapshot with adjusted counts:
- **Create hold:** `beds_on_hold += 1` (new snapshot via AvailabilityService)
- **Confirm hold:** `beds_on_hold -= 1, beds_occupied += 1` (new snapshot)
- **Cancel/Expire hold:** `beds_on_hold -= 1` (new snapshot)

This preserves the append-only model — no UPDATE on bed_availability. The reservation service calls AvailabilityService.createSnapshot() with the adjusted values derived from the current latest snapshot.

**Rationale:** Reuses the existing availability infrastructure (cache invalidation, event publishing, data freshness). No new patterns needed.

### D3: Dual-tier auto-expiry

**Lite tier (no Redis):**
- `@Scheduled` task runs every 30 seconds
- Queries `SELECT * FROM reservation WHERE status = 'HELD' AND expires_at < NOW()`
- Transitions each to EXPIRED and creates availability snapshot

**Standard/Full tier (Redis available):**
- On reservation create: set Redis key `reservation:{id}` with TTL = hold duration
- Redis keyspace notification (`__keyevent@0__:expired`) triggers expiry handler
- Fallback: scheduled task still runs as safety net (catches missed notifications)

**Rationale:** Redis TTL gives near-instant expiry (< 1s latency). The scheduled task is a reliable fallback that works everywhere. Both paths converge on the same `expireReservation()` method.

### D4: API design — reservation endpoints

```
POST   /api/v1/reservations              Create hold (OUTREACH_WORKER+)
GET    /api/v1/reservations              List active holds for current user
PATCH  /api/v1/reservations/{id}/confirm  Client arrived (OUTREACH_WORKER+)
PATCH  /api/v1/reservations/{id}/cancel   Release hold (OUTREACH_WORKER+)
```

Create request:
```json
{
  "shelterId": "uuid",
  "populationType": "SINGLE_ADULT",
  "notes": "Family of 3 en route, ETA 20 min"
}
```

Response includes `expires_at` so the client can show a countdown timer.

**Rationale:** Reservation is its own resource (not nested under shelters) because the actor is an outreach worker, not a coordinator. PATCH for state transitions (confirm/cancel) follows the same pattern as availability updates.

### D5: Bed search integration

The bed search response gains a `bedsHeld` field per population type. `beds_available` already accounts for holds (via `beds_on_hold` in the availability snapshot), but showing `bedsHeld` separately lets outreach workers understand contention — "3 available, 1 held" is more informative than just "3 available."

### D6: New reservation module in modular monolith

```
org.fabt.reservation/
  api/         ReservationController
  domain/      Reservation, ReservationStatus
  repository/  ReservationRepository
  service/     ReservationService, ReservationExpiryService
```

Dependencies:
- `shared/` (cache, event, security, web)
- `availability/service/` (to create snapshots on state changes)
- `shelter/service/` (to verify shelter exists)

ArchUnit rules will be updated to allow these cross-module dependencies.

## Risks / Trade-offs

- **[Hold contention at popular shelters]** → Mitigation: Short default hold duration (45 min). UI shows hold count so workers can see contention. Future: configurable per-shelter hold limits.
- **[Expiry race condition]** → Mitigation: Reservation status update uses optimistic locking (WHERE status = 'HELD'). If already expired, confirm returns 409 Conflict.
- **[Redis key missed]** → Mitigation: Scheduled task runs as safety net even in Standard/Full tier. Double-expiry is idempotent (WHERE status = 'HELD' guard).
- **[Availability snapshot flood from holds]** → Mitigation: Each hold creates one snapshot. At realistic volumes (< 100 holds/day per shelter), this is negligible alongside coordinator updates.
