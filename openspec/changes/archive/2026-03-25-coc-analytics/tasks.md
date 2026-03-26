## 1. Branch Setup

- [x] 1.1 Create branch `feature/coc-analytics` from main

## 2. Database Migrations

- [x] 2.1 Create `V23__create_analytics_tables.sql`: bed_search_log table, daily_utilization_summary table, BRIN index on bed_availability.snapshot_ts
- [x] 2.2 bed_search_log: id, tenant_id, population_type, results_count, search_ts. Index on (tenant_id, search_ts)
- [x] 2.3 daily_utilization_summary: id, tenant_id, shelter_id, population_type, summary_date, avg_utilization, max_occupied, min_available, snapshot_count. UNIQUE on (tenant_id, shelter_id, population_type, summary_date)
- [x] 2.4 BRIN index: `CREATE INDEX idx_bed_avail_snapshot_brin ON bed_availability USING brin(snapshot_ts) WITH (pages_per_range = 128)`
- [x] 2.5 Create `V24__spring_batch_schema.sql`: copy Spring Batch PostgreSQL schema (BATCH_JOB_INSTANCE, BATCH_JOB_EXECUTION, BATCH_STEP_EXECUTION, etc.)
- [x] 2.6 Update `docs/schema.dbml` with bed_search_log, daily_utilization_summary, and batch tables

## 3. Separate HikariCP Connection Pools (D10)

- [x] 3.1 Create analytics DataSource configuration: `@Qualifier("analyticsDataSource")` with max-pool-size=3, read-only, 30s statement_timeout, 256MB work_mem
- [x] 3.2 Keep primary DataSource as `@Primary` for all existing OLTP repositories (unchanged)
- [x] 3.3 Analytics module repositories inject the analytics DataSource
- [x] 3.4 Verify OLTP queries unaffected when analytics pool is fully utilized

## 4. Spring Batch Configuration (D13)

- [x] 4.1 Add `spring-boot-starter-batch` to pom.xml
- [x] 4.2 Configure `application.yml`: `spring.batch.job.enabled=false`, `spring.batch.jdbc.initialize-schema=never`
- [x] 4.3 Create `BatchConfig.java`: JobLauncher, JobRepository auto-configured from primary DataSource
- [x] 4.4 Store job cron expressions in tenant config JSONB: `batch_schedules: { "dailyAggregation": "0 0 3 * * *", "hmisPush": "0 0 */6 * * *", "hicExport": "0 0 4 29 1 *" }`
- [x] 4.5 Create `BatchJobScheduler.java`: reads cron from tenant config, registers scheduled tasks dynamically via `ScheduledTaskRegistrar`

## 5. Bed Search Demand Logging

- [x] 5.1 Create `BedSearchLogger.java` in `org.fabt.analytics.service`: logs search events to bed_search_log
- [x] 5.2 Modify `BedSearchService.search()`: after search, call BedSearchLogger with tenant_id, population_type, results count
- [x] 5.3 Add Micrometer counter: `fabt_search_zero_results_total` for zero-result searches

## 6. Analytics Module — Domain and Repository

- [x] 6.1 Create `org.fabt.analytics` module package structure
- [x] 6.2 Create `BedSearchLogRepository.java`: insert, countByTenantAndPeriod, countZeroResultsByPeriod
- [x] 6.3 Create `DailyUtilizationSummaryRepository.java`: upsert, findByTenantAndDateRange
- [x] 6.4 Create ArchUnit rule: analytics module boundary enforcement

## 7. Spring Batch Jobs (D13)

- [x] 7.1 Create `DailyAggregationJob.java`: chunk-oriented (read bed_availability snapshots for date, compute utilization, write daily_utilization_summary). Commit interval 100. Restartable.
- [x] 7.2 Create `HmisPushJob.java`: refactor existing HmisPushScheduler (@Scheduled) into a Spring Batch job. HmisPushService business logic unchanged — just the scheduling/retry wrapper moves to Batch. Chunk: read PENDING outbox, push via adapter, mark SENT. Retry 3x on transient HTTP errors. Skip permanent failures. Remove old @Scheduled from HmisPushScheduler after migration.
- [x] 7.3 Create `HicExportJob.java`: parameterized (reportDate). Step 1: gather shelter data. Step 2: generate HIC CSV. Prevents duplicate generation via JobParameters.
- [x] 7.4 Create `PitExportJob.java`: parameterized (reportDate). Same pattern as HIC. DV shelters aggregated in output.
- [x] 7.5 Wire all jobs to BatchJobScheduler with configurable cron from tenant config

