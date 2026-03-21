## ADDED Requirements

### Requirement: reservation-api-e2e
The E2E suite SHALL verify the full reservation lifecycle via Karate API tests: create hold, confirm arrival, cancel hold, and concurrent last-bed race condition.

#### Scenario: Full reservation lifecycle
- **WHEN** an OUTREACH_WORKER creates a reservation, then confirms it
- **THEN** status transitions HELD → CONFIRMED, bedsOccupied increments, bedsOnHold decrements

#### Scenario: Cancel reservation releases bed
- **WHEN** an OUTREACH_WORKER creates then cancels a reservation
- **THEN** status transitions HELD → CANCELLED, bedsAvailable returns to pre-hold count

#### Scenario: Cross-user confirm returns 403
- **WHEN** Worker B attempts to confirm Worker A's reservation
- **THEN** the response is 403

#### Scenario: Concurrent last-bed hold
- **WHEN** two workers simultaneously POST reservations for the last available bed
- **THEN** exactly one gets 201, the other gets 409, bedsAvailable never goes negative
