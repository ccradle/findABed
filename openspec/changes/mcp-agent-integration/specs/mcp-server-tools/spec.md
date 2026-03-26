## NEW Requirements

### Requirement: mcp-server-tools
The MCP server SHALL expose 28 tools organized in 6 categories that map 1:1 to existing FABT REST API endpoints. Each tool SHALL include a JSON Schema for its parameters, a semantic description written for AI model consumption, and role-based visibility restrictions.

#### Scenario: Agent searches for available beds
- **WHEN** an agent calls the `search_beds` tool with `{"populationType": "FAMILY_WITH_CHILDREN", "constraints": {"petsAllowed": true}, "location": {"latitude": 35.78, "longitude": -78.64, "radiusMiles": 5}}`
- **THEN** the MCP server calls `POST /api/v1/queries/beds` on the backend
- **AND** returns ranked results including `bedsAvailable`, `dataFreshness`, shelter name, and constraints
- **AND** DV shelters are excluded unless the authenticated user has dvAccess

#### Scenario: Agent creates a bed reservation
- **WHEN** an agent calls `create_reservation` with `{"shelterId": "<uuid>", "populationType": "SINGLE_ADULT"}`
- **THEN** the MCP server calls `POST /api/v1/reservations` on the backend
- **AND** returns the reservation with `id`, `status: HELD`, `expiresAt`, and `remainingSeconds`
- **AND** the tool response includes a human-readable message: "Bed held at {shelter_name} for {minutes} minutes"

#### Scenario: Agent confirms a reservation
- **WHEN** an agent calls `confirm_reservation` with `{"reservationId": "<uuid>"}`
- **THEN** the MCP server calls `PATCH /api/v1/reservations/{id}/confirm`
- **AND** returns the updated reservation with `status: CONFIRMED`

#### Scenario: Agent submits availability update
- **WHEN** an agent with COORDINATOR role calls `submit_availability` with bed counts
- **THEN** the MCP server calls `PATCH /api/v1/shelters/{id}/availability`
- **AND** the backend enforces all 9 invariants (INV-1 through INV-9)
- **AND** returns the new snapshot with derived `bedsAvailable`

#### Scenario: Agent queries analytics
- **WHEN** an agent with COC_ADMIN role calls `get_utilization` with date range
- **THEN** the MCP server calls `GET /api/v1/analytics/utilization`
- **AND** returns utilization data with `utilizationRate`, `bedsTotal`, `bedsOccupied`, `bedsAvailable` per period

#### Scenario: Unauthorized tool access is rejected
- **WHEN** an agent with OUTREACH_WORKER role calls `activate_surge`
- **THEN** the MCP server returns an error: `{"error": "forbidden", "message": "Surge activation requires COC_ADMIN role"}`
- **AND** the tool invocation is logged to the audit trail

#### Scenario: Backend error is translated to agent-friendly message
- **WHEN** the backend returns 409 Conflict (no beds available)
- **THEN** the MCP server translates to a structured error with `error`, `message`, and `context` fields
- **AND** the context includes `nearest_partial_match` or `alternative_shelters` if available
