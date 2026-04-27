## ADDED Requirements

### Requirement: batch-job-execution
The system SHALL use Spring Batch for complex scheduled jobs (pre-aggregation, HMIS push, HIC/PIT export) with full execution history, chunk processing, retry/skip, and restart from failure. Available in all deployment tiers (Lite, Standard, Full). The HMIS push job's outbox processing step SHALL dispatch vendor REST calls in parallel using virtual threads, bounded by vendor rate limits via Resilience4j.

#### Scenario: Daily aggregation job processes snapshots in chunks
- **WHEN** the daily aggregation job runs
- **THEN** it reads bed_availability snapshots for the target date in chunks
- **AND** computes utilization metrics and writes to daily_utilization_summary
- **AND** the execution is recorded in BATCH_JOB_EXECUTION with read/write/skip counts

#### Scenario: Failed job is restartable from last committed chunk
- **WHEN** a batch job fails mid-execution (e.g., at chunk 47 of 100)
- **THEN** chunks 1-46 remain committed
- **AND** the job can be restarted and resumes from chunk 47

#### Scenario: HMIS push job retries transient failures
- **WHEN** an HMIS push encounters a transient HTTP error (503, timeout)
- **THEN** the item is retried up to 3 times with backoff
- **AND** permanently bad records are skipped and counted

#### Scenario: HIC/PIT export prevents duplicate generation
- **WHEN** a HIC export job runs with the same reportDate parameter twice
- **THEN** the second attempt is rejected as an already-completed JobInstance

#### Scenario: HMIS outbox entries processed in parallel
- **WHEN** the HMIS push job's processOutbox step executes with 10 pending outbox entries across 2 vendors
- **THEN** outbox entries are dispatched to virtual threads for concurrent vendor REST calls
- **AND** concurrency per vendor is bounded by Resilience4j rate limiter configuration
- **AND** all entries are marked as SENT or FAILED upon completion

### Requirement: batch-job-scheduling-management
The system SHALL allow `PLATFORM_OPERATOR` users (gated additionally by `@PlatformAdminOnly`) to manage GLOBAL batch job schedules from the Admin UI. Per-tenant cron expressions are stored in tenant config JSONB and editable by `COC_ADMIN`. The `BatchJobScheduler` SHALL use a virtual thread-backed `TaskScheduler`, ensuring cron-triggered job launches execute on virtual threads and never block each other or other `@Scheduled` tasks. (Previously: PLATFORM_ADMIN for both global and per-tenant. Now split: PLATFORM_OPERATOR for global ops including manual triggers via `/api/v1/batch/jobs/{name}/run`; COC_ADMIN for per-tenant cron schedule edits in tenant config.)

#### Scenario: Admin views job list with schedules
- **WHEN** a `COC_ADMIN` views the batch jobs section
- **THEN** they see each job's name, current cron schedule (per their tenant), enabled/disabled state, last run status, and next scheduled run

#### Scenario: COC_ADMIN edits per-tenant job schedule
- **WHEN** a `COC_ADMIN` changes the daily aggregation cron for their tenant from "0 0 3 * * *" to "0 0 2 * * *"
- **THEN** the schedule is updated in tenant config
- **AND** the next run reflects the new cron expression for THAT tenant only

#### Scenario: PLATFORM_OPERATOR triggers global manual run
- **WHEN** a `PLATFORM_OPERATOR` POSTs `/api/v1/batch/jobs/auditChainVerifier/run` with header `X-Platform-Justification: ad-hoc verification before audit board meeting`
- **THEN** the batch job runs immediately
- **AND** the execution appears in the job history
- **AND** a `platform_admin_access_log` row is written with `action = PLATFORM_BATCH_JOB_TRIGGERED`, justification text persisted
- **AND** an `audit_events` row is written under SYSTEM_TENANT_ID with `action = PLATFORM_BATCH_JOB_TRIGGERED` (NOT chained, per existing SYSTEM_TENANT_ID rule)

#### Scenario: COC_ADMIN cannot trigger global manual run
- **WHEN** a `COC_ADMIN` attempts POST `/api/v1/batch/jobs/{name}/run`
- **THEN** the system returns HTTP 403 Forbidden
- **AND** no log rows are written

#### Scenario: PLATFORM_OPERATOR disables a global job
- **WHEN** a `PLATFORM_OPERATOR` disables a batch job globally with justification
- **THEN** the job does not run on its schedule until re-enabled
- **AND** both log tables receive rows

#### Scenario: Failed job restart available to PLATFORM_OPERATOR
- **WHEN** a batch job execution has failed
- **THEN** the error message is displayed
- **AND** a "Restart" button is visible to `PLATFORM_OPERATOR` (not COC_ADMIN)
- **AND** clicking restart resumes the job from the last committed chunk

#### Scenario: Outreach worker cannot see batch jobs
- **WHEN** an `OUTREACH_WORKER` navigates to the admin panel
- **THEN** the batch jobs section is not rendered
- **AND** direct API access returns HTTP 403

### Requirement: batch-job-execution-history
The system SHALL provide queryable execution history for all batch jobs, viewable in the Admin UI.

#### Scenario: Admin views execution history
- **WHEN** an admin clicks on a batch job
- **THEN** they see a list of past executions: start time, end time, duration, status (COMPLETED/FAILED), exit message

#### Scenario: Admin views step-level detail
- **WHEN** an admin clicks on a specific execution
- **THEN** they see step-level detail: step name, read count, write count, skip count, commit count, status

#### Scenario: Failed execution shows error and restart button
- **WHEN** an execution has status FAILED
- **THEN** the error message is displayed
- **AND** a "Restart" button is visible to PLATFORM_ADMIN
- **AND** clicking restart resumes the job from the last committed chunk

#### Scenario: Outreach worker cannot see batch jobs
- **WHEN** an OUTREACH_WORKER navigates to the admin panel
- **THEN** the batch jobs section is not visible
