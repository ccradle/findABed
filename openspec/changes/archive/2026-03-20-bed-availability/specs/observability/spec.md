## MODIFIED Requirements

### Requirement: data-age-tracking
The system SHALL track and expose the age of data to callers so that stale data is identifiable. Applies to shelter list, shelter detail, and bed availability query endpoints -- these are the responses where data freshness matters for outreach workers making real-time decisions. When availability snapshots exist, `data_age_seconds` is computed from `bed_availability.snapshot_ts` (the most recent snapshot for the shelter or population type), not from `shelter.updated_at`. The `shelter.updated_at` timestamp reflects profile edits (name, address, constraints), while `snapshot_ts` reflects the actual availability data freshness that outreach workers depend on.

#### Scenario: API response includes data age
- **WHEN** a GET `/api/v1/shelters`, GET `/api/v1/shelters/{id}`, or POST `/api/v1/queries/beds` response is returned
- **THEN** the response includes a `data_age_seconds` field calculated from the most recent `snapshot_ts` in the `bed_availability` table for the relevant shelter(s)
- **AND** if no availability snapshot exists for a shelter, `data_age_seconds` falls back to `shelter.updated_at`

#### Scenario: Data age in cache responses
- **WHEN** a shelter or availability response is served from cache
- **THEN** `data_age_seconds` reflects the time since the original `snapshot_ts`, not the time since the data was cached
- **AND** the value is recomputed on each response (current time minus snapshot_ts) so it increases even while the data is cached

#### Scenario: Data freshness enum included
- **WHEN** a GET `/api/v1/shelters`, GET `/api/v1/shelters/{id}`, or POST `/api/v1/queries/beds` response is returned
- **THEN** the response includes a `data_freshness` field derived from `data_age_seconds`: FRESH (< 7200s), AGING (7200-28800s), STALE (> 28800s), UNKNOWN (no snapshot and no updated_at)

#### Scenario: data_age_seconds from availability snapshot
- **WHEN** Shelter A has a profile `updated_at` of 3 hours ago and a `bed_availability.snapshot_ts` of 30 minutes ago
- **THEN** the `data_age_seconds` for Shelter A is approximately 1800 (30 minutes), not 10800 (3 hours)
- **AND** the `data_freshness` is FRESH because 1800 < 7200
- **AND** when Shelter B has a profile `updated_at` of 1 hour ago but no availability snapshots, `data_age_seconds` is approximately 3600 (1 hour) computed from `updated_at`
