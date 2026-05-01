## ADDED Requirements

### Requirement: Payload-driven deep-link URL construction
The system SHALL construct deep-link URLs for notifications using the notification's `payload` JSONB field. The `getNavigationPath(notification, userRoles)` function SHALL accept the full notification object (not just eventType) and return a URL with query params derived from payload (e.g., `referralId`, `shelterId`, `reservationId`).

#### Scenario: Referral notification deep-links with referralId
- **WHEN** a notification with `type=dv-referral.requested` and `payload.referralId=abc-123` is clicked
- **THEN** the user navigates to `/coordinator?referralId=abc-123` (for COORDINATOR role)

#### Scenario: Hold cancellation notification deep-links with reservationId
- **WHEN** a notification with `type=HOLD_CANCELLED_SHELTER_DEACTIVATED` and `payload.reservationId=res-001` is clicked
- **THEN** the user navigates to `/outreach/my-holds?reservationId=res-001`
- **AND** (prerequisite) the backend `ShelterService.cancelHoldsForShelter` includes `reservationId` in the notification payload (see setup tasks 0a.2, 0a.3)

#### Scenario: Shelter deactivation notification deep-links with shelterId
- **WHEN** a notification with `type=SHELTER_DEACTIVATED` and `payload.shelterId=def-456` is clicked
- **THEN** the user navigates to `/coordinator?shelterId=def-456` (for COORDINATOR role)
- **AND** (prerequisite) the backend `ShelterService.doDeactivate` includes `shelterId` in the notification payload (see setup tasks 0a.1, 0a.3)

#### Scenario: Payload missing expected field — graceful fallback
- **WHEN** a notification is clicked and its payload is missing the expected deep-link field (pre-change notifications)
- **THEN** the user navigates to the role-based default destination without error (e.g., `/coordinator`)

### Requirement: Role-aware notification routing
The system SHALL route the same notification type to different destinations based on the user's role. Escalation notifications SHALL route COC_ADMIN and PLATFORM_ADMIN to the admin escalation queue, and COORDINATOR to their dashboard referral view.

#### Scenario: Admin clicking escalation notification
- **WHEN** a COC_ADMIN or PLATFORM_ADMIN clicks a notification with `type=escalation.1h` and `payload.referralId=abc-123`
- **THEN** they navigate to `/admin#dvEscalations?referralId=abc-123`

#### Scenario: Coordinator clicking the same escalation notification
- **WHEN** a COORDINATOR clicks a notification with `type=escalation.1h` and `payload.referralId=abc-123`
- **THEN** they navigate to `/coordinator?referralId=abc-123`

#### Scenario: Role determined from JWT claims
- **WHEN** the notification is clicked
- **THEN** the current user's roles are read from the authenticated session (not from the notification payload)

### Requirement: Coordinator dashboard auto-opens targeted referral
The coordinator dashboard SHALL accept a `referralId` query parameter. When present, the dashboard SHALL auto-expand the shelter containing that referral, scroll to the specific referral row, and move keyboard focus to the primary action button.

#### Scenario: Coordinator lands on dashboard with referralId
- **WHEN** a coordinator navigates to `/coordinator?referralId=abc-123`
- **THEN** the dashboard loads, the shelter containing the pending referral with id `abc-123` is auto-expanded
- **AND** the page scrolls to the referral row
- **AND** keyboard focus moves to the referral row heading (NOT the Accept button — safety: prevents accidental acceptance via Enter key)
- **AND** an `aria-live="polite"` region announces "Opened pending DV referral: {populationType}, household size {N}, urgency {urgency}"

#### Scenario: Unsaved bed count changes protected during deep-link auto-expand
- **GIVEN** a coordinator has expanded shelter A and edited a bed count without saving
- **WHEN** the coordinator clicks a notification for a referral at shelter B
- **THEN** a confirmation dialog appears: "You have unsaved bed count changes. Save before switching to the referral?"
- **AND** the dialog offers Save, Discard, or Cancel
- **AND** on Cancel, the deep-link is not processed; shelter A remains expanded with unsaved edits intact

#### Scenario: Deep-link idempotent under re-render
- **WHEN** a coordinator has landed on `/coordinator?referralId=abc-123` and the deep-link has processed
- **AND** a re-render occurs (e.g., React Router state change, URL back navigation)
- **THEN** the deep-link processing effect does NOT re-run for the same referralId
- **AND** the user's current scroll position and focus are preserved

