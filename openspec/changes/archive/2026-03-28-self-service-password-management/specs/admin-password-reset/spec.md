## admin-password-reset

Admin-initiated password reset for users in their tenant.

### Requirements

- REQ-ARST-1: COC_ADMIN and PLATFORM_ADMIN MUST be able to reset a user's password via `POST /api/v1/users/{id}/reset-password`
- REQ-ARST-2: Admin can only reset passwords for users in their own tenant
- REQ-ARST-3: Same password strength validation as self-service (minimum 12 characters)
- REQ-ARST-4: After admin reset, the user's existing JWT tokens MUST be invalidated
- REQ-ARST-5: A "Reset Password" button MUST appear per user row in the Admin panel Users tab
- REQ-ARST-6: The temporary password MUST be communicated out-of-band — not stored or displayed after the modal closes
- REQ-ARST-7: The "Reset Password" button MUST be hidden for SSO-only users in the Admin panel

### Scenarios

```gherkin
Scenario: Admin resets a user's password
  Given a COC_ADMIN is viewing the Users tab
  When they click "Reset Password" for a coordinator
  And enter a new temporary password
  Then the coordinator's password hash is updated
  And the coordinator's tokens are invalidated
  And the admin sees a success message

Scenario: Admin cannot reset password for user in different tenant
  Given a COC_ADMIN for Tenant A
  When they attempt to reset a password for a user in Tenant B
  Then the response is 404 (user not found in their tenant)

Scenario: Coordinator cannot reset passwords
  Given a user with COORDINATOR role
  When they attempt POST /api/v1/users/{id}/reset-password
  Then the response is 403
```
