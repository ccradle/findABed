## ADDED Requirements

### Requirement: eligibility-criteria-storage
The system SHALL store structured eligibility criteria per shelter in an `eligibility_criteria` JSONB column on the `shelter_constraints` table. The column is nullable; absence means no structured criteria have been entered. A GIN index SHALL be present on this column.

The JSONB schema:
```json
{
  "criminal_record_policy": {
    "accepts_felonies": true,
    "excluded_offense_types": ["SEX_OFFENSE", "ARSON"],
    "individualized_assessment": false,
    "vawa_protections_apply": false,
    "notes": "string (max 500 chars)"
  },
  "program_requirements": ["string"],
  "documentation_required": ["string"],
  "intake_hours": "string",
  "custom_tags": ["string"]
}
```

Controlled vocabulary for `excluded_offense_types`: `SEX_OFFENSE`, `ARSON`, `DRUG_MANUFACTURING`, `VIOLENT_FELONY`, `PENDING_CHARGES`, `OPEN_WARRANTS`. Additional values may appear in `custom_tags`; the controlled list is used for filtering.

The `individualized_assessment` boolean is stored and surfaced as contextual display information only. In Phase 1, it does NOT affect search filtering — shelters with `individualized_assessment: true` are treated identically to others when evaluating the `acceptsFelonies` filter.

#### Scenario: Eligibility criteria persisted via shelter PATCH
- **WHEN** a COC_ADMIN sends PATCH `/api/v1/shelters/{id}` with a valid `eligibility_criteria` object
- **THEN** the object is stored in the `eligibility_criteria` JSONB column on `shelter_constraints`
- **AND** the response includes the stored `eligibility_criteria` in the shelter detail

#### Scenario: Partial update preserves unmentioned top-level JSONB keys
- **WHEN** a COC_ADMIN sends PATCH `/api/v1/shelters/{id}` with only `eligibility_criteria.criminal_record_policy`
- **THEN** the existing `program_requirements`, `documentation_required`, `intake_hours`, and `custom_tags` top-level keys are preserved
- **AND** only the `criminal_record_policy` top-level key is replaced in its entirety
- **AND** top-level keys absent from the request body are not modified

#### Scenario: Null eligibility_criteria is valid
- **WHEN** a shelter has no `eligibility_criteria` populated
- **THEN** search results show the shelter with `eligibilityData: null`
- **AND** the shelter's `requires_verification_call` flag (if true) is still surfaced

#### Scenario: Invalid offense type value rejected
- **WHEN** a COC_ADMIN sends `excluded_offense_types: ["INVALID_VALUE"]`
- **THEN** the response is 400 Bad Request listing valid controlled vocabulary values

### Requirement: accepts-felonies-filter
The bed search endpoint SHALL accept an optional `acceptsFelonies` filter. When `true`, only shelters where `eligibility_criteria.criminal_record_policy.accepts_felonies = true` are returned. When absent, no filtering on this field occurs. `acceptsFelonies=false` is not a supported query value — the endpoint returns 400 Bad Request if supplied.

