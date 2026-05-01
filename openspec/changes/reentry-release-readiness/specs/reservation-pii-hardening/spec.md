## ADDED Requirements

### Requirement: Audit events emitted for hold-attribution PII lifecycle
The system SHALL emit a structured audit event each time hold-attribution PII is written, decrypted-on-read, or purged. The 24-hour purge claim is otherwise forensically unverifiable.

#### Scenario: AuditEventType enum extended with three new cases
- **WHEN** `backend/src/main/java/org/fabt/shared/audit/AuditEventType.java` is read post-change
- **THEN** the enum SHALL contain the cases `RESERVATION_HELD_FOR_CLIENT_RECORDED`, `RESERVATION_PII_DECRYPTED_ON_READ`, and `RESERVATION_PII_PURGED`

#### Scenario: Write-side emitter wired
- **WHEN** a reservation is created via `ReservationService.doCreateReservation` with non-null `heldForClientName`, `heldForClientDob`, OR `holdNotes`
- **THEN** an audit event of type `RESERVATION_HELD_FOR_CLIENT_RECORDED` SHALL be emitted
- **AND** the audit event payload SHALL contain the reservation id, the tenant id, and the actor user id, but SHALL NOT contain any plaintext or ciphertext from the encrypted columns
- **AND** in system-scheduled contexts where no human actor exists (e.g., bulk-cancel-on-shelter-deactivation), the actor column SHALL contain the system-actor sentinel used elsewhere in `audit_event` (rather than null), per Round 4 C-RR-3

#### Scenario: Read-side emitter wired (throttled)
- **WHEN** a coordinator reads a reservation row that decrypts hold-attribution ciphertext via the detail-view endpoint defined in design D12
- **THEN** an audit event of type `RESERVATION_PII_DECRYPTED_ON_READ` SHALL be emitted
- **AND** the implementation SHALL throttle to at most one audit row per (coordinator user id, shelter id, hour) tuple to bound audit volume
- **AND** the audit payload SHALL contain reservation id + actor user id only (no plaintext)
- **AND** the emitter SHALL be invoked from a service-layer method (NOT from a JDBC RowMapper), so integration tests can mock the audit publisher and assert payload shape (per Round 4 R-RR-1 testability finding)
- **AND** the throttle cache SHALL be configured with `expireAfterWrite=Duration.ofHours(2)` and `maximumSize=100_000`; eviction SHALL favor over-emit (false-positive duplicate audit row) over under-emit (false-negative missed audit row), since under-emit is the security finding while over-emit is a forensics nuisance (per Round 4 S-RR-1)
- **AND** in system-scheduled contexts where no human actor exists, the audit row's actor column SHALL contain the system-actor sentinel used elsewhere in `audit_event` (rather than null), so the audit chain remains queryable (per Round 4 C-RR-3)

#### Scenario: Purge-side emitter wired
- **WHEN** the scheduled purge runs (`ReferralTokenPurgeService` invocation of `ReservationService.purgeExpiredHoldAttribution`)
- **THEN** exactly one audit event of type `RESERVATION_PII_PURGED` SHALL be emitted per scheduled run
- **AND** the audit payload SHALL contain `{purgedCount, cutoff}` only (no row ids, no plaintext)

### Requirement: Validation exception messages SHALL NOT include user-supplied PII
Exception messages thrown during hold-attribution input validation SHALL be generic and SHALL NOT echo user-supplied DOB, name, or note values. Any debug-level inspection of input values SHALL use structured fields, not string concatenation that flows into log messages.

#### Scenario: DOB exception message generic
- **WHEN** a hold creation fails because `heldForClientDob` is before the floor (1900-01-01)
- **THEN** the thrown `IllegalArgumentException` message SHALL state the rule generically (e.g., "heldForClientDob must be on or after 1900-01-01") and SHALL NOT include the offending input value
- **AND** the 400 response body SHALL NOT include the offending input value

#### Scenario: No PII string concatenation in log statements
- **WHEN** `ReservationService` is grepped for log statements referencing `heldForClient*` or `holdNotes` fields
- **THEN** zero matches SHALL combine the field value with a string-concatenation operator into a log message
- **AND** structured logging (key-value pairs at debug level) MAY reference the field name without echoing the value

### Requirement: Hold-attribution purge cadence floor SHALL be at most 15 minutes
The `purgeExpiredHoldAttribution` `@Scheduled` method on `ReferralTokenPurgeService` SHALL run at a cadence that bounds worst-case hold-attribution PII lifetime to at most 24 hours plus one purge interval. With user-facing copy stating "no later than 25 hours" (per change Decision D10), the cadence SHALL be no longer than 15 minutes (so worst case is 24h15m, comfortably under 25h). The DV referral `purgeTerminalTokens` method on the same class is OUT of scope for this change — its 1-hour cadence stays unchanged because its retention rationale (VAWA referral_token expiry) is independent of the hold-attribution PII contract.

