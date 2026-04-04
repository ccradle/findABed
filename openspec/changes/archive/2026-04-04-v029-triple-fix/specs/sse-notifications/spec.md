## ADDED Requirements

### Requirement: SSE dv-referral.expired event
The `NotificationService` SHALL handle `dv-referral.expired` domain events and push them to connected coordinators who are assigned to the affected shelters.

#### Scenario: Expired tokens pushed to coordinator via SSE
- **WHEN** `expireTokens()` publishes a `dv-referral.expired` event with token IDs
- **THEN** the `NotificationService` SHALL send an SSE event with type `dv-referral.expired` to all connected COORDINATOR users for the matching tenant
- **AND** the event data SHALL include the list of expired token IDs

#### Scenario: Expired event replayed on reconnection
- **WHEN** a coordinator reconnects with a `Last-Event-ID` that precedes a `dv-referral.expired` event still in the buffer
- **THEN** the expired event SHALL be replayed to the reconnecting client

#### Scenario: Expired event filtered by tenant
- **WHEN** a `dv-referral.expired` event is published for tenant A
- **THEN** coordinators connected for tenant B SHALL NOT receive the event
