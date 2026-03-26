## Context

The existing dev seed creates 10 shelters (9 non-DV + 1 DV) with static availability snapshots. The analytics module (v0.12.0) introduced `bed_search_log`, `daily_utilization_summary`, and Spring Batch tables that are empty in a fresh dev environment. The demo walkthrough screenshots and accessibility audit need populated data.

## Goals / Non-Goals

**Goals:**
- Generate 28 days of realistic activity data across all seed shelters
- Data patterns should tell a visible story (weekday/weekend variation, seasonal trends, demand spikes)
- Idempotent — safe to run multiple times
- Fast — completes in under 5 seconds

**Non-Goals:**
- Client-level data (FABT stores no PII)
- Perfect statistical accuracy — plausible is sufficient
- Production seed data — this is dev/demo only

## Decisions

### D1: Data generation approach — SQL not Java

Use a single SQL script with `generate_series()` and `random()` to create backdated data. This is faster than Java, has no dependency on Spring context, and can be run independently via psql. The script runs after Flyway migrations and shelter seed data.

### D2: Activity data patterns

Generate realistic variation using these patterns:

**Bed availability snapshots** (4 per shelter per day, ~6h apart):
- Base occupancy: 60-90% of beds_total (varies by shelter)
- Weekday boost: +10-15% occupancy Mon-Thu
- Weekend dip: -5-10% Fri-Sun
- Random daily noise: ±5%
- One shelter ("Downtown Warming Station") at 95%+ consistently (high-demand story)
- One shelter ("New Beginnings Family Shelter") at 30-40% (underutilized story)

**Bed search log** (50-120 searches per day):
- Population type distribution: 40% SINGLE_ADULT, 25% FAMILY_WITH_CHILDREN, 15% VETERAN, 10% all/unfiltered, 10% other
- Zero-result searches: 5-15% of total (higher on weeknights)
- Weekday peak: 1.5x weekend volume

**Reservations** (10-25 per day):
- 65% confirmed (realistic conversion rate)
- 15% expired (unmet demand proxy)
- 10% cancelled
- 10% still held (most recent day only)
- Hold duration: 10-40 minutes before resolution

**Daily utilization summary** (pre-aggregated):
- Computed from the generated snapshots
- One row per (tenant, shelter, population_type, date)
- avg_utilization, max_occupied, min_available, snapshot_count

### D3: Batch job execution history

Insert directly into Spring Batch tables to simulate completed job runs:
- 28 `dailyAggregation` executions (one per day, all COMPLETED)
- 4 `hmisPush` executions (weekly, 3 COMPLETED + 1 FAILED for demo)
- 1 `hicExport` execution (COMPLETED)
- Step-level detail for each execution (read/write/skip counts)

### D4: Integration with dev-start.sh

Add the seed script execution after the existing `seed-data.sql` step in `dev-start.sh`. Run it every time (idempotent via DELETE + INSERT for activity tables — shelter data is untouched). No flag needed — activity data is always useful in dev.

### D5: Idempotency

The script DELETEs from activity-only tables before inserting:
- `DELETE FROM daily_utilization_summary` (safe — no FK dependencies)
- `DELETE FROM bed_search_log` (safe — no FK dependencies)
- `DELETE FROM reservation WHERE created_at < NOW() - INTERVAL '1 hour'` (preserves any active test holds)
- Batch tables: DELETE from BATCH_STEP_EXECUTION_CONTEXT, BATCH_JOB_EXECUTION_CONTEXT, BATCH_STEP_EXECUTION, BATCH_JOB_EXECUTION_PARAMS, BATCH_JOB_EXECUTION, BATCH_JOB_INSTANCE (order matters for FK constraints)

Shelter and bed_availability seed data from the existing seed script is NOT touched.
