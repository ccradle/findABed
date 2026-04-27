# Capability: platform-operator-identity

## Purpose
Separate identity, authentication, and JWT signing infrastructure for platform operators. Platform operators are NOT tenant-scoped users — they perform tenant-affecting actions (suspend, offboard, hardDelete) but are not part of any single tenant's user inventory. This capability defines the `platform_user` table, the `/auth/platform/*` login flow, mandatory MFA, account lockout, platform key material, and JWT shape.

## Requirements

### Requirement: Platform user is a separate identity from app_user
The system SHALL store platform operators in a `platform_user` table that has NO `tenant_id` column and is logically distinct from the tenant-scoped `app_user` table. Platform users SHALL NOT appear in any query against `app_user` and vice versa.

#### Scenario: Platform user not visible to tenant queries
- **WHEN** a tenant-scoped query iterates `app_user` rows for tenant T
- **THEN** no `platform_user` row appears in the result, regardless of email overlap

#### Scenario: app_user not visible to platform user lookup
- **WHEN** the platform login endpoint queries by email
- **THEN** only rows in `platform_user` are returned, never rows in `app_user`

#### Scenario: REVOKE on platform_user from fabt_app
- **WHEN** the runtime database role `fabt_app` issues a SELECT against `platform_user`
- **THEN** PostgreSQL returns a permission-denied error
- **AND** access is only available via a SECURITY DEFINER function owned by the `fabt` superuser

### Requirement: Platform user bootstrap row created in V87
The system SHALL include a Flyway migration V87 that creates the `platform_user` table and inserts exactly one bootstrap row at the well-known UUID `00000000-0000-0000-0000-000000000fab` with `email = NULL`, `password_hash = NULL`, `account_locked = true`.

#### Scenario: Bootstrap row exists after V87
- **WHEN** Flyway has applied migrations through V87
- **THEN** `SELECT id, email, password_hash, account_locked FROM platform_user WHERE id = '00000000-0000-0000-0000-000000000fab'` returns exactly one row with `email IS NULL`, `password_hash IS NULL`, `account_locked = true`

#### Scenario: Operator activates the bootstrap row via psql
- **WHEN** the operator UPDATEs the bootstrap row to set `email`, `password_hash` (bcrypt-12), and `account_locked = false`
- **THEN** the row is ready for first-login MFA setup
- **AND** no application restart is required

### Requirement: Login refused when account is locked or password_hash is NULL
The system SHALL refuse login to any `platform_user` row whose `account_locked = true` OR `password_hash IS NULL`, returning HTTP 401 with a generic "Invalid credentials" body.

#### Scenario: Login attempt with NULL password_hash
- **WHEN** a request to `POST /auth/platform/login` provides correct email but the row's `password_hash IS NULL`
- **THEN** the response is HTTP 401 with `{"message":"Invalid credentials"}`
- **AND** no JWT is issued
- **AND** no information distinguishes "account locked" from "wrong password" in the response

#### Scenario: Login attempt with account_locked = true
- **WHEN** a request to `POST /auth/platform/login` provides correct email + password but `account_locked = true`
- **THEN** the response is HTTP 401 with `{"message":"Invalid credentials"}`
- **AND** no JWT is issued

### Requirement: Platform login endpoint
The system SHALL expose `POST /auth/platform/login` accepting `{email, password}` (no `tenantSlug`). On success, it SHALL return either a short-lived MFA-setup token (if MFA not yet enabled) OR a full platform JWT (if MFA already verified for this session).

#### Scenario: First login (MFA not yet enabled) returns MFA-setup token
- **WHEN** a request provides correct credentials and the row's `mfa_enabled = false`
- **THEN** the response is HTTP 200 with `{accessToken, expiresIn: 600, mfaSetupRequired: true}`
- **AND** the token's scope is limited to `/auth/platform/mfa-setup` and `/auth/platform/mfa-confirm` endpoints only
- **AND** the token expires in exactly 600 seconds

