## 1. Branch Setup

- [ ] 1.1 Create branch `feature/mcp-agent-integration` from main

## 2. MCP Server — Project Scaffolding

- [ ] 2.1 Create `mcp-server/` directory with Maven `pom.xml` (Spring Boot 4.0, Spring AI MCP server starter — verify Spring AI starter compatibility with Spring Boot 4.0 before proceeding)
- [ ] 2.2 Add `McpServerApplication.java` entry point with `@SpringBootApplication`
- [ ] 2.3 Configure `application.yml`: Streamable HTTP transport on port 8090, backend URL, API key reference
- [ ] 2.4 Add stdio transport support for local dev (Claude Desktop / Claude Code)
- [ ] 2.5 Add to `docker-compose.yml` as optional service (profile: `mcp`)
- [ ] 2.6 Update `dev-start.sh` with `--mcp` flag

## 3. MCP Server — Authentication (D3)

- [ ] 3.1 Configure OAuth 2.1 resource server (validate tokens from existing authorization server)
- [ ] 3.2 Implement role extraction from OAuth token (map to FABT roles)
- [ ] 3.3 Configure service account API key for backend communication
- [ ] 3.4 Implement role-based tool visibility filter (D4 role table)
- [ ] 3.5 Implement Client Credentials grant support for machine-to-machine agents
- [ ] 3.6 Add `X-MCP-User` delegation header for audit trail passthrough

## 4. MCP Server — Bed Search & Placement Tools (5 tools)

- [ ] 4.1 Implement `search_beds` tool with JSON Schema, semantic description, and role restriction
- [ ] 4.2 Implement `create_reservation` tool with hold duration in response message
- [ ] 4.3 Implement `confirm_reservation` tool
- [ ] 4.4 Implement `cancel_reservation` tool
- [ ] 4.5 Implement `list_my_reservations` tool
- [ ] 4.6 Add error translation: 409 → agent-friendly message with `nearest_partial_match`

## 5. MCP Server — DV Referral Tools (5 tools)

- [ ] 5.1 Implement `request_dv_referral` tool with `confirmation_required: true` annotation
- [ ] 5.2 Implement `list_my_referrals` tool
- [ ] 5.3 Implement `list_pending_referrals` tool (COORDINATOR role required)
- [ ] 5.4 Implement `accept_referral` tool with coordinator assignment verification
- [ ] 5.5 Implement `reject_referral` tool
- [ ] 5.6 Add `sensitivity: HIGH` metadata to all DV tool schemas

## 6. MCP Server — Shelter Management Tools (4 tools)

- [ ] 6.1 Implement `list_shelters` tool with pagination and filter support
- [ ] 6.2 Implement `get_shelter_detail` tool with DV address redaction
- [ ] 6.3 Implement `submit_availability` tool (COORDINATOR+ role)
- [ ] 6.4 Implement `get_shelter_availability` tool

## 7. MCP Server — Emergency Tools (4 tools)

- [ ] 7.1 Implement `get_surge_events` tool
- [ ] 7.2 Implement `activate_surge` tool (COC_ADMIN+ role, human-in-loop annotation)
- [ ] 7.3 Implement `deactivate_surge` tool (COC_ADMIN+ role)
- [ ] 7.4 Implement `get_weather_status` tool

## 8. MCP Server — Analytics Tools (6 tools)

- [ ] 8.1 Implement `get_utilization` tool with date range and granularity params
- [ ] 8.2 Implement `get_demand_signals` tool
- [ ] 8.3 Implement `get_capacity_trends` tool
- [ ] 8.4 Implement `get_dv_summary` tool (dvAccess required, small-cell suppression)
- [ ] 8.5 Implement `export_hic_csv` tool
- [ ] 8.6 Implement `export_pit_csv` tool

## 9. MCP Server — Configuration & Subscription Tools (4 tools)

- [ ] 9.1 Implement `get_tenant_config` tool
- [ ] 9.2 Implement `update_hold_duration` tool (COC_ADMIN+ role)
- [ ] 9.3 Implement `subscribe_to_events` tool with filter support
- [ ] 9.4 Implement `list_subscriptions` tool

## 10. MCP Server — Resources (D5)

- [ ] 10.1 Implement `shelter://{id}` resource provider
- [ ] 10.2 Implement `shelter://{id}/availability` resource provider
- [ ] 10.3 Implement `surge://active` resource provider
- [ ] 10.4 Implement `analytics://utilization/today` resource provider

## 11. MCP Server — Prompts (D6)

- [ ] 11.1 Implement `find-bed` prompt template with `--description` argument
- [ ] 11.2 Implement `report-utilization` prompt template with `--period` argument
- [ ] 11.3 Implement `surge-check` prompt template
- [ ] 11.4 Implement `update-beds` prompt template with `--description` argument

## 12. MCP Server — DV Guardrails (D7)

- [ ] 12.1 Implement DV address redaction in all tool responses (defense in depth beyond API)
- [ ] 12.2 Add `confirmation_required` annotation to DV referral creation tool
- [ ] 12.3 Implement DV audit log: capture all DV tool invocations with `dv_tools_accessed: true`
- [ ] 12.4 Add sensitivity annotations to DV tool schemas
- [ ] 12.5 Verify DV shelters excluded from `search_beds` for non-dvAccess users (integration test)

## 13. MCP Server — Observability (D10)

