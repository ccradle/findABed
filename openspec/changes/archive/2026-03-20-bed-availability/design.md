## Context

The platform foundation provides shelter profiles, constraints, capacities, and multi-tenant auth. But the outreach search shows static total capacity — not real-time availability. This change adds the BedAvailability domain object from the HSDS extension spec, making the search a live placement tool.

Key constraints from the HSDS extension spec:
- `beds_available` is derived, not stored: `beds_total - beds_occupied - beds_on_hold`
- Availability updates are append-only (never UPDATE, always INSERT new snapshot)
- `ON CONFLICT DO NOTHING` on concurrent inserts
- Data age surfaces to caller (`data_age_seconds` from `snapshot_ts`)
- Cache invalidation must be synchronous (invalidate L1/L2 BEFORE returning 200)
- Coordinators update on mobile, standing up, stressed (< 3 taps, < 200ms)

## Goals / Non-Goals

**Goals:**
- Real-time bed availability query with ranked results
- Append-only availability snapshots with concurrent insert safety
- Availability update API optimized for coordinator mobile workflow
- EventBus integration for webhook subscription delivery
- Frontend integration (outreach search + coordinator dashboard)
- Performance: query p50 < 100ms, p95 < 500ms; update p95 < 200ms

**Non-Goals:**
- Reservations / soft-hold (separate change: reservation-system)
- Surge mode / overflow capacity (separate change: surge-mode)
- Geo-distance ranking (requires PostGIS — deferred to geo-search change)
- Historical analytics on availability trends (separate change: coc-analytics)

## Decisions

### D1: Append-only availability table with latest-snapshot query

```sql
CREATE TABLE bed_availability (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shelter_id      UUID NOT NULL REFERENCES shelter(id),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    population_type VARCHAR(50) NOT NULL,
    beds_total      INTEGER NOT NULL,
    beds_occupied   INTEGER NOT NULL DEFAULT 0,
    beds_on_hold    INTEGER NOT NULL DEFAULT 0,
    accepting_new_guests BOOLEAN NOT NULL DEFAULT TRUE,
    snapshot_ts     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by      VARCHAR(255),
    notes           VARCHAR(500)
);

CREATE INDEX idx_bed_avail_latest ON bed_availability(shelter_id, population_type, snapshot_ts DESC);
CREATE INDEX idx_bed_avail_tenant ON bed_availability(tenant_id, snapshot_ts DESC);
```

Latest snapshot query uses `DISTINCT ON`:
```sql
SELECT DISTINCT ON (shelter_id, population_type) *
FROM bed_availability
WHERE tenant_id = :tenantId
ORDER BY shelter_id, population_type, snapshot_ts DESC;
```

**Rationale:** Append-only preserves full audit history. `DISTINCT ON` with the descending index is efficient for latest-per-group queries. No UPDATE means no row locking, no lost updates, no concurrent modification conflicts.

### D2: Derived beds_available — never stored

`beds_available = beds_total - beds_occupied - beds_on_hold`

Computed in the service layer and in SQL queries. Never persisted as a column. This prevents inconsistency between stored available count and the component values.

### D3: Availability update endpoint — PATCH not PUT

`PATCH /api/v1/shelters/{id}/availability` accepts a partial update per population type:

```json
{
  "populationType": "SINGLE_ADULT",
  "bedsTotal": 50,
  "bedsOccupied": 47,
  "bedsOnHold": 1,
  "acceptingNewGuests": true,
  "notes": "2 beds freed at 11pm shift change"
}
```

PATCH (not PUT) because:
- Coordinators update one population type at a time (3-tap mobile flow)
- The endpoint creates a new snapshot (append-only) — it doesn't replace
- Atomic, single-purpose (REQ-MCP-1)

### D4: Bed search endpoint — POST with body, not GET with query params

`POST /api/v1/queries/beds` with structured filter body:

```json
{
  "populationType": "FAMILY_WITH_CHILDREN",
  "constraints": {
    "petsAllowed": true,
    "wheelchairAccessible": true
  },
  "location": {
    "latitude": 35.7796,
    "longitude": -78.6382,
    "radiusMiles": 10
  },
  "limit": 20
}
```

POST (not GET) because:
- Filter body is complex and structured (nested constraints, location object)
- Maps cleanly to an MCP tool parameter schema
- Avoids URL length limits on deeply filtered queries

Response includes ranked results with `beds_available`, `data_age_seconds`, `data_freshness` per shelter.

**Ranking:** (1) beds_available > 0 first, (2) fewer barriers (constraint count), (3) beds_available descending. Distance ranking deferred until PostGIS is added.

### D5: Synchronous cache invalidation on update

When a coordinator submits an availability update:
1. INSERT new snapshot into PostgreSQL
2. Invalidate L1 cache (Caffeine) for this shelter
3. Invalidate L2 cache (Redis, if Standard/Full) for this shelter
4. Publish `availability.updated` event to EventBus
5. Return 200 OK

Steps 2-3 happen BEFORE step 5. The caller never gets a 200 while stale data is still in cache. This is design rule D6 from the platform foundation.

### D6: New availability module in modular monolith

```
org.fabt.availability/
  api/         AvailabilityController, BedSearchController
  domain/      BedAvailability, BedSearchRequest, BedSearchResult
  repository/  BedAvailabilityRepository
  service/     AvailabilityService, BedSearchService
```

The availability module depends on:
- `shared/` (cache, event, security, web)
- `shelter/service/` (to get shelter constraints for filtering)

ArchUnit rules will be updated to allow this cross-module dependency.

## Risks / Trade-offs

- **[Append-only table growth]** → Mitigation: Partition by month on `snapshot_ts`. Archive partitions older than 12 months. The `DISTINCT ON` query always reads only the latest snapshot.
- **[DISTINCT ON performance at scale]** → Mitigation: The composite index `(shelter_id, population_type, snapshot_ts DESC)` makes this an index-only scan. At 1000 shelters × 7 population types × 4 updates/day, that's ~28K rows/day — trivial for PostgreSQL.
- **[Cache invalidation race]** → Mitigation: Invalidate before returning 200. If cache invalidation fails, log error but still return 200 (availability is in PostgreSQL — cache will rebuild on next miss).
- **[No geo-distance ranking yet]** → Mitigation: Results ranked by beds_available and barrier count. Location-based ranking comes in a geo-search change with PostGIS.
