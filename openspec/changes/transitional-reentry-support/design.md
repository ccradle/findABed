## Context

FABT's shelter model currently treats all non-DV shelters as undifferentiated emergency shelters with five boolean constraints. Two practitioner categories — reentry housing navigators and call-center placement navigators — cannot use the platform without additional structured eligibility data that today only exists in shelter staff's heads, discovered by phone call.

The current state:
- `shelter_constraints` table: `requires_sobriety`, `requires_referral`, `requires_id`, `allows_pets`, `wheelchair_accessible` — five booleans, no extensibility
- No shelter type taxonomy beyond the `dvShelter` boolean
- No county field; no supervision geography filtering
- Hold model: `reservation` table with no third-party attribution; `held_for_client_name`/`held_for_client_dob`/`hold_notes` absent
- `holdDurationMinutes` in `tenant.config` JSONB has no admin UI

National context (research-grounded): CSG 2023 found <5% of DOCs use dedicated technology for housing needs assessment; no platform nationally combines real-time bed availability + criminal record policy filtering + supervision geography matching. The criminal record policy data gap is documented — HSDS 3.0 explicitly defers to implementers; HMIS 2024 standards include no standardized field. The proposed offense-type vocabulary is grounded in documented national patterns (Prison Policy Initiative, Root & Rebound, GA THOR, OACRA).

**Warroom contributors:** Alex Chen, Elena Vasquez, Marcus Webb, Riley Cho, Keisha Thompson, Tomás Herrera, Casey Drummond, Sam Okafor, Demetrius Holloway (primary design subject), Dr. Yemi Okafor.

## Goals / Non-Goals

**Goals:**
- Enable bed search filtering by shelter type, county, and criminal record acceptance policy
- Provide structured, extensible eligibility criteria per shelter with a guided editing UI
- Support third-party navigator hold attribution with dignified labeling and 24h PII purge
- Expose hold duration configuration in the admin panel
- Render a non-dismissable, accessible policy disclaimer on all criminal record field displays
- Maintain full backward compatibility — all existing workflows unaffected

**Non-Goals:**
- Integration with NC DAC supervision data for automated boundary enforcement (deferred; county filter is the practical MVP)
- A distinct NAVIGATOR role with separate permissions (deferred to Phase E per-tenant role configuration)
- Waitlist management or intake pipeline tracking
- HUD VAWA compliance extensions for DV-involved reentry clients beyond the `vawa_protections_apply` boolean
- Per-shelter-type availability semantics (program slots behave identically to beds in the data model)
- Hold extension request mechanism (navigator-requested one-time extension)
- Client profile or case management
- Pre-release reservation model (longer-horizon soft commitment before release date; out of scope for initial phase)
- HMIS CSV 7.0 export adapter (needs dedicated scoping; 2–3 day estimate in the source brief is not defensible per Kenji Watanabe warroom review)

## Decisions

### D1 — JSONB Schema for `eligibility_criteria`

**Decision:** `eligibility_criteria` JSONB on `shelter_constraints` with the following schema:

```json
{
  "criminal_record_policy": {
    "accepts_felonies": true,
    "excluded_offense_types": ["SEX_OFFENSE", "ARSON"],
    "individualized_assessment": false,
    "vawa_protections_apply": false,
    "notes": "string"
  },
  "program_requirements": ["string"],
  "documentation_required": ["string"],
  "intake_hours": "string",
  "custom_tags": ["string"]
}
```

**Rationale:** Sub-object pattern lets the schema evolve without migrations. The `criminal_record_policy` sub-object is the primary reentry use case; `program_requirements`/`documentation_required`/`intake_hours` serve the transitional housing navigator use case. All keys nullable/optional.

**`vawa_protections_apply` boolean:** HUD VAWA rules require CoC-funded programs to accept DV survivors whose criminal records are related to the violence they experienced — a shelter that categorically excludes violent offenses may still be required to accept VAWA-protected individuals. This boolean flags that nuance without the platform making legal determinations. Disclaimer text must mention it when `vawa_protections_apply = true`. *(Casey Drummond warroom)*

**Alternatives considered:** Top-level columns for each policy field — rejected: each new offense category or program requirement type would require a migration. Current pattern scales without schema changes.