#### Scenario: acceptsFelonies=true returns only felony-accepting shelters
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?acceptsFelonies=true`
- **THEN** only shelters with `criminal_record_policy.accepts_felonies = true` in their eligibility criteria are returned
- **AND** shelters with null `eligibility_criteria` are excluded (unknown policy)

#### Scenario: acceptsFelonies=false returns 400 Bad Request
- **WHEN** an outreach worker calls GET `/api/v1/beds/search?acceptsFelonies=false`
- **THEN** the response is 400 Bad Request
- **AND** the error message indicates that `acceptsFelonies=false` is not a valid query value

#### Scenario: acceptsFelonies filter and requires_verification_call can both be true simultaneously
- **WHEN** a shelter has `accepts_felonies = true` AND `requires_verification_call = true`
- **AND** an outreach worker calls GET `/api/v1/beds/search?acceptsFelonies=true`
- **THEN** the shelter is included in results
- **AND** the response for that shelter includes both `acceptsFelonies: true` and `requiresVerificationCall: true`
- **AND** the `CriminalRecordPolicyDisclaimer` component is rendered on the shelter card

#### Scenario: Cross-tenant isolation — eligibility criteria not accessible across tenants
- **WHEN** Tenant A's shelter has eligibility_criteria populated
- **AND** Tenant B's outreach worker calls GET `/api/v1/beds/search`
- **THEN** Tenant B's response contains no shelters or eligibility data from Tenant A

### Requirement: criminal-record-policy-disclaimer
The system SHALL render a `CriminalRecordPolicyDisclaimer` component wherever criminal record policy fields are displayed. The disclaimer is non-dismissable. It SHALL use `role="note"` ARIA attribute and be present in the screen reader reading order immediately after the policy data it annotates.

Disclaimer text (i18n key `shelter.criminalRecordPolicyDisclaimer`): "Criminal record acceptance policies are self-reported by shelters. Verify directly with the shelter before assuming eligibility."

When `vawa_protections_apply = true`: additionally render `shelter.vawaNoteDisclaimer`: "This shelter may be required to accept individuals whose criminal record is related to domestic violence they experienced. Confirm with the shelter coordinator."

Note: Final EN and ES i18n strings for both keys require legal review (Casey Drummond) before merge.

#### Scenario: Disclaimer renders when criminal record fields are shown in search results
- **WHEN** an outreach worker views a shelter card with `criminal_record_policy` data populated
- **THEN** the `CriminalRecordPolicyDisclaimer` appears adjacent to the policy data
- **AND** it is not dismissable (no close button)
- **AND** a screen reader announces it after the policy fields

#### Scenario: Disclaimer renders in shelter detail view
- **WHEN** any user views a shelter detail page with `criminal_record_policy` populated
- **THEN** the disclaimer is visible

#### Scenario: Disclaimer renders in shelter edit form
- **WHEN** a COC_ADMIN views the eligibility criteria section of the shelter edit form
- **THEN** the disclaimer is visible and not dismissable

#### Scenario: Disclaimer absent when no criminal record fields displayed
- **WHEN** a shelter card shows availability and basic info with no `criminal_record_policy` data
- **THEN** no disclaimer component is rendered

#### Scenario: VAWA note renders when vawa_protections_apply is true
- **WHEN** a shelter has `eligibility_criteria.criminal_record_policy.vawa_protections_apply = true`
- **AND** the criminal record policy section is displayed
- **THEN** both the base disclaimer and the VAWA note are rendered

### Requirement: eligibility-criteria-edit-ui
The admin shelter edit form SHALL expose an eligibility criteria editor as a structured guided form, not a raw JSON editor. Criminal record policy fields are surfaced as purpose-labeled controls. Coordinators and COC_ADMINs who cannot fill in a field SHALL see it as optional — the form must not suggest non-entry is a failure.

#### Scenario: Criminal record policy fields render as form controls
- **WHEN** a COC_ADMIN opens the shelter edit form for any shelter type
- **THEN** a "Eligibility Criteria" section is visible
- **AND** "Accepts individuals with felony convictions" renders as a labeled toggle (not labeled "accepts_felonies")
- **AND** "Offense types excluded from eligibility" renders as a multi-select from the controlled vocabulary
- **AND** each vocabulary value has a localized display label

#### Scenario: All eligibility criteria fields are clearly optional
- **WHEN** a coordinator views the eligibility criteria section
- **THEN** each field is labeled "Optional" or equivalent
- **AND** an unfilled section shows "Not specified" in read-only views, not an empty field or error state

#### Scenario: Coordinator cannot see criminal record policy fields
- **WHEN** a COORDINATOR (non-admin) opens the shelter edit form
- **THEN** criminal record policy fields are not visible (read-only or absent — per existing coordinator edit restriction pattern)

#### Scenario: CI guard prevents criminal_record_policy display without disclaimer
- **WHEN** CI runs the JSX disclaimer guard job
- **THEN** any JSX/TSX file that contains a prop reference to `criminal_record_policy`, `accepts_felonies`, or `excluded_offense_types` AND does NOT contain `<CriminalRecordPolicyDisclaimer` in the same file causes the CI job to fail
- **AND** the guard matches on exact string tokens (not substring) to avoid false positives from comments or unrelated prop names
