## 0. Setup

- [x] 0.1 Switch to the code repo (`finding-a-bed-tonight`), checkout `main`, pull latest, then create and switch to branch `feature/issue-108-shelter-activate-deactivate` from `main`.

## 1. Database — Migration V53

- [x] 1.1 Create Flyway migration `V53__shelter_deactivation_metadata.sql`: add `deactivated_at TIMESTAMPTZ`, `deactivated_by UUID REFERENCES app_user(id)`, `deactivation_reason VARCHAR(50)` to shelter table. All nullable (active shelters have null values).
- [x] 1.2 Verify migration runs cleanly against Testcontainers and local dev stack.

## 2. Backend — Domain & Enum

- [x] 2.1 Add `DeactivationReason` enum to the shelter module: `TEMPORARY_CLOSURE`, `SEASONAL_END`, `PERMANENT_CLOSURE`, `CODE_VIOLATION`, `FUNDING_LOSS`, `OTHER`. Add `CANCELLED_SHELTER_DEACTIVATED` to `ReservationStatus` enum. Grep for exhaustive status checks (switch without default, if-else chains on ReservationStatus) and update — specifically `ReservationRepository.updateStatus()` switch must map the new status to `cancelled_at` timestamp column.
- [x] 2.2 Add `deactivatedAt`, `deactivatedBy`, `deactivationReason` fields to the `Shelter` domain class. Ensure Spring Data JDBC mapping handles the new columns.

## 3. Backend — Service Layer

- [x] 3.1 Add `ShelterService.deactivate(UUID shelterId, DeactivationReason reason, boolean confirmDv)` method. Sets `active=false`, populates deactivation metadata, publishes SHELTER_DEACTIVATED audit event. Wrap in `TenantContext.callWithContext` with `dvAccess=true` (deactivation may target DV shelters).
- [x] 3.2 Implement hold cascade in `deactivate()`: add `ReservationRepository.findHeldByShelterId(UUID shelterId)` (all HELD reservations across all population types — the existing `findActiveByShelterId` requires a population type). Transition each to `CANCELLED_SHELTER_DEACTIVATED`, decrement `beds_on_hold` per reservation, create persistent notification for each affected outreach worker.
- [x] 3.3 Implement DV safety gate in `deactivate()`: if shelter is DV and has PENDING referrals and `confirmDv=false`, return a confirmation-required response with pending referral count. If `confirmDv=true`, proceed.
- [x] 3.4 Add `ShelterService.reactivate(UUID shelterId)` method. Sets `active=true`, clears deactivation metadata, publishes SHELTER_REACTIVATED audit event.
- [x] 3.5 Add guard in `ShelterService.updateAvailability()`: reject availability updates for inactive shelters with 409. (Implemented in AvailabilityController)
- [x] 3.6 Add guard in `ReservationService.createReservation()`: reject hold creation for inactive shelters with 409.

## 4. Backend — Controller

- [x] 4.1 Add `PATCH /api/v1/shelters/{id}/deactivate` endpoint. Accepts `{"reason": "TEMPORARY_CLOSURE", "confirmDv": false}`. Requires COC_ADMIN or PLATFORM_ADMIN. Returns 200 on success, 409 if already inactive or if DV confirmation required, 400 for invalid reason.
- [x] 4.2 Add `PATCH /api/v1/shelters/{id}/reactivate` endpoint. No body required. Requires COC_ADMIN or PLATFORM_ADMIN. Returns 200 on success, 409 if already active.
- [x] 4.3 Update shelter list/detail response DTOs to include `active`, `deactivatedAt`, `deactivatedBy`, `deactivationReason` fields.

## 5. Backend — DemoGuard

- [x] 5.1 Add `/api/v1/shelters/*/deactivate` and `/api/v1/shelters/*/reactivate` block messages to `DemoGuardFilter.getBlockMessage()`. Messages: "Shelter deactivation is disabled in the demo environment — would affect other visitors' bed search results." and "Shelter reactivation is disabled in the demo environment."

## 6. Backend — Notification

- [x] 6.1 Add `HOLD_CANCELLED_SHELTER_DEACTIVATED` notification type. Message template: "Your bed hold at {shelter name} was cancelled because the shelter was deactivated." (Implemented in ShelterService.cancelHoldsForShelter())
- [x] 6.2 For DV shelter deactivation *event broadcast* (admin-facing "shelter was deactivated"), restrict recipients to users with `dvAccess=true`. Notification text must NOT include shelter address. Note: per-worker "your hold was cancelled" notifications (task 3.2) always go to the hold creator regardless of dvAccess — those are operational, not DV events.

