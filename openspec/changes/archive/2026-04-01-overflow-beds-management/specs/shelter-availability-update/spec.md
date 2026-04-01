## MODIFIED Requirements

### Requirement: Pre-populate overflow from latest snapshot

The coordinator dashboard availability form SHALL pre-populate the overflow beds value from the latest availability snapshot.

#### Scenario: Overflow value retained across form sessions
- **GIVEN** a coordinator set overflow to 20 in a previous update
- **WHEN** the coordinator reopens the shelter card during active surge
- **THEN** the overflow stepper shows 20 (read from API response `overflowBeds` field)

#### Scenario: No previous snapshot
- **GIVEN** no availability snapshot exists for a population type
- **THEN** the overflow field defaults to 0

### Requirement: Availability math invariants preserved with overflow

Overflow beds SHALL NOT alter the core invariant calculations. `beds_available = beds_total - beds_occupied - beds_on_hold` remains unchanged. Overflow is additive at the consumption layer only.

#### Scenario: INV-1 preserved — beds_available derivation unchanged
- **GIVEN** `beds_total=30, beds_occupied=20, beds_on_hold=2, overflow_beds=15`
- **THEN** `beds_available = 30 - 20 - 2 = 8` (domain derivation, excludes overflow)
- **AND** `effective_available = 8 + 15 = 23` (computed in service/UI layer)

#### Scenario: INV-5 preserved — occupied + on_hold <= total
- **GIVEN** `beds_total=30, beds_occupied=28, beds_on_hold=2, overflow_beds=20`
- **THEN** INV-5 check: `28 + 2 = 30 <= 30` — valid
- **AND** overflow does NOT participate in this invariant (overflow capacity is independent)

#### Scenario: beds_total is NOT inflated by overflow
- **GIVEN** a shelter with 30 permanent beds reports 20 overflow during surge
- **THEN** `beds_total` remains 30 in the snapshot (permanent capacity)
- **AND** `overflow_beds` is 20 (temporary capacity)
- **AND** HIC export sees `beds_total=30` and `overflow_beds=20` separately