**Warroom input (Alex Chen):** `requires_verification_call` remains a top-level column on `shelter` (V94), not in the JSONB. The sentinel must be queryable without JSONB extraction for the search UI "call to verify" indicator.

**`acceptsFelonies` filter behavior with the `requires_verification_call` sentinel (H1 warroom 2026-04-28):** A naïve "exclude null-eligibility shelters" rule for `acceptsFelonies=true` defeats the design's mitigation strategy (line 169 risk: most shelters launch with null eligibility; sentinel keeps them visible to navigators). The actual filter semantics:

- `eligibility_criteria.criminal_record_policy.accepts_felonies = false` (explicit) → **EXCLUDE** from `acceptsFelonies=true` results.
- `eligibility_criteria.criminal_record_policy.accepts_felonies = true` (explicit) → **INCLUDE**.
- `eligibility_criteria` is null OR `criminal_record_policy` is null OR `accepts_felonies` is null → **INCLUDE if `requires_verification_call = true` on the shelter** (annotated with the "call to verify" badge in the UI); **EXCLUDE otherwise** (no policy data and no sentinel = treated as unknown-and-not-flagged).

This three-way logic is what task 4.2 must implement (and tasks/spec test 13.4 must cover all three branches). Backend SQL pattern: `(eligibility_criteria->'criminal_record_policy'->>'accepts_felonies')::boolean = TRUE OR (eligibility_criteria IS NULL AND requires_verification_call = TRUE)`.

### D2 — Shelter Type Taxonomy

**Decision:** Controlled enum for `shelter_type` VARCHAR(50) with values:
`EMERGENCY`, `DV`, `TRANSITIONAL`, `SUBSTANCE_USE_TREATMENT`, `MENTAL_HEALTH_TREATMENT`, `REENTRY_TRANSITIONAL`, `PERMANENT_SUPPORTIVE`, `RAPID_REHOUSING`

V91 migration: DEFAULT `'EMERGENCY'`; backfill `dvShelter = true` rows to `shelter_type = 'DV'`. DB check constraint: `CHECK (dvShelter = FALSE OR shelter_type = 'DV')` — enforces at the database layer that these two representations of DV status cannot diverge. *(Alex Chen warroom — critical)*

**Rationale:** `dvShelter` boolean is retained as-is; it is load-bearing for RLS policies (V68) and DV access control. `shelter_type` is a display/filter taxonomy. These serve different purposes and must not be conflated. The check constraint is the last line of defense against divergence.

**`shelter_type` carries no implied compliance status** — it is a classification for filtering. A REENTRY_TRANSITIONAL shelter is one that self-classifies as such; the platform does not certify program eligibility or compliance with any regulation.

**Alternatives considered:** Sub-type field separate from the DV boolean — accepted in this exact form. Removing the DV boolean — rejected: would require RLS policy rewrite, high risk, no benefit.

### D3 — County Field Approach

**Decision (revised 2026-04-28 — H2 warroom):** Store county as `VARCHAR(100)` on `shelter`, indexed. Validate values against `tenant.config.active_counties: string[]` at the application layer; do **NOT** create a DB-level enum or check constraint listing specific counties. The NC 100-county list is seeded as the *default* `active_counties` config row at tenant creation time, but lives entirely in `tenant.config` JSONB — not in DDL. Deployments outside NC override the seed by setting their own `active_counties` list.

**Supervision geography is jurisdictional, not distance-based.** *(Research finding, warroom:* Demetrius Holloway*.)* The question a reentry navigator needs answered is: "Does this shelter fall within the supervision district where this person's supervising officer has jurisdiction?" A shelter 2 miles away in the wrong county is a supervision violation; a shelter 40 miles away in the right county is valid. The county field implements the jurisdictional boundary check, not geographic proximity.

**Rationale:** Free text was considered and rejected — "Johnston County" vs "johnston county" vs "Johnston" creates unmatchable data. Application-layer validation against the per-tenant config list gives the same data-quality guarantee as a DB enum without forcing future migrations when a non-NC tenant onboards. The earlier draft of D3 ("FABT-wide NC 100-county enum is acceptable") was contradictory ("FABT-wide" vs single-state) and would have required a schema-touch migration to add a state.

