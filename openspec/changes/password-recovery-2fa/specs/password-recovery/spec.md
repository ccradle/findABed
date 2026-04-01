## ADDED Requirements

### Requirement: Admin-generated temporary access code

The system SHALL allow admins to generate time-limited access codes for locked-out users.

#### Scenario: Admin generates access code

- **WHEN** a COC_ADMIN calls POST /api/v1/users/{id}/generate-access-code
- **THEN** a single-use code is returned with 15-minute expiry
- **AND** the code is stored hashed in the database

#### Scenario: Worker uses access code to log in

- **WHEN** a user enters a valid access code on the login screen
- **THEN** they are authenticated and required to set a new password before proceeding

#### Scenario: Expired access code is rejected

- **WHEN** a user enters an access code older than 15 minutes
- **THEN** the response is 401 with message "Access code expired"

#### Scenario: DV-role user reset requires DV-authorized admin

- **WHEN** an admin without dvAccess attempts to generate an access code for a dvAccess user
- **THEN** the response is 403 Forbidden

### Requirement: Email-based password reset

The system SHALL support email-based password reset for users with email access.

#### Scenario: User requests password reset

- **WHEN** a user submits their email via POST /api/v1/auth/forgot-password
- **THEN** the response is always 200 (no account enumeration)
- **AND** if the email exists and SMTP is configured, a reset link is sent

#### Scenario: User resets password via email link

- **WHEN** a user clicks a valid reset link and submits a new password
- **THEN** the password is updated and all existing tokens are invalidated

#### Scenario: Reset token expires after 30 minutes

- **WHEN** a user clicks a reset link older than 30 minutes
- **THEN** the response indicates the link has expired

#### Scenario: "Forgot Password?" hidden when SMTP not configured

- **GIVEN** SMTP is not configured on the backend
- **WHEN** the login page loads and calls GET /api/v1/auth/capabilities
- **THEN** `emailResetAvailable` is false and "Forgot Password?" is not displayed
- **AND** the admin OTT code path remains available regardless

### Requirement: Password change required after access code login

After logging in with an access code, the user SHALL be required to set a new password before accessing any other functionality.

#### Scenario: Access code user blocked from other endpoints

- **GIVEN** a user logged in via access code and has `mustChangePassword: true` in their JWT
- **WHEN** they try to access any endpoint except PUT /api/v1/auth/password
- **THEN** the response is 403 with error code `password_change_required`

### Requirement: OTT token cleanup

Expired one-time tokens SHALL be cleaned up by a scheduled task to prevent table bloat.

#### Scenario: Expired tokens purged hourly

- **GIVEN** expired OTT tokens exist in the database
- **WHEN** the hourly cleanup scheduler runs
- **THEN** all expired tokens are deleted
