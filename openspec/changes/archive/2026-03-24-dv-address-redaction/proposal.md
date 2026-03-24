## Why

During the DV opaque referral implementation, we discovered that `GET /api/v1/shelters/{id}` returns full address fields (`addressStreet`, `addressCity`, `addressState`, `addressZip`, `latitude`, `longitude`) for DV shelters to any authenticated user with `dvAccess=true`. This includes outreach workers who should NOT see the address (FVPSA — address shared verbally during warm handoff only).

The bed search API was already redacted (address/lat/lng nulled for DV shelters in `BedSearchService`), and the frontend hides the address in the UI. But a direct API call bypasses both mitigations. An MCP agent or custom client calling the shelter detail endpoint would receive the full address.

The fix: configurable, tenant-level policy that controls which users can see DV shelter addresses based on their role and shelter assignment.

## What Changes

- **Tenant config policy**: Add `dv_address_visibility` to tenant config JSONB with a default of `ADMIN_AND_ASSIGNED`. Supported policies: `ADMIN_AND_ASSIGNED` (default — PLATFORM_ADMIN, COC_ADMIN, and coordinators assigned to the shelter), `ADMIN_ONLY` (only PLATFORM_ADMIN and COC_ADMIN), `ALL_DV_ACCESS` (any user with dvAccess=true), `NONE` (never show address in API)
- **API-level redaction**: `ShelterController` evaluates the policy against the authenticated user's role and shelter assignment before including address fields in the response
- **Policy change endpoint**: `PUT /api/v1/tenants/{id}/dv-address-policy` — PLATFORM_ADMIN only, requires `X-Confirm-Policy-Change` header to prevent accidental invocation. API-only, no UI.
- **Documentation**: Runbook and DV addendum updated. Endpoint documented as internal/admin-only — should not be exposed outside the firewall.
- **All changes on feature branch** `feature/dv-address-redaction` from main — PR to main after full test suite passes

## Capabilities

### New Capabilities
- `dv-address-policy`: Configurable tenant-level policy for DV shelter address visibility

### Modified Capabilities
- `shelter-management`: `ShelterResponse` redacts address fields for DV shelters based on policy

## Impact

- **Modified files (backend)**: `ShelterController.java` (redaction logic), `ShelterResponse.java` (conditional address fields), `TenantController.java` or new policy endpoint, `SecurityConfig.java`
- **Modified files (config)**: `seed-data.sql` (default policy in tenant config)
- **Modified files (docs)**: `DV-OPAQUE-REFERRAL.md`, `runbook.md`, `README.md`
- **New tests**: Integration tests for each policy mode, Karate API tests verifying address presence/absence
- **Risk**: Low — additive redaction. Existing behavior (address visible to all dvAccess users) becomes the `ALL_DV_ACCESS` policy. Default changes to the more restrictive `ADMIN_AND_ASSIGNED`.
- **Branch strategy**: All changes on `feature/dv-address-redaction` from main, PR after full test suite passes
