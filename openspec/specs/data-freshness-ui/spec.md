## Purpose

Data freshness badge Playwright tests with test-only backdating endpoint.

## ADDED Requirements

### Requirement: data-freshness-badge-e2e
The E2E suite SHALL verify that data freshness badges render correctly in the UI. A test-only `@Profile("test")` backdating endpoint enables deterministic STALE testing.

#### Scenario: FRESH badge renders after recent update
- **WHEN** availability was updated within the last 2 hours
- **THEN** the search result shows a FRESH badge (green indicator)

#### Scenario: STALE badge renders after backdating
- **WHEN** the test-only endpoint backdates snapshot_ts to 9 hours ago
- **THEN** the search result shows a STALE badge (red indicator)
