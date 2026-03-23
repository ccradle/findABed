## Context

FABT already protects DV shelter data with PostgreSQL Row Level Security — only users with `dvAccess=true` see DV shelters in search results. But there is no referral mechanism. Outreach workers can see availability but cannot request a bed without an out-of-band phone call (which they may not have a number for).

Federal law (VAWA, FVPSA) prohibits storing PII about DV survivors in shared systems. The referral token must contain zero PII and must be purged after use. The DV shelter's identity must never be exposed to users without `dvAccess=true`.

The research document (`dv-privacy-research.md`) provides the full legal and technical analysis.

## Goals / Non-Goals

**Goals:**
- Enable outreach workers to request a DV bed placement through FABT without storing client PII
- Enable DV shelter staff to screen and accept/reject referrals with minimal operational data
- Facilitate a warm handoff (phone callback) for accepted referrals
- Hard-delete expired tokens — no permanent record of referrals
- Support aggregate analytics for HUD reporting (counts only, no PII)
- Document the legal basis and architecture in a standalone addendum

**Non-Goals:**
- Client intake forms (DV shelters use their own comparable database)
- Automated bed assignment (human-in-the-loop is required by safety screening)
- Chat or messaging between referring worker and shelter staff (phone is intentional — no digital trail)
- Multi-shelter referral fan-out (one token → one shelter, to prevent information leakage about which shelters exist)

## Decisions

### D1: Branch strategy

All changes on branch `feature/dv-opaque-referral` created from main. PR to main after full test suite passes.

### D2: Referral token schema — zero PII by design

The `referral_token` table stores operational data only:

```
referral_token
  id                UUID PK (gen_random_uuid)
  shelter_id        UUID FK → shelter (ON DELETE CASCADE)
  tenant_id         UUID FK → tenant
  referring_user_id UUID FK → app_user (the outreach worker)
  household_size    INTEGER (1-20)
  population_type   VARCHAR(50) (PopulationType enum)
  urgency           VARCHAR(20) ('STANDARD', 'URGENT', 'EMERGENCY')
  special_needs     VARCHAR(500) (free text: wheelchair, pets, medical — no names)
  callback_number   VARCHAR(50) (referring worker's phone for warm handoff)
  status            VARCHAR(20) ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED')
  created_at        TIMESTAMPTZ
  responded_at      TIMESTAMPTZ (when shelter staff accepted/rejected)
  responded_by      UUID (shelter staff user ID)
  expires_at        TIMESTAMPTZ (created_at + configurable window)
  rejection_reason  VARCHAR(500) (optional — e.g., "safety concern", no client details)
```

**What is NOT in this table:** client name, DOB, SSN, address, phone, or any identifier. The `callback_number` is the **worker's** number, not the client's. The `referring_user_id` identifies the worker, not the client.

**VAWA compliance check:** Even if the database is compromised, an attacker learns only "an outreach worker requested a DV bed at time T for a household of size N" — no way to identify the survivor.

### D3: Token lifecycle

```
PENDING → ACCEPTED → (warm handoff happens out-of-band) → purged after 24h
PENDING → REJECTED → purged after 24h
PENDING → EXPIRED (default 4h) → purged immediately
```

All terminal states (ACCEPTED, REJECTED, EXPIRED) are hard-deleted by `ReferralTokenPurgeService` within 24 hours. No audit trail of individual referrals is kept.

**Aggregate counters only:** Before purging, increment Micrometer counters: `fabt_dv_referral_total{status=accepted|rejected|expired}`. These counters survive purge and support HUD reporting.

### D4: Configurable expiry window

Add `dv_referral_expiry_minutes` to tenant config JSONB (default: 240 = 4 hours). Read from `ObservabilityConfigService` pattern (cached, 60s refresh).

### D5: RLS integration

The `referral_token` table inherits DV shelter RLS via the shelter FK join. Model the policy after `dv_bed_availability_access` in `V13__enable_rls_bed_availability.sql` — same `EXISTS` subquery pattern, different table name:
- Only users with `dvAccess=true` (via `current_setting('app.dv_access')`) can see referral tokens for DV shelters
- The referring outreach worker (who already has `dvAccess=true` to see DV shelters in search) can see their own pending tokens
- DV shelter coordinators see tokens for their assigned shelters

### D6: Notification via event bus

On token creation, publish `dv-referral.requested` event via the existing `EventBus`. The event payload includes only the token ID and shelter ID — no PII.

DV shelter coordinators see a notification indicator (badge count) on their dashboard. Clicking expands the pending referral with screening data.

### D7: Warm handoff — no shelter address in system

When DV shelter staff accepts a referral:
1. The token status changes to `ACCEPTED`
2. The referring outreach worker's dashboard shows "Referral accepted — call shelter intake"
3. The shelter's intake phone number is provided to the referring worker (from `shelter.phone`, which is already RLS-protected)
4. The shelter address is shared **verbally during the phone call**, never displayed in the system to the referring worker

Alternative considered: displaying the shelter address after acceptance. Rejected because FVPSA prohibits disclosure of shelter location, and the system cannot guarantee the worker's device isn't compromised.

### D8: UI flow — outreach worker side

