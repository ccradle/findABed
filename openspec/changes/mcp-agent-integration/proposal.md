## Why

Finding A Bed Tonight has a clean, MCP-ready REST API (REQ-MCP-1 through REQ-MCP-6) but no way for AI agents to interact with it. Outreach workers still navigate a visual UI to search beds, apply filters, and place holds — a workflow that could be voice-driven or natural-language-driven in high-stress field conditions (parking lots, encampments, hospital ERs).

Four scenarios justify this investment:

1. **Natural language bed search** — "I need a bed for a mom with two kids, she has a service dog, we're near Capital Blvd" is faster than navigating filters when your hands are cold and the client is losing patience.

2. **Proactive alerting** — An agent watches for bed openings matching a worker's criteria and notifies them immediately, instead of the worker polling the app.

3. **Conversational CoC reporting** — "What was our unmet demand on the coldest nights this month?" is faster than navigating the analytics dashboard and interpreting charts.

4. **Coordinator voice updates** — "Three families checked in, one single left" translates to availability snapshots without touching a screen.

The Model Context Protocol (MCP) is now an open standard under the Linux Foundation's Agentic AI Foundation. Spring AI provides a `spring-ai-starter-mcp-server-webmvc` that integrates natively with Spring Boot. The Anthropic Agent SDK provides the client runtime. No existing MCP server covers homeless services — this would be a novel open-source contribution.

## What Changes

- **MCP Server module**: New Spring Boot module (`mcp-server/`) exposing ~28 tools, resources, and prompts via Streamable HTTP transport. Delegates to existing service layer — no new business logic.

- **Reference agent**: Demo agent built with the Anthropic Agent SDK demonstrating all four scenarios end-to-end. Human-in-the-loop for DV referrals and surge activation.

- **Auth integration**: OAuth 2.1 + PKCE for human-facing agents, API key for machine-to-machine. Role-based tool visibility (outreach workers cannot access admin tools).

- **DV safety guardrails**: DV shelter addresses never exposed through MCP. Opaque referral workflow enforced with mandatory human screening. Agent conversation logs treated as protected data.

- **Documentation**: MCP server setup guide, agent scenario walkthroughs, security model documentation.

## Capabilities

### New Capabilities
- `mcp-server-tools`: MCP tool definitions wrapping FABT REST API endpoints
- `mcp-server-resources`: MCP resource providers for read-only shelter/availability data
- `mcp-server-prompts`: MCP prompt templates for common workflows (bed search, reporting)
- `mcp-agent-auth`: OAuth 2.1 + PKCE authentication for MCP clients, role-based tool access
- `mcp-dv-guardrails`: DV data protection at MCP layer (address redaction, human-in-loop enforcement)
- `agent-bed-search`: Reference agent: natural language bed search with hold
- `agent-proactive-alerting`: Reference agent: webhook-driven availability notifications
- `agent-coc-reporting`: Reference agent: conversational analytics queries
- `agent-coordinator-update`: Reference agent: voice/text-driven bed count updates

### Modified Capabilities
- `webhook-subscriptions`: Enhanced with MCP-compatible event filtering for agent subscriptions

## Impact

- **New module**: `mcp-server/` — Spring Boot application with Spring AI MCP server starter
- **New directory**: `agent-demo/` — Agent SDK reference implementation (TypeScript or Python)
- **Modified**: `backend/` — minor additions for MCP-optimized response enrichment (if needed)
- **Modified**: `docs/` — MCP server guide, agent scenarios, security model
- **Modified**: `README.md` — Phase 2 MCP section, updated architecture diagram
- **No schema changes**: MCP server consumes existing API; no database modifications
- **No breaking changes**: All Phase 1 functionality unchanged

## Risk

- **Spring AI MCP starter maturity**: v0.x — API may change. Mitigated by thin wrapper pattern (easy to update).
- **Agent SDK evolution**: Anthropic Agent SDK is pre-1.0. Mitigated by keeping agent-demo as a reference, not production code.
- **DV data leakage via agent logs**: Agent conversations may contain sensitive context. Mitigated by: (1) DV addresses never in API responses, (2) audit trail on all tool invocations, (3) guidance on log retention policies.
- **Dignity of language**: AI-generated responses about homeless individuals must use person-first language. Mitigated by prompt engineering review (Keisha Thompson persona lens).
- **Scope creep**: MCP server could grow to replicate the entire Admin UI. Mitigated by strict tool surface (~28 tools) defined in specs.
