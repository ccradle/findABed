## Context

FABT's REST API satisfies MCP-ready design requirements REQ-MCP-1 through REQ-MCP-6 (atomic endpoints, structured errors, semantic descriptions, UUIDs, domain events, stateless). The MCP-BRIEFING.md decision record deferred MCP server construction to Phase 2 with a "thin wrapper" architecture.

Spring AI provides `spring-ai-starter-mcp-server-webmvc` with `@McpTool`, `@McpResource`, and `@McpPrompt` annotations. The MCP spec (2025-11-25) defines three transport options: stdio, Streamable HTTP, and deprecated SSE. The Anthropic Agent SDK (Python v0.1.48, TypeScript v0.2.71) provides the client runtime for building reference agents.

No existing MCP server covers homeless services. This is a novel contribution to the ecosystem.

## Goals / Non-Goals

**Goals:**
- Expose FABT's core workflows as MCP tools consumable by any MCP-compatible AI agent
- Demonstrate four agentic scenarios end-to-end with a reference agent
- Enforce DV data protection at the MCP layer (defense in depth beyond RLS)
- Provide role-based tool visibility matching FABT's existing RBAC model
- Document the security model for production deployment

**Non-Goals:**
- Replacing the React PWA — the MCP server is an additional interface, not a replacement
- Building a production-grade agent — the agent-demo is a reference implementation
- Supporting non-MCP agent protocols (LangChain tools, OpenAI function calling) — MCP is the standard
- Per-shelter MCP servers — one server serves the entire tenant
- Real-time streaming of bed availability (WebSocket) — webhook subscriptions are sufficient

## Decisions

### D1: Module structure

The MCP server is a **separate Spring Boot application** (`mcp-server/`) that shares the same Maven parent but runs as its own process. It communicates with the backend via the REST API (HTTP), not by sharing the Spring application context.

**Rationale:** Decoupled deployment. The MCP server can scale independently, be restarted without affecting the backend, and be disabled entirely in deployments that don't need agent access. The added latency of an HTTP hop is negligible (p99 <100ms for the REST API).

**Alternative rejected:** Shared Spring context (same JVM). Simpler, but couples MCP lifecycle to backend deployments and makes it harder to disable MCP in Lite tier.

### D2: Transport — Streamable HTTP

Use Streamable HTTP as the primary transport. Also support stdio for local development (Claude Desktop, Claude Code integration).

**Rationale:** Streamable HTTP is the current MCP standard (replaced deprecated SSE in March 2025). Supports both stateful sessions and stateless request/response. stdio enables developer experience without running a server.

### D3: Authentication model

```
┌──────────────┐     OAuth 2.1 + PKCE      ┌──────────────┐     API Key        ┌──────────────┐
│  AI Agent    │ ──────────────────────────→ │  MCP Server  │ ─────────────────→ │  FABT Backend│
│  (Claude,    │     Bearer token            │  (Spring AI) │     X-API-Key      │  (REST API)  │
│   custom)    │                             │              │                     │              │
└──────────────┘                             └──────────────┘                     └──────────────┘
```

- **Agent → MCP Server**: OAuth 2.1 with PKCE (human-facing) or Client Credentials (machine-to-machine). Uses FABT's existing Keycloak/Spring Security as authorization server.
- **MCP Server → Backend**: Dedicated service account API key with scoped permissions. One key per MCP server instance.
- **Role propagation**: MCP server extracts user roles from the OAuth token and passes them to the backend via JWT delegation or role headers. Backend enforces RBAC as usual.

**Why not pass-through JWT?** The MCP server needs to add context (tool invocation metadata, audit trail) that the original JWT doesn't carry. A service account with role delegation is cleaner.

### D4: Tool surface — 28 tools in 6 categories

| Category | Tools | Count | Roles |
|----------|-------|-------|-------|
| **Bed Search & Placement** | `search_beds`, `create_reservation`, `confirm_reservation`, `cancel_reservation`, `list_my_reservations` | 5 | OUTREACH_WORKER+ |
| **DV Referrals** | `request_dv_referral`, `list_my_referrals`, `list_pending_referrals`, `accept_referral`, `reject_referral` | 5 | OUTREACH_WORKER+ (request), COORDINATOR+ (accept/reject) |
| **Shelter Management** | `list_shelters`, `get_shelter_detail`, `submit_availability`, `get_shelter_availability` | 4 | ANY (read), COORDINATOR+ (write) |
| **Emergency** | `get_surge_events`, `activate_surge`, `deactivate_surge`, `get_weather_status` | 4 | ANY (read), COC_ADMIN+ (activate/deactivate) |
| **Analytics** | `get_utilization`, `get_demand_signals`, `get_capacity_trends`, `get_dv_summary`, `export_hic_csv`, `export_pit_csv` | 6 | COC_ADMIN+ |
| **Configuration** | `get_tenant_config`, `update_hold_duration`, `subscribe_to_events`, `list_subscriptions` | 4 | COC_ADMIN+ (config), ANY (subscribe) |

Total: **28 tools**. Each maps 1:1 to an existing REST endpoint. No new business logic.

### D5: MCP Resources

| URI Pattern | Description | Update Frequency |
|---|---|---|
| `shelter://{id}` | Shelter profile with constraints | On change |
| `shelter://{id}/availability` | Live bed counts by population type | On snapshot |
| `surge://active` | Currently active surge events | On activation/deactivation |
| `analytics://utilization/today` | Today's utilization summary | Hourly (pre-aggregated) |

