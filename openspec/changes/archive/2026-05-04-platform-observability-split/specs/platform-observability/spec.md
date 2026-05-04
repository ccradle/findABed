# Platform Observability Spec

## ADDED Requirements

### Requirement: Platform-level config storage

The system SHALL store platform-wide observability settings in a
single-row `platform_config` table with a JSONB `config` column. The
single-row invariant is enforced by a CHECK constraint on the
canonical UUID `00000000-0000-0000-0000-000000000001`. Reads use
`SELECT config FROM platform_config WHERE id = '00...001'`.

The initial seed row carries:
- `prometheus_enabled: true`
- `tracing_enabled: false`
- `tracing_endpoint: "http://localhost:4318/v1/traces"`
- `monitor_stale_interval_minutes: 5`
- `monitor_dv_canary_interval_minutes: 15`
- `monitor_temperature_interval_minutes: 60`

#### Scenario: Singleton invariant prevents second row insert

- **WHEN** an INSERT into `platform_config` uses any UUID other than the
  canonical singleton UUID
- **THEN** the database rejects the insert with a CHECK constraint
  violation

#### Scenario: Initial-row read after migration

- **GIVEN** a fresh database with V98 applied
- **WHEN** `PlatformConfigService.get()` is invoked
- **THEN** the seeded defaults above are returned

### Requirement: GET endpoint for platform observability config

The system SHALL expose `GET /api/v1/platform/observability` returning
the current `platform_config.config` JSONB. Authorized for
`PLATFORM_OPERATOR` only (via `@PreAuthorize`); does NOT require an
`X-Platform-Justification` header (read-only access).

#### Scenario: Platform operator reads config

- **GIVEN** a logged-in `PLATFORM_OPERATOR`
- **WHEN** GET `/api/v1/platform/observability` is called
- **THEN** 200 with the JSONB payload

#### Scenario: COC_ADMIN forbidden

- **GIVEN** a logged-in `COC_ADMIN` (NOT a platform operator)
- **WHEN** GET `/api/v1/platform/observability` is called
- **THEN** 403 Forbidden

### Requirement: PUT endpoint for platform observability config

The system SHALL expose `PUT /api/v1/platform/observability` accepting
a partial JSONB patch of the 6 platform-wide fields. Authorized for
`PLATFORM_OPERATOR` only AND requires `@PlatformAdminOnly` justification
(`X-Platform-Justification` header). Validation:
- Each interval (stale, dv-canary, temperature) MUST be in `[1, 1440]`
  minutes; bounds violations return 400 with `errorCode:
  "platform.observability.intervalOutOfRange"`.
- `tracing_endpoint` MUST be a non-empty string parseable as a URI;
  malformed values return 400 with `errorCode:
  "platform.observability.tracingEndpointMalformed"`.

On successful write, the system SHALL:
- Persist the merged JSONB to `platform_config`
- Update `platform_config.updated_at` and `updated_by`
- Emit a `PLATFORM_OBSERVABILITY_UPDATED` audit event with details
  `{field, old_value, new_value, value_changed, outcome: "applied"}`
  per changed field
- Trigger `OperationalMonitorService.rescheduleFromConfig()` so monitor
  cadence changes take effect on the next cycle without restart

#### Scenario: Successful interval update

- **GIVEN** a logged-in `PLATFORM_OPERATOR` with a justification header
- **WHEN** PUT `/api/v1/platform/observability` with body
  `{"monitor_stale_interval_minutes": 10}`
- **THEN** 200 with the merged JSONB
- **AND** the `platform_config.config` row contains
  `monitor_stale_interval_minutes: 10`
- **AND** an audit row exists with `field: "monitor_stale_interval_minutes",
  old_value: 5, new_value: 10, value_changed: true, outcome: "applied"`

#### Scenario: Interval out of bounds

- **GIVEN** a logged-in `PLATFORM_OPERATOR` with a justification header
- **WHEN** PUT `/api/v1/platform/observability` with body
  `{"monitor_stale_interval_minutes": 0}`
- **THEN** 400 with `context.errorCode:
  "platform.observability.intervalOutOfRange"`
- **AND** no audit row is emitted (validation failure precedes write)

#### Scenario: Missing justification header

- **GIVEN** a logged-in `PLATFORM_OPERATOR` WITHOUT a justification header
- **WHEN** PUT `/api/v1/platform/observability`
- **THEN** 400 with `context.errorCode: "missing_justification"`
  (existing `@PlatformAdminOnly` filter behavior)

