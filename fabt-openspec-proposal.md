# Proposal: hsds-bed-availability-extension

## Why

The Human Services Data Specification (HSDS / Open Referral format) is the closest
thing the sector has to a shared language for publishing information about health,
human, and social services. Version 3.0 deliberately excludes real-time bed
availability — the project's own FAQ states the omission explicitly: "we excluded
many kinds of information that are unique to specific kinds of services, such as
the availability of beds in a shelter."

That gap is precisely what kills families at midnight. This change proposes and
documents a formal HSDS Profile Extension that fills it — a machine-readable,
open-source addition to the HSDS standard that any city, shelter, or outreach
app can adopt at zero licensing cost.

The extension is designed to be contributed back to the Open Referral Initiative
as a community profile proposal. It is also the data contract that governs the
`finding-a-bed-tonight` reference implementation.

## What Changes

- **`hsds-extension/spec.md`** — Formal HSDS Profile Extension defining the
  `BedAvailability` object, all enumerated constraint fields (population types,
  sobriety policy, ID policy, referral policy, accessibility, pets, DV flag),
  the `SurgeMode` flag for White Flag / cold-weather emergency events, and the
  `ShelterReservation` hold object. Includes JSON schema fragment suitable for
  contribution to `openreferral/specification`.

- **`api-contract/spec.md`** — OpenAPI 3.1 contract for the three surface areas:
  (1) the public query API (outreach worker mobile path), (2) the shelter update
  API (coordinator dashboard path), and (3) the CoC admin / analytics API.
  Security model: API-key for shelter updates; public (rate-limited) for queries;
  OAuth2 client credentials for CoC analytics. Includes AsyncAPI 3.0 fragment
  for Kafka availability-update events (used by HMIS bridge and analytics pipeline).

- **`data-model/spec.md`** — PostgreSQL schema with DBML source and ERD.
  Covers `shelters`, `bed_availability_snapshots`, `bed_reservations`,
  `surge_events`, `audit_log`. Reactive boundary documented (R2DBC for query
  and update paths; imperative for HMIS bridge batch sync). Includes
  `ON CONFLICT DO NOTHING` patterns for concurrent shelter updates.

- **`security-privacy/spec.md`** — DV shelter hard separation design. Hard
  architectural boundary: DV providers register in an isolated `dv_registry`
  schema with no public query surface. Referral routing for DV uses a one-way
  opaque token handed to a trusted coordinator only. Documents VAWA compliance
  posture and the decision NOT to store any client PII — queries describe
  needs, not persons.

## Capabilities

### New Capabilities

- **`bed-availability-query`**: Any authorized caller (mobile app, city dashboard,
  211 system) can POST a structured need descriptor (location, radius, population
  type, accessibility requirements, pet flag, sobriety policy preference) and
  receive a ranked list of shelters with current available beds, distance, and
  reservation instructions. Targets < 500ms p95. Backed by Caffeine L1 +
  Redis L2 with 60-second TTL on availability snapshots.

- **`shelter-availability-update`**: An authenticated shelter coordinator can
  PATCH their shelter's current bed counts for each population type in ≤ 3
  API calls. The update invalidates the shelter's L1/L2 cache entries and
  publishes an `availability.updated` Kafka event for downstream consumers
  (analytics pipeline, HMIS bridge). Idempotent — concurrent updates from
  the same shelter use `ON CONFLICT` semantics.

- **`surge-mode`**: A CoC admin can activate a `SurgeEvent` for a geographic
  area (Raleigh White Flag pattern). Activated surge opens an overflow
  availability tier, broadcasts a `surge.activated` Kafka event to all
  subscribed outreach worker apps, and enables reporting of temporary capacity
  beyond normal year-round bed inventory.

- **`dv-shelter-opaque-referral`**: A trusted coordinator (role: `DV_REFERRAL`)
  can query DV bed availability through a privacy-preserving channel that
  returns only a boolean (space available: yes/no) and a one-time referral
  token. No location, name, or capacity details are ever returned. VAWA
  compliant by design.

