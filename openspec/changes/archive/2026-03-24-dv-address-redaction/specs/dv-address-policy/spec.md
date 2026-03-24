## ADDED Requirements

### Requirement: dv-address-visibility-policy
The system SHALL redact DV shelter address fields in API responses based on a configurable tenant-level policy. The policy determines which users can see DV shelter addresses.

#### Scenario: Default policy ADMIN_AND_ASSIGNED — admin sees address
- **WHEN** the tenant policy is `ADMIN_AND_ASSIGNED` (default)
- **AND** a PLATFORM_ADMIN or COC_ADMIN requests `GET /api/v1/shelters/{id}` for a DV shelter
- **THEN** the response includes `addressStreet`, `addressCity`, `latitude`, `longitude`

#### Scenario: Default policy ADMIN_AND_ASSIGNED — assigned coordinator sees address
- **WHEN** the tenant policy is `ADMIN_AND_ASSIGNED`
- **AND** a COORDINATOR assigned to the DV shelter requests the detail
- **THEN** the response includes address fields

#### Scenario: Default policy ADMIN_AND_ASSIGNED — unassigned coordinator does NOT see address
- **WHEN** the tenant policy is `ADMIN_AND_ASSIGNED`
- **AND** a COORDINATOR NOT assigned to the DV shelter requests the detail
- **THEN** the response has `addressStreet: null`, `latitude: null`, etc.

#### Scenario: Default policy ADMIN_AND_ASSIGNED — outreach worker does NOT see address
- **WHEN** the tenant policy is `ADMIN_AND_ASSIGNED`
- **AND** an OUTREACH_WORKER with dvAccess requests the detail
- **THEN** the response has address fields set to null

#### Scenario: ADMIN_ONLY policy — even assigned coordinator does not see address
- **WHEN** the tenant policy is `ADMIN_ONLY`
- **AND** a COORDINATOR assigned to the DV shelter requests the detail
- **THEN** the response has address fields set to null

#### Scenario: ALL_DV_ACCESS policy — any dvAccess user sees address
- **WHEN** the tenant policy is `ALL_DV_ACCESS`
- **AND** an OUTREACH_WORKER with dvAccess requests the detail
- **THEN** the response includes address fields

#### Scenario: NONE policy — no one sees address
- **WHEN** the tenant policy is `NONE`
- **AND** a PLATFORM_ADMIN requests the detail for a DV shelter
- **THEN** the response has address fields set to null

#### Scenario: Non-DV shelters are unaffected
- **WHEN** any user requests `GET /api/v1/shelters/{id}` for a non-DV shelter
- **THEN** the response always includes address fields regardless of policy

### Requirement: dv-address-policy-management
The system SHALL provide an API endpoint for PLATFORM_ADMIN users to change the DV address visibility policy. The endpoint requires a confirmation header to prevent accidental invocation.

#### Scenario: Policy change with confirmation succeeds
- **WHEN** a PLATFORM_ADMIN calls `PUT /api/v1/tenants/{id}/dv-address-policy` with `{"policy": "ADMIN_ONLY"}` and header `X-Confirm-Policy-Change: CONFIRM`
- **THEN** the policy is updated and the response confirms the new policy

#### Scenario: Policy change without confirmation rejected
- **WHEN** a PLATFORM_ADMIN calls the endpoint without the `X-Confirm-Policy-Change` header
- **THEN** the API returns 400 with a message about the missing header

#### Scenario: Non-admin cannot change policy
- **WHEN** a COC_ADMIN or OUTREACH_WORKER calls the policy change endpoint
- **THEN** the API returns 403

#### Scenario: Invalid policy value rejected
- **WHEN** a PLATFORM_ADMIN sends `{"policy": "INVALID_VALUE"}`
- **THEN** the API returns 400 listing valid policies

### Requirement: redaction-applies-to-all-shelter-endpoints
Address redaction SHALL apply consistently to all endpoints that return shelter data for DV shelters.

#### Scenario: Shelter list redacts DV addresses
- **WHEN** the policy restricts address visibility
- **AND** a user without address access requests `GET /api/v1/shelters`
- **THEN** DV shelter entries in the list have address fields set to null

#### Scenario: HSDS export redacts DV addresses
- **WHEN** the policy restricts address visibility
- **AND** a user without address access requests `GET /api/v1/shelters/{id}?format=hsds`
- **THEN** the `physical_address` section is omitted or nulled for DV shelters