**Who sets `tenant.config.active_counties`? (B3 warroom 2026-04-28 — Phase G now shipped, Open Question #3 resolved):** **PLATFORM_OPERATOR** sets it at tenant creation time, via the platform-operator UI lifecycle endpoints (Phase G G-4.6 + F11). It is deployment-scope configuration — analogous to how `tenant.dvAccess` and other deployment-shaped settings flow from PLATFORM_OPERATOR authority. COC_ADMIN can READ the list (to populate the county dropdown in their shelter edit form) but cannot mutate it. Rationale: changing the active counties list mid-tenant invalidates existing shelter county values; this is a platform-operator-grade decision, not in-tenant operational configuration. Confirmed via Phase G role split shipped in v0.53.

**Default seed:** at tenant creation, `tenant.config.active_counties` defaults to the NC 100-county list (constant in `org.fabt.shelter.county.NcCountyDefaults`). PLATFORM_OPERATOR can override pre- or post-creation. If the operator explicitly sets `active_counties = []`, county validation is disabled (free-text accepted) — useful for non-pilot deployments still gathering their canonical list.

### D4 — Third-Party Hold Attribution PII Lifecycle

**Decision (revised 2026-04-24 — warroom pass-2 Marcus):** `held_for_client_name_encrypted` TEXT, `held_for_client_dob_encrypted` TEXT, `hold_notes_encrypted` TEXT — all nullable, all storing the v1 `EncryptionEnvelope` as base64. Fields are encrypted via `SecretEncryptionService.encryptForTenant(tenantId, KeyPurpose.RESERVATION_PII, plaintext)` on write and decrypted on read. The V93 migration bundles the `tenant_dek.purpose` CHECK-constraint update (add `RESERVATION_PII` to the allowed set) alongside the `ALTER TABLE reservation` column adds. See design Open Question #5 resolution + issue #152.

**Two-layer posture (defense in depth):**
1. **At-rest ciphertext via `tenant_dek`.** A pg_dump captured at any time exports ciphertext unreadable without master_KEK + the `tenant_dek` row. Survives backup-retention windows; inherits crypto-shred via tenant CASCADE on hardDelete.
2. **24h purge via Spring Batch.** Cleanup job extended to null all three `_encrypted` fields on reservation records where `expires_at < NOW() - INTERVAL '24 hours'` OR `status IN ('CANCELLED', 'CONFIRMED', 'CANCELLED_SHELTER_DEACTIVATED', 'EXPIRED') AND updated_at < NOW() - INTERVAL '24 hours'`. Purge applies to the ciphertext columns (not the plaintext, which was never persisted).

`hold_notes_encrypted` is explicitly in scope for both layers. Navigator hold notes may include names and contact information of supervision officers. *(Casey Drummond warroom)* Operator documentation must state: hold notes are not a permanent record; they are purged 24h after hold resolution regardless of their ciphertext durability.

**UI labeling:** Fields must use purpose-clear, dignity-centered labels. `held_for_client_name` → "Who is this hold for?" with sub-label "Name (for shelter check-in)". `held_for_client_dob` → "Date of birth (for shelter to confirm arrival)". `hold_notes` → "Note for shelter coordinator". Labels reviewed against dignity-centered language standards. *(Keisha Thompson warroom)*

**Deployment order:** Spring Batch job extension must be deployed in the same release as V93 migration or later — never before. The job code must be null-safe on pre-V93 databases.

### D5 — Hold Duration Configuration Semantics

**Decision:** Hold duration change applies to **new holds only**. In-flight holds (already created, not yet expired/resolved) retain their `expires_at` as set at creation time. *(Riley Cho warroom: must be explicitly specified and tested.)*

Admin panel range: 30–480 minutes. Default: 90 minutes. Reentry deployments configure 180–240 minutes. Hospital discharge deployments: 180+ minutes. The range covers both use cases without separate per-use-case configuration.

`ReservationSettings` admin panel component already exists as a stub (`admin/components/ReservationSettings`). Wire to `tenant.config.holdDurationMinutes`. Endpoint: `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration`, COC_ADMIN+ role.

**Endpoint security posture (M2 + H4 warroom 2026-04-28):**

- **Role**: COC_ADMIN (in-tenant operational config) — NOT `@PlatformAdminOnly`. Therefore the Phase G `JustificationValidationFilter` (which gates `@PlatformAdminOnly` endpoints behind `X-Platform-Justification` header) does **NOT** apply. Audit logging follows the standard `AuditEventType.TENANT_CONFIG_UPDATED` path, not the per-action `PlatformAdminAccessLog` chain.
- **Demo-mode behavior**: `DemoGuardFilter.ALLOWED_MUTATIONS` (Spring backend filter, `@Profile("demo")`) does NOT include this endpoint, by design. In the demo, attempts return 403 with body `{"error":"demo_restricted",...}`. A dedicated branch in `DemoGuardFilter.getBlockMessage()` MUST be added matching the `/api/v1/admin/tenants/*/hold-duration` path: `"Hold duration changes are disabled in the demo environment — would affect other visitors' reservation flow."` Without the dedicated branch, the operator hits the generic `/api/v1/tenants/...` block message ("Tenant management is disabled..."), which is misleading because this is reservation config, not tenant lifecycle.

### D6 — Criminal Record Policy Disclaimer

**Decision:** `CriminalRecordPolicyDisclaimer` React component. Non-dismissable. Rendered adjacent to any display of `criminal_record_policy` fields (search results, shelter detail, shelter edit form).

ARIA: `role="note"`. Visible at all zoom levels including 400%. Visible in dark mode with passing contrast. Included in screen reader reading order immediately after the data it annotates. *(Tomás Herrera warroom)*

i18n key `shelter.criminalRecordPolicyDisclaimer` in both EN and ES locales. When `vawa_protections_apply = true` on the shelter, the disclaimer additionally reads the `shelter.vawaNoteDisclaimer` key (NB: name corrected from earlier draft `vawa_protections_apply_note` — that is the form-level admin-facing key per i18n-legal-review-strings.md). *(Casey Drummond warroom: legal-reviewed strings landed pre-implementation 2026-04-28 — see `i18n-legal-review-strings.md` in this change directory. Task 15.6 retained as final pre-merge sign-off.)*

**VAWA + categorical-exclusion interaction (H5 warroom 2026-04-28):** A shelter with `excluded_offense_types = ['VIOLENT_FELONY']` AND `vawa_protections_apply = true` is making a legally complex statement. The disclaimer text MUST flag this nuance to navigators — VAWA protections may override categorical exclusions for survivors whose record relates to the violence they experienced. The Casey-reviewed `shelter.vawaNoteDisclaimer` string covers this requirement; do not paraphrase "may apply" to "applies" or "do apply" when implementing.

**Platform neutrality:** FABT represents what shelter programs actually do, not what they should do. The 2024 HUD proposed rule limiting criminal record screening was withdrawn January 2025; the current federal policy direction emphasizes owner discretion. The platform neither endorses nor normalizes any particular exclusion policy — it makes existing policies transparent to navigators who need the information.

### D7 — NAVIGATOR Role

**Decision:** Deferred. OUTREACH_WORKER is the correct role for reentry navigators in the current model. Third-party hold attribution fields are available to any OUTREACH_WORKER. A distinct NAVIGATOR role with different permissions (extended hold duration, supervision notes) is deferred to Phase E when per-tenant role configuration is built.

**Rationale:** Role proliferation at this stage creates complexity without payoff. The functional requirements (longer holds, hold notes) are satisfied through configuration and field availability rather than role-based access differences.

### D8 — Supervision Geography Enforcement

**Decision:** County filter only for initial phase. No DAC integration attempt. The platform shows shelter county; the navigator applies their supervision boundary knowledge. Documented limitation: the county filter helps navigators pre-screen for likely-compliant shelters; it does not replace the home plan approval process. This limitation is documented in the runbook and training materials.

### D9 — GIN Index on `eligibility_criteria` JSONB

**Decision:** V92 migration includes `CREATE INDEX CONCURRENTLY idx_shelter_constraints_eligibility ON shelter_constraints USING GIN (eligibility_criteria)`. *(Elena Vasquez warroom — critical for query performance at pilot scale.)*

**Flyway note:** `CREATE INDEX CONCURRENTLY` must run outside an explicit transaction block in Flyway. Use `mixed = true` or a separate non-transactional migration step. This is documented precedent in this codebase — follow existing concurrent index migration pattern.

**Rationale:** The `accepts_felonies` filter in `BedSearchService` queries `eligibility_criteria->'criminal_record_policy'->>'accepts_felonies'`. Without a GIN index, this is a sequential scan on every bed search request. At demo scale (dozens of shelters) this is imperceptible; at deployment scale (hundreds of providers) it will impact the navigator use case.

### D10 — `dvShelter` / `shelter_type` Sync

**Decision:** DB-level check constraint (`CHECK (dvShelter = FALSE OR shelter_type = 'DV')`) added in V91 migration. Application layer also enforces: any PUT/PATCH that sets `dvShelter = true` must set `shelter_type = 'DV'`; any that sets `shelter_type = 'DV'` must ensure `dvShelter = true`. *(Alex Chen warroom — "the database constraint is the last line of defense.")*

**Not a trigger:** A trigger that auto-syncs the two fields was considered and rejected. An auto-sync masks a programming error; a constraint surfaces it loudly.

### D11 — Offense Type Controlled Vocabulary

**Decision:** `excluded_offense_types` is `string[]` in JSONB but the UI presents a multi-select from a controlled vocabulary. Controlled values (research-grounded):

| Value | Basis |
|---|---|
| `SEX_OFFENSE` | Most common categorical exclusion nationally; driven by SORN proximity laws |
| `ARSON` | Second most common; frequently paired with sex offense in documented program policies |
| `DRUG_MANUFACTURING` | Federal statute: mandatory exclusion for meth production on federally subsidized premises |
| `VIOLENT_FELONY` | Variable; many programs use individualized assessment rather than categorical exclusion |
| `PENDING_CHARGES` | Used by some programs as separate admission criterion |
| `OPEN_WARRANTS` | Used by some programs; distinct from conviction-based exclusions |

`custom_tags: string[]` in the JSONB provides an escape valve for free-text program-specific labels. The controlled vocabulary covers documented national patterns; custom tags cover edge cases.

**Rationale:** Free-text `excluded_offense_types` would produce "violent crimes" vs "crimes of violence" — unmatchable. Controlled vocabulary enables reliable filtering. i18n keys required for each value.

### D12 — Mobile Search UX: Advanced Filters

**Decision:** `shelter_type`, `county`, and `accepts_felonies` filters are placed in a collapsible "Advanced Filters" section on `OutreachSearch.tsx`. On desktop: expanded by default. On mobile: collapsed by default. *(Tomás Herrera warroom: three new optional filters must not complicate the primary mobile bed-search flow for outreach workers like Darius.)*

The optional `/navigator` desktop route (call-center-optimized layout) expands these filters prominently and adds inline eligibility detail cards. Stretch goal for initial phase.

### D13 — `features.reentryMode` Tenant Flag Semantics (B5 warroom 2026-04-28)

**Decision:** `features.reentryMode` is a boolean key under `tenant.config.features` JSONB, default `false`. The flag gates **frontend visibility** of the new reentry surface; backend behavior is uniform across tenants.

**What the flag DOES:**

- Hides the `OutreachSearch.tsx` "Advanced Filters" section's three new filters (`shelterType`, `county`, `acceptsFelonies`) for tenants where `reentryMode = false`. Outreach workers in non-reentry tenants see no UI change vs v0.54.
- Hides the "Eligibility Criteria" section in the admin shelter edit form (per task 10.1) for tenants where `reentryMode = false`. The `requires_verification_call` toggle is also hidden.
- Hides the "Add client details (optional)" expansion in the hold creation dialog for tenants where `reentryMode = false`. The base hold dialog is unchanged.

**What the flag DOES NOT do:**

- Backend always accepts and persists the new fields regardless of the flag. Reasoning: a tenant flipping the flag from `false → true` should immediately see any eligibility data already entered by other-tenant admins or imported from external sources; a tenant flipping `true → false` should not silently drop data.
- Backend search filter parameters (`shelterType`, `county`, `acceptsFelonies`) are always honored. A non-reentry-mode tenant's API consumer sending `?acceptsFelonies=true` gets a correct response. Frontend is responsible for not surfacing the parameters in the UI.
- The `dvShelter` ↔ `shelter_type='DV'` constraint is uniform across all tenants (it's a DB-level check constraint per D10).

**Who sets the flag:** PLATFORM_OPERATOR, via the lifecycle endpoints shipped in Phase G G-4.6. Same authority as `tenant.config.active_counties` per D3.

**Rationale:** A flag-gated UI surface lets the reentry capability ship to all tenants in one release without forcing the rollout. Reentry tenants enable the flag; non-reentry tenants are unaffected. A backend-side flag would have introduced cross-tenant inconsistency in API behavior that's harder to reason about and test.

**What reads the flag:**

- `frontend/src/pages/OutreachSearch.tsx` — wraps the new advanced-filters section in `{tenantConfig.features?.reentryMode && (...)}`.
- `frontend/src/pages/admin/ShelterEditPage.tsx` — wraps the new eligibility-criteria section + `requires_verification_call` toggle in the same condition.
- `frontend/src/components/HoldCreationDialog.tsx` — wraps the "Add client details" expansion in the same condition.

The `tenantConfig.features` shape is fetched via the existing `useTenantConfig()` hook (Phase D ships this); no new endpoint required.

## Risks / Trade-offs

**[Data quality risk: criminal record policy fields will be empty for most shelters at launch]** → Mitigation: `requires_verification_call = true` is the default sentinel for any shelter where criminal record policy JSONB is not populated. Navigators see "call to verify" rather than silence. Documentation and training materials emphasize that the platform reduces calls, it does not replace verification.

**[JSONB filtering performance at scale]** → Mitigation: GIN index in V92 (D9). At demo scale, risk is zero. At deployment scale with the index, acceptable.

**[`dvShelter` / `shelter_type` divergence if migration backfill is wrong]** → Mitigation: DB check constraint (D10) will reject any row that diverges. Test V91 migration backfill explicitly: verify `dvShelter = true` rows all have `shelter_type = 'DV'` post-migration.

**[PII in hold notes purged before shelter coordinator records arrival]** → Trade-off accepted. The 24h window is the same as DV referral tokens. Shelters with longer intake processes should use their own intake system for records; the hold note is a transient coordination artifact, not a permanent record.

**[Evidence base for transitional housing is contested]** → Platform neutrality: FABT facilitates matching. The platform makes no outcome claims. Documentation avoids "transitional housing works" framing. See national research synthesis (Recidiviz 2024 Iowa natural experiment; NYC ETH observational data).

**[Federal policy on criminal record screening is in active flux]** → Platform neutrality: FABT represents actual shelter-reported policies. The 2024 HUD proposed rule (lookback period limits, individualized assessment requirements) was withdrawn January 16, 2025. Current direction emphasizes owner discretion. Platform stance: accurate representation of what programs do, with appropriate disclaimers; no compliance claims.

**[Spring Batch job extension deployed before V93 migration]** → Mitigation: Job code must be null-safe; deploy as part of or after the V93 migration release, never before.

## Migration Plan

**Migrations finalized at V91–V94** after a two-step renumber: V79–V82 → V85–V88 post-v0.51.0 Phase F (which consumed V79–V84), then V85–V88 → V91–V94 (2026-04-26) after Phase G claimed V85/V87/V88/V89. Phase G ships at HWM V89; reentry-spec slots V91–V94 follow. **Re-verify HWM before writing any migration file** in case any further pre-reentry slice has claimed additional slots. Query: `SELECT version FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 1`.

| Migration | Content | Notes |
|---|---|---|
| V91 | `shelter_type` VARCHAR(50) DEFAULT 'EMERGENCY'; `county` VARCHAR(100) indexed; backfill `dvShelter=true` → `shelter_type='DV'`; check constraint `dvShelter=false OR shelter_type='DV'` | Non-breaking; all existing shelters remain 'EMERGENCY' except DV shelters |
| V92 | `eligibility_criteria` JSONB nullable on `shelter_constraints`; GIN index (CONCURRENTLY, outside transaction) | Flyway `mixed=true` or separate migration step for CONCURRENTLY |
| V93 | (1) ALTER `tenant_dek.purpose` CHECK constraint to add `RESERVATION_PII` to allowed set (Phase F follow-up piece); (2) `held_for_client_name_encrypted` TEXT, `held_for_client_dob_encrypted` TEXT, `hold_notes_encrypted` TEXT on `reservation` — all nullable, all storing base64 v1 envelope from `SecretEncryptionService.encryptForTenant(..., KeyPurpose.RESERVATION_PII, ...)`. | Behavior unchanged until columns populated. Option A per issue #152 |
| V94 | `requires_verification_call` BOOLEAN DEFAULT FALSE on `shelter` | Non-breaking; existing shelters default to false |

**Rollback:** All new columns are nullable or have safe defaults. If any migration must be rolled back, the application code must not reference the missing columns — Spring Boot startup will fail if entities reference non-existent columns. Standard rollback posture: retag previous backend image, force-recreate backend only. Flyway migrations are immutable after apply; rollback requires a new forward migration if needed.

**No data loss path:** The `dvShelter` boolean is untouched. No existing reservation behavior changes. Existing hold durations, shelter records, and search results are unaffected until shelter admins populate the new fields.

## Open Questions

1. **Hold note character limit:** *[RESOLVED — warroom 2026-04-24 pass-2]* UI enforces 500 chars, server-side validation 1000 chars.

2. **County display in search results:** *[RESOLVED — warroom 2026-04-24 pass-2]* County in the detailed card only; not in the mobile summary list (space constraint).

3. **`active_counties` tenant config key — who sets it?** *[BLOCKED on issue #141 resolution]* — recommendation (PLATFORM_ADMIN sets at tenant creation, not COC_ADMIN) depends on whether the split into TENANT_ADMIN + PLATFORM_OPERATOR changes who holds "deployment-scope configuration" authority. Resolves inside Phase G.

4. **Reentry deployment identifier (`features.reentryMode` flag):** Decision — **scope in at V91 design time**. Adding the flag with V91 (shelter schema) is cheap; retrofitting later requires touching the shelter edit form + search UI in a second pass. Warroom 2026-04-24 pass-2 recommendation: include as a tenant-level config flag driven by admin panel; PLATFORM_ADMIN-level setting (same authority as `active_counties`).

5. **[NEW] `held_for_client_*` PII encryption posture (V93 design blocker):** *[RESOLVED 2026-04-24 — Option A: ride `tenant_dek`]* — `heldForClientName`, `heldForClientDob`, `holdNotes` ship as `tenant_dek`-wrapped ciphertext (v0.51.0 Phase F-6 infrastructure) from V93 forward. New `KeyPurpose.RESERVATION_PII` enum value; V93 migration bundles the `tenant_dek.purpose` CHECK-constraint update alongside the `ALTER TABLE reservation` column adds. Columns are `TEXT` (base64 v1 envelope), not `VARCHAR`/`DATE`/`TEXT`. Spring Batch 24h purge retained as defense in depth. Closed via **[issue #152](https://github.com/ccradle/finding-a-bed-tonight/issues/152)**. Rationale: no regression against v0.51.0 security posture, inherits crypto-shred via tenant CASCADE, backup-at-rest stronger (pg_dump in the 24h window exports ciphertext not plaintext), infrastructure is the use case Phase F-6 was designed for.

6. **[NEW] Asheville stakeholder messaging:** *[OPEN — coordination item]* — should this capability be described as "coming next release" in City of Asheville materials, or held back until tagged? County filter directly enables Buncombe County deployment scope. Recommend holding back until Phase G tags and transitional-reentry branch begins active development, but flag now for awareness.

7. **[NEW] Casey Drummond i18n legal-review window:** *[OPEN — coordination item]* — book Casey's bandwidth for EN+ES sign-off on `shelter.criminalRecordPolicyDisclaimer`, `shelter.vawaNoteDisclaimer`, `hold.clientAttributionPrivacyNote` strings BEFORE implementation starts (task 15.6 is too late). See warroom 2026-04-24 pass-2.
