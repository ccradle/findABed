## Context

FABT runs Java 21 + Spring Boot 3.4.13 with a modular monolith architecture (PostgreSQL, Flyway, Spring Data JDBC, Spring Batch, Spring Security with OAuth2, Resilience4j, Micrometer/OTel). The codebase already uses modern Boot 3.4 patterns — lambda DSL security, `SecurityFilterChain`, `JobBuilder`/`StepBuilder` constructors, `jakarta.*` imports. Spring Boot 3.4 reached OSS end-of-life December 2025. Java 25 (LTS) and Boot 4.0 are the current stable targets.

The runtime has a concrete concurrency bottleneck: all 8 `@Scheduled` tasks share a single default scheduler thread. Long-running tasks (DV canary bed search, batch job launches) delay time-sensitive tasks (reservation expiry at 30s intervals). Webhook delivery is synchronous on the event bus — a slow subscriber blocks the entire event chain.

Tenant context propagation uses `ThreadLocal<Context>` in `TenantContext.java`, which is incompatible with virtual threads (carrier-thread unmounting can lose ThreadLocal state). This must be resolved before enabling virtual threads.

## Goals / Non-Goals

**Goals:**
- Upgrade to Java 25 LTS + Spring Boot 4.0.x with all dependencies at compatible versions
- Enable virtual threads for Tomcat request handling and task execution
- Migrate `TenantContext` from `ThreadLocal` to `ScopedValue` for virtual thread safety
- Eliminate the single-thread scheduling bottleneck
- Make webhook delivery concurrent and non-blocking to the event bus
- Fan out per-tenant monitoring checks and parallelize HMIS outbox processing
- Maintain zero downtime — no external API changes, no schema migrations

**Non-Goals:**
- Reactive migration (R2DBC, WebFlux) — virtual threads provide concurrency without reactive rewrite
- `RestTemplate` → `WebClient` migration — `RestTemplate` is still supported in Boot 4.0
- Structured Concurrency adoption (still in preview as of Java 26)
- Spring Boot native image / AOT compilation
- Connection pool re-architecture — monitor first, tune if needed

## Decisions

### D1: Upgrade to Java 25 LTS (not Java 26)

**Decision**: Target Java 25, not Java 26.

**Rationale**: Java 25 is the current LTS with support through September 2028 (premier) / 2033 (extended). Java 26 is a non-LTS release (March 2026) with only 6 months of support. The incremental gains of Java 26 (HTTP/3, G1 throughput improvements) do not justify the maintenance burden of tracking non-LTS releases.

**Alternative considered**: Java 26 for HTTP/3 support — rejected because the built-in HTTP Client is not used in the codebase (RestTemplate/RestClient handle all HTTP).

### D2: Spring Boot 4.0.x (not 3.5.x)

**Decision**: Upgrade directly to Boot 4.0.x, skipping 3.5.x.

**Rationale**: Boot 3.5.x would be a safe interim step, but it doesn't unlock virtual thread first-class support, the new OTel starter, or the Flyway starter consolidation. Since the codebase already uses modern Boot 3.4 patterns (no deprecated APIs found), the incremental risk of going to 4.0 directly is low compared to doing two framework upgrades.

**Alternative considered**: Boot 3.5.x as stepping stone — rejected to avoid two migration cycles. The codebase is already 95%+ Boot 4.0 compatible based on code analysis.

### D3: ScopedValue for TenantContext (not context parameter passing)

**Decision**: Replace `ThreadLocal<Context>` in `TenantContext` with `ScopedValue<Context>`.

**Rationale**: `ScopedValue` (finalized in Java 25, JEP 506) is designed exactly for this use case — immutable context bound to a scope, automatically inherited by child virtual threads, no manual cleanup needed. The alternative (passing tenant context as a method parameter through every call chain) would require touching dozens of service/repository signatures and fundamentally change the API ergonomics.

**Trade-off**: `ScopedValue.where(KEY, value).run(() -> ...)` requires wrapping the request handling in a lambda scope. This changes `JwtAuthenticationFilter` and `RlsDataSourceConfig` to use the scoped-value pattern instead of set/remove.

**Alternative considered**: Spring's `ContextSnapshot` / `TaskDecorator` — rejected because it's a framework-specific workaround rather than a language-level solution, and doesn't provide the immutability guarantees of `ScopedValue`.

### D4: Async webhook delivery via virtual thread executor (not @Async)

**Decision**: Replace the synchronous `@EventListener` in `WebhookDeliveryService` with an async pattern using a virtual thread executor. Each subscription delivery runs on its own virtual thread.

