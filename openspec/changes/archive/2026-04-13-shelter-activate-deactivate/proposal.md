## Why

V52 added `shelter.active BOOLEAN NOT NULL DEFAULT TRUE` and bed search filters inactive shelters at the SQL level (`AND s.active = TRUE`). But there is no admin UI to toggle this flag. Admins cannot deactivate a shelter that closes — temporarily (code violation, weather damage) or permanently (funding loss, organizational failure). Without this, the only recourse is a direct database UPDATE, which defeats the purpose of the admin panel.

This also blocks the seasonal shelter lifecycle (Rev. Monroe's White Flag nights) where shelters activate and deactivate on a weather-triggered schedule. And it creates a gap for DV shelters: deactivating a DV shelter has safety implications (active referrals, address confidentiality) that require a gated workflow, not a raw SQL toggle.

Issue #108.

## What Changes

- **Admin shelter list**: add an active/inactive status badge per shelter row, with a toggle action (button or switch) for COC_ADMIN and PLATFORM_ADMIN.
- **Deactivation confirmation dialog**: standard shelters get a simple confirmation. DV shelters get an enhanced confirmation with a safety warning (mirrors the existing DV toggle confirmation pattern from shelter-edit).
- **Cascade on deactivation**: active bed holds are expired with status `CANCELLED_SHELTER_DEACTIVATED` and outreach workers are notified. Active DV referrals surface a warning — admin must acknowledge before proceeding.
- **Deactivation metadata**: record `deactivated_at`, `deactivated_by`, and `deactivation_reason` (enum: TEMPORARY_CLOSURE, SEASONAL_END, PERMANENT_CLOSURE, CODE_VIOLATION, FUNDING_LOSS, OTHER) for audit trail and seasonal reactivation support.
- **Reactivation**: toggle back to active. If `deactivation_reason` was SEASONAL_END, clear the metadata. Reactivation is immediate — shelter reappears in bed search.
- **Coordinator dashboard**: inactive shelters show as grayed with "Inactive" badge. Bed update controls disabled with explanatory text.
- **Audit trail**: SHELTER_DEACTIVATED and SHELTER_REACTIVATED audit events with reason, actor, and affected hold/referral counts.
- **Flyway migration**: add `deactivated_at TIMESTAMPTZ`, `deactivated_by UUID`, `deactivation_reason VARCHAR(50)` to shelter table.

## Capabilities

### New Capabilities

- `shelter-lifecycle`: Shelter activation/deactivation workflow including cascade behavior, DV safety gate, deactivation metadata, coordinator visibility, and audit events.

### Modified Capabilities

- `shelter-management`: Add deactivation metadata columns and reactivation behavior to the shelter data model.
- `bed-reservation`: Add `CANCELLED_SHELTER_DEACTIVATED` hold expiry path with outreach worker notification.
- `demo-guard`: Shelter deactivation should be blocked in demo mode (destructive mutation with cross-visitor impact).

## Impact

- **Backend**: ShelterService (deactivate/reactivate methods), ShelterController (new endpoints or PATCH), ReservationService (cascade expiry), NotificationService (outreach worker notification), AuditEventService (new event types).
- **Frontend**: Admin shelter list (status badge + toggle), deactivation confirmation dialog (standard + DV variant), coordinator dashboard (inactive state rendering).
- **Database**: V53 migration adding 3 columns to shelter table. New audit event types.
- **API**: `PATCH /api/v1/shelters/{id}/deactivate` and `PATCH /api/v1/shelters/{id}/reactivate` (or single `PATCH /api/v1/shelters/{id}/status`).
- **Existing behavior**: bed search already filters `active = TRUE` (no change needed). DV referral safety check already loads inactive shelters for `SHELTER_CLOSED` flagging (v0.36.0).
