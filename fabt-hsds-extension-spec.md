# Spec: hsds-extension

## Purpose

This spec formally defines the `finding-a-bed-tonight` HSDS Profile Extension.
It extends the Open Referral Human Services Data Specification v3.0 with the
`BedAvailability`, `ShelterConstraints`, `SurgeEvent`, and `ShelterReservation`
objects that HSDS deliberately excluded from its core standard.

The extension is designed for submission to the Open Referral Initiative as a
community profile proposal. All field names and object structures follow HSDS
naming conventions (snake_case, UUID primary keys per RFC 4122).

---

## Requirements

---

### Requirement: HSDS profile declaration
The extension SHALL declare itself as an HSDS Profile in its JSON schema metadata,
referencing HSDS v3.0 as the base standard. It SHALL NOT modify or replace any
core HSDS objects — only extend them.

#### Scenario: Profile metadata present
- **WHEN** the JSON schema is read
- **THEN** `profile.base` is `openreferral/hsds@3.0` and `profile.name` is
  `finding-a-bed-tonight/bed-availability@1.0`

---

### Requirement: BedAvailability object
The extension SHALL define a `BedAvailability` object linked to an HSDS `location`
by `location_id`. It captures the real-time state of available beds at a shelter
at a specific moment in time.

**Fields (required unless marked optional):**

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Primary key |
| `location_id` | UUID | FK → HSDS `location.id` |
| `snapshot_ts` | ISO 8601 datetime | When this record was written |
| `last_updated_by` | string | Staff identifier (non-PII — role or station) |
| `population_type` | enum | See PopulationType below |
| `beds_total` | integer | Total capacity for this population type |
| `beds_available` | integer | Currently unoccupied and unreserved |
| `beds_on_hold` | integer (optional) | Soft-reserved, not yet occupied |
| `overflow_available` | integer (optional) | Surge/overflow capacity if activated |
| `accepting_new_guests` | boolean | Master toggle — false overrides bed counts |
| `notes` | string (optional) | Free text, max 500 chars, no PII |

**PopulationType enum values:**
`SINGLE_ADULT`, `FAMILY_WITH_CHILDREN`, `WOMEN_ONLY`, `VETERAN`,
`YOUTH_18_24`, `YOUTH_UNDER_18`, `DV_SURVIVOR` (restricted — see security spec)

#### Scenario: BedAvailability snapshot written
- **WHEN** a shelter coordinator submits an availability update
- **THEN** a new `BedAvailability` row is inserted (append-only log)
- **AND** the previous snapshot for the same `(location_id, population_type)` is
  NOT deleted — snapshots are immutable audit records
- **AND** the query layer reads only the most recent snapshot per
  `(location_id, population_type)`

#### Scenario: Concurrent updates from the same shelter
- **WHEN** two coordinators at the same shelter submit updates simultaneously
- **THEN** both inserts succeed using `ON CONFLICT DO NOTHING` semantics
- **AND** the query layer reads the snapshot with the latest `snapshot_ts`

---

### Requirement: ShelterConstraints object
The extension SHALL define a `ShelterConstraints` object linked to an HSDS
`location` by `location_id`. It captures the stable attributes of a shelter that
affect matching — this is the "filter panel" data, not the live availability data.

**Fields:**

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Primary key |
| `location_id` | UUID | FK → HSDS `location.id` |
| `sobriety_required` | boolean | Sobriety required for admission |
| `id_required` | boolean | Government-issued ID required |
| `referral_required` | boolean | Referral from specific agency required |
| `referral_agencies` | string[] (optional) | Names of accepted referral sources |
| `pets_allowed` | boolean | Domestic pets permitted |
| `wheelchair_accessible` | boolean | ADA-compliant accessible entry and rooms |
| `languages_spoken` | string[] | ISO 639-1 language codes |
| `curfew_time` | time (optional) | Latest admission time (local) |
| `max_stay_days` | integer (optional) | Maximum length of stay, null = no limit |
| `dv_shelter` | boolean | DV privacy flag — governs data access rules |
| `population_types_served` | PopulationType[] | Which population types this shelter accepts |
| `check_in_instructions` | string (optional) | What to tell the outreach worker, max 1000 chars |

#### Scenario: DV flag enforces data access boundary
- **WHEN** `dv_shelter = true`
- **THEN** this shelter's location, address, and capacity are NEVER returned
  in a public query response
- **AND** availability is accessible ONLY via the opaque-referral endpoint
  to callers with the `DV_REFERRAL` role

---

### Requirement: SurgeEvent object
The extension SHALL define a `SurgeEvent` object that a CoC admin can activate
for a geographic bounding box. Activation unlocks overflow capacity reporting
and broadcasts an event to all subscribed outreach worker sessions.

