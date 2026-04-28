## ADDED Requirements

### Requirement: Platform operator metadata endpoint
The system SHALL expose `GET /api/v1/auth/platform/me` returning the currently-authenticated platform operator's metadata. The endpoint SHALL require a valid platform JWT (iss=fabt-platform) and SHALL reject tenant JWTs with HTTP 403.

#### Scenario: Authenticated platform operator retrieves own metadata
- **WHEN** a request to `GET /api/v1/auth/platform/me` is presented with a valid platform JWT (mfaVerified=true)
- **THEN** the response is HTTP 200 with body `{id, email, mfaEnabled, lastLoginAt, mfaEnrolledAt, backupCodesRemaining}`
- **AND** `email` is the operator's email from `platform_user.email`
- **AND** `mfaEnabled` is the boolean from `platform_user.mfa_enabled`
- **AND** `lastLoginAt` is the Instant from `platform_user.last_login_at`
- **AND** `mfaEnrolledAt` is the timestamp captured by V90's `platform_user.mfa_enrolled_at` column on the first false→true transition of `mfa_enabled` (or null if MFA not yet enrolled, or null pre-V90 for legacy rows that lacked any `platform_user_backup_code` rows during the V90 backfill)
- **AND** `backupCodesRemaining` is `findUnusedBackupCodes(userId).size()` (where `used_at IS NULL`)
- **AND** the response does NOT include `passwordHash`, `mfaSecret`, or any backup code material

#### Scenario: Tenant JWT rejected with 403
- **WHEN** a request to `GET /api/v1/auth/platform/me` is presented with a tenant JWT (iss=fabt-tenant)
- **THEN** the response is HTTP 403 Forbidden
- **AND** no operator metadata is leaked in the response body

#### Scenario: Missing JWT rejected with 401
- **WHEN** a request to `GET /api/v1/auth/platform/me` is presented without an Authorization header
- **THEN** the response is HTTP 401 Unauthorized

#### Scenario: MFA-setup-only token rejected
- **WHEN** a request bears the short-lived MFA-setup token (scope `mfa-setup-only`) and attempts `GET /api/v1/auth/platform/me`
- **THEN** the response is HTTP 403 Forbidden
- **AND** the scope claim is independently validated (not relying on URL-path-only routing)

#### Scenario: Anonymized or missing operator → 410 Gone
- **WHEN** a request bears a structurally-valid platform access token whose `sub` claim resolves to a `platform_user` row that is anonymized (`anonymized_at IS NOT NULL`) OR no longer present
- **THEN** the response is HTTP 410 Gone
- **AND** the response body is opaque (no operator metadata leaked)
- **AND** the SPA's 410 handler displays "your account has been removed; contact support" and does NOT loop the operator back to login (which would also fail)
- **AND** the V90 SECURITY DEFINER function `platform_user_get_me` returns zero rows for anonymized OR missing rows (the `WHERE id = p_id AND anonymized_at IS NULL` clause filters both cases identically)

### Requirement: Platform operator logout endpoint
The system SHALL expose `POST /api/v1/auth/platform/logout` returning HTTP 204 No Content. For v0.54 the endpoint is a server-side no-op (no token revocation; future hook for Phase H+ when `token_invalidation_at` lands). The endpoint SHALL require a valid platform JWT.

#### Scenario: Authenticated platform operator logs out
- **WHEN** a request to `POST /api/v1/auth/platform/logout` is presented with a valid platform JWT
- **THEN** the response is HTTP 204 No Content with empty body
- **AND** no DB mutation occurs (server-side no-op for v0.54)
- **AND** the JWT remains technically valid until `exp` (frontend is responsible for clearing sessionStorage)

#### Scenario: Tenant JWT rejected
- **WHEN** a request to `POST /api/v1/auth/platform/logout` is presented with a tenant JWT
- **THEN** the response is HTTP 403 Forbidden

#### Scenario: Missing JWT rejected
- **WHEN** a request to `POST /api/v1/auth/platform/logout` is presented without an Authorization header
- **THEN** the response is HTTP 401 Unauthorized