## 8. Analytics Service

- [x] 8.1 Create `AnalyticsService.java`: orchestrates all analytics queries using analytics DataSource
- [x] 8.2 `getUtilization(tenantId, from, to, granularity)`: query daily_utilization_summary (not raw snapshots)
- [x] 8.3 `getDemand(tenantId, from, to)`: reservation conversion/expiry rates + zero-result search counts
- [x] 8.4 `getCapacity(tenantId, from, to)`: total beds over time, add/remove deltas
- [x] 8.5 `getDvSummary(tenantId)`: aggregated DV stats with minimum cell size 5 suppression
- [x] 8.9 Fix `getDvSummary()`: add distinct DV shelter count check (suppress if < 3 shelters), not just bed count
- [x] 8.10 Fix `HmisTransformer.buildInventory()`: suppress DV aggregate record when fewer than 3 distinct DV shelters in CoC (D18 compliance fix)
- [x] 8.6 `getGeographic(tenantId)`: shelter locations with utilization, DV excluded
- [x] 8.7 `getHmisHealth(tenantId)`: push success/failure rates from hmis_audit_log
- [x] 8.8 Cache all analytics responses with 5-minute TTL via `@Cacheable`

## 9. HIC/PIT Export Service

- [x] 9.1 Create `HicPitExportService.java`: generates HIC and PIT CSV data
- [x] 9.2 `generateHic(tenantId, date)`: query latest snapshot near date, format as HUD HIC CSV
- [x] 9.3 `generatePit(tenantId, date)`: query beds_occupied on date, format as sheltered PIT CSV
- [x] 9.4 DV shelter handling: include DV beds in HIC count, aggregate in PIT, redact address per policy
- [x] 9.5 Fix `generateHic()`: suppress DV aggregate row when fewer than 3 distinct DV shelters (D18)
- [x] 9.6 Fix `generatePit()`: suppress DV aggregate row when fewer than 3 distinct DV shelters (D18)

## 10. Analytics API Endpoints

- [x] 10.1 Create `AnalyticsController.java` in `org.fabt.analytics.api`
- [x] 10.2 `GET /api/v1/analytics/utilization` — COC_ADMIN, PLATFORM_ADMIN
- [x] 10.3 `GET /api/v1/analytics/demand` — COC_ADMIN, PLATFORM_ADMIN
- [x] 10.4 `GET /api/v1/analytics/capacity` — COC_ADMIN, PLATFORM_ADMIN
- [x] 10.5 `GET /api/v1/analytics/dv-summary` — COC_ADMIN, PLATFORM_ADMIN (dvAccess required)
- [x] 10.6 `GET /api/v1/analytics/geographic` — COC_ADMIN, PLATFORM_ADMIN
- [x] 10.7 `GET /api/v1/analytics/hic?date=2026-01-29` — COC_ADMIN, PLATFORM_ADMIN (returns CSV)
- [x] 10.8 `GET /api/v1/analytics/pit?date=2026-01-29` — COC_ADMIN, PLATFORM_ADMIN (returns CSV)
- [x] 10.9 `GET /api/v1/analytics/hmis-health` — COC_ADMIN, PLATFORM_ADMIN
- [x] 10.10 Add all endpoints to `SecurityConfig.java`
- [x] 10.11 OpenAPI annotations on all endpoints

## 11. Batch Job Admin API Endpoints (D14)

