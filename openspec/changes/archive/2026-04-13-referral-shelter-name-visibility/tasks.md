## 0. Setup

- [x] 0.1 Switch to implementation directory `finding-a-bed-tonight`.
- [x] 0.2 Create and switch to new branch `feature/issue-92-referral-shelter-name` from `main`.

## 1. Database & Domain (Backend)

- [x] 1.1 Create migration `V51__add_referral_shelter_name.sql` adding `shelter_name` column.
- [x] 1.2 Update `ReferralToken` domain model to include `shelterName` field.
- [x] 1.3 Update `ReferralTokenRepository` `ROW_MAPPER` to read `shelter_name`.
- [x] 1.4 Update `ReferralTokenRepository.insert` to persist `shelter_name`.
- [x] 1.5 Update `ReferralTokenController` creation path to include `shelterName` in audit details (via `ApplicationEventPublisher` → `AuditEventRecord`, `AuditEventTypes.DV_REFERRAL_REQUESTED`).
- [x] 1.6 Add `V52__shelter_active_flag.sql` and `Shelter.active` so `listMine` safety check compiles; exclude inactive shelters from bed search.

## 2. Service & API (Backend)

- [x] 2.1 Update `ReferralTokenService.createToken` to fetch and snapshot shelter name.
- [x] 2.2 Update `ReferralTokenResponse` record to include `shelterName` and ensure `createdAt` is provided.
- [x] 2.3 Implement "Safety Check" (join/filter) in `ReferralTokenController.listMine` to flag deactivated shelters as `SHELTER_CLOSED` (with intake phone withheld when flagged).
- [x] 2.4 Update `ReferralTokenController` and `ReferralTokenResponse.from` to reflect the above.

## 3. Frontend Implementation

- [x] 3.1 Update `ReferralToken` interface in `OutreachSearch.tsx`.
- [x] 3.2 Update `OutreachSearch.tsx` list rendering to display `shelterName` and a formatted time suffix (e.g., `2:15 PM`).
- [x] 3.3 Implement `aria-label` for list items following Tomás persona (Status first).
- [x] 3.4 Ensure `myReferrals` in-session list is cleared on logout (`useAuth` + `OutreachSearch`); documented in `design.md` (no IndexedDB cache today).

## 4. Verification & Testing

- [x] 4.1 Integration Test: Verify `shelterName` is persisted and returned (`DvReferralIntegrationTest.tc_create_includesShelterName_snapshotInCreateAndMine`).
- [x] 4.2 Integration Test: Verify "Safety Check" correctly returns `SHELTER_CLOSED` for deactivated shelters (`tc_deactivatedShelter_mineShowsShelterClosed`).
- [x] 4.3 Playwright Test: Verify shelter name and time identifiers in "My DV Referrals" (`dv-outreach-worker.spec.ts`).
- [x] 4.4 ~~Playwright Test: Verify "Rename" edge case~~ — covered by API integration test `tc_shelterRenamed_snapshotPreservesOriginalName` (war room 2026-04-12). Playwright-level test deferred as the API contract is the load-bearing assertion.
- [ ] 4.5 Playwright Test: Verify offline persistence of `myReferrals` list — deferred until IndexedDB snapshot exists.