#### Scenario: Referral no longer exists (stale notification)
- **WHEN** a coordinator navigates to `/coordinator?referralId=abc-123` but no pending referral with that id exists (already accepted by another coordinator, expired, etc.)
- **THEN** the dashboard loads normally (no auto-expand)
- **AND** a non-blocking toast displays: "This referral is no longer pending."
- **AND** the coordinator's notification is marked READ (via `/read` endpoint) but NOT acted — preserves the lifecycle distinction between "I was too late" and "I successfully acted"

#### Scenario: Authorization failure on deep-link target
- **WHEN** a coordinator navigates to `/coordinator?referralId=abc-123` and the backend returns 403 on the referral fetch (the coordinator is not assigned to this shelter, or access was revoked)
- **THEN** the same fallback applies as the stale-notification scenario
- **AND** the toast message is identical ("This referral is no longer pending.") — the system does NOT leak whether the referral exists or the user lacks access

#### Scenario: Coordinator lands on dashboard with shelterId (no referralId)
- **WHEN** a coordinator navigates to `/coordinator?shelterId=def-456` (e.g., from a SHELTER_DEACTIVATED notification)
- **THEN** the dashboard loads and the specified shelter is auto-expanded
- **AND** keyboard focus moves to the shelter card

#### Scenario: Deep-link target fails to materialize within timeout
- **WHEN** a coordinator navigates to `/coordinator?referralId=abc-123` but the target row does not appear in the dashboard within 5 seconds (slow network, infrastructure failure, host's data fetch hangs)
- **THEN** the same fallback as the stale-notification scenario applies — non-blocking toast "This referral is no longer pending." displays
- **AND** the dashboard returns to a usable state (no infinite spinner, no stuck overlay)
- **NOTE** This timeout is owned by the `useDeepLink` hook's `awaiting-target` deadline (D-12). It guarantees that no deep-link can leave the user in a silent stuck state, regardless of which host (coordinator dashboard, admin queue, my-past-holds) consumed the hook.

### Requirement: Backend single-referral lookup endpoint for deep-link resolution
The system SHALL expose `GET /api/v1/dv-referrals/{id}` returning the full `ReferralTokenResponse` (including `shelterId`) for the requested referral. The endpoint SHALL be RLS-tenant-scoped, role-restricted to COORDINATOR / COC_ADMIN / PLATFORM_ADMIN, and SHALL contain zero client PII (matches the `/pending` list shape — household size, population type, urgency, callback number; never address). Both not-found and access-denied SHALL respond with HTTP 404 (NOT 403) so the response never leaks whether the referral exists in another tenant (D10 unified stale shape).

#### Scenario: Coordinator deep-link resolves a referral to its shelter
- **WHEN** the frontend deep-link processor calls `GET /api/v1/dv-referrals/abc-123` for a referral the requesting coordinator has dvAccess to
- **THEN** the response is HTTP 200 with the full `ReferralTokenResponse` including `shelterId`
- **AND** the response contains no shelter address, latitude, or longitude (FVPSA / VAWA)

#### Scenario: Unknown referral id returns 404
- **WHEN** the frontend deep-link processor calls `GET /api/v1/dv-referrals/00000000-0000-0000-0000-000000000000`
- **THEN** the response is HTTP 404 with no body details that would distinguish "doesn't exist" from "RLS-hidden"

#### Scenario: Cross-tenant referral returns 404 (no info leak)
- **WHEN** a coordinator from tenant A calls `GET /api/v1/dv-referrals/{id}` for a referral that exists only in tenant B
- **THEN** RLS hides the row, the service throws `NoSuchElementException`, and the response is HTTP 404 — identical to the unknown-id response. The caller cannot distinguish "exists in another tenant" from "doesn't exist anywhere."

### Requirement: Admin escalation queue auto-opens detail modal
The DvEscalationsTab SHALL accept a `referralId` query parameter. When present, the tab SHALL automatically open the detail modal for that referral upon load.

#### Scenario: Admin lands on escalation queue with referralId
- **WHEN** an admin navigates to `/admin#dvEscalations?referralId=abc-123`
- **THEN** the escalation queue loads, the DV Escalations tab is selected
- **AND** the detail modal for referral `abc-123` opens automatically
- **AND** keyboard focus moves into the modal (existing modal focus trap)

#### Scenario: Referral already claimed by another admin
- **WHEN** the admin opens the detail modal for a referral already claimed by another admin
- **THEN** the modal opens in read-only / claim-override state per existing claim/release flow (no change to that behavior)

### Requirement: CriticalNotificationBanner CTA for coordinators
The CriticalNotificationBanner SHALL display a working CTA for COORDINATOR users when unread CRITICAL notifications include referral-related events. The CTA SHALL deep-link to the first referral requiring attention.

#### Scenario: Coordinator sees CriticalNotificationBanner with CTA
- **WHEN** a coordinator has unread CRITICAL notifications of type `escalation.*` with a `referralId` in payload
- **THEN** the banner displays "View pending referrals →" as a clickable CTA
- **AND** clicking it navigates to `/coordinator?referralId=<first-critical-referral>`

#### Scenario: Admin still sees their queue CTA
- **WHEN** a COC_ADMIN or PLATFORM_ADMIN has unread CRITICAL escalation notifications
- **THEN** they see "Review N pending escalations →" navigating to `/admin#dvEscalations`

#### Scenario: No referral-related critical notifications
- **WHEN** the user's unread CRITICAL notifications are only `surge.activated` or similar (no `referralId`)
- **THEN** the banner shows count text without a CTA button (current behavior preserved)

### Requirement: Missing notification type mappings
The system SHALL provide user-facing message text, icon, and navigation path for notification types that currently fall through to `'notifications.unknown'`: `SHELTER_DEACTIVATED`, `HOLD_CANCELLED_SHELTER_DEACTIVATED`, `referral.reassigned`.

#### Scenario: SHELTER_DEACTIVATED notification has user-facing message with localized reason
- **WHEN** a user views a SHELTER_DEACTIVATED notification in the bell and the payload reason is `TEMPORARY_CLOSURE`
- **THEN** the text reads (en): "Shelter {shelterName} was deactivated. Reason: Temporary closure" — the enum value is resolved via `shelter.reason.TEMPORARY_CLOSURE` i18n key (shipped in v0.38.0), NOT rendered as the raw enum string
- **AND** (es): "Refugio {shelterName} fue desactivado. Motivo: Cierre temporal"
- **AND** the raw enum value `TEMPORARY_CLOSURE` never appears in the user-facing string

#### Scenario: HOLD_CANCELLED_SHELTER_DEACTIVATED notification has user-facing message
- **WHEN** an outreach worker views a HOLD_CANCELLED_SHELTER_DEACTIVATED notification
- **THEN** the text reads (en): "Your bed hold at {shelterName} was cancelled — the shelter was deactivated."
- **AND** (es): "Su reserva de cama en {shelterName} fue cancelada — el refugio fue desactivado."

#### Scenario: referral.reassigned notification has user-facing message
- **WHEN** a coordinator or admin views a referral.reassigned notification
- **THEN** the text reads (en): "DV referral reassigned to you."
- **AND** (es): "Referencia de VD reasignada a usted."
- **AND** the notification deep-links per the payload's `referralId`

### Requirement: Focus management after deep-link navigation
After a deep-link navigation completes, keyboard focus SHALL move to the primary action button on the target item, not to the page heading or a container element.

#### Scenario: Deep-link to coordinator referral moves focus to referral row
- **WHEN** a deep-link navigates to a referral on the coordinator dashboard
- **THEN** after the shelter auto-expands and the referral is scrolled into view, keyboard focus moves to the referral row heading (NOT the Accept button)
- **AND** a visible `:focus-visible` indicator is rendered per WCAG 2.4.7
- **AND** the Accept and Reject buttons are one Tab stop away — the user must make an intentional keypress to activate them (DV safety: prevents accidental Enter-key acceptance)

#### Scenario: Deep-link to admin escalation modal moves focus into modal
- **WHEN** a deep-link opens the escalation detail modal
- **THEN** keyboard focus moves into the modal per existing modal focus-trap behavior
- **AND** the modal's first interactive element (Claim or Accept button) receives focus

#### Scenario: Deep-link to My Past Holds moves focus to highlighted hold
- **WHEN** a deep-link opens `/outreach/my-holds?reservationId=res-001`
- **THEN** the list loads with reservation `res-001` highlighted
- **AND** keyboard focus moves to the highlighted row's primary action (e.g., "Find another bed")

### Requirement: Notification lifecycle — markActed after successful actions
The system SHALL mark notifications as "acted" after the user successfully completes a terminal action related to the notification. The acted state SHALL be distinct from read and from dismissed.

#### Scenario: Acted on referral accept
- **WHEN** a coordinator accepts a DV referral via the API (PATCH /api/v1/dv-referrals/{id}/accept returns 200)
- **THEN** the frontend calls `PATCH /api/v1/notifications/{notificationId}/acted` for every unread notification with `payload.referralId` matching the accepted referral
- **AND** those notifications display with the "acted" visual state

#### Scenario: Acted on hold confirm
- **WHEN** an outreach worker confirms a bed hold successfully
- **THEN** any reservation.expired or HOLD_CANCELLED_* notifications for that reservation are marked acted

#### Scenario: Failed action does not mark acted
- **WHEN** a coordinator attempts to accept a referral but the API returns 409 (already accepted by another coordinator)
- **THEN** NO notification is marked acted
- **AND** the user sees an error message

#### Scenario: Dismiss is not mark-acted
- **WHEN** a user clicks the `×` dismiss button on a notification in the bell
- **THEN** the notification is dismissed (existing behavior)
- **AND** it is NOT marked acted

### Requirement: Bell visual distinction between lifecycle states
The NotificationBell dropdown SHALL display three distinct visual states for notifications: unread, read-but-not-acted, and acted.

#### Scenario: Unread notification visual
- **WHEN** a notification is unread (readAt is null)
- **THEN** the row has `backgroundColor: color.bgHighlight` and `fontWeight: semibold`
- **AND** the notification counts in the bell badge

#### Scenario: Read-but-unacted notification visual
- **WHEN** a notification has been read (readAt not null) but not acted (actedAt is null)
- **THEN** the row has `backgroundColor: color.bg`, `fontWeight: normal`, and a small "pending action" indicator (e.g., dot or "• Pending" text)
- **AND** the notification does NOT count in the bell badge

#### Scenario: Acted notification visual
- **WHEN** a notification has been acted on (actedAt not null)
- **THEN** the row has `backgroundColor: color.bg`, `color: color.textMuted`, and a small ✓ icon
- **AND** the notification does NOT count in the bell badge

#### Scenario: State indicators have accessible tooltips
- **WHEN** a user hovers or focuses the "• Pending" indicator on a read-unacted notification
- **THEN** a tooltip displays: "Pending — you've seen this but haven't responded"
- **WHEN** a user hovers or focuses the ✓ icon on an acted notification
- **THEN** a tooltip displays: "Completed — you've acted on this"

#### Scenario: Screen reader announces lifecycle state
- **WHEN** a screen reader user navigates to a notification in the bell
- **THEN** the row's aria-label includes the state: "Unread", "Pending action", or "Completed"
- **AND** example: "DV referral requested at Safe Haven. Pending action."

### Requirement: Notification deep-link observability metrics
The system SHALL emit Micrometer metrics for every deep-link click so time-to-action improvements can be measured for grant applications and pilot evaluation.

#### Scenario: Deep-link click counter
- **WHEN** a user clicks a notification that deep-links to an item
- **THEN** `fabt.notification.deeplink.click.count` counter is incremented with tags `type` (notification type), `role`, `outcome` (success/stale/offline)

#### Scenario: Time-to-action histogram
- **WHEN** a user successfully acts on an item (referral accept, hold confirm)
- **THEN** `fabt.notification.time_to_action.seconds` histogram records the duration from notification `createdAt` to the successful action, tagged by `type`

#### Scenario: Stale referral counter
- **WHEN** the stale-referral fallback fires (toast shown, notification marked read-unacted)
- **THEN** `fabt.notification.stale_referral.count` counter is incremented with tags `type` and `role`

### Requirement: Offline deep-link handling
The system SHALL handle deep-link navigation gracefully when the user is offline.

#### Scenario: Offline deep-link to My Past Holds
- **WHEN** an outreach worker is offline and clicks a notification deep-linking to `/outreach/my-holds?reservationId=X`
- **THEN** the My Past Holds page attempts to load cached data from the service worker cache
- **AND** if the specific reservation is in cache, it is highlighted
- **AND** if no cache is available, a toast displays: "Can't load your holds — check your connection."
- **AND** the page does NOT show an infinite loading spinner

### Requirement: Auth redirect preserves deep-link
The system SHALL preserve deep-link query parameters through the login redirect flow when the user's session expires.

#### Scenario: Expired JWT during notification click
- **WHEN** a user clicks a notification that deep-links to `/coordinator?referralId=X`
- **AND** the JWT has expired and the user is redirected to `/login`
- **THEN** after successful login, the user is redirected back to `/coordinator?referralId=X` with the deep-link intact
- **AND** the auto-expand and focus behavior runs as if the login redirect had not occurred
