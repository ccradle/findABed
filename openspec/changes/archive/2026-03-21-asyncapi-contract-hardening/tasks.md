## 1. DV Security Annotations

- [x] 1.1 Add `x-security` extension block to all six channel definitions (availabilityUpdated, reservationCreated, reservationConfirmed, reservationCancelled, reservationExpired, surgeActivated) documenting DV_REFERRAL role requirement for DV_SURVIVOR events
- [x] 1.2 Add inline `description` on the `DV_SURVIVOR` enum value in `AvailabilityUpdatedPayload.population_type` referencing DV_REFERRAL role
- [x] 1.3 Add inline `description` on the `DV_SURVIVOR` enum value in `ReservationPayload.population_type` referencing DV_REFERRAL role
- [x] 1.4 Add Full-tier Kafka ACL requirement note to `info.description` block

## 2. Surge Payload Enrichment

- [x] 2.1 Add `affected_shelter_count` optional nullable integer field to `SurgeActivatedPayload` with description
- [x] 2.2 Add `estimated_overflow_beds` optional nullable integer field to `SurgeActivatedPayload` with description
- [x] 2.3 Verify neither field is added to the `required` array
- [x] 2.4 Verify `SurgeDeactivatedPayload` is unchanged

## 3. Validation

- [x] 3.1 Validate AsyncAPI 3.0 compliance of the modified YAML (no syntax errors, valid x- extensions)
- [x] 3.2 Verify zero breaking changes — all existing fields, types, required arrays, and channel addresses preserved
