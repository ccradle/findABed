## Context

V52 (v0.36.0) added `shelter.active BOOLEAN NOT NULL DEFAULT TRUE` with SQL-level filtering in bed search. The column exists but has no admin UI, no cascade behavior, and no audit trail. The referral safety check (v0.36.0) already flags `PENDING` referrals for inactive shelters as `SHELTER_CLOSED` — this change builds the admin-facing workflow on top of that foundation.

Real-world shelter closures are common and varied: funding loss (Grand Junction, CO — 100 displaced), code violations (Jacksonville, FL — overnight ops halted), organizational failure (Portland, OR — 134+ beds lost), weather damage, and seasonal cycles (White Flag / Code Blue). The deactivation workflow must handle all these patterns safely, with special attention to DV shelters where address confidentiality and active referrals create safety-critical constraints.

## Goals / Non-Goals

**Goals:**
- Admin toggle to activate/deactivate shelters with a single action
- Cascade: expire active holds on deactivation, notify affected outreach workers
- DV safety gate: enhanced confirmation for DV shelters, restricted notifications
- Deactivation metadata (reason, timestamp, actor) for audit and seasonal support
- Coordinator visibility: grayed inactive shelters with disabled bed controls
- Audit trail: SHELTER_DEACTIVATED and SHELTER_REACTIVATED events

**Non-Goals:**
- Scheduled/automatic reactivation (seasonal shelters reactivate manually for now — auto-reactivation is a future enhancement)
- Soft-delete or hard-delete of shelters (deactivation is always reversible)
- HIC/PIT export changes (inactive shelters retain historical data; export logic already handles this)
- Notification to external systems (211 integration is out of scope for this change)
- `SEASONAL_CLOSED` as a distinct shelter status (we use the existing boolean + reason metadata instead of a status enum)

## Decisions

### D1: Two endpoints vs. single PATCH

**Decision:** Two dedicated endpoints: `PATCH /api/v1/shelters/{id}/deactivate` and `PATCH /api/v1/shelters/{id}/reactivate`.

**Alternatives considered:**
- Single `PATCH /api/v1/shelters/{id}` with `{active: false}` in body — simpler REST, but loses the ability to require a `reason` field on deactivation without making the update endpoint asymmetric.
- Single `PATCH /api/v1/shelters/{id}/status` with `{active: false, reason: "..."}` — reasonable, but the deactivation and reactivation flows have different validation (deactivation requires reason + cascade check; reactivation is immediate). Separate endpoints make this explicit.

**Rationale:** Deactivation is a lifecycle event with side effects (cascade, audit, notification), not a simple field update. Dedicated endpoints make the side effects visible in the API contract and simplify DemoGuard allowlisting.

### D2: Cascade behavior — expire holds, warn on DV referrals

**Decision:** On deactivation:
1. All HELD reservations for this shelter are transitioned to `CANCELLED_SHELTER_DEACTIVATED`.
2. Each affected outreach worker receives a persistent notification: "Your bed hold at {shelter} was cancelled because the shelter was deactivated."
3. If active PENDING DV referrals exist, the deactivation request returns a confirmation-required response listing them. Admin must acknowledge before proceeding.

**Alternatives considered:**
- Block deactivation entirely if active holds exist — too restrictive. Shelters close suddenly; forcing admin to track down each hold creator is impractical (Grand Junction model).
- Silently expire everything including DV referrals — violates VAWA safety principle. DV referrals involve people in active danger; bulk cancellation without acknowledgment is unsafe.

**Rationale:** Holds are operational convenience (outreach worker can re-search). DV referrals are safety-critical (Keisha: "showing 'Shelter closed' on a completed referral causes unnecessary panic"). Different treatment for different stakes.

### D3: Deactivation reason as VARCHAR, not enum

**Decision:** Store `deactivation_reason` as `VARCHAR(50)` in the database with application-level validation against a known set of values. The backend enum defines: `TEMPORARY_CLOSURE`, `SEASONAL_END`, `PERMANENT_CLOSURE`, `CODE_VIOLATION`, `FUNDING_LOSS`, `OTHER`.

**Alternatives considered:**
- PostgreSQL enum type — requires a migration to add new values. Too rigid for a field that may grow.
- Free-text field — no structure, can't filter or report on.

**Rationale:** Application-validated VARCHAR is the project's established pattern (see `PopulationType` — enum in Java, text in DB). Allows future reason values without migration.

### D4: DV safety gate mirrors existing DV toggle pattern

**Decision:** Reuse the existing DV confirmation dialog pattern from shelter-edit (role-gated, confirmation dialog, audit-logged). When deactivating a DV shelter:
1. Frontend shows an enhanced confirmation dialog listing active DV referral count.
2. Deactivation notification for DV shelters is restricted to users with `dvAccess=true`.
3. The notification text does NOT include the shelter address.

**Rationale:** Consistent UX pattern. The shelter-edit DV toggle already solved this interaction design; we extend rather than reinvent.

### D5: Coordinator sees inactive shelters but cannot act

**Decision:** Coordinators assigned to an inactive shelter see it in their dashboard with visual indicators (opacity 0.6, "Inactive" badge, disabled bed update controls). They cannot update availability for an inactive shelter. Tooltip: "This shelter was deactivated on {date}. Contact your CoC admin to reactivate."

**Alternatives considered:**
- Hide inactive shelters from coordinators entirely — confusing. Sandra: "Where did my shelter go?"
- Allow coordinators to reactivate — risky. Deactivation may be for safety or policy reasons the coordinator isn't aware of.

### D6: Migration is additive only

**Decision:** V53 adds three nullable columns to shelter: `deactivated_at TIMESTAMPTZ`, `deactivated_by UUID REFERENCES app_user(id)`, `deactivation_reason VARCHAR(50)`. No backfill needed — all existing shelters have `active=TRUE` and null deactivation metadata.

## Risks / Trade-offs

- **[Risk] Hold cascade during high-activity period** — if a shelter with 10 active holds is deactivated, 10 notifications fire simultaneously. → Mitigation: notifications are DB-backed (persistent_notification table), not real-time-only. SSE delivers them asynchronously. No thundering herd risk.
- **[Risk] Coordinator confusion on reactivation** — coordinator's availability data may be stale after a long inactive period. → Mitigation: reactivation does NOT restore previous availability. Coordinator must update bed counts after reactivation. UI shows "Beds: not yet updated" until first snapshot.
- **[Risk] DV referral in flight during deactivation** — a referral accepted 5 minutes before deactivation. → Mitigation: ACCEPTED/REJECTED referrals are terminal states; only PENDING referrals are flagged. This matches the v0.36.0 safety check behavior.
- **[Trade-off] No auto-reactivation for seasonal shelters** — Rev. Monroe must manually reactivate each season. Acceptable for MVP; auto-reactivation with `planned_reactivation_date` is a natural follow-up.
