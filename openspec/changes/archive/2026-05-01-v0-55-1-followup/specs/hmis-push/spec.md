## ADDED Requirements

### Requirement: Hold-attribution PII absence enforced by automated contract test

An automated backend integration test SHALL assert that `OutboxRecord` rows for `HMIS_BED_INVENTORY_PUSH` events contain NO trace of the 3 hold-attribution PII columns (`held_for_client_name_encrypted`, `held_for_client_dob_encrypted`, `held_for_client_notes_encrypted`), regardless of the tenant `tenant.config.features.reentryMode` flag value. The test MUST run with both `reentryMode = true` and `reentryMode = false` and assert the same absence in both states (e.g., via parameterized `@ValueSource`).

The assertion MUST be thorough (per warroom B2 + Q4 = thorough): the column is absent from the projection schema entirely, OR — if the column is present in the schema for compatibility reasons — its value is null AND not coerced to empty string AND not coerced to any blank-equivalent placeholder. The test MUST read the raw DB row directly via `JdbcTemplate` (not through any DTO that might null-coerce blank values) to make this distinction observable.

The test asserts column-level absence at the projection layer (the JOIN that constructs the OutboxRecord from `reservation`), NOT payload-level absence after JSON serialization, because the projection layer is the single point where the fields are either included or excluded. Payload-level assertions would be downstream of the actual gate and would be brittle to Jackson configuration changes.

#### Scenario: HMIS push outbox excludes hold-attribution PII when reentryMode is true

- **GIVEN** a tenant with `tenant.config.features.reentryMode = true` and an active hold attributed to a named client (with all 3 hold-attribution PII columns populated to non-null encrypted values on the `reservation` row)
- **WHEN** the HMIS push pipeline produces an `OutboxRecord` for the `HMIS_BED_INVENTORY_PUSH` event referencing that hold's shelter
- **THEN** reading the OutboxRecord row directly via `JdbcTemplate`:
  - The 3 hold-attribution PII columns are EITHER absent from the OutboxRecord projection schema entirely, OR present with a strictly null value
  - The 3 columns are NOT empty string (`""`)
  - The 3 columns are NOT any other blank-equivalent placeholder (single space, zero-byte string, etc.)
- **AND** the test class explicitly logs which form of absence (schema-absent vs null-valued) it observed, so a future regression that flips between forms is detectable

#### Scenario: HMIS push outbox excludes hold-attribution PII when reentryMode is false

- **GIVEN** a tenant with `tenant.config.features.reentryMode = false` and an active hold (in this state, hold-attribution PII is not collected via the API serialization gate, but the test seeds it directly on the `reservation` row to prove the projection layer's gate works regardless of API-layer behavior)
- **WHEN** the HMIS push pipeline produces an `OutboxRecord` for the same shelter
- **THEN** reading the OutboxRecord row directly via `JdbcTemplate`:
  - The 3 columns satisfy the same thorough absence assertion as the `reentryMode = true` case
- **AND** the assertion form (schema-absent vs null-valued) is the same in both branches (the gate is unconditional regardless of the flag)

#### Scenario: Test scope is the canonical projection layer, not tenant-specific adapters

- **WHEN** the test is read for scope clarity
- **THEN** the test class Javadoc explicitly documents that the assertion covers the canonical `hmis-push` projection layer
- **AND** the Javadoc notes that tenant-specific custom adapters (per `hmis-vendor-adapters` capability) are out of scope and would be tested separately if introduced

#### Scenario: Test reads raw DB row, not coerced DTO

- **WHEN** the test queries the OutboxRecord
- **THEN** it uses `JdbcTemplate.queryForMap` (or equivalent raw-row API) to inspect column presence + value
- **AND** the test does NOT route the query through a Java DTO with `@JsonInclude(Include.NON_NULL)`, `@JsonProperty(defaultValue = "")`, or any other coercion that could mask a present-but-blank value
- **AND** if the OutboxRecord schema does not include the 3 columns at all, the test confirms this via column-list inspection (e.g., querying `information_schema.columns` for the OutboxRecord table) rather than relying on the absence of a key in a Map (which is ambiguous between "absent from schema" and "null in row")
