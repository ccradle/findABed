# MCP Server Briefing — finding-a-bed-tonight

**Author:** Architecture / Principal Engineering  
**Date:** March 2026  
**Status:** Decision record — Phase 1 hold with MCP-ready design requirements  
**Audience:** Engineering contributors, CoC technical leads, city technology offices

---

## Table of Contents

1. [What Is MCP?](#1-what-is-mcp)
2. [How MCP Works — The Three Primitives](#2-how-mcp-works--the-three-primitives)
3. [Opportunity — What MCP Enables for This Platform](#3-opportunity--what-mcp-enables-for-this-platform)
4. [Phase 1 Recommendation — Hold](#4-phase-1-recommendation--hold)
5. [MCP-Ready Design Requirements](#5-mcp-ready-design-requirements)
6. [Immediate Additions to the Current Spec](#6-immediate-additions-to-the-current-spec)
7. [What the MCP Server Looks Like in Phase 2](#7-what-the-mcp-server-looks-like-in-phase-2)
8. [Trade-Off Summary](#8-trade-off-summary)

---

## 1. What Is MCP?

The **Model Context Protocol (MCP)** is an open standard published by Anthropic in 2024
that defines how AI models connect to external systems in a structured, predictable, and
tool-agnostic way.

Before MCP, every integration between an AI assistant and an external tool was bespoke
wiring — proprietary, fragile, and impossible to reuse across different AI models or
platforms. MCP solves this the same way USB solved peripheral connectivity: one standard
protocol that any compliant device can speak.

An **MCP server** is a lightweight process that sits alongside your application and
exposes its capabilities — data, actions, and prompt templates — to any MCP-compatible
AI agent. The agent does not need to know anything about your internal architecture. It
only needs to know what tools the MCP server exposes and what those tools do.

MCP is model-agnostic. A server built for Claude Code works equally with any other
MCP-compatible AI agent — today and as the agent ecosystem evolves.

> **One-sentence definition:** MCP is the protocol that lets an AI agent ask
> "what can I do with this system?" and get a structured, machine-readable answer.

---

## 2. How MCP Works — The Three Primitives

An MCP server exposes exactly three types of things:

### Resources
Data the AI can read. Resources are URIs that resolve to structured content.

```
shelter://raleigh/oak-city-cares/availability
surge://nc-507/active
shelter://raleigh/family-promise/constraints
```

An AI agent reads a resource the same way a developer reads a REST endpoint — but
without writing integration code. The MCP protocol handles discovery, authentication,
and schema negotiation.

### Tools
Actions the AI can take. Tools are typed function calls with defined input parameters
and return schemas.

```
find_available_beds(lat, lng, radius_miles, population_type, constraints[])
  → ShelterMatch[]

update_bed_count(shelter_id, population_type, available_count)
  → UpdateConfirmation

place_reservation(shelter_id, population_type, held_by)
  → ReservationToken  // hold_duration_minutes read from tenant config (default 90, configurable via Admin UI)

activate_surge(coc_id, bounding_box, reason)
  → SurgeEvent
```

The AI agent decides which tool to call, constructs the parameters, calls the tool,
and reasons about the result — without a human specifying the steps.

### Prompts
Reusable prompt templates the AI can invoke with parameters. These encode domain
knowledge about how to reason in this specific context.

```
triage_placement(client_description: string)
  → structured query ready for find_available_beds

summarize_unmet_demand(date_range, coc_id)
  → narrative summary for a CoC director
```

---

## 3. Opportunity — What MCP Enables for This Platform

The following scenarios are not speculative — they are direct consequences of the
platform's existing capabilities, accessed through a natural language interface
instead of a structured UI.

---

### Scenario 1 — Natural Language Bed Search

**Today (without MCP):**
An outreach worker opens the app, manually selects "Family with children," toggles
"Wheelchair accessible," sets a radius, clears "Sobriety required," and submits.
Under stress, at midnight, with a family in the car.

**With MCP + AI agent:**
The outreach worker says or types:

> *"I need a bed for a mom and two kids, she has a service dog, she's in a
> wheelchair, we're near the bus station on Capital Boulevard."*

The agent calls `triage_placement()` to extract structured constraints, calls
`find_available_beds()` with the derived parameters, and returns a ranked list of
matches — in seconds, with no form to fill out.

**Why this matters:** Cognitive load reduction at the moment of highest stress is not
a convenience feature. It is the difference between a placement happening and not
happening in the 15-minute window an outreach worker has before a client disengages.

---

### Scenario 2 — Proactive Availability Alerting

**Today (without MCP):**
An outreach worker has a client who needs a family bed with wheelchair access.
Nothing is available at 9pm. They check back manually at 11pm. By then the bed
may be gone or the client may no longer be reachable.

**With MCP + AI agent:**
The agent places a subscription via the webhook API:

> *"Notify me when a wheelchair-accessible family bed opens within 5 miles of
> the Moore Square bus station."*

When a shelter updates their availability and a match appears, the Kafka event
fires the webhook, the agent notifies the outreach worker immediately.

**Architecture note:** The Kafka `availability.updated` topic we are already building
is the foundation. The MCP layer adds the subscription surface and the reasoning
about which updates are relevant to which open cases.

---

### Scenario 3 — Conversational CoC Reporting

**Today (without MCP):**
A Wake County CoC administrator loads the analytics dashboard and runs a series of
filtered queries to answer: *"What was our unmet demand on the three coldest nights
last January? Which population type had the worst placement rate?"*

**With MCP + AI agent:**
They ask that question in plain English. The agent calls the analytics API,
synthesizes the result, and can be followed up with:

> *"Compare that to the White Flag nights in January 2025."*
> *"Which shelter had the most unoccupied family beds on those nights?"*
> *"Draft a paragraph I can include in our HUD grant application about unmet demand."*

**Why this matters:** The CoC analytics data we are building has latent value that
most coordinators will never extract because they are not data analysts. A
conversational interface over that data multiplies its impact without additional
dashboards.

---

### Scenario 4 — AI-Assisted Coordinator Updates

**Today (without MCP):**
A shelter coordinator manually logs into the app and updates bed counts.

**With MCP + AI agent (future):**
A coordinator's shift management tool — even a simple SMS thread with an AI
assistant — can update the platform automatically as guests check in and out.

> *"Three families checked in tonight, one single adult left."*

The agent calls `update_bed_count()` for each affected population type. The
coordinator never opens the app.

**Architecture note:** This requires the API-key authentication model we are already
designing. The MCP layer adds the natural language interpretation front-end.

---

## 4. Phase 1 Recommendation — Hold

**Recommendation: Do not build the MCP server in Phase 1.**

The MCP server is a thin wrapper around a clean REST API. If the REST API is designed
correctly — atomic endpoints, machine-readable errors, semantic OpenAPI descriptions —
adding the MCP server in Phase 2 is a two-day engineering task, not a two-week one.

Building it now would mean:

- **Maintaining a second surface area** before the underlying API is stable. Every
  API change during early development would require a simultaneous MCP update.
- **Designing tools for hypothetical AI agents** before any real outreach workers
  have used the platform and told us what they actually need from a natural language
  interface.
- **Consuming contributor time** on infrastructure that delivers no value until the
  platform has real data and real users.

The right trigger for Phase 2 MCP development is:

> At least one pilot city (Raleigh) has active shelter data, at least 20 outreach
> workers are using the query app, and at least one specific pain point has been
> identified where a natural language interface would change behavior.

Build the foundation right. MCP will be waiting.

---

## 5. MCP-Ready Design Requirements

The following requirements must be satisfied in Phase 1 to make Phase 2 MCP
development trivially easy. None of them add cost to Phase 1 — they are good API
design practice that happens to align perfectly with MCP compatibility.

---

### REQ-MCP-1: Atomic, single-purpose endpoints

Each API endpoint must do exactly one thing. An MCP tool maps 1:1 to an endpoint.
Endpoints that do multiple things produce MCP tools that are ambiguous, unreliable,
and difficult for an AI agent to reason about when they fail.

**Compliant:**
```
PATCH /shelters/{id}/availability          → update bed counts only
POST  /queries/beds                         → find available beds only
POST  /reservations                         → place a hold only
POST  /surge-events                         → activate surge only
```

**Non-compliant:**
```
POST /shelters/{id}/update                  → updates availability AND profile AND constraints
```

---

### REQ-MCP-2: Machine-readable, actionable error responses

MCP tools return errors to AI agents that must reason about them and decide what
to do next. Errors must be structured, typed, and include enough context for an
agent to take corrective action without human intervention.

**Compliant:**
```json
{
  "error": "no_beds_available",
  "message": "No beds matching the specified constraints are currently available.",
  "context": {
    "constraints_applied": ["FAMILY_WITH_CHILDREN", "wheelchair_accessible", "pets_allowed"],
    "nearest_partial_match": {
      "shelter_name": "Salvation Army — Raleigh",
      "missing_constraint": "pets_allowed",
      "beds_available": 2,
      "distance_miles": 1.4
    },
    "waitlist_available": true
  }
}
```

**Non-compliant:**
```json
{ "status": 404, "message": "Not found" }
```

The agent cannot reason about a generic 404. It can reason about a nearest partial
match and offer the outreach worker a meaningful alternative.

---

### REQ-MCP-3: Semantic intent in OpenAPI descriptions

The `description` field on every OpenAPI endpoint and parameter becomes the MCP tool
description. An AI agent reads this description to decide whether to call the tool
and how to construct the parameters. Write it for a reasoning model.

**Compliant:**
```yaml
/queries/beds:
  post:
    summary: Find available shelter beds matching client constraints
    description: >
      Returns a ranked list of shelters with currently available beds that match
      the specified client constraints. Ranking criteria: distance (ascending),
      then beds_available (descending), then barrier level (lower-barrier shelters
      ranked higher). The data_age_seconds field in each result indicates how
      recently the shelter updated their availability — treat values over 3600
      (1 hour) as potentially stale. DV shelters are never returned in this
      response; use the opaque-referral endpoint for DV placements.
```

**Non-compliant:**
```yaml
/queries/beds:
  post:
    summary: Query beds
    description: Returns beds.
```

---

### REQ-MCP-4: Stable, versioned resource identifiers

MCP resources are addressed by URI. Every entity in the system that an AI agent
might want to read or monitor must have a stable, predictable URI format — not
auto-incremented integers that change between environments.

**Compliant:** UUID primary keys (`shelter_id: "a3f2c1d4-..."`) with URI scheme:
```
shelter://{coc_id}/{shelter_id}
availability://{shelter_id}/{population_type}
surge://{coc_id}/{surge_event_id}
```

**Non-compliant:** Auto-incremented integer IDs that break if the database is
reseeded between environments.

All primary keys are already specified as UUIDs per RFC 4122 in the data model
spec. This requirement is satisfied by compliance with that spec.

---

### REQ-MCP-5: Structured domain events on Kafka topics

MCP agents that subscribe to real-time notifications need events that are
self-describing, typed, and carry enough context that the agent does not need
to make a second API call to understand what happened.

**Compliant `availability.updated` event:**
```json
{
  "event_type": "availability.updated",
  "schema_version": "1.0",
  "shelter_id": "a3f2c1d4-...",
  "shelter_name": "Oak City Cares",
  "coc_id": "NC-507",
  "population_type": "FAMILY_WITH_CHILDREN",
  "beds_available": 3,
  "beds_available_previous": 0,
  "snapshot_ts": "2026-01-15T23:14:00Z",
  "data_age_seconds": 0
}
```

An agent subscribed to this topic can immediately determine: availability improved,
a specific population type, at a specific shelter, right now. No follow-up call needed.

---

### REQ-MCP-6: No implicit state in the query path

MCP tools are stateless function calls. The query endpoint must not rely on
session state, cookies, or server-side context that would not be available to
an AI agent calling the tool in isolation. Every query must be fully self-contained.

This is already satisfied by the reactive, stateless WebFlux architecture in the
current spec. This requirement documents the constraint explicitly so it is not
accidentally violated during implementation.

---

## 6. Immediate Additions to the Current Spec

Two additions should be made to the current spec now that add minimal Phase 1
cost but significantly increase MCP leverage in Phase 2.

---

### Addition 1 — Webhook Subscription Endpoint

Add `POST /subscriptions` to the API contract spec. This exposes the Kafka
`availability.updated` topic as a webhook subscription surface.

```
POST /subscriptions
Authorization: Bearer {api_key}

{
  "event_type": "availability.updated",
  "filter": {
    "population_types": ["FAMILY_WITH_CHILDREN"],
    "bounding_box": { ... },
    "min_beds_available": 1
  },
  "callback_url": "https://agent.example.com/notify",
  "callback_secret": "sha256-hmac-secret"
}

→ 201 Created
{
  "subscription_id": "uuid",
  "status": "ACTIVE",
  "expires_at": "2027-01-01T00:00:00Z"
}
```

**Why now:** The Kafka topic is already being built. Exposing webhook subscriptions
over that topic is a small bridge adapter using the outbox pattern already specified
in the standing amendments. Deferring this to Phase 2 means retrofitting it into a
stable system — always harder than designing for it upfront.

**MCP payoff:** An AI agent that can subscribe to availability changes can implement
Scenario 2 (proactive alerting) without polling. Polling is expensive, fragile, and
results in stale matches. Push notification is the correct model for time-sensitive
placement.

---

### Addition 2 — `data_age_seconds` as a First-Class Field

The `data_age_seconds` field must appear in every availability query response — not
as an optional field, not buried in metadata, but at the top level of every shelter
result.

```json
{
  "shelter_name": "Oak City Cares",
  "beds_available": 2,
  "data_age_seconds": 4320,
  "data_freshness": "STALE",
  ...
}
```

Where `data_freshness` is a derived enum:
- `FRESH` — updated within the last 2 hours
- `AGING` — updated 2-8 hours ago
- `STALE` — updated more than 8 hours ago
- `UNKNOWN` — no snapshot on record

**Why now:** An AI agent acting on stale availability data causes real harm — an
outreach worker drives across the city to a shelter that has been full since 9pm.
The agent must be able to reason about data freshness and either warn the user or
deprioritize stale results. This field must be in the response contract from Day 1,
not added as an afterthought.

---

## 7. What the MCP Server Looks Like in Phase 2

When the Phase 1 API is stable and the Raleigh pilot has real users, building the
MCP server is a focused, bounded task. The server is a standalone process — not a
modification to the core application.

**Estimated scope:** 2–4 weeks for one contributor, given a clean Phase 1 API.

**Folder structure:**
```
finding-a-bed-tonight/
  mcp-server/
    src/
      tools/
        FindAvailableBedsTools.java
        UpdateBedCountTool.java
        PlaceReservationTool.java
        ActivateSurgeTool.java
        SubscribeAvailabilityTool.java
      resources/
        ShelterResourceProvider.java
        SurgeEventResourceProvider.java
      prompts/
        TriagePlacementPrompt.java
        SummarizeUnmetDemandPrompt.java
      McpServerApplication.java
    Dockerfile
    mcp-server-spec.md
```

**Security model for Phase 2 MCP server:**
- MCP server authenticates to the REST API using a dedicated service account API key
- MCP client (AI agent host) authenticates to the MCP server using OAuth2 client
  credentials
- DV shelter data access is not exposed through MCP under any circumstances —
  the opaque-referral endpoint requires a human-in-the-loop confirmation step
  that cannot be delegated to an AI agent

---

## 8. Trade-Off Summary

| Dimension | Build MCP Now (Phase 1) | MCP-Ready Design + Hold | Skip MCP Entirely |
|---|---|---|---|
| **Phase 1 engineering cost** | High — second surface to maintain during unstable API | Low — good API hygiene only | Zero |
| **Phase 2 MCP cost** | None (already built) | Low — 2-4 week bounded task | High — retrofit into stable system |
| **Risk to Phase 1 delivery** | High — scope creep before pilot data | None | None |
| **Natural language triage** | Possible but untested | Enabled in Phase 2 | Never |
| **Proactive alerting** | Possible but untested | Enabled in Phase 2 via webhooks | Never |
| **Conversational CoC reporting** | Possible but untested | Enabled in Phase 2 | Never |
| **Vendor / model lock-in** | None (MCP is open standard) | None | Not applicable |
| **Maintenance overhead** | Permanent second surface | Deferred until justified | None |
| **Alignment with open-source contributor model** | Risky — complex for new contributors | Good — core platform remains approachable | Good |

**Decision: MCP-Ready Design + Hold for Phase 2.**

The platform earns the right to AI-native features by first being reliable, accurate,
and trusted by real outreach workers and shelter operators. Build the foundation right.
The natural language interface is a multiplier on a working system — it is not a
substitute for one.

---

*This briefing is a living document. Revisit after the Raleigh pilot's 90-day
milestone review to determine whether the Phase 2 trigger conditions have been met.*

*Finding a Bed Tonight — Apache 2.0 Open Source*  
*github.com/ccradle/finding-a-bed-tonight*
