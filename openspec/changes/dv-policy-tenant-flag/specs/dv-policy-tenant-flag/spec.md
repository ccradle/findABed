## ADDED Requirements

### Requirement: Tenant DV-policy flag

The system SHALL persist a tenant-level boolean flag `dv_policy_enabled` under the JSONB `tenant.config` column. The flag SHALL default to `false` on tenants where the key is absent. A `Tenant.isDvPolicyEnabled()` helper SHALL be the single read path used by service-layer enforcement code.

#### Scenario: Default value on absent key

- **WHEN** a tenant has no `dv_policy_enabled` key in `tenant.config`
- **THEN** `Tenant.isDvPolicyEnabled()` returns `false`

#### Scenario: Read after explicit enable

- **WHEN** a tenant has `tenant.config.dv_policy_enabled = true`
- **THEN** `Tenant.isDvPolicyEnabled()` returns `true`

#### Scenario: Read after explicit disable

- **WHEN** a tenant has `tenant.config.dv_policy_enabled = false`
- **THEN** `Tenant.isDvPolicyEnabled()` returns `false`

### Requirement: PATCH dv-policy endpoint

The system SHALL expose `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy` accepting `{"dvPolicyEnabled": <boolean>}`. The endpoint SHALL require role `COC_ADMIN`. The endpoint SHALL enforce tenant scoping: the path's `tenantId` MUST equal the caller's JWT-bound `TenantContext.getTenantId()`. On success the endpoint SHALL return `200 OK` with the updated value as confirmation.

#### Scenario: COC_ADMIN enables flag on own tenant

- **WHEN** a COC_ADMIN whose JWT-bound tenant equals the path tenant sends `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy` with `{"dvPolicyEnabled": true}`
- **THEN** the response is `200 OK`
- **AND** the response body confirms `tenantId` and `dvPolicyEnabled: true`
- **AND** the value is persisted in `tenant.config.dv_policy_enabled`

#### Scenario: COC_ADMIN cannot flip another tenant's flag

- **WHEN** a COC_ADMIN whose JWT-bound tenant is Tenant A sends `PATCH /api/v1/admin/tenants/{tenantBId}/dv-policy`
- **THEN** the response is `403 Forbidden` with no body

#### Scenario: Cross-tenant probe does not leak DV-shelter inventory

- **WHEN** a COC_ADMIN whose JWT-bound tenant is Tenant A sends `PATCH /api/v1/admin/tenants/{tenantBId}/dv-policy` with `{"dvPolicyEnabled": false}` against a Tenant B that has 3 active DV shelters
- **THEN** the response is `403 Forbidden` with no body
- **AND** the response headers, response body, and any error-message text contain no integer or string referencing the count `3` (or any other shelter-derived datum)
- **AND** the tenant-scoping check executes BEFORE the disable-path inventory query, so the response timing does not vary based on Tenant B's DV-shelter count

#### Scenario: Non-admin cannot flip flag

- **WHEN** a COORDINATOR or OUTREACH_WORKER sends `PATCH /api/v1/admin/tenants/{tenantId}/dv-policy`
- **THEN** the response is `403 Forbidden`

#### Scenario: Missing or malformed body returns 400

- **WHEN** a COC_ADMIN sends the request without `dvPolicyEnabled` in the body or with a non-boolean value
- **THEN** the response is `400 Bad Request` with a Bean Validation error

### Requirement: Enable path is unrestricted

The system SHALL accept a `false → true` flip regardless of the tenant's current shelter inventory. A tenant with zero shelters SHALL be able to enable the flag in preparation for onboarding DV shelters.

#### Scenario: Enable on tenant with zero shelters

- **WHEN** a COC_ADMIN sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": true}` on a tenant with no shelters
- **THEN** the response is `200 OK` and the flag is set to `true`

#### Scenario: Enable on tenant with only non-DV shelters

- **WHEN** a COC_ADMIN sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": true}` on a tenant with shelters but none `dv_shelter=true`
- **THEN** the response is `200 OK` and the flag is set to `true`

#### Scenario: Re-enable when already enabled is idempotent

- **WHEN** a COC_ADMIN sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": true}` on a tenant where the flag is already `true`
- **THEN** the response is `200 OK` and the flag remains `true`

### Requirement: Disable path forbidden while DV shelters exist

The system SHALL reject a `true → false` flip if the tenant has any active shelter with `dv_shelter = true`. The response SHALL be `400 Bad Request` with structured error code `tenant.dvPolicy.cannotDisableWhileDvSheltersExist`. The error message SHALL include the count of remaining DV shelters. The flag value SHALL NOT change. The operator MUST first migrate or deactivate all active DV shelters, THEN re-attempt the disable.

#### Scenario: Disable rejected when active DV shelters exist

- **WHEN** a COC_ADMIN sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": false}` on a tenant with 2 active DV shelters
- **THEN** the response is `400 Bad Request` with error code `tenant.dvPolicy.cannotDisableWhileDvSheltersExist`
- **AND** the error message includes "2 active DV shelters" or equivalent count text
- **AND** `tenant.config.dv_policy_enabled` remains `true`

#### Scenario: Disable allowed after all DV shelters deactivated

- **WHEN** a COC_ADMIN deactivates all DV shelters on the tenant (each via `PATCH /api/v1/shelters/{id}/deactivate`)
- **AND** subsequently sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": false}`
- **THEN** the response is `200 OK` and the flag is set to `false`

#### Scenario: Inactive DV shelters do not block disable

