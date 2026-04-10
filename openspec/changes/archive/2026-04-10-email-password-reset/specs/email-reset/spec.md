## MODIFIED Requirements

### Requirement: email-forgot-password (MODIFIED — was stub)
`POST /api/v1/auth/forgot-password` SHALL generate a SHA-256 hashed reset token with 30-minute expiry and send a reset email when SMTP is configured. Always returns 200 regardless of email existence (no account enumeration).

#### Scenario: Valid email with SMTP configured
- **GIVEN** a user with email "coordinator@example.org" in tenant "dev-coc"
- **WHEN** POST /api/v1/auth/forgot-password with `{email, tenantSlug}`
- **THEN** a password_reset_token row SHALL be created with SHA-256 hash and 30-min expiry
- **AND** an email SHALL be sent with a reset link containing the plaintext token
- **AND** response SHALL be 200 with "If the email exists, a reset link has been sent."

#### Scenario: Non-existent email (no enumeration)
- **GIVEN** no user with email "nobody@example.org" exists
- **WHEN** POST /api/v1/auth/forgot-password with that email
- **THEN** response SHALL be 200 with the same message as a valid email
- **AND** no token SHALL be created, no email SHALL be sent
- **AND** response time SHALL be consistent with the valid-email case

#### Scenario: DV user blocked (D3)
- **GIVEN** a user with dvAccess=true
- **WHEN** POST /api/v1/auth/forgot-password with their email
- **THEN** response SHALL be 200 with the same message (no enumeration)
- **AND** no token SHALL be created, no email SHALL be sent

#### Scenario: SMTP not configured
- **GIVEN** spring.mail.host is empty
- **WHEN** POST /api/v1/auth/forgot-password
- **THEN** response SHALL be 200 with the same message
- **AND** no email SHALL be sent (silently succeed)

#### Scenario: Email send failure (SMTP error)
- **GIVEN** SMTP is configured but the mail server rejects the message
- **WHEN** POST /api/v1/auth/forgot-password for a valid email
- **THEN** the token row SHALL be deleted from password_reset_token (no orphaned tokens)
- **AND** response SHALL be 200 with the same message (no error leak)
- **AND** the failure SHALL be logged at ERROR level

### Requirement: email-reset-password (MODIFIED — was 503 stub)
`POST /api/v1/auth/reset-password` SHALL validate a reset token and set a new password. Invalidates token and all existing JWTs.

#### Scenario: Valid token resets password
- **GIVEN** a valid, unused, non-expired reset token
- **WHEN** POST /api/v1/auth/reset-password with `{token, newPassword}`
- **THEN** the user's password SHALL be updated (BCrypt hashed)
- **AND** the token SHALL be marked as used
- **AND** tokenVersion SHALL be incremented (invalidating all existing JWTs)
- **AND** response SHALL be 200

#### Scenario: Expired token rejected
- **GIVEN** a reset token created 31 minutes ago (expired)
- **WHEN** POST /api/v1/auth/reset-password with that token
- **THEN** response SHALL be 400 with "Invalid or expired reset token"

#### Scenario: Used token rejected (single-use)
- **GIVEN** a reset token that has already been used
- **WHEN** POST /api/v1/auth/reset-password with that token
- **THEN** response SHALL be 400 with "Invalid or expired reset token"

#### Scenario: Invalid token rejected
- **GIVEN** a random string that doesn't match any stored token hash
- **WHEN** POST /api/v1/auth/reset-password with that string
- **THEN** response SHALL be 400 with "Invalid or expired reset token"

#### Scenario: Password too short rejected
- **GIVEN** a valid reset token
- **WHEN** POST /api/v1/auth/reset-password with newPassword of 5 characters
- **THEN** response SHALL be 400 with validation error (minimum 12 characters)

### Requirement: totp-intact-after-reset (ADDED)
Email-based password reset SHALL NOT modify TOTP enrollment, TOTP secret, or recovery codes. The user's next login SHALL require both the new password AND their TOTP code.

#### Scenario: TOTP user resets password via email
- **GIVEN** a user with totp_enabled=true who reset their password via email
- **WHEN** they log in with the new password
- **THEN** the login response SHALL contain `mfaRequired: true`
- **AND** the user must provide their TOTP code to complete login

### Requirement: dv-user-email-reset-blocked (ADDED)
Users with dvAccess=true SHALL NOT receive password reset emails. The forgotPassword endpoint SHALL silently succeed (no account enumeration) but SHALL NOT generate a token or send an email.

#### Scenario: DV user's email is invisible to reset flow
- **GIVEN** two users: one with dvAccess=false, one with dvAccess=true
- **WHEN** POST /forgot-password is called for each
- **THEN** both responses SHALL be identical (200, same message, same timing)
- **AND** only the non-DV user SHALL receive an email

### Requirement: token-version-increment-on-password-change (ADDED — bug fix)
All password change operations SHALL increment tokenVersion to invalidate existing JWTs immediately. This includes self-service password change, admin password reset, and email-based password reset.

#### Scenario: Self-service password change invalidates old JWTs
- **GIVEN** a user with an active access token
- **WHEN** they change their password via PUT /api/v1/auth/password
- **THEN** tokenVersion SHALL be incremented
- **AND** the old access token SHALL be rejected on the next request

### Requirement: generic-email-content (ADDED)
Password reset emails SHALL NOT contain the platform name, organization name, or any language identifying the platform as a shelter/homelessness/DV service. Subject line SHALL be "Password Reset Request" only.

#### Scenario: Email does not reveal platform purpose
- **WHEN** a password reset email is sent
- **THEN** the subject SHALL be "Password Reset Request"
- **AND** the body SHALL NOT contain "Finding A Bed Tonight", "shelter", "bed", "homelessness", or "domestic violence"

### Requirement: password-reset-token-schema (ADDED)
A `password_reset_token` table SHALL store email reset tokens with SHA-256 hashing. Flyway V39.

#### Scenario: Token stored with SHA-256 hash
- **WHEN** a reset token is generated
- **THEN** the plaintext token SHALL NOT be stored in the database
- **AND** the SHA-256 hex digest of the token SHALL be stored in `token_hash`
- **AND** validation SHALL use direct hash lookup (WHERE token_hash = SHA-256(input))