- [x] 11.1 Create `BatchJobController.java` in `org.fabt.analytics.api`
- [x] 11.2 `GET /api/v1/batch/jobs`: list all batch jobs with current schedule, enabled/disabled, last status — COC_ADMIN, PLATFORM_ADMIN
- [x] 11.3 `GET /api/v1/batch/jobs/{jobName}/executions`: execution history with step detail — COC_ADMIN, PLATFORM_ADMIN
- [x] 11.4 `POST /api/v1/batch/jobs/{jobName}/run`: trigger manual run with optional date parameter — PLATFORM_ADMIN
- [x] 11.5 `POST /api/v1/batch/jobs/{jobName}/restart/{executionId}`: restart failed execution — PLATFORM_ADMIN
- [x] 11.6 `PUT /api/v1/batch/jobs/{jobName}/schedule`: update cron expression — PLATFORM_ADMIN
- [x] 11.7 `PUT /api/v1/batch/jobs/{jobName}/enable`: enable/disable job — PLATFORM_ADMIN
- [x] 11.8 Add endpoints to SecurityConfig.java

## 12. Frontend — Analytics Admin Tab

- [x] 12.1 Install Recharts and react-leaflet: `npm install recharts react-leaflet leaflet @types/leaflet`
- [x] 12.2 Add "Analytics" tab to Admin panel — visible to COC_ADMIN, PLATFORM_ADMIN. Lazy-load the entire tab via `React.lazy()` so the ~200KB Recharts bundle only downloads when an admin opens the tab (outreach workers on phones never load it)
- [x] 12.3 Executive Summary section: total beds, occupied, available, on hold, utilization gauge (65-105% thresholds)
- [x] 12.4 Utilization Trends section: Recharts LineChart with daily/weekly/monthly toggle, population type filter
- [x] 12.5 Shelter Performance section: table with per-shelter utilization, RAG indicators, DV aggregated row
- [x] 12.6 Demand Signals section: reservation expiry rate chart, zero-result search count, hold-to-confirmation time
- [x] 12.7 Geographic View section: react-leaflet map with shelter markers colored by utilization, DV excluded. Fallback: if map tiles fail to load (air-gapped), show a table grouped by city/zip instead
- [x] 12.8 HMIS Health section: push success rate, last push per vendor, dead letter count
- [x] 12.9 HIC/PIT Export section: date picker, download HIC CSV button, download PIT CSV button

## 13. Frontend — Batch Jobs Management (D14)

- [x] 13.1 Batch Jobs section in Analytics tab (or separate section)
- [x] 13.2 Job list: name, cron schedule, enabled/disabled toggle, last run status badge, next scheduled run
- [x] 13.3 Edit cron modal: PLATFORM_ADMIN can change schedule, with validation
- [x] 13.4 Run Now button: PLATFORM_ADMIN, date picker for parameterized jobs, confirmation dialog
- [x] 13.5 Execution history panel: click job to expand, table of runs (start, end, duration, status, exit message)
- [x] 13.6 Step detail: click execution to expand, table of steps (name, read/write/skip counts, status)
- [x] 13.7 Restart button on FAILED executions — PLATFORM_ADMIN only
- [x] 13.8 Add `data-testid` attributes to all batch job UI elements
- [x] 13.9 i18n: add EN/ES strings for all analytics + batch job labels

## 14. Grafana Dashboard

- [x] 14.1 Create `grafana/dashboards/fabt-coc-analytics.json`: 6 panels (utilization gauge, zero-result rate, reservation conversion, capacity trend, demand vs capacity, stale shelter count)
- [x] 14.2 Add Spring Batch job panels: job success/failure rate (`spring.batch.job` timer), job duration trends
- [x] 14.3 Dashboard auto-loads via existing provisioning config
- [x] 14.4 Only available when --observability stack is active

## 15. Gatling Mixed-Load Performance Test (D15)

- [x] 15.1 Create `AnalyticsMixedLoadSimulation.java`: baseline OLTP (50 bed searches + 20 availability updates)
- [x] 15.2 Add concurrent analytics load: 3 analytics queries (utilization, demand, HIC export)
- [x] 15.3 Measure bed search p99 under mixed load — threshold: must stay under 200ms
- [x] 15.4 Measure analytics query duration — threshold: under 5s
- [x] 15.5 Verify HikariCP OLTP pool is not exhausted during analytics

