## ADDED Requirements

### Requirement: platform_admin_access_log table created in V88
The system SHALL include a Flyway migration V88 (or combined with V87) that creates the `platform_admin_access_log` table with at minimum: `id UUID PK, platform_user_id UUID FK, action TEXT, resource TEXT, resource_id UUID NULL, justification TEXT NOT NULL, request_method TEXT, request_path TEXT, request_body_excerpt TEXT, before_state JSONB NULL, after_state JSONB NULL, audit_event_id UUID NULL, timestamp TIMESTAMPTZ NOT NULL`.

#### Scenario: Table schema present after V88
- **WHEN** Flyway has applied migrations through V88
- **THEN** `\d platform_admin_access_log` shows the required columns
- **AND** `justification` is `NOT NULL`
- **AND** there is a foreign key from `platform_user_id` to `platform_user(id)`
- **AND** there are indexes on `(platform_user_id, timestamp)`, `(timestamp)`, and `(resource_id)`

### Requirement: platform_admin_access_log is append-only at the database layer
The system SHALL revoke `UPDATE` and `DELETE` privileges on `platform_admin_access_log` from the `fabt_app` runtime role. Only `INSERT` and `SELECT` SHALL be permitted from `fabt_app`. This mirrors the Phase B V70 pattern for `audit_events`.

#### Scenario: UPDATE attempt by fabt_app fails
- **WHEN** the application (running as `fabt_app`) issues `UPDATE platform_admin_access_log SET justification='altered' WHERE id = ?`
- **THEN** PostgreSQL returns a permission-denied error
- **AND** no row is modified

#### Scenario: DELETE attempt by fabt_app fails
- **WHEN** the application (running as `fabt_app`) issues `DELETE FROM platform_admin_access_log WHERE id = ?`
- **THEN** PostgreSQL returns a permission-denied error
- **AND** no row is removed

### Requirement: @PlatformAdminOnly annotation declares both reason and emitted AuditEventType
The system SHALL define a Java annotation `@PlatformAdminOnly` with TWO required members: `reason` (String, design-time justification template) and `emits` (AuditEventType enum, the audit event type written when this endpoint is invoked). Both members are required (no defaults). This eliminates string-mapping fragility — a controller method rename does NOT silently change the audit event type.

#### Scenario: Annotation declaration present
- **WHEN** code review inspects the new annotation source
- **THEN** the annotation has `@Target(ElementType.METHOD)`, `@Retention(RetentionPolicy.RUNTIME)`, `String reason()` with no default, and `AuditEventType emits()` with no default

#### Scenario: Annotated endpoint compiles only with both members
- **WHEN** a developer writes `@PlatformAdminOnly("some reason")` (omits emits) OR `@PlatformAdminOnly(emits=AuditEventType.X)` (omits reason)
- **THEN** the Java compiler rejects the code

#### Scenario: AOP aspect uses annotation.emits() directly for audit_events.action
- **WHEN** a `@PlatformAdminOnly(reason="...", emits=AuditEventType.PLATFORM_TENANT_SUSPENDED)` endpoint executes
- **THEN** the `audit_events.action` column written by the aspect equals `"PLATFORM_TENANT_SUSPENDED"` regardless of the controller method name or path

### Requirement: AOP aspect intercepts @PlatformAdminOnly calls
The system SHALL register a Spring AOP aspect that intercepts every method invocation annotated `@PlatformAdminOnly`. The aspect SHALL run AFTER `@PreAuthorize` (so unauthorized calls do NOT write log rows) and BEFORE the method body executes (so the audit row is committed even if the method throws).

#### Scenario: Unauthorized call does NOT write access log row
- **WHEN** a request fails the `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` check
- **THEN** the response is HTTP 403 Forbidden
- **AND** no row is written to `platform_admin_access_log`
- **AND** no row is written to `audit_events`

#### Scenario: Method throws AFTER access log row is written
- **WHEN** a request passes `@PreAuthorize` AND the `@PlatformAdminOnly` aspect commits an access log row in REQUIRES_NEW transaction, AND the actual method body subsequently throws
- **THEN** the platform_admin_access_log row PERSISTS (because of REQUIRES_NEW)
- **AND** the chained `audit_events` row also PERSISTS (Phase C `DetachedAuditPersister` pattern)
- **AND** the operator-facing error is the original method exception

