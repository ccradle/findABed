## MODIFIED Requirements

### Requirement: dv-event-security-annotation
The AsyncAPI contract SHALL annotate all event channels with `x-security` extension blocks documenting that events containing `population_type: DV_SURVIVOR` require `DV_REFERRAL` authorization at the consumer level. The `DV_SURVIVOR` enum value in both `AvailabilityUpdatedPayload` and `ReservationPayload` SHALL include an inline description referencing the role requirement. The `info.description` block SHALL note that Full-tier Kafka deployments MUST configure topic ACLs before enabling the Full Spring profile.

#### Scenario: x-security extension on all channels
- **WHEN** a developer reads the AsyncAPI contract
- **THEN** all six channel definitions (availabilityUpdated, reservationCreated, reservationConfirmed, reservationCancelled, reservationExpired, surgeActivated) include an `x-security` extension block
- **AND** the extension states that DV_SURVIVOR events require DV_REFERRAL authorization

#### Scenario: DV_SURVIVOR enum inline description
- **WHEN** a developer reads the population_type enum in AvailabilityUpdatedPayload or ReservationPayload
- **THEN** the DV_SURVIVOR value has a description stating: "Protected by DV_REFERRAL role — consumers MUST verify authorization before processing events with this population type"

#### Scenario: Kafka ACL requirement in info block
- **WHEN** a developer reads the info.description of the AsyncAPI contract
- **THEN** a clear statement indicates that Full-tier Kafka deployments MUST configure topic ACLs restricting DV_SURVIVOR event consumption to DV_REFERRAL-authorized service accounts

#### Scenario: Zero breaking changes
- **WHEN** the annotations are applied
- **THEN** all existing field names, types, required arrays, and channel addresses are preserved exactly
- **AND** the contract remains valid AsyncAPI 3.0

### Requirement: surge-payload-enrichment
The `SurgeActivatedPayload` SHALL include two new optional nullable integer fields: `affected_shelter_count` (number of shelters in scope of the surge) and `estimated_overflow_beds` (sum of overflow capacity at activation time). Neither field appears in the `required` array. Descriptions explicitly state that null is valid and consumers must handle null gracefully. `SurgeDeactivatedPayload` is unchanged.

#### Scenario: affected_shelter_count field present
- **WHEN** a surge.activated event is published
- **THEN** the payload includes `affected_shelter_count` (integer or null)
- **AND** when null, consumers understand the count could not be determined at activation time

#### Scenario: estimated_overflow_beds field present
- **WHEN** a surge.activated event is published
- **THEN** the payload includes `estimated_overflow_beds` (integer or null)
- **AND** the description states this is a point-in-time snapshot, not a live value

#### Scenario: SurgeDeactivatedPayload unchanged
- **WHEN** the contract is updated
- **THEN** SurgeDeactivatedPayload has no new fields
