## Purpose

Password recovery mechanisms for locked-out users: admin-generated one-time access codes (primary) and email-based reset (secondary, requires SMTP). Includes PasswordChangeRequiredFilter and OTT cleanup.

## ADDED Requirements

### Requirement: Admin-generated temporary access code

The system SHALL allow admins to generate time-limited access codes for locked-out users. Codes are bcrypt-hashed, 15-minute expiry, single-use. DV safeguard: generating code for dvAccess user requires dvAccess admin.

### Requirement: Email-based password reset

The system SHALL support email-based password reset when SMTP is configured. Always returns 200 (no account enumeration). "Forgot Password?" hidden when SMTP not configured (auth capabilities endpoint).

### Requirement: Password change required after access code login

After access-code login, PasswordChangeRequiredFilter blocks all API calls except PUT /api/v1/auth/password with 403 `password_change_required`. JWT carries `mustChangePassword: true` claim.

### Requirement: OTT token cleanup

Expired one-time tokens cleaned up hourly by AccessCodeCleanupScheduler.
