## Context

Outreach workers need shelter names and timestamps in the "My Referrals" list to manage multiple referrals efficiently. DV-authorized workers already see shelter names in search, so this change extends existing visibility while strictly hiding addresses.

## Goals / Non-Goals

**Goals:**
- Improve outreach worker efficiency with shelter names and time identifiers (Darius persona).
- Ensure offline availability (24h snapshot policy).
- Maintain high performance (No N+1 queries).
- Implement "Safety Checks" for deactivated shelters (Marcus persona).
- Ensure accessibility-first labels (Tomás persona).

**Non-Goals:**
- Displaying shelter addresses.
- Updating shelter names on existing tokens (snapshot only).

## Decisions

### Decision 1: Denormalized `shelter_name` in `referral_token`
- **Rationale**: We will add `shelter_name` to `referral_token` at creation. This ensures offline availability (Darius persona) and avoids N+1 queries. Given the 24h purge cycle, data redundancy is negligible.

### Decision 2: Safety Check for Inactive Shelters
- **Rationale**: Based on Marcus Webb's feedback, the `GET /mine` endpoint will perform an `active` check on the shelter. If a shelter is deactivated after referral creation, the worker will see "SHELTER_CLOSED" status in their list.

### Decision 3: Accessibility - Structured `aria-label`
- **Rationale**: Tomás Herrera's feedback ensures screen readers hear: *"Status: Accepted. Shelter: Safe Haven. Population: DV Survivor. Time: 2:15 PM."*

### Decision 4: Darius's Identifier (Time/Callback)
- **Rationale**: To distinguish referrals of the same population type, we will add the `createdAt` timestamp (short format) to the list view. 

### Decision 5: Security - Cache Mitigation
- **Rationale**: Elena Vasquez's feedback requires ensuring the frontend cache (IndexedDB) for `myReferrals` is cleared on logout or upon the 24h backend purge to minimize the PII-adjacent risk surface.
- **Implementation note (2026-04):** the production app does **not** persist `GET /dv-referrals/mine` in IndexedDB; referrals live in React session state and are **cleared on logout** (`OutreachSearch` + `AuthContext`). The 24h hard-delete on terminal tokens remains the server-side purge. If a future offline snapshot is added to IndexedDB, logout handlers must explicitly wipe that store.

## Risks / Trade-offs

- **[Risk] Data Redundancy**: Intentionally traded for offline performance.
- **[Risk] Inactive Shelter Complexity**: Adding a join/check for the safety check adds minor overhead.
    - **Mitigation**: Scoped to the `mine` list (typically < 20 active referrals).
