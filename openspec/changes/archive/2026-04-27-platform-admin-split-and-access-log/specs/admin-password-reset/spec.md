## MODIFIED Requirements

### Requirement: admin-password-reset
The system SHALL allow `COC_ADMIN` to reset passwords for users in their own tenant via `POST /api/v1/users/{id}/reset-password`. (Previously: `COC_ADMIN and PLATFORM_ADMIN`. PLATFORM_ADMIN is deprecated; backward-compat preserved through v0.53 by COC_ADMIN backfill in V87.)

- REQ-ARST-1: `COC_ADMIN` MUST be able to reset a user's password via `POST /api/v1/users/{id}/reset-password`
- REQ-ARST-2: Admin can only reset passwords for users in their own tenant
- REQ-ARST-3: Same password strength validation as self-service (minimum 12 characters)
- REQ-ARST-4: After admin reset, the user's existing JWT tokens MUST be invalidated
- REQ-ARST-5: A "Reset Password" button MUST appear per user row in the Admin panel Users tab
- REQ-ARST-6: The temporary password MUST be communicated out-of-band — not stored or displayed after the modal closes
- REQ-ARST-7: The "Reset Password" button MUST be hidden for SSO-only users in the Admin panel

#### Scenario: COC_ADMIN resets a user password in their tenant
- **WHEN** a `COC_ADMIN` of tenant T sends `POST /api/v1/users/{id}/reset-password` for a user belonging to tenant T
- **THEN** the system returns the temporary password in the response body (one-shot)
- **AND** the target user's existing JWTs are invalidated immediately

#### Scenario: COC_ADMIN cannot reset a password in another tenant
- **WHEN** a `COC_ADMIN` of tenant A sends `POST /api/v1/users/{id}/reset-password` for a user belonging to tenant B
- **THEN** the response is HTTP 404 Not Found (no information disclosure on cross-tenant queries)

#### Scenario: PLATFORM_ADMIN-only JWT can still reset during deprecation window
- **WHEN** a JWT bearing only `PLATFORM_ADMIN` is presented during the v0.53 deprecation window
- **THEN** the operation succeeds because the V87 backfill added COC_ADMIN to all PLATFORM_ADMIN-bearing rows
