## NEW Requirements

### Requirement: mcp-dv-guardrails
The MCP server SHALL enforce defense-in-depth DV data protection beyond the existing database RLS and API-layer redaction. DV shelter addresses SHALL never appear in any MCP tool response. DV referral tools SHALL require explicit human confirmation before submission. All DV-related tool invocations SHALL be logged for compliance audit.

#### Scenario: Bed search excludes DV shelters for non-DV users
- **WHEN** an agent without dvAccess calls `search_beds`
- **THEN** DV shelters are not included in results (enforced by backend RLS)
- **AND** the tool response does not indicate that DV shelters were excluded (no information leakage)

#### Scenario: DV shelter detail redacts address
- **WHEN** an agent calls `get_shelter_detail` for a DV shelter
- **AND** the agent's user has dvAccess
- **THEN** the address field returns `"Address protected — shared verbally during warm handoff"`
- **AND** the shelter phone number is included (for coordinator contact)

#### Scenario: DV referral requires human confirmation
- **WHEN** an agent calls `request_dv_referral`
- **THEN** the tool is annotated with `confirmation_required: true` in its schema
- **AND** the MCP client MUST present referral details to the user and obtain explicit confirmation before the tool executes
- **AND** the tool description states: "This action creates a referral to a DV shelter. The user must review and confirm the details before submission."

#### Scenario: DV referral acceptance requires coordinator
- **WHEN** an agent calls `accept_referral` for a DV shelter referral
- **THEN** the tool requires COORDINATOR role at the specific shelter
- **AND** the MCP server verifies coordinator assignment before forwarding to backend

#### Scenario: DV tool invocations are audit-logged
- **WHEN** any DV-related tool is invoked (`request_dv_referral`, `accept_referral`, `reject_referral`, `list_pending_referrals`, `get_dv_summary`)
- **THEN** the audit log captures: timestamp, tool name, user identity, role, parameters (excluding any PII), result status
- **AND** the log entry is tagged `dv_tools_accessed: true`

#### Scenario: Agent cannot access DV analytics without dvAccess
- **WHEN** an agent without dvAccess calls `get_dv_summary`
- **THEN** the tool returns an error: `{"error": "forbidden", "message": "DV analytics requires dvAccess permission"}`

#### Scenario: Tool descriptions include sensitivity annotations
- **WHEN** an MCP client requests the tool schema for any DV-related tool
- **THEN** the schema includes `"sensitivity": "HIGH"` metadata
- **AND** the description warns: "This tool accesses domestic violence shelter data. Exercise extreme caution with any information returned."
