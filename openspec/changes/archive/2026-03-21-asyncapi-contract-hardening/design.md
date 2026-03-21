## Context

`docs/asyncapi.yaml` is a 505-line AsyncAPI 3.0 contract covering event channels across three deployment tiers. The contract is production quality but two specific gaps were identified in a principal engineering review. Both must be addressed before Full-tier Kafka consumers are wired and before the `surge-mode` OpenSpec change begins.

## Goals / Non-Goals

**Goals:**
- Annotate DV_SURVIVOR access control requirements in the contract itself
- Enrich SurgeActivatedPayload with optional convenience fields for consumer reasoning
- Document both decisions as lightweight ADRs

**Non-Goals:**
- Implementation code changes (no Java, no Spring changes)
- Kafka ACL configuration (that's infrastructure, not contract)
- Breaking changes to existing schemas

## Decisions

### D1: Annotate DV_SURVIVOR access control in the AsyncAPI contract

**Context:** The `population_type` enum in `AvailabilityUpdatedPayload` and `ReservationPayload` includes `DV_SURVIVOR`. A downstream Kafka consumer can infer that a `shelter_id` serves DV survivors — even though the REST API hides this via PostgreSQL RLS. The RLS protects the query path; the event path is unprotected. In Lite/Standard tiers the risk is low (in-process events). In Full tier with Kafka, topic ACLs are the only enforcement and the contract doesn't document this requirement.

**Decision:** Add `x-security` extension blocks to all six channel definitions. Add inline `description` on the `DV_SURVIVOR` enum value in both payload schemas. Add a Kafka ACL requirement note to `info.description`.

**Consequences:**
- Zero breaking changes — additive annotations only
- Future Kafka consumer implementers have explicit guidance in the contract
- The `@EventListener` authorization check in Spring is a follow-on implementation task (not in this change)
- Kafka ACL configuration is an infrastructure task documented but not implemented here

### D2: Add optional denormalized fields to SurgeActivatedPayload

**Context:** REQ-MCP-5 states events must be self-describing. The current `SurgeActivatedPayload` carries geographic bounds and a reason string, but answering "how much capacity just opened up?" requires a follow-up `POST /api/v1/queries/beds`. This adds latency at exactly the moment outreach workers need fast answers.

**Decision:** Add two optional nullable fields: `affected_shelter_count` (integer, number of shelters in scope) and `estimated_overflow_beds` (integer, sum of overflow capacity at activation time). Both are nullable — null is valid when the count can't be determined at activation time.

**Consequences:**
- `surge-mode` implementation must populate these fields when available
- Consumers must handle null gracefully
- No downstream schema breaks — both fields are optional and not in the `required` array
- `SurgeDeactivatedPayload` is unchanged
