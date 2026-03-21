## Context

The platform has real-time bed availability and reservations but no mechanism for emergency surge events. Cities activate White Flag nights (freezing temperatures), disaster responses, or seasonal overflow capacity. The asyncapi.yaml already defines `surge.activated` and `surge.deactivated` event schemas (including `affected_shelter_count` and `estimated_overflow_beds` from the asyncapi-contract-hardening change). This change implements the domain model and wires the events to real data.

## Goals / Non-Goals

**Goals:**
- Surge event lifecycle (ACTIVE → DEACTIVATED, optional auto-expiry)
- Geographic scoping via optional bounding box
- Real-time broadcast to outreach workers via EventBus
- Overflow capacity tracking (temporary beds opened during surge)
- Bed search integration (overflow beds visible, surge indicator)
- Admin surge activation UI
- Webhook delivery of surge events to subscribers

**Non-Goals:**
- Automated surge activation based on weather data (that's operational-monitoring change)
- Push notifications to mobile devices (PWA notification API is future work)
- Multi-surge overlap handling (one active surge per tenant for v1)
- Historical surge analytics (that's coc-analytics change)

## Decisions

### D1: Surge event table with lifecycle

```sql
CREATE TABLE surge_event (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenant(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    reason          VARCHAR(500) NOT NULL,
    bounding_box    JSONB,
    activated_by    UUID NOT NULL REFERENCES app_user(id),
    activated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deactivated_at  TIMESTAMPTZ,
    deactivated_by  UUID REFERENCES app_user(id),
    scheduled_end   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Status lifecycle: `ACTIVE → DEACTIVATED | EXPIRED`. Only COC_ADMIN and PLATFORM_ADMIN can activate/deactivate. One active surge per tenant (enforced at application layer).

### D2: Overflow beds on availability snapshots

Add nullable `overflow_beds` column to `bed_availability`:

```sql
ALTER TABLE bed_availability ADD COLUMN overflow_beds INTEGER DEFAULT 0;
```

During a surge, coordinators can report temporary overflow capacity (cots, mats, emergency space). `overflow_beds` is separate from `beds_total` — it represents temporary capacity that exists only during the surge. Bed search includes `overflow_beds` in results when a surge is active.

### D3: Surge activation API

```
POST   /api/v1/surge-events              Activate surge (COC_ADMIN+)
GET    /api/v1/surge-events              List surges (active + historical)
GET    /api/v1/surge-events/{id}         Surge detail
PATCH  /api/v1/surge-events/{id}/deactivate  End surge (COC_ADMIN+)
```

Activation request:
```json
{
  "reason": "White Flag — overnight low below 32°F",
  "boundingBox": { "north": 35.85, "south": 35.70, "east": -78.55, "west": -78.75 },
  "scheduledEnd": "2026-03-22T08:00:00Z"
}
```

Response includes `affected_shelter_count` and `estimated_overflow_beds` computed at activation time.

### D4: Event publishing with real data

On activation: publish `surge.activated` with payload matching asyncapi.yaml schema — including `affected_shelter_count` (count of shelters in bounding box) and `estimated_overflow_beds` (sum of current overflow_beds for those shelters, or null if none reported yet).

On deactivation: publish `surge.deactivated` with `surge_event_id`, `coc_id`, `deactivated_at`.

### D5: Bed search during active surge

When a surge is active for the querying tenant:
- Search results include `overflowBeds` per population type (from availability snapshot)
- Each result includes `surgeActive: true` indicator
- Ranking unchanged — overflow beds are additive capacity, not a replacement for beds_available

### D6: Auto-expiry for scheduled surges

If `scheduled_end` is set and the time passes, a `@Scheduled` task transitions the surge to EXPIRED and publishes `surge.deactivated`. Same pattern as reservation expiry.

### D7: Surge module in modular monolith

```
org.fabt.surge/
  api/         SurgeEventController
  domain/      SurgeEvent, SurgeEventStatus
  repository/  SurgeEventRepository
  service/     SurgeEventService, SurgeExpiryService
```

Dependencies: `shared/` (event, security, web), `shelter/service/` (shelter count in bounding box), `availability/repository/` (overflow beds sum).

## Risks / Trade-offs

- **[One surge per tenant]** → Simplification for v1. Multi-surge support can be added later with a `priority` field.
- **[Bounding box is optional]** → Null means entire CoC geography. Most White Flag events are city-wide.
- **[Overflow capacity is self-reported]** → Coordinators enter overflow manually. No verification — same trust model as regular availability updates.
- **[Scheduled end is optional]** → Some surges are open-ended (disaster response). Admin must manually deactivate.
