## MODIFIED Requirements

### Requirement: hold-invariant-enforcement
The system SHALL ensure reservation holds never produce negative bed availability. A hold must be rejected if no beds are available. Concurrent holds on the last bed must result in exactly one success and one rejection.

#### Scenario: TC-2.6 — hold rejected when zero available
- **WHEN** `beds_available=0` and an outreach worker attempts a hold
- **THEN** the API returns 409 Conflict
- **AND** `beds_on_hold` is unchanged

#### Scenario: TC-2.2 — confirm does not change available (INV-6)
- **WHEN** a held reservation is confirmed
- **THEN** `beds_occupied` increments by 1, `beds_on_hold` decrements by 1
- **AND** `beds_available` is unchanged

#### Scenario: TC-2.3 — cancel increases available by 1 (INV-7)
- **WHEN** a held reservation is cancelled
- **THEN** `beds_on_hold` decrements by 1
- **AND** `beds_available` increases by exactly 1

#### Scenario: TC-2.4 — expiry increases available by 1 (INV-7)
- **WHEN** a held reservation expires
- **THEN** same behavior as cancel — `beds_available` increases by exactly 1

#### Scenario: TC-2.5 — hold on last bed
- **WHEN** `beds_available=1` and a hold is placed
- **THEN** `beds_on_hold=1`, `beds_available=0`
- **AND** no further holds can be placed

#### Scenario: TC-3.2 — concurrent double-hold on last bed
- **WHEN** two workers simultaneously attempt to hold the last available bed
- **THEN** exactly one succeeds (201), exactly one fails (409)
- **AND** `beds_on_hold=1`, `beds_available=0` (never -1, never hold=2)

### Requirement: coordinator-hold-protection
The system SHALL prevent coordinator availability updates from silently overwriting active reservation holds. When a coordinator submits an availability PATCH, the `beds_on_hold` value must not be reduced below the count of active HELD reservations.

#### Scenario: TC-2.7 — coordinator sends hold=0 while holds exist
- **WHEN** 1 active HELD reservation exists and coordinator submits `bedsOnHold=0`
- **THEN** the system overrides `bedsOnHold` to 1 (the active reservation count)
- **AND** `beds_available` is computed using the corrected `bedsOnHold`

#### Scenario: TC-2.8 — coordinator reduces total while holds exist
- **WHEN** `beds_total=10, beds_occupied=7, beds_on_hold=2` and coordinator submits `bedsTotal=8`
- **THEN** the API rejects with 422 because `7 + 2 > 8` (INV-5 violated)
