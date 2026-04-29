## Why

Emergency shelter bed availability alone is insufficient for two practitioner categories that are poorly served today: reentry housing navigators placing people on release day, and call-center navigators placing callers into transitional housing programs with complex eligibility requirements. Both populations face the same structural gap — shelter records carry no machine-readable eligibility data — forcing navigators to make phone calls that the platform should make unnecessary. A CSG 2023 national survey of DOCs confirmed fewer than 5% use dedicated technology for housing needs assessment; no platform nationally combines real-time bed availability with criminal record policy filtering and supervision geography matching. This change addresses both use cases through a unified data model, because the architectural foundation is identical.

## What Changes

- **New `shelter_type` field** on shelter records: controlled vocabulary replacing the implicit "everything that isn't DV is emergency" assumption. Enables filtering by TRANSITIONAL, SUBSTANCE_USE_TREATMENT, MENTAL_HEALTH_TREATMENT, REENTRY_TRANSITIONAL, PERMANENT_SUPPORTIVE, RAPID_REHOUSING, and EMERGENCY.
- **New `county` field** (indexed) on shelter records: enables supervision geography filtering. A bed in the wrong county triggers a supervision violation for someone on post-release supervision. County is the practical boundary for supervision district compliance.
- **New `eligibility_criteria` JSONB** on shelter_constraints: structured, extensible eligibility schema covering program requirements, documentation, intake hours, and a `criminal_record_policy` sub-object with a controlled offense-type vocabulary drawn from documented national patterns.
- **New `requires_verification_call` boolean** on shelter: sentinel flag indicating the shelter requires a direct call before eligibility can be assumed, regardless of what the JSONB fields say.
- **Criminal record policy disclaimer** rendered as a non-dismissable component wherever criminal record fields are displayed: "Self-reported by shelter. Verify directly before assuming eligibility." Legally required; platform represents actual shelter-reported policies, not certified compliance.
- **Third-party navigator hold attribution**: `held_for_client_name`, `held_for_client_dob`, `hold_notes` on reservation records, supporting the reentry navigator model where the person holding the bed is not the person who will occupy it. PII purged 24h after hold expiry/completion.
- **Hold duration admin UI**: existing `holdDurationMinutes` tenant config key exposed in admin panel. Reentry deployments configure 180–240 min holds; release-day transport logistics routinely exceed 90 min.
- **Bed search filter additions**: `shelter_type`, `county`, `accepts_felonies` filters on `GET /api/v1/beds/search`.

## Capabilities

### New Capabilities

- `shelter-type-taxonomy`: Controlled vocabulary for shelter classification. New `shelter_type` column on `shelter` table with enum values and V91 migration. Existing `dvShelter` boolean retained for RLS (load-bearing); `shelter_type` is a display/filter layer. DB constraint enforces that `dvShelter = true` implies `shelter_type = 'DV'`.
- `extended-eligibility-criteria`: JSONB eligibility schema on `shelter_constraints` (V92 migration) with GIN index. Schema covers `criminal_record_policy` (object with controlled `excluded_offense_types` enum, `accepts_felonies` boolean, `vawa_protections_apply` boolean, notes), `program_requirements` (string[]), `documentation_required` (string[]), `intake_hours` (string), `custom_tags` (string[]). Guided form editor in admin UI — never raw JSON input. `CriminalRecordPolicyDisclaimer` component rendered wherever criminal record fields are visible; non-dismissable; ARIA `role="note"`; i18n in both locales.
- `supervision-county-filter`: Indexed `county` VARCHAR(100) column on `shelter` table (V91 migration). County filter on bed search endpoint. County values are validated against `tenant.config.active_counties` (no DB-level enum — see design D3); deployments seed the NC 100-county list as the default `active_counties` config row. Supervision geography is jurisdictional (county/district authority), not distance-based.

### Modified Capabilities

- `bed-reservation`: Reservation record gains `held_for_client_name` VARCHAR(100), `held_for_client_dob` DATE, `hold_notes` TEXT (V81 migration, all nullable). Spring Batch cleanup job extended to null these fields 24h after hold expiry/completion. Hold dialog UI gains optional client attribution fields with purpose-clear labels.
- `shelter-edit`: Admin shelter form gains shelter_type selector, county selector, eligibility_criteria guided section editor, requires_verification_call toggle (V94: `requires_verification_call` BOOLEAN DEFAULT FALSE on shelter table). Field labels use dignity-centered language throughout.
- `reservation-hold-duration-config`: ReservationSettings admin panel component (stub exists) wired to expose `holdDurationMinutes` from tenant.config JSONB. Range 30–480 min. COC_ADMIN role required. Hold duration change applies to new holds only; in-flight holds retain creation-time duration.

## Impact

- **Database**: 4 migrations (V91–V94); GIN index on eligibility_criteria JSONB; indexed county column; DB constraint on dvShelter/shelter_type sync
- **Backend**: `BedSearchService` gains three new filter parameters; `ReservationService` gains navigator attribution fields; Spring Batch cleanup job scope extended; new `PATCH /api/v1/admin/tenants/{tenantId}/hold-duration` endpoint
- **Frontend**: `OutreachSearch.tsx` (new filters, advanced-filters collapsed on mobile), `ShelterEditPage.tsx` (new field sections), hold dialog (client attribution), `ReservationSettings` admin panel component (wired from stub)
- **i18n**: ~13 new key groups in both EN and ES locales; all criminal record policy labels reviewed against dignity-centered language standards (per Keisha Thompson warroom)
- **Testing**: Cross-tenant isolation test for new PII fields; `accepts_felonies + requires_verification_call` AND-condition test; hold duration mid-session semantics test; PII cleanup job integration test
- **No breaking changes**: All new fields nullable; existing reservation and shelter behavior unchanged; `dvShelter` boolean retained
- **Flyway HWM**: V90 → V94 (4 migrations: V91 / V92 / V93 / V94). Renumbered twice — V79–V82 → V85–V88 post-v0.51.0 Phase F, then V85–V88 → V91–V94 (2026-04-26) after Phase G claimed V85/V87/V88/V89. **Phase G (v0.53) and F11 (v0.54) both shipped** — current live HWM is V90. Verify actual HWM at implementation start in case any further pre-reentry slice claims additional slots.

## Scheduling note (warroom 2026-04-24 pass-2)

This change is **scaffolded but paused** until Phase G (multi-tenant-production-readiness §8 — audit chain hashing + platform admin access log) ships. Phase G strengthens every claim this feature makes about what happens to the data. Demetrius Holloway, the primary design subject, explicitly concurred: *"Phase G first, but scaffold transitional-reentry in parallel NOW so the day Phase G tags, we start. No drift. No re-scoping."*

**V93 encryption decision — RESOLVED 2026-04-24 (Option A)**: the `held_for_client_*` columns persist as `_encrypted` TEXT columns riding the `tenant_dek`-wrapped DEK infrastructure shipped in v0.51.0 Phase F-6 (new `KeyPurpose.RESERVATION_PII`). Two-layer PII posture: (1) at-rest ciphertext for `pg_dump` / backup exposure scenarios and crypto-shred on hard-delete; (2) 24h post-resolution Spring Batch purge of ciphertext columns. The plaintext is never persisted. Marcus Webb's regression concern is resolved — new PII columns inherit the same defense-in-depth posture v0.51.0 established. Decision closed in **[GitHub issue #152](https://github.com/ccradle/finding-a-bed-tonight/issues/152)**; full rationale in `design.md` D4.
