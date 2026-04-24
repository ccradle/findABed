## ADDED Requirements

### Requirement: shelter-county-field
The system SHALL store a `county` VARCHAR(100) field on shelter records. The field is indexed. For the NC pilot, values SHALL be drawn from the 100-county NC controlled list; additional controlled lists may be added for future deployments. The active county list for a deployment is configurable via `tenant.config.active_counties: string[]`. County is shelter-admin-entered and is not derived from geocoding. When `tenant.config.active_counties` is not configured, county validation defaults to the NC 100-county list.

The county field serves a supervision geography compliance purpose: people on post-release supervision are restricted to an approved jurisdiction (county/district) by their supervision order. A bed in the wrong county triggers a supervision violation. **Supervision geography is jurisdictional, not distance-based** — the county boundary defines where a supervising officer has authority, not how far the shelter is from the client's last address.

#### Scenario: County field stored and returned
- **WHEN** a COC_ADMIN sends PATCH `/api/v1/shelters/{id}` with `county: "Johnston"`
- **THEN** the shelter record stores the county value
- **AND** GET `/api/v1/shelters/{id}` returns `county: "Johnston"` in the response

#### Scenario: County appears in bed search results
- **WHEN** an outreach worker calls GET `/api/v1/beds/search`
- **THEN** each shelter in the response includes a `county` field (null if not set)

#### Scenario: Invalid county value rejected for deployments with active_counties configured
- **WHEN** a COC_ADMIN sends PATCH `/api/v1/shelters/{id}` with `county: "NotACounty"` on a tenant with `active_counties` configured
- **THEN** the response is 400 Bad Request
- **AND** the error message lists valid county values for this deployment

#### Scenario: County validation defaults to NC 100-county list when active_counties not configured
- **WHEN** a tenant has no `active_counties` configured
- **AND** a COC_ADMIN sends PATCH `/api/v1/shelters/{id}` with `county: "NotACounty"`
- **THEN** the response is 400 Bad Request (NC 100-county list is applied as the default)
- **AND** the error message lists valid NC county values

#### Scenario: County field is null-safe for existing shelters
- **WHEN** the V79 migration is applied to a database with existing shelter records
- **THEN** all existing shelters have `county = null`
- **AND** existing search and hold workflows continue to function without error

### Requirement: county-search-filter
The bed search endpoint SHALL accept an optional `county` filter parameter. When provided, only shelters in the specified county are returned. The match is case-insensitive exact match.

#### Scenario: County filter returns only matching shelters
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?county=Johnston`
- **THEN** only shelters where `county` matches "Johnston" (case-insensitive) are returned
- **AND** shelters in Wayne, Wilson, and Nash counties are excluded

#### Scenario: County filter "johnston" matches "Johnston"
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?county=johnston`
- **THEN** shelters with `county = "Johnston"` are included in results

#### Scenario: County filter excludes null-county shelters
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?county=Johnston`
- **THEN** shelters with `county = null` are not returned
- **AND** the filter applies regardless of other filter combinations

#### Scenario: No county filter returns all counties
- **WHEN** an outreach worker calls GET `/api/v1/beds/search` without a county parameter
- **THEN** shelters from all counties (and null-county shelters) are included in results

#### Scenario: County filter combined with shelter type filter
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?county=Johnston&shelterType=REENTRY_TRANSITIONAL`
- **THEN** only REENTRY_TRANSITIONAL shelters in Johnston County are returned

#### Scenario: Three-way filter combination — county, shelter type, and acceptsFelonies
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?county=Johnston&shelterType=REENTRY_TRANSITIONAL&acceptsFelonies=true`
- **THEN** only shelters that satisfy all three conditions are returned: county = Johnston, shelter_type = REENTRY_TRANSITIONAL, and `criminal_record_policy.accepts_felonies = true`
- **AND** shelters failing any one of the three conditions are excluded from results

### Requirement: county-filter-ui
The `OutreachSearch.tsx` bed search page SHALL expose a county filter. On desktop the filter is visible in the filter bar. On mobile the county filter SHALL be in a collapsible "Advanced Filters" section, collapsed by default, to preserve the primary search flow for mobile outreach workers.

#### Scenario: Desktop shows county filter in filter bar
- **WHEN** a user opens OutreachSearch on a viewport wider than the mobile breakpoint
- **THEN** the county filter is visible in the main filter area without expansion

#### Scenario: Mobile county filter is in collapsed advanced filters
- **WHEN** a user opens OutreachSearch on a mobile viewport
- **THEN** the county filter is not visible by default
- **AND** an "Advanced Filters" toggle/button is present
- **AND** tapping it reveals the county filter alongside shelter type and accepts-felonies filters
- **AND** the toggle button has `aria-expanded="false"` when collapsed and `aria-expanded="true"` when expanded
- **AND** the toggle button has an `aria-controls` attribute referencing the advanced filters panel element
- **AND** the button activates on Enter and Space keypress in addition to tap/click

#### Scenario: County filter accessible via keyboard
- **WHEN** a user navigates to the county filter with keyboard
- **THEN** the filter control has a visible focus indicator
- **AND** the filter control has a persistent `<label>` element (not placeholder-only)
- **AND** the label is associated via `htmlFor` or wrapping