#### Scenario: Subsequent login (MFA enabled) requires TOTP
- **WHEN** a request provides correct credentials and the row's `mfa_enabled = true`
- **THEN** the response is HTTP 200 with a challenge: `{mfaChallenge: <token>, expiresIn: 60}` requiring a follow-up POST with TOTP code

#### Scenario: TOTP verification issues full platform JWT
- **WHEN** a follow-up `POST /auth/platform/login/mfa-verify` provides a valid TOTP code (or an unused backup code)
- **THEN** the response is HTTP 200 with `{accessToken, expiresIn: 900, refreshToken}` where the access token is a platform JWT (iss=fabt-platform, no tenantId claim)
- **AND** the access token expires in exactly 900 seconds (15 min)

### Requirement: Mandatory TOTP MFA enrollment on first login
The system SHALL force every platform user to enroll TOTP MFA on first login. The MFA-setup-only token SHALL NOT grant access to any other endpoint.

#### Scenario: MFA-setup token cannot access platform endpoints
- **WHEN** a request bearing an MFA-setup token attempts `GET /api/v1/platform/users` or any other platform-scoped endpoint
- **THEN** the response is HTTP 403 Forbidden

#### Scenario: MFA setup generates QR + 10 backup codes
- **WHEN** the operator visits `POST /auth/platform/mfa-setup` with the MFA-setup token
- **THEN** the response includes a TOTP secret, a QR-code image (PNG, RFC 6238 otpauth URL), and 10 single-use backup codes
- **AND** the backup codes are displayed exactly once (subsequent calls return only the QR + secret, never the codes)

#### Scenario: TOTP confirmation flips mfa_enabled = true
- **WHEN** the operator confirms MFA via `POST /auth/platform/mfa-confirm` with a valid TOTP code generated from the issued secret
- **THEN** `mfa_enabled` is set to `true` for that platform_user row
- **AND** the 10 backup codes are persisted as bcrypt hashes in `platform_user_backup_code`
- **AND** the response is HTTP 200 with a real platform JWT

### Requirement: Backup codes are single-use
The system SHALL allow each backup code to be used at most once. Used codes are marked with `used_at` and rejected on subsequent attempts.

#### Scenario: Valid backup code accepted in lieu of TOTP
- **WHEN** a TOTP-verify request provides one of the 10 backup codes (matched against bcrypt hash) instead of a TOTP code
- **THEN** the response is HTTP 200 with a platform JWT
- **AND** the row's `used_at` column is set to `NOW()`

#### Scenario: Already-used backup code rejected
- **WHEN** a TOTP-verify request provides a backup code whose `used_at IS NOT NULL`
- **THEN** the response is HTTP 401 with `{"message":"Invalid MFA code"}`

#### Scenario: Regenerate backup codes invalidates the existing 10
- **WHEN** a platform_user calls `POST /api/v1/platform/users/me/backup-codes/regenerate`
- **THEN** all existing rows in `platform_user_backup_code` for that user are DELETEd
- **AND** 10 new codes are generated and returned exactly once

### Requirement: Per-IP rate limit on platform login endpoint
The system SHALL apply a per-IP bucket4j rate limit of 5 requests per 15-minute window to `POST /auth/platform/login`. This is the password-attempt throttle; the per-account MFA lockout is a separate mechanism.

#### Scenario: 6th login attempt from same IP within 15min throttled
- **WHEN** a single IP makes 5 attempts to `/auth/platform/login` in 15 minutes (regardless of which account or whether attempts succeeded) and a 6th request arrives
- **THEN** the 6th request returns HTTP 429 with `{"error":"rate_limited","message":"Too many platform login attempts from this IP. Try again later."}`
- **AND** the request does NOT consume an MFA-lockout-counter slot (the per-account counter is independent)

### Requirement: Per-account + per-IP MFA lockout (dual mechanism)
The system SHALL implement two independent lockout counters: (a) per-`platform_user` 5-fail/15-min lockout (locks the account in DB), and (b) per-IP 20-fail/15-min lockout on `/auth/platform/*` endpoints (rejects requests from that IP regardless of which account). Both run concurrently; either trips → request rejected.

