## Context

FABT stores append-only bed availability snapshots, reservation lifecycle events, DV referral tokens, surge events, and HMIS audit logs. All project-level data, no client PII. CoCs need this data analyzed for HUD reporting (HIC, PIT), grant applications (unmet demand), and operational planning (utilization trends, geographic coverage).

## Goals / Non-Goals

**Goals:**
- Provide aggregate analytics from existing FABT data without requiring client PII
- Enable one-click HIC and sheltered PIT count exports
- Track unmet demand via bed search zero-result logging
- Spring Batch for complex jobs (pre-aggregation, HMIS push, HIC/PIT export) with execution history, restart, chunk processing
- Admin UI job management: schedule editing, run history, step-level detail, manual trigger, restart failed jobs
- Isolate analytics queries from OLTP via separate HikariCP connection pool
- Display utilization trends, demand signals, and geographic coverage in an Admin UI dashboard
- Aggregate DV shelter data with minimum cell size of 5, never individual shelters
- Grafana dashboard for analytics operational monitoring (observability-dependent)

**Non-Goals:**
- Client-level analytics (SPMs 1,2,4,5,7, APR/CAPER, LSA) — requires HMIS client data
- Unsheltered PIT count — requires field survey data
- Predictive modeling or forecasting
- Public-facing dashboards (admin-only for now)

## Decisions

### D1: Analytics module structure

New `org.fabt.analytics` module within the modular monolith. ArchUnit rule: analytics module can access shelter, availability, reservation, referral, surge, and hmis services — not their repositories.

### D2: Bed search demand logging

Add `bed_search_log` table:
```
bed_search_log
  id              UUID PK
  tenant_id       UUID FK → tenant
  population_type VARCHAR(50)
  results_count   INTEGER
  search_ts       TIMESTAMPTZ
```

`BedSearchService.search()` logs every search — especially those returning 0 results. This is the strongest unmet demand signal: "47 searches for SINGLE_ADULT beds with zero results last Tuesday night."

### D3: Analytics API endpoints

All endpoints require COC_ADMIN or PLATFORM_ADMIN. All return aggregate data, no PII.

- `GET /api/v1/analytics/utilization` — utilization rates over time, filterable by shelter, population type, date range
- `GET /api/v1/analytics/demand` — reservation conversion/expiry rates, zero-result search counts, by period
- `GET /api/v1/analytics/capacity` — total system capacity trends, beds added/removed over time
- `GET /api/v1/analytics/dv-summary` — aggregated DV shelter stats (minimum cell size 5), acceptance/rejection rates
- `GET /api/v1/analytics/geographic` — shelter locations with utilization data (DV shelters excluded from map)
- `GET /api/v1/analytics/hic` — HIC export data for a specific date (default: latest January snapshot)
- `GET /api/v1/analytics/pit` — Sheltered PIT count for a specific date
- `GET /api/v1/analytics/hmis-health` — HMIS push success/failure rates from audit log

### D4: DV aggregation rules

- Minimum cell size: 5 — suppress any aggregate representing fewer than 5 beds at individual DV shelters
- Never display individual DV shelter names, IDs, or locations in analytics
- DV data shown only as "DV Shelters (Aggregated)" row
- Time granularity: weekly or monthly only for DV (no daily/hourly)
- Geographic view: DV shelters excluded from map markers
- Role-gated: all DV analytics require `dvAccess=true`
- Referral metrics: suppress if total referrals < 5 in the period

### D5: Admin UI — Analytics tab

New "Analytics" tab in the Admin panel. Access: COC_ADMIN, PLATFORM_ADMIN. Seven sections:

1. **Executive Summary** — Total beds, occupied, available, on hold. System utilization rate with 65-105% threshold (green/amber/red). Active surge count. DV aggregate stats.

2. **Utilization Trends** — Time-series chart (daily/weekly/monthly). Filter by population type. Year-over-year overlay. Surge event markers.

3. **Shelter Performance** — Table with per-shelter utilization rate (RAG indicators), beds total/occupied/available, last updated, reservation conversion rate. DV shelters shown only in aggregate row.

4. **Demand Signals** — Reservation volume over time. Expiry rate (unmet demand proxy). Zero-result search count. Hold-to-confirmation time trend.

5. **Geographic View** — Map with shelter markers colored by utilization. Population type filter. DV shelters excluded. Coverage gap visualization.

6. **HMIS Health** — Push success/failure rate. Last push per vendor. Dead letter count.

7. **HIC/PIT Export** — Date picker (default last January). One-click CSV export for HIC. One-click sheltered PIT count export. Historical comparison.

### D6: HIC export format

CSV with columns matching HUD HIC submission requirements:
- ProjectID, ProjectName, ProjectType, HouseholdType, BedType, AvailabilityCategory
- BedInventory, UnitInventory
- TargetPopulation (from population_type)
- HMISParticipation (always yes for FABT shelters)

DV shelters included in HIC but with suppressed address/location per existing redaction policy.

### D7: Sheltered PIT count format

CSV with:
- CoC code (from tenant)
- ProjectType (Emergency Shelter)
- HouseholdType
- TotalPersons (beds_occupied on PIT night)
- Population breakdowns by type

### D8: Grafana CoC Analytics dashboard (observability-dependent)

Separate dashboard `fabt-coc-analytics`. Panels:
1. System utilization rate — gauge with 65-105% thresholds
2. Zero-result search rate — `rate(fabt_search_zero_results_total[1h])`
3. Reservation conversion rate — accepted / total
4. Bed capacity trend — total beds over time
5. Demand vs capacity — overlay of search volume and available beds
6. Stale shelter count — shelters not updating

