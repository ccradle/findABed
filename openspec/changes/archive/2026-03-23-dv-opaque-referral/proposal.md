## Why

A family fleeing a violent partner is sitting in a social worker's car at 11 PM. The worker opens FABT and sees "DV Shelter — 3 beds available." But they can't refer the family — there's no way to contact the shelter without revealing its location in the system, and no way for the shelter to screen the referral for safety before accepting.

Today, FABT protects DV shelter data with Row Level Security (only users with `dvAccess=true` can see DV shelters in search results). But seeing availability is not enough — outreach workers need a way to **request a bed** at a DV shelter without the system ever storing who went where.

Federal law (VAWA 34 U.S.C. 12291(b)(2)) prohibits disclosure of PII "regardless of whether the information has been encoded, encrypted, hashed, or otherwise protected." FVPSA prohibits disclosing shelter locations. HUD prohibits DV providers from entering client data into shared HMIS. The system must facilitate the connection without becoming a record of it.

The pattern is a **token-based opaque referral with human-in-the-loop confirmation**: the system creates a time-limited referral token containing only operational data (household size, population type, urgency), the DV shelter staff reviews and accepts or rejects, and the actual placement happens via a warm handoff phone call — never through the system.

## What Changes

- **Referral token lifecycle**: Outreach worker requests a DV bed → system generates a referral token (no client PII, no shelter identity in the token) → DV shelter staff receives notification → staff accepts/rejects → if accepted, warm handoff callback number provided → token expires and is purged
- **DV shelter notification**: Real-time in-app notification to DV shelter coordinators when a referral token is created for their shelter. Push via existing event bus.
- **Safety screening UI**: DV shelter staff see only: household size, population type, special needs, urgency level, referring worker's callback number. They never see client name or any PII.
- **Token expiry and purge**: Tokens expire after a configurable window (default 4 hours). Expired tokens are hard-deleted (not soft-deleted) — no permanent record linking a referral to a shelter.
- **Warm handoff flow**: On acceptance, the referring outreach worker receives a callback number (shelter's intake line). The shelter address is shared verbally during the call, never stored in FABT.
- **Aggregate analytics**: Referral counts (requested/accepted/rejected/expired) per time period, without any identifying data. Supports HUD HIC/PIT aggregate reporting.
- **DV Referral addendum document**: A standalone document (`docs/DV-OPAQUE-REFERRAL.md`) explaining the legal basis, architecture, and privacy guarantees. Linked from README.
- **Demo screenshots**: Dedicated screenshot set showing the full DV referral flow (request → notify → screen → accept → warm handoff).
- **All changes on feature branch** `feature/dv-opaque-referral` from main — PR to main after full test suite passes

## Capabilities

### New Capabilities
- `dv-referral-token`: Token-based opaque referral lifecycle (create, accept, reject, expire, purge)
- `dv-referral-notification`: Real-time notification to DV shelter coordinators
- `dv-referral-screening`: Safety screening UI for DV shelter staff

### Modified Capabilities
- `bed-availability-query`: DV bed search results show "Request Referral" button instead of "Hold This Bed"
- `shelter-availability-update`: DV coordinator dashboard shows pending referral tokens

## Impact

- **New files (backend)**: `ReferralToken.java` (domain), `ReferralTokenRepository.java`, `ReferralTokenService.java`, `ReferralTokenController.java`, `ReferralTokenPurgeService.java` (@Scheduled hard-delete)
- **New files (frontend)**: DV referral request form component, DV coordinator screening view component, warm handoff confirmation component
- **New migration**: `V21__create_referral_token.sql` — referral_token table (no PII columns, FK to shelter with ON DELETE CASCADE)
- **Modified files**: `OutreachSearch.tsx` (conditional "Request Referral" for DV shelters), `CoordinatorDashboard.tsx` (pending referrals indicator), `SecurityConfig.java` (new endpoints), `README.md` (link to addendum)
- **New document**: `docs/DV-OPAQUE-REFERRAL.md` — legal basis, architecture, privacy guarantees
- **New screenshots**: DV referral flow captured in demo walkthrough
- **RLS enforcement fix**: During development, discovered that Testcontainers PostgreSQL uses a SUPERUSER role which bypasses RLS entirely. Integration tests were giving false confidence — DV shelter protection was not enforced in tests. Fixed by adding `SET ROLE fabt_app` in `RlsDataSourceConfig` when running as a superuser, and adding explicit `dvAccess` check in service layer as defense-in-depth.
- **Risk**: This feature has zero tolerance for PII leakage. Every code path must be reviewed against VAWA requirements. The token must never contain client-identifying data. The purge must be hard-delete, not soft-delete. RLS enforcement is verified at two layers: database (RLS policy) and service (explicit dvAccess check).
- **Branch strategy**: All changes on `feature/dv-opaque-referral` branch from main, PR after full test suite passes
