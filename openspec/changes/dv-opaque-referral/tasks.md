## 1. Branch Setup

- [x] 1.1 Create branch `feature/dv-opaque-referral` from main: `git checkout -b feature/dv-opaque-referral`

## 2. DV Referral Addendum Document

- [x] 2.1 Create `docs/DV-OPAQUE-REFERRAL.md` in code repo: legal basis section (VAWA, FVPSA, HMIS prohibition, NC G.S. 8-53.12)
- [x] 2.2 Architecture section: opaque referral token design, zero-PII guarantee, purge mechanism
- [x] 2.3 What FABT stores vs. what it never stores — explicit table
- [x] 2.4 VAWA compliance checklist (can be used by deploying CoCs for self-assessment)
- [x] 2.5 Warm handoff flow diagram (text-based ASCII, no external tool dependency)
- [x] 2.6 Analytics durability note: counters reset on restart without observability stack; Prometheus provides long-term retention (D13)
- [x] 2.7 Link from README.md under a "DV Privacy" section with link to addendum

## 3. Database Migration — Referral Token Table

- [x] 3.1 Create `V21__create_referral_token.sql`: table with all columns, FKs, ON DELETE CASCADE
- [x] 3.2 CHECK constraints: status IN (PENDING/ACCEPTED/REJECTED/EXPIRED), urgency IN (STANDARD/URGENT/EMERGENCY), household_size 1-20
- [x] 3.3 Index: `idx_referral_token_shelter_status` on (shelter_id, status)
- [x] 3.4 Index: `idx_referral_token_user` on (referring_user_id, status)
- [x] 3.5 Partial UNIQUE index: `uq_referral_token_pending` on (referring_user_id, shelter_id) WHERE status='PENDING'
- [x] 3.6 RLS enabled with `dv_referral_token_access` policy (EXISTS subquery via shelter FK, same as V13/V15 pattern)
- [x] 3.7 Updated `docs/schema.dbml` with `referral_token` table + V20/V21 sections
- [x] 3.8 Verified: V21 migration ran clean, referral_token table exists, Flyway shows V21

## 4. Backend Domain and Repository

- [x] 4.1 Created `ReferralToken.java` domain class in `org.fabt.referral.domain` with zero-PII fields
- [x] 4.2 Created `ReferralTokenRepository.java` with JdbcTemplate: insert, findById, findPendingByShelterId, findByUserId, updateStatus, expirePendingTokens, purgeTerminalTokens, countPendingByShelterId
- [x] 4.3 Added `dv_referral_expiry_minutes: 240` to seed-data.sql tenant config JSONB
- [x] 4.4 Added 2 ArchUnit rules: referral repository boundary + referral domain entity boundary

## 4b. RLS Enforcement Fix (D14)

- [x] 4b.1 `RlsDataSourceConfig.applyRlsContext()`: always executes `SET ROLE fabt_app` — drops superuser to restricted role, RLS enforces in all environments
- [x] 4b.2 `ReferralTokenService.createToken()`: explicit `TenantContext.getDvAccess()` check, throws `AccessDeniedException` — defense-in-depth independent of RLS
- [x] 4b.3 `DvAccessRlsTest` passes — updated to use `fabt_app` role (V16) instead of creating separate test role; `TenantContext.setDvAccess(true)` for test data setup
- [x] 4b.4 `tc_noDvAccess_cannotCreate` passes — outreach worker with dvAccess=false is now blocked by service-layer check
- [x] 4b.5 Covered by tc_noDvAccess_cannotCreate — service rejects with AccessDeniedException before DB query; RLS would also block
- [x] 4b.6 Added "Defense in Depth (D14)" section to `docs/DV-OPAQUE-REFERRAL.md`
- [x] 4b.7 Fixed `@Scheduled` jobs: `ReferralTokenPurgeService` and `ReferralTokenService.expireTokens()` set `TenantContext.dvAccess=true` for RLS access
- [x] 4b.8 Fixed `AvailabilityIntegrationTest.test_dvShelters_excludedWithoutDvAccess()` — uses dvAccess=true user to create DV shelter
- [x] 4b.9 Full suite: 193 tests, 0 failures with RLS enforcing on every connection

## 5. Backend Service — Token Lifecycle