- **`hmis-bridge`**: Optional async push adapter. Shelters already running
  HMIS-compliant software (Bitfocus Clarity, ServicePoint, etc.) can configure
  a webhook that pushes availability snapshots to the platform automatically
  on each entry/exit event. Reduces manual update burden to zero for
  participating shelters. Uses Resilience4J circuit breaker + retry per
  HMIS vendor endpoint.

- **`coc-analytics`**: Authenticated CoC and city admins can query aggregate,
  anonymized metrics: nightly utilization by shelter, unmet demand (queries
  with no match), surge event performance, population-type gaps. Backed by
  a materialized view refreshed nightly and an on-demand query path for
  live reads. No individual-level data is accessible through this surface.

### Modified Capabilities

*(none — this is a greenfield repo with no prior implementation)*

## Impact

- **Repo:** `finding-a-bed-tonight` (GitHub, account: `ccradle`, public) — new repo
- **HSDS upstream:** Extension will be submitted as a community profile proposal
  to `openreferral/specification` after Raleigh pilot validates the schema
- **Downstream consumers:** Any outreach app, 211 system, or city dashboard
  that speaks HSDS can query this API with zero proprietary dependency
- **Pilot city:** Raleigh / Wake County NC-507 CoC — selected because Wake County
  is actively rebuilding its CoC infrastructure (took over as lead agency 2023),
  HMIS platform upgrade is in progress, and the 2025 PIT count (1,258 persons,
  +27% YoY) explicitly called out the need for real-time availability data
- **Open source license:** Apache 2.0 — compatible with municipal adoption,
  nonprofit use, and commercial wrapper products
- **No client PII stored or transmitted at any point in the system**

## Standing Amendments Required Before `/opsx:apply`

The following six cross-cutting concerns MUST be injected into all specs before
implementation begins. Each is a non-negotiable architectural constraint.

1. **Webhook/Status API** — HMIS bridge uses outbox pattern. Each bridge
   delivery attempt logged to `hmis_bridge_outbox`. Retry schedule: 1m, 5m,
   30m, 2h. HTTP 410 from HMIS vendor triggers automatic deregistration.
   `/actuator/bridge-status/{shelterId}` exposes delivery health per shelter.

2. **Resilience4J** — Circuit breaker + retry on every HMIS vendor HTTP call.
   Instance naming: `fabt-hmis-{vendor}` (e.g., `fabt-hmis-bitfocus`).
   Reactive pipeline: `CircuitBreakerOperator` / `RetryOperator` only —
   NEVER `@CircuitBreaker` annotation inside a `Mono`/`Flux` chain.

3. **Caffeine L1 + Redis L2** — `CacheNames` interface defines constants:
   `SHELTER_AVAILABILITY`, `SHELTER_PROFILE`, `GEO_QUERY_RESULTS`.
   L1 TTL: 60s. L2 TTL: 300s. `ReactiveRedisTemplate` for cache-aside in
   reactive paths — NEVER `@Cacheable` inside a `Mono`/`Flux`.

4. **Reactive Programming** — Query and update APIs are fully reactive
   (Spring WebFlux + R2DBC). HMIS bridge batch sync is imperative
   (Spring Batch + JDBC). Reactive boundary documented in `design.md`.
   `BlockHound` active in test profile. OTel context propagation explicit.

5. **CI/CD** — Pipeline Type B (GitHub Actions only, no Jenkins for this
   open-source project). Stages: lint → unit → integration (Testcontainers)
   → performance (Gatling) → Docker build → smoke test → publish.
   Docker image: `ghcr.io/ccradle/finding-a-bed-tonight:{version}`.

6. **Terraform IaC** — Modules: `network`, `postgres`, `redis`, `kafka`,
   `app`. Remote state in S3 + DynamoDB lock. Cost guardrail: `$50/month`
   budget alert. `[BOOTSTRAP]` tasks tagged for manual first-run steps.
   Designed for single-region deployment (pilot scale — multi-region out of scope).
