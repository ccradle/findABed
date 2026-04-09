## Context

The `coordinator_assignment` table exists (many-to-many between `app_user` and `shelter`). The REST API for assignments exists shelter-side (`POST/DELETE /api/v1/shelters/{id}/coordinators`). The admin panel has a user edit drawer (`UserEditDrawer.tsx`, 400px right-side) and a shelter edit full-page form (`ShelterForm.tsx`, 680px centered). Neither shows assignment information.

Industry pattern (Salesforce, JIRA, Clarity HMIS): edit from the resource side, view from the user side.

## Goals / Non-Goals

**Goals:**
- Add "Assigned Coordinators" combobox+chips to shelter edit page (primary editing surface)
- Add "Assigned Shelters" read-only chips to user edit drawer (secondary view)
- New API: `GET /api/v1/users/{id}/shelters` for user-side view
- WCAG 2.1 AA compliant (combobox pattern, keyboard navigation, screen reader)
- Works in both light and dark mode via existing color tokens

**Non-Goals:**
- Bi-directional editing (edit assignments from user side) — too complex, dual edit surfaces cause sync confusion
- Bulk assignment (assign coordinator to 10 shelters at once) — defer until needed
- Audit trail for assignment changes — create GitHub issue, implement separately
- Role-based filtering (only show COORDINATOR role users in the combobox) — implement, but not a separate spec

## Design Decisions

### D1: Shelter-Side Primary, User-Side Read-Only

Edit assignments from the shelter edit page. Show assignments as read-only on the user edit drawer. This matches Salesforce Account Teams, JIRA Project Roles, and Clarity HMIS patterns. Avoids dual edit surfaces and the "which save button governs?" confusion.

### D2: Combobox + Chips (Not Checkboxes or Dual Listbox)

For 1-50 coordinators per tenant, a searchable combobox with removable chips is the optimal pattern (per Smashing Magazine, Adrian Roselli). Checkboxes don't scale past 5 options. Dual listbox is overkill. Native `<select multiple>` has 20+ years of poor usability research.

The combobox follows the W3C APG Combobox Pattern:
- `role="combobox"` with `aria-haspopup="listbox"`
- `aria-activedescendant` for keyboard navigation
- Removable chips with `aria-label="Remove {name}"`
- Min 44px touch targets on chips and remove buttons

### D3: Filter Combobox to Eligible Users

Only show users with COORDINATOR role (or COC_ADMIN/PLATFORM_ADMIN) in the combobox dropdown. For DV shelters, additionally indicate which users have `dvAccess=true` — critical for DV referral notifications.

### D4: Persist on Shelter Save (Not Immediate)

Assignment changes are staged in the UI (add/remove chips) and persisted when the user clicks "Save" on the shelter form. This matches the existing shelter edit pattern where all changes are batched. The save handler diffs the current assignments against the staged list and calls `POST`/`DELETE` for each change.

### D5: User-Side Read-Only View

The user edit drawer shows "Assigned Shelters" as a list of shelter name chips. Each chip links to the shelter edit page (`/coordinator/shelters/{id}/edit?from=/admin`). No remove buttons — editing happens shelter-side.

### D6: No New Database Schema

`coordinator_assignment` table already has the correct schema (composite PK: user_id + shelter_id). No migration needed.
