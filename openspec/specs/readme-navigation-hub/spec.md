## readme-navigation-hub

Slim README that routes each audience to their page within 10 seconds.

### Requirements

- REQ-NAV-1: Code repo README MUST be under 250 lines
- REQ-NAV-2: README MUST lead with the problem statement (parking lot story) before any technical content
- REQ-NAV-3: README MUST include a "Who It's For" section with links to all 5 audience pages within the first 30 lines
- REQ-NAV-4: README MUST retain Quick Start instructions for developers (condensed)
- REQ-NAV-5: README MUST retain Project Status section with current version and completed features (condensed)
- REQ-NAV-6: All existing deep-link URLs MUST either continue working or be redirected via the new docs/FOR-DEVELOPERS.md
- REQ-NAV-7: Docs repo README MUST lead with the parking lot story and "No more midnight phone calls" before OpenSpec workflow details

### Requirement: README test and migration counts
The code repo README and FOR-DEVELOPERS.md SHALL display accurate test suite counts and Flyway migration counts that reflect the current state of the codebase. All counts SHALL be verified by grep at implementation time, not hardcoded from prior estimates.

#### Scenario: Flyway migration count is accurate in README.md
- **WHEN** a reader checks the migration count in README.md (line 60)
- **THEN** the stated count SHALL match `ls backend/src/main/resources/db/migration/ | wc -l`

#### Scenario: Flyway migration count is accurate in FOR-DEVELOPERS.md (all 3 locations)
- **WHEN** a reader checks the migration count in FOR-DEVELOPERS.md
- **THEN** the count at line 33 (Tech Stack table), line 87 (Database Schema section), and line 895 (file tree comment) SHALL all match the actual file count
- **AND** the version range description (e.g., "V1–V32 + V8.1") SHALL match the actual migration filenames

#### Scenario: Karate API scenario count is accurate
- **WHEN** a reader checks the Karate test count in README.md or FOR-DEVELOPERS.md
- **THEN** the stated count SHALL match `grep -rc "Scenario:" backend/src/test/resources/`

#### Scenario: Playwright UI test count is accurate
- **WHEN** a reader checks the Playwright test count in README.md or FOR-DEVELOPERS.md
- **THEN** the stated count SHALL match `grep -rc "test(" e2e/playwright/tests/*.spec.ts`

#### Scenario: JUnit/ArchUnit test count is accurate
- **WHEN** a reader checks the backend test count in README.md or FOR-DEVELOPERS.md
- **THEN** the stated count SHALL match `grep -rc "@Test" backend/src/test/java/`

#### Scenario: Vitest unit test count is accurate
- **WHEN** a reader checks the Vitest test count in README.md or FOR-DEVELOPERS.md
- **THEN** the stated count SHALL match `grep -rc "test\|it(" frontend/src/**/*.test.ts`

#### Scenario: Gatling simulation count is accurate
- **WHEN** a reader checks the Gatling simulation count in README.md or FOR-DEVELOPERS.md
- **THEN** the stated count SHALL match the number of concrete simulation classes in `backend/src/gatling/java/`

#### Scenario: ArchUnit rule count is internally consistent
- **WHEN** a reader checks ArchUnit rule counts in FOR-DEVELOPERS.md
- **THEN** line 66 ("architecture tests") and line 1257 ("rules total") SHALL state the same number
- **AND** that number SHALL match the actual count of ArchUnit test methods