Resources are read-only and fetched on demand by the MCP client.

### D6: MCP Prompts

| Prompt | Arguments | Description |
|---|---|---|
| `find-bed` | `--description` (natural language) | Parses intent → calls `search_beds` → presents results |
| `report-utilization` | `--period` (today/week/month) | Calls analytics → synthesizes narrative |
| `surge-check` | (none) | Gets weather + capacity → assesses surge need |
| `update-beds` | `--description` (natural language) | Parses bed count changes → calls `submit_availability` |

Prompts are user-invokable templates that the MCP client exposes as slash commands.

### D7: DV safety guardrails (defense in depth)

Layer 1 (existing): PostgreSQL RLS prevents unauthorized DV data access at the database.
Layer 2 (existing): API redacts DV shelter addresses based on tenant policy.
Layer 3 (new — MCP layer):
- `search_beds` tool description explicitly states: "DV shelters are excluded from search results unless the user has dvAccess permission."
- `request_dv_referral` tool includes a `confirmation_required: true` flag — the MCP client MUST show the user the referral details and get explicit confirmation before submitting.
- No MCP tool returns DV shelter addresses. The `get_shelter_detail` tool for DV shelters returns `"address": "Address protected — shared verbally during warm handoff"`.
- Agent audit log captures all DV-related tool invocations for compliance review.
- Tool descriptions include data sensitivity annotations (e.g., `"sensitivity": "HIGH"` for DV referral tools).

### D8: Reference agent architecture

The reference agent is built with the Anthropic Agent SDK (TypeScript) and demonstrates four scenarios:

```
agent-demo/
├── package.json
├── src/
│   ├── agent.ts                    # Main agent loop with MCP client
│   ├── scenarios/
│   │   ├── bed-search.ts           # Scenario 1: Natural language bed search
│   │   ├── proactive-alert.ts      # Scenario 2: Webhook-driven notifications
│   │   ├── coc-reporting.ts        # Scenario 3: Conversational analytics
│   │   └── coordinator-update.ts   # Scenario 4: Voice/text bed count updates
│   ├── guardrails/
│   │   ├── dv-safety.ts            # DV data protection checks
│   │   └── dignity-language.ts     # Person-first language enforcement
│   └── config/
│       └── mcp-config.json         # MCP server connection settings
├── tests/
│   └── scenarios/                  # E2E tests for each scenario
└── README.md                       # Setup, scenarios, security model
```

### D9: Deployment model

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Compose                        │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │PostgreSQL│  │  Backend  │  │MCP Server│              │
│  │   :5432  │  │   :8080  │  │   :8090  │              │
│  └──────────┘  └──────────┘  └────┬─────┘              │
│                     ▲              │                     │
│                     │  REST API    │                     │
│                     └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
         ▲                              ▲
         │ PWA (browser)                │ MCP (Streamable HTTP)
         │                              │
    Human Users                    AI Agents
```

- **Lite tier**: MCP server optional. Can be disabled entirely.
- **Standard/Full tier**: MCP server deployed alongside backend.
- **dev-start.sh**: New `--mcp` flag to start MCP server. `--agent` flag to also start agent-demo.

### D10: Audit and observability

Every MCP tool invocation is logged:
```json
{
  "timestamp": "2026-04-01T15:30:00Z",
  "tool": "search_beds",
  "user": "outreach@dev.fabt.org",
  "role": "OUTREACH_WORKER",
  "params": {"populationType": "FAMILY_WITH_CHILDREN", "petsAllowed": true},
  "result_count": 3,
  "duration_ms": 145,
  "dv_tools_accessed": false
}
```

Micrometer metrics:
- `fabt.mcp.tool.invocation.count` (tags: tool, role, status)
- `fabt.mcp.tool.invocation.duration` (timer)
- `fabt.mcp.dv.access.count` (counter for DV-related tool usage)

### D11: Interaction with SSE notifications (v0.18.0)

The proactive alerting scenario (D8, scenario 2) currently uses webhook subscriptions. SSE notifications (added in v0.18.0) provide an alternative real-time push channel. Consider:
- MCP server could subscribe to the backend's SSE endpoint for real-time event delivery to agents
- This would be more efficient than webhook polling for agent scenarios
- However, SSE requires a persistent HTTP connection from MCP server → backend, which adds operational complexity
- **Decision**: Use webhook subscriptions for Phase 1 (already supported). Evaluate SSE for Phase 2 if agents need lower-latency event delivery.

### D12: Interaction with 2FA (password-recovery-2fa change)

MCP server authenticates to the backend via **API key** (D3), not local password login. TOTP two-factor authentication (from password-recovery-2fa) applies only to local password login. Therefore:
- MCP service accounts are **exempt from TOTP** — they use API keys
- OAuth2 human-facing agents authenticate via the IdP, which handles its own MFA
- No changes to the MCP auth model are needed when 2FA is implemented

### D13: Audit trail integration (admin-user-management change)

MCP tool invocation audit (D10) should use the same `audit_events` table created by admin-user-management, with action type `MCP_TOOL_INVOKED`. This avoids two separate audit systems. The MCP server writes audit events via a REST endpoint on the backend (POST /api/v1/audit-events) rather than direct DB access, maintaining module separation.