#### Scenario: purgeExpiredHoldAttribution @Scheduled fixedRate reduced
- **WHEN** `backend/src/main/java/org/fabt/referral/service/ReferralTokenPurgeService.java` is read post-change
- **THEN** the `purgeExpiredHoldAttribution` method's `@Scheduled` annotation SHALL specify `fixedRate=900_000` (15 minutes) or shorter
- **AND** the JavaDoc SHALL state the rationale: "worst-case PII lifetime is 24h + 15min interval = 24h15m; user-facing copy says no later than 25 hours"

#### Scenario: purgeTerminalTokens cadence is unchanged
- **WHEN** the same file is read post-change
- **THEN** the `purgeTerminalTokens` method (DV referral_token purge) SHALL retain its existing `@Scheduled(fixedRate = 3_600_000)` (1-hour) annotation
- **AND** the file SHALL NOT have introduced a single global cadence change that affects both methods

### Requirement: Purge UPDATE SHALL be bounded by LIMIT
The purge `UPDATE` statement SHALL include a `LIMIT` clause to prevent table-locking on a backlog of terminal-state reservations. The purge SHALL re-run within the same scheduled invocation until `purgedCount=0` for the current cutoff.

#### Scenario: SQL includes a bounded UPDATE
- **WHEN** the purge SQL in `ReservationRepository` is read post-change
- **THEN** the `UPDATE reservation SET ... WHERE ...` SHALL be bounded (e.g., `WHERE id IN (SELECT id FROM reservation WHERE ... LIMIT 10000)`) so a single statement updates no more than 10,000 rows

#### Scenario: Purge loops until backlog is drained
- **WHEN** the scheduled purge invocation runs against a backlog larger than the LIMIT
- **THEN** the service SHALL re-run the bounded UPDATE within the same invocation until `purgedCount=0` for the current cutoff
- **AND** the audit event (per the audit-events Requirement) SHALL aggregate the total `purgedCount` across all sub-runs into one event per scheduled invocation

### Requirement: List-view reservation responses SHALL NOT carry plaintext PII
Reservation responses returned by list-view endpoints SHALL NOT include the plaintext PII fields (`heldForClientName`, `heldForClientDob`, `holdNotes`). PII MAY be returned only by single-resource detail endpoints, where it is decrypted under audit (per the audit-events Requirement read-side scenario).

#### Scenario: List endpoints omit PII fields
- **WHEN** a coordinator calls `GET /api/v1/shelters/{id}/reservations` (list view)
- **THEN** each reservation in the response SHALL have `heldForClientName`, `heldForClientDob`, and `holdNotes` set to `null` regardless of whether the underlying row carries ciphertext
- **AND** an indicator field MAY be present (e.g., `hasHoldAttribution: boolean`) so the UI can surface "click for details"

#### Scenario: Detail endpoint decrypts under audit
- **WHEN** a coordinator calls a single-reservation detail endpoint
- **THEN** the response MAY include the decrypted `heldForClientName` / `heldForClientDob` / `holdNotes` fields
- **AND** an audit event of type `RESERVATION_PII_DECRYPTED_ON_READ` SHALL be emitted (subject to throttling per the audit-events Requirement)

### Requirement: PII-bearing endpoints SHALL serve no-store cache headers
Every endpoint that returns plaintext hold-attribution PII (the detail-view endpoints from the previous Requirement) SHALL respond with `Cache-Control: no-store, private` so browsers and intermediate caches do not retain the PII payload.

#### Scenario: Detail endpoint sets no-store header
- **WHEN** a coordinator detail-view endpoint returns plaintext PII
- **THEN** the HTTP response SHALL include `Cache-Control: no-store, private`
- **AND** the response SHALL NOT include any `Cache-Control: public` or `max-age=` directive that would allow caching

### Requirement: OpenAPI / Swagger schema SHALL annotate PII fields
The OpenAPI spec / Springdoc-generated artifact SHALL annotate the PII fields on `ReservationResponse` (or its detail-view equivalent) with `@Schema(description=...)` so consumers see the privacy posture without re-leaking field semantics in operation descriptions.

#### Scenario: PII fields carry @Schema annotations
- **WHEN** `ReservationResponse.java` (or the detail-view DTO) is read
- **THEN** each PII field SHALL carry a `@Schema(description="...")` annotation that names the field as PII, references encryption-at-rest with per-tenant DEK, and references the "no later than 25h" purge SLA

#### Scenario: Operation descriptions do not enumerate PII field names
- **WHEN** `ShelterReservationsController` `@Operation.description` is read
- **THEN** it SHALL describe the response semantics ("list of held reservations for the shelter") without enumerating the PII field names
- **AND** the description SHALL NOT reference deprecated roles (e.g., `PLATFORM_ADMIN`); it SHALL use current role names per the G-4.4 migration
