## ADDED Requirements

### Requirement: webhook-subscription-crud
The system SHALL allow authenticated users to create, list, and delete webhook subscriptions for domain events.

#### Scenario: Create availability subscription
- **WHEN** an authenticated user sends POST `/api/v1/subscriptions` with event_type "availability.updated", filter constraints, callback_url, and callback_secret
- **THEN** the system creates the subscription, validates the callback URL is reachable (HEAD request), and returns 201 with the subscription resource including subscription_id and expires_at

#### Scenario: List subscriptions
- **WHEN** an authenticated user sends GET `/api/v1/subscriptions`
- **THEN** the system returns all active subscriptions for the user's tenant

#### Scenario: Delete subscription
- **WHEN** an authenticated user sends DELETE `/api/v1/subscriptions/{id}`
- **THEN** the system deactivates the subscription and returns 204

#### Scenario: Subscription expiry
- **WHEN** a subscription's expires_at timestamp has passed
- **THEN** the system stops delivering webhooks for that subscription
- **AND** a scheduled task marks it as EXPIRED

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

### Requirement: mcp-ready-error-responses
The system SHALL return machine-readable error responses with structured error codes and context on all API endpoints.

#### Scenario: Error response structure
- **WHEN** any API endpoint returns an error (4xx or 5xx)
- **THEN** the response body includes: `error` (snake_case code), `message` (human-readable), `status` (HTTP status code), `timestamp` (ISO 8601), and `context` (object with domain-specific details)

#### Scenario: Validation error with field details
- **WHEN** a request fails validation
- **THEN** the error response includes `error: "validation_failed"` and `context.field_errors` array with field name, rejected value, and reason for each invalid field

### Requirement: semantic-openapi-descriptions
The system SHALL provide rich, agent-readable OpenAPI descriptions on all API endpoints and parameters.

#### Scenario: OpenAPI description content
- **WHEN** the OpenAPI spec is generated
- **THEN** every endpoint has a `description` field explaining: what the endpoint does, ranking/ordering logic (if applicable), data freshness caveats, edge cases, and which constraints are applied

### Requirement: dv-event-security-annotation
The AsyncAPI contract SHALL annotate all event channels with `x-security` extension blocks documenting that events containing `population_type: DV_SURVIVOR` require `DV_REFERRAL` authorization at the consumer level. The `DV_SURVIVOR` enum value in both `AvailabilityUpdatedPayload` and `ReservationPayload` SHALL include an inline description referencing the role requirement. The `info.description` block SHALL note that Full-tier Kafka deployments MUST configure topic ACLs before enabling the Full Spring profile.

#### Scenario: x-security extension on all channels
- **WHEN** a developer reads the AsyncAPI contract
- **THEN** all six channel definitions (availabilityUpdated, reservationCreated, reservationConfirmed, reservationCancelled, reservationExpired, surgeActivated) include an `x-security` extension block
- **AND** the extension states that DV_SURVIVOR events require DV_REFERRAL authorization

#### Scenario: Kafka ACL requirement in info block
- **WHEN** a developer reads the info.description of the AsyncAPI contract
- **THEN** a clear statement indicates that Full-tier Kafka deployments MUST configure topic ACLs restricting DV_SURVIVOR event consumption to DV_REFERRAL-authorized service accounts

### Requirement: surge-payload-enrichment
The `SurgeActivatedPayload` SHALL include two new optional nullable integer fields: `affected_shelter_count` (number of shelters in scope of the surge) and `estimated_overflow_beds` (sum of overflow capacity at activation time). Neither field appears in the `required` array. Descriptions explicitly state that null is valid and consumers must handle null gracefully. `SurgeDeactivatedPayload` is unchanged.

#### Scenario: affected_shelter_count field present
- **WHEN** a surge.activated event is published
- **THEN** the payload includes `affected_shelter_count` (integer or null)

#### Scenario: estimated_overflow_beds field present
- **WHEN** a surge.activated event is published
- **THEN** the payload includes `estimated_overflow_beds` (integer or null)

### Requirement: self-describing-domain-events
The system SHALL emit domain events that include schema version, entity names, and sufficient context for consumers to process the event without follow-up API calls.

#### Scenario: Event includes schema version
- **WHEN** a domain event is published
- **THEN** the event includes `schema_version` (semver string, e.g., "1.0.0"), `event_type`, `tenant_id`, `timestamp`, and entity-specific context fields

#### Scenario: Availability event includes previous values
- **WHEN** an availability update event is published
- **THEN** the event includes `beds_available`, `beds_available_previous`, `shelter_name`, `coc_id`, and `population_type` so consumers know what changed without querying the API
