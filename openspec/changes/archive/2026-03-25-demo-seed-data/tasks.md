## 1. Branch Setup

- [x] 1.1 Create branch `feature/demo-seed-data` from main

## 2. Seed Script — Bed Availability Snapshots

- [x] 2.1 Create `infra/scripts/demo-activity-seed.sql`
- [x] 2.2 Generate 28 days of backdated bed_availability snapshots (4 per shelter per day)
- [x] 2.3 Apply weekday/weekend occupancy variation pattern
- [x] 2.4 Create high-demand shelter story (Downtown Warming Station at 92%+)
- [x] 2.5 Create underutilized shelter story (New Beginnings at 35%)
- [x] 2.6 Include DV shelter snapshots (for aggregation testing)

## 3. Seed Script — Bed Search Log

- [x] 3.1 Generate 50-120 bed_search_log entries per day for 28 days
- [x] 3.2 Distribute population types: 40% SINGLE_ADULT, 25% FAMILY, 15% VETERAN, 10% unfiltered, 10% other
- [x] 3.3 Generate ~12% zero-result searches (higher on weeknights)

## 4. Seed Script — Reservations

- [x] 4.1 Generate 10-25 reservations per day for 28 days
- [x] 4.2 Apply realistic lifecycle: 70% CONFIRMED, 15% EXPIRED, 10% CANCELLED (from weighted array)
- [x] 4.3 Set realistic hold durations (10-40 minutes before resolution)

## 5. Seed Script — Daily Utilization Summary

- [x] 5.1 Pre-compute daily_utilization_summary from generated snapshots
- [x] 5.2 One row per (tenant, shelter, population_type, date) for all 28 days

## 6. Seed Script — Batch Job History

- [x] 6.1 Insert 28 dailyAggregation job executions (all COMPLETED)
- [x] 6.2 Insert 4 hmisPush job executions (3 COMPLETED, 1 FAILED)
- [x] 6.3 Insert 1 hicExport execution (COMPLETED)
- [x] 6.4 Include step-level detail (read/write/skip counts) for each execution

## 7. Idempotency

- [x] 7.1 Add DELETE statements for activity tables at top of script (respecting FK order)
- [x] 7.2 Preserve shelter and shelter_constraints data (no DELETE on those tables)
- [x] 7.3 Test: run script twice, verify no duplicate data

## 8. Integration

- [x] 8.1 Update `dev-start.sh`: run demo-activity-seed.sql after existing seed-data.sql
- [x] 8.2 Verify seed completes in under 5 seconds
- [x] 8.3 Verify analytics dashboard shows populated data after seed

## 9. Exception Logging Hardening

- [x] 9.1 Add Logger + log.warn to GlobalExceptionHandler (5 handlers)
- [x] 9.2 Add log.debug to JwtAuthenticationFilter catch block
- [x] 9.3 Add log.warn to ShelterService.getDvAddressPolicy() (2 catches)
- [x] 9.4 Add log.warn to ReferralTokenService.getDvReferralExpiryMinutes() (2 catches)
- [x] 9.5 Add log.warn to ReservationService.getHoldDurationMinutes() (2 catches)
- [x] 9.6 Add log.warn to HmisConfigService.getVendors() (3 catches)
- [x] 9.7 Add log.warn to BatchJobController (4 catch blocks)
- [x] 9.8 Add log.debug to AuthController.refresh()
- [x] 9.9 Add log.error to HmisPushService.sha256()
- [x] 9.10 Add log.warn to OAuth2TestConnectionController, TenantController, DvAddressPolicy
- [x] 9.11 Add log.debug to DataAgeResponseAdvice, HsdsImportAdapter

## 10. Performance — Connection Pool Sizing (Little's Law)

- [x] 10.1 Diagnose Gatling 15% failure rate via Prometheus hikaricp_connections_timeout_total (681 timeouts)
- [x] 10.2 Apply Little's Law: 70 peak × 0.17s hold = 12 needed + 60% headroom = 20
- [x] 10.3 Update application.yml: maximum-pool-size=20, connection-timeout=5000, leak-detection-threshold=10000

## 11. Performance — Bed Search Query Optimization

- [x] 11.1 Create V25__add_tenant_latest_index.sql: composite index (tenant_id, shelter_id, population_type, snapshot_ts DESC)
- [x] 11.2 Rewrite BedAvailabilityRepository.findLatestByTenantId() from DISTINCT ON to lateral join skip-scan
- [x] 11.3 Verify query plan: 250ms seq scan → 36ms lateral join
- [x] 11.4 Verify Gatling: bed search p99 152ms, 0% failures, all SLO assertions pass

## 12. Verification

- [x] 12.1 Verify utilization trends: 364 data points (28 days × 13 shelter/pop combos)
- [x] 12.2 Verify executive summary: 2,079 searches, 233 zero-result, 73.8% conversion, 22.9% expiry
- [x] 12.3 Verify batch jobs: 4 jobs with last execution status, hmisPush shows FAILED execution
- [x] 12.4 Verify demand signals: non-zero zero-result count, realistic rates
- [ ] 12.5 Re-capture analytics screenshots with populated data (deferred to wcag-accessibility-audit)

## 13. Regression and PR

- [x] 13.1 Run full backend test suite (236 tests, 0 failures)
- [x] 13.2 Run Playwright suite (100 tests, 0 failures)
- [x] 13.3 Run Karate suite (73 tests, 0 failures)
- [x] 13.4 Run Gatling mixed-load (0% failures, all SLO passed)
- [x] 13.5 Commit (3 separate commits: seed, exception logging, performance)
- [x] 13.6 Push, create PR (#10)
- [x] 13.7 Merge to main
- [ ] 13.8 Tag release (v0.12.1)
