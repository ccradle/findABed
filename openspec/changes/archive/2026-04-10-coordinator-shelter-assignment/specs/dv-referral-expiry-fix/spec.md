## MODIFIED Requirements

### Requirement: referral-expiry-scheduled-job (MODIFIED)
The `expireTokens()` scheduled method SHALL NOT use `@Transactional`. The underlying SQL is a single atomic UPDATE RETURNING statement. `@Transactional` eagerly acquires a JDBC connection before `TenantContext.runWithContext()` sets dvAccess=true, making DV shelter referral tokens invisible via RLS.

#### Scenario: DV referral token expired by scheduled job
- **GIVEN** a PENDING DV referral token with expires_at in the past
- **WHEN** `expireTokens()` runs via @Scheduled (no outer TenantContext)
- **THEN** the token status SHALL change to EXPIRED
- **AND** a `dv-referral.expired` domain event SHALL be published

#### Scenario: Fail-fast on missing dvAccess
- **GIVEN** `expireTokens()` is called
- **WHEN** `TenantContext.getDvAccess()` returns false inside `runWithContext`
- **THEN** an IllegalStateException SHALL be thrown (never silently return zero rows)

### Requirement: referral-purge-scheduled-job (MODIFIED)
The `purgeTerminalTokens()` scheduled method SHALL NOT use `@Transactional`. Same root cause as expiry: single atomic DELETE, `@Transactional` breaks RLS context.

#### Scenario: DV terminal tokens purged by scheduled job
- **GIVEN** an EXPIRED DV referral token older than 24 hours
- **WHEN** `purgeTerminalTokens()` runs via @Scheduled (no outer TenantContext)
- **THEN** the token SHALL be hard-deleted

### Requirement: expiry-diagnostic-logging (ADDED)
Both `expireTokens()` and `purgeTerminalTokens()` SHALL log on every invocation (not just when rows are affected). Logs SHALL include the dvAccess state and the count of affected rows.

#### Scenario: Expiry job logs every run
- **WHEN** `expireTokens()` runs and finds 0 expired tokens
- **THEN** the log SHALL contain `expireTokens: dvAccess=true, expired=0`

### Requirement: expiry-test-without-outer-context (ADDED)
Integration tests for `expireTokens()` SHALL call the method WITHOUT an outer `TenantContext` — matching the production `@Scheduled` invocation. Tests that wrap `expireTokens()` in `TenantContext.runWithContext()` mask the RLS context bug.

#### Scenario: Test calls expireTokens like @Scheduled does
- **GIVEN** a DV referral with expires_at in the past
- **WHEN** `expireTokens()` is called directly (no TenantContext wrapper)
- **THEN** the token SHALL be EXPIRED (proving the fix works in production conditions)
