## MODIFIED Requirements

### Requirement: availability-snapshot-validation
The system SHALL reject availability snapshots that violate bed count invariants. `AvailabilityService.createSnapshot()` must enforce: `beds_total >= 0`, `beds_occupied >= 0`, `beds_on_hold >= 0`, `beds_occupied <= beds_total`, `beds_occupied + beds_on_hold <= beds_total`. Violations return 422 with a clear error message.

#### Scenario: TC-1.6 — total below occupied rejected
- **WHEN** a coordinator submits `bedsTotal=5, bedsOccupied=8, bedsOnHold=0`
- **THEN** the API returns 422: "beds_occupied cannot exceed beds_total"
- **AND** no snapshot is written

#### Scenario: TC-1.7 — total below occupied+hold rejected
- **WHEN** a coordinator submits `bedsTotal=6, bedsOccupied=5, bedsOnHold=3`
- **THEN** the API returns 422: "occupied + on_hold cannot exceed total"
- **AND** no snapshot is written

#### Scenario: TC-1.8 — all zeros accepted
- **WHEN** a coordinator submits `bedsTotal=0, bedsOccupied=0, bedsOnHold=0`
- **THEN** the API returns 200 with `bedsAvailable=0`

#### Scenario: Negative values rejected
- **WHEN** a coordinator submits `bedsTotal=-1` or `bedsOccupied=-1`
- **THEN** the API returns 400 (JSR-303 `@Min(0)` validation) or 422 (service-layer invariant check)
- **NOTE** Defense in depth: `@Min(0)` on request DTO rejects at the API boundary (400); `AvailabilityService.createSnapshot()` rejects at the service layer (422) for any code path that bypasses the DTO

#### Scenario: Valid updates accepted (INV-9 holds)
- **WHEN** a coordinator submits valid values where `total >= occupied + hold`
- **THEN** the snapshot is written and `beds_available == beds_total - beds_occupied - beds_on_hold` exactly
