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
