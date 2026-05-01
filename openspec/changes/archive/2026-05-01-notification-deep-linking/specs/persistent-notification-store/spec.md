## ADDED Requirements

### Requirement: Notification lifecycle visual distinction
The notification bell SHALL display three visual states per notification: unread, read-but-unacted, and acted. Only unread notifications SHALL count toward the bell badge.

#### Scenario: Bell badge counts unread only
- **WHEN** a user has 3 unread, 5 read-but-unacted, and 2 acted notifications
- **THEN** the bell badge shows "3"

#### Scenario: Acted notifications remain visible in list
- **WHEN** a user opens the bell dropdown
- **THEN** all notifications are visible ordered by createdAt DESC
- **AND** each is rendered in its visual state (unread/read-unacted/acted)

#### Scenario: Filter to hide acted notifications
- **WHEN** the user clicks the "Hide acted" filter toggle in the bell header
- **THEN** only unread and read-but-unacted notifications are shown
- **AND** the filter preference persists across sessions (localStorage)

#### Scenario: Hide-acted filter default is OFF for first-time users
- **WHEN** a user opens the bell for the first time (no `fabt_notif_hide_acted` localStorage key)
- **THEN** the filter is OFF by default — all notifications are visible including acted ones
- **AND** first-time volunteers see the full lifecycle (unread → pending → acted) to learn the system before opting in to filtering

### Requirement: markActed wired from frontend
The frontend SHALL call `PATCH /api/v1/notifications/{id}/acted` after a user successfully completes the terminal action related to the notification. Failed actions SHALL NOT mark notifications acted.

> **Note:** This requirement describes the store-side behavior (persistence and visual states). The notification-deep-linking spec describes the action-flow wiring (which action triggers markActed). The two specs are complementary — implementation satisfies both.

#### Scenario: Referral accept marks related notifications acted
- **WHEN** a coordinator successfully accepts DV referral `abc-123`
- **THEN** all of that coordinator's unread and read-unacted notifications with `payload.referralId = "abc-123"` are marked acted via API call
- **AND** the bell updates to show the acted visual state

#### Scenario: Bulk mark-acted by payload field
- **WHEN** multiple notifications reference the same operational entity (e.g., a referral and its escalation)
- **THEN** a single user action (accept the referral) marks all of them acted together
