## 1. Database Schema

- [ ] 1.1 Create Flyway migration `V12__create_bed_availability.sql`: bed_availability table (id UUID PK, shelter_id FK, tenant_id FK, population_type VARCHAR, beds_total INTEGER, beds_occupied INTEGER DEFAULT 0, beds_on_hold INTEGER DEFAULT 0, accepting_new_guests BOOLEAN DEFAULT TRUE, snapshot_ts TIMESTAMPTZ DEFAULT NOW(), updated_by VARCHAR, notes VARCHAR(500)). Index on (shelter_id, population_type, snapshot_ts DESC). Index on (tenant_id, snapshot_ts DESC). ON CONFLICT DO NOTHING constraint on (shelter_id, population_type, snapshot_ts).
- [ ] 1.2 Enable RLS on bed_availability table: same dv_shelter policy pattern (join through shelter table) as shelter_constraints/shelter_capacity

## 2. Availability Module

- [ ] 2.1 Create `BedAvailability` entity in `org.fabt.availability.domain` with all fields from migration V12
- [ ] 2.2 Create `BedAvailabilityRepository` using Spring Data JDBC with custom queries: findLatestByTenantId (DISTINCT ON), findLatestByShelterId (DISTINCT ON), insert (append-only)
- [ ] 2.3 Create `AvailabilityService`: createSnapshot (validate, insert, invalidate cache, publish event), getLatestByShelterId, getLatestByTenantId. Derive beds_available in service layer.
- [ ] 2.4 Create `AvailabilityController`: PATCH /api/v1/shelters/{id}/availability — accepts AvailabilityUpdateRequest (populationType, bedsTotal, bedsOccupied, bedsOnHold, acceptingNewGuests, notes). @PreAuthorize COORDINATOR+. Verify coordinator is assigned to shelter (or COC_ADMIN/PLATFORM_ADMIN).
- [ ] 2.5 Add @Operation annotation with semantic MCP-ready description to PATCH endpoint
- [ ] 2.6 Create `package-info.java` for org.fabt.availability module

## 3. Bed Search

- [ ] 3.1 Create `BedSearchRequest` record: populationType (optional), constraints (optional: petsAllowed, wheelchairAccessible, sobrietyRequired), location (optional: latitude, longitude, radiusMiles), limit (default 20)
- [ ] 3.2 Create `BedSearchResult` record: shelterId, shelterName, address, phone, latitude, longitude, bedsAvailable (per population type), dataAgeSeconds, dataFreshness, constraints summary
- [ ] 3.3 Create `BedSearchService`: query shelters with availability, apply constraint filters, rank results (beds_available > 0 first, fewer barriers, beds_available DESC), compute data_age_seconds from snapshot_ts
- [ ] 3.4 Create `BedSearchController`: POST /api/v1/queries/beds — any authenticated user. Returns ranked BedSearchResult list.
- [ ] 3.5 Add @Operation annotation with semantic MCP-ready description to POST /api/v1/queries/beds
- [ ] 3.6 Add /api/v1/queries/** to SecurityConfig as authenticated (any role)

## 4. Cache + Event Integration

- [ ] 4.1 Add shelter availability to CacheNames: SHELTER_AVAILABILITY
- [ ] 4.2 Implement synchronous cache invalidation in AvailabilityService.createSnapshot: evict L1 (Caffeine) + L2 (Redis if Standard/Full) BEFORE returning 200
- [ ] 4.3 Publish availability.updated DomainEvent on every snapshot insert with payload: shelter_id, shelter_name, population_type, beds_available, beds_available_previous, snapshot_ts, data_age_seconds
- [ ] 4.4 Add cache-aside read in BedSearchService: check cache first, populate on miss from PostgreSQL

## 5. Shelter Detail Enhancement

- [ ] 5.1 Modify ShelterService.getDetail() to include latest availability per population type (beds_available, snapshot_ts, data_age_seconds, data_freshness)
- [ ] 5.2 Modify ShelterDetailResponse to include availability array
- [ ] 5.3 Modify shelter list endpoint to include availability summary (total beds_available across all population types)

## 6. Frontend Updates

- [ ] 6.1 Update OutreachSearch to use POST /api/v1/queries/beds instead of GET /api/v1/shelters
- [ ] 6.2 Show beds_available per population type in search results (green number for available, red for full)
- [ ] 6.3 Show data_freshness indicator (FRESH/AGING/STALE badge) on each result
- [ ] 6.4 Hide or deprioritize shelters with 0 beds available (show at bottom with "Currently Full" label)
- [ ] 6.5 Update CoordinatorDashboard: add availability update form (beds_occupied input per population type) alongside existing capacity stepper
- [ ] 6.6 Add "Last availability update" timestamp to coordinator shelter cards

## 7. ArchUnit + Security

- [ ] 7.1 Update ArchitectureTest: add org.fabt.availability to module boundary rules, allow availability→shelter.service dependency
- [ ] 7.2 Add /api/v1/queries/** to SecurityConfig requestMatchers (any authenticated)
- [ ] 7.3 Verify PATCH /api/v1/shelters/{id}/availability requires COORDINATOR+ with shelter assignment check

## 8. Integration Tests

- [ ] 8.1 Test: create availability snapshot, verify append-only (previous snapshot preserved)
- [ ] 8.2 Test: query beds with population type filter, verify ranked results with beds_available
- [ ] 8.3 Test: query beds with constraint filters (pets, wheelchair), verify correct shelters returned
- [ ] 8.4 Test: concurrent availability updates from same shelter (ON CONFLICT DO NOTHING)
- [ ] 8.5 Test: shelter detail includes latest availability per population type
- [ ] 8.6 Test: data_age_seconds computed from snapshot_ts, not shelter.updatedAt
- [ ] 8.7 Test: coordinator can update availability for assigned shelter, cannot for unassigned
- [ ] 8.8 Test: outreach worker can search beds but cannot update availability (403)
- [ ] 8.9 Test: DV shelters excluded from bed search for users without dvAccess
- [ ] 8.10 Test: availability.updated event published on snapshot insert (verify via test EventBus listener)
