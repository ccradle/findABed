## MODIFIED Requirements

### Requirement: webhook-delivery
The system SHALL deliver matching domain events to active webhook subscriptions via HTTP POST with HMAC-SHA256 signature. With the bed-availability change, `availability.updated` events now fire on real availability changes when coordinators submit availability snapshots, rather than being a schema-only definition.

#### Scenario: Matching event delivered
- **WHEN** a domain event matches a subscription's event_type and filter criteria
- **THEN** the system sends HTTP POST to the callback_url with the event payload and X-Signature header (sha256=hmac-sha256(callback_secret, body))

#### Scenario: Delivery retry on failure
- **WHEN** a webhook delivery fails (non-2xx response or timeout)
- **THEN** the system retries with exponential backoff: 1m, 5m, 30m, 2h
- **AND** after all retries fail, the subscription is marked as FAILING with last_error details

#### Scenario: Callback deregistration on 410
- **WHEN** a webhook delivery receives HTTP 410 Gone
- **THEN** the system permanently deactivates the subscription

#### Scenario: availability.updated fires on snapshot insert
- **WHEN** a coordinator submits an availability update via PATCH `/api/v1/shelters/{id}/availability` and the snapshot is successfully inserted
- **THEN** an `availability.updated` event is published to the EventBus
- **AND** all active webhook subscriptions with `event_type: "availability.updated"` whose filter criteria match the shelter's tenant and constraints receive the event via HTTP POST
- **AND** the webhook payload includes the HMAC-SHA256 signature in the X-Signature header

#### Scenario: Event includes beds_available and beds_available_previous
- **WHEN** an `availability.updated` event is delivered to a webhook subscriber
- **THEN** the event payload includes `beds_available` (current derived value), `beds_available_previous` (derived value from the prior snapshot, or null if this is the first snapshot), `shelter_id`, `tenant_id`, `population_type`, `shelter_name`, `coc_id`, `snapshot_ts`, and `schema_version`
- **AND** the subscriber can determine the direction and magnitude of change without querying the API (e.g., beds_available_previous: 5, beds_available: 2 indicates 3 beds were filled)
