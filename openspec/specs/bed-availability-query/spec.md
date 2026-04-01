## MODIFIED Requirements

### Requirement: bed-search-results-display
MODIFY: Freshness badges must not rely on color alone.

#### Scenario: Freshness badges show text labels
- **WHEN** search results display freshness indicators
- **THEN** each badge includes a text label ("Fresh", "Stale", "Unknown") alongside the color background
- **AND** the text meets 4.5:1 contrast ratio against the badge background

### Requirement: Combined overflow display for outreach workers
During an active surge, outreach search results SHALL combine `beds_available` and `overflow_beds` into a single displayed count with "(includes N temporary beds)" transparency note. Hold/Referral buttons use effective availability. Search ranking includes overflow during surge.

### Requirement: Cache key unchanged for surge ranking
Availability data is cached per tenant. Ranking computed per-request from `surgeActive` parameter. No cache key change needed — same data, different sort order.
