## ADDED Requirements

### Requirement: Tenant DV-policy invariant on dv_shelter writes

The system SHALL reject any shelter create or update request that sets `dv_shelter = true` if the parent tenant's `dv_policy_enabled` flag is `false` (or absent). The response SHALL be `400 Bad Request` with structured error code `shelter.dvShelter.requiresDvPolicy`. The error message SHALL direct the operator to enable the tenant DV-policy flag in the admin Settings tab before flipping per-shelter `dv_shelter` to `true`. Setting `dv_shelter = false` SHALL succeed regardless of the tenant flag.

#### Scenario: Create rejected when tenant flag is off

- **WHEN** a COC_ADMIN sends `POST /api/v1/shelters` with `dvShelter: true` on a tenant where `dv_policy_enabled` is `false` or absent
- **THEN** the response is `400 Bad Request` with error code `shelter.dvShelter.requiresDvPolicy`
- **AND** no shelter row is created

#### Scenario: Update rejected when flipping to dvShelter=true while tenant flag is off

- **WHEN** a COC_ADMIN sends `PUT /api/v1/shelters/{id}` setting `dvShelter` from `false` to `true` on a tenant where `dv_policy_enabled` is `false` or absent
- **THEN** the response is `400 Bad Request` with error code `shelter.dvShelter.requiresDvPolicy`
- **AND** the shelter's `dv_shelter` value is unchanged

#### Scenario: Create allowed when tenant flag is on

- **WHEN** a COC_ADMIN sends `POST /api/v1/shelters` with `dvShelter: true` on a tenant where `dv_policy_enabled` is `true`
- **THEN** the response is `201 Created` and the shelter is persisted with `dv_shelter = true`

#### Scenario: Update allowed when flipping to dvShelter=true with tenant flag on

- **WHEN** a COC_ADMIN sends `PUT /api/v1/shelters/{id}` setting `dvShelter` from `false` to `true` on a tenant where `dv_policy_enabled` is `true`
- **THEN** the response is `200 OK` and the shelter's `dv_shelter` value is `true`

#### Scenario: Setting dvShelter=false succeeds regardless of tenant flag

- **WHEN** a COC_ADMIN sends `POST /api/v1/shelters` with `dvShelter: false` (or omits the field) on a tenant where `dv_policy_enabled` is `false`
- **THEN** the response is `201 Created` and the shelter is persisted with `dv_shelter = false`

#### Scenario: Existing dvShelter=true shelters unaffected after flag flip

- **WHEN** a tenant's `dv_policy_enabled` flag was previously `true` and a shelter was created with `dv_shelter = true`
- **AND** the operator subsequently deactivates that shelter and disables the flag
- **THEN** other (active or inactive) shelters with `dv_shelter = true` not yet touched remain in the database with their values preserved
- **AND** subsequent reads return their existing `dv_shelter` value
- **AND** any further write attempting to set `dv_shelter = true` on such a shelter is rejected per the create/update scenarios above

#### Scenario: Reactivation rejected when tenant flag is off

- **WHEN** a tenant's `dv_policy_enabled` is `false` and a deactivated shelter exists with `dv_shelter = true` AND `active = false`
- **AND** a COC_ADMIN attempts to reactivate that shelter (e.g. via `PATCH /api/v1/shelters/{id}/activate` or equivalent project route)
- **THEN** the response is `400 Bad Request` with error code `shelter.dvShelter.requiresDvPolicy`
- **AND** the shelter remains `active = false`
- **AND** the operator must enable the tenant DV-policy flag before reactivation succeeds

#### Scenario: Reactivation succeeds after re-enabling the flag

- **WHEN** the operator first sets `dv_policy_enabled = true` on the tenant
- **AND** then reactivates the shelter with `dv_shelter = true`
- **THEN** the response is `200 OK` and the shelter is `active = true`

### Requirement: 211 CSV bulk import enforces the tenant DV-policy invariant per row

The 211 CSV import path SHALL apply the tenant DV-policy invariant to each imported row independently. When the import target tenant's `dv_policy_enabled` is `false`, rows that would create a shelter with `dv_shelter = true` SHALL be rejected with structured error code `shelter.dvShelter.requiresDvPolicy`, and rows that would create non-DV shelters SHALL succeed. The import response SHALL include per-row results so the operator can see which rows were rejected and why. The import SHALL NOT fail wholesale on the presence of DV rows on a flag-off tenant.

#### Scenario: Mixed import on flag-off tenant — DV rows rejected, non-DV rows succeed

- **WHEN** a COC_ADMIN imports a 211 CSV containing 5 rows (3 with source data implying `dv_shelter = true`, 2 with `dv_shelter = false`) on a tenant where `dv_policy_enabled = false`
- **THEN** the 2 non-DV rows are persisted as new shelters
- **AND** the 3 DV rows are rejected with structured error code `shelter.dvShelter.requiresDvPolicy`
- **AND** the import response includes per-row results identifying which rows were accepted and which were rejected
- **AND** the import is reported as partial success, not wholesale failure

#### Scenario: All-DV import on flag-off tenant — all rows rejected, partial-result response

- **WHEN** a COC_ADMIN imports a 211 CSV where every row has source data implying `dv_shelter = true` on a tenant where `dv_policy_enabled = false`
- **THEN** every row is rejected with `shelter.dvShelter.requiresDvPolicy`
- **AND** no shelters are created
- **AND** the import response identifies the total rejected count and the structured code

#### Scenario: Import on flag-on tenant — DV rows succeed

- **WHEN** a COC_ADMIN imports a 211 CSV containing rows with `dv_shelter = true` on a tenant where `dv_policy_enabled = true`
- **THEN** all rows are persisted regardless of `dv_shelter` value (subject to other validation)
