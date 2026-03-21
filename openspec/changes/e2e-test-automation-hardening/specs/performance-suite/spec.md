## ADDED Requirements

### Requirement: bed-search-performance
The E2E suite SHALL include a Gatling BedSearchSimulation that ramps to 50 concurrent users, holds for 2 minutes with 4 payload variants, and asserts SLOs: p50<100ms, p95<500ms, p99<1000ms, <1% error rate.

#### Scenario: Bed search meets SLO under load
- **WHEN** 50 concurrent users query POST /api/v1/queries/beds for 2 minutes
- **THEN** p95 response time is under 500ms and error rate is under 1%

### Requirement: availability-update-performance
The E2E suite SHALL include a Gatling AvailabilityUpdateSimulation with two scenarios: multi-shelter (10 coordinators, different shelters) and same-shelter (5 coordinators, same shelter). SLO: p95<200ms, <1% errors. Post-simulation assertion: bedsAvailable is never negative.

#### Scenario: Multi-shelter concurrent updates meet SLO
- **WHEN** 10 coordinators update different shelters concurrently for 2 minutes
- **THEN** p95 response time is under 200ms

#### Scenario: Same-shelter concurrent updates don't corrupt data
- **WHEN** 5 coordinators update the same shelter concurrently for 1 minute
- **THEN** bedsAvailable is non-negative after all updates complete

### Requirement: surge-load-simulation-stub
The E2E suite SHALL include a SurgeLoadSimulation stub with documented spec for post-surge-mode implementation. The stub compiles but skips execution with a TODO comment.

#### Scenario: Surge simulation spec documented
- **WHEN** the Gatling project is built
- **THEN** SurgeLoadSimulation.scala exists with full spec in comments and a TODO marker
