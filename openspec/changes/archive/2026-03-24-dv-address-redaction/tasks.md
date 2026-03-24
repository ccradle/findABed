## 1. Branch Setup

- [x] 1.1 Create branch `feature/dv-address-redaction` from main

## 2. Tenant Config — Policy Setting

- [x] 2.1 Added `dv_address_visibility: ADMIN_AND_ASSIGNED` to seed-data.sql tenant config
- [x] 2.2 Created `DvAddressPolicy` enum with 4 values + `fromString()` parser
- [x] 2.3 Added `getDvAddressPolicy(tenantId)` to `ShelterService` — reads from tenant config JSONB

## 3. Address Redaction Logic

- [x] 3.1 Created `DvAddressRedactionHelper` with `shouldRedact(Shelter, Authentication, DvAddressPolicy)` and overload for dvShelter boolean
- [x] 3.2 Logic: non-DV never redacted; switch on policy evaluating admin role + coordinator assignment
- [x] 3.3 Static `redactAddress(ShelterResponse)`: nulls street/city/state/zip/lat/lng, keeps phone

## 4. Apply Redaction to Shelter Endpoints

- [x] 4.1 `GET /api/v1/shelters/{id}`: redaction via `DvAddressRedactionHelper` + `redactAddress()` based on tenant policy
- [x] 4.2 `GET /api/v1/shelters` (list): redaction in stream map for each DV shelter
- [x] 4.3 `GET /api/v1/shelters/{id}?format=hsds`: removes `physical_address` and nulls lat/lng for DV shelters per policy
- [x] 4.4 Verify bed search API (`BedSearchService`) already redacts — no change needed (confirm with test)

## 5. Policy Change Endpoint

- [x] 5.1 Added `PUT /api/v1/tenants/{id}/dv-address-policy` in TenantController — PLATFORM_ADMIN + @PreAuthorize
- [x] 5.2 Requires `X-Confirm-Policy-Change: CONFIRM` header — 400 without it
- [x] 5.3 Validates against `DvAddressPolicy` enum — 400 with valid policies list for invalid values
- [x] 5.4 Updates tenant config JSONB via `tenantService.updateConfig()`
- [x] 5.5 Logs at WARN with policy, tenant, and user
- [x] 5.6 Endpoint at `/api/v1/tenants/{id}/dv-address-policy` — already covered by existing tenant SecurityConfig rules
- [x] 5.7 @Operation annotation: "INTERNAL/ADMIN-ONLY — should not be exposed outside corporate firewall"

## 6. Integration Tests

- [x] 6.1 Test: ADMIN_AND_ASSIGNED — PLATFORM_ADMIN sees address
- [x] 6.2 Test: ADMIN_AND_ASSIGNED — assigned COORDINATOR sees address
- [x] 6.3 Test: ADMIN_AND_ASSIGNED — unassigned COORDINATOR does NOT see address
- [x] 6.4 Test: ADMIN_AND_ASSIGNED — OUTREACH_WORKER does NOT see address
- [x] 6.5 Test: ADMIN_ONLY — assigned COORDINATOR does NOT see address
- [x] 6.6 Test: ALL_DV_ACCESS — OUTREACH_WORKER sees address
- [x] 6.7 Test: NONE — PLATFORM_ADMIN does NOT see address
- [x] 6.8 Test: non-DV shelter always returns address regardless of policy
- [x] 6.9 Test: policy change without confirmation header → 400
- [x] 6.10 Test: policy change by non-PLATFORM_ADMIN → 403
- [x] 6.11 Test: invalid policy value → 400
- [x] 6.12 Test: shelter list redacts DV addresses per policy
- [x] 6.13 Test: HSDS export redacts DV addresses per policy

## 7. Karate API Tests

- [x] 7.1 `dv-address-redaction.feature`: verify address present/absent per role under default policy
- [x] 7.2 `dv-address-policy.feature`: change policy, verify effect, confirm safeguards (header, role)

## 8. Documentation

- [x] 8.1 Update `docs/DV-OPAQUE-REFERRAL.md`: add "Address Visibility Policy" section documenting policies and the API endpoint
- [x] 8.2 Update `docs/runbook.md`: add policy change to DV referral operations, note endpoint should not be exposed outside firewall
- [x] 8.3 Update code repo `README.md` DV Privacy section: note configurable address policy
- [x] 8.4 Update `docs/schema.dbml`: note `dv_address_visibility` in tenant config
- [x] 8.5 Update code repo `README.md` test counts

## 9. Regression and PR

- [x] 9.1 Run full backend test suite
- [x] 9.2 Run Playwright suite
- [x] 9.3 Run Karate suite
- [x] 9.4 Commit all changes on `feature/dv-address-redaction` branch
- [x] 9.5 Push branch, create PR to main
- [x] 9.6 Merge PR to main
- [x] 9.7 Delete feature branch
- [x] 9.8 Tag release (v0.10.1)
