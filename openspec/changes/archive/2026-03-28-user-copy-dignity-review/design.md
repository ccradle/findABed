## Overview

Review and update all user-facing copy through dignity and communications lenses. Changes are frontend-only (display labels, i18n strings, component text). Backend enum values are unchanged.

## Design Decisions

### DV_SURVIVOR → "Safety Shelter"

The internal enum `DV_SURVIVOR` remains unchanged in the backend. The frontend display label in the population type filter dropdown changes from "DV Survivors" to "Safety Shelter." Rationale: an outreach worker searching for DV beds may have the client sitting next to them — the screen should not display "DV_SURVIVOR" or "DV Survivors" where the client can read it.

The i18n keys change:
- `search.dvSurvivor`: "DV Survivors" → "Safety Shelter" (en)
- `search.dvSurvivor`: "Sobrevivientes de VD" → "Refugio Seguro" (es)

### Freshness Badge Enhancement

Currently: colored dot + "Fresh" / "Stale" / "Unknown" text.
After: colored dot + status text + plain-text age: "Fresh · Updated 12 min ago" / "Stale · Last updated 9 hours ago"

The `DataAge` component already receives `dataAgeSeconds`. The enhancement adds a human-readable relative time string next to the badge.

### Offline Banner Enhancement

Currently: "You are offline"
After: "You are offline — your last search is still available"

Simple i18n string update.

### Error Message Review

Audit all user-facing error messages (not JSON API errors, which are for MCP agents):
- Login failures: already human ("Invalid email or password")
- Session timeout: already human ("Session Expiring")
- Network errors: review for actionability ("Unable to reach server. Check your connection and try again.")

### i18n Approach

All changes go through the i18n system (en.json, es.json). No hardcoded strings. Spanish translations should be reviewed for cultural appropriateness, not just literal translation.

## File Changes

| File | Change |
|------|--------|
| `frontend/src/i18n/en.json` | Update labels: dvSurvivor, freshness descriptions, offline message |
| `frontend/src/i18n/es.json` | Spanish equivalents |
| `frontend/src/components/DataAge.tsx` | Add relative time string next to badge |
| `frontend/src/components/OfflineBanner.tsx` | Add reassurance text |
| `frontend/src/pages/OutreachSearch.tsx` | Verify DV label comes from i18n (should already) |
| `e2e/playwright/tests/outreach-search.spec.ts` | Update assertions for new label text |
| New or updated: `e2e/playwright/tests/copy-dignity.spec.ts` | Verify "Safety Shelter" label, freshness descriptions, offline message |