**Fields:**

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Primary key |
| `coc_id` | string | HUD-assigned CoC identifier (e.g., `NC-507`) |
| `triggered_by` | string | Admin user identifier |
| `triggered_at` | ISO 8601 datetime | Activation timestamp |
| `bounding_box` | GeoJSON Polygon | Geographic scope of the surge |
| `reason` | string | Human-readable description (e.g., "White Flag — temps below 32°F") |
| `status` | enum | `ACTIVE`, `DEACTIVATED`, `EXPIRED` |
| `deactivated_at` | ISO 8601 datetime (optional) | When surge ended |

#### Scenario: Surge activated for Raleigh White Flag event
- **WHEN** a Wake County CoC admin activates a SurgeEvent
- **THEN** a `surge.activated` Kafka event is published to the
  `fabt.surge.events` topic
- **AND** shelters within the bounding box are prompted to update their
  `overflow_available` field on their next BedAvailability snapshot
- **AND** outreach worker apps subscribed to the surge topic receive a
  push notification within 30 seconds

---

### Requirement: ShelterReservation object
The extension SHALL define a `ShelterReservation` soft-hold mechanism. A hold
removes beds from the `beds_available` count for a configurable window to
prevent double-booking while an outreach worker transports a guest.

**Fields:**

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Primary key |
| `location_id` | UUID | FK → HSDS `location.id` |
| `population_type` | PopulationType | Which bed type is held |
| `held_by` | string | Outreach worker identifier (non-PII — org + worker ID) |
| `held_at` | ISO 8601 datetime | When hold was created |
| `hold_expires_at` | ISO 8601 datetime | Auto-release time (default: 2 hours) |
| `status` | enum | `ACTIVE`, `CONFIRMED`, `CANCELLED`, `EXPIRED` |
| `confirmation_notes` | string (optional) | Shelter staff can add intake notes |

#### Scenario: Hold placed by outreach worker
- **WHEN** an outreach worker places a hold on a bed
- **THEN** `beds_available` for that `(location_id, population_type)` is
  decremented by 1 in the cache layer atomically (Redis DECRBY)
- **AND** the shelter receives a webhook notification with the hold details
- **AND** if the hold is not confirmed within `hold_expires_at`,
  the bed is automatically returned to available inventory

---

### Requirement: Query response contract
The public query endpoint SHALL return a ranked list of matching shelters.
Ranking criteria (in order): (1) distance from query origin, (2) beds_available
descending, (3) fewer constraints (lower barrier shelters ranked higher).

**Response envelope fields per shelter:**

| Field | Source |
|---|---|
| `shelter_name` | HSDS `organization.name` |
| `address` | HSDS `location.address` (omitted for DV) |
| `distance_miles` | Calculated from query lat/lng |
| `phone` | HSDS `phone.number` |
| `beds_available` | `BedAvailability.beds_available` |
| `population_type` | `BedAvailability.population_type` |
| `accepting_new_guests` | `BedAvailability.accepting_new_guests` |
| `constraints_summary` | Derived from `ShelterConstraints` |
| `data_age_seconds` | Seconds since `snapshot_ts` |
| `reservation_supported` | boolean |
| `surge_overflow_available` | integer (if SurgeEvent active in area) |

#### Scenario: No matching beds found
- **WHEN** a query returns zero matching shelters with `beds_available > 0`
- **THEN** the response includes `unmet_demand: true` and logs an
  `UnmetDemandEvent` to the analytics pipeline
- **AND** shelters matching all constraints but with `beds_available = 0`
  are returned with `waitlist_available` flag (if shelter supports it)

---

### Requirement: Non-functional — performance
- Query endpoint: p50 < 100ms, p95 < 500ms under 100 concurrent users
- Availability update: p95 < 200ms
- Cache TTL: Availability snapshots 60s L1, 300s L2
- Stale data indicator: `data_age_seconds` field always present in response

### Requirement: Non-functional — security
- All update and admin endpoints require authentication (API key or OAuth2)
- All query endpoints are public but rate-limited: 60 req/min per IP
- No PII stored or transmitted at any point
- DV shelter data access enforced at the data layer — not just API routing
- All API keys stored in AWS Secrets Manager; never in application.yml or HCL
- Audit log (`audit_log` table) captures every availability update with
  timestamp, shelter ID, operator ID, and before/after snapshot IDs

### Requirement: Non-functional — observability
- Micrometer metrics on every cache hit/miss, query latency, update latency,
  HMIS bridge delivery success/failure, surge activation events
- Structured JSON logs with `shelterId`, `populationType`, `traceId` on
  every availability update
- Health endpoint: `/actuator/health` exposes DB, Redis, Kafka liveness
- OTel trace propagation across reactive boundary (WebFlux → Kafka → bridge)

### Requirement: Non-functional — maintainability
- All enumerated values (PopulationType, SurgeStatus, ReservationStatus)
  defined as Java enums with HSDS profile JSON export — single source of truth
- `CacheNames` interface defines all cache name constants — no magic strings
- Resilience4J instance names follow `fabt-{target}` convention throughout
- Every HMIS vendor integration isolated behind a `HmisBridgePort` interface —
  new vendors added without touching core domain code