### Requirement: Per-call justification via X-Platform-Justification header is operator-asserted DOCUMENTATION
The system SHALL require requests to `@PlatformAdminOnly` endpoints to include an `X-Platform-Justification` header with at least 10 non-whitespace characters. The header value is **operator-asserted documentation**, NOT server-validated authority — the system records what the operator typed; auditors read the recorded text to UNDERSTAND the action. The system does NOT validate semantic accuracy of the justification.

The aspect SHALL persist BOTH the annotation's design-time `reason` text AND the request-time header value into the `justification` column (concatenated as `"<annotation reason> | request: <header value>"`). Justification style guide is documented in `docs/security/platform-admin-justification-conventions.md`.

#### Scenario: Missing X-Platform-Justification header rejected
- **WHEN** a request to a `@PlatformAdminOnly` endpoint omits the header
- **THEN** the response is HTTP 400 Bad Request with `{"error":"justification_required","message":"Platform admin endpoints require X-Platform-Justification header (min 10 chars)."}`
- **AND** no log row is written

#### Scenario: Empty / whitespace justification rejected
- **WHEN** the header value is empty, whitespace-only, or under 10 chars
- **THEN** the response is HTTP 400 Bad Request

#### Scenario: Justification persisted to log row
- **WHEN** a request includes a valid header (e.g., `X-Platform-Justification: pilot-cancellation per board vote 2026-04-30`)
- **THEN** the resulting `platform_admin_access_log.justification` column reads `"<annotation reason text> | request: pilot-cancellation per board vote 2026-04-30"`

### Requirement: Double-write to chained audit_events
The system SHALL write a row to `audit_events` for every `@PlatformAdminOnly` invocation, in addition to the `platform_admin_access_log` row. The two rows SHALL be linked: `audit_events.details->>'platform_admin_access_log_id'` equals `platform_admin_access_log.id`, and `platform_admin_access_log.audit_event_id` equals the `audit_events.id`.

#### Scenario: Both rows written and linked
- **WHEN** a `@PlatformAdminOnly` endpoint executes successfully
- **THEN** exactly one new row exists in `platform_admin_access_log` for this invocation
- **AND** exactly one new row exists in `audit_events` for this invocation
- **AND** the two rows reference each other by id

#### Scenario: Audit_events row carries justification excerpt
- **WHEN** the linked `audit_events.details` JSONB is read
- **THEN** it contains keys `platform_admin_access_log_id`, `platform_user_id`, `platform_user_email`, `justification_excerpt` (first 200 chars), `request_method`, `request_path`

### Requirement: Audit_events tenant_id chosen by action target
For tenant-affecting platform actions (suspend, unsuspend, offboard, hardDelete, key-rotation, HMIS-export, OAuth2-test), the audit_events row SHALL be written with `tenant_id` equal to the TARGETED tenant's id. For platform-wide actions (BatchJobController, TestResetController), the audit_events row SHALL be written with `tenant_id = SYSTEM_TENANT_ID`.

#### Scenario: TenantLifecycleController.suspend(X) lands in X's chain
- **WHEN** a platform operator suspends tenant X
- **THEN** the audit_events row has `tenant_id = X`, `action = PLATFORM_TENANT_SUSPENDED`
- **AND** the row's `prev_hash` and `row_hash` are populated (chained per Phase G-1)
- **AND** X's `tenant_audit_chain_head.last_hash` is updated to this row's `row_hash`

#### Scenario: TenantController.create(newSlug=Y) lands in Y's brand-new chain
- **WHEN** a platform operator creates a new tenant Y
- **THEN** Y's `tenant_audit_chain_head` is initialized with the zero-hash sentinel (per Phase F-4)
- **AND** the audit_events row for the create has `tenant_id = Y`, `action = PLATFORM_TENANT_CREATED`, and is the FIRST chained row (prev_hash = zero-hash sentinel; row_hash = computed hash)

#### Scenario: BatchJobController.run lands under SYSTEM_TENANT_ID, not chained
- **WHEN** a platform operator triggers a global batch job
- **THEN** the audit_events row has `tenant_id = SYSTEM_TENANT_ID`, `action = PLATFORM_BATCH_JOB_TRIGGERED`
- **AND** `prev_hash IS NULL` and `row_hash IS NULL` (consistent with Phase G-1 SYSTEM_TENANT_ID skip rule)

#### Scenario: PLATFORM_TENANT_HARD_DELETED special-cases to SYSTEM_TENANT_ID
- **WHEN** a platform operator hard-deletes tenant T (Phase F-6 crypto-shred)
- **THEN** the audit_events row has `tenant_id = SYSTEM_TENANT_ID` (NOT tenant T) — even though the action targets a specific tenant
- **AND** the row survives the hardDelete cascade (which would otherwise delete it along with all other audit_events rows for T)
- **AND** the `details` JSONB still records `target_tenant_id = T` for forensic reconstruction
- **AND** the `platform_admin_access_log` row is unaffected by the cascade (keyed by platform_user_id, not tenant_id)

