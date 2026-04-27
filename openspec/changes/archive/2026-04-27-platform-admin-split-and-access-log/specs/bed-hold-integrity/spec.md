## MODIFIED Requirements

### Requirement: manual-offline-hold-filter-chain
Spring Security's filter chain SHALL admit `POST /api/v1/shelters/*/manual-hold` for roles `COORDINATOR`, `COC_ADMIN` (PLATFORM_ADMIN deprecated; backward-compat via COC_ADMIN backfill in V87). The matcher MUST precede any broader `POST /api/v1/shelters/**` rule (Spring matchers are first-match-wins).

#### Scenario: filter admits manual hold for COORDINATOR or COC_ADMIN
- **WHEN** Spring Security's filter chain evaluates a `POST /api/v1/shelters/{id}/manual-hold` request
- **THEN** the request SHALL match the explicit matcher `POST /api/v1/shelters/*/manual-hold` admitting roles `COORDINATOR`, `COC_ADMIN`
- **AND** the request SHALL reach the controller's `isAssigned` check (filter-level admission, not filter-level rejection)

#### Scenario: PLATFORM_ADMIN-only JWT admitted during deprecation window
- **WHEN** the same matcher evaluates a request bearing only `PLATFORM_ADMIN` during the v0.53 deprecation window
- **THEN** the request is admitted because the COC_ADMIN backfill added COC_ADMIN to the same user's roles array
- **AND** the cleanup release removes the deprecated role from the matcher entirely

#### Scenario: offline hold expires through normal reservation lifecycle
- **GIVEN** an offline hold reservation with `expires_at` in the past
- **WHEN** the `ReservationExpiryService` scheduled task runs
- **THEN** the offline hold is transitioned through the normal expiry path
- **AND** `beds_on_hold` is decremented via a new availability snapshot
