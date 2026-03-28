## Why

Users currently have no way to change their own password. The `UserController` comment explicitly states "Email and password cannot be changed." If Sandra Kim (AI persona, Coordinator) forgets her password, or if Darius Webb's (AI persona, Outreach Worker) phone is lost/stolen, there is no mechanism to rotate credentials — the CoC admin would have to delete and recreate the account. Marcus Webb (AI persona, AppSec) flags this as a security gap: compromised credentials persist until account deletion. Teresa Nguyen's (AI persona, City Official) city attorney will ask about credential management during procurement evaluation. NIST 800-63B recommends password change capability for all authenticated systems.

## What Changes

- Add authenticated password change endpoint (current password + new password)
- Add admin-initiated password reset (COC_ADMIN/PLATFORM_ADMIN resets for any user in their tenant)
- Add "Change Password" UI in the user profile/settings area
- Add "Reset Password" action in the Admin panel's Users tab
- Password strength validation (minimum length, complexity per NIST 800-63B)
- Invalidate all existing JWT tokens for the user after password change (force re-login)

## Capabilities

### New Capabilities
- `password-change`: Authenticated self-service password change (requires current password)
- `admin-password-reset`: Admin-initiated password reset for users in their tenant

### Modified Capabilities
- `auth-and-roles`: New API endpoints for password change and admin reset
- `ui-test-suite`: Playwright tests for password change and admin reset flows

## Impact

- **Backend**: New endpoints in `AuthController` or `UserController`, password validation service
- **Frontend**: New "Change Password" UI component, Admin panel "Reset Password" button
- **Security**: JWT invalidation after password change, rate limiting on password change endpoint
- **Testing**: Integration tests for password change/reset, Playwright e2e for UI flows
- **Documentation**: Runbook update for password management procedures
