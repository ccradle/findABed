## MODIFIED Requirements

### Requirement: bed-search
The bed search response now includes `bedsHeld` per population type alongside the existing availability fields. This allows outreach workers to see contention — how many beds are currently held by other workers in transit.

#### Scenario: Search results include held bed count
- **WHEN** an outreach worker sends POST `/api/v1/queries/beds` and a shelter has 5 beds available with 2 currently held
- **THEN** the result for that shelter includes `bedsHeld: 2` alongside `bedsAvailable: 3` (which already accounts for holds via beds_on_hold)
- **AND** the outreach worker can assess contention before initiating transport
