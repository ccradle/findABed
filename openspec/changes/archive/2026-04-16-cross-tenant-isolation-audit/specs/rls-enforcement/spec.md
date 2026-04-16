## ADDED Requirements

### Requirement: rls-policy-semantic-accuracy
Every RLS policy comment, Javadoc reference to RLS, and developer-facing documentation SHALL accurately describe what the policy enforces. Policy comments SHALL NOT claim tenant isolation unless the policy's `USING` / `WITH CHECK` clauses actually reference `app.tenant_id`. Where an existing policy comment in an applied migration makes a false claim (Flyway's immutability rule precludes edits to the original migration), a subsequent migration SHALL ship a `COMMENT ON POLICY` correction so `psql \d+` reflects the truth.

#### Scenario: referral_token policy comment correction via V56
- **GIVEN** V21 created policy `dv_referral_token_access` on `referral_token` with `USING (EXISTS (SELECT 1 FROM shelter s WHERE s.id = referral_token.shelter_id))` — enforces shelter existence only, NOT tenant
- **AND** the service layer's v0.39 `findByIdAndTenantId` fix is the actual tenant guard
- **WHEN** migration V56 runs `COMMENT ON POLICY dv_referral_token_access ON referral_token IS 'Enforces dv_access inheritance through the shelter FK join. Does NOT enforce tenant isolation — tenant is enforced at the service layer via findByIdAndTenantId. See openspec/changes/cross-tenant-isolation-audit for rationale.'`
- **THEN** `psql \d+ referral_token` output includes the corrected comment
- **AND** the prior (misleading) comment from V21 is overwritten (Postgres `COMMENT ON` is last-write-wins)

#### Scenario: Javadoc audit removes false RLS claims
- **GIVEN** any `*Service.java` or `*Repository.java` contains a comment asserting "RLS enforces tenant" or equivalent
- **WHEN** the Javadoc audit runs as part of this change
- **THEN** every such comment is either corrected (if the service actually has a tenant guard the comment can point to) or removed (if the comment is historically inaccurate)
- **AND** a short note in `docs/security/rls-coverage.md` references the V21/V56 case as the canonical example of why these comments get audited

### Requirement: rls-coverage-map
The project SHALL maintain an authoritative table-by-table map of RLS coverage at `docs/security/rls-coverage.md`. The map SHALL list every tenant-owned table in the schema, its RLS status (enforced / not enforced), what the policy actually enforces when present (`dv_access`, `shelter_id` membership, etc.), and the corresponding service-layer guard method name. The map SHALL be updated whenever a new tenant-owned table is added to the schema.

#### Scenario: RLS coverage map exists and is complete
- **GIVEN** the full list of tenant-owned tables in the current schema
- **WHEN** `docs/security/rls-coverage.md` is reviewed
- **THEN** every table appears as a row
- **AND** each row names: table name, RLS-enabled flag, policy name if any, what the policy enforces, service-layer guard method, test that pins cross-tenant behavior

#### Scenario: Adding a new tenant-owned table requires updating the map
- **WHEN** a future migration adds a new tenant-owned table (e.g. `intake_form`)
- **THEN** the PR adding the migration includes an update to `docs/security/rls-coverage.md` adding a row for the new table
- **AND** CI or a checklist item flags the PR if the map was not updated
