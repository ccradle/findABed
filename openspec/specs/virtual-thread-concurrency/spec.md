## ADDED Requirements

### Requirement: virtual-thread-platform-enablement
The system SHALL enable virtual threads for Tomcat request handling, `@Async` execution, and Spring TaskExecutor via `spring.threads.virtual.enabled=true`. All inbound HTTP requests SHALL be handled on virtual threads instead of platform threads.

#### Scenario: Tomcat serves requests on virtual threads
- **WHEN** the application starts with `spring.threads.virtual.enabled=true`
- **THEN** inbound HTTP requests are dispatched on virtual threads
- **AND** the platform thread pool is no longer the concurrency bottleneck for I/O-bound requests

#### Scenario: Virtual threads release carrier during blocking I/O
- **WHEN** a request handler makes a blocking JDBC query or HTTP call
- **THEN** the virtual thread is unmounted from its carrier thread during the wait
- **AND** the carrier thread is available for other virtual threads

### Requirement: virtual-thread-task-scheduler
The system SHALL configure a `TaskScheduler` bean backed by a virtual thread factory. All `@Scheduled` methods and `BatchJobScheduler` cron tasks SHALL execute on virtual threads, eliminating the single-thread scheduling bottleneck.

#### Scenario: Scheduled tasks run concurrently
- **WHEN** two `@Scheduled` tasks are due at the same time (e.g., reservation expiry at 30s and token expiry at 60s)
- **THEN** both tasks execute concurrently on separate virtual threads
- **AND** a long-running task does not delay other scheduled tasks

#### Scenario: Batch job launch does not block scheduled monitors
- **WHEN** the daily aggregation batch job is running (potentially minutes)
- **THEN** `@Scheduled` monitoring tasks (stale shelter check, DV canary) continue to execute on schedule

### Requirement: connection-pool-monitoring-under-virtual-threads
The system SHALL expose HikariCP connection pool metrics to detect exhaustion under virtual thread concurrency. The system SHALL log a WARNING when pending connection requests exceed a configurable threshold (default: pool size / 2).

#### Scenario: Connection pool metrics exposed
- **WHEN** the application runs with virtual threads enabled
- **THEN** `hikaricp_connections_pending`, `hikaricp_connections_active`, `hikaricp_connections_idle`, and `hikaricp_connections_timeout_total` metrics are available at `/actuator/prometheus`

#### Scenario: Warning on connection pool pressure
- **WHEN** `hikaricp_connections_pending` exceeds `maximum-pool-size / 2` for the OLTP pool
- **THEN** a WARNING-level structured log is emitted with pool name, pending count, active count, and max pool size

### Requirement: semaphore-bounded-concurrent-fan-out
The system SHALL provide a shared utility for bounded concurrent fan-out using virtual threads. Fan-out operations SHALL be bounded by a configurable concurrency limit (default: connection pool size minus headroom) to prevent connection pool exhaustion.

#### Scenario: Fan-out respects concurrency limit
- **WHEN** a monitoring check fans out across 15 tenants with concurrency limit of 10
- **THEN** at most 10 tenant checks execute concurrently
- **AND** the remaining 5 execute as earlier checks complete

#### Scenario: Fan-out propagates tenant context via ScopedValue
- **WHEN** a fan-out operation dispatches work to virtual threads
- **THEN** each virtual thread has the correct tenant context bound via ScopedValue
- **AND** RLS enforcement applies correctly per-tenant

### Requirement: grafana-performance-dashboard
The system SHALL include a provisioned Grafana dashboard for visualizing JVM and connection pool metrics during Gatling performance tests. The dashboard SHALL be committed to the repository and provisioned automatically when the Grafana container starts. It MUST be created before Gatling performance tests are run so that load test metrics are captured and viewable after test completion.

#### Scenario: Dashboard shows JVM thread metrics during load test
- **WHEN** a Gatling performance test runs against the application with Prometheus scraping at 5s intervals
- **THEN** the Grafana dashboard displays JVM thread count by state (runnable, waiting, timed-waiting), showing carrier threads staying flat while virtual thread throughput increases

#### Scenario: Dashboard shows connection pool metrics during load test
- **WHEN** a Gatling performance test generates concurrent database-bound requests
- **THEN** the Grafana dashboard displays `hikaricp_connections_active`, `hikaricp_connections_pending`, and `hikaricp_connections_timeout_total` for the OLTP and analytics pools

#### Scenario: Dashboard shows CPU and memory metrics during load test
- **WHEN** a Gatling performance test runs
- **THEN** the Grafana dashboard displays `process_cpu_usage`, `jvm_memory_used_bytes` by area (heap, non-heap), and `jvm_gc_pause_seconds` percentiles

#### Scenario: Dashboard shows HTTP request rate and latency
- **WHEN** a Gatling performance test sends HTTP requests to the application
- **THEN** the Grafana dashboard displays request rate and response time percentiles (p50, p95, p99) from Micrometer HTTP server metrics
