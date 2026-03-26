## ADDED Requirements

### Requirement: batch-job-execution
The system SHALL use Spring Batch for complex scheduled jobs (pre-aggregation, HMIS push, HIC/PIT export) with full execution history, chunk processing, retry/skip, and restart from failure. Available in all deployment tiers (Lite, Standard, Full).

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

### Requirement: batch-job-scheduling-management
The system SHALL allow PLATFORM_ADMIN users to manage batch job schedules from the Admin UI. Cron expressions are stored in tenant config JSONB.

#### Scenario: Admin views job list with schedules
- **WHEN** a COC_ADMIN or PLATFORM_ADMIN views the batch jobs section
- **THEN** they see each job's name, current cron schedule, enabled/disabled state, last run status, and next scheduled run

#### Scenario: PLATFORM_ADMIN edits a job schedule
- **WHEN** a PLATFORM_ADMIN changes the daily aggregation cron from "0 0 3 * * *" to "0 0 2 * * *"
- **THEN** the schedule is updated in tenant config
- **AND** the next run reflects the new cron expression

#### Scenario: PLATFORM_ADMIN disables a job
- **WHEN** a PLATFORM_ADMIN disables a batch job
- **THEN** the job does not run on its schedule until re-enabled

#### Scenario: PLATFORM_ADMIN triggers manual run
- **WHEN** a PLATFORM_ADMIN clicks "Run Now" with a date parameter
- **THEN** the batch job runs immediately with the specified date
- **AND** the execution appears in the job history

#### Scenario: COC_ADMIN cannot modify schedules
- **WHEN** a COC_ADMIN views the batch jobs section
- **THEN** they can see job status and history but cannot edit schedules, trigger runs, or restart jobs

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
