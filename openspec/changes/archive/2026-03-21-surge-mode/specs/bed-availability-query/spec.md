## MODIFIED Requirements

### Requirement: bed-search
During an active surge event, bed search results include overflow capacity and a surge indicator so outreach workers can see temporary emergency beds.

#### Scenario: Search results include overflow beds during active surge
- **WHEN** an outreach worker sends POST `/api/v1/queries/beds` and a surge is active for the tenant
- **THEN** each result includes `overflowBeds` per population type and `surgeActive: true`
- **AND** overflow beds are shown as additional capacity beyond `bedsAvailable`

#### Scenario: No surge indicator when no active surge
- **WHEN** an outreach worker sends POST `/api/v1/queries/beds` and no surge is active
- **THEN** results do not include `surgeActive` or show `surgeActive: false`
- **AND** `overflowBeds` is 0 or omitted