### Requirement: OperationalMonitorService reads from platform config

The system SHALL read the 3 monitor cadence values from
`PlatformConfigService` (NOT from `@Scheduled` literal rates) such that
operator-initiated changes take effect on the next monitor cycle.
`OperationalMonitorService` SHALL implement `SchedulingConfigurer` and
register tasks via `TaskScheduler`, mirroring the pattern in
`org.fabt.analytics.config.BatchJobScheduler`.

#### Scenario: Cadence change propagates to scheduler

- **GIVEN** the monitor is scheduled at the default 5-minute stale
  interval
- **WHEN** the platform operator updates
  `monitor_stale_interval_minutes: 10` via the PUT endpoint
- **AND** `rescheduleFromConfig()` is invoked
- **THEN** the prior `ScheduledFuture` is cancelled (`future.cancel(false)`)
- **AND** a new `ScheduledFuture` registers with a 10-minute fixed rate

#### Scenario: Mid-flight reschedule does not interrupt running task

- **GIVEN** the stale-shelter check is currently executing
- **WHEN** `rescheduleFromConfig()` fires
- **THEN** the in-flight task completes normally (cancel is non-interrupting)
- **AND** the next invocation uses the new cadence

### Requirement: Prometheus + tracing wiring reads platform config

The system SHALL read `prometheus_enabled`, `tracing_enabled`, and
`tracing_endpoint` from `PlatformConfigService`. The
`ObservabilityConfigService` SHALL no longer expose these fields per
tenant; the per-tenant getter methods are removed.

#### Scenario: Tracing toggle takes effect

- **GIVEN** `tracing_enabled: false` in `platform_config`
- **WHEN** the OTel exporter is invoked
- **THEN** no spans are exported
- **WHEN** the platform operator updates `tracing_enabled: true`
- **THEN** subsequent spans ARE exported to `tracing_endpoint`

### Requirement: Cross-tenant audit on platform config writes

The system SHALL audit every successful PUT against `platform_config`
with the `PLATFORM_OBSERVABILITY_UPDATED` audit type. Failed writes
(validation failures, missing justification) SHALL NOT emit an audit
row (those are pre-write rejections; the existing `@PlatformAdminOnly`
filter already audits the missing-justification path separately).

#### Scenario: One audit row per changed field

- **WHEN** a PUT changes 3 fields in one request
- **THEN** 3 separate `PLATFORM_OBSERVABILITY_UPDATED` audit rows are
  emitted, one per `field`
- **AND** each row carries old + new + value_changed for its specific
  field

#### Scenario: Idempotent re-set audit

- **GIVEN** `tracing_enabled: false`
- **WHEN** PUT with body `{"tracing_enabled": false}`
- **THEN** an audit row is emitted with `value_changed: false, outcome:
  "applied"` (intent traceability — operator's request is captured even
  if the value didn't change)

### Requirement: ObservabilityTab removed from /admin

The system SHALL NOT render an "Observability" tab in the
`/admin` AdminPanel for any user role. The frontend ObservabilityTab
component is removed from `TABS` and `TAB_COMPONENTS` in
`AdminPanel.tsx`. Platform operators reach observability config via
the existing Platform Operator Dashboard.

#### Scenario: COC_ADMIN no longer sees the tab

- **GIVEN** a logged-in COC_ADMIN
- **WHEN** they navigate to `/admin`
- **THEN** the tab list contains no "Observability" entry

#### Scenario: PLATFORM_OPERATOR uses dashboard cards

- **GIVEN** a logged-in PLATFORM_OPERATOR on the platform dashboard
- **WHEN** they view the action card grid
- **THEN** observability action cards appear under a new
  `'observability'` category alongside the existing categories

### Requirement: Backward-read for obsoleted per-tenant fields

The system SHALL preserve unread access to the obsoleted
`tenant.config.observability.{prometheus_enabled, tracing_enabled,
tracing_endpoint, monitor_*_interval_minutes}` JSONB keys for one
release cycle. No code path SHALL invoke these reads. The keys exist
solely to prevent backward-incompatible JSONB schema changes from
crashing on prod tenants whose old config still carries them.

In the v0.58+ follow-up change, these keys are dropped via Flyway
migration after observability confirms zero reads in production.

#### Scenario: Old config values do not crash startup

- **GIVEN** a tenant whose `tenant.config.observability` contains a value
  for `tracing_enabled`
- **WHEN** the application starts
- **THEN** startup completes without error
- **AND** no code reads from that JSONB path
