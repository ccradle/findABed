# Capability: hmis-push

## Purpose
Pushes bed inventory data to HMIS vendors on a scheduled basis using the outbox pattern, with vendor-specific adapters and comprehensive audit logging.

## Requirements

### Requirement: hmis-bed-inventory-push
The system SHALL push bed inventory data to configured HMIS vendors on a scheduled interval using the outbox pattern.

#### Scenario: Scheduled push sends bed inventory to vendor
- **WHEN** the push scheduler runs
- **THEN** it reads the latest bed_availability snapshot per shelter/population
- **AND** transforms to HMIS Element 2.07 format
- **AND** pushes to each configured and enabled vendor
- **AND** creates an audit log entry

#### Scenario: DV shelter data is aggregated before push
- **WHEN** the push includes DV shelters
- **THEN** DV shelter beds are summed across all DV shelters in the tenant
- **AND** no individual DV shelter name, address, or ID appears in the push
- **AND** the aggregated row shows "DV Shelters (Aggregated)"

#### Scenario: Push survives application restart (outbox pattern)
- **WHEN** a push is initiated and the application restarts before completion
- **THEN** PENDING outbox entries are picked up and retried on restart

#### Scenario: Failed push retries then dead-letters
- **WHEN** a push to a vendor fails 3 consecutive times
- **THEN** the outbox entry status is set to DEAD_LETTER
- **AND** the entry is visible in the Admin UI for manual retry

#### Scenario: Circuit breaker opens on repeated failures
- **WHEN** 5 consecutive pushes to a vendor fail
- **THEN** the circuit breaker opens and no pushes are attempted for 5 minutes
- **AND** the circuit breaker state is exposed as a Prometheus metric

### Requirement: hmis-vendor-adapters
The system SHALL support multiple HMIS vendor integrations via a strategy pattern.

#### Scenario: Clarity adapter pushes via REST API
- **WHEN** a vendor of type CLARITY is configured
- **THEN** the push sends a JSON payload to the Clarity API endpoint

#### Scenario: WellSky adapter generates HMIS CSV
- **WHEN** a vendor of type WELLSKY is configured
- **THEN** the push generates an HMIS-format CSV file for upload

#### Scenario: No vendor configured uses NoOp adapter
- **WHEN** no HMIS vendor is configured for a tenant
- **THEN** no push is attempted and no error is logged

### Requirement: hmis-audit-logging
The system SHALL maintain an append-only audit log of all HMIS data transmissions.

#### Scenario: Successful push creates audit entry
- **WHEN** a push to a vendor succeeds
- **THEN** an audit entry records: tenant, vendor, timestamp, record count, status=SUCCESS, payload hash

#### Scenario: Failed push creates audit entry with error
- **WHEN** a push to a vendor fails
- **THEN** an audit entry records: status=FAILED, error message
