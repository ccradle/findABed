## Why

Spring Boot 3.4 reached open-source end-of-life in December 2025, leaving the project on an unsupported framework version. Java 25 (LTS, September 2025) and Spring Boot 4.0 (November 2025) are the current stable targets. Upgrading now captures LTS support through 2028+, unlocks virtual threads to eliminate the single-thread scheduling bottleneck (8 `@Scheduled` tasks competing for 1 thread), and resolves synchronous webhook delivery blocking the event bus under load.

## What Changes

### Core Platform Upgrade
- **BREAKING**: Java 21 → 25 (pom.xml `java.version`, JDK 25 toolchain)
- **BREAKING**: Spring Boot 3.4.13 → 4.0.x (parent POM, all starters, Jakarta EE 11, Spring Framework 7.0)
- **BREAKING**: Jackson 2 → 3 (ships with Boot 4.0 — cascading impact on springdoc, logstash-logback-encoder, any custom serializers)

### Dependency Migrations
- **BREAKING**: springdoc-openapi 2.8.16 → 3.0.2 (major bump required for Boot 4)
- **BREAKING**: Testcontainers 1.20.4 → 2.0.4 (artifact renames, package relocations)
- **BREAKING**: logstash-logback-encoder 8.0 → 9.0 (Jackson 3 required)
- **BREAKING**: resilience4j 2.2.0 → 2.4.0 (artifact: `spring-boot3` → `spring-boot4`)
- **BREAKING**: Flyway: swap `flyway-core` + `flyway-database-postgresql` → `spring-boot-starter-flyway` (Boot 4 auto-config requirement — silent failure if missed)
- ArchUnit 1.3.0 → 1.4.1 (Java 25 class file support)
- OWASP dependency-check 10.0.4 → 12.2.0
- Micrometer/OTel: consolidate individual deps to `spring-boot-starter-opentelemetry`

### Virtual Thread Enablement
- Enable `spring.threads.virtual.enabled=true` for Tomcat, `@Async`, and TaskExecutor
- **BREAKING**: Migrate `TenantContext` from `ThreadLocal` to `ScopedValue` (prerequisite — ThreadLocal is unreliable with virtual thread carrier-thread unmounting; this is on the RLS critical path)
- Configure `TaskScheduler` with virtual thread factory for `@Scheduled` tasks

### Concurrency Refactoring (Leverage Virtual Threads)
- `WebhookDeliveryService`: async concurrent delivery to all subscribers instead of sequential blocking on the event bus
- `BatchJobScheduler`: virtual thread-backed scheduler so cron jobs never block each other
- `OperationalMonitorService`: fan out per-tenant health checks concurrently
- `HmisPushJobConfig` step 2: parallelize outbox processing across HMIS vendor REST calls
- `OAuth2RedirectController`: concurrent token exchange + userinfo fetch

### Safety Rails
- Connection pool monitoring for HikariCP under virtual thread concurrency
- Grafana performance dashboard for JVM threads, CPU, memory, and connection pool metrics — provisioned before Gatling performance tests to capture before/after virtual thread impact
- Verify Spring Batch 6.0 schema compatibility (current V24 Flyway migration)
- Validate Flyway migrations execute correctly after starter swap

## Capabilities

### New Capabilities
- `virtual-thread-concurrency`: Virtual thread enablement, TenantContext ScopedValue migration, concurrency patterns for webhook delivery, batch scheduling, monitoring fan-out, HMIS push parallelization, OAuth2 concurrent fetches, and Grafana performance dashboard for load test observability

### Modified Capabilities
- `webhook-subscriptions`: Delivery changes from synchronous sequential to async concurrent via virtual thread executor
- `batch-job-management`: Scheduler switches to virtual thread-backed TaskScheduler; HMIS push step parallelized
- `operational-monitoring`: Per-tenant health checks fan out on virtual threads instead of sequential loops
- `oauth2-browser-flow`: Token exchange and userinfo fetch run concurrently instead of sequentially
- `rls-enforcement`: TenantContext migrates from ThreadLocal to ScopedValue — behavioral change in how tenant context propagates

## Impact

- **Build**: JDK 25 required for compilation and test execution; all CI pipelines must update
- **Dependencies**: 8 dependencies have breaking version bumps; 3 require artifact/package renames
- **Runtime**: Virtual threads change concurrency model — connection pool sizing and tenant context propagation must be validated
- **Database**: No schema migration expected for Spring Batch 6.0, but must verify. Flyway auto-config mechanism changes.
- **API**: No external API changes — all modifications are internal implementation
- **Test**: Testcontainers 2.0 requires import/artifact renames across all integration tests
- **Observability**: OTel dependency consolidation may change metric/trace wiring
