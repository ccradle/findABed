## Context

SSE real-time notifications work correctly for connected users but are ephemeral — stored only in React `useState`, lost on logout. DV shelter referrals have a 4-hour expiration window. If a coordinator logs out and a referral arrives, they have no way to know it's waiting when they return. The coordinator dashboard only shows pending referral badges after manually expanding a DV shelter card — there's no proactive indicator.

Commercial HMIS platforms such as Clarity Human Services (Bitfocus) offer persistent in-app notifications, email alerts, and referral aging alerts at configurable intervals. We are designing similar notification patterns using our existing PostgreSQL + Spring Boot + SSE stack, adapted for our open-source single-instance deployment model.

## Goals / Non-Goals

**Goals:**
- Persist all actionable notifications in PostgreSQL (survive logout/restart)
- Deliver unread notifications on login via SSE catch-up batch
- Source bell badge count from DB (not in-memory)
- Show pending DV referral count on coordinator dashboard at page load (collapsed view)
- Escalate unacknowledged DV referrals (1h reminder, 2h CoC admin, 3.5h expiry warning)
- Maintain support for VAWA/FVPSA compliance requirements: zero PII in notification payloads

**Non-Goals:**
- Email/SMS notification channels (Phase 2, requires SMTP/Twilio integration)
- Web Push via VAPID keys (Phase 2, requires service worker push subscription management)
- PostgreSQL LISTEN/NOTIFY (not needed for single-instance lite tier; service layer holds both DB and SSE emitter)
- Notification preferences/settings UI (all notifications delivered; no opt-out for safety-critical DV alerts)

## Design Decisions

### D1: Inbox Pattern (one row per recipient)

Write one notification row per recipient. At our scale (dozens of users, not millions), the inbox pattern is simpler than fan-out (single row, multiple readers via join). Each row has a single `recipient_id` FK to `app_user`.

### D2: JSONB Payload with Zero PII

Notification payload uses JSONB for flexibility but stores only opaque identifiers: `{"referralId": "uuid", "status": "ACCEPTED", "shelterId": "uuid"}`. Never store client names, addresses, or any personally identifying information. This is a VAWA/FVPSA requirement — victim service providers must not enter PII into databases beyond what's strictly necessary. The frontend resolves display names from the referral/shelter APIs at render time.

### D3: Three Severity Tiers

| Severity | UX Treatment | Examples |
|----------|-------------|---------|
| CRITICAL | Persistent red banner at top of page on login if unread (not a modal — user must navigate to act, banner stays until acted on) | DV referral expiring in <1h, referral pending >2h, surge activated |
| ACTION_REQUIRED | Orange badge on bell, toast on arrival | New DV referral pending review, referral accepted/rejected |
| INFO | Badge count increment only | Availability update, referral acknowledged |

CRITICAL notifications cannot be dismissed without acting (accept/reject the referral). ACTION_REQUIRED can be marked as read. INFO auto-expires.

### D4: SSE Catch-Up on Connect (Not Polling)

When a user's SSE connection establishes, `NotificationService.registerEmitter()` queries unread notifications from PostgreSQL and sends them as a batch before real-time events begin. This replaces the current pattern where SSE starts empty and only delivers events that fire while connected. No client-side polling needed — the catch-up is server-push.

### D5: Write-Through (DB + SSE in Same Method)

`NotificationPersistenceService.send()` writes the DB row AND pushes to the SSE emitter in a single method call. No LISTEN/NOTIFY bridge needed because the same JVM process holds both the database connection and the SSE emitter map. If the user is connected, they get real-time SSE. If not, the DB row waits for catch-up on next login. Idempotent by notification ID — SSE delivery of an already-read notification is a no-op on the frontend.

### D6: Escalation via @Scheduled (Not Event-Driven)

DV referral escalation runs on a fixed schedule (every 5 minutes), scanning for pending referrals past their escalation thresholds. This is simpler than event-driven timers and self-healing (missed ticks catch up on next run). Uses the existing `@Scheduled` pattern with ShedLock comment for future multi-instance.

| Threshold | Action |
|-----------|--------|
| T+1h | Create ACTION_REQUIRED notification to assigned coordinator |
| T+2h | Create CRITICAL notification to CoC admin (escalation) |
| T+3.5h | Create CRITICAL notification to coordinator + outreach worker (30-min expiry warning) |
| T+4h | Referral expires → ACTION_REQUIRED notification to outreach worker (family may be waiting) |

### D7: Coordinator Dashboard Pending Count

On `CoordinatorDashboard` mount, fetch `GET /api/v1/dv-referrals/pending/count` (new lightweight endpoint). Returns total pending referrals across all DV shelters the coordinator is assigned to. Displayed as a persistent banner at the top of the dashboard — not dismissable, only resolves when referrals are actioned. Also show badge count on collapsed shelter cards for DV shelters with pending referrals.

### D8: Notification Cleanup

`@Scheduled` daily job: delete read notifications older than 90 days. Unread CRITICAL notifications are never auto-deleted — they persist until acted on. This prevents table bloat while maintaining safety-critical audit trail.

### D9: RLS on Notification Table

Row Level Security policy: `recipient_id` must match the authenticated user's ID. Same enforcement pattern as DV shelter access — `fabt_app` role is NOSUPERUSER, RLS is always enforced. Prevents cross-user notification access.
