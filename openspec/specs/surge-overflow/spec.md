## Purpose

## ADDED Requirements

### Requirement: overflow-capacity
The system SHALL allow coordinators to report temporary overflow capacity during active surge events via the existing availability update endpoint. A new optional `overflowBeds` field on the availability update request records temporary beds (cots, mats, emergency space) that exist only during the surge.

#### Scenario: Coordinator reports overflow capacity
- **WHEN** a coordinator sends PATCH `/api/v1/shelters/{id}/availability` with `{"populationType": "SINGLE_ADULT", "bedsTotal": 50, "bedsOccupied": 45, "bedsOnHold": 0, "acceptingNewGuests": true, "overflowBeds": 20}`
- **THEN** the availability snapshot includes `overflow_beds: 20`
- **AND** the overflow capacity is visible in bed search results during an active surge

#### Scenario: Overflow beds default to 0 when not provided
- **WHEN** a coordinator sends an availability update without the `overflowBeds` field
- **THEN** `overflow_beds` defaults to 0 in the snapshot

### Requirement: Coordinator overflow input (surge-gated)
The coordinator dashboard SHALL display a "Temporary Beds" stepper input when a surge event is active. The stepper uses the existing StepperButton pattern. Pre-populated from latest snapshot. Hidden when no surge active. Value submitted in PATCH payload and self-corrects to 0 when surge ends.

### Requirement: Holds succeed at overflow-only shelters
`ReservationService` SHALL use `effectiveAvailable = bedsAvailable + overflowBeds` when checking if a hold can be created. INV-5 updated: `occupied + on_hold <= total + overflow`. Overflow preserved through hold/confirm/cancel snapshot creation.
