## Tasks

### Legal Language CI Gate

- [x] T-LG-1: Create `infra/scripts/legal-language-scan.sh` — grep for overclaimed keywords (compliant, certified, guarantees, ensures compliance, zero downtime, no way to, equivalent to, 100% uptime, enterprise-ready). Scans .md, .tsx, .ts, .java, .html. Supports `.legal-allowlist` file for known-good matches. Exit 1 on unallowlisted matches.
- [x] T-LG-2: Test locally — run scan against both repos, verify it catches known issues (e.g., archived dv-opaque-referral "no way to identify") and passes on already-fixed files. Build the initial allowlist from legitimate matches. Code repo: 28 total, 21 allowlisted, 7 real issues (known from Casey's audit). Docs repo: 119 total (includes code repo subdirectory), needs scoped allowlist at CI level.
- [x] T-LG-3: Add `legal-language` job to code repo `.github/workflows/ci.yml` — runs on push/PR to main, uses the scan script. Warning annotations on matches.
- [x] T-LG-4: Create `.github/workflows/ci.yml` in docs repo (`findABed`) — minimal workflow with the same legal language scan on push/PR to main.
- [x] T-LG-5: Verify both CI workflows pass on current main before proceeding. Code repo: hard gate (0 flagged). Docs repo: advisory mode (prose discusses legal concepts — warning annotations, does not block).

### Setup

- [x] T-0: Create branch `feature/persistent-notifications` from main

### Backend — Notification Store (Flyway V35)

- [x] T-1: Flyway V35: CREATE TABLE notification. Also update `infra/scripts/seed-reset.sql` — add `DELETE FROM notification` in Layer 1 (leaf tables, before subscription/api_key deletes). (id UUID PK, tenant_id FK, recipient_id FK, type VARCHAR, severity VARCHAR, payload JSONB, read_at TIMESTAMPTZ, acted_at TIMESTAMPTZ, created_at TIMESTAMPTZ, expires_at TIMESTAMPTZ)
- [x] T-2: Flyway V35: CREATE INDEX idx_notification_unread ON notification (recipient_id, created_at DESC) WHERE read_at IS NULL
- [x] T-3: Flyway V35: Enable RLS on notification table. Policy: recipient_id matches current app user. GRANT DML to fabt_app (handled by V16 ALTER DEFAULT PRIVILEGES).
- [x] T-4: Create `Notification` domain entity in notification module
- [x] T-5: Create `NotificationRepository` (Spring Data JDBC) — findUnreadByRecipientId, countUnreadByRecipientId, markRead, markActed, markAllRead, deleteOldRead
- [x] T-6: Create `NotificationPersistenceService.send(recipientId, type, severity, payload)` — writes DB row + pushes to SSE emitter if user connected (Design D5)
- [x] T-7: Verify `npm run build` passes (no frontend changes yet)

### Backend — REST API

- [x] T-8: `GET /api/v1/notifications` — returns unread (or all) notifications for authenticated user, ordered by severity DESC, created_at DESC. Supports `?unread=true` filter.
- [x] T-9: `GET /api/v1/notifications/count` — returns `{"unread": N}` for bell badge
- [x] T-10: `PATCH /api/v1/notifications/{id}/read` — sets read_at. Idempotent (204).
- [x] T-11: `PATCH /api/v1/notifications/{id}/acted` — sets acted_at + read_at. For CRITICAL notifications.
- [x] T-12: `POST /api/v1/notifications/read-all` — marks all unread as read for authenticated user. (204).
- [x] T-13: Add @Operation annotations to all endpoints
- [x] T-14: Add notification REST endpoints to DemoGuard allowlist (read/acted/read-all are safe mutations)
- [x] T-14a: Integration test: demo profile active, PATCH /notifications/{id}/read returns 204 (not 403 demo_restricted)

### Backend — SSE Catch-Up

- [x] T-15: Modify `NotificationService.registerEmitter()` — after sending "connected" event, query unread notifications from DB (limit 50, ordered severity DESC, created_at DESC) and send as SSE events
- [x] T-16: Integration test: connect SSE, verify unread notifications from DB are delivered in catch-up batch
- [x] T-17: Integration test: catch-up delivers CRITICAL before ACTION_REQUIRED before INFO

### Backend — DV Referral Integration

- [x] T-18: When referral is created, call `NotificationPersistenceService.send()` to coordinator with type `referral.requested`, severity `ACTION_REQUIRED`
- [x] T-19: When referral is accepted/rejected, call `NotificationPersistenceService.send()` to outreach worker with type `referral.responded`, severity `ACTION_REQUIRED`
- [x] T-20: Integration test: create referral → verify notification row exists for coordinator
- [x] T-21: Integration test: accept referral → verify notification row exists for outreach worker

### Backend — Surge Activation Notification

- [x] T-SRG-1: When surge is activated, call `NotificationPersistenceService.send()` to ALL coordinators in the CoC with type `surge.activated`, severity `CRITICAL`, payload {surgeEventId, reason}
- [x] T-SRG-2: When surge is deactivated, send INFO notification to all coordinators
- [x] T-SRG-3: Integration test: activate surge → verify CRITICAL notification exists for every coordinator in tenant
- [x] T-SRG-4: i18n: "White Flag activated — open overflow capacity" (en + es)

### Backend — Reservation Expiry Notification

- [x] T-RES-1: When reservation expires (existing `@Scheduled` expiry job), call `NotificationPersistenceService.send()` to the outreach worker who created the hold with type `reservation.expired`, severity `ACTION_REQUIRED`, payload {reservationId, shelterId, shelterName}
- [x] T-RES-2: Integration test: create reservation, let it expire → verify notification exists for the outreach worker
- [x] T-RES-3: i18n: "Your bed hold at {shelter} has expired" (en + es)

### Backend — DV Referral Escalation

- [x] T-22: `@Scheduled` job (every 5 minutes): scan PENDING referrals, create escalation notifications at thresholds. **Payload discipline (Casey/VAWA):** all escalation payloads contain ONLY referralId + threshold label. NEVER household size, population type, callback number, or any client-identifying data.
- [x] T-23: T+1h: ACTION_REQUIRED notification to coordinator ("Referral waiting 1 hour"). Payload: `{"referralId":"<uuid>","threshold":"1h"}`
- [x] T-24: T+2h: CRITICAL notification to CoC admin (escalation). Uses `UserService.findActiveByRole(tenantId, "COC_ADMIN")` — not DV-access-filtered, since CoC admins have system-wide oversight responsibility.
- [x] T-25: T+3.5h: CRITICAL notification to coordinator + outreach worker ("Expires in 30 minutes")
- [x] T-26: T+4h (expiry): ACTION_REQUIRED notification to outreach worker ("Referral expired — find another bed"). Upgraded from INFO: a family may be waiting.
- [x] T-27: Each threshold fires only once per referral (tracking column or notification dedup)
- [x] T-28: Integration test: create referral, advance clock past 1h → verify 1h escalation notification created
- [x] T-29: Integration test: accept referral before 2h → verify no 2h escalation created
- [x] T-30: Integration test: verify escalation is idempotent (run job twice, same notifications)

### Backend — Coordinator Pending Count

- [x] T-31: `GET /api/v1/dv-referrals/pending/count` — returns total PENDING count across all coordinator's assigned DV shelters. Requires COORDINATOR+ role + dvAccess.
- [x] T-32: Integration test: create 2 referrals to different shelters → count returns 2

### Backend — Cleanup

- [x] T-33: `@Scheduled` daily: DELETE FROM notification WHERE read_at IS NOT NULL AND created_at < NOW() - INTERVAL '90 days'. Never delete unread CRITICAL.
- [x] T-34: Integration test: old read notification deleted, old unread CRITICAL preserved

### Backend — Tests

- [x] T-35: ArchUnit: notification module boundary verified
- [x] T-36: Run full backend test suite — all green

### Frontend — Bell Badge from DB

- [x] T-37: `useNotifications` hook: on mount, call `GET /api/v1/notifications/count` to initialize badge count. REST count is the source of truth; SSE catch-up does NOT override it. Reconciliation: REST sets the baseline, SSE increments/decrements from there.
- [x] T-37a: Handle the new `"notification"` SSE event type in `useNotifications`. The backend's `pushNotification()` sends persistent notifications as `event: notification` with data `{notificationId, type, severity, payload, createdAt}`. The hook must process these alongside existing domain events (`dv-referral.responded`, etc.). Increment unread count on arrival; add to notification list for bell dropdown.
- [x] T-38: SSE events increment/decrement count in real-time after initial REST value. Race handling: if SSE catch-up arrives before REST response, buffer SSE events and reconcile after REST baseline is set.
- [x] T-39: Deduplicate by notification ID — catch-up notifications that were already shown via SSE are no-ops
- [x] T-40: Bell dropdown: fetch `GET /api/v1/notifications?unread=true` on open (lazy load)
- [x] T-41: Mark as read: `PATCH /api/v1/notifications/{id}/read` on notification click. Add navigation routing for new notification types: `referral.responded` → `/outreach`, `reservation.expired` → `/outreach`, `escalation.*` → `/coordinator` (or `/` for CoC admins), `surge.activated`/`surge.deactivated` → `/coordinator`.
- [x] T-42: "Mark all as read" button: `POST /api/v1/notifications/read-all`. Excludes CRITICAL severity (Design D3 — CRITICAL cannot be dismissed without acting). Frontend label uses `notifications.markAllRead` i18n key.

### Frontend — Coordinator Referral Banner

- [x] T-43: New `CoordinatorReferralBanner` component: fetches pending count on mount, shows persistent red banner if > 0
- [x] T-44: Banner text: "{N} referral(s) waiting for review" — i18n (en + es)
- [x] T-45: Banner is NOT dismissable — resolves when referrals are actioned
- [x] T-46: Clicking banner scrolls to / expands first DV shelter with pending referrals. After acting on all referrals at that shelter, banner re-targets the next DV shelter with pending referrals (or disappears if none remain).
- [x] T-47: Pending referral badge on COLLAPSED shelter cards (not just expanded). Badge includes urgency indicator: red dot for EMERGENCY, amber for URGENT, so coordinators expand the most critical shelter first.
- [x] T-48: SSE events update banner count in real-time
- [x] T-49: WCAG: role="alert", color tokens for dark mode, min 44px touch target

### Frontend — CRITICAL Notification Lifecycle

- [ ] T-49a: When coordinator accepts or rejects a referral (existing accept/reject buttons in referral screening UI), call `PATCH /api/v1/notifications/{id}/acted` for the related CRITICAL notification (escalation.3_5h, escalation.2h, or referral.requested if CRITICAL). Lookup: match by referralId in notification payload. This is the ONLY way to dismiss a CRITICAL banner (Design D3). NOTE: Deferred until T-50 (CRITICAL banner) is built — requires notification ID lookup by referralId.
- [x] T-49b: When all pending referrals for a shelter are actioned, banner auto-refreshes. Implementation: banner listens to SSE_REFERRAL_UPDATE events → re-fetches pending count → disappears when count reaches 0.

### Frontend — Severity-Based Notification UI

- [x] T-50: CRITICAL notifications: persistent red banner at top of page on login if unread. NOT a modal — banner stays visible until acted on but does not block page interaction (coordinators need to navigate to the referral to act on it). Uses role="alert" for screen reader announcement.
- [x] T-51: ACTION_REQUIRED notifications: toast on arrival + bell badge
- [x] T-52: INFO notifications: bell badge increment only
- [x] T-53: i18n: all notification text in en.json + es.json

### Frontend — Tests

- [x] T-54: Playwright: coordinator logs in → pending referral banner visible with count
- [x] T-55: Playwright: outreach worker submits referral, logs out, coordinator accepts, worker logs back in → My Referrals shows ACCEPTED status
- [x] T-56: Playwright: bell badge shows unread count on login (not zero)
- [x] T-57: Playwright: mark notification as read → badge count decrements
- [x] T-58: Playwright: WCAG — banner has role="alert", keyboard accessible
- [x] T-58b: Playwright: coordinator sees CRITICAL banner → accepts referral → CRITICAL banner disappears. This is the most safety-critical E2E flow — the exact scenario this feature exists to prevent.
- [x] T-58c: Playwright: "Mark all as read" → badge shows only CRITICAL count (Design D3 enforcement at UI level)
- [x] T-58d: Playwright: non-DV outreach worker bell has no referral.requested notifications (negative/security — DV isolation)
- [x] T-58e: Playwright: notification dropdown renders correct message text for at least one type (rendering spot-check)

### Documentation

- [x] T-58a: Flyway V36: `CREATE INDEX idx_notification_payload_referral_id ON notification ((payload ->> 'referralId'))` — functional index for escalation dedup query at NYC scale. Without this, the `payload ->> 'referralId' = ?` check does a sequential scan on the entire notification table.
- [x] T-59: Update docs/schema.dbml — notification table
- [x] T-60: Update docs/asyncapi.yaml — notification.created event channel
- [x] T-61: Update docs/FOR-DEVELOPERS.md — notification REST API reference
- [x] T-62: Update docs/erd.svg — regenerate from DBML
- [x] T-63: Seed data: demo notifications for screenshots (pending referral for coordinator, accepted for outreach worker). Note: seed INSERT must use `set_config('app.current_user_id', recipientId, true)` before each INSERT to satisfy the RETURNING clause's SELECT RLS policy (Lesson #79).

### Verification

- [x] T-64: npm run build — zero errors
- [x] T-65: ESLint clean
- [x] T-66: Full backend test suite — all green (457/457)
- [x] T-67: Full Playwright suite through nginx — all green (8/8 persistent-notifications)
- [x] T-68: Merge to main, tag v0.31.0, release, deploy to findabed.org, 8/8 smoke tests green

### Post-Deploy Communications (after successful deploy + sanity checks)

- [ ] T-COM-1: DEFERRED (5 days post-deploy) — GitHub Discussion post. See #89.
- [ ] T-COM-2: DEFERRED (5 days post-deploy) — Homepage feature list update. See #89.
- [ ] T-COM-3: Update findabed.org changelog page — version entry with summary of notification framework, surge alerts, reservation expiry notifications. Link to GitHub release.
