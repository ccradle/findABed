## Context

FABT's `bed_availability` snapshots contain project-level data (beds_total, beds_occupied, population_type) that maps to HMIS Element 2.07 (Bed and Unit Inventory). This data does not contain client PII and does not require client consent to share. NC's Raleigh/Wake CoC uses Bitfocus Clarity; NC Balance of State uses WellSky. The adapter must support multiple vendors per tenant.

## Goals / Non-Goals

**Goals:**
- Push bed inventory and utilization data from FABT to HMIS vendors automatically
- Support multiple HMIS vendors via strategy pattern (Clarity, WellSky, ClientTrack)
- Survive application restarts (outbox pattern)
- Handle vendor downtime gracefully (circuit breaker + dead letter)
- Aggregate DV shelter data before push to prevent small-n identification
- Admin UI tab for export management, data preview, and vendor configuration
- Grafana dashboard for operational monitoring (observability-dependent)
- Audit log all transmissions (HMIS security standards requirement)

**Non-Goals:**
- Client-level HMIS data (UDEs, enrollment, intake) — future change
- Inbound data from HMIS (read-only push, not bidirectional sync)
- HMIS CSV 24-file export for APR/CAPER (requires client data)
- Automated PIT/HIC submission to HDX (manual process using FABT data)

## Decisions

### D1: Module structure

New `org.fabt.hmis` module within the modular monolith. ArchUnit rule: hmis module can access shelter and availability services, not their repositories.

```
hmis/
  api/HmisExportController.java        — Admin endpoints
  domain/HmisOutboxEntry.java          — Outbox record
  domain/HmisAuditEntry.java           — Audit log record
  domain/HmisVendorConfig.java         — Vendor connection config
  repository/HmisOutboxRepository.java
  repository/HmisAuditRepository.java
  service/HmisPushService.java         — Orchestrator: read snapshots, transform, push
  service/HmisTransformer.java         — bed_availability → HMIS 2.07 format
  adapter/HmisVendorAdapter.java       — Strategy interface
  adapter/ClarityAdapter.java          — Bitfocus REST API
  adapter/WellSkyAdapter.java          — HMIS CSV generation
  adapter/ClientTrackAdapter.java      — Eccovia REST API
  adapter/NoOpAdapter.java             — Default (no HMIS configured)
  schedule/HmisPushScheduler.java      — @Scheduled outbox processor
```

### D2: Data transformation — FABT to HMIS Element 2.07

| FABT Field | HMIS Element 2.07 Field |
|-----------|------------------------|
| `shelter.name` | ProjectName |
| `shelter.id` | ProjectID (UUID) |
| `beds_total` | BedInventory |
| `beds_occupied` | (derived utilization) |
| `population_type` | HouseholdType |
| `snapshot_ts` | InventoryStartDate |

The transformer reads the latest `bed_availability` snapshot per shelter/population and maps to the HMIS inventory format. For WellSky, this becomes a CSV row. For Clarity/ClientTrack, it becomes a JSON payload.

### D3: Outbox pattern

1. `HmisPushScheduler` runs on configurable interval (default: every 6 hours)
2. Reads latest snapshots for all non-DV shelters + aggregated DV data
3. Writes `HmisOutboxEntry` rows: one per shelter-vendor combination
4. Outbox processor picks up PENDING entries, transforms, and pushes
5. On success: status → SENT, audit log entry created
6. On failure: retry up to 3 times, then status → DEAD_LETTER
7. Dead letter entries visible in Admin UI for manual retry

### D4: DV shelter aggregation

Before pushing to HMIS, DV shelter data is aggregated:
- Sum `beds_total` across all DV shelters in the tenant
- Sum `beds_occupied` across all DV shelters
- Population type: `DV_SURVIVOR` (aggregated)
- Shelter name: "DV Shelters (Aggregated)" — never individual names
- No address, no lat/lng, no individual shelter ID

This prevents small-n inference (e.g., "the DV shelter with 3 beds has 2 occupied tonight" could identify someone).

### D5: Circuit breaker

Resilience4j circuit breaker per vendor adapter:
- Failure threshold: 5 consecutive failures → OPEN
- Wait in OPEN: 5 minutes before HALF_OPEN
- Success in HALF_OPEN: 2 successes → CLOSED
- Metrics exposed to Prometheus (`fabt_hmis_circuit_breaker_state`)

### D6: Vendor credential management

Credentials stored in tenant config JSONB under `hmis_vendors` array:
```json
{
  "hmis_vendors": [
    {
      "type": "CLARITY",
      "base_url": "https://clarity.example.com/api/v1",
      "api_key_encrypted": "...",
      "enabled": true,
      "push_interval_hours": 6
    }
  ]
}
```

API key entered write-once (same pattern as OAuth2 client secrets). Displayed masked in Admin UI.

### D7: Admin UI — HMIS Export tab

New tab in the Admin panel (after OAuth2 Providers). Access: COC_ADMIN and PLATFORM_ADMIN.

**Sections:**
1. **Export Status** — Last push time, status per vendor, next scheduled push
2. **Data Preview** — Table showing what will be pushed: shelter name, population type, beds_total, beds_occupied, utilization %. DV shelters shown as aggregated row. Filterable by shelter, population type, DV/non-DV.
3. **Export History** — Table of past pushes: timestamp, vendor, record count, status (success/failed/dead-letter). Filterable by date range, vendor, status.
4. **Manual Push** — "Push Now" button (PLATFORM_ADMIN only). Confirmation dialog: "Push bed inventory to HMIS now?"
5. **Vendor Configuration** — List of configured vendors: type, base URL, status (enabled/disabled), last push. Add/edit/remove vendor (PLATFORM_ADMIN only). API key write-once with masked display.

### D8: Grafana dashboard — HMIS Bridge

Separate dashboard `fabt-hmis-bridge` (observability-dependent). Panels:
1. Push rate — `rate(fabt_hmis_push_total[1h])` by vendor
2. Push failure rate — `rate(fabt_hmis_push_failures_total[1h])`
3. Push latency — `fabt_hmis_push_duration_seconds` histogram
4. Circuit breaker state — gauge per vendor
5. Dead letter count — `fabt_hmis_dead_letter_count` gauge
6. Records pushed — `fabt_hmis_records_pushed_total` counter

### D9: Audit logging

`hmis_audit_log` table:
- `id`, `tenant_id`, `vendor_type`, `push_timestamp`, `record_count`, `status` (SUCCESS/FAILED), `error_message`, `payload_hash` (SHA-256 of payload — not the payload itself, to avoid storing data twice)

Required by HMIS security standards. Admin UI shows history from this table.

### D10: Access control

| Action | Role |
|--------|------|
| View HMIS Export tab | COC_ADMIN, PLATFORM_ADMIN |
| View data preview | COC_ADMIN, PLATFORM_ADMIN |
| View export history | COC_ADMIN, PLATFORM_ADMIN |
| Manual push | PLATFORM_ADMIN only |
| Configure vendors | PLATFORM_ADMIN only |
| View Grafana dashboard | Operations (Grafana access) |

Outreach workers and coordinators do NOT see the HMIS Export tab.

### D11: Filtering in Admin UI

- **Data preview**: filter by shelter name, population type, DV/non-DV toggle
- **Export history**: filter by date range, vendor, status (success/failed/dead-letter)
