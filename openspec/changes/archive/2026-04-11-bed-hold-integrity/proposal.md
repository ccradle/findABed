# bed-hold-integrity

## Why

`bed_availability.beds_on_hold` is the field that drives bed search results. The formula `beds_available = beds_total - beds_occupied - beds_on_hold` is computed in the bed search hot path on every query (`BedSearchController.java:40`, `AvailabilityService.java:164`). When this field is too high, real beds are silently hidden from outreach workers, and the system fails at its core mission — finding a bed tonight for a person in crisis.

This field can drift away from the truth (the count of `reservation` rows with `status = 'HELD'` for that shelter+population). On the live findabed.org demo as of 2026-04-11, **17 shelter+population pairs have phantom holds, totaling 24 beds that the bed search reports as held but are not backed by any reservation row**. The founder discovered this while investigating "I see 3 beds held at Downtown Warming Station, but I suspect they're all expired and I have no way to check without running SQL." Investigation confirmed the suspicion and revealed the bug class is much wider than the originally reported instance.

The bug is **not** in the reservation expiry job — that job is healthy. Every `EXPIRED` reservation correctly transitioned and the `cancelled_at` timestamps line up with the auto-expiry runs. The bug is structural: the `beds_on_hold` value is denormalized from the `reservation` table without write-time enforcement. **Three independent write paths can introduce drift, and not one of them reconciles against the source of truth.**

The persona drivers and their concerns are:

- **🔥 Sam Okafor (performance, capacity math)** — *the program-harm voice*. This is not a demo cosmetic issue. The same bug class would affect every real-tenant deployment. Outreach workers searching for beds are silently routed away from shelters that actually have capacity. A person seeking shelter is told "no" when there is in fact a bed available. **This is the worst kind of bug for FABT: silently invisible, biased toward affecting the most vulnerable populations, and indistinguishable from legitimate "no availability" without DB access.**
- **🔧 Marcus Webb (backend, data integrity)** — `beds_on_hold` is denormalization without an enforcement mechanism. Denormalization is a defensible optimization, but the cost of denormalization is that EVERY write path must maintain the invariant. We have three write paths and not one of them does. The principle violated is "single write path discipline for any cached value derived from elsewhere."
- **🐘 Elena Vasquez (PostgreSQL, schema)** — the table has `CHECK (beds_on_hold >= 0)` and `CHECK (beds_occupied + beds_on_hold <= beds_total + overflow_beds)`, but no constraint linking `beds_on_hold` to the count of `HELD` reservation rows. The denormalization is structurally unenforced at the database layer. Triggers were considered and rejected (D3 in design.md) — they are operationally hard to debug and create cross-table commit dependencies. The fix lives at the application layer.
- **⚖️ Casey Drummond (audit, chain-of-custody)** — phantom holds appear in capacity reports without provenance. There is no `reservation` row to point at, no actor, no timestamp, no reason. An auditor asking "why are 3 beds held at Downtown Warming Station?" today has no answer. That is a chain-of-custody failure independent of the program-harm risk.
- **🏗️ Alex Chen (architecture)** — the canonical source of truth is the `reservation` table. `bed_availability.beds_on_hold` is a derived value masquerading as authoritative. The permanent fix is to stop pretending it is authoritative and route every write through a single method that recomputes from the source.
- **🧪 Riley Cho (test design)** — there is **zero existing test** that catches this bug class. The test that should exist is an invariant assertion: `beds_on_hold === COUNT(reservation WHERE shelter_id=X AND population_type=Y AND status='HELD')` after every reservation lifecycle event. That test does not exist anywhere in the test suite. Without it, a future refactor could silently reintroduce the same bug class.
- **📋 Marcus Okafor (CoC admin practitioner)** — the related enhancement #101 (Bed Maintenance UI) is the operator-facing tool. The two are complementary: this RCA prevents most drift automatically and surfaces what remains; the Bed Maintenance UI handles the cases that need human judgment. The two should ship together as a coherent "bed hold integrity" story.
- **🤝 The founder** — this is the second piece of personally-experienced-and-reported pain (after the v0.32.3 notification bell hotfix). The pattern is real: founder-as-user finds bugs that no automated test catches because no test exists at the level the founder operates at.