## 16. Integration Tests

- [x] 16.1 Test: bed search logs events to bed_search_log table
- [x] 16.2 Test: zero-result search increments Micrometer counter
- [x] 16.3 Test: utilization endpoint returns rates from summary table
- [x] 16.4 Test: demand endpoint includes reservation expiry rate and zero-result count
- [x] 16.5 Test: capacity endpoint shows total beds over time
- [x] 16.6 Test: DV summary aggregates with minimum cell size suppression
- [x] 16.7 Test: geographic endpoint excludes DV shelters
- [x] 16.8 Test: HIC export generates CSV with correct columns
- [x] 16.9 Test: PIT export aggregates DV shelters
- [x] 16.10 Test: outreach worker cannot access analytics endpoints (403)
- [x] 16.11 Test: Spring Batch daily aggregation job runs and populates summary table
- [x] 16.12 Test: batch job execution history queryable via JobExplorer
- [x] 16.13 Test: batch job restart on failed execution
- [x] 16.14 Test: analytics queries use analytics DataSource (not OLTP pool)
- [x] 16.15 Test: DV summary suppressed when CoC has only 1 DV shelter (D18)
- [x] 16.16 Test: DV summary NOT suppressed when CoC has 3+ DV shelters (D18)
- [x] 16.17 Test: HMIS transformer suppresses DV aggregate for single-shelter CoC (D18)
- [x] 16.18 Test: HIC export omits DV row for single-shelter CoC (D18)
- [x] 16.19 Test: PIT export omits DV row for single-shelter CoC (D18)

## 17. Playwright Tests

- [x] 17.1 Test: Analytics tab visible to admin, not to outreach worker
- [x] 17.2 Test: executive summary shows utilization metrics
- [x] 17.3 Test: utilization trends chart renders
- [x] 17.4 Test: shelter performance table loads with RAG indicators
- [x] 17.5 Test: HIC/PIT export buttons visible
- [x] 17.6 Test: batch jobs list shows job names and status
- [x] 17.7 Test: batch job execution history expands on click

## 18. Karate API Tests

- [x] 18.1 `analytics-utilization.feature`: utilization, capacity, geographic endpoints
- [x] 18.2 `analytics-demand.feature`: demand signals, DV summary
- [x] 18.3 `analytics-export.feature`: HIC and PIT CSV exports
- [x] 18.4 `analytics-security.feature`: role-based access to all endpoints
- [x] 18.5 `batch-jobs.feature`: list jobs, trigger run, view executions

## 19. Demo Screenshots

- [x] 19.1 Add screenshot: Analytics tab executive summary
- [x] 19.2 Add screenshot: Utilization trends chart
- [x] 19.3 Add screenshot: Demand signals section
- [x] 19.4 Add screenshot: Batch jobs management panel
- [x] 19.5 Add screenshot: HIC/PIT export
- [x] 19.6 Create `capture-analytics-screenshots.spec.ts`
- [x] 19.7 Create `demo/analyticsindex.html` — analytics walkthrough linked from main index

## 20. Documentation

- [x] 20.1 Update code repo README: add Analytics + Spring Batch section, test counts, file structure, project status
- [x] 20.2 Update runbook: analytics operations (pre-aggregation schedule, batch job monitoring, connection pool tuning, HIC/PIT generation, DV suppression rules)
- [x] 20.3 Update docs repo README: add coc-analytics to completed
- [x] 20.4 Update `docs/schema.dbml`: bed_search_log, daily_utilization_summary, batch tables
- [x] 20.5 Update AsyncAPI if analytics events added

## 21. Regression and PR

- [x] 21.1 Run full backend test suite
- [x] 21.2 Run Playwright suite
- [x] 21.3 Run Karate suite (with observability)
- [x] 21.4 Run Gatling mixed-load test (D15)
- [ ] 21.5 Commit all changes on `feature/coc-analytics` branch
- [ ] 21.6 Push branch, create PR to main
- [ ] 21.7 Merge PR to main
- [ ] 21.8 Delete feature branch
- [ ] 21.9 Tag release (v0.12.0)