### Requirement: Three-write transaction ordering with client-side UUIDs
The aspect SHALL generate UUIDs for both the new `platform_admin_access_log` row and the new `audit_events` row UP FRONT (client-side via `UUID.randomUUID()`), then INSERT both rows within a single `REQUIRES_NEW` transaction with the IDs already cross-referenced. NO subsequent `UPDATE` statement is needed to populate the link.

#### Scenario: Both INSERTs happen in single transaction with pre-generated IDs
- **WHEN** the aspect writes both rows for one platform action
- **THEN** the rows reference each other via the pre-generated UUIDs
- **AND** there is NO `UPDATE platform_admin_access_log SET audit_event_id = ?` statement (link populated at INSERT time)
- **AND** if the REQUIRES_NEW transaction commit fails, NEITHER row persists (atomicity)

#### Scenario: REQUIRES_NEW commit failure logged
- **WHEN** the REQUIRES_NEW commit fails (e.g., DB connection drops, constraint violation)
- **THEN** a WARN log line is emitted with MDC marker `platform_action: true` describing the failure
- **AND** the main method body executes regardless (audit miss is preferable to blocking the operation)
- **AND** SOC operators can grep for `platform_action: true` AND `WARN` to find missed audit rows

### Requirement: 10 new PLATFORM_* AuditEventType values
The system SHALL define the following new `AuditEventType` enum values: `PLATFORM_TENANT_CREATED`, `PLATFORM_TENANT_SUSPENDED`, `PLATFORM_TENANT_UNSUSPENDED`, `PLATFORM_TENANT_OFFBOARDED`, `PLATFORM_TENANT_HARD_DELETED`, `PLATFORM_KEY_ROTATED`, `PLATFORM_HMIS_EXPORTED`, `PLATFORM_OAUTH2_TESTED`, `PLATFORM_BATCH_JOB_TRIGGERED`, `PLATFORM_TEST_RESET_INVOKED`.

#### Scenario: Enum values present after Phase G-4
- **WHEN** code review inspects `AuditEventType`
- **THEN** all 10 new values are present
- **AND** an ArchUnit test verifies each value is referenced from at least one `@PlatformAdminOnly` aspect emit site

### Requirement: ArchUnit guard preventing future @PreAuthorize PLATFORM_ADMIN
The system SHALL include an ArchUnit test that fails the build if any `@PreAuthorize` annotation in `org.fabt.*.api` references the string `PLATFORM_ADMIN` (case-sensitive) after this change is fully merged.

#### Scenario: New @PreAuthorize PLATFORM_ADMIN added in source
- **WHEN** a developer adds `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` to a new controller method
- **THEN** the next CI run's ArchUnit job fails with a clear error: "PLATFORM_ADMIN is deprecated; use COC_ADMIN (tenant-scoped) or PLATFORM_OPERATOR + @PlatformAdminOnly (platform-scoped). See PR #141."

### Requirement: Retention policy is indefinite for v0.53; explicit policy lands Phase H+
The `platform_admin_access_log` table SHALL retain rows indefinitely (no automated deletion) for v0.53. Phase H+ adds a retention policy (per-tenant overrides; per-action-type retention; age-based cleanup). This aligns with HIPAA 6yr / VAWA per-OVW / government audit 7yr expectations until proper policy infrastructure exists. Operators MAY manually purge via psql in the interim; documented procedure in runbook.

#### Scenario: No automated deletion of platform_admin_access_log rows in v0.53
- **WHEN** the system runs for an extended period (months / years)
- **THEN** no scheduled job DELETEs from `platform_admin_access_log`
- **AND** the table grows monotonically until manual psql purge or Phase H+ retention policy deploy

### Requirement: Forensic walker can reconstruct platform admin actions
The system SHALL document a `docs/security/platform-admin-forensic-walk.md` query playbook describing how to (a) list all platform-admin actions in a time window via `platform_admin_access_log`; (b) join to `audit_events` for chained-tamper-evidence coverage; (c) cross-reference with OCI anchor objects for verifying the chain hasn't been tampered with.

#### Scenario: Documented forensic queries are executable
- **WHEN** an operator copies the documented queries verbatim into psql
- **THEN** all queries execute without error
- **AND** the result columns and types match the documented schema