- **WHEN** a tenant has 3 shelters with `dv_shelter=true` but `active=false`, and zero active DV shelters
- **AND** a COC_ADMIN sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": false}`
- **THEN** the response is `200 OK` and the flag is set to `false`

#### Scenario: Re-disable when already disabled is idempotent

- **WHEN** a COC_ADMIN sends `PATCH .../dv-policy` with `{"dvPolicyEnabled": false}` on a tenant where the flag is already `false`
- **THEN** the response is `200 OK` and the flag remains `false`

### Requirement: Audit on flag change and on rejected disable

The system SHALL emit a `TENANT_CONFIG_UPDATED` audit event on every successful flag change AND on every rejected disable attempt. The details payload SHALL include `config_key: "dv_policy_enabled"`, `old_value`, `new_value`, `outcome` (`"applied"` or `"rejected"`), `rejection_code` (the structured error code or `null`), and `remaining_dv_shelter_count` (integer or `null`).

#### Scenario: Audit on successful enable

- **WHEN** a COC_ADMIN enables the flag on a tenant where it was previously `false`
- **THEN** a `TENANT_CONFIG_UPDATED` audit row is recorded
- **AND** the details payload includes `outcome: "applied"`, `old_value: false`, `new_value: true`, `rejection_code: null`, `remaining_dv_shelter_count: null`

#### Scenario: Audit on successful disable

- **WHEN** a COC_ADMIN disables the flag on a tenant with zero active DV shelters
- **THEN** a `TENANT_CONFIG_UPDATED` audit row is recorded
- **AND** the details payload includes `outcome: "applied"`, `old_value: true`, `new_value: false`, `rejection_code: null`, `remaining_dv_shelter_count: 0`

#### Scenario: Audit on rejected disable attempt

- **WHEN** a COC_ADMIN attempts to disable the flag on a tenant with 2 active DV shelters and the request is rejected
- **THEN** a `TENANT_CONFIG_UPDATED` audit row is still recorded
- **AND** the details payload includes `outcome: "rejected"`, `old_value: true`, `new_value: true`, `rejection_code: "tenant.dvPolicy.cannotDisableWhileDvSheltersExist"`, `remaining_dv_shelter_count: 2`
- **AND** the audit row is emitted BEFORE the rejection exception is thrown, so the row persists even when the request fails

#### Scenario: Audit on cross-tenant access attempt

- **WHEN** a COC_ADMIN whose JWT-bound tenant is Tenant A sends `PATCH /api/v1/admin/tenants/{tenantBId}/dv-policy`
- **THEN** an audit row is recorded with details including `outcome: "rejected"`, `rejection_code: "tenant.crossTenantAccess"`, the actor's tenant ID, and the target tenant ID
- **AND** the audit captures the lateral-movement signal regardless of whether Tenant B exists or has DV shelters

### Requirement: Initial-deploy backfill

A Flyway migration SHALL set `dv_policy_enabled = true` on every tenant where at least one shelter exists with `dv_shelter = true` at migration time. Tenants with zero DV shelters SHALL receive no write (the helper defaults to `false` on absent key). The migration SHALL be idempotent (safe to re-run).

#### Scenario: Tenant with existing DV shelters backfills to true

- **WHEN** the V94 migration runs on a tenant with one or more shelters where `dv_shelter = true`
- **THEN** that tenant's `tenant.config.dv_policy_enabled` is `true` after migration

#### Scenario: Tenant with no DV shelters is not modified

- **WHEN** the V94 migration runs on a tenant with no shelters where `dv_shelter = true`
- **THEN** that tenant's `tenant.config` does NOT contain a `dv_policy_enabled` key
- **AND** `Tenant.isDvPolicyEnabled()` returns `false` for that tenant

#### Scenario: Migration is idempotent on re-run

- **WHEN** V94 has already run and the migration is re-applied
- **THEN** the resulting state is identical to a single run (no duplicate writes, no state drift)

### Requirement: Admin UI with extra-confirm modal

The frontend admin Settings tab SHALL include a `DvPolicySettings.tsx` component that displays the current flag value and allows COC_ADMIN users to flip it. Submission SHALL be gated by an extra-confirm modal that describes the implications of the flip. The component SHALL render localized copy in EN and ES.

#### Scenario: Component visible to COC_ADMIN

- **WHEN** a COC_ADMIN navigates to the admin Settings tab
- **THEN** the `DvPolicySettings` panel is visible with the current flag state and toggle control

#### Scenario: Component hidden from non-admins

- **WHEN** a COORDINATOR or OUTREACH_WORKER navigates to the admin Settings area
- **THEN** the `DvPolicySettings` panel is not rendered

#### Scenario: Extra-confirm modal pre-flip

- **WHEN** a COC_ADMIN clicks the toggle to flip the flag
- **THEN** a confirmation modal appears describing the implications of the new state
- **AND** the PATCH request is only sent after the user clicks "Confirm"
- **AND** clicking "Cancel" leaves the flag unchanged and closes the modal

#### Scenario: Disable rejection surfaces in UI

- **WHEN** a COC_ADMIN attempts to disable the flag on a tenant with active DV shelters and the backend returns the rejection
- **THEN** the UI displays an error explaining that DV shelters must be deactivated first
- **AND** the error message references the count of remaining DV shelters returned by the backend
- **AND** the toggle reverts to the prior (enabled) state

#### Scenario: Localized copy in Spanish

- **WHEN** the user has language set to `es`
- **THEN** the panel label, current-state text, modal title, modal body, confirm button, and error messages render in Spanish
