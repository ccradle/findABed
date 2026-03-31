## ADDED Requirements

### Requirement: FCM device token registration
The backend SHALL provide `POST /api/v1/devices` to register an FCM device token and `DELETE /api/v1/devices/{token}` to unregister.

**Acceptance criteria:**
- Flyway migration creates `device_token` table (user_id, token, platform, created_at)
- Registering the same token twice is idempotent (upsert)
- Tokens are scoped to the authenticated user
- Backend integration test verifies registration and unregistration

### Requirement: Backend push notification sender
The `NotificationService` SHALL send FCM push notifications alongside SSE events for availability updates and DV referral responses.

**Acceptance criteria:**
- Firebase Admin SDK configured with service account credentials
- Push sent to all registered device tokens for the target user
- Push payload includes event type, shelter name, and deep link URL
- Failed push (invalid token) triggers automatic token deregistration
- SSE delivery continues to work unchanged for web users

### Requirement: Frontend push permission and registration
On native platforms, the app SHALL request push notification permission on first login and register the FCM token with the backend.

**Acceptance criteria:**
- Permission prompt shown after successful login (not on cold launch)
- If granted: FCM token sent to `POST /api/v1/devices`
- If denied: app functions normally without push (SSE still works in foreground)
- Token refreshed when FCM issues a new one

### Requirement: Background notification display
When a push notification arrives while the app is backgrounded, the OS SHALL display a native notification banner.

**Acceptance criteria:**
- Notification shows shelter name and event summary
- Tapping the notification opens the app to the relevant screen
- Badge count updates on the app icon