### D9: Performance considerations

Analytics queries on the full `bed_availability` table (append-only, growing) could be slow. Mitigations:
- Use `DISTINCT ON` for latest-snapshot queries (already indexed)
- For historical trends, query with date range filters using `snapshot_ts` index
- Consider adding a `daily_utilization_summary` materialized view if query performance degrades
- Cache analytics responses with 5-minute TTL (utilization doesn't change second-by-second)

### D10: Separate HikariCP connection pools (OLTP vs Analytics)

Analytics queries (multi-month aggregations, full scans) can evict hot index pages from PostgreSQL's shared buffers, causing bed search p99 to spike. Mitigate with dual pools:

**OLTP pool** (primary, used by all existing repositories):
- `maximum-pool-size: 10`
- `connection-timeout: 5000` (5s — fail fast)
- `leak-detection-threshold: 10000` (10s)

**Analytics pool** (used by analytics module only):
- `maximum-pool-size: 3` (limit analytics concurrency)
- `connection-timeout: 30000` (30s — analytics can wait)
- `read-only: true`
- `SET LOCAL statement_timeout = '30s'` on every connection (kill runaway queries)
- `SET LOCAL work_mem = '256MB'` (allow larger sorts for aggregation)

Configure via `@Configuration` with `@Primary` DataSource for OLTP and `@Qualifier("analyticsDataSource")` for analytics. Analytics module injects the qualified DataSource. All other modules use the primary pool unchanged.

Available in all tiers (Lite, Standard, Full) — no additional infrastructure.

### D11: BRIN index for analytics time-range queries

Add BRIN index on `bed_availability.snapshot_ts` in the V23 migration. BRIN is ideal because `bed_availability` is append-only (snapshot_ts perfectly correlates with physical row order):
- Tiny: ~0.1% the size of an equivalent B-tree
- Near-zero insert cost
- Effective for the `WHERE snapshot_ts BETWEEN ? AND ?` filters in all analytics queries

Keep the existing B-tree indexes for OLTP unchanged.

### D12: Pre-aggregation summary table

`daily_utilization_summary` — populated by a Spring Batch job running at 3 AM:
- One row per (tenant, shelter, population_type, date)
- Stores: avg_utilization, max_occupied, min_available, snapshot_count
- Analytics dashboard queries hit this table (365 rows/shelter/year) instead of raw snapshots (1,460+/shelter/year)
- Batch job uses chunk processing: read snapshots for yesterday, compute aggregates, upsert summaries

### D13: Spring Batch for complex jobs

Add `spring-boot-starter-batch`. Jobs use Spring Batch; simple cleanup jobs remain @Scheduled.

**Spring Batch jobs:**
- Daily pre-aggregation → chunk-oriented (read snapshots, compute, write summaries), restartable
- HMIS push → chunk-oriented (read outbox, push to vendor, mark sent), retry/skip on HTTP errors
- HIC export → parameterized (reportDate), prevents duplicate generation
- PIT export → parameterized, same pattern as HIC

**Keep as @Scheduled:**
- Reservation expiry (30s cycle, single query)
- Token purge (hourly, single DELETE)
- Token expiry (60s cycle, small loop)
- Stale shelter monitor, DV canary, temperature check

**Configuration:**
- `spring.batch.job.enabled=false` — don't auto-run on startup
- `spring.batch.jdbc.initialize-schema=never` — Flyway manages DDL
- Batch tables in existing PostgreSQL (V24 migration)
- `@Scheduled` methods trigger batch jobs via `JobLauncher`
- Cron expressions stored in tenant config JSONB — editable from Admin UI

**Available in all tiers** — same JVM, same PostgreSQL, zero additional infrastructure.

### D14: Job management Admin UI

New "Batch Jobs" section in the Analytics tab (or Admin panel). Available to COC_ADMIN (view only) and PLATFORM_ADMIN (full control).

**Job list view:**
- Job name, current cron schedule, enabled/disabled toggle, last run status/time, next scheduled run
- PLATFORM_ADMIN: edit cron expression, enable/disable, "Run Now" with date picker

**Job execution history:**
- Table: job name, start time, end time, duration, status (COMPLETED/FAILED/STARTED), exit message
- Click to expand: step-level detail — step name, read count, write count, skip count, commit count, status
- Filter by job name, status, date range
- Failed jobs: error message + "Restart" button (calls `JobOperator.restart()`)

**Backed by:**
- `JobExplorer` API — queries BATCH_* tables, no custom SQL
- `JobOperator` API — start, stop, restart programmatically
- Dynamic scheduling via `ScheduledTaskRegistrar` — reads cron from tenant config instead of hardcoded annotations

### D15: Gatling mixed-load performance test

New Gatling simulation: `AnalyticsMixedLoadSimulation.java`
- Baseline: 50 concurrent bed searches + 20 availability updates
- Mixed: same OLTP load + 3 concurrent analytics queries (utilization, demand, HIC export)
- Measure: bed search p99 before and after analytics load
- Threshold: bed search p99 must stay under 200ms during analytics
- Run as part of regression suite

### D16: Charting and mapping libraries

- **Charts**: Recharts — React-native, lightweight, good for time-series and bar charts
- **Map**: react-leaflet with Leaflet — open-source, no API key required. Renders shelter markers colored by utilization on OpenStreetMap tiles. DV shelters excluded from map per D4.

### D17: Export formats

- HIC: CSV (HUD format)
- PIT: CSV (HUD format)
- Analytics data: JSON (API) + CSV download option from Admin UI