- [x] 5.1 Created `ReferralTokenService.java` in `org.fabt.referral.service`
- [x] 5.2 `createToken()`: validates dvShelter=true, creates token with expires_at from tenant config, publishes `dv-referral.requested` event, increments counter
- [x] 5.3 `acceptToken()`: validates PENDING + not expired, sets ACCEPTED, publishes `dv-referral.responded` event, increments counter
- [x] 5.4 `rejectToken()`: validates PENDING + not expired, requires reason, sets REJECTED, publishes event, increments counter
- [x] 5.5 `expireTokens()`: @Scheduled(fixedRate=60000), expires PENDING tokens past expires_at, increments counter
- [x] 5.6 `getShelterPhoneForToken()`: returns shelter.phone for ACCEPTED tokens only, never address

## 6. Backend Service — Token Purge

- [x] 6.1 Created `ReferralTokenPurgeService.java`: @Scheduled(fixedRate=3600000), hard-deletes terminal tokens older than 24h
- [x] 6.2 Logs purge count at INFO level
- [x] 6.3 Purge uses DELETE (hard-delete) via `purgeTerminalTokens()` — no soft-delete

## 7. Backend API — Referral Controller

- [x] 7.1 Created `ReferralTokenController.java` in `org.fabt.referral.api`
- [x] 7.2 `POST /api/v1/dv-referrals`: creates token, returns 201. Request validated with @Valid
- [x] 7.3 `GET /api/v1/dv-referrals/mine`: lists user's tokens, includes shelter phone on ACCEPTED, never address
- [x] 7.4 `GET /api/v1/dv-referrals/pending?shelterId={id}`: lists PENDING tokens for coordinator screening
- [x] 7.5 `PATCH /api/v1/dv-referrals/{id}/accept`: accepts token, returns shelter phone for warm handoff
- [x] 7.6 `PATCH /api/v1/dv-referrals/{id}/reject`: rejects with reason via `RejectReferralRequest`
- [ ] 7.7 `GET /api/v1/analytics/dv-referrals?from={date}&to={date}`: aggregate analytics — requires COC_ADMIN/PLATFORM_ADMIN. Returns counts from Micrometer/Prometheus counters, no PII.
- [x] 7.8 Added `/api/v1/dv-referrals/**` to `SecurityConfig.java` as authenticated, fine-grained via @PreAuthorize
- [x] 7.9 All endpoints have OpenAPI @Operation annotations emphasizing zero-PII design

## 8. Frontend — Outreach Worker Referral Flow

- [x] 8.1 DV shelter results show "Request Referral" (purple) instead of "Hold This Bed" when `dvShelter=true`
- [x] 8.2 Referral modal: household size, urgency (STANDARD/URGENT/EMERGENCY buttons), special needs, callback number
- [x] 8.3 On submit: POST to `/api/v1/dv-referrals`, refreshes My Referrals
- [x] 8.4 "My DV Referrals" collapsible section: pending (countdown), accepted (shelter phone), rejected (reason), expired
- [x] 8.5 `data-testid` on: modal, form fields, submit button, referral list, individual referrals, phone display
- [x] 8.6 i18n: 28 EN + 28 ES strings for referral labels, statuses, modal, screening

## 9. Frontend — DV Coordinator Screening View

- [x] 9.1 DV shelters show "N referral(s)" badge when expanded with pending referrals
- [x] 9.2 Screening view: household size, population type, urgency pill, special needs, callback number, time remaining
- [x] 9.3 Accept (instant) and Reject (inline reason input with PII advisory via i18n placeholder)
- [x] 9.4 Accept: PATCH to API, removes from pending list
- [x] 9.5 Reject: inline reason input → PATCH to API, removes from pending list
- [x] 9.6 Time remaining displayed; expired tokens handled by server-side expiry scheduler
- [x] 9.7 `data-testid` on: screening container, individual referrals, accept/reject buttons, reject reason input
- [x] 9.8 i18n included in section 8.6 (28 shared EN/ES strings cover both outreach and coordinator views)

## 9b. Grafana DV Referral Dashboard (D15)

- [x] 9b.1 Added `fabt_dv_referral_response_seconds` Timer to `ReferralTokenService` — records duration from creation to accept/reject
- [ ] 9b.2 Add `fabt_dv_referral_pending` Gauge to `ReferralTokenService` — backed by global count query (deferred to test phase)
- [x] 9b.3 Created `grafana/dashboards/fabt-dv-referrals.json` — 6 panels: request rate, acceptance %, response time, rejection rate, expired rate, totals by status
- [x] 9b.4 Dashboard auto-loads via existing `dashboard-provider.yaml` (loads all JSON from dashboards/)
- [x] 9b.5 Updated runbook: DV referral dashboard section with panel descriptions, investigation guide for high expiry rate
- [x] 9b.6 Updated `docs/DV-OPAQUE-REFERRAL.md`: Grafana Dashboard section with panel table and separation rationale