**Rationale**: The current implementation loops through subscriptions synchronously — a slow subscriber blocks all subsequent deliveries and the event publisher. Virtual threads make this trivially concurrent: `Executors.newVirtualThreadPerTaskExecutor()` spawns a virtual thread per webhook delivery. No reactive programming needed.

**Design**: The `@EventListener` method submits each subscription delivery to the virtual thread executor. Fire-and-forget with existing Resilience4j circuit breaker for per-subscriber fault isolation. Delivery failures are already handled (retry with backoff, deactivation on 410).

**Alternative considered**: `@Async` with `@EnableAsync` — rejected because `@Async` requires proxy-based interception and loses the direct traceability of the event flow. Explicit executor usage is more transparent.

### D5: Virtual thread-backed TaskScheduler for @Scheduled tasks

**Decision**: Configure a `ThreadPoolTaskScheduler` with a virtual thread factory as the application-wide scheduler.

**Rationale**: The default scheduler uses 1 platform thread. Increasing the pool size to N platform threads is wasteful — most tasks are I/O-bound (JDBC queries, HTTP calls). A virtual thread factory means each scheduled task invocation gets its own virtual thread, and the carrier thread is released during I/O waits.

**Design**: Define a `TaskScheduler` bean in a new `VirtualThreadConfig` configuration class. This replaces the default scheduler for all `@Scheduled` methods and the `BatchJobScheduler`'s `SchedulingConfigurer`.

### D6: Per-tenant fan-out with bounded virtual threads

**Decision**: In `OperationalMonitorService`, replace sequential tenant loops with `ExecutorService.invokeAll()` on a virtual thread executor, bounded by the connection pool.

**Rationale**: `checkStaleShelters()`, `checkDvCanary()`, and `checkTemperatureSurgeGap()` each loop over all tenants sequentially. With virtual threads, per-tenant checks can run concurrently. However, each check requires a JDBC connection, so concurrency is naturally bounded by the HikariCP pool size (20 OLTP, 3 analytics).

**Design**: Use `Semaphore` to limit concurrent tenant checks to `min(tenantCount, poolSize - headroom)`. This prevents connection pool exhaustion while maximizing throughput.

### D7: Parallel HMIS outbox processing

**Decision**: In `HmisPushJobConfig` step 2, process outbox entries in parallel using virtual threads instead of sequential iteration.

**Rationale**: Each outbox entry involves a blocking REST call to an HMIS vendor (Clarity, ClientTrack). Sequential processing means throughput is limited to 1 vendor call at a time. With virtual threads, outbox entries can be dispatched concurrently, bounded by the vendor's rate limits (enforced via Resilience4j).

### D8: Concurrent OAuth2 token + userinfo fetch

**Decision**: In `OAuth2RedirectController`, issue the token exchange and userinfo fetch concurrently where the IdP supports it, or pipeline them with virtual threads to avoid blocking the request thread.

**Rationale**: The current flow creates a new `RestTemplate` per call and blocks sequentially: (1) exchange code for tokens, (2) fetch userinfo. The token exchange must complete first (userinfo requires the access token), but the overall operation runs on a virtual thread instead of occupying a platform thread during the blocking HTTP calls.

**Design**: Wrap the callback handler in a virtual thread scope. The sequential nature is preserved (token → userinfo), but the platform thread is released during I/O waits. This is the simplest win — no code restructuring needed, just ensuring the request runs on a virtual thread (which `spring.threads.virtual.enabled=true` provides for Tomcat).

### D10: Grafana performance dashboard provisioned before Gatling tests

**Decision**: Create a Grafana dashboard with JVM thread, CPU, memory, GC, and HikariCP connection pool panels. Provision it before running Gatling performance tests so that metrics captured during the load test are visible in Grafana after the test completes.

**Rationale**: Virtual threads fundamentally change the threading model. Without observability during load tests, we can't validate that virtual threads actually improve throughput or detect problems like connection pool exhaustion. The dashboard provides before/after comparison capability — run Gatling on Java 21 (baseline), then again on Java 25 with virtual threads, and compare the panels.

**Design**: A provisioned Grafana JSON dashboard file (`grafana/dashboards/virtual-thread-performance.json`) with panels for:
- JVM thread counts by state (runnable, waiting, timed-waiting) — shows carrier thread pool staying flat while throughput increases
- `process_cpu_usage` and `system_cpu_usage` — CPU impact of virtual threads
- `jvm_memory_used_bytes` by area (heap, non-heap) — memory impact
- `jvm_gc_pause_seconds` — GC pressure under load
- `hikaricp_connections_active`, `hikaricp_connections_pending`, `hikaricp_connections_timeout_total` — connection pool saturation
- Request rate and latency (from Micrometer HTTP server metrics)

