# Pre-Change Prompt: asyncapi-contract-hardening

Paste this into Claude Code **before** running `/opsx:new asyncapi-contract-hardening`.
It gives Claude Code the full context needed to produce a tight proposal, design,
specs, and tasks without ambiguity.

---

## Context

We are doing spec-driven development using OpenSpec conventions.
Your job is to create and populate markdown specification files only.
Do not write implementation code.
You are working with a senior Java engineer named Corey Cradle.
Active repo: finding-a-bed-tonight (standalone GitHub repo, account: ccradle)
Docs repo: findABed (OpenSpec artifacts, account: ccradle)

OpenSpec workflow rules — non-negotiable:
Do NOT use planning mode (Shift+Tab Shift+Tab) — it blocks file creation.
Command sequence: /opsx:new → /opsx:ff → review artifacts →
paste standing amendments → /opsx:apply → /opsx:verify →
/opsx:sync if drift → /opsx:archive
During spec phase: create and populate markdown files ONLY.
Clear context window before each /opsx:apply session.

---

## What This Change Is

**Change name:** `asyncapi-contract-hardening`

A targeted two-item hardening of `docs/asyncapi.yaml` based on a principal
engineering review of the existing AsyncAPI 3.0 contract. No new features.
No implementation code changes. Output is a corrected `docs/asyncapi.yaml`
and a brief ADR (Architecture Decision Record) documenting the rationale.

This change should be fast: one spec, one task list, one implementation
session, verify, archive.

---

## Background: What Was Reviewed

`docs/asyncapi.yaml` is a 505-line AsyncAPI 3.0 contract covering six event
channels across three deployment tiers (Lite / Standard / Full). The overall
contract is production quality. Two specific gaps were identified in a
principal engineering review that must be addressed before:

- The **Full-tier Kafka consumer** is built (gap 1 is a security prerequisite)
- The **surge-mode** OpenSpec change begins (gap 2 must land in this contract
  first so the surge-mode spec can reference it as already resolved)

---

## Gap 1 — DV Survivor Population Type: Missing Security Annotation

### What the problem is

The `population_type` enum in both `AvailabilityUpdatedPayload` and
`ReservationPayload` includes the value `DV_SURVIVOR`. This means a downstream
consumer of the `availability.updated` or `reservation.*` Kafka topics can
infer that a particular `shelter_id` serves domestic violence survivors —
even though the REST API never exposes that shelter in any public query
(enforced by PostgreSQL Row Level Security).

The RLS protects the **query path**. It does not protect the **event path**.

In the Lite and Standard tiers, Spring ApplicationEvents and Redis pub/sub are
in-process or same-network and the consumer is the application itself. The
exposure risk is low. In the Full tier with Kafka, **topic ACLs at the broker
level are the only enforcement mechanism** — and right now the AsyncAPI spec
does not document this requirement. A future contributor wiring up a new Kafka
consumer has no signal in the contract that `DV_SURVIVOR` events require
elevated authorization.

### What the fix is

Add an AsyncAPI `x-security` extension block to the `availabilityUpdated`
and `reservationCreated` / `reservationConfirmed` / `reservationCancelled` /
`reservationExpired` channel definitions. The extension must state:

1. Events where `payload.population_type = DV_SURVIVOR` MUST only be consumed
   by services holding the `DV_REFERRAL` authorization role.
2. In the Full-tier Kafka deployment, the `availability.updated` and
   `reservation.*` topics MUST be protected by broker-level ACLs. Only
   service accounts with the `DV_REFERRAL` role may consume these topics.
3. In Lite and Standard tiers, Spring `@EventListener` methods that receive
   `DomainEvent` payloads containing `DV_SURVIVOR` MUST check
   `SecurityContext` for `DV_REFERRAL` role before processing.

Add a schema-level `description` annotation on the `DV_SURVIVOR` enum value
in both `AvailabilityUpdatedPayload` and `ReservationPayload` making the
access control requirement explicit inline — not just in the channel extension.

### Acceptance criteria

- `x-security` extension present on all six channel definitions
  (availabilityUpdated, reservationCreated, reservationConfirmed,
  reservationCancelled, reservationExpired, surgeActivated)
- `DV_SURVIVOR` enum value in both payload schemas has an inline `description`
  that references the `DV_REFERRAL` role requirement
- A note is added to the `info.description` block stating that Full-tier
  Kafka deployments MUST configure topic ACLs before enabling the Full
  Spring profile
- Existing schema structure, field names, and required arrays are unchanged —
  this is annotation-only, zero breaking changes

---

## Gap 2 — SurgeActivatedPayload: Missing Affected Shelter Count

### What the problem is

`SurgeActivatedPayload` currently carries `surge_event_id`, `coc_id`,
`reason`, `bounding_box` (optional), `activated_by`, and `activated_at`.

When a MCP agent (Phase 2) or an outreach worker app subscribes to
`surge.activated`, it receives a geographic polygon and a reason string.
To answer "how much capacity just opened up?", it must issue a follow-up
`POST /api/v1/queries/beds` call. That follow-up is acceptable — but it
adds latency and a network round-trip at exactly the moment outreach workers
most need fast answers (a White Flag cold-weather night).

The `bounding_box` field is already optional (null = entire CoC). An
`affected_shelter_count` field follows the same pattern: it is a
denormalized convenience field that saves downstream consumers a query,
not a normative source of truth.

