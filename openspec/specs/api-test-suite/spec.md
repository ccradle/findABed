## Purpose

Karate BDD feature-file tests covering all API endpoint contracts: authentication, shelter CRUD, availability updates, bed search, and webhook subscriptions.

## Requirements

### Requirement: auth-api-tests
The E2E suite SHALL validate API authentication flows using Karate feature files: login, token refresh, API key auth, and role-based access.

#### Scenario: Login returns JWT tokens
- **WHEN** the test sends POST /api/v1/auth/login with valid credentials
- **THEN** the response is 200 with accessToken and refreshToken
- **AND** the accessToken is a valid JWT with expected claims (sub, tenantId, roles)

#### Scenario: Token refresh works
- **WHEN** the test sends POST /api/v1/auth/refresh with a valid refreshToken
- **THEN** a new accessToken is returned

#### Scenario: Unauthorized access returns 401
- **WHEN** the test sends a request without Authorization header to a protected endpoint
- **THEN** the response is 401

### Requirement: shelter-api-tests
The E2E suite SHALL validate shelter CRUD API contracts: create, read, update, list, filter, HSDS export, and coordinator assignment.

#### Scenario: Create and read shelter
- **WHEN** the test creates a shelter via POST /api/v1/shelters with full payload (name, address, constraints, capacities)
- **THEN** the response is 201 with the shelter resource
- **AND** GET /api/v1/shelters/{id} returns the same shelter with constraints and capacities

#### Scenario: Filter shelters by constraints
- **WHEN** the test sends GET /api/v1/shelters?petsAllowed=true
- **THEN** only shelters with pets_allowed=true are returned

#### Scenario: HSDS export format
- **WHEN** the test sends GET /api/v1/shelters/{id}?format=hsds
- **THEN** the response contains organization, service, location objects in HSDS 3.0 format

### Requirement: availability-api-tests
The E2E suite SHALL validate availability update and bed search API contracts.

#### Scenario: Submit availability update
- **WHEN** the test sends PATCH /api/v1/shelters/{id}/availability with a valid payload as a coordinator
- **THEN** the response is 200 with the snapshot including derived beds_available
- **AND** subsequent GET /api/v1/shelters/{id} includes the availability in the response

#### Scenario: Bed search with filters
- **WHEN** the test sends POST /api/v1/queries/beds with populationType and constraint filters
- **THEN** the response contains ranked results with availability data, dataAgeSeconds, and dataFreshness

#### Scenario: Outreach worker cannot update availability
- **WHEN** the test sends PATCH /api/v1/shelters/{id}/availability as an outreach worker
- **THEN** the response is 403

### Requirement: subscription-api-tests
The E2E suite SHALL validate webhook subscription CRUD contracts.

#### Scenario: Create and list subscriptions
- **WHEN** the test creates a subscription via POST /api/v1/subscriptions
- **THEN** the response is 201
- **AND** GET /api/v1/subscriptions includes the new subscription
