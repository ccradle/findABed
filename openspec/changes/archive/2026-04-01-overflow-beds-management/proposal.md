## Why

The overflow beds pipeline is fully wired (database V18, API, events, search results) but **dead from the entry point**: the coordinator dashboard hardcodes `overflowBeds: 0` with no input control. Sandra can't report the 20 cots her church set up on a White Flag night. Darius sees "0 available" and skips the shelter. Rev. Monroe's clients sleep outside.

Additionally, overflow beds are returned as a separate field — not included in `beds_available` or search ranking. A shelter with 0 regular beds + 20 overflow cots appears "full" to outreach workers. Worse: `ReservationService` checks `bedsAvailable` (which excludes overflow) and **rejects holds** at shelters that only have overflow capacity. The San Diego Shelter Ready app (real-world precedent) shows combined available counts because workers need one answer: "Is there a spot?"

HUD HMIS Data Element 2.07 requires overflow to be reported as a separate inventory record. Our data model stores `overflow_beds` alongside `beds_total` on the availability snapshot — keeping both values preserves HIC reporting accuracy. `beds_total` means permanent physical capacity; `overflow_beds` means temporary (cots, mats). Neither is inflated or conflated.

The fix uses overflow data that's ALREADY on the `BedAvailability` domain object. `ReservationService` already reads `BedAvailability` from the availability repository — no cross-module dependency needed. We just read `getOverflowBeds()` alongside `getBedsAvailable()`. No ArchUnit violations, no semantic pollution, no new abstractions.

## What Changes

- **Backend hold check**: `ReservationService` uses `effectiveAvailable = bedsAvailable + overflowBeds` — holds succeed at overflow-only shelters
- **Backend search ranking**: `BedSearchService` ranks by effective available (includes overflow) during active surge
- **Backend cache key**: Include surge state to prevent stale ranking after surge activation/deactivation
- **Coordinator dashboard**: Surge-gated overflow stepper, pre-populated from latest snapshot
- **Outreach search**: Combined display during surge with "(includes N temporary beds)" transparency note
- **Coordinator/admin view**: Shows breakdown — regular beds and overflow separately
- **Language**: "temporary beds" not "overflow" in user-facing copy (Simone/Keisha: human, not jargon)
- **i18n**: Wire existing dead keys, add new keys for transparency notes
- **Documentation**: FOR-COORDINATORS.md updated with overflow reporting instructions

## Capabilities

### New Capabilities
_None._

### Modified Capabilities
- `surge-overflow`: Coordinator UI input for overflow beds (currently spec'd but not implemented in UI)
- `bed-availability-query`: Combined display for outreach, breakdown for coordinators, overflow in ranking during surge
- `shelter-availability-update`: Pre-populate overflow from latest snapshot in coordinator form

## Impact

- **Backend:** `ReservationService.java` — hold check uses `bedsAvailable + overflowBeds` (one line change, no new dependency)
- **Backend:** `BedSearchService.java` — ranking includes overflow during surge, cache key includes surge state
- **Frontend:** `CoordinatorDashboard.tsx` — surge fetch, overflow stepper (surge-gated), pre-populate from snapshot
- **Frontend:** `OutreachSearch.tsx` — combined display during surge, transparency note, Hold button uses effective available
- **Frontend:** `en.json` + `es.json` — wire existing keys, new transparency note keys, "temporary beds" language
- **Docs:** `FOR-COORDINATORS.md` — overflow reporting instructions
- **No database changes** (overflow_beds column already exists in V18)
- **No API changes** (overflowBeds already accepted in PATCH)
- **No new Flyway migrations**
