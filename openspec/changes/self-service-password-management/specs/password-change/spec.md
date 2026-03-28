## password-change

Authenticated self-service password change with JWT invalidation.

### Requirements

- REQ-PWD-1: Authenticated users MUST be able to change their password via `PUT /api/v1/auth/password`
- REQ-PWD-2: Password change MUST require the current password for verification
- REQ-PWD-3: New password MUST be at least 12 characters (NIST 800-63B — length over complexity)
- REQ-PWD-4: After password change, all existing JWT tokens for that user MUST be invalidated (force re-login)
- REQ-PWD-5: JWT invalidation MUST use a `password_changed_at` timestamp comparison, not a token blocklist
- REQ-PWD-6: Password change endpoint MUST be rate-limited (5 attempts per 15 minutes)
- REQ-PWD-7: A "Change Password" UI MUST be accessible from the user profile area
- REQ-PWD-8: On successful change, the user MUST be redirected to the login page with a clear message

### Scenarios

```gherkin
Scenario: User changes their password
  Given a user is authenticated
  When they submit current password + new password via PUT /api/v1/auth/password
  Then the password hash is updated in the database
  And all existing tokens are invalidated
  And the response instructs the user to sign in again

Scenario: Wrong current password rejected
  Given a user is authenticated
  When they submit an incorrect current password
  Then the response is 401 with "Current password is incorrect"
  And the password is not changed

Scenario: Weak new password rejected
  Given a user is authenticated
  When they submit a new password shorter than 12 characters
  Then the response is 422 with a message about minimum length
  And the password is not changed

Scenario: Token issued before password change is rejected
  Given a user changed their password at time T
  When a request uses a JWT issued before time T
  Then the response is 401
```
