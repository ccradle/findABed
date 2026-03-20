# CLAUDE-CODE-BRIEF.md — finding-a-bed-tonight

**Engineer:** Corey Cradle | 30 years Java/Spring Boot | [ccradle](https://github.com/ccradle)
**Project:** `finding-a-bed-tonight` — open-source emergency shelter bed availability
infrastructure. Apache 2.0. Designed for city/state adoption at zero licensing cost.

---

## Current Project Context

```
Active repo: finding-a-bed-tonight
Active OpenSpec change: 2026-03-19-hsds-bed-availability-extension
Current phase: spec
```

---

## Mandatory Session Opener (paste verbatim to start any session)

```
We are doing spec-driven development using OpenSpec conventions.
Your job is to create and populate markdown specification files only.
Do not write implementation code.
You are working with a senior Java engineer named Corey Cradle.
30 years of Java/Spring Boot experience. Building finding-a-bed-tonight —
open-source emergency shelter bed availability infrastructure targeting
Apache 2.0 license and zero-cost city/state adoption.
Active repo: finding-a-bed-tonight (standalone GitHub repo, account: ccradle)

OpenSpec workflow rules — non-negotiable:
Do NOT use planning mode (Shift+Tab Shift+Tab) — it blocks file creation
Command sequence: /opsx:new → /opsx:ff → review artifacts →
paste standing amendments → /opsx:apply → /opsx:verify →
/opsx:sync if drift → /opsx:archive
During spec phase: create and populate markdown files ONLY
Commit OpenSpec change folder after /opsx:ff — specs are portfolio
artifacts even before implementation code exists
Clear context window before each /opsx:apply session
```

---

## Project Mission (say this to yourself before every spec decision)

A family of five is sitting in a parking lot at midnight. A social worker has
30 minutes before the family stops cooperating. Every architectural decision
in this codebase exists to get that family into a bed faster.

**Optimise for:**
1. Data freshness — stale availability data is worse than no data
2. Update friction — if coordinators do more than 3 taps to update, they won't
3. Offline resilience — outreach workers are in basements and under bridges
4. Zero PII — the system describes needs, never persons

---

## Tech Stack

Java 21, Spring Boot 3.4.x, Spring WebFlux + WebClient + R2DBC,
PostgreSQL 16, Redis 7, Apache Kafka 3.x + Avro + Confluent Schema Registry,
Resilience4J 2.x, Caffeine L1 + Redis L2, Springdoc OpenAPI (WebFlux),
Testcontainers, Gatling, Terraform, GitHub Actions

---

## OpenSpec Command Sequence

| Step | Command | Purpose |
|---|---|---|
| 1 | `/opsx:new` | Create new change, scaffold change directory |
| 2 | `/opsx:ff` | Fast-forward: proposal → design → specs → tasks in one session |
| 3 | Review artifacts | Read ALL generated artifacts before implementing |
| 4 | Paste standing amendments | Inject six cross-cutting concerns into specs |
| 5 | `/opsx:apply` | Implement tasks from tasks.md; mark complete as you go |
| 6 | `/opsx:verify` | Verify implementation matches all artifacts |
| 7 | `/opsx:sync` | Sync specs if drift found during implementation |
| 8 | `/opsx:archive` | Finalise and archive the completed change |

---

## Standing Amendment Checklist

Before `/opsx:apply`, paste each amendment prompt:

- [ ] **Webhook/Status API** — HMIS bridge uses outbox pattern. Retry: 1m, 5m, 30m, 2h.
  HTTP 410 triggers deregistration. `/actuator/bridge-status/{shelterId}` per shelter.
- [ ] **Resilience4J** — CB + retry per HMIS vendor. Naming: `fabt-hmis-{vendor}`.
  Reactive: `CircuitBreakerOperator` / `RetryOperator` — NEVER `@CircuitBreaker` in Mono/Flux.
- [ ] **Caffeine L1 + Redis L2** — `CacheNames` interface: `SHELTER_AVAILABILITY`,
  `SHELTER_PROFILE`, `GEO_QUERY_RESULTS`. L1 TTL 60s, L2 TTL 300s.
  `ReactiveRedisTemplate` for cache-aside — NEVER `@Cacheable` in Mono/Flux.
- [ ] **Reactive Programming** — Query + update = WebFlux + R2DBC (reactive).
  HMIS bridge batch sync = Spring Batch + JDBC (imperative). Document boundary in design.md.
  BlockHound active in test profile. OTel context propagation explicit.
- [ ] **CI/CD** — Pipeline Type B (GitHub Actions only). Stages: lint → unit →
  integration → perf → docker → smoke → publish.
  Image: `ghcr.io/ccradle/finding-a-bed-tonight:{version}`.
- [ ] **Terraform IaC** — Modules: `network`, `postgres`, `redis`, `kafka`, `app`.
  Remote state S3 + DynamoDB. Cost guardrail: $50/month. `[BOOTSTRAP]` tags on first-run tasks.

---

## Hard Rules — Non-Negotiable

1. Never write implementation code during spec phase — markdown files only
2. Never use `@CircuitBreaker` annotation in reactive pipelines — `CircuitBreakerOperator` only
3. Never use `@Cacheable` inside a `Mono<T>` / `Flux<T>` chain — `ReactiveRedisTemplate` + cache-aside
4. Never block a Netty event loop thread — `BlockHound` catches it in tests
5. Never put secrets in HCL, `application.yml` committed to Git, or `.env` files committed to Git
6. Always name Resilience4J instances `fabt-{target}` (e.g., `fabt-hmis-bitfocus`)
7. Always define cache names as constants in a `CacheNames` interface — never magic strings
8. Always document the reactive boundary explicitly in `design.md`
9. Always tag Terraform bootstrap tasks as `[BOOTSTRAP]` in `tasks.md`
10. Do NOT use planning mode (Shift+Tab Shift+Tab) — it blocks file creation
11. Never store or log any PII — queries describe needs, not persons
12. DV shelter (`dv_shelter = true`) data access must be enforced at the DATA LAYER —
    routing-level checks are not sufficient and will not pass verify
13. `ON CONFLICT DO NOTHING` on all concurrent availability snapshot inserts —
    read-before-write has a race condition under concurrent shelter updates

---

## Domain-Specific Hard-Won Lessons

*(In addition to the 48 lessons in portfolio CLAUDE-CODE-BRIEF.md)*

**D1. Data age always surfaces to the caller.**
Every availability query response MUST include `data_age_seconds` derived from
`snapshot_ts`. A stale-cache hit that silently returns 3-hour-old data is worse
than returning nothing — the social worker drives across town to a shelter that
has been full since 9pm. Surface the staleness; never hide it.

**D2. `beds_available` is a derived field, not a stored field.**
Never store `beds_available` as a column. Derive it:
`beds_total - beds_occupied - beds_on_hold`. Storing it creates a consistency
hazard when concurrent reservations and updates overlap.

**D3. Availability updates are append-only snapshots.**
Never UPDATE a `BedAvailability` row. Insert a new snapshot and query the
latest by `snapshot_ts`. This gives you a complete audit trail and eliminates
update conflicts entirely. The CoC analytics pipeline reads the history.

**D4. The DV boundary is a data-layer rule, not a routing rule.**
Do not implement DV shelter privacy as an API gateway filter or a service-layer
`if (dv_shelter)` check. The boundary must be in the PostgreSQL Row Level
Security policy. A misconfigured route should return an empty result, not a
location. Verify with a test that directly queries the DB as a non-DV-role user.

**D5. Shelter coordinators update on mobile, standing up, under stress.**
The update UI must work in one hand on a phone with a cracked screen. Never
require a login per session — use a long-lived API key tied to the shelter.
Never require more than 3 taps to submit a routine bed count update. Test
the update flow with simulated 3G throttling in CI.

**D6. Cache invalidation must be synchronous with the write.**
When a coordinator submits an update, invalidate the L1 and L2 cache entries
for that shelter BEFORE returning 200 OK to the caller. Do not rely on TTL
expiry. A coordinator who refreshes their app and sees the old number will
stop trusting the system.

**D7. White Flag / surge events are first-class domain events.**
Surge activation is not an admin toggle — it is a `SurgeEvent` domain entity
with its own Kafka topic, its own lifecycle (`ACTIVE → DEACTIVATED | EXPIRED`),
and its own audit trail. It must be queryable historically: "How many beds were
available during the January 2026 White Flag event?" is a legitimate CoC question.

**D8. HMIS bridge failure must never degrade the query path.**
The bridge is a nice-to-have integration for shelters with existing HMIS software.
Its circuit breaker must isolate bridge failures completely from the availability
query and update paths. A blown circuit breaker on the Bitfocus integration must
never cause a 503 on the query endpoint.

---

## Debugging Strategies

1. **Data freshness problem first.** When a query returns stale data, check
   `data_age_seconds` in the response before investigating cache config.
   The snapshot may simply not have been updated — coordinator training issue,
   not a system bug.
2. **DV boundary failures are silent by design.** A test that expects a 403
   on a DV shelter query is wrong — the correct response is 200 with an empty
   result set. A 403 leaks the existence of the shelter.
3. **Reservation hold expiry is async.** Do not assert that expired holds are
   released synchronously. The expiry scheduler runs on a configurable interval
   (default 60s). Use `Awaitility` with a 90s timeout, not a `Thread.sleep`.
4. **Surge event broadcast latency.** The 30-second broadcast SLA is measured
   from `triggered_at` to the Kafka consumer offset commit, not to UI render.
   Test the Kafka consumer, not the websocket.