Prometheus scrapes `/actuator/prometheus` at 5s intervals during the Gatling test. Dashboard uses `$__range` variables so the Gatling test window is visible after completion.

**Alternative considered**: Ad-hoc PromQL queries after the test — rejected because a provisioned dashboard is repeatable and can be committed to the repo for ongoing use.

### D9: Phased migration order

**Decision**: Execute the migration in this order:
1. **Phase 1 — Platform upgrade**: Java 25, Boot 4.0, all dependency bumps. Goal: `mvn compile` passes.
2. **Phase 2 — Test migration**: Testcontainers 2.0 renames, test compilation. Goal: `mvn test` passes.
3. **Phase 3 — TenantContext ScopedValue**: Migrate ThreadLocal → ScopedValue. Goal: RLS tests pass.
4. **Phase 4 — Virtual thread enablement**: Enable `spring.threads.virtual.enabled=true`, configure TaskScheduler. Goal: all tests pass with virtual threads.
5. **Phase 5 — Concurrency refactoring**: Webhook async delivery, monitoring fan-out, HMIS parallel processing. Goal: integration tests validate concurrent behavior.
6. **Phase 6 — Safety validation**: Connection pool monitoring, load testing, Flyway migration verification.

**Rationale**: Each phase has a clear gate (compile/test/integration). If a phase fails, the blast radius is contained. The most impactful change (TenantContext) is isolated in Phase 3 where it can be tested independently.

## Risks / Trade-offs

**[Connection pool exhaustion under virtual threads]** → Mitigate with Semaphore-bounded fan-out in monitoring checks and connection pool metrics. HikariCP max-pool-size remains at 20 (OLTP) / 3 (analytics). Monitor `hikaricp_connections_pending` and `hikaricp_connections_timeout` metrics. Increase pool size only if metrics indicate saturation.

**[Jackson 3 cascade breaks serialization]** → Mitigate by testing all REST endpoints and webhook payloads after upgrade. Jackson 3 changes group ID (`com.fasterxml.jackson` → `tools.jackson`) but Spring Boot 4.0 manages this transparently via its dependency management. Custom serializers/deserializers in the codebase (if any) need manual verification.

**[Flyway silent failure with wrong starter]** → Mitigate by adding an integration test that verifies Flyway migration count matches expected count on startup. The swap from `flyway-core` to `spring-boot-starter-flyway` must be validated before merging.

**[springdoc-openapi 3.0 edge cases]** → Known issue with Boot 4 API versioning (springdoc#3163). Mitigate by testing Swagger UI endpoint manually after upgrade. If blocked, pin to 3.0.2+ which includes fixes.

**[TenantContext ScopedValue touches RLS critical path]** → Mitigate by running the full RLS test suite (DV canary, tenant isolation tests) after migration. The `ScopedValue` API is simpler than `ThreadLocal` (no cleanup needed), reducing the surface area for bugs.

**[Testcontainers 2.0 package relocations break all integration tests]** → Mitigate by using OpenRewrite's `Testcontainers2Migration` recipe for automated refactoring, then manual verification.

**[Spring Batch 6.0 schema change (unlikely)]** → Mitigate by checking the `spring-batch-core` JAR for `migration/6.0/` scripts after upgrading. Current analysis indicates no schema changes, but verify at upgrade time. If scripts exist, add as a Flyway migration (V26).

## Migration Plan

### Rollback Strategy
Each phase produces a commit. If a phase introduces regressions:
- Revert the phase commit
- No database schema changes means no Flyway rollback needed
- Virtual thread enablement is a single property toggle — can be disabled instantly

### Deployment
- No external API changes → no client coordination needed
- No database migration → no maintenance window needed
- Feature flag: `spring.threads.virtual.enabled` can be toggled in production config without redeployment (if using Spring Cloud Config or environment variable override)

## Open Questions

1. **Spring Batch 6.0 schema scripts**: Must verify at upgrade time. If migration scripts exist, they need a Flyway V26 migration.
2. **logstash-logback-encoder vs Boot 4 native structured logging**: Boot 4.0 has improved built-in JSON logging. Evaluate whether `logstash-logback-encoder` is still needed or can be replaced, reducing a dependency.
3. **HikariCP pool sizing**: Current 20-connection OLTP pool was sized for single-thread scheduling. Virtual threads may require tuning after monitoring — but changing it prematurely would be premature optimization.
4. **Resilience4j Spring Boot 4 starter maturity**: `resilience4j-spring-boot4:2.4.0` is relatively new. Evaluate stability and consider whether Spring Framework 7's native retry/concurrency annotations can replace some Resilience4j usage.
