## ADDED Requirements

### Requirement: shelter-crud
The system SHALL support creating, reading, updating, and listing shelter profiles scoped to a tenant, aligned with HSDS 3.0 organization/service/location model.

#### Scenario: Create a shelter
- **WHEN** a CoC admin sends POST `/api/v1/shelters` with name, address, phone, and capacity
- **THEN** the system creates the shelter within the admin's tenant and returns 201 with the shelter resource including a generated UUID

#### Scenario: Read a shelter
- **WHEN** an authenticated user sends GET `/api/v1/shelters/{id}` for a shelter in their tenant
- **THEN** the system returns the full shelter profile including constraints

#### Scenario: Update a shelter
- **WHEN** a coordinator or CoC admin sends PUT `/api/v1/shelters/{id}`
- **THEN** the system updates the shelter profile and returns 200

#### Scenario: List shelters with pagination
- **WHEN** an authenticated user sends GET `/api/v1/shelters?page=0&size=20`
- **THEN** the system returns a paginated list of shelters in the user's tenant
- **AND** the response includes total count and page metadata

### Requirement: shelter-constraints
The system SHALL store shelter constraints as defined by the HSDS extension: sobriety_required, id_required, referral_required, pets_allowed, wheelchair_accessible, dv_shelter, curfew_time, max_stay_days, and population_types_served.

#### Scenario: Constraints stored on creation
- **WHEN** a shelter is created with constraints (sobriety_required=true, pets_allowed=false, population_types_served=[SINGLE_ADULT, VETERAN])
- **THEN** the system persists all constraints and returns them in the shelter response

#### Scenario: Constraints filterable in list
- **WHEN** an outreach worker sends GET `/api/v1/shelters?pets_allowed=true&wheelchair_accessible=true`
- **THEN** the system returns only shelters matching all specified constraint filters

#### Scenario: Population type enum enforced
- **WHEN** a shelter is created with an invalid population type (e.g., "INVALID_TYPE")
- **THEN** the system returns 400 Bad Request listing valid population types: SINGLE_ADULT, FAMILY_WITH_CHILDREN, WOMEN_ONLY, VETERAN, YOUTH_18_24, YOUTH_UNDER_18, DV_SURVIVOR

### Requirement: shelter-hsds-compatibility
The system SHALL map shelter data to HSDS 3.0 organization, service, and location entities to support future upstream proposal and interoperability.

#### Scenario: HSDS-compatible export
- **WHEN** a platform admin sends GET `/api/v1/shelters/{id}?format=hsds`
- **THEN** the system returns the shelter data mapped to HSDS 3.0 JSON structure with organization, service, and location objects

#### Scenario: Internal model extends HSDS
- **WHEN** a shelter is stored with FABT-specific fields (ShelterConstraints, capacity by population type)
- **THEN** the HSDS export includes these as extension fields under a `fabt:` namespace prefix
- **AND** the core HSDS fields (name, description, url, phones, addresses) are in standard HSDS locations

### Requirement: shelter-assignment
The system SHALL support assigning coordinators to specific shelters, restricting their update access to assigned shelters only.

#### Scenario: Coordinator assigned to shelter
- **WHEN** a CoC admin sends POST `/api/v1/shelters/{id}/coordinators` with a user ID
- **THEN** the coordinator is assigned to that shelter and can update its profile and availability

#### Scenario: Coordinator cannot update unassigned shelter
- **WHEN** a coordinator sends PUT `/api/v1/shelters/{id}` for a shelter they are not assigned to
- **THEN** the system returns 403 Forbidden
