## NEW Requirements

### Requirement: mcp-server-resources
The MCP server SHALL expose read-only resources identified by URI patterns. Resources SHALL be fetchable on demand by MCP clients and SHALL include data freshness metadata.

#### Scenario: Client fetches shelter availability resource
- **WHEN** an MCP client requests `shelter://{id}/availability`
- **THEN** the server returns the latest bed availability snapshot for all population types at that shelter
- **AND** each entry includes `dataAgeSeconds` and `dataFreshness`

#### Scenario: Client fetches active surge resource
- **WHEN** an MCP client requests `surge://active`
- **THEN** the server returns all currently active surge events with reason, affected area, and scheduled end time
- **AND** returns an empty list if no surge is active

#### Scenario: Client fetches shelter profile resource
- **WHEN** an MCP client requests `shelter://{id}`
- **THEN** the server returns the shelter profile with constraints, address, phone, and population types served
- **AND** DV shelter addresses are redacted per tenant policy

#### Scenario: Resource URI with invalid ID returns error
- **WHEN** an MCP client requests `shelter://invalid-uuid/availability`
- **THEN** the server returns a structured error with `"error": "not_found"`

### Requirement: mcp-server-prompts
The MCP server SHALL expose reusable prompt templates that MCP clients can present as slash commands or conversational entry points.

#### Scenario: User invokes find-bed prompt
- **WHEN** a user invokes `/find-bed --description "veteran with a dog near downtown"`
- **THEN** the prompt template instructs the agent to parse population type, constraints, and location from the description
- **AND** call `search_beds` with the parsed parameters
- **AND** present results in a human-friendly format with freshness warnings

#### Scenario: User invokes report-utilization prompt
- **WHEN** a user invokes `/report-utilization --period week`
- **THEN** the prompt template instructs the agent to call `get_utilization` for the past 7 days
- **AND** synthesize a narrative summary of trends, highlights, and concerns

#### Scenario: User invokes surge-check prompt
- **WHEN** a user invokes `/surge-check`
- **THEN** the prompt template instructs the agent to call `get_weather_status` and `get_utilization` for today
- **AND** assess whether conditions warrant surge activation
- **AND** present a recommendation with supporting data (temperature, capacity, historical context)
