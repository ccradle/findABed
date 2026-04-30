## ADDED Requirements

### Requirement: Capture script enumerates all capture specs
`demo/capture.sh` SHALL invoke every `capture-*.spec.ts` file in the e2e Playwright directory by explicit enumeration, not by glob. Specs added to the directory without being added to `capture.sh` are a regression because the script currently only invokes one of nine such specs.

#### Scenario: All current capture specs enumerated
- **WHEN** `capture.sh` is read post-change
- **THEN** the script SHALL invoke `capture-screenshots.spec.ts`, `capture-analytics-screenshots.spec.ts`, `capture-dv-screenshots.spec.ts`, `capture-hmis-screenshots.spec.ts`, `capture-mobile-header.spec.ts`, `capture-notification-screenshots.spec.ts`, `capture-offline-screenshots.spec.ts`, `capture-platform-operator-screenshots.spec.ts`, `capture-totp-screenshots.spec.ts`, AND `capture-reentry-screenshots.spec.ts` (the new file)
- **AND** the enumeration SHALL be explicit (one invocation or one entry per spec), not a glob

#### Scenario: Script accepts a filter argument
- **WHEN** an operator runs `capture.sh reentry`
- **THEN** the script SHALL invoke only the spec(s) whose filename matches the filter
- **AND** the script SHALL exit 0 if at least one spec matched
- **AND** the script SHALL exit non-zero with a clear error if no spec matched

### Requirement: Capture script defaults to nginx URL, not Vite default
`demo/capture.sh` SHALL run Playwright with `BASE_URL=http://localhost:8081` (nginx) as the default, because per `feedback_check_ports_before_assuming` screenshots captured against the bare Vite dev server (5173) do not match the production CSS/SW environment.

#### Scenario: Default BASE_URL is nginx
- **WHEN** `capture.sh` is invoked without an explicit `BASE_URL` env override
- **THEN** the Playwright invocations SHALL use `BASE_URL=http://localhost:8081`

#### Scenario: BASE_URL override is honored
- **WHEN** an operator sets `BASE_URL=http://localhost:5173` and invokes `capture.sh`
- **THEN** the script SHALL honor the override

### Requirement: Reentry screenshot inventory exists in screenshots dir
After `capture-reentry-screenshots.spec.ts` runs successfully against a stack with V95 reentry seed loaded, six new PNGs SHALL be present in `demo/screenshots/`.

#### Scenario: Six new PNGs produced
- **WHEN** the reentry capture spec completes successfully
- **THEN** `demo/screenshots/` SHALL contain `reentry-01-advanced-search-filters.png`, `reentry-02-search-results-filtered.png`, `reentry-03-shelter-detail-eligibility.png`, `reentry-04-hold-dialog-attribution.png`, `reentry-05-admin-reservation-settings.png`, `reentry-06-no-match-failure-path.png`
- **AND** each file SHALL be a valid non-empty PNG
