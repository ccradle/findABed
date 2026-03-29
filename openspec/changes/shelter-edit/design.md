## Context

ShelterForm.tsx is create-only. The Admin Shelters tab shows a read-only table. The Coordinator dashboard only allows bed availability updates, not shelter detail edits. The API supports PUT /api/v1/shelters/{id} for COORDINATOR+ but no frontend uses it. DV shelters have special sensitivity — changing the DV flag or address could expose a survivor's location.

## Goals / Non-Goals

**Goals:**
- Reuse ShelterForm for both create and edit modes
- Admin can edit all shelter fields from the Shelters tab
- Coordinator can edit own shelter's operational details (phone, hours, constraints)
- DV shelter edits have tiered safeguards (role-gated fields, confirmation dialogs, audit logging)

**Non-Goals:**
- Shelter deactivation/archival (future change)
- Shelter transfer between tenants
- Bulk shelter editing
- Shelter merge/duplicate detection

## Decisions

### D1: ShelterForm mode detection via initialData prop

If `initialData` is provided, form is in edit mode (PUT on save). If not, create mode (POST). Parent component handles the routing: `/coordinator/shelters/new` for create, `/coordinator/shelters/:id/edit` for edit. Form fields identical in both modes except disabled fields for role-based restrictions.

### D2: Tiered field sensitivity

| Field Category | Examples | Who Can Edit | UX |
|---|---|---|---|
| Operational | phone, curfew, max stay, accepting guests | COORDINATOR+ | Immediate save |
| Structural | name, address, population types, capacity | COC_ADMIN+ | Save + audit log |
| Safety-critical | dvShelter flag | COC_ADMIN+ | Confirmation dialog + audit |

Coordinator sees structural fields as read-only in the edit form. COC_ADMIN sees all fields editable.

### D3: DV shelter safeguards

- `dvShelter` toggle: disabled for roles below COC_ADMIN. Not hidden (transparency), but locked with tooltip "Contact your CoC administrator to change DV status."
- Changing `dvShelter` from true→false: confirmation dialog explaining "This will make the shelter address visible to all users including outreach workers without DV authorization."
- Backend enforcement: PUT /api/v1/shelters/{id} checks role if `dvShelter` field is changing. Returns 403 if COORDINATOR tries to change it.
- Address changes on DV shelters: audit-logged with old/new values.

### D4: Edit navigation paths

- Admin Shelters tab: "Edit" link in each table row → navigates to `/coordinator/shelters/:id/edit`
- Coordinator dashboard: "Edit Details" button on expanded shelter card → same route
- After save: navigate back to the originating page (admin or coordinator)

## Risks / Trade-offs

- **Coordinator editing wrong shelter**: mitigated by existing coordinator-shelter assignment checks in backend (coordinators can only edit shelters they're assigned to).
- **DV flag change race condition**: if two admins edit simultaneously and one changes DV flag, the other's save could overwrite it. Mitigated by optimistic locking (version field on shelter entity, 409 on conflict).
