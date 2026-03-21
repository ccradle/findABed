## ADDED Requirements

### Requirement: reservation-ui-e2e
The E2E suite SHALL verify reservation UI interactions via Playwright: hold a bed, cancel a hold, and coordinator hold indicator.

#### Scenario: Hold a bed from search results
- **WHEN** an outreach worker clicks "Hold This Bed" on an available result
- **THEN** a countdown timer appears, bedsAvailable decrements in the UI

#### Scenario: Cancel a hold
- **WHEN** an outreach worker cancels an active hold
- **THEN** bedsAvailable increments back, API confirms no active reservations

#### Scenario: Coordinator sees active holds
- **WHEN** a coordinator expands a shelter with active holds
- **THEN** the availability form shows bedsOnHold count
