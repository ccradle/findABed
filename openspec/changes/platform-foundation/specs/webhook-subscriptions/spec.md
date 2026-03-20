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
The system SHALL deliver matching domain events to active webhook subscriptions via HTTP POST with HMAC-SHA256 signature.

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

### Requirement: self-describing-domain-events
The system SHALL emit domain events that include schema version, entity names, and sufficient context for consumers to process the event without follow-up API calls.

#### Scenario: Event includes schema version
- **WHEN** a domain event is published
- **THEN** the event includes `schema_version` (semver string, e.g., "1.0.0"), `event_type`, `tenant_id`, `timestamp`, and entity-specific context fields

#### Scenario: Availability event includes previous values
- **WHEN** an availability update event is published
- **THEN** the event includes `beds_available`, `beds_available_previous`, `shelter_name`, `coc_id`, and `population_type` so consumers know what changed without querying the API
