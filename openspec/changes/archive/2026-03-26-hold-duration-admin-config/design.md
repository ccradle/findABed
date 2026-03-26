## Context

Hold duration is stored in the tenant config JSONB field `hold_duration_minutes` (default 90). `ReservationService.getHoldDurationMinutes()` reads it with a fallback to `DEFAULT_HOLD_DURATION_MINUTES = 90`. The `PUT /api/v1/tenants/{id}/config` endpoint already updates tenant config JSONB. The Admin UI already has a tenant config editing pattern (observability settings use `TenantService.updateConfig()`).

The frontend countdown timer reads `remainingSeconds` from the API response — no hardcoded 45 in the frontend.

## Goals / Non-Goals

**Goals:**
- CoC admins can view and change hold duration from the Admin UI
- Outreach workers see the configured hold duration when holding a bed
- All documentation accurately describes hold duration as configurable
- Contradictions in HSDS spec and MCP briefing are resolved

**Non-Goals:**
- Per-shelter hold duration (all shelters in a tenant share the same setting)
- Hold duration override per reservation (the API could support this later)

## Decisions

### D1: UI placement

Add hold duration to a **"Reservation Settings"** section in the Admin panel, near or within the existing admin configuration tabs. Use the same pattern as the observability config: label, number input, save button, success confirmation.

### D2: Validation

- Minimum: 5 minutes (below this, holds expire before transport is possible)
- Maximum: 480 minutes / 8 hours (beyond this, a hold is no longer a short-term reservation)
- Default: 45 minutes (displayed as placeholder)
- Input type: number with `min`, `max`, and `step=5` for convenience

### D3: Outreach worker visibility

When a hold is created, show the configured hold duration in the success message: "Bed held! You have {minutes} minutes." This uses the existing i18n key `search.holdSuccess` which already has `{minutes}` placeholder — the current code passes a hardcoded value that should be replaced with the actual configured duration.

### D5: Default change from 45 → 90 minutes

Change `DEFAULT_HOLD_DURATION_MINUTES` from 45 to 90 in `ReservationService.java`. Update `seed-data.sql` tenant config from `"hold_duration_minutes": 45` to `"hold_duration_minutes": 90`. Update all documentation references from "45 minutes" to "90 minutes".

Rationale: 45 minutes is insufficient for many real-world scenarios — transport time, traffic, client hesitation, hospital discharge workflows. 90 minutes provides a practical default while remaining a short-term hold. Hospital deployments can configure to 120-180 minutes via the Admin UI.

### D4: Documentation update strategy

Update all 7 hardcoded "45 minutes" references to use the pattern: "configurable per tenant (default 90 minutes)". Fix the two contradictions:
- HSDS extension spec: change "default: 2 hours" to "default: 45 minutes (configurable per tenant)"
- MCP briefing: clarify that hold duration is read from tenant config, not passed as API parameter
