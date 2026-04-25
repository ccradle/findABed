## MODIFIED Requirements

### Requirement: admin-user-edit-drawer
The admin panel SHALL allow `COC_ADMIN` to edit user details via a slide-out drawer. (Previously: `COC_ADMIN and PLATFORM_ADMIN`. PLATFORM_ADMIN is deprecated; tenant-scoped admin operations are gated solely on `COC_ADMIN` going forward.)

#### Scenario: Admin edits user display name and roles
- **WHEN** an admin clicks "Edit" on a user row in the Users tab
- **THEN** a slide-out drawer opens with editable fields: display name, email, roles, dvAccess
- **AND** saving sends PUT /api/v1/users/{id} and the drawer closes with a success message

#### Scenario: PLATFORM_ADMIN-only JWT can still edit during deprecation window
- **WHEN** a JWT bearing only `PLATFORM_ADMIN` (no `COC_ADMIN`) is presented to PUT /api/v1/users/{id} during the v0.53 deprecation window
- **THEN** the request succeeds because the COC_ADMIN backfill in V87 added COC_ADMIN to all PLATFORM_ADMIN-bearing rows
- **AND** the cleanup release (post-v0.53) removes the PLATFORM_ADMIN enum value entirely
