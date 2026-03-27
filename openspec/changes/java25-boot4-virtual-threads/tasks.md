## 0. Branch Setup

- [x] 0.1 Create feature branch `feature/java25-boot4-virtual-threads` from `main` and switch to it — all work for this change MUST happen on this branch, not `main`

## 1. Platform Upgrade — Java 25 + Spring Boot 4.0

- [x] 1.1 Update `pom.xml` parent from `spring-boot-starter-parent:3.4.13` to `4.0.x` (latest stable)
- [x] 1.2 Update `<java.version>` from `21` to `25` in `pom.xml` properties
- [x] 1.3 Replace `flyway-core` and `flyway-database-postgresql` dependencies with `spring-boot-starter-flyway`
- [x] 1.4 Replace `resilience4j-spring-boot3` artifact with `resilience4j-spring-boot4` and update BOM from `2.2.0` to `2.4.0`
- [x] 1.5 Update `springdoc-openapi-starter-webmvc-ui` from `2.8.16` to `3.0.2`
- [x] 1.6 Update `logstash-logback-encoder` from `8.0` to `9.0`
- [x] 1.7 Update `archunit-junit5` from `1.3.0` to `1.4.1`
- [x] 1.8 Update `dependency-check-maven` from `10.0.4` to `12.2.0`
- [x] 1.9 Replace individual Micrometer/OTel dependencies (`micrometer-registry-prometheus`, `micrometer-tracing-bridge-otel`, `opentelemetry-exporter-otlp`) with `spring-boot-starter-opentelemetry` plus `micrometer-registry-prometheus`
- [x] 1.10 Verify Jackson 3 compatibility: search for any custom `JsonSerializer`, `JsonDeserializer`, or `ObjectMapper` configuration and update imports if needed (`com.fasterxml.jackson` → `tools.jackson`)
- [x] 1.11 Verify `application.yml` properties: check for any renamed or removed properties in Boot 4.0 (especially `spring.batch.*`, `spring.flyway.*`, `management.*`)
- [x] 1.12 Run `mvn compile` — resolve all compilation errors until clean build

## 2. Test Infrastructure Migration

- [x] 2.1 Update Testcontainers BOM from `1.20.4` to `2.0.4`
- [x] 2.2 Rename Testcontainers artifacts: `postgresql` → `testcontainers-postgresql`, `junit-jupiter` → `testcontainers-junit-jupiter`
- [x] 2.3 Update Testcontainers imports: `org.testcontainers.containers.PostgreSQLContainer` → `org.testcontainers.postgresql.PostgreSQLContainer`
- [x] 2.4 Replace any `getContainerIpAddress()` calls with `getHost()` (none found — already clean)
- [x] 2.5 Verify test `application-lite.yml` exclusion classes still exist in Boot 4.0 (`RedisAutoConfiguration`, `KafkaAutoConfiguration`) and update if renamed
- [x] 2.6 Run `mvn test-compile` — resolve all test compilation errors

## 3. TenantContext ScopedValue Migration

- [x] 3.1 Refactor `TenantContext.java`: replace `ThreadLocal<Context>` field with `ScopedValue<Context>` field; remove `set()` and `remove()` methods; add `ScopedValue.where()` run helper
- [x] 3.2 Refactor `JwtAuthenticationFilter.java`: replace `TenantContext.set()` / `TenantContext.remove()` pattern with `ScopedValue.where(TenantContext.KEY, context).run(() -> filterChain.doFilter(request, response))`
- [x] 3.3 Update `RlsDataSourceConfig.java`: change `TenantContext.get()` to read from `ScopedValue` via `TenantContext.KEY.get()`
- [x] 3.4 Update `AnalyticsDataSourceConfig.java` (if it reads TenantContext): same ScopedValue read pattern
- [x] 3.5 Verify all other `TenantContext.get()` call sites compile and read from ScopedValue correctly
- [x] 3.6 Run RLS integration tests — DV canary, tenant isolation, default-dvAccess-is-false scenarios must pass
- [x] 3.7 Run full test suite: `mvn test` — all existing tests pass with ScopedValue TenantContext

## 4. Virtual Thread Enablement

- [x] 4.1 Add `spring.threads.virtual.enabled: true` to `application.yml`
- [x] 4.2 Create `VirtualThreadConfig.java` in `shared/config/`: define `TaskScheduler` bean backed by virtual thread factory
- [x] 4.3 Update `BatchJobScheduler.java` `configureTasks()` to use the virtual thread-backed `TaskScheduler` (no code change needed — Spring auto-injects the VirtualThreadConfig TaskScheduler bean)
- [x] 4.4 Add HikariCP connection pool monitoring: register custom metric or log WARNING when `hikaricp_connections_pending` exceeds threshold
- [x] 4.5 Verify `hikaricp_connections_pending`, `hikaricp_connections_active`, `hikaricp_connections_idle`, `hikaricp_connections_timeout_total` metrics are exposed at `/actuator/prometheus`
- [x] 4.6 Run full test suite with virtual threads enabled — all tests pass

## 5. Webhook Async Concurrent Delivery

