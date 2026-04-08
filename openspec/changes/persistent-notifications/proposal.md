## Why

SSE notifications are in-memory only (React `useState`). When a user logs out, all notifications are lost. For DV shelter referrals — which have a 4-hour expiration window — this is a safety-critical gap. A coordinator who steps away may never discover a pending referral. An outreach worker who loses phone battery may not know their referral was accepted. Clarity Human Services (the HMIS market leader) solves this with persistent email + in-app banner + referral aging alerts. We need the same reliability without adding new infrastructure services.

Additionally, the coordinator dashboard only shows pending referral badges after manually expanding a DV shelter card. There is no collapsed-view indicator or dashboard-level summary of waiting referrals.

## What Changes

- **Persistent notification store** — PostgreSQL `notification` table with JSONB payload, severity tiers (INFO, ACTION_REQUIRED, CRITICAL), read/acted timestamps, and tenant-scoped RLS
- **REST endpoints** — fetch unread notifications, mark as read, unread count for bell badge
- **Login catch-up** — on SSE connect, query unread notifications from DB and deliver as a batch before real-time events begin
- **Bell badge from DB** — notification count sourced from persistent store, survives logout/login
- **Coordinator dashboard referral banner** — on mount, fetch pending referral count across all coordinator's DV shelters; show persistent banner ("2 referrals waiting for review") on collapsed view
- **DV referral escalation** — `@Scheduled` aging alerts: 1h reminder, 2h CoC admin escalation, 3.5h expiry warning, 4h expired notification
- **Notification payload privacy** — designed to support VAWA/FVPSA: no PII in notification payloads. JSONB stores only opaque identifiers (referralId, status), never client information

## Capabilities

### New Capabilities
- `persistent-notification-store`: PostgreSQL notification table, NotificationPersistenceService, Flyway migration, RLS, cleanup scheduler
- `notification-rest-api`: REST endpoints for unread fetch, mark read, count; integrated with existing auth
- `notification-login-catchup`: SSE catch-up on connect — deliver unread batch from DB before real-time events
- `dv-referral-escalation`: Scheduled aging alerts, CoC admin escalation, expiry warnings for DV referrals
- `coordinator-referral-banner`: Dashboard-level pending referral indicator on mount (not just expanded card)

### Modified Capabilities
- `sse-real-time-notifications`: Bell badge count now sourced from persistent DB, not in-memory array. SSE still delivers real-time push; DB is the durable fallback.

## Impact

- **Backend**: New `notification` module (service, repository, controller, domain), Flyway V35, `@Scheduled` escalation job. Modifications to `NotificationService` (write to DB on event publish, catch-up on connect).
- **Frontend**: `useNotifications` hook reads from REST on mount instead of starting empty. Bell badge from `GET /notifications/count`. New `CoordinatorReferralBanner` component. `CoordinatorDashboard` fetches pending count on mount.
- **Database**: New `notification` table with partial index, RLS policy. ~1KB per notification row, cleanup after 90 days.
- **Security**: RLS on notification table (tenant isolation). No PII in JSONB payload. Notification content opaque per VAWA.
- **No new infrastructure**: PostgreSQL only. No Redis, Kafka, or external notification services.
