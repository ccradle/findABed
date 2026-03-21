## Purpose

CI pipeline, test data management, environment configuration, and reporting infrastructure for E2E test suites.

## Requirements

### Requirement: ci-pipeline
The E2E suite SHALL run automatically in CI (GitHub Actions) on every push to main and on pull requests. Playwright UI tests and Karate API tests run in parallel. Total CI time target: under 5 minutes.

#### Scenario: CI runs both test suites
- **WHEN** code is pushed to main or a PR is opened
- **THEN** GitHub Actions starts the E2E workflow
- **AND** Karate API tests and Playwright UI tests execute in parallel
- **AND** test reports are uploaded as build artifacts

#### Scenario: CI failure blocks merge
- **WHEN** any E2E test fails in a PR check
- **THEN** the PR status check is marked as failed
- **AND** the test report artifact identifies which tests failed

### Requirement: test-data-management
The E2E suite SHALL manage test data so that tests are isolated and repeatable. The baseline is seed-data.sql. Tests that create data use unique identifiers and clean up.

#### Scenario: Tests use seed data baseline
- **WHEN** E2E tests run
- **THEN** the dev-coc tenant, 3 users, and 10 shelters from seed-data.sql are available
- **AND** auth fixtures use the seed user credentials

#### Scenario: Tests do not interfere with each other
- **WHEN** a test creates a shelter with a UUID-suffixed name
- **THEN** the shelter is identifiable as test data
- **AND** other tests are not affected by this shelter's existence

### Requirement: test-reporting
The E2E suite SHALL produce human-readable test reports for debugging failures.

#### Scenario: Playwright generates HTML report
- **WHEN** Playwright tests complete
- **THEN** an HTML report is generated in e2e/playwright/playwright-report/
- **AND** failed tests include screenshots and traces

#### Scenario: Karate generates HTML report
- **WHEN** Karate tests complete
- **THEN** an HTML report is generated in e2e/karate/target/karate-reports/
