## Why

FABT tracks real-time bed availability across shelters, but this data stays in a silo. CoCs are required by HUD to report shelter bed inventory and utilization through HMIS (Homeless Management Information System). Today, this reporting is manual — coordinators re-enter numbers into their HMIS vendor (Bitfocus Clarity, WellSky, Eccovia ClientTrack).

FABT already stores exactly the data HMIS needs for project-level reporting: `beds_total`, `beds_occupied`, `population_type`, shelter name/address. This maps directly to HMIS Element 2.07 (Bed and Unit Inventory) and the Housing Inventory Count (HIC). Critically, this is **project-level descriptor data, not client PII** — no client consent is required to share it.

The HMIS bridge automates the push from FABT to HMIS vendors, eliminating manual double-entry and ensuring HMIS always has current bed inventory data.

## What Changes

- **Vendor adapter module**: New `hmis` module within the modular monolith. Strategy pattern per HMIS vendor — `ClarityAdapter` (Bitfocus REST API), `WellSkyAdapter` (HMIS CSV generation), `ClientTrackAdapter` (Eccovia REST API)
- **Outbox pattern**: Push intent written to DB, async worker sends. Survives restart. Dead letter table for failed pushes with manual retry.
- **Circuit breaker**: Resilience4j per vendor endpoint with auto-recovery
- **DV shelter aggregation**: DV shelter bed counts aggregated across all DV shelters before push — never individual DV shelter occupancy (small-n inference risk)
- **Admin UI tab**: "HMIS Export" tab in the Admin panel — export status/history, data preview, manual push trigger, vendor credential management
- **Grafana dashboard**: HMIS Bridge operations dashboard (push rate, failure rate, latency, circuit breaker state) — available only with observability stack
- **Audit logging**: Append-only log of all HMIS data transmissions (required by HMIS security standards)
- **Tenant-scoped config**: Each CoC/tenant may use different HMIS vendors with separate credentials and push schedules
- **All changes on feature branch** `feature/hmis-bridge` from main — PR to main after full test suite passes

## Capabilities

### New Capabilities
- `hmis-push`: Async push of bed inventory data to HMIS vendors
- `hmis-admin`: Admin UI for export management, preview, and vendor configuration
- `hmis-monitoring`: Grafana dashboard for HMIS bridge operations (observability-dependent)

### Modified Capabilities
- `shelter-management`: Shelter data now flows to external HMIS systems

## Impact

- **New files (backend)**: `hmis` module — adapters (Clarity, WellSky, ClientTrack), transformer (bed_availability → HMIS 2.07), outbox/scheduler, circuit breaker config, audit log
- **New migration**: `V22__create_hmis_outbox.sql` — outbox table, dead letter table, audit log table
- **New files (frontend)**: HMIS Export admin tab component
- **New files (infra)**: Grafana dashboard JSON (`fabt-hmis-bridge.json`)
- **Modified files**: `SecurityConfig.java` (new endpoints), `seed-data.sql` (HMIS config in tenant JSONB), `README.md`, `runbook.md`
- **Risk**: External system dependency — HMIS vendors may be down, rate-limited, or reject data. Circuit breaker and dead letter patterns mitigate.
- **Privacy**: No client PII flows. DV shelter data aggregated before push. Vendor credentials stored encrypted.
- **Branch strategy**: All changes on `feature/hmis-bridge` from main, PR after full test suite passes
