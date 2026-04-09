## Tasks

### Setup

- [x] T-0: Work directly on main (demo site backend is down — no separate branch needed for hotfix)

### Database Migration

- [x] T-1: Flyway V38: DROP `notification_recipient_read_policy` + `notification_recipient_write_policy`. CREATE `notification_read_policy FOR SELECT USING (true)` + `notification_write_policy FOR UPDATE USING (true)`. Include detailed comment explaining WHY (per-user was wrong pattern, 3 production bugs, service layer is the security boundary).

### Backend — Remove RESET ROLE Hacks

- [ ] T-2: `NotificationPersistenceService.send()`: remove `jdbcTemplate.queryForObject("SELECT set_config('app.current_user_id', ?, true)")`. Remove the Javadoc about RLS RETURNING workaround.
- [ ] T-2a: Add `recipientId` parameter to `NotificationRepository.markRead(UUID id, UUID recipientId)` and `markActed(UUID id, UUID recipientId)`. Update SQL: `WHERE id = :id AND recipient_id = :recipientId`. This replaces the UPDATE RLS policy as the security boundary.
- [ ] T-2b: Update `NotificationController.markRead()` and `markActed()` to extract `userId` from Authentication and pass to `NotificationPersistenceService.markRead(id, userId)` and `markActed(id, userId)`. Update service methods to accept and pass `recipientId`.
- [ ] T-3: `NotificationPersistenceService.cleanupOldNotifications()`: remove RESET ROLE + try/finally. Remove `@Transactional` (the repository method has its own `@Transactional`). Simplify to direct `notificationRepository.deleteOldRead(cutoff)` call. Update Javadoc — remove RLS note, keep the cleanup retention and CRITICAL preservation documentation.
- [ ] T-4: `ReferralEscalationJobConfig.isNew()`: replace raw `dataSource.getConnection()` + RESET ROLE with `notificationRepository.existsByTypeAndReferralId(type, referralId)`. Remove `DataSource` field from constructor. Remove `javax.sql.DataSource` import.
- [ ] T-5: Verify `NotificationPersistenceService` still needs `JdbcTemplate` — if cleanup and send no longer use it, remove the field. If other methods still use it, keep it.

### Backend — Tests

- [ ] T-6: Rewrite `NotificationRlsIntegrationTest.userCanOnlyReadOwnNotifications`: change from direct DB check to REST API test — coordinator GET returns only their notifications (via JWT auth), not outreach worker's. Use `restTemplate.exchange` with different auth headers.
- [ ] T-7: Rewrite `NotificationRlsIntegrationTest.markReadOnOtherUsersNotificationIsNoop`: test via REST API — outreach worker's PATCH on coordinator's notification has no effect. Verify via coordinator's subsequent GET that notification is still unread.
- [ ] T-8: Rewrite `NotificationRlsIntegrationTest.crossTenantNotificationIsolation`: test via REST API — tenant B coordinator's GET returns only tenant B notifications.
- [ ] T-9: Simplify `NotificationRlsIntegrationTest.cleanupDeletesOldReadPreservesUnreadCritical`: remove TenantContext wrappers for markAllRead and jdbcTemplate.update. Cleanup job should work without any context.
- [ ] T-10: Simplify `NotificationRlsIntegrationTest.cleanupAt89DaysPreservesNotification`: same simplification as T-9.
- [ ] T-11: Simplify `NotificationRlsIntegrationTest.setUp()`: remove RESET ROLE pattern from notification cleanup. Plain `jdbcTemplate.update("DELETE FROM notification WHERE recipient_id IN (?, ?)")` should work.
- [ ] T-12: Verify `ReferralEscalationIntegrationTest` passes with simplified `isNew()` — no raw connection, no RESET ROLE. The escalation dedup test (`escalationIsIdempotent`) should use REST API or direct repository for count verification instead of raw connection.
- [ ] T-13: Run full backend test suite — all green (457+ tests)

### Documentation

- [ ] T-14: Update `docs/schema.dbml` — change notification table RLS comment from "per-user" to "unrestricted, service-layer enforced"
- [ ] T-15: Add Lesson #84 to CLAUDE-CODE-BRIEF.md: "Per-user RLS is wrong for system-accessed tables — use binary or unrestricted policies, enforce per-user at service layer"

### Verification

- [ ] T-16: `mvn compile test-compile` — zero errors
- [ ] T-17: Full backend test suite — all green
- [ ] T-18: `npm run build` — zero errors (frontend unchanged but verify)
- [ ] T-19: Playwright smoke tests through nginx — all green
- [ ] T-20: Deploy to findabed.org:
  - `git pull origin main`
  - `cd backend && mvn clean package -DskipTests -q` (clean removes old JARs)
  - Verify single JAR: `ls backend/target/*.jar` (must show only 0.31.0)
  - `docker build --no-cache -f infra/docker/Dockerfile.backend -t fabt-backend:latest .`
  - Verify class in image: `docker exec fabt-backend unzip -l app.jar | grep ReferralEscalation` (size should be smaller than 12662 bytes — RESET ROLE code removed)
  - `docker compose ... up -d --force-recreate backend`
  - Health check: `curl -sf http://localhost:9091/actuator/health`
  - Verify V38 applied: `SELECT version, description FROM flyway_schema_history WHERE version = '38'`
  - Clean up remaining escalation duplicates in DB
  - `docker image prune -f`
- [ ] T-21: Verify no more duplicate escalation notifications after 10+ minutes (watch `docker logs fabt-backend` for "Referral escalation: created 0 notifications")
- [ ] T-22: Commit, push to main
