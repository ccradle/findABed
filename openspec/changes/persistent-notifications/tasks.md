## Tasks

### Legal Language CI Gate

- [x] T-LG-1: Create `infra/scripts/legal-language-scan.sh` — grep for overclaimed keywords (compliant, certified, guarantees, ensures compliance, zero downtime, no way to, equivalent to, 100% uptime, enterprise-ready). Scans .md, .tsx, .ts, .java, .html. Supports `.legal-allowlist` file for known-good matches. Exit 1 on unallowlisted matches.
- [x] T-LG-2: Test locally — run scan against both repos, verify it catches known issues (e.g., archived dv-opaque-referral "no way to identify") and passes on already-fixed files. Build the initial allowlist from legitimate matches. Code repo: 28 total, 21 allowlisted, 7 real issues (known from Casey's audit). Docs repo: 119 total (includes code repo subdirectory), needs scoped allowlist at CI level.
- [x] T-LG-3: Add `legal-language` job to code repo `.github/workflows/ci.yml` — runs on push/PR to main, uses the scan script. Warning annotations on matches.
- [x] T-LG-4: Create `.github/workflows/ci.yml` in docs repo (`findABed`) — minimal workflow with the same legal language scan on push/PR to main.
- [ ] T-LG-5: Verify both CI workflows pass on current main before proceeding.

### Setup

- [ ] T-0: Create branch `feature/persistent-notifications` from main

### Backend — Notification Store (Flyway V35)

- [ ] T-1: Flyway V35: CREATE TABLE notification. Also update `infra/scripts/seed-reset.sql` — add `DELETE FROM notification` in Layer 1 (leaf tables, before subscription/api_key deletes). (id UUID PK, tenant_id FK, recipient_id FK, type VARCHAR, severity VARCHAR, payload JSONB, read_at TIMESTAMPTZ, acted_at TIMESTAMPTZ, created_at TIMESTAMPTZ, expires_at TIMESTAMPTZ)
- [ ] T-2: Flyway V35: CREATE INDEX idx_notification_unread ON notification (recipient_id, created_at DESC) WHERE read_at IS NULL
- [ ] T-3: Flyway V35: Enable RLS on notification table. Policy: recipient_id matches current app user. GRANT DML to fabt_app.
- [ ] T-4: Create `Notification` domain entity in notification module
- [ ] T-5: Create `NotificationRepository` (Spring Data JDBC) — findUnreadByRecipientId, countUnreadByRecipientId, markRead, markActed, markAllRead, deleteOldRead
- [ ] T-6: Create `NotificationPersistenceService.send(recipientId, type, severity, payload)` — writes DB row + pushes to SSE emitter if user connected (Design D5)
- [ ] T-7: Verify `npm run build` passes (no frontend changes yet)

### Backend — REST API

- [ ] T-8: `GET /api/v1/notifications` — returns unread (or all) notifications for authenticated user, ordered by severity DESC, created_at DESC. Supports `?unread=true` filter.
- [ ] T-9: `GET /api/v1/notifications/count` — returns `{"unread": N}` for bell badge
- [ ] T-10: `PATCH /api/v1/notifications/{id}/read` — sets read_at. Idempotent (204).
- [ ] T-11: `PATCH /api/v1/notifications/{id}/acted` — sets acted_at + read_at. For CRITICAL notifications.
- [ ] T-12: `POST /api/v1/notifications/read-all` — marks all unread as read for authenticated user. (204).
- [ ] T-13: Add @Operation annotations to all endpoints
- [ ] T-14: Add notification REST endpoints to DemoGuard allowlist (read/acted/read-all are safe mutations)
- [ ] T-14a: Integration test: demo profile active, PATCH /notifications/{id}/read returns 204 (not 403 demo_restricted)

### Backend — SSE Catch-Up

- [ ] T-15: Modify `NotificationService.registerEmitter()` — after sending "connected" event, query unread notifications from DB (limit 50, ordered severity DESC, created_at DESC) and send as SSE events
- [ ] T-16: Integration test: connect SSE, verify unread notifications from DB are delivered in catch-up batch
- [ ] T-17: Integration test: catch-up delivers CRITICAL before ACTION_REQUIRED before INFO

### Backend — DV Referral Integration

- [ ] T-18: When referral is created, call `NotificationPersistenceService.send()` to coordinator with type `referral.requested`, severity `ACTION_REQUIRED`
- [ ] T-19: When referral is accepted/rejected, call `NotificationPersistenceService.send()` to outreach worker with type `referral.responded`, severity `ACTION_REQUIRED`
- [ ] T-20: Integration test: create referral → verify notification row exists for coordinator
- [ ] T-21: Integration test: accept referral → verify notification row exists for outreach worker

### Backend — Surge Activation Notification

- [ ] T-SRG-1: When surge is activated, call `NotificationPersistenceService.send()` to ALL coordinators in the CoC with type `surge.activated`, severity `CRITICAL`, payload {surgeEventId, reason}
- [ ] T-SRG-2: When surge is deactivated, send INFO notification to all coordinators
- [ ] T-SRG-3: Integration test: activate surge → verify CRITICAL notification exists for every coordinator in tenant
- [ ] T-SRG-4: i18n: "White Flag activated — open overflow capacity" (en + es)

### Backend — Reservation Expiry Notification

- [ ] T-RES-1: When reservation expires (existing `@Scheduled` expiry job), call `NotificationPersistenceService.send()` to the outreach worker who created the hold with type `reservation.expired`, severity `ACTION_REQUIRED`, payload {reservationId, shelterId, shelterName}
- [ ] T-RES-2: Integration test: create reservation, let it expire → verify notification exists for the outreach worker
- [ ] T-RES-3: i18n: "Your bed hold at {shelter} has expired" (en + es)

### Backend — DV Referral Escalation

- [ ] T-22: `@Scheduled` job (every 5 minutes): scan PENDING referrals, create escalation notifications at thresholds
- [ ] T-23: T+1h: ACTION_REQUIRED notification to coordinator ("Referral waiting 1 hour")
- [ ] T-24: T+2h: CRITICAL notification to CoC admin (escalation)
- [ ] T-25: T+3.5h: CRITICAL notification to coordinator + outreach worker ("Expires in 30 minutes")
- [ ] T-26: T+4h (expiry): ACTION_REQUIRED notification to outreach worker ("Referral expired — find another bed"). Upgraded from INFO: a family may be waiting.
- [ ] T-27: Each threshold fires only once per referral (tracking column or notification dedup)
- [ ] T-28: Integration test: create referral, advance clock past 1h → verify 1h escalation notification created
- [ ] T-29: Integration test: accept referral before 2h → verify no 2h escalation created
- [ ] T-30: Integration test: verify escalation is idempotent (run job twice, same notifications)

### Backend — Coordinator Pending Count

- [ ] T-31: `GET /api/v1/dv-referrals/pending/count` — returns total PENDING count across all coordinator's assigned DV shelters. Requires COORDINATOR+ role + dvAccess.
- [ ] T-32: Integration test: create 2 referrals to different shelters → count returns 2

### Backend — Cleanup

- [ ] T-33: `@Scheduled` daily: DELETE FROM notification WHERE read_at IS NOT NULL AND created_at < NOW() - INTERVAL '90 days'. Never delete unread CRITICAL.
- [ ] T-34: Integration test: old read notification deleted, old unread CRITICAL preserved

### Backend — Tests

- [ ] T-35: ArchUnit: notification module boundary verified
- [ ] T-36: Run full backend test suite — all green

### Frontend — Bell Badge from DB

- [ ] T-37: `useNotifications` hook: on mount, call `GET /api/v1/notifications/count` to initialize badge count
- [ ] T-38: SSE events increment/decrement count in real-time after initial REST value
- [ ] T-39: Deduplicate by notification ID — catch-up notifications that were already shown via SSE are no-ops
- [ ] T-40: Bell dropdown: fetch `GET /api/v1/notifications?unread=true` on open (lazy load)
- [ ] T-41: Mark as read: `PATCH /api/v1/notifications/{id}/read` on notification click
- [ ] T-42: "Mark all as read" button: `POST /api/v1/notifications/read-all`

### Frontend — Coordinator Referral Banner

- [ ] T-43: New `CoordinatorReferralBanner` component: fetches pending count on mount, shows persistent red banner if > 0
- [ ] T-44: Banner text: "{N} referral(s) waiting for review" — i18n (en + es)
- [ ] T-45: Banner is NOT dismissable — resolves when referrals are actioned
- [ ] T-46: Clicking banner scrolls to / expands first DV shelter with pending referrals
- [ ] T-47: Pending referral badge on COLLAPSED shelter cards (not just expanded)
- [ ] T-48: SSE events update banner count in real-time
- [ ] T-49: WCAG: role="alert", color tokens for dark mode, min 44px touch target

### Frontend — Severity-Based Notification UI

- [ ] T-50: CRITICAL notifications: persistent red banner at top of page on login if unread. NOT a modal — banner stays visible until acted on but does not block page interaction (coordinators need to navigate to the referral to act on it). Uses role="alert" for screen reader announcement.
- [ ] T-51: ACTION_REQUIRED notifications: toast on arrival + bell badge
- [ ] T-52: INFO notifications: bell badge increment only
- [ ] T-53: i18n: all notification text in en.json + es.json

### Frontend — Tests

- [ ] T-54: Playwright: coordinator logs in → pending referral banner visible with count
- [ ] T-55: Playwright: outreach worker submits referral, logs out, coordinator accepts, worker logs back in → My Referrals shows ACCEPTED status
- [ ] T-56: Playwright: bell badge shows unread count on login (not zero)
- [ ] T-57: Playwright: mark notification as read → badge count decrements
- [ ] T-58: Playwright: WCAG — banner has role="alert", keyboard accessible

### Documentation

- [ ] T-59: Update docs/schema.dbml — notification table
- [ ] T-60: Update docs/asyncapi.yaml — notification.created event channel
- [ ] T-61: Update docs/FOR-DEVELOPERS.md — notification REST API reference
- [ ] T-62: Update docs/erd.svg — regenerate from DBML
- [ ] T-63: Seed data: demo notifications for screenshots (pending referral for coordinator, accepted for outreach worker)

### Verification

- [ ] T-64: npm run build — zero errors
- [ ] T-65: ESLint clean
- [ ] T-66: Full backend test suite — all green
- [ ] T-67: Full Playwright suite through nginx — all green
- [ ] T-68: Merge to main, tag, release, deploy

### Post-Deploy Communications (after successful deploy + sanity checks)

- [ ] T-COM-1: GitHub Discussion post — "Design: Persistent Notifications for Time-Sensitive Referrals." Frame as design decision, not feature announcement. Use "designed to" language, "time-sensitive" not "safety-critical." Link to spec. Do NOT detail DV-specific flow — keep at feature level. Include: problem statement, approach (PostgreSQL + SSE catch-up, no new services), escalation concept, links to #77 and #78 (roadmap for extended notification types).
- [ ] T-COM-2: Update findabed.org homepage feature list — add "Persistent notifications with escalation for time-sensitive referrals" to capabilities section. Use person-centered framing: "Coordinators see pending referrals the moment they log in — even if requests arrived while they were away."
- [ ] T-COM-3: Update findabed.org changelog page — version entry with summary of notification framework, surge alerts, reservation expiry notifications. Link to GitHub release.
