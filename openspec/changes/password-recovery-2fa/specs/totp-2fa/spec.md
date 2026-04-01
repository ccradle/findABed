## ADDED Requirements

### Requirement: TOTP enrollment

The system SHALL allow authenticated users to enroll in TOTP two-factor authentication.

#### Scenario: User enrolls in TOTP

- **WHEN** an authenticated user calls POST /api/v1/auth/enroll-totp
- **THEN** the response includes a QR code URI and base32 secret
- **AND** the secret is NOT stored until the user verifies their first TOTP code

#### Scenario: User confirms TOTP enrollment

- **WHEN** the user submits a valid TOTP code during enrollment
- **THEN** totp_enabled is set to true, the secret is stored AES-256-GCM encrypted (D11), and 8 backup codes are returned
- **AND** the backup codes are displayed once with copy/download/print options and stored bcrypt-hashed
- **AND** user is warned: "These codes will not be shown again. Print them and store in a safe place."

#### Scenario: Concurrent enrollment replaces previous

- **WHEN** a user initiates enrollment from a second device while the first is pending
- **THEN** the second enrollment invalidates the first (only one pending secret at a time)

### Requirement: Two-phase TOTP login

The system SHALL require TOTP verification as a second factor for users with 2FA enabled.

#### Scenario: Login with 2FA enabled returns mfaRequired

- **WHEN** a user with totp_enabled=true submits correct password via POST /api/v1/auth/login
- **THEN** the response is {mfaRequired: true, mfaToken: "<signed-5-min-token>"} instead of JWTs

#### Scenario: Valid TOTP code completes login

- **WHEN** the user submits a valid TOTP code with the mfaToken via POST /api/v1/auth/verify-totp
- **THEN** access and refresh JWTs are issued

#### Scenario: Invalid TOTP code is rejected

- **WHEN** the user submits an incorrect TOTP code
- **THEN** the response is 401 and the mfaToken remains valid for retry (until 5-min expiry or 5 failed attempts)

#### Scenario: mfaToken is single-use after successful verification

- **WHEN** a user successfully completes TOTP verification
- **THEN** the mfaToken's jti is added to a short-lived blocklist (5-min TTL)
- **AND** any subsequent use of the same mfaToken is rejected with 401

#### Scenario: Rate limiting on verify-totp (5 attempts per mfaToken)

- **WHEN** a user submits 5 incorrect TOTP codes for the same mfaToken
- **THEN** the mfaToken is invalidated and the user must re-enter their password
- **AND** this prevents brute-force of the 6-digit TOTP space within the 5-minute window

#### Scenario: TOTP validation accepts ±1 time step (clock drift)

- **GIVEN** the server time and authenticator app may differ by up to 30 seconds
- **WHEN** a user submits a TOTP code from the previous or next 30-second window
- **THEN** the code is accepted (standard RFC 6238 ±1 step tolerance)

#### Scenario: Recovery code can substitute for TOTP

- **WHEN** a user submits a valid recovery code instead of a TOTP code
- **THEN** the login succeeds and the recovery code is marked as consumed

### Requirement: Admin can disable 2FA

The system SHALL allow admins to disable TOTP for a user (e.g., lost device).

#### Scenario: Admin disables user's 2FA

- **WHEN** a COC_ADMIN calls DELETE /api/v1/users/{id}/totp
- **THEN** totp_enabled is set to false, totp_secret_encrypted is cleared, and an audit event is recorded

### Requirement: Recovery code regeneration

Users SHALL be able to regenerate backup codes, invalidating all previous codes.

#### Scenario: User regenerates backup codes

- **WHEN** an authenticated user calls POST /api/v1/auth/regenerate-recovery-codes
- **THEN** all previous codes are invalidated, 8 new codes are generated and returned (displayed once)
- **AND** the action is audit-logged

#### Scenario: Admin regenerates backup codes for a user

- **WHEN** a COC_ADMIN calls POST /api/v1/users/{id}/regenerate-recovery-codes
- **THEN** the user's previous codes are invalidated, 8 new codes are generated
- **AND** the codes are returned to the admin (for verbal communication to the user)
- **AND** the action is audit-logged

### Requirement: TOTP secret encrypted at rest

TOTP secrets SHALL be encrypted with AES-256-GCM before storage. The encryption key SHALL be sourced from an environment variable, NOT stored in the database.

#### Scenario: TOTP secret not stored in plaintext

- **GIVEN** a user enrolls in TOTP
- **THEN** the database column `totp_secret_encrypted` contains AES-256-GCM ciphertext
- **AND** the encryption key is from `FABT_TOTP_ENCRYPTION_KEY` env var
- **AND** the plaintext base32 secret is never logged or persisted unencrypted
