## Why

The notification table's per-user RLS policy (`recipient_id = current_setting('app.current_user_id')::uuid`) is fundamentally incompatible with system operations that need cross-user access. Every other RLS table in the system uses a binary pattern (`app.dv_access` true/false) which has a natural "see everything" value. Per-user RLS has no equivalent — nil UUID means "nobody."

This mismatch caused 3 production bugs in the first 2 hours after deploy:
1. **INSERT RETURNING fails** — Spring Data JDBC's `save()` uses `INSERT ... RETURNING *`, which triggers the SELECT policy. Nil UUID matches nobody → "violates row-level security policy."
2. **Cleanup DELETE does nothing** — DELETE WHERE clause reads go through SELECT policy. Nil UUID → zero rows visible → cleanup never deletes.
3. **Escalation dedup can't see existing notifications** — SELECT returns empty → dedup always reports "new" → 144 duplicate escalation notifications in 2 hours.

Each bug required a different RESET ROLE hack (set_config before INSERT, @Transactional + raw connection for DELETE, DataSourceUtils for dedup). The hacks were fragile — the dedup fix worked in tests but failed in production because `DataSourceUtils.getConnection()` returned a non-transaction-bound connection in the scheduler thread.

The notification table is accessed through exactly 2 code paths (`NotificationController` + `NotificationPersistenceService`), both of which already filter by `recipient_id` in every query. Notification payloads contain zero client PII (opaque IDs only). ArchUnit enforces that no other module accesses the notification repository.

## What Changes

- **RLS simplification** — Flyway V38: replace per-user SELECT and UPDATE policies with unrestricted `USING (true)`. All 4 notification policies become unrestricted for `fabt_app`. RLS remains ENABLED (not removed) so the infrastructure is in place for future tenant-scoped policies if needed.
- **Remove 3 RESET ROLE hacks** — eliminate raw connection management, set_config overrides, and @Transactional workarounds from `NotificationPersistenceService` and `ReferralEscalationJobConfig`.
- **Rewrite DB-level tests to service-level** — tests that verified per-user isolation at the DB level become REST API tests that verify the controller enforces per-user access.

## Capabilities

### Modified Capabilities
- `persistent-notification-store`: RLS policies simplified from per-user to unrestricted. Defense-in-depth moves from DB-level per-user isolation to service-level filtering. Zero PII payloads limit blast radius.

## Impact

- **Database**: V38 migration drops 2 policies, creates 2 replacements. Non-breaking — existing data unaffected.
- **Backend**: 4 files simplified (removal of RESET ROLE hacks). Net reduction in code complexity.
- **Frontend**: No changes — REST API interface unchanged.
- **Security**: Per-user isolation enforced by service layer (NotificationController extracts userId from JWT; NotificationPersistenceService receives recipientId as parameter). ArchUnit prevents unauthorized repository access. Notification payloads are zero PII by design.
- **Performance**: Query planner freed from RLS predicate evaluation. Partial index `idx_notification_unread` used directly without RLS overhead.
