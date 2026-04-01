## MODIFIED Requirements

### Requirement: Coordinator overflow input (surge-gated)

The coordinator dashboard SHALL display a temporary beds stepper input when a surge event is active.

#### Scenario: Overflow stepper visible during active surge
- **GIVEN** a surge event is active for the coordinator's tenant
- **WHEN** the coordinator expands a shelter card on the dashboard
- **THEN** a "Temporary Beds" stepper is visible (same StepperButton pattern as Total/Occupied)
- **AND** hint text reads "Cots, mats, and emergency space during surge"
- **AND** the stepper has `data-testid` attributes: `overflow-minus-{popType}`, `overflow-value-{popType}`, `overflow-plus-{popType}`
- **AND** the minus button is disabled when overflow is 0
- **AND** all colors use design token `color.*` (dark mode safe)

#### Scenario: Overflow stepper hidden when no surge active
- **GIVEN** no surge event is active
- **WHEN** the coordinator expands a shelter card
- **THEN** no temporary beds stepper is visible
- **AND** the form submits `overflowBeds: 0` (current behavior preserved)

#### Scenario: Overflow value submitted with availability update
- **GIVEN** the coordinator sets temporary beds to 20 and saves
- **THEN** the PATCH payload includes `overflowBeds: 20`
- **AND** the bed_availability snapshot stores `overflow_beds = 20`

#### Scenario: Overflow pre-populated from latest snapshot
- **GIVEN** the coordinator previously set temporary beds to 20
- **WHEN** the coordinator opens the shelter card again during an active surge
- **THEN** the overflow stepper shows 20 (not 0)

#### Scenario: Surge ends before coordinator saves
- **GIVEN** the coordinator has the overflow stepper visible with value 20
- **WHEN** the surge auto-expires or is deactivated
- **THEN** the surge banner disappears and the overflow stepper hides
- **AND** on next save, `overflowBeds` defaults to 0 (self-correcting)

### Requirement: Holds succeed at overflow-only shelters

`ReservationService` SHALL use effective available beds (regular + overflow) when checking if a hold can be created.

#### Scenario: Hold succeeds with overflow-only capacity
- **GIVEN** a shelter has `beds_total=30, beds_occupied=30, beds_on_hold=0, overflow_beds=20`
- **WHEN** an outreach worker requests a hold
- **THEN** `effectiveAvailable = (30 - 30 - 0) + 20 = 20` — hold succeeds
- **AND** `beds_on_hold` is incremented to 1

#### Scenario: Hold rejected when no capacity at all
- **GIVEN** a shelter has `beds_total=30, beds_occupied=30, beds_on_hold=0, overflow_beds=0`
- **WHEN** an outreach worker requests a hold
- **THEN** `effectiveAvailable = 0 + 0 = 0` — hold rejected with IllegalStateException

#### Scenario: Concurrent last-overflow-bed hold
- **GIVEN** a shelter has `effectiveAvailable = 1` (0 regular + 1 overflow)
- **WHEN** two outreach workers simultaneously request a hold
- **THEN** one succeeds and one receives 409 Conflict
- **AND** `beds_on_hold` is exactly 1 after both attempts resolve

#### Scenario: Non-surge overflow still holdable
- **GIVEN** a shelter has `overflow_beds = 5` from a previous surge (stale, not yet cleared)
- **AND** no surge is currently active
- **WHEN** an outreach worker requests a hold
- **THEN** `effectiveAvailable = bedsAvailable + 5` — hold uses whatever is in the snapshot
- **NOTE** This is acceptable because overflow_beds defaults to 0 and is only set by coordinator action
