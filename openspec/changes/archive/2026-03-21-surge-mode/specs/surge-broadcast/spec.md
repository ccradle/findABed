## ADDED Requirements

### Requirement: surge-event-broadcast
The system SHALL publish surge events to the EventBus for real-time delivery to outreach workers and webhook subscribers. The `surge.activated` payload includes `affected_shelter_count` and `estimated_overflow_beds` as defined in asyncapi.yaml.

#### Scenario: surge.activated event published with shelter count
- **WHEN** a surge is activated
- **THEN** the `surge.activated` event includes `surge_event_id`, `coc_id`, `reason`, `activated_by`, `activated_at`, `bounding_box` (if set), `affected_shelter_count`, and `estimated_overflow_beds`

#### Scenario: surge.deactivated event published
- **WHEN** a surge is deactivated (manually or by auto-expiry)
- **THEN** the `surge.deactivated` event includes `surge_event_id`, `coc_id`, `deactivated_at`

#### Scenario: Webhook subscribers receive surge events
- **WHEN** a surge event is published and an active subscription with `event_type: "surge.activated"` exists
- **THEN** the subscriber receives the event via HTTP POST with HMAC-SHA256 signature
