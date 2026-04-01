## MODIFIED Requirements

### Requirement: Combined overflow display for outreach workers

During an active surge, outreach search results SHALL combine `beds_available` and `overflow_beds` into a single displayed count. Language uses "temporary beds" not "overflow."

#### Scenario: Outreach worker sees combined count during surge
- **GIVEN** a surge is active and a shelter has 5 regular beds available + 20 overflow beds
- **WHEN** an outreach worker views search results
- **THEN** the shelter card shows "25" as the available count
- **AND** a transparency note "(includes 20 temporary beds)" appears in muted text
- **AND** the badge background is green (`color.successBg`) because effective > 0

#### Scenario: Overflow-only shelter shows as available during surge
- **GIVEN** a surge is active and a shelter has 0 regular beds + 20 overflow
- **WHEN** an outreach worker views search results
- **THEN** the shelter card shows "20" as available (green badge)
- **AND** the transparency note reads "(includes 20 temporary beds)"

#### Scenario: No surge — display unchanged
- **GIVEN** no surge is active
- **WHEN** an outreach worker views search results
- **THEN** `beds_available` is displayed as-is (overflow is 0 in normal operation)
- **AND** no transparency note appears

#### Scenario: Hold This Bed button uses effective availability
- **GIVEN** a surge is active and a shelter has 0 regular beds + 10 overflow
- **THEN** the "Hold This Bed" button IS visible (effective = 10 > 0)

#### Scenario: Request Referral button uses effective availability
- **GIVEN** a surge is active and a DV shelter has 0 regular beds + 5 overflow
- **THEN** the "Request Referral" button IS visible for DV-authorized workers (effective = 5 > 0)

#### Scenario: Old red "+N overflow" text removed
- **GIVEN** any search results with overflow > 0
- **THEN** there is NO red `+N overflow` text (old pattern removed)
- **AND** the transparency note "(includes N temporary beds)" replaces it

### Requirement: Coordinator/admin breakdown view

Coordinators and admins SHALL see the overflow breakdown separately.

#### Scenario: Coordinator sees breakdown during surge
- **GIVEN** a surge is active and a shelter has 5 regular + 20 overflow
- **WHEN** the coordinator views the shelter card on the dashboard
- **THEN** the available count shows the permanent beds available
- **AND** the overflow stepper shows 20 temporary beds separately
- **AND** both are visible and distinct

### Requirement: Search ranking includes overflow during surge

During an active surge, search result ranking SHALL include overflow beds.

#### Scenario: Shelter with overflow ranks higher
- **GIVEN** a surge is active
- **AND** Shelter A has `effectiveAvailable = 20` (0 regular + 20 overflow)
- **AND** Shelter B has `effectiveAvailable = 5` (5 regular + 0 overflow)
- **THEN** Shelter A ranks above Shelter B

#### Scenario: No surge — ranking unchanged
- **GIVEN** no surge is active
- **THEN** ranking uses only `beds_available` (overflow is 0)

### Requirement: Cache key includes surge state

The bed search cache key SHALL include the surge active state to prevent stale results.

#### Scenario: Surge activates — cache refreshes
- **GIVEN** search results are cached for tenant X with no surge
- **WHEN** a surge is activated
- **THEN** the next search uses a different cache key (tenant + surge)
- **AND** fresh results are returned with surge-aware ranking

#### Scenario: Surge deactivates — cache refreshes
- **GIVEN** search results are cached for tenant X with surge active
- **WHEN** the surge deactivates
- **THEN** the next search uses the non-surge cache key
- **AND** results return to normal ranking (overflow excluded)
