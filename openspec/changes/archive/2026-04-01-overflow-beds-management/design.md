## Context

The overflow beds infrastructure is complete: V18 migration added `overflow_beds` column, `AvailabilityUpdateRequest` accepts `overflowBeds`, `BedSearchResult.PopulationAvailability` includes `overflowBeds`, search results return the field, and the `surge.activated` event includes `estimated_overflow_beds`. But:

1. The coordinator dashboard hardcodes `overflowBeds: 0` (line 133) with no input control
2. Outreach search shows overflow as a red `+N overflow` addendum separate from `beds_available`
3. `BedSearchService` ranking ignores overflow
4. `ReservationService` hold check uses `bedsAvailable` (excludes overflow) — **rejects holds at overflow-only shelters**

Key architectural insight: `BedAvailability` is in the `availability` module. Both `BedSearchService` (availability module) and `ReservationService` (reservation module, depends on availability.repository per ArchUnit) already read `BedAvailability`. The `getOverflowBeds()` method is already on the domain object — no cross-module dependency needed. We just read it.

Research findings:
- San Diego Shelter Ready: workers see combined beds, not type breakdown
- HUD HMIS 2.07: overflow is separate inventory record — `beds_total` must stay pure (permanent capacity)
- Simone/Keisha: "overflow" is operational jargon — use "temporary beds" in user-facing copy
- Alex: don't inflate `beds_total` — overflow is an annotation alongside, not a replacement for, permanent capacity
- Riley: test concurrency (two workers holding the last overflow bed simultaneously)

## Goals / Non-Goals

**Goals:**
- Holds succeed at overflow-only shelters (0 regular + N overflow = holdable)
- Coordinators can report overflow via dashboard during active surge
- Outreach workers see combined count with transparency note
- Search ranking includes overflow during active surge
- Cache invalidated correctly on surge state change
- Language is human-centered ("temporary beds" not "overflow")
- Accessibility: aria-labels, dark mode contrast, screen reader support
- Test coverage: positive, negative, regression, concurrency, math invariants

**Non-Goals:**
- Shelter availability category (YEAR_ROUND/SEASONAL/OVERFLOW) — deferred, committed OpenSpec in memory
- Overflow input outside surge — deferred until shelter-type-gating exists
- Auto-setting overflow on surge activation — coordinators report manually
- HIC export format changes — data is already correct, format is separate concern

## Design

**1. Backend — ReservationService hold check (the one-line fix):**

```java
// ReservationService.java:101-104 — current:
int bedsAvailable = current != null ? current.getBedsAvailable() : 0;
if (bedsAvailable <= 0) {
    throw new IllegalStateException("No beds available");
}

// Fixed:
int bedsAvailable = current != null ? current.getBedsAvailable() : 0;
int overflow = current != null && current.getOverflowBeds() != null
    ? current.getOverflowBeds() : 0;
int effectiveAvailable = bedsAvailable + overflow;
if (effectiveAvailable <= 0) {
    throw new IllegalStateException("No beds available");
}
```

No new imports, no cross-module dependency. `BedAvailability` is already in the method's scope.