- [ ] 13.1 Implement structured audit log for all tool invocations (JSON format)
- [ ] 13.2 Add Micrometer metrics: `fabt.mcp.tool.invocation.count` and `.duration`
- [ ] 13.3 Add DV access counter: `fabt.mcp.dv.access.count`
- [ ] 13.4 Add health endpoint for MCP server liveness
- [ ] 13.5 Add Grafana dashboard panel for MCP tool usage

## 14. MCP Server — Testing

- [ ] 14.1 Unit tests: tool parameter validation, role-based visibility, error translation
- [ ] 14.2 Integration tests: MCP server → backend REST API round-trip for each tool category
- [ ] 14.3 Integration test: DV guardrails (address redaction, confirmation_required, audit log)
- [ ] 14.4 Integration test: OAuth 2.1 authentication flow
- [ ] 14.5 Integration test: unauthorized tool access returns proper error
- [ ] 14.6 Performance test: MCP tool invocation overhead (target: <50ms added latency)

## 15. Reference Agent — Scaffolding

- [ ] 15.1 Create `agent-demo/` directory with `package.json` (Anthropic Agent SDK TypeScript)
- [ ] 15.2 Implement `agent.ts` main entry with MCP client configuration
- [ ] 15.3 Add `mcp-config.json` for server connection settings (URL, auth)
- [ ] 15.4 Add `README.md` with setup, scenario descriptions, security model

## 16. Reference Agent — Scenario 1: Natural Language Bed Search

- [ ] 16.1 Implement `bed-search.ts` scenario: parse natural language → `search_beds` → present results
- [ ] 16.2 Handle zero results: suggest constraint relaxation or proactive alert
- [ ] 16.3 Handle hold flow: user selects → `create_reservation` → countdown display
- [ ] 16.4 Handle hold failure (409): auto-retry search
- [ ] 16.5 Person-first language: map enum values to human-friendly text

## 17. Reference Agent — Scenario 2: Proactive Alerting

- [ ] 17.1 Implement `proactive-alert.ts` scenario: parse criteria → `subscribe_to_events`
- [ ] 17.2 Implement webhook receiver for incoming availability notifications
- [ ] 17.3 Match notification against subscription criteria → notify worker
- [ ] 17.4 Handle subscription expiry notification
- [ ] 17.5 Handle subscription cancellation

## 18. Reference Agent — Scenario 3: Conversational CoC Reporting

- [ ] 18.1 Implement `coc-reporting.ts` scenario: parse question → analytics API → narrative
- [ ] 18.2 Handle follow-up questions with conversation context
- [ ] 18.3 Handle HIC/PIT export requests
- [ ] 18.4 Handle grant narrative generation with AI-attribution disclaimer
- [ ] 18.5 DV analytics: surface small-cell suppression warnings

## 19. Reference Agent — Scenario 4: Coordinator Voice Update

- [ ] 19.1 Implement `coordinator-update.ts` scenario: parse natural language → compute deltas
- [ ] 19.2 Fetch current counts via `get_shelter_detail` before computing update
- [ ] 19.3 Present computed changes and require explicit confirmation
- [ ] 19.4 Catch invariant violations before submission (client-side pre-check)
- [ ] 19.5 Handle multi-shelter coordinators (match shelter by name)

## 20. Reference Agent — Guardrails

- [ ] 20.1 Implement `dv-safety.ts`: prevent DV data exposure in agent responses
- [ ] 20.2 Implement `dignity-language.ts`: person-first language mappings for all enum values
- [ ] 20.3 Review all agent-generated text against Keisha Thompson persona lens
- [ ] 20.4 Add agent-level audit logging (separate from MCP server audit)

## 21. Reference Agent — Testing

- [ ] 21.1 E2E test: Scenario 1 — natural language search → hold → confirm
- [ ] 21.2 E2E test: Scenario 2 — subscribe → webhook → notification
- [ ] 21.3 E2E test: Scenario 3 — utilization question → narrative response
- [ ] 21.4 E2E test: Scenario 4 — text update → confirmation → availability snapshot
- [ ] 21.5 E2E test: DV guardrails — referral confirmation required, address never shown

## 22. Documentation

- [ ] 22.1 Write `docs/mcp-server-guide.md`: setup, configuration, tool reference, security model
- [ ] 22.2 Write `agent-demo/README.md`: setup, scenarios, running demos
- [ ] 22.3 Update `README.md`: Phase 2 MCP section with architecture diagram
- [ ] 22.4 Update `MCP-BRIEFING.md` in docs repo: mark Phase 2 as active, link to implementation
- [ ] 22.5 Update architecture.drawio to include MCP server in diagram
- [ ] 22.6 Add MCP tool reference to OpenAPI/Swagger documentation

## 23. README & Demo Updates

- [ ] 23.1 Update code repo README: add MCP server to tech stack, architecture diagram, prerequisites
- [ ] 23.2 Update docs repo README: add mcp-agent-integration to active/archived changes
- [ ] 23.3 Create demo walkthrough for agent scenarios (screenshots or video)
- [ ] 23.4 Update PERSONAS.md: note Phase 2 agent capabilities for relevant personas
- [ ] 23.5 Update PRE-DEMO-CHECKLIST.md: close Phase 2 MCP items

## 24. Regression & PR

- [ ] 24.1 Backend: all existing tests pass (regression — no backend changes expected)
- [ ] 24.2 MCP server: all new tests pass
- [ ] 24.3 Agent demo: all scenario tests pass
- [ ] 24.4 Playwright: existing 114 UI tests pass (regression)
- [ ] 24.5 Karate: existing 77 API tests pass (regression)
- [ ] 24.6 Commit, push, create PR
- [ ] 24.7 Merge to main, tag release
