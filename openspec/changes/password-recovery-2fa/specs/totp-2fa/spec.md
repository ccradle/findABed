## ADDED Requirements

### Requirement: TOTP enrollment

The system SHALL allow authenticated users to enroll in TOTP two-factor authentication.

#### Scenario: User enrolls in TOTP

- **WHEN** an authenticated user calls POST /api/v1/auth/enroll-totp
- **THEN** the response includes a QR code URI and base32 secret
- **AND** the secret is NOT stored until the user verifies their first TOTP code

#### Scenario: User confirms TOTP enrollment

- **WHEN** the user submits a valid TOTP code during enrollment
- **THEN** totp_enabled is set to true, the secret is stored, and 8 recovery codes are returned
- **AND** the recovery codes are displayed once and stored bcrypt-hashed

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
- **THEN** the response is 401 and the mfaToken remains valid for retry (until 5-min expiry)

#### Scenario: Recovery code can substitute for TOTP

- **WHEN** a user submits a valid recovery code instead of a TOTP code
- **THEN** the login succeeds and the recovery code is marked as consumed

### Requirement: Admin can disable 2FA

The system SHALL allow admins to disable TOTP for a user (e.g., lost device).

#### Scenario: Admin disables user's 2FA

- **WHEN** a COC_ADMIN calls DELETE /api/v1/users/{id}/totp
- **THEN** totp_enabled is set to false, totp_secret is cleared, and an audit event is recorded