## 7. Backend — Tests

- [x] 7.1 Integration test: deactivate shelter with no holds → active=false, metadata populated, audit event created, shelter excluded from bed search.
- [x] 7.2 Integration test: deactivate shelter with active holds → holds cancelled with `CANCELLED_SHELTER_DEACTIVATED`, outreach workers notified, beds_on_hold decremented.
- [x] 7.3 Integration test: DV shelter deactivation without confirm → 409 with pendingDvReferrals count. With confirm → success.
- [x] 7.4 Integration test: DV shelter deactivation notification restricted to dvAccess=true users, no address in text.
- [x] 7.5 Integration test: reactivate shelter → active=true, metadata cleared, audit event, shelter reappears in bed search.
- [x] 7.6 Integration test: deactivate already-inactive → 409. Reactivate already-active → 409.
- [x] 7.7 Integration test: availability update on inactive shelter → 409. Hold creation on inactive shelter → 409.
- [x] 7.8 Integration test: non-admin (COORDINATOR, OUTREACH_WORKER) cannot deactivate → 403.

## 8. Frontend — Admin Shelter List

- [x] 8.1 Add active/inactive status badge to each shelter row in the admin shelter table. Active = green badge, Inactive = muted badge with reduced row opacity.
- [x] 8.2 Add deactivate/reactivate action button per row. Deactivate shows for active shelters, Reactivate shows for inactive shelters. Include `aria-label` on toggle button: "Deactivate {shelter name}" / "Reactivate {shelter name}".
- [x] 8.3 Deactivation confirmation dialog: reason selector dropdown (6 options), confirm/cancel buttons. For DV shelters, add safety warning text and pending referral count (fetched from the 409 response).
- [x] 8.4 Reactivation confirmation dialog: simple confirmation with message about coordinator needing to update availability.
- [x] 8.5 i18n: add all new strings (badges, dialogs, reasons, notifications) to `en.json` and `es.json`.
- [x] 8.6 Use `data-testid` attributes on all new elements: `shelter-status-badge-{id}`, `shelter-deactivate-btn-{id}`, `shelter-reactivate-btn-{id}`, `deactivation-reason-select`, `deactivation-confirm-btn`, `dv-deactivation-warning`.

## 9. Frontend — Coordinator Dashboard

- [x] 9.1 If an assigned shelter is inactive, render with opacity 0.6, "Inactive" badge, and disabled bed update controls.
- [x] 9.2 Show tooltip/message: "This shelter was deactivated on {date}. Contact your CoC admin to reactivate."
- [x] 9.3 Use `aria-disabled="true"` on disabled controls (not HTML `disabled`) so screen readers can discover them.

## 10. Playwright — E2E Tests

- [x] 10.1 Test: admin deactivates a shelter → status badge changes to "Inactive", shelter disappears from outreach search.
- [x] 10.2 Test: admin reactivates a shelter → status badge changes to "Active", shelter reappears in outreach search.
- [x] 10.3 Test: DV shelter deactivation shows safety warning dialog with pending referral count.
- [x] 10.4 Test: coordinator sees inactive shelter with disabled controls and explanatory message.
- [x] 10.5 Test: demo guard blocks deactivation for public users (run against demo profile).

## 11. Verification

- [x] 11.1 Run full backend test suite (`mvn clean test`). Tee to `logs/issue-108-regression.log`. 618/618 green.
- [x] 11.2 Run Playwright tests through nginx (`BASE_URL=http://localhost:8081`). Tee to `logs/issue-108-playwright.log`. 5/5 green.
- [x] 11.3 `npm run build` — frontend builds clean.
- [x] 11.4 Update DBML with new shelter columns. Regenerate ERD if applicable.
- [x] 11.5 Update OpenAPI docs if Springdoc doesn't auto-generate the new endpoints. Springdoc auto-generates from @Operation annotations.
- [x] 11.6 Open follow-up GitHub issue: "Seasonal shelter auto-reactivation — planned_reactivation_date + scheduler" for Rev. Monroe's White Flag lifecycle. → #112
