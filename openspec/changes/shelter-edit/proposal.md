## Why

Shelters can be created but never edited from the UI. Sandra (Coordinator) can't update her shelter's phone number when it changes. Marcus (CoC Admin) can't fix an address typo from onboarding. Reverend Monroe can't reactivate her seasonal shelter or update capacity for winter. All of these require direct database access or developer intervention — a self-service gap that blocks daily operations and makes the platform look incomplete in procurement review.

## What Changes

- **ShelterForm edit mode**: reuse existing ShelterForm.tsx (currently create-only) with `initialData` prop for edit. POST for create, PUT for edit. Route: `/coordinator/shelters/:id/edit`.
- **Admin Shelters tab — edit link**: "Edit" button on each shelter row, navigates to ShelterForm in edit mode. COC_ADMIN+ can edit all fields.
- **Coordinator dashboard — edit own shelter**: "Edit Details" button on expanded shelter card. Coordinators can edit phone, curfew, max stay, constraints, accepting new guests. Cannot edit name, address, DV flag (admin-only).
- **DV shelter safeguards**: dvShelter flag locked below COC_ADMIN. Changing DV→non-DV requires confirmation dialog. Address changes on DV shelters logged and flagged. Backend enforcement on the PATCH endpoint.

## Capabilities

### New Capabilities
- `shelter-edit`: Shelter edit form (create/edit mode), admin and coordinator edit paths, DV shelter safeguards with tiered field sensitivity

### Modified Capabilities

## Impact

- **Backend**: Shelter edit endpoint validation for DV safeguards, field-level authorization checks, audit logging for sensitive field changes
- **Frontend**: ShelterForm edit mode detection, admin Shelters tab edit link, coordinator dashboard edit button, DV confirmation dialog
- **Testing**: Backend integration tests for shelter edit, DV safeguards. Playwright e2e for edit flow, DV confirmation. Screenshot captures.