In `OutreachSearch.tsx`, when a search result is a DV shelter (`dvShelter=true`):
- Replace "Hold This Bed" with "Request Referral"
- Clicking opens a modal: household size, population type, urgency, special needs, callback number
- Submit creates a referral token
- Worker's pending referrals appear in a "My Referrals" section with status and countdown

### D9: UI flow — DV coordinator side

In `CoordinatorDashboard.tsx`, for DV shelters:
- A "Pending Referrals" badge shows the count of PENDING tokens
- Expanding shows each pending referral: household size, population type, urgency, special needs, callback number, time remaining
- Two buttons: "Accept" and "Reject" (reject requires a reason)
- On accept: status changes, referring worker is notified, shelter phone number is revealed to the worker

### D10: DV Referral addendum document

Create `docs/DV-OPAQUE-REFERRAL.md` in the code repo (`finding-a-bed-tonight`). This document:
- Explains the legal basis (VAWA, FVPSA, HMIS prohibition)
- Describes the opaque referral architecture
- Lists what the system stores vs. what it never stores
- Describes the purge mechanism
- Provides a VAWA compliance checklist
- Is linked from the main README under a "DV Privacy" section

### D11: Demo screenshots

Add dedicated DV referral screenshots to the demo walkthrough:
- DV bed search result with "Request Referral" button
- Referral request form (modal)
- DV coordinator pending referral notification
- Safety screening view
- Acceptance confirmation + warm handoff prompt
- Aggregate analytics view (counts only)

These are captured alongside existing screenshots in `capture-screenshots.spec.ts`.

### D12: Aggregate analytics endpoint

`GET /api/v1/analytics/dv-referrals` — returns aggregate counts for a time range:
```json
{
  "period": "2026-03-01/2026-03-31",
  "requested": 47,
  "accepted": 38,
  "rejected": 4,
  "expired": 5,
  "averageResponseMinutes": 42
}
```

Backed by Micrometer counters and histograms, not by querying the referral_token table (which is purged). No PII in the response.

Metrics emitted:
- `fabt_dv_referral_total` (Counter, tag: status) — request/accept/reject/expire counts
- `fabt_dv_referral_response_seconds` (Timer) — duration from token creation to accept/reject
- `fabt_dv_referral_pending` (Gauge) — current count of PENDING tokens (queried on scrape)

### D14: RLS enforcement in tests — SET ROLE fix

During development, we discovered that Testcontainers PostgreSQL creates a SUPERUSER role (`fabt_test`). PostgreSQL superusers **always bypass RLS**, even with `FORCE ROW LEVEL SECURITY`. This means all integration tests were running without DV shelter protection — a test with `dvAccess=false` could see DV shelters.

**Production is safe**: The application connects as `fabt_app` (NOSUPERUSER, created in V16), so RLS enforces in production and local dev.

**Fix (two layers):**

1. **`RlsDataSourceConfig.applyRlsContext()`**: After setting `app.dv_access`, execute `SET ROLE fabt_app` to drop from superuser to the restricted application role. This makes RLS enforce in all environments, including tests. Use `RESET ROLE` is not needed because the connection returns to the pool and `SET ROLE` is re-executed on every `getConnection()` call.

2. **Service-layer defense-in-depth**: `ReferralTokenService.createToken()` explicitly checks `TenantContext.getDvAccess()` before proceeding. Even if RLS fails (misconfigured database, wrong role), the service layer rejects the request. This applies to all DV-sensitive operations, not just referrals.

**Why not just SET ROLE?** Defense in depth. The database layer (RLS) and the application layer (dvAccess check) both enforce independently. If either is misconfigured, the other catches it.

### D15: DV Referral Grafana Dashboard (optional)

A separate Grafana dashboard for DV referral analytics, distinct from the main FABT Operations dashboard. Separate because:
- DV referral volume patterns are sensitive even in aggregate (e.g., a spike might correlate with a publicized DV incident)
- CoCs may want different Grafana access controls for DV data vs. operational data

**Dashboard: FABT DV Referrals** (`fabt-dv-referrals`)

Panels:
1. **Referral Request Rate** — `rate(fabt_dv_referral_total{status="requested"}[1h])`
2. **Acceptance Rate** — `fabt_dv_referral_total{status="accepted"} / fabt_dv_referral_total{status="requested"} * 100`
3. **Response Time** — average minutes from request to accept/reject (via `fabt_dv_referral_response_seconds` histogram)
4. **Rejection Rate** — `rate(fabt_dv_referral_total{status="rejected"}[1h])`
5. **Expired Rate** — `rate(fabt_dv_referral_total{status="expired"}[1h])` (high rate = shelters not responding)
6. **Current Pending** — `fabt_dv_referral_pending` gauge (count of PENDING tokens)

Provisioned via Grafana JSON provisioning alongside the existing `fabt-operations` dashboard. Only available when `--observability` stack is active.

### D13: Counter persistence via Prometheus

Micrometer counters are in-memory — they reset to zero on backend restart. For durable DV referral analytics:
- When the optional observability stack is active (`--observability`), Prometheus scrapes and retains counter values long-term. The analytics endpoint queries Prometheus for historical data, falling back to in-memory counters when Prometheus is unavailable.
- Without the observability stack (Lite tier), counters reset on restart. This is a documented limitation: deployers who need durable DV referral analytics must enable the observability package.
- This trade-off is documented in the README (DV Privacy section) and in `docs/DV-OPAQUE-REFERRAL.md`.
