## 1. Database Schema

- [x] 1.1 Create Flyway migration `V14__create_reservation.sql`: reservation table (id UUID PK, shelter_id FK, tenant_id FK, population_type VARCHAR(50), user_id FK, status VARCHAR(20) DEFAULT 'HELD', expires_at TIMESTAMPTZ NOT NULL, confirmed_at TIMESTAMPTZ, cancelled_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW(), notes VARCHAR(500)). Index on (tenant_id, user_id, status). Index on (shelter_id, population_type, status). Index on (status, expires_at) for expiry polling.
- [x] 1.2 Enable RLS on reservation table: same dv_shelter policy pattern (join through shelter table)
- [x] 1.3 Add `hold_duration_minutes` column to tenant config JSONB (default 45)

## 2. Reservation Module

- [x] 2.1 Create `Reservation` entity in `org.fabt.reservation.domain` with all fields from migration V14
- [x] 2.2 Create `ReservationStatus` enum: HELD, CONFIRMED, CANCELLED, EXPIRED
- [x] 2.3 Create `ReservationRepository` using JdbcTemplate: insert, findByIdAndTenantId, findActiveByUserId, findExpired (WHERE status='HELD' AND expires_at < NOW()), updateStatus (WHERE status='HELD' optimistic guard)
- [x] 2.4 Create `ReservationService`: createReservation (validate availability, insert, create availability snapshot with beds_on_hold+1, publish event), confirmReservation (transition HELD→CONFIRMED, snapshot with beds_on_hold-1 beds_occupied+1), cancelReservation (transition HELD→CANCELLED, snapshot with beds_on_hold-1), expireReservation (transition HELD→EXPIRED, snapshot with beds_on_hold-1)
- [x] 2.5 Create `ReservationController`: POST /api/v1/reservations (create), GET /api/v1/reservations (list active), PATCH /api/v1/reservations/{id}/confirm, PATCH /api/v1/reservations/{id}/cancel. @PreAuthorize OUTREACH_WORKER+. Verify creator owns reservation (or COC_ADMIN/PLATFORM_ADMIN).
- [x] 2.6 Add @Operation annotations with semantic MCP-ready descriptions to all reservation endpoints
- [x] 2.7 Create `package-info.java` for org.fabt.reservation module

## 3. Auto-Expiry

- [x] 3.1 Create `ReservationExpiryService` with `@Scheduled(fixedRate = 30000)` method: query expired HELD reservations, transition each to EXPIRED via ReservationService.expireReservation()
- [x] 3.2 Create `RedisReservationExpiryService` (profile: standard, full): on reservation create, set Redis key `reservation:{id}` with TTL; listen for keyspace expiry notification; call ReservationService.expireReservation()
- [x] 3.3 Add Redis keyspace notification config: `notify-keyspace-events Ex` for Standard/Full profiles
- [x] 3.4 Read hold_duration_minutes from tenant config JSONB (default 45 if not set)

## 4. Availability Integration

- [x] 4.1 Modify ReservationService.createReservation to call AvailabilityService.createSnapshot with beds_on_hold incremented
- [x] 4.2 Modify ReservationService.confirmReservation to call AvailabilityService.createSnapshot with beds_on_hold decremented and beds_occupied incremented
- [x] 4.3 Modify ReservationService.cancelReservation/expireReservation to call AvailabilityService.createSnapshot with beds_on_hold decremented
- [x] 4.4 Add concurrency guard: check beds_available > 0 before creating reservation (SELECT ... FOR UPDATE or application-level check with retry)

## 5. Bed Search Integration

- [x] 5.1 Add `bedsHeld` field to BedSearchResult.PopulationAvailability record
- [x] 5.2 Populate bedsHeld from beds_on_hold in BedSearchService

## 6. Event Integration

- [x] 6.1 Publish reservation.created event on successful hold creation (shelter_id, tenant_id, population_type, user_id, reservation_id, expires_at)
- [x] 6.2 Publish reservation.confirmed event on confirmation (reservation_id, shelter_id, population_type)
- [x] 6.3 Publish reservation.cancelled event on cancellation (reservation_id, shelter_id, population_type)
- [x] 6.4 Publish reservation.expired event on auto-expiry (reservation_id, shelter_id, population_type)

## 7. Frontend Updates

- [x] 7.1 Add "Hold This Bed" button to OutreachSearch result cards (calls POST /api/v1/reservations)
- [x] 7.2 Add active reservations panel showing countdown timer (expires_at - now)
- [x] 7.3 Add confirm/cancel buttons on active reservation cards
- [x] 7.4 Show hold success feedback with countdown and shelter directions
- [x] 7.5 Show bedsHeld count in search result availability pills
- [x] 7.6 Update CoordinatorDashboard to show active holds on their shelters (read-only)
- [x] 7.7 Add i18n keys for reservation UI (en.json + es.json)

## 8. ArchUnit + Security

- [x] 8.1 Update ArchitectureTest: add org.fabt.reservation to module boundary rules, allow reservation→availability.service and reservation→shelter.service dependencies
- [x] 8.2 Add /api/v1/reservations/** to SecurityConfig (OUTREACH_WORKER, COORDINATOR, COC_ADMIN, PLATFORM_ADMIN)
- [x] 8.3 Verify reservation creator check on confirm/cancel endpoints

## 9. Integration Tests

- [x] 9.1 Test: create reservation, verify beds_on_hold incremented in availability snapshot
- [x] 9.2 Test: confirm reservation, verify beds_on_hold decremented and beds_occupied incremented
- [x] 9.3 Test: cancel reservation, verify beds_on_hold decremented
- [x] 9.4 Test: create reservation fails with 409 when beds_available = 0
- [x] 9.5 Test: confirm expired reservation returns 409
- [x] 9.6 Test: concurrent reservation for last bed — one succeeds, one gets 409
- [x] 9.7 Test: only creator can confirm/cancel (other user gets 403, COC_ADMIN can)
- [x] 9.8 Test: auto-expiry transitions HELD to EXPIRED after hold duration
- [x] 9.9 Test: reservation events published (reservation.created, confirmed, cancelled, expired)
- [x] 9.10 Test: bed search results include bedsHeld count