#### Scenario: 5 failed MFA attempts triggers per-account lockout
- **WHEN** a platform_user accumulates 5 failed TOTP verifications within 15 minutes
- **THEN** the row's `account_locked = true` is set
- **AND** subsequent login attempts return HTTP 401 with `{"message":"Invalid credentials"}` for the next 15 minutes
- **AND** a row is written to `platform_admin_access_log` with `action = PLATFORM_USER_LOCKED_OUT` and details including the 5 failed attempt timestamps

#### Scenario: 20 failed MFA attempts from single IP triggers per-IP lockout
- **WHEN** a single IP accumulates 20 failed TOTP verifications across any platform users within 15 minutes
- **THEN** subsequent requests from that IP to `/auth/platform/*` are rejected with HTTP 429
- **AND** valid TOTP attempts from a different IP for the same accounts still succeed (per-IP, not per-account)
- **AND** the per-IP counter is JVM-scoped (Caffeine cache, not persisted)

#### Scenario: Lockout auto-clears after 15 minutes
- **WHEN** 15 minutes elapse from the lockout timestamp
- **THEN** `account_locked` is set back to `false` automatically (cron-driven)
- **AND** the next valid login attempt succeeds

### Requirement: MFA-setup-only token scope is server-validated
The MFA-setup-only token issued at first login SHALL contain a `scope` claim that the server explicitly validates on each request. The token MUST NOT be accepted at any endpoint other than `/auth/platform/mfa-setup` or `/auth/platform/mfa-confirm`, regardless of URL routing.

#### Scenario: MFA-setup token presented to platform users endpoint
- **WHEN** a request bearing an MFA-setup token attempts `POST /api/v1/platform/users`
- **THEN** the server reads the JWT `scope` claim, observes it is `"mfa-setup-only"`, and rejects with HTTP 403
- **AND** the URL path is NOT the only basis for rejection — the scope claim is independently validated by the JwtAuthenticationConverter

#### Scenario: MFA-setup token presented to wrong MFA endpoint (defense in depth)
- **WHEN** a request bearing an MFA-setup token attempts `POST /auth/platform/login/mfa-verify`
- **THEN** the request is rejected with HTTP 403 (the scope is `mfa-setup-only`, not `mfa-verify`)

### Requirement: Backup code recovery scenario documented
The system SHALL document a recovery procedure for the case where a platform_user has lost their TOTP device AND exhausted/lost all 10 backup codes. The procedure requires either (a) another active platform_user to perform the unlock via `POST /api/v1/platform/users/{id}/reset` (Phase H+ endpoint; manual psql in v0.53), OR (b) DBA SSH access to the VM to execute the bootstrap-equivalent reset SQL.

#### Scenario: Documented recovery via second platform_user (Phase H endpoint, manual psql in v0.53)
- **WHEN** a platform_user is locked out AND another active platform_user exists AND the recovery runbook is followed
- **THEN** the other platform_user can reset the locked account via psql UPDATE: `password_hash = NULL, mfa_enabled = false, mfa_secret = NULL, account_locked = true` (back to bootstrap state); locked user re-activates via fabt-cli + new MFA enrollment

#### Scenario: Documented DBA recovery when no other platform_user exists
- **WHEN** ONLY ONE platform_user exists AND that user is locked out
- **THEN** an operator with DBA SSH access to the VM follows the same UPDATE procedure
- **AND** the runbook documents this is a `Sev-1`-equivalent operational event — provisioning a 2nd platform_user as recovery contact within first week of v0.53 is mandatory operational practice

### Requirement: Backup code hashing uses SHA-256 + per-row salt
Backup codes SHALL be hashed using SHA-256 with a per-row 16-byte random salt, NOT bcrypt. Bcrypt's slow-comparison property protects against brute-force on user-chosen passwords; backup codes are random 8-char strings used at most once each — bcrypt's overhead provides no security benefit and adds 100-200ms latency per recovery attempt.

