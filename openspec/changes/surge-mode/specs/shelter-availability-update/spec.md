## MODIFIED Requirements

### Requirement: availability-snapshot-create
The availability update request now accepts an optional `overflowBeds` field for temporary surge capacity. The `bed_availability` table gains an `overflow_beds` column.

#### Scenario: Availability update with overflow beds
- **WHEN** a coordinator sends PATCH `/api/v1/shelters/{id}/availability` with `overflowBeds: 15`
- **THEN** the snapshot is created with `overflow_beds = 15`
- **AND** the `availability.updated` event payload includes `overflow_beds`
