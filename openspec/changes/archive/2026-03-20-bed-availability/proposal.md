## Why

The platform foundation is deployed with shelters, constraints, and capacities — but outreach workers see total bed counts, not real-time availability. A shelter with 50 total beds and 48 occupied looks the same as one with 50 beds and 2 occupied. Without live availability data, the outreach search is a directory, not a placement tool. This change adds the core domain capability that makes the platform actually save time: real-time bed availability with append-only snapshots, ranked query results, and coordinator update flow.

## What Changes

- New `bed_availability` table: append-only snapshots of bed state per shelter + population type, with `snapshot_ts`, `beds_total`, `beds_occupied`, `beds_on_hold`, `accepting_new_guests`
- `beds_available` derived at query time: `beds_total - beds_occupied - beds_on_hold` (never stored)
- Availability update API: coordinators submit snapshots via `PATCH /api/v1/shelters/{id}/availability` (atomic, single-purpose — REQ-MCP-1)
- Availability query API: `POST /api/v1/queries/beds` with constraint filters, ranked by (1) distance, (2) beds_available descending, (3) fewer barriers
- Every query response includes `data_age_seconds` and `data_freshness` (FRESH/AGING/STALE/UNKNOWN)
- `ON CONFLICT DO NOTHING` on concurrent snapshot inserts (HSDS extension spec requirement)
- EventBus publishes `availability.updated` event on every snapshot (enables webhook subscriptions from platform-foundation)
- Frontend outreach search updated to show real-time availability, hide shelters with 0 beds (or flag as full)
- Coordinator dashboard updated with availability update form (beds_occupied input, not just total capacity)
- Cache invalidation: L1/L2 cache invalidated synchronously before returning 200 on update (design rule D6)

## Capabilities

### New Capabilities

- `bed-availability-query`: Query available shelter beds with constraint filters and ranked results. Response includes beds_available (derived), data_age_seconds, data_freshness. p95 < 500ms.
- `shelter-availability-update`: Coordinator submits availability snapshot. Append-only, ≤ 3 API calls, p95 < 200ms. Publishes availability.updated event.

### Modified Capabilities

- `shelter-profile`: Shelter detail response now includes latest availability snapshot (beds_available per population type) alongside static constraints and total capacity.
- `observability`: data_age_seconds and data_freshness now computed from live availability snapshots (snapshot_ts), not just shelter updatedAt.
- `webhook-subscriptions`: availability.updated events now fire on real data changes (previously only the event schema was defined, no events were published).

## Impact

- **New database table**: `bed_availability` (append-only, partitioned by snapshot_ts for performance)
- **New module**: `org.fabt.availability` (api/, domain/, repository/, service/) — modular monolith boundary
- **Modified modules**: shelter (availability in detail response), observability (data_age from snapshot_ts)
- **New API endpoints**: `PATCH /api/v1/shelters/{id}/availability`, `POST /api/v1/queries/beds`
- **Modified API endpoints**: `GET /api/v1/shelters/{id}` (includes availability), `GET /api/v1/shelters` (includes availability summary)
- **Frontend**: OutreachSearch shows beds_available with freshness indicators; CoordinatorDashboard has availability update form
- **Events**: availability.updated events published to EventBus on every snapshot insert
- **Cache**: Shelter availability cached in L1 (Caffeine 60s) / L2 (Redis 300s) with synchronous invalidation on update
- **Performance**: Query p50 < 100ms, p95 < 500ms; Update p95 < 200ms (targets from HSDS extension spec)
