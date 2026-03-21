## 1. Database Schema

- [x] 1.1 Create Flyway migration `V17__create_surge_event.sql`: surge_event table (id UUID PK, tenant_id FK, status VARCHAR(20) DEFAULT 'ACTIVE', reason VARCHAR(500), bounding_box JSONB nullable, activated_by FK to app_user, activated_at TIMESTAMPTZ, deactivated_at TIMESTAMPTZ, deactivated_by FK to app_user nullable, scheduled_end TIMESTAMPTZ nullable, created_at TIMESTAMPTZ). Index on (tenant_id, status). CHECK constraint on status IN ('ACTIVE', 'DEACTIVATED', 'EXPIRED').
- [x] 1.2 Create Flyway migration `V18__add_overflow_beds.sql`: ALTER TABLE bed_availability ADD COLUMN overflow_beds INTEGER DEFAULT 0
- [x] 1.3 Enable RLS on surge_event table (same dv_shelter pattern via shelter join — or direct tenant_id policy)

## 2. Surge Module

- [x] 2.1 Create `SurgeEvent` entity in `org.fabt.surge.domain` with all fields from V17
- [x] 2.2 Create `SurgeEventStatus` enum: ACTIVE, DEACTIVATED, EXPIRED
- [x] 2.3 Create `SurgeEventRepository` using JdbcTemplate: insert, findByIdAndTenantId, findActiveByTenantId, findByTenantId (all, ordered by activated_at DESC), updateStatus
- [x] 2.4 Create `SurgeEventService`: activate (validate no active surge, insert, compute affected_shelter_count + estimated_overflow_beds, publish event), deactivate (transition, publish event), getActive, list
- [x] 2.5 Create `SurgeEventController`: POST /api/v1/surge-events (activate, COC_ADMIN+), GET /api/v1/surge-events (list), GET /api/v1/surge-events/{id} (detail), PATCH /api/v1/surge-events/{id}/deactivate (COC_ADMIN+)
- [x] 2.6 Add @Operation annotations with semantic MCP-ready descriptions to all surge endpoints
- [x] 2.7 Create `package-info.java` for org.fabt.surge module

## 3. Auto-Expiry

- [x] 3.1 Create `SurgeExpiryService` with `@Scheduled(fixedRate = 60000)` method: query ACTIVE surges with scheduled_end < NOW(), transition each to EXPIRED, publish surge.deactivated events

## 4. Overflow Capacity

- [x] 4.1 Add `overflowBeds` field to `AvailabilityUpdateRequest` (optional, default 0)
- [x] 4.2 Add `overflow_beds` to `BedAvailability` entity
- [x] 4.3 Update `BedAvailabilityRepository` insert to include overflow_beds column
- [x] 4.4 Update `AvailabilityService.createSnapshot` to accept and persist overflowBeds

## 5. Bed Search Integration

- [x] 5.1 Add `overflowBeds` to `BedSearchResult.PopulationAvailability` record
- [x] 5.2 Add `surgeActive` boolean to `BedSearchResult`
- [x] 5.3 Update `BedSearchService.search()` to check for active surge, populate overflowBeds and surgeActive

## 6. Event Publishing

- [x] 6.1 Publish surge.activated event with payload matching asyncapi.yaml: surge_event_id, coc_id, reason, bounding_box, activated_by, activated_at, affected_shelter_count, estimated_overflow_beds
- [x] 6.2 Publish surge.deactivated event: surge_event_id, coc_id, deactivated_at

## 7. Frontend

- [x] 7.1 Add surge banner component: visible to outreach workers when a surge is active (polls GET /api/v1/surge-events for active surge, shows reason and time)
- [x] 7.2 Add overflow beds input to CoordinatorDashboard availability form (optional numeric field, visible during active surge)
- [x] 7.3 Add surge activation controls to AdminPanel: button to activate (reason + optional scheduled end), button to deactivate
- [x] 7.4 Show overflow beds in OutreachSearch results when surge is active
- [x] 7.5 Add i18n keys for surge UI (en.json + es.json)

## 8. ArchUnit + Security

- [x] 8.1 Update ArchitectureTest: add org.fabt.surge to module boundary rules
- [x] 8.2 Add /api/v1/surge-events/** to SecurityConfig (GET: any authenticated, POST/PATCH: COC_ADMIN+)

## 9. Documentation

- [x] 9.1 Update docs/schema.dbml with surge_event table + overflow_beds column
- [x] 9.2 Update docs/asyncapi.yaml: note that surge events now fire with real data (not schema-only)

## 10. Integration Tests

- [x] 10.1 Test: activate surge, verify status ACTIVE, surge.activated event published with affected_shelter_count
- [x] 10.2 Test: deactivate surge, verify status DEACTIVATED, surge.deactivated event published
- [x] 10.3 Test: activate fails with 409 when surge already active
- [x] 10.4 Test: outreach worker cannot activate surge (403)
- [x] 10.5 Test: auto-expiry transitions scheduled surge to EXPIRED
- [x] 10.6 Test: availability update with overflowBeds, verify in search results during active surge
- [x] 10.7 Test: bed search includes surgeActive flag and overflowBeds when surge is active
- [x] 10.8 Test: bed search does not include surge indicator when no active surge
