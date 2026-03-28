## ADDED Requirements

### Requirement: Screenshot-narrative alignment

The demo seed data SHALL produce screenshots that visually match every narrative caption in the walkthrough pages. Each caption's specific claims (shelter count, freshness color, constraint flags, analytics numbers) SHALL be verifiable by visual inspection of the corresponding screenshot.

#### Scenario: Family bed search returns exactly three results

- **WHEN** an outreach worker without dvAccess searches for FAMILY_WITH_CHILDREN beds
- **THEN** exactly 3 shelters appear in results, all with green freshness badges (updated < 1 hour)

#### Scenario: First family shelter shows pets and wheelchair

- **WHEN** the outreach worker taps the first family shelter result
- **THEN** the detail view shows pets_allowed=true, wheelchair_accessible=true, and freshness ~12 minutes

#### Scenario: Analytics shows target utilization and zero-result count

- **WHEN** a CoC administrator opens the analytics executive summary
- **THEN** system utilization is near 78% and zero-result searches show approximately 47 for the prior week
