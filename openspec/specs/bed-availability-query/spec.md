## Purpose

Real-time bed availability search for outreach workers. Returns ranked shelters with availability data, constraint filtering, and data freshness indicators.

## Requirements

### Requirement: bed-search
The system SHALL provide a bed availability search endpoint at POST `/api/v1/queries/beds` that accepts a structured filter body and returns ranked shelters with real-time availability data. The request body supports filtering by `populationType`, `constraints` (petsAllowed, wheelchairAccessible, sobrietyRequired, idRequired, referralRequired), `location` (latitude, longitude, radiusMiles), and `limit` (default 20). Results are ranked: (1) shelters with `beds_available > 0` first, (2) fewer barriers (lower constraint count), (3) `beds_available` descending. Each result includes shelter info, `beds_available` per population type (derived: `beds_total - beds_occupied - beds_on_hold`), `data_age_seconds` (seconds since `snapshot_ts`), and `data_freshness` (FRESH < 7200s, AGING 7200-28800s, STALE > 28800s, UNKNOWN if no snapshot). DV shelters are excluded via row-level security unless the caller has `dvAccess` scope. Query performance target: p95 < 500ms.

#### Scenario: Query with population type filter
- **WHEN** an outreach worker sends POST `/api/v1/queries/beds` with `{"populationType": "FAMILY_WITH_CHILDREN", "limit": 20}`
- **THEN** the system returns only shelters that serve the FAMILY_WITH_CHILDREN population type
- **AND** each result includes `beds_available`, `beds_total`, `beds_occupied`, `beds_on_hold`, `accepting_new_guests`, `data_age_seconds`, and `data_freshness` for the requested population type
- **AND** results are ranked with available beds first, then by fewer barriers, then by `beds_available` descending

#### Scenario: Query with constraint filters
- **WHEN** an outreach worker sends POST `/api/v1/queries/beds` with `{"populationType": "SINGLE_ADULT", "constraints": {"petsAllowed": true, "wheelchairAccessible": true}}`
- **THEN** the system returns only shelters where `pets_allowed = true` AND `wheelchair_accessible = true` that serve SINGLE_ADULT
- **AND** shelters that do not match all specified constraints are excluded from results

#### Scenario: Empty results when no beds available
- **WHEN** an outreach worker sends POST `/api/v1/queries/beds` and no shelters in the tenant have `beds_available > 0` for the requested population type and constraints
- **THEN** the system returns 200 with an empty `results` array and `total_count: 0`
- **AND** the response does NOT return a 404

#### Scenario: Stale data flagged in response
- **WHEN** a shelter's latest availability snapshot has a `snapshot_ts` older than 8 hours (28800 seconds)
- **THEN** the result for that shelter includes `data_freshness: "STALE"` and `data_age_seconds` reflecting the actual age
- **AND** when a shelter has no availability snapshot at all, the result includes `data_freshness: "UNKNOWN"` and `data_age_seconds: null`

#### Scenario: DV shelters excluded for users without dvAccess
- **WHEN** an authenticated user WITHOUT `dvAccess` scope sends POST `/api/v1/queries/beds`
- **THEN** shelters with `dv_shelter = true` are excluded from results via row-level security
- **AND** the excluded shelters are not visible in `total_count`

### Requirement: bed-search-ranking
The system SHALL rank bed search results to surface the most actionable placements first. Shelters with available beds appear before full shelters. Among shelters with equal availability status, those with fewer barriers (fewer true constraint flags) rank higher. Among shelters with equal barrier levels, those with more `beds_available` rank higher.

#### Scenario: Shelters with available beds ranked above full shelters
- **WHEN** a bed search returns Shelter A with `beds_available: 3` and Shelter B with `beds_available: 0`
- **THEN** Shelter A appears before Shelter B in the results
- **AND** Shelter B includes `beds_available: 0` and `accepting_new_guests` status so outreach workers can see it is full

#### Scenario: Lower-barrier shelters ranked higher among equal availability
- **WHEN** a bed search returns Shelter A (beds_available: 5, sobriety_required: true, id_required: true) and Shelter B (beds_available: 5, sobriety_required: false, id_required: false)
- **THEN** Shelter B appears before Shelter A in the results because it has fewer barriers (0 vs 2)
- **AND** both shelters display their constraint details so the outreach worker can make an informed decision