### What the fix is

Add two optional fields to `SurgeActivatedPayload`:

**Field 1: `affected_shelter_count`**
```yaml
affected_shelter_count:
  type: integer
  minimum: 0
  nullable: true
  description: |
    Number of shelters within the surge bounding_box (or the entire CoC
    if bounding_box is null) that are currently active and participating
    in the platform. Null if the count cannot be determined at activation
    time. Provided as a convenience for consumers so they can reason
    about the scale of the surge without a follow-up query.
```

**Field 2: `estimated_overflow_beds`**
```yaml
estimated_overflow_beds:
  type: integer
  minimum: 0
  nullable: true
  description: |
    Sum of overflow_available beds across all shelters in scope at the
    moment of surge activation. Null if no shelters have reported overflow
    capacity. This is a point-in-time snapshot — actual available overflow
    beds will be reflected in subsequent availability.updated events as
    shelters update their counts.
```

Both fields are **optional** (`nullable: true`, not in `required` array).
The surge-mode implementation can populate them when the data is readily
available from the database, or omit them (null) if the count would
require an expensive query at activation time. Consumers must handle null
gracefully.

### Why both fields, not just one

`affected_shelter_count` tells a consumer the scope of the surge —
how many shelters are potentially involved. `estimated_overflow_beds`
tells a consumer the immediate magnitude — how much extra capacity
is theoretically available right now. Together they answer the two
questions an outreach worker or MCP agent asks in the first 10 seconds
of a surge: "how big is this?" and "is there actually space?"

### Acceptance criteria

- Both fields added to `SurgeActivatedPayload` as optional, nullable integers
- Neither field appears in the `required` array
- Schema descriptions explicitly state that null is valid and must be
  handled gracefully by consumers
- `SurgeDeactivatedPayload` is unchanged — the deactivation event does
  not need these fields
- Existing `required` fields and all other schemas are unchanged

---

## ADR Requirement

The `/opsx:ff` output MUST include a lightweight Architecture Decision Record
as part of the design artifact. It should cover:

- **Decision 1:** Annotate DV_SURVIVOR access control in the AsyncAPI contract
  rather than relying solely on implementation-level enforcement
  - *Context:* Spec-as-documentation must reflect security requirements;
    a future Kafka consumer wiring step with no spec annotation is a
    misconfiguration waiting to happen
  - *Decision:* x-security extension + inline enum description
  - *Consequences:* Zero breaking changes; adds implementer obligation for
    Kafka ACL configuration documented in the contract itself

- **Decision 2:** Add optional denormalized fields to SurgeActivatedPayload
  rather than requiring a follow-up query
  - *Context:* MCP-ready design requirement REQ-MCP-5 states events must be
    self-describing; the surge event failed this test for the "scale of surge"
    question
  - *Decision:* Two nullable optional fields; null is explicit and documented
  - *Consequences:* Surge-mode implementation must populate these fields when
    available; consumers must handle null; no downstream schema breaks

---

## Standing Amendments

This change is documentation-only (YAML + ADR markdown). The six standing
amendments (Webhook/Status API, Resilience4J, Caffeine L1+L2, Reactive
Programming, CI/CD, Terraform IaC) **do not apply** to this change. Do not
inject them. The only implementation artifact is `docs/asyncapi.yaml`.

---

## Constraints

- **Zero breaking changes.** Every existing field, required array, and
  channel address is preserved exactly. This is additive-only.
- **No implementation code.** The Spring `@EventListener` authorization
  check described in Gap 1 is noted in the ADR as a consequence but is NOT
  a task in this change. It belongs in a future `security-hardening` change
  or the `surge-mode` change as appropriate.
- **asyncapi.yaml only.** Do not modify `schema.dbml`, `erd.png`,
  `architecture.drawio`, or any backend Java files.
- **AsyncAPI 3.0 spec compliance.** The `x-security` extension must be
  valid AsyncAPI 3.0 YAML — use the `x-` prefix convention for extensions.

---

## Expected Output from `/opsx:ff`

1. `proposal.md` — Why this change exists, what it modifies, impact
2. `design.md` — ADR covering both decisions (see ADR Requirement above)
3. `specs/asyncapi-hardening/spec.md` — Requirements and scenarios for each gap
4. `tasks.md` — Implementation task list (expected: 4-6 tasks total)

Tasks should be:
- [ ] Add `x-security` extension to all six channel definitions
- [ ] Add `DV_SURVIVOR` inline description with role requirement to both payload schemas
- [ ] Add Full-tier Kafka ACL requirement note to `info.description`
- [ ] Add `affected_shelter_count` to `SurgeActivatedPayload`
- [ ] Add `estimated_overflow_beds` to `SurgeActivatedPayload`
- [ ] Validate AsyncAPI 3.0 compliance of the modified YAML

---

## How to Start

1. Paste this entire file into Claude Code
2. Run `/opsx:new asyncapi-contract-hardening`
3. Run `/opsx:ff` — Claude Code will draft all four artifacts
4. Review artifacts before `/opsx:apply`
5. `/opsx:apply` will be a single session editing `docs/asyncapi.yaml`
6. `/opsx:verify` — confirm both gaps are addressed, no regressions
7. `/opsx:archive`

Expected total time: 1-2 Claude Code sessions.
