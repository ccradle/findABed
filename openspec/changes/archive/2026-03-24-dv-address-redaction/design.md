## Context

`GET /api/v1/shelters/{id}` returns full address for DV shelters. The bed search API already redacts (BedSearchService nulls address/lat/lng for dvShelter=true), and the frontend hides the address. But direct API access bypasses both. FVPSA requires the address be shared verbally only.

Different CoC deployments may have different rules about who can see DV shelter addresses. The redaction policy must be configurable per tenant.

## Goals / Non-Goals

**Goals:**
- Redact DV shelter address fields at the API layer based on a configurable tenant policy
- Default to the most restrictive reasonable policy (`ADMIN_AND_ASSIGNED`)
- Allow CoC administrators to change the policy via a secured API call
- Document the policy and endpoint as internal/admin-only

**Non-Goals:**
- Admin UI for policy changes (API-only, deliberate invocation)
- Per-user address visibility overrides (policy is tenant-wide)
- Redacting address in the database (data stays intact, redaction is at the response layer)

## Decisions

### D1: Policy values

| Policy | Who Sees Address | Use Case |
|--------|-----------------|----------|
| `ADMIN_AND_ASSIGNED` (default) | PLATFORM_ADMIN, COC_ADMIN, coordinators assigned to the shelter | Most deployments — admins manage, assigned coordinators work there |
| `ADMIN_ONLY` | PLATFORM_ADMIN, COC_ADMIN only | Stricter — even assigned coordinators don't see address in API |
| `ALL_DV_ACCESS` | Any user with dvAccess=true | Permissive — legacy behavior before this change |
| `NONE` | No one sees address in API | Maximum restriction — address only via verbal handoff |

### D2: Redaction location

Redaction happens in `ShelterController` (not `ShelterService` or `ShelterResponse`). The controller has access to `Authentication` (for role/assignment checks) and can read the tenant policy. The service layer returns full data; the controller filters before serialization.

This means `ShelterResponse.from(shelter)` remains unchanged — it always builds the full response. The controller nulls out address fields based on policy before returning.

### D3: Policy storage

Add `dv_address_visibility` to the existing tenant config JSONB. Default: `ADMIN_AND_ASSIGNED`. Read via the same cached config pattern used by `hold_duration_minutes` and `dv_referral_expiry_minutes`.

### D4: Policy change endpoint

`PUT /api/v1/tenants/{id}/dv-address-policy` with body `{"policy": "ADMIN_AND_ASSIGNED"}`.

Safeguards:
- `PLATFORM_ADMIN` role required
- `X-Confirm-Policy-Change: CONFIRM` header required (prevents accidental invocation)
- Logged at WARN level: "DV address visibility policy changed to X for tenant Y by user Z"

### D5: Coordinator assignment check

For `ADMIN_AND_ASSIGNED` policy, the controller checks `CoordinatorAssignmentRepository.isAssigned(userId, shelterId)`. This is already injected in `ShelterController` (used for PUT authorization). No new dependency needed.

### D6: Fields redacted

When redaction applies, the following fields are set to `null` in the response:
- `addressStreet`
- `addressCity`
- `addressState`
- `addressZip`
- `latitude`
- `longitude`

`name`, `phone`, `dvShelter`, and all other fields remain. Phone is needed for warm handoff after referral acceptance.

### D7: Which endpoints are affected

- `GET /api/v1/shelters/{id}` — redact in the detail response
- `GET /api/v1/shelters` (list) — redact in each `ShelterListResponse` if it includes address fields
- `GET /api/v1/shelters/{id}?format=hsds` — redact in the HSDS response (physical_address section)

The bed search API (`POST /api/v1/queries/beds`) already redacts in `BedSearchService` — no change needed there.

### D8: Security documentation

The policy change endpoint must be documented as:
- Internal/admin-only — should not be exposed outside the corporate firewall
- Requires PLATFORM_ADMIN + confirmation header
- Runbook: include in the DV referral operations section
- DV addendum: add "Address Visibility Policy" section
- README: note in the DV Privacy section
