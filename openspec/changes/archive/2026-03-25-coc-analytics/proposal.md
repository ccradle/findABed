## Why

CoCs compete annually for $3.5B+ in HUD funding. Their applications are scored on system performance metrics, data quality, and demonstrated need. Today, CoC administrators using FABT have real-time bed availability but no way to analyze trends, generate HUD-required exports, or quantify unmet demand — the data exists in the database but there's no analytics layer.

FABT's append-only `bed_availability` snapshots, reservation lifecycle data, DV referral tokens, surge events, and HMIS audit log contain 18+ directly computable metrics without any client PII. This includes HIC data for the annual Housing Inventory Count, sheltered PIT count data, bed utilization trends, demand proxies from reservation expiry rates, and geographic coverage analysis.

Adding an analytics dashboard and HUD export tools transforms FABT from an operational tool into a strategic asset for CoC planning, grant applications, and HUD compliance.

## What Changes

- **Analytics API**: New endpoints for querying utilization trends, demand signals, capacity metrics, and DV aggregate analytics. All aggregate, no client PII.
- **Bed search log**: New `bed_search_log` table to capture searches returning zero results — the strongest unmet demand signal for HUD grant applications.
- **Pre-aggregation summary table**: `daily_utilization_summary` populated by Spring Batch — analytics queries hit this instead of scanning millions of raw snapshots.
- **Separate HikariCP connection pools**: OLTP pool (10 connections) isolated from analytics pool (3 connections, read-only, 30s timeout). Analytics can never starve bed search.
- **BRIN index**: On `bed_availability.snapshot_ts` for efficient analytics time-range queries with near-zero insert cost.
- **Spring Batch**: For complex jobs (pre-aggregation, HMIS push, HIC/PIT export) with execution history, chunk processing, retry/skip, and restart from failure. Simple jobs remain @Scheduled. Available in all tiers (Lite, Standard, Full) — zero additional infrastructure.
- **Job management Admin UI**: Schedule editing, run history with step-level detail, manual trigger, restart failed jobs. Available to all CoC admins.
- **CoC Admin Analytics Dashboard**: New Admin UI tab with 7+ sections — Executive Summary, Utilization Trends, Shelter Performance, Demand Signals, Geographic View (react-leaflet), HMIS Health, HIC/PIT Export Tools, Batch Jobs Management.
- **HIC/PIT Export**: One-click generation of Housing Inventory Count and sheltered PIT count data in HUD-compatible format.
- **DV analytics aggregation**: Minimum cell size of 5, weekly/monthly only, never individual DV shelters, role-gated to dvAccess users.
- **HMIS DV cell suppression (compliance fix)**: `HmisTransformer.buildInventory()` currently emits DV aggregate data even when a CoC has only one DV shelter — making the aggregate identical to the individual, which defeats aggregation. Fix: suppress DV aggregate output when fewer than 3 distinct DV shelters exist in the CoC (consistent with CMS small-cell suppression guidance). Apply same logic to HIC/PIT exports and analytics DV summary. Flagged by Dr. Kenji Watanabe as a compliance defect.
- **Grafana dashboard**: CoC Analytics + Spring Batch job metrics (observability-dependent).
- **Gatling mixed-load test**: Verifies bed search p99 stays under 200ms during concurrent analytics queries.
- **All changes on feature branch** `feature/coc-analytics` from main — PR to main after full test suite passes.

## Capabilities

### New Capabilities
- `coc-analytics-dashboard`: Admin UI analytics dashboard with utilization, demand, geographic, and HUD export tools
- `coc-analytics-api`: REST API for querying aggregate metrics
- `hic-pit-export`: One-click HIC and sheltered PIT count generation
- `bed-search-demand`: Unmet demand tracking from bed search zero-result events

### Modified Capabilities
- `bed-availability-query`: Bed search logs zero-result events to `bed_search_log`

## Impact

- **New migration**: `V23__create_analytics_tables.sql` — `bed_search_log` table
- **New files (backend)**: `analytics` module — `AnalyticsService`, `AnalyticsController`, `HicPitExportService`, `BedSearchLogger`
- **New files (frontend)**: Analytics admin tab with charts (utilization trends, demand signals, geographic map)
- **New files (infra)**: Grafana dashboard JSON (`fabt-coc-analytics.json`)
- **Modified files**: `BedSearchService.java` (log zero-result searches), `SecurityConfig.java`, `AdminPanel.tsx`, i18n EN/ES
- **Risk**: Analytics queries on large snapshot tables may be slow — consider materialized views or periodic aggregation for historical data.
- **Privacy**: No client PII. DV shelter data aggregated with minimum cell size of 5 beds AND minimum 3 distinct DV shelters. Geographic view excludes DV shelters.
- **Modified files (additional)**: `HmisTransformer.java` (add small-cell suppression before DV aggregate emit)
- **Branch strategy**: All changes on `feature/coc-analytics` from main, PR after full test suite passes
