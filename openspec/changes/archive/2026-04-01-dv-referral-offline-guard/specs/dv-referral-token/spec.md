## MODIFIED Requirements

### Requirement: DV referrals intentionally not queued offline

DV referral requests SHALL NOT be queued in the offline IndexedDB queue. This is an intentional security decision, not a missing feature.

#### Rationale
- DV referrals contain sensitive operational data: callback number, household size, urgency, special needs
- IndexedDB is unencrypted browser storage on the worker's device
- A lost, seized, or shared device could expose this data — potential VAWA/FVPSA confidentiality violation
- The zero-PII design depends on data living on the server briefly and being hard-deleted within 24 hours
- Persisting referral data on-device in IndexedDB undermines this threat model
- No DV service platform in the sector has an offline referral workflow (NNEDV Safety Net confirms this gap)

#### Scenario: Offline queue does not accept referral actions
- **GIVEN** the offline queue accepts HOLD_BED and UPDATE_AVAILABILITY action types
- **THEN** no REFERRAL_REQUEST action type exists in the queue
- **AND** this is documented in FOR-COORDINATORS.md and training materials
