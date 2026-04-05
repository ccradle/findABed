## MODIFIED Requirements

### Requirement: E2E CI workflow generates build-info
The E2E Tests workflow SHALL include `spring-boot:build-info` in the Maven compile step so `VersionController` loads and `/api/v1/version` returns 200.

#### Scenario: E2E workflow generates build-info.properties
- **WHEN** the E2E Tests CI job runs
- **THEN** `META-INF/build-info.properties` SHALL exist in the classpath
- **AND** `GET /api/v1/version` SHALL return 200 with the version number

#### Scenario: Consistency across all build paths
- **WHEN** the application is built via E2E Tests CI, Performance Tests CI, or local dev-start.sh
- **THEN** all three paths SHALL produce the same `build-info.properties` file
- **AND** the version endpoint SHALL be available in all environments
