## Why

The dev environment currently seeds 10 shelters with a single snapshot each — all from the current timestamp. This means the analytics dashboard shows flat metrics (0% utilization trend, single data point on charts, no search demand history, no batch job execution history). Demo walkthroughs, accessibility reviews, and developer onboarding all need realistic multi-week data to evaluate the platform meaningfully.

A dedicated seed script that generates 3-4 weeks of backdated activity would:
- Populate utilization trend charts with realistic daily variation
- Create zero-result search entries for unmet demand visualization
- Generate reservation lifecycle data (held → confirmed/expired/cancelled) with realistic conversion rates
- Pre-compute `daily_utilization_summary` rows so the analytics dashboard has chart data immediately
- Create batch job execution history so the job management UI isn't empty
- Make demo screenshots and accessibility audits representative of production use

## What Changes

- **New seed script**: `infra/scripts/demo-activity-seed.sql` — generates 28 days of backdated bed_availability snapshots, bed_search_log entries, reservation lifecycle events, daily_utilization_summary pre-aggregation, and Spring Batch execution history
- **Integration with dev-start.sh**: The script runs automatically after the existing shelter seed data, always-on for dev
- **Idempotent**: Running the seed multiple times doesn't duplicate data — DELETEs from activity tables before re-inserting
- **No production impact**: Seed SQL only runs via dev-start.sh
- **Exception logging hardening**: 12 Java files with 22 catch blocks that silently swallowed exceptions now have logging. GlobalExceptionHandler, JwtAuthenticationFilter, DV-safety config parsers, HMIS config, batch controller, auth refresh, SHA-256 hash. 8 HIGH severity findings.
- **Connection pool sizing (Little's Law)**: OLTP pool increased from 10 to 20 based on Little's Law calculation (70 peak concurrent × 0.17s hold = 12 needed + 60% headroom). Connection timeout set to 5s (fail fast). Leak detection at 10s.
- **Bed search query optimization**: `V25__add_tenant_latest_index.sql` — composite index `(tenant_id, shelter_id, population_type, snapshot_ts DESC)`. Query rewritten from DISTINCT ON (250ms seq scan) to lateral join skip-scan (36ms). Reduces connection hold time from 0.17s to ~0.04s.

## Capabilities

### New Capabilities
- `demo-seed-data`: Realistic multi-week activity data generation for dev/demo environments

### Modified Capabilities

## Impact

- **New file**: `infra/scripts/demo-activity-seed.sql`
- **New migration**: `V25__add_tenant_latest_index.sql` — composite index for bed search performance
- **Modified files**: `dev-start.sh` (seed step), `application.yml` (pool sizing), `BedAvailabilityRepository.java` (lateral join query), `GlobalExceptionHandler.java` + 11 other Java files (exception logging)
- **Schema change**: V25 adds one index (no table changes)
- **Risk**: Pool sizing and query changes affect all environments (positive — faster queries, better pool utilization)
