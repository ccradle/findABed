## Why

Hold duration is configurable per tenant in the backend (`ReservationService.getHoldDurationMinutes()` reads `hold_duration_minutes` from tenant config JSONB), but there is no way to change it from the Admin UI. A CoC administrator must have direct database access to modify the value — defeating the purpose of a configurable setting.

Dr. James Whitfield (hospital social worker persona) needs 2-3 hours for discharge workflows. Rev. Alicia Monroe's seasonal shelter may want a shorter hold. Sandra Kim (coordinator) needs to trust that the auto-expiry timer matches what was configured. Teresa Nguyen (city procurement) will ask "can an admin change this without calling a developer?"

Additionally, 7 documentation locations hardcode "45 minutes" without mentioning configurability, and 2 documents have contradictory default values.

## What Changes

- **Admin UI**: Add hold duration configuration field to the Admin panel tenant settings, with validation (minimum 5 minutes, maximum 480 minutes / 8 hours)
- **Frontend display**: Show the configured hold duration alongside the countdown timer so outreach workers know the hold window
- **Default change**: `DEFAULT_HOLD_DURATION_MINUTES` from 45 → 90 minutes (45 is too tight for real-world transport + discharge)
- **Documentation fixes (7+ places)**: Update all hardcoded "45 minutes" references to state "configurable per tenant (default 90 minutes)"
- **Contradiction fixes (2 places)**: Fix HSDS extension spec "2 hours" default, fix MCP briefing parameter-vs-tenant-config discrepancy
- **Test**: Verify changing hold duration via Admin UI affects new reservations

## Capabilities

### New Capabilities

### Modified Capabilities
- `reservation-hold-duration-config`: Add Admin UI for hold duration editing (currently backend-only)

## Impact

- **Modified file (frontend)**: `AdminPanel.tsx` — add hold duration input to tenant config section
- **Modified file (frontend)**: `OutreachSearch.tsx` — display configured hold duration in reservation UI
- **Modified files (docs, 7)**: partial-participation-guide.md, demo/index.html, schema.dbml, runbook.md, government-adoption-guide.md, README.md, WCAG-ACR.md
- **Modified files (docs, 2 contradictions)**: fabt-hsds-extension-spec.md (docs repo), MCP-BRIEFING.md (docs repo)
- **Backend change**: `ReservationService.java` — change `DEFAULT_HOLD_DURATION_MINUTES` from 45 to 90
- **Seed data change**: `seed-data.sql` — update `hold_duration_minutes` from 45 to 90 in tenant config JSONB
- **No schema changes**: `hold_duration_minutes` already exists in tenant config JSONB
- **Risk**: None — the backend logic is already implemented and tested. This is UI + documentation.
