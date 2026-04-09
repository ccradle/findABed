## Context

The notification table (V35) has 4 RLS policies. SELECT and UPDATE use per-user isolation (`recipient_id = current_setting('app.current_user_id')::uuid`). DELETE and INSERT are unrestricted (`USING (true)` / `WITH CHECK (true)`). The per-user policies caused 3 production bugs because system operations (cleanup, escalation dedup, INSERT RETURNING) have no user context.

Every other RLS table uses a binary pattern (`app.dv_access` true/false). The notification table is the only one using per-user isolation. The binary pattern works because `dvAccess=true` is a universal bypass. Per-user isolation has no universal bypass — nil UUID means "nobody."

The notification table is accessed through 2 code paths only:
1. `NotificationController` — extracts userId from JWT authentication
2. `NotificationPersistenceService` — receives recipientId as method parameter

Both already include `WHERE recipient_id = ?` in every query. ArchUnit rule `notification_should_not_access_other_repositories` enforces module boundary isolation.

## Goals / Non-Goals

**Goals:**
- Remove per-user SELECT and UPDATE RLS policies from notification table
- Remove all RESET ROLE hacks from Java code (3 locations)
- Rewrite DB-level isolation tests as service-level (REST API) tests
- Maintain service-layer per-user filtering (no change to controller or service queries)
- Net reduction in code complexity

**Non-Goals:**
- Adding tenant-scoped RLS (future — requires `app.current_tenant_id` session variable wiring)
- Removing RLS entirely from notification table (keep ENABLED for future policy additions)
- Changing the `app.current_user_id` session variable infrastructure (harmless, leave in place)
- Changing frontend code (REST API interface unchanged)

## Design Decisions

### D1: All 4 Policies Become USING (true)

Replace per-user SELECT and UPDATE policies with `USING (true)`. DELETE and INSERT are already unrestricted. Result: RLS is enabled but effectively no-op for `fabt_app`. This eliminates ALL the per-user RLS interactions that caused production bugs.

Why not tenant-scoped: We don't set `app.current_tenant_id` as a PostgreSQL session variable. Adding it means changing `RlsDataSourceConfig` — the same infrastructure that caused our problems. Simplest correct solution first.

### D2: Service Layer Is the Security Boundary

Per-user notification access is enforced by:
- `NotificationController.list()`: `userId = (UUID) authentication.getPrincipal()`
- `NotificationController.count()`: same
- `NotificationController.markRead()`: RLS UPDATE was recipient-scoped but the controller only allows marking your own (userId from JWT)
- `NotificationPersistenceService.send()`: receives recipientId explicitly
- `NotificationRepository` queries: all include `recipient_id = :recipientId`

This is the same enforcement model used for most other tables (shelters, reservations, referrals) — the service layer validates access, the DB enforces structural constraints (FK, NOT NULL, unique).

### D3: Remove All RESET ROLE Hacks

Three locations where RESET ROLE was added to work around per-user RLS:

1. `NotificationPersistenceService.send()` — `set_config('app.current_user_id', recipientId, true)` before `notificationRepository.save()`. Needed because INSERT RETURNING triggers SELECT policy.
2. `NotificationPersistenceService.cleanupOldNotifications()` — `@Transactional` + `RESET ROLE` via JdbcTemplate on same connection. Needed because DELETE WHERE reads go through SELECT policy.
3. `ReferralEscalationJobConfig.isNew()` — raw `dataSource.getConnection()` + RESET ROLE. Needed because dedup SELECT is filtered by per-user policy.

All three become unnecessary when SELECT and UPDATE policies are unrestricted. Replace with direct repository calls.

### D4: Rewrite Tests at the Correct Level

DB-level isolation tests become REST API tests. The controller is the security boundary — test THAT, not the DB policy. Tests that verify notification functionality (markAllRead excludes CRITICAL, cleanup preserves unread CRITICAL, batch insert, etc.) remain unchanged.

### D5: Keep RLS Enabled

`ALTER TABLE notification ENABLE ROW LEVEL SECURITY` stays in place. The policies are all `USING (true)` but the infrastructure exists if we later add tenant-scoped policies. Removing ENABLE would require a separate migration and decision.
