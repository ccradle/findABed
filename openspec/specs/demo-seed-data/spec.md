## ADDED Requirements

### Requirement: demo-activity-seed
The system SHALL provide a seed script that generates 28 days of realistic activity data for dev/demo environments.

#### Scenario: Utilization trends show daily variation
- **WHEN** the seed script has run and an admin views the analytics utilization trends
- **THEN** the chart shows 28 data points with visible weekday/weekend variation

#### Scenario: Demand signals show zero-result searches
- **WHEN** the seed script has run and an admin views demand analytics
- **THEN** zero-result search count is non-zero and reflects realistic unmet demand patterns

#### Scenario: Shelter performance shows varied utilization
- **WHEN** the seed script has run and an admin views shelter performance
- **THEN** at least one shelter shows high utilization (>90%) and one shows low utilization (<40%)

#### Scenario: Reservation data shows realistic conversion rates
- **WHEN** the seed script has run and an admin views demand analytics
- **THEN** reservation conversion rate is approximately 60-70% and expiry rate is approximately 10-20%

#### Scenario: Batch job history shows completed executions
- **WHEN** the seed script has run and an admin views batch jobs
- **THEN** the dailyAggregation job shows 28 completed executions with step-level detail

#### Scenario: Seed is idempotent
- **WHEN** the seed script runs a second time
- **THEN** it produces the same result without duplicating data

#### Scenario: Seed does not affect shelter configuration
- **WHEN** the seed script runs
- **THEN** the shelter table, shelter_constraints table, and existing seed availability snapshots are unchanged

### Requirement: Demo seed expansion to 12 users across 3 tenants
The system SHALL seed exactly 12 demo users across the 3 demo tenants (`dev-coc`, `dev-coc-west`, `dev-coc-east`), with 4 users per tenant: `admin` (COC_ADMIN), `outreach` (OUTREACH_WORKER), `dv-coordinator` (COORDINATOR with dvAccess=true), `dv-outreach` (OUTREACH_WORKER with dvAccess=true). All 12 SHALL share the password `admin123` for demo accessibility.

#### Scenario: Seed inserts 4 users per demo tenant
- **WHEN** seed-data.sql runs against a fresh database
- **THEN** each of dev-coc, dev-coc-west, dev-coc-east has exactly 4 user rows
- **AND** the role/dvAccess matrix per tenant is `{(COC_ADMIN, false), (OUTREACH_WORKER, false), (COORDINATOR, true), (OUTREACH_WORKER, true)}`

#### Scenario: All 12 demo users authenticate with admin123
- **WHEN** any of the 12 demo emails attempts login with password `admin123` and the correct tenantSlug
- **THEN** the response is HTTP 200 with valid JWT

#### Scenario: Seed roles use COC_ADMIN, not deprecated PLATFORM_ADMIN
- **WHEN** seed-data.sql is inspected
- **THEN** no row uses `roles = '{PLATFORM_ADMIN}'`
- **AND** the previous `PLATFORM_ADMIN` admin user is now `COC_ADMIN`

### Requirement: COC_ADMIN backfill + token-version bump in V87 for existing PLATFORM_ADMIN-bearing rows
The V87 migration SHALL grant `COC_ADMIN` to every existing `app_user` row that has `PLATFORM_ADMIN` in its `roles` array AND increment that row's `token_version`. The COC_ADMIN backfill preserves tenant-scoped permissions through the deploy window; the token-version bump invalidates all existing JWTs (forces re-login), closing the "stolen pre-v0.53 PLATFORM_ADMIN JWT retains access" window per design Decision 16.

#### Scenario: Backfill adds COC_ADMIN AND increments token_version
- **WHEN** V87 runs against a database where `app_user` rows exist with `roles = '{PLATFORM_ADMIN}'` and `token_version = 5`
- **THEN** each such row is updated to `roles = '{PLATFORM_ADMIN, COC_ADMIN}'` AND `token_version = 6`
- **AND** rows that already had COC_ADMIN are left unchanged (no duplicate add, no token bump)
- **AND** rows without PLATFORM_ADMIN are not touched at all

#### Scenario: Existing JWTs invalidated post-backfill
- **WHEN** a JWT issued pre-V87 (with `ver=5`) is presented to any tenant-scoped endpoint after V87 runs
- **THEN** the JWT is rejected with HTTP 401 (token version mismatch — JWT carries `ver=5` but `app_user.token_version=6`)
- **AND** the user must re-login to receive a fresh JWT bearing the new role taxonomy

#### Scenario: Backfill is idempotent
- **WHEN** V87 is re-run (Flyway prevents normal re-run, but the SQL itself uses `WHERE NOT ('COC_ADMIN' = ANY(roles))` defensive guard)
- **THEN** no row is duplicated; rows already containing COC_ADMIN are unchanged
- **AND** token_version is NOT incremented a second time (the WHERE filter excludes COC_ADMIN-bearing rows)

#### Scenario: Lock-contention safe at current scale; batched at growth scale
- **WHEN** V87 runs against a database with fewer than 1000 app_user rows total
- **THEN** the UPDATE completes as a single statement
- **AND** acquires brief row locks (no extended impact on tenant logins)
- **AND** the migration includes a comment documenting that for tenants with > 10K admin rows, the backfill should be re-implemented as a batched DO-block with `LIMIT 1000` per iteration to avoid extended lock holding

### Requirement: Platform user NOT seeded as a regular demo user
The system SHALL NOT include any `platform_user` row in the standard demo seed beyond the bootstrap row (which is locked, has no credentials, and is not a demoable user).

#### Scenario: platform_user table empty of demoable rows after seeding
- **WHEN** seed-data.sql + V87 have run
- **THEN** `SELECT count(*) FROM platform_user WHERE account_locked = false` returns 0
- **AND** the only row in `platform_user` is the bootstrap row at UUID `00000000-0000-0000-0000-000000000fab`

#### Scenario: "Try it Live" page does not list platform_user
- **WHEN** the public demo page renders the user list
- **THEN** no platform_user email appears
- **AND** no link to `/auth/platform/login` is rendered in the navigation by default (visible in dev profile only)
