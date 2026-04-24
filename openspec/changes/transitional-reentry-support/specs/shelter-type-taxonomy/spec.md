## ADDED Requirements

### Requirement: shelter-type-field
The system SHALL store a `shelter_type` classification on each shelter record using a controlled vocabulary. The field is separate from and does not replace the `dvShelter` boolean, which remains load-bearing for RLS and DV access control. The database SHALL enforce that `dvShelter = true` implies `shelter_type = 'DV'` via a check constraint.

Accepted values: `EMERGENCY`, `DV`, `TRANSITIONAL`, `SUBSTANCE_USE_TREATMENT`, `MENTAL_HEALTH_TREATMENT`, `REENTRY_TRANSITIONAL`, `PERMANENT_SUPPORTIVE`, `RAPID_REHOUSING`.

Default for all existing shelters: `EMERGENCY`. Shelters where `dvShelter = true` are backfilled to `DV` during the V79 migration.

`shelter_type` carries no implied compliance status. It is a self-reported classification for search filtering and display only.

#### Scenario: New shelter defaults to EMERGENCY
- **WHEN** an admin creates a new shelter without specifying `shelter_type`
- **THEN** the shelter record is created with `shelter_type = 'EMERGENCY'`

#### Scenario: DV shelter gets DV type
- **WHEN** an admin creates a shelter with `dvShelter = true`
- **THEN** the shelter record is created with `shelter_type = 'DV'`
- **AND** any attempt to set `shelter_type` to a value other than `'DV'` when `dvShelter = true` is rejected with 400 Bad Request

#### Scenario: DB constraint prevents dvShelter/shelter_type divergence
- **WHEN** a database UPDATE attempts to set `dvShelter = true` on a shelter where `shelter_type != 'DV'`
- **THEN** the database rejects the update with a constraint violation
- **AND** similarly, setting `dvShelter = false` on a shelter where `shelter_type = 'DV'` is rejected

#### Scenario: Shelter type appears in search response
- **WHEN** an outreach worker calls GET `/api/v1/beds/search`
- **THEN** each shelter in the response includes a `shelterType` field with the current value
- **AND** the field is present on all shelters, not only those with non-EMERGENCY types

#### Scenario: V79 migration backfill is correct
- **WHEN** the V79 migration is applied to a database with existing shelter records
- **THEN** all shelters where `dvShelter = true` have `shelter_type = 'DV'`
- **AND** all shelters where `dvShelter = false` have `shelter_type = 'EMERGENCY'`
- **AND** the check constraint is active and enforced after migration completes

### Requirement: shelter-type-filter
The bed search endpoint SHALL accept an optional `shelterType` filter parameter. Multiple values may be specified. When the filter is provided, only shelters matching one of the specified types are returned.

#### Scenario: Filter by TRANSITIONAL returns only transitional shelters
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?shelterType=TRANSITIONAL`
- **THEN** the response contains only shelters where `shelter_type = 'TRANSITIONAL'`
- **AND** EMERGENCY and REENTRY_TRANSITIONAL shelters are excluded

#### Scenario: Filter by multiple types returns union
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?shelterType=TRANSITIONAL&shelterType=REENTRY_TRANSITIONAL`
- **THEN** the response contains shelters matching either type
- **AND** EMERGENCY shelters are excluded

#### Scenario: No shelter type filter returns all types
- **WHEN** an outreach worker calls GET `/api/v1/beds/search` without a shelterType parameter
- **THEN** all shelter types are included in results (subject to other active filters)
- **AND** DV shelters remain subject to existing DV access control regardless of shelter_type filter

#### Scenario: shelterType=DV filter returns empty results for unauthorized callers
- **WHEN** an outreach worker without DV authorization calls GET `/api/v1/beds/search?shelterType=DV`
- **THEN** the response is 200 OK with an empty results list
- **AND** no DV shelter locations or details are disclosed
- **AND** the response is not 403 (RLS filters the data; it does not block the request)

#### Scenario: Invalid shelter type value returns 400
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?shelterType=INVALID_VALUE`
- **THEN** the response is 400 Bad Request with a message listing valid shelter type values

### Requirement: shelter-type-i18n
The system SHALL provide localized display strings for all shelter type enum values in English and Spanish.

#### Scenario: Shelter type displays in current locale
- **WHEN** a user with locale `es` views search results
- **THEN** each shelter card shows the shelter type label in Spanish (e.g., `shelter.type.TRANSITIONAL` → "Vivienda de Transición")

#### Scenario: All enum values have EN and ES keys
- **WHEN** the i18n bundle is loaded
- **THEN** keys `shelter.type.EMERGENCY`, `shelter.type.DV`, `shelter.type.TRANSITIONAL`, `shelter.type.SUBSTANCE_USE_TREATMENT`, `shelter.type.MENTAL_HEALTH_TREATMENT`, `shelter.type.REENTRY_TRANSITIONAL`, `shelter.type.PERMANENT_SUPPORTIVE`, `shelter.type.RAPID_REHOUSING` are all present in both locales
