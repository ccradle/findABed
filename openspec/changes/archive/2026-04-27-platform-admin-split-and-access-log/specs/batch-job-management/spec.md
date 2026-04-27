## MODIFIED Requirements

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
