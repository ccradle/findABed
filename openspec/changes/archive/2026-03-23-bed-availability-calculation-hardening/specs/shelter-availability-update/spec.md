## MODIFIED Requirements

### Requirement: ui-stepper-bounds
The coordinator dashboard UI SHALL enforce bed count bounds on all steppers. Occupied cannot exceed total minus on-hold. On-hold cannot exceed total minus occupied. The `beds_on_hold` stepper is disabled (read-only) when active reservations exist — holds are system-managed.

#### Scenario: Occupied stepper capped at total minus hold
- **WHEN** `bedsTotal=10, bedsOnHold=2` and coordinator clicks Occupied +
- **THEN** occupied cannot exceed 8

#### Scenario: On-hold stepper disabled when active reservations exist
- **WHEN** active HELD reservations exist for the population type
- **THEN** the on-hold stepper is disabled with a label showing the held count

#### Scenario: Capacity stepper syncs to availability (already fixed)
- **WHEN** coordinator changes total beds via the capacity stepper
- **THEN** the availability section's `bedsAvailable` updates immediately

### Requirement: shelter-list-badge-refresh
The coordinator dashboard SHALL refresh the shelter list summary (including "X avail" badge) after saving capacity changes, not only after availability updates.

#### Scenario: Badge updates after capacity save
- **WHEN** coordinator changes total beds and clicks Save Changes
- **THEN** the collapsed card badge shows the updated available count

### Requirement: merged-capacity-availability-ui
The coordinator dashboard SHALL present a single unified editing section for bed counts per population type. There is no separate "capacity" section — total beds, occupied, and on-hold are all edited in one place, and a single save writes one `bed_availability` snapshot.

#### Scenario: Coordinator sees unified bed editing
- **WHEN** a coordinator expands a shelter card
- **THEN** they see one section per population type with Total, Occupied, On Hold, and Available
- **AND** there is no separate "Total Beds" / capacity section

#### Scenario: Single save writes snapshot
- **WHEN** a coordinator changes total beds from 20 to 25 and occupied from 3 to 5
- **THEN** clicking Save writes one `bed_availability` snapshot with `beds_total=25, beds_occupied=5`
- **AND** `beds_available` is displayed as `25 - 5 - onHold`

### Requirement: cache-consistency
After any availability write operation, an immediate GET request must return the updated values. No stale reads from cache.

#### Scenario: TC-4.1 — GET immediately after PATCH returns updated values
- **WHEN** a coordinator PATCHes availability (occupied increases by 1)
- **THEN** an immediate GET /api/v1/shelters/{id} returns the same updated available count

#### Scenario: TC-4.3 — bed search reflects update
- **WHEN** a coordinator updates a shelter from available=0 to available=3
- **THEN** an immediate POST /api/v1/queries/beds returns the shelter with beds_available=3