#### Scenario: Backup code stored with salt
- **WHEN** the MFA setup endpoint generates 10 backup codes
- **THEN** each row in `platform_user_backup_code` has a unique 16-byte salt and `code_hash = sha256(salt || code)`
- **AND** verification at login time computes `sha256(stored_salt || provided_code)` and compares to `stored_code_hash`

### Requirement: MFA cannot be disabled via UI
The system SHALL NOT expose any user-facing endpoint that flips `mfa_enabled` from `true` back to `false`.

#### Scenario: No disable-MFA endpoint exists
- **WHEN** a platform_user requests `POST /api/v1/platform/users/me/mfa/disable` or any analogous endpoint
- **THEN** the response is HTTP 404 Not Found
- **AND** the only path to disable MFA is direct psql by another platform_user (or bootstrap re-activation flow via SSH + DB owner credentials)

### Requirement: Platform JWT shape and validation
The system SHALL issue platform JWTs with `iss = "fabt-platform"`, NO `tenantId` claim, `roles = ["PLATFORM_OPERATOR"]`, and a 15-minute `exp`. The cryptographic signature SHALL use a key derived from the master KEK via HKDF, stored in `platform_key_material`.

#### Scenario: Platform JWT shape
- **WHEN** a platform JWT is issued
- **THEN** decoded claims include exactly `iss="fabt-platform"`, `sub`, `roles`, `mfaVerified`, `ver`, `iat`, `exp`
- **AND** there is NO `tenantId` claim
- **AND** `exp - iat = 900`

#### Scenario: Iss-routed JwtDecoder dispatch
- **WHEN** the SecurityConfig JwtDecoder receives a token with `iss="fabt-platform"`
- **THEN** kid is resolved against `platform_key_material`, NOT against `jwt_key_generation`
- **AND** signature is verified against the platform key
- **AND** validation succeeds only if the token resolves to an active platform_key_material row

#### Scenario: Tenant kid presented with platform iss is rejected
- **WHEN** an attacker presents a JWT with `iss="fabt-platform"` but a kid that resolves only via `jwt_key_generation` (a tenant kid)
- **THEN** validation fails with `CrossTenantJwtException` (or analogous)
- **AND** the response is HTTP 401

### Requirement: Platform key material in separate table
The system SHALL store platform JWT signing key material in a `platform_key_material` table mirroring `tenant_key_material` shape but without a `tenant_id` column. Only one row SHALL be active at a time initially; rotation tooling is out of scope for this release.

#### Scenario: Platform key material schema
- **WHEN** Flyway has applied V87
- **THEN** `\d platform_key_material` shows columns: `id UUID PK, generation INT, kid TEXT UNIQUE, key_bytes BYTEA, active BOOLEAN, created_at TIMESTAMPTZ`
- **AND** there is NO `tenant_id` column

#### Scenario: First boot populates initial key generation
- **WHEN** the application starts and `platform_key_material` is empty (or has no active row)
- **THEN** the application derives a fresh signing key via HKDF from master KEK and inserts it as `(generation=1, kid=<random UUID>, key_bytes=<HKDF output>, active=true)`
- **AND** subsequent boots find the existing active row and do not insert a new one

### Requirement: Platform user creation gated by another platform_user
The system SHALL allow creation of additional platform_user rows only via an authenticated request from an existing platform_user. There is no other ingress (no UI in initial release; no public signup; no env-var-based creation after V87).

#### Scenario: Creating a second platform_user requires platform JWT
- **WHEN** a request to `POST /api/v1/platform/users` provides `{email, password}` with a valid platform JWT in the Authorization header
- **THEN** the response is HTTP 201 with the new user id
- **AND** a row is written to `platform_admin_access_log` with `action = PLATFORM_USER_CREATED`

#### Scenario: Tenant JWT cannot create platform users
- **WHEN** a request to `POST /api/v1/platform/users` provides any tenant-scoped JWT
- **THEN** the response is HTTP 403 Forbidden
