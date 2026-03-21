## Why

When temperatures drop below freezing or a natural disaster displaces families, cities activate emergency "White Flag" or surge events to open additional shelter capacity. Today this coordination happens via phone calls and group texts — there is no system-level mechanism to activate a surge, broadcast it to outreach workers, or track which shelters have opened overflow capacity. An outreach worker in the field has no way to know a surge was activated unless someone calls them. This change adds surge events as a first-class domain entity with lifecycle management, real-time broadcast, and overflow capacity tracking.

## What Changes

- New `surge_event` table: lifecycle (ACTIVE → DEACTIVATED → EXPIRED), bounding box (optional geographic scope), reason, activated_by, timestamps
- Surge API: `POST /api/v1/surge-events` (activate), `PATCH /api/v1/surge-events/{id}/deactivate` (end surge), `GET /api/v1/surge-events` (list active/historical), `GET /api/v1/surge-events/{id}` (detail)
- `surge.activated` and `surge.deactivated` events published to EventBus (schemas already defined in asyncapi.yaml with `affected_shelter_count` and `estimated_overflow_beds` fields from asyncapi-contract-hardening)
- Shelter overflow capacity: new optional `overflow_beds` field on availability snapshots — coordinators report temporary overflow capacity opened during a surge
- Bed search integration: during an active surge, search results include overflow capacity and a surge indicator
- Frontend: surge banner for outreach workers (real-time notification), coordinator overflow capacity form, admin surge activation/deactivation controls
- Auto-expiry: surges can have an optional `scheduled_end` timestamp; a scheduled task deactivates expired surges

## Capabilities

### New Capabilities
- `surge-lifecycle`: Surge event CRUD, activation/deactivation, auto-expiry, geographic scoping
- `surge-broadcast`: Real-time surge notification to outreach workers via EventBus
- `surge-overflow`: Shelter overflow capacity reporting during active surges

### Modified Capabilities
- `bed-availability-query`: Search results include overflow beds and surge indicator during active surge
- `shelter-availability-update`: Availability snapshots gain optional `overflow_beds` field
- `webhook-subscriptions`: surge.activated and surge.deactivated events now fire with real data (was schema-only)

## Impact

- **New database table**: `surge_event` (lifecycle, bounding box, reason, timestamps)
- **Modified table**: `bed_availability` gains `overflow_beds` column (nullable, default 0)
- **New module**: `org.fabt.surge` (api/, domain/, repository/, service/)
- **Modified modules**: availability (overflow beds in snapshots + search), shelter (surge indicator in responses)
- **New API endpoints**: `POST /api/v1/surge-events`, `PATCH /api/v1/surge-events/{id}/deactivate`, `GET /api/v1/surge-events`, `GET /api/v1/surge-events/{id}`
- **Modified API**: `POST /api/v1/queries/beds` includes overflow and surge context
- **Frontend**: Surge banner, coordinator overflow form, admin surge controls
- **Events**: surge.activated and surge.deactivated with real payload data