## 10. Integration Tests

- [x] 10.1 `DvReferralIntegrationTest.java`: tc_create_accept_warmHandoff — full lifecycle with warm handoff verification
- [x] 10.2 tc_create_reject_workerSeesReason — reject with reason, worker sees it in /mine
- [x] 10.3 tc_create_expire_statusChange — force expiry, verify EXPIRED status
- [x] 10.4 tc_noDvAccess_cannotCreate — RLS blocks DV shelter lookup for non-dvAccess users
- [x] 10.5 tc_nonDvShelter_rejected — 400 for non-DV shelter
- [x] 10.6 tc_duplicatePending_rejected — 409 for duplicate PENDING token
- [x] 10.7 tc_accepted_includesPhone_notAddress — warm handoff phone included, address excluded
- [x] 10.8 Same as 10.7 — verified in both accept response and /mine list
- [x] 10.9 tc_purge_hardDeletes — verify row count goes to 0 after purge
- [ ] 10.10 Analytics endpoint test (deferred with task 7.7 — requires Prometheus integration)
- [x] 10.11 tc_coordinatorSeesOnlyAssignedShelters — pending list by shelterId
- [x] 10.12 tc_expiredToken_cannotAccept — expired token returns 4xx on accept
- [x] 10.13 tc_referralDoesNotAffectAvailability — beds_on_hold unchanged after referral create+accept

## 11. Playwright Tests — DV Referral Flow

- [x] 11.1 DV shelter search result shows "Request Referral" (data-testid: `request-referral-*`)
- [x] 11.2 Referral modal opens, fields fillable, submit button enabled
- [x] 11.3 "My Referrals" section shows pending token after submit
- [x] 11.4 Coordinator dashboard loads with cards (badge appears only if pending referrals exist)
- [x] 11.5 Screening view shows operational data (household, callback), verifies no PII fields
- [x] 11.6 Accept referral removes from pending list
- [x] 11.7 Reject referral with reason via inline input

## 12. Karate API Tests

- [x] 12.1 `dv-referral-lifecycle.feature`: create → accept → verify shelterPhone present, address absent
- [x] 12.2 `dv-referral-security.feature`: non-DV shelter → 400, duplicate → 409, no dvAccess → RLS block
- [x] 12.3 ACCEPTED response assertions: `response.shelterPhone == '#notnull'`, `!contains { addressStreet }`

## 13. Demo Screenshots — DV Referral Flow

- [x] 13.1 dv-01: DV shelter search results with purple "Request Referral" button
- [x] 13.2 dv-02: Referral request modal filled with household=4, URGENT, special needs, callback
- [x] 13.3 dv-03: "My DV Referrals" with pending token and countdown
- [x] 13.4 dv-04: Coordinator screening view with "1 referral" badge + pending referral details
- [x] 13.5 dv-05: Accepted referral — referral removed from pending list
- [x] 13.6 dv-06: Warm handoff — worker sees shelter intake phone number
- [x] 13.7 dv-07: Reject with reason — inline input with "No capacity for pets"
- [x] 13.8 Created `capture-dv-screenshots.spec.ts` — dedicated DV referral capture with beforeAll reset
- [x] 13.9 Created `demo/dvindex.html` — standalone DV referral walkthrough (7 screenshots), linked from main index.html

## 14. Documentation

- [x] 14.1 README DV Privacy section with links to addendum and DV demo walkthrough
- [x] 14.2 README Project Status: added "Completed: DV Opaque Referral" section
- [x] 14.3 README test counts: 193 backend, 70 Playwright, 40 Karate, grand total 303
- [x] 14.4 README file structure: added referral module (5 files), migration V21
- [x] 14.5 Runbook: DV referral operations section (expiry, purge, RLS D14, monitoring)
- [x] 14.6 Docs repo README: added DV referral walkthrough link

## 15. Full Regression and PR

- [x] 15.1 Backend: 193 tests, 0 failures (19 ArchUnit rules, 11 DV referral tests)
- [x] 15.2 Playwright: 70 tests, 0 failures (7 DV referral tests with beforeAll reset)
- [x] 15.3 Karate: 40 tests, 0 failures (4 DV referral scenarios with reset helper)
- [x] 15.4 Gatling: 3 simulations, 0 KO, 100% under 800ms
- [ ] 15.5 Commit all changes on `feature/dv-opaque-referral` branch
- [ ] 15.6 Push branch, create PR to main
- [ ] 15.7 Merge PR to main
- [ ] 15.8 Delete feature branch
- [ ] 15.9 Tag release (v0.10.0)
