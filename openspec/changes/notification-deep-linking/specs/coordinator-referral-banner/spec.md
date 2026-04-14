## MODIFIED Requirements

### Requirement: banner-click-navigation

Clicking the banner SHALL navigate the coordinator to the oldest PENDING referral the caller is authorized to see, regardless of whether the coordinator arrived on the dashboard via a notification deep-link or by any other route (direct nav, bookmark, fresh login).

This replaces the prior behavior ("scroll to the first DV shelter with pending referrals"), which was doubly broken: the code did not filter to shelters with pending referrals, and even if it had, the coordinator would have been dropped on the shelter card without the specific pending referral row being focused — forcing a second visual hunt.

The click handler SHALL read the routing hint (`firstPending.referralId`) returned by `GET /api/v1/dv-referrals/pending/count` (see pending-count-endpoint requirement below) and navigate via React Router to `/coordinator?referralId=${firstPending.referralId}`. The `useDeepLink` state machine owns every subsequent step: resolve → expand → scroll → focus the referral row. The banner MUST NOT carry its own resolve/scroll logic — the two code paths (notification bell click and banner click) converge on a single implementation.

#### Scenario: Banner click with referralId query param already in URL (notification deep-link in flight)

- **GIVEN** the coordinator arrived via `/coordinator?referralId=abc-123` from a notification click
- **AND** the `useDeepLink` hook has already processed that intent (state is `done` or `stale`)
- **WHEN** the coordinator clicks the banner
- **THEN** the click handler SHALL NOT re-navigate (re-clicking the same URL adds no information)
- **AND** the click handler SHALL NOT fall back to the `firstPending` hint (the user-initiated deep-link wins)

#### Scenario: Banner click without referralId query param (genesis gap closure)

- **GIVEN** the coordinator is on `/coordinator` with no query parameters
- **AND** `GET /api/v1/dv-referrals/pending/count` returned `{ count: 1, firstPending: { referralId: "abc-123", shelterId: "shelterB" } }`
- **AND** the referral `abc-123` is pending at Harbor House (a DV shelter the coordinator is assigned to)
- **WHEN** the coordinator clicks the banner
- **THEN** the browser URL SHALL become `/coordinator?referralId=abc-123`
- **AND** `useDeepLink` SHALL resolve the referral, auto-expand Harbor House (not the alphabetically-first DV shelter), scroll to the screening row, and focus the row (per S-2)
- **AND** the `coordinator-referral-banner` component MUST NOT invoke `openShelter(shelters.find(item => item.shelter.dvShelter).id)` — that fallback is deleted

#### Scenario: Banner click when count drops to zero mid-flight

- **GIVEN** the banner has rendered with `{ count: 1, firstPending: { referralId: "abc-123", shelterId: "shelterB" } }`
- **AND** another coordinator accepts `abc-123` between render and click (SSE `referral.update` event has not yet round-tripped to refresh the banner's state)
- **WHEN** the coordinator clicks the banner
- **THEN** navigation SHALL still occur to `/coordinator?referralId=abc-123`
- **AND** `useDeepLink` SHALL resolve the referral, observe it is no longer PENDING, and transition to `stale` — surfacing the existing stale-toast copy ("This referral is no longer pending") rather than silently doing nothing
- **AND** the next SSE `referral.update` event SHALL re-fetch `/pending/count`; if `count === 0`, the banner self-hides (existing behavior preserved)

#### Scenario: Banner click when no pending referrals exist (defensive — banner should not be visible)

- **GIVEN** `count === 0` and `firstPending === null`
- **THEN** the banner SHALL not render (existing early return on `pendingCount <= 0` — CoordinatorReferralBanner.tsx:57)
- **AND** therefore no click is possible — no routing contract applies in this state

### Requirement: pending-count-endpoint

`GET /api/v1/dv-referrals/pending/count` SHALL return the total PENDING referral count across the coordinator's assigned DV shelters, AND a routing hint identifying the oldest such pending referral so the banner can deep-link without a separate round-trip.

The response shape is `{ count: integer, firstPending: { referralId: UUID, shelterId: UUID } | null }`. When `count === 0`, `firstPending` is JSON `null` (the field is present so clients can test for `=== null`; we do NOT configure `@JsonInclude(NON_NULL)` for this field). When `count >= 1`, `firstPending` identifies the referral with the earliest `created_at` across the caller's assigned shelters.

Authorization is unchanged: `hasAnyRole('COORDINATOR', 'COC_ADMIN', 'PLATFORM_ADMIN')`. RLS + `coordinatorAssignmentRepository.findShelterIdsByUserId(userId)` scope the query — `firstPending` cannot surface a referral the caller is not authorized to see.

This is an additive change to an existing endpoint. Pre-Phase-4 clients that destructure only `{ count }` continue to work unmodified.

#### Scenario: Count and routing hint reflect all assigned shelters (oldest-first tie-break)

- **GIVEN** a coordinator assigned to 3 DV shelters with the following PENDING referrals:
  - Shelter A: 1 referral created at T+0
  - Shelter B: 0 referrals
  - Shelter C: 1 referral created at T+5
- **WHEN** the coordinator calls `GET /dv-referrals/pending/count`
- **THEN** the response SHALL be `{ "count": 2, "firstPending": { "referralId": "<T+0 referral UUID>", "shelterId": "<Shelter A UUID>" } }`

#### Scenario: Empty state explicitly returns null firstPending

- **GIVEN** a coordinator with zero PENDING referrals
- **WHEN** the coordinator calls `GET /dv-referrals/pending/count`
- **THEN** the response SHALL be `{ "count": 0, "firstPending": null }`
- **AND** the JSON representation SHALL include the `firstPending` key (not omit it)

#### Scenario: Unassigned shelter's pending referrals do not leak into firstPending

- **GIVEN** a coordinator assigned only to Shelter A
- **AND** Shelter D (same tenant, same dvShelter=true flag) has a PENDING referral created at T+0, older than any referral at Shelter A
- **WHEN** the coordinator calls `GET /dv-referrals/pending/count`
- **THEN** `firstPending` SHALL NOT point at the Shelter D referral
- **AND** `firstPending` SHALL point at the oldest referral at Shelter A only

#### Scenario: Cross-tenant referrals do not leak via firstPending

- **GIVEN** a coordinator in Tenant X with zero pending referrals in their assigned shelters
- **AND** Tenant Y has pending referrals (invisible to Tenant X via RLS)
- **WHEN** the Tenant X coordinator calls `GET /dv-referrals/pending/count`
- **THEN** the response SHALL be `{ "count": 0, "firstPending": null }`
- **AND** the response MUST NOT leak any Tenant Y referral identifiers

#### Scenario: Backward compatibility — pre-Phase-4 clients destructuring only count

- **GIVEN** a hypothetical pre-Phase-4 client that parses the response as `const { count } = await response.json()`
- **WHEN** the endpoint returns `{ count: 2, firstPending: { ... } }`
- **THEN** that client SHALL continue to receive the correct `count` without error
- **AND** the additional `firstPending` field SHALL NOT cause a parse error (standard JSON deserialization ignores unknown fields)