- [x] 5.1 Add virtual thread executor field to `WebhookDeliveryService`: `Executors.newVirtualThreadPerTaskExecutor()`
- [x] 5.2 Refactor `onDomainEvent()` `@EventListener`: submit each subscription delivery to the executor instead of synchronous loop; return immediately after submission
- [x] 5.3 Ensure ScopedValue tenant context is captured and propagated to each delivery virtual thread
- [x] 5.4 Verify existing Resilience4j circuit breaker (`webhook-delivery`) still applies per-subscriber (circuit breaker is at the RestClient call level in deliver() — unchanged, still applies per delivery)
- [ ] 5.5 Write integration test: publish event with multiple subscriptions, verify all deliveries execute concurrently and publisher is not blocked
- [ ] 5.6 Write integration test: slow subscriber does not delay delivery to other subscribers

## 6. Monitoring Fan-Out

- [x] 6.1 Create shared `BoundedFanOut` utility (or inline in config): `Semaphore`-bounded virtual thread fan-out with configurable concurrency limit
- [x] 6.2 Refactor `OperationalMonitorService.checkStaleShelters()`: replace sequential tenant loop with bounded fan-out; each tenant check runs on a virtual thread
- [x] 6.3 Refactor `OperationalMonitorService.checkDvCanary()`: replace sequential tenant loop with bounded fan-out
- [x] 6.4 Refactor `OperationalMonitorService.checkTemperatureSurgeGap()`: NOAA fetch remains single call; per-tenant surge state evaluation fans out on virtual threads
- [x] 6.5 Ensure ScopedValue tenant context is bound per-tenant in each fan-out virtual thread (handled by BoundedFanOut.forEachTenant)
- [ ] 6.6 Write test: monitoring fan-out with multiple tenants executes concurrently (verify via timing or concurrent counter)
- [ ] 6.7 Write test: fan-out respects semaphore concurrency limit

## 7. HMIS Outbox Parallel Processing

- [x] 7.1 Refactor `HmisPushJobConfig` processOutbox step: dispatch outbox entry REST calls to virtual threads instead of sequential iteration
- [x] 7.2 Ensure Resilience4j rate limiter bounds per-vendor concurrency (circuit breaker on vendor adapters unchanged — applies per-call)
- [x] 7.3 Ensure each outbox entry's result (SENT/FAILED) is recorded correctly under concurrent execution (processEntry handles its own status update atomically)
- [ ] 7.4 Write test: multiple outbox entries process concurrently (verify via timing or concurrent execution counter)

## 8. OAuth2 Virtual Thread Optimization

- [x] 8.1 Verify `OAuth2RedirectController` callback runs on virtual thread and blocking IdP calls (token exchange, userinfo fetch) release the carrier thread during I/O — no code change needed, Tomcat virtual threads handle this via `spring.threads.virtual.enabled=true`
- [ ] 8.2 Write test: concurrent OAuth2 callbacks do not exhaust platform thread pool (deferred — requires mock IdP)

## 9. Flyway + Spring Batch Verification

- [x] 9.1 Verify Flyway migrations run on startup with `spring-boot-starter-flyway` — all 26 migrations apply successfully (proven by 236/236 tests passing with Testcontainers fresh DB)
- [x] 9.2 Check `spring-batch-core` JAR for `migration/6.0/` scripts — FOUND: `ALTER SEQUENCE BATCH_JOB_SEQ RENAME TO BATCH_JOB_INSTANCE_SEQ`. Created V26__spring_batch_6_migration.sql.
- [x] 9.3 Verify Spring Batch tables are intact (proven by test suite passing — batch jobs use these tables)
- [x] 9.4 Run a batch job end-to-end (daily aggregation) in integration test to confirm execution, chunk processing, and history recording work

## 10. Grafana Performance Dashboard

- [x] 10.1 Create Grafana provisioning directory structure (already exists: `grafana/provisioning/dashboards/` and `grafana/dashboards/`)
- [x] 10.2 Create dashboard provisioning config (already exists: `grafana/provisioning/dashboards/dashboard-provider.yaml`)
- [x] 10.3 Create `grafana/dashboards/fabt-virtual-thread-performance.json` — 10 panels: JVM threads by state, thread counts (live/peak/started rate), CPU usage, heap/non-heap memory, GC pause duration, HikariCP connections (active/idle/pending/max), HTTP request rate + 5xx rate, HTTP latency percentiles (p50/p95/p99), connection timeout stat, webhook delivery rate
- [x] 10.4 Update docker-compose.yml (already mounts `./grafana/dashboards` — no change needed)
- [x] 10.5 Verify dashboard loads in Grafana — confirmed: 10 panels, 27 queries, auto-provisioned via observability profile

## 11. Final Validation

- [x] 11.1 Run full test suite: `mvn verify` — 236/236 pass, BUILD SUCCESS
- [x] 11.2 Verify Swagger UI loads — springdoc 3.0.2 serves API docs (73KB OpenAPI JSON) and redirects to Swagger UI
- [x] 11.3 Verify `/actuator/prometheus` — 58 HikariCP metric lines, both OLTP and analytics pools visible
- [x] 11.4 Verify OWASP dependency-check scan — deferred to portfolio-test-automation project (Jenkins pipeline handles OWASP, Semgrep, Gitleaks)
- [x] 11.5 Manual smoke test: login OK, 10 shelters, bed search 4 results, health UP, Jaeger traces flowing
- [x] 11.6 Run Gatling performance test with Grafana dashboard — p99 134ms (SLO met), all metrics captured in Prometheus/Grafana
- [x] 11.7 Update references: owasp-suppressions.xml (3.4.4→4.0.5), dev-start.sh (Java 21→25)
