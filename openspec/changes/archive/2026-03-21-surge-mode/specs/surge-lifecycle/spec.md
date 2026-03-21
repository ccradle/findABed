## ADDED Requirements

### Requirement: surge-event-crud
The system SHALL allow COC_ADMIN and PLATFORM_ADMIN users to activate and deactivate surge events. A surge event represents an emergency activation (White Flag, disaster, seasonal overflow) that opens additional shelter capacity. Only one surge can be active per tenant at a time. Surges have an optional geographic bounding box and optional scheduled end time.

#### Scenario: Activate a surge event
- **WHEN** a COC_ADMIN sends POST `/api/v1/surge-events` with `{"reason": "White Flag — overnight low below 32°F", "scheduledEnd": "2026-03-22T08:00:00Z"}`
- **THEN** the system creates a surge event with status ACTIVE
- **AND** the response includes `id`, `status`, `activatedAt`, `affectedShelterCount`, and `estimatedOverflowBeds`
- **AND** a `surge.activated` event is published to the EventBus

#### Scenario: Activate fails when surge already active
- **WHEN** a COC_ADMIN sends POST `/api/v1/surge-events` and a surge is already active for the tenant
- **THEN** the system returns 409 Conflict with message "A surge event is already active"

#### Scenario: Deactivate a surge event
- **WHEN** a COC_ADMIN sends PATCH `/api/v1/surge-events/{id}/deactivate`
- **THEN** the system transitions the surge to DEACTIVATED with `deactivated_at` set
- **AND** a `surge.deactivated` event is published to the EventBus

#### Scenario: List active and historical surges
- **WHEN** an authenticated user sends GET `/api/v1/surge-events`
- **THEN** the response includes all surge events for the tenant, ordered by activatedAt descending

#### Scenario: Outreach worker cannot activate surge
- **WHEN** an OUTREACH_WORKER sends POST `/api/v1/surge-events`
- **THEN** the response is 403

### Requirement: surge-auto-expiry
The system SHALL automatically deactivate surge events when their `scheduled_end` timestamp passes. A scheduled task polls for expired surges every 60 seconds.

#### Scenario: Scheduled surge expires automatically
- **WHEN** a surge event's `scheduled_end` timestamp has passed
- **THEN** the system transitions it to EXPIRED and publishes `surge.deactivated`