This change closes [GitHub issue #102](https://github.com/ccradle/finding-a-bed-tonight/issues/102), is the structural counterpart to [#101](https://github.com/ccradle/finding-a-bed-tonight/issues/101) (Bed Maintenance enhancement), and is **production-blocking for the next real-tenant deployment** per the founder decision recorded in #102's `priority:high` label and severity escalation comment.

## What Changes

This is a **bundled structural fix** with seven coherent components. They ship together because the fix is coherent only as a bundle — partial fixes leave open drift sources.

**Backend — single write path discipline (Component 1)**

- New private method `ReservationService.recomputeBedsOnHold(shelterId, populationType, actor, notes)` that:
  1. Queries `reservation` table for `COUNT(*) WHERE status = 'HELD' AND shelter_id = ? AND population_type = ?`
  2. Reads the latest `bed_availability` snapshot for that shelter+population to preserve `beds_total`, `beds_occupied`, `accepting_new_guests`, `overflow_beds`
  3. Calls `availabilityService.createSnapshot(...)` with the actual count, never with delta math
- Replaces the existing `adjustAvailability(reservation, +/-1, ...)` calls in `createReservation`, `cancelReservation`, `expireReservation` with `recomputeBedsOnHold(reservation.shelterId, reservation.populationType, ...)`
- Eliminates Finding 1 (delta-against-stale-baseline) entirely

**Backend — manual PATCH endpoint no longer accepts `beds_on_hold` (Component 2)**

- `AvailabilityController.updateAvailability` strips `bedsOnHold` from the request DTO consumption. The field becomes server-managed only.
- `AvailabilityUpdateRequest.bedsOnHold` field is **deprecated** with a Javadoc note. Kept in the record for backward compat for one release window. Logged as a `WARN` if non-null and non-zero, ignored.
- The current "TC-2.7 hold protection" lower-bound check (`Math.max(requestedHold, activeHeldCount)`) becomes redundant and is removed.
- Eliminates Finding 2 (manual coordinator drift) entirely

**Backend — new offline-hold endpoint for legitimate manual override (Component 3)**

- New endpoint `POST /api/v1/shelters/{shelterId}/manual-hold` for the legitimate "coordinator marks beds as held for offline reasons" use case (phone reservations, expected guests).
- Creates a real `reservation` row with `user_id` = the requesting coordinator, `status = 'HELD'`, `expires_at = now() + tenant.hold_duration_minutes`, `notes = "Manual offline hold: <reason>"`.
- The next `recomputeBedsOnHold()` (called automatically by the create path) picks up the new reservation and writes a fresh snapshot.
- Preserves the legitimate manual override workflow without bypassing the invariant.

**Backend — Spring Batch reconciliation tasklet (Component 4)**

- New `BedHoldsReconciliationJobConfig` (Spring Batch job, modeled on `ReferralEscalationJobConfig`).
- Single tasklet that:
  1. SELECT-joins the latest `bed_availability` snapshots with `COUNT(*) FILTER (WHERE status = 'HELD')` from `reservation` grouped by `(shelter_id, population_type)`
  2. For every row where the snapshot value differs from the actual count, calls `recomputeBedsOnHold()` to write a corrective snapshot tagged `updated_by = 'system:reconciliation'`
  3. Writes one `audit_events` row per correction with the new event type `BED_HOLDS_RECONCILED`
  4. Logs every correction at INFO level
  5. Emits Micrometer metrics: `fabt.bed.hold.reconciliation.batch.duration` Timer, `fabt.bed.hold.reconciliation.corrections.total` Counter
- Scheduled via `@Scheduled(fixedDelay = 5 * 60 * 1000)` invoking `JobLauncher.run(reconciliationJob, ...)` — same pattern as the escalation batch
- Wrapped in `TenantContext.runWithContext(null, true, ...)` per Elena Vasquez's RLS requirement so DV shelters are visible (same gotcha as the existing `ReservationExpiryService`)
- Defense-in-depth, not the primary fix. Catches drift from any future unforeseen source.

**Backend — new audit event type (Component 5)**

- Add `public static final String BED_HOLDS_RECONCILED = "BED_HOLDS_RECONCILED"` to `AuditEventTypes.java`
- Written by the reconciliation tasklet whenever a corrective snapshot is fired
- Payload: `{shelter_id, population_type, snapshot_value_before, actual_count, delta}`

**Seed fix (Component 6)**

- Update `infra/scripts/seed-data.sql` to back every `bed_availability` row with `beds_on_hold = N > 0` by inserting N matching `reservation` rows with `status = 'HELD'`, realistic `expires_at` (mix of past and future for demo realism), and `user_id = 'b0000000-0000-0000-0000-000000000001'` (admin sentinel).
- Eliminates the seed source of drift permanently. After this change, `--fresh` produces a clean baseline.

**One-time backfill migration (Component 7)**

- New Flyway migration `V40__backfill_phantom_beds_on_hold.sql` (next available version on the demo) that performs a one-time data correction:
  - For every shelter+population where the latest `bed_availability` snapshot has `beds_on_hold > COALESCE(actual_held_count, 0)`, insert a new snapshot reconciling the value, tagged `updated_by = 'V40-rca-backfill'`
- Append-only, audit-traceable, idempotent (re-running inserts zero rows)
- Runs once at deploy time

**Tests — invariant assertion + reconciliation tests (gating)**

- New `BedHoldsInvariantTest` — for every reservation lifecycle event in `ReservationCreateTest`, `ReservationCancelTest`, `ReservationExpiryTest`, add a tail assertion verifying `beds_on_hold === COUNT(reservation WHERE shelter_id=X AND population_type=Y AND status='HELD')`.
- New `BedHoldsReconciliationJobTest` — seed a shelter with `beds_on_hold = 5` and zero HELD reservations, run the reconciliation job, assert a corrective snapshot exists with `beds_on_hold = 0` and `updated_by = 'system:reconciliation'`, assert the `BED_HOLDS_RECONCILED` audit row was written.
- New `OfflineHoldEndpointTest` — POST creates a real HELD reservation, the next bed search reflects the new hold via the existing recompute path.

## Out of scope (NOT in this change)

- **Dropping the `beds_on_hold` column entirely** (Option D1 in the design discussion). Considered and rejected for blast radius. The denormalization stays as a read optimization; only the write paths are disciplined.
- **Database triggers on the `reservation` table** (Option D3). Considered and rejected by Elena Vasquez — operationally hard to debug, create cross-table commit dependencies, brittle.
- **Hard rejection of `beds_on_hold` in PATCH** (vs. current proposal which logs a warning and ignores). Deferred to v0.34.0 to give external API consumers one release window of soft deprecation.
- **Multi-instance ShedLock for the reconciliation job**. Current FABT deployment is single-instance. Multi-instance future-proofing deferred. The reconciliation job is idempotent under concurrency (two instances writing the same correction is wasteful but not corrupting).
- **Migrating the existing `ReservationExpiryService` from `@Scheduled` to Spring Batch**. Out of scope; that service's work is fundamentally per-row and the existing pattern is fine. Only the new reconciliation job uses Spring Batch.
- **The Bed Maintenance admin UI** (issue #101). That is a separate change tracked independently. The two issues are cross-linked but the UI is operator-facing and this RCA is structural.
