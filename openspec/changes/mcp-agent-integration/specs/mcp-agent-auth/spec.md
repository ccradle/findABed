## NEW Requirements

### Requirement: mcp-agent-auth
The MCP server SHALL authenticate incoming agent connections via OAuth 2.1 with PKCE (human-facing) or Client Credentials (machine-to-machine). The MCP server SHALL authenticate to the FABT backend using a dedicated service account API key. Role-based tool visibility SHALL restrict which tools each agent can discover and invoke.

#### Scenario: Human-facing agent authenticates via OAuth 2.1
- **WHEN** an MCP client initiates a connection with an OAuth 2.1 authorization code + PKCE
- **THEN** the MCP server validates the token against the authorization server
- **AND** extracts user roles (OUTREACH_WORKER, COORDINATOR, COC_ADMIN, PLATFORM_ADMIN)
- **AND** only advertises tools the user's role is permitted to invoke

#### Scenario: Machine-to-machine agent authenticates via Client Credentials
- **WHEN** an MCP client connects using OAuth 2.1 Client Credentials grant
- **THEN** the MCP server validates the client credentials and scopes
- **AND** maps scopes to FABT roles for tool visibility

#### Scenario: Outreach worker sees only placement tools
- **WHEN** an agent authenticated as OUTREACH_WORKER calls `tools/list`
- **THEN** the response includes: `search_beds`, `create_reservation`, `confirm_reservation`, `cancel_reservation`, `list_my_reservations`, `request_dv_referral`, `list_my_referrals`, `list_shelters`, `get_shelter_detail`, `get_surge_events`, `get_weather_status`, `subscribe_to_events`
- **AND** does NOT include: `activate_surge`, `get_utilization`, `export_hic_csv`, `update_hold_duration`

#### Scenario: COC_ADMIN sees analytics and configuration tools
- **WHEN** an agent authenticated as COC_ADMIN calls `tools/list`
- **THEN** the response includes all tools available to OUTREACH_WORKER plus: `get_utilization`, `get_demand_signals`, `get_capacity_trends`, `get_dv_summary`, `export_hic_csv`, `export_pit_csv`, `activate_surge`, `deactivate_surge`, `get_tenant_config`, `update_hold_duration`

#### Scenario: Unauthenticated agent is rejected
- **WHEN** an MCP client connects without valid credentials
- **THEN** the MCP server returns an authentication error per MCP auth spec
- **AND** no tools, resources, or prompts are advertised

#### Scenario: MCP server authenticates to backend
- **WHEN** the MCP server starts up
- **THEN** it loads its service account API key from configuration
- **AND** uses the API key in `X-API-Key` header for all backend REST API calls
- **AND** passes the authenticated user's identity via a delegation header for audit trail
