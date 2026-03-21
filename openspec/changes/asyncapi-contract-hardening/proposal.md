## Why

A principal engineering review of `docs/asyncapi.yaml` identified two gaps that must be addressed before the Full-tier Kafka consumer is built and before the `surge-mode` change begins. Gap 1 is a security prerequisite (DV_SURVIVOR events leak shelter identity on the event path even though RLS protects the query path). Gap 2 is a REQ-MCP-5 compliance issue (surge events don't carry enough context for consumers to reason about scale without a follow-up query).

## What Changes

- Add `x-security` extension to all event channel definitions documenting that `DV_SURVIVOR` events require `DV_REFERRAL` authorization role at the consumer level
- Add inline `description` annotation on the `DV_SURVIVOR` enum value in both `AvailabilityUpdatedPayload` and `ReservationPayload`
- Add Full-tier Kafka ACL requirement note to `info.description`
- Add two optional nullable fields to `SurgeActivatedPayload`: `affected_shelter_count` and `estimated_overflow_beds`
- ADR documenting rationale for both decisions

## Capabilities

### New Capabilities

_(none — this is annotation-only on an existing contract)_

### Modified Capabilities

- `webhook-subscriptions`: AsyncAPI contract hardened with security annotations and surge payload enrichment

## Impact

- **Modified file**: `docs/asyncapi.yaml` only
- **Zero breaking changes**: All existing fields, required arrays, and channel addresses preserved
- **No implementation code changes**: The `@EventListener` authorization check for DV_SURVIVOR is noted in the ADR as a consequence but belongs in a future `security-hardening` change
