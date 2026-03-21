## Purpose

CI infrastructure: health check waits, worker-to-shelter isolation, dv-canary gate.

## ADDED Requirements

### Requirement: ci-health-check-waits
The CI pipeline SHALL wait for both backend and frontend to be healthy before executing tests. Backend wait polls `/actuator/health/liveness` for up to 60 seconds. Frontend wait polls port 5173 for up to 30 seconds.

#### Scenario: Tests wait for backend readiness
- **WHEN** the CI pipeline starts the backend
- **THEN** tests do not execute until `/actuator/health/liveness` returns 200

### Requirement: worker-shelter-isolation
The Playwright test suite SHALL assign dedicated shelters to each parallel worker to prevent race conditions in mutation tests. 3 workers each get 3 shelters. Shelter[9] is reserved for creation tests.

#### Scenario: Workers use isolated shelters
- **WHEN** 3 Playwright workers run in parallel
- **THEN** each worker mutates only its assigned shelters
- **AND** no two workers modify the same shelter