**Critical: THREE places in ReservationService need overflow:**
1. Initial availability check (effectiveAvailable > 0)
2. Post-hold INV-5 verification (occupied + newHold <= total + overflow)
3. createSnapshot call after hold (pass overflow through, don't wipe to 0)

Same for confirm/cancel/expire path — createSnapshot must preserve overflow value.

**AvailabilityService.createSnapshot INV-5 also updated:**
`occupied + on_hold <= total + overflow` (was `<= total`).
This allows holds to be placed against overflow capacity.

**2. Backend — BedSearchService ranking (surge-aware):**

```java
// BedSearchService.java:222-232 — current ranking:
results.sort(Comparator
    .<BedSearchResult, Integer>comparing(r -> {
        int totalAvail = r.availability().stream()
            .mapToInt(PopulationAvailability::bedsAvailable).sum();
        return totalAvail > 0 ? 0 : 1;
    })
    ...

// Fixed (surgeActive is already a parameter on the method):
results.sort(Comparator
    .<BedSearchResult, Integer>comparing(r -> {
        int totalAvail = r.availability().stream()
            .mapToInt(a -> a.bedsAvailable() + (surgeActive ? a.overflowBeds() : 0))
            .sum();
        return totalAvail > 0 ? 0 : 1;
    })
    ...
```

Same pattern for the tertiary sort (descending by total available).

**3. Backend — Cache key includes surge state:**

```java
// BedSearchService.java:86 — current:
String cacheKey = tenantId.toString();

// Fixed:
String cacheKey = tenantId.toString() + (surgeActive ? "-surge" : "");
```

This ensures surge activation/deactivation serves fresh results immediately, not stale cache from the previous state.

**4. Frontend — Coordinator dashboard surge-gated overflow stepper:**

Uses the existing `StepperButton` component pattern (44px circular buttons, ±). Visible only when surge is active.

```tsx
// Fetch surge state on mount (same pattern as OutreachSearch):
const [surgeActive, setSurgeActive] = useState(false);
useEffect(() => {
  api.get<SurgeEventResponse[]>('/api/v1/surge-events')
    .then(surges => setSurgeActive(surges.some(s => s.status === 'ACTIVE')))
    .catch(() => {});
}, []);

// In the availability row, after On-Hold display:
{surgeActive && (
  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
    <span style={{ fontSize: text.xs, color: color.textTertiary, fontWeight: weight.semibold, minWidth: 60 }}>
      <FormattedMessage id="surge.overflowBeds" />
    </span>
    <StepperButton label="−" data-testid={`overflow-minus-${avail.populationType}`}
      onClick={() => updateOverflow(avail.populationType, -1)}
      disabled={avail.overflowBeds <= 0} />
    <span data-testid={`overflow-value-${avail.populationType}`}
      style={{ fontSize: text.lg, fontWeight: weight.extrabold, minWidth: 32, textAlign: 'center' }}>
      {avail.overflowBeds}
    </span>
    <StepperButton label="+" data-testid={`overflow-plus-${avail.populationType}`}
      onClick={() => updateOverflow(avail.populationType, 1)} />
  </div>
)}
```

Pre-populate from API: change `overflowBeds: 0` (line 133) to `overflowBeds: a?.overflowBeds ?? 0`.

Hint text below stepper:
```tsx
{surgeActive && (
  <div style={{ fontSize: text['2xs'], color: color.textMuted, marginTop: 2 }}>
    <FormattedMessage id="surge.overflowHint" />
  </div>
)}
```

All colors from `color.*` design tokens — dark mode safe.

**5. Frontend — Outreach search combined display:**

```tsx
// Compute effective available:
const effectiveAvailable = activeSurge
  ? a.bedsAvailable + a.overflowBeds
  : a.bedsAvailable;

// Badge shows combined count:
{getPopulationTypeLabel(a.populationType, intl)}: {effectiveAvailable}

// Transparency note when overflow contributes:
{activeSurge && a.overflowBeds > 0 && (
  <span style={{ color: color.textMuted, fontWeight: weight.normal }}>
    {' '}
    <FormattedMessage id="search.includesTemporary" values={{ count: a.overflowBeds }} />
  </span>
)}

// Hold button uses effective available:
{effectiveAvailable > 0 && !r.dvShelter && ( <button ... /> )}

// Request Referral uses effective available:
{effectiveAvailable > 0 && r.dvShelter && ( <button ... /> )}
```

Remove the old red `+N overflow` display (line 744).

**6. Language — "temporary beds" not "overflow":**

User-facing copy:
- `search.includesTemporary`: "(includes {count} temporary beds)" / "(incluye {count} camas temporales)"
- `surge.overflowBeds`: "Temporary Beds" / "Camas Temporales" (update existing key)
- `surge.overflowHint`: "Cots, mats, and emergency space during surge" / "Catres, colchonetas y espacio de emergencia durante emergencia"

Internal/admin copy can still use "overflow" where appropriate.

**7. Accessibility:**

- Overflow stepper uses `StepperButton` which has `aria-label` ("Increase"/"Decrease")
- Add explicit `aria-label` on overflow value display: `aria-label={intl.formatMessage({ id: 'surge.overflowAriaLabel' }, { count: avail.overflowBeds })}`
- Transparency note in outreach search: wrapped in `<span>` (not a separate live region — it renders with the badge, not announced separately)
- Dark mode: all colors via `color.*` tokens, no hardcoded values. Verify `color.textMuted` contrast against both `color.successBg` and `color.errorBg` badge backgrounds.

## Risks

- **Stale overflow after surge ends:** Coordinator's last overflow value persists in snapshot. On next update without surge, the stepper is hidden and the form sends `overflowBeds: 0` (current hardcoded default). Self-correcting.
- **Concurrent last-overflow-bed hold:** Two workers hold simultaneously when effectiveAvailable = 1 (0 regular + 1 overflow). This is the same concurrency scenario as regular last-bed holds (TC-2.7) — the existing `ON CONFLICT DO NOTHING` + `bedsOnHold` increment handles it. One succeeds, one gets 409 conflict. Tested in existing `ReservationIntegrationTest`.
- **Cache staleness window:** Up to 60 seconds between surge activation and cache expiry with old ranking. Mitigated by including surge in cache key — surge on/off creates different cache entries.
- **Overflow without surge via API:** Backend accepts `overflowBeds > 0` even without active surge. UI prevents this (stepper hidden), but the API is permissive. Acceptable — no validation change needed.
