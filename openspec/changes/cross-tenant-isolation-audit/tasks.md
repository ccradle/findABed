## 1. Phase 1 — Foundations (0.5 day)

- [x] 1.1 Create branch `feature/cross-tenant-isolation-audit` from current main in the code repo
- [x] 1.2 Add `org.fabt.shared.security.TenantUnscoped` annotation (runtime retention, `@Target(METHOD)`, single `String value()` — conceptually the justification; named `value` for positional shorthand per Java convention) with Javadoc explaining the contract and citing design D2
- [x] 1.3 Add `TenantGuardArchitectureTest` skeleton under `backend/src/test/java/org/fabt/architecture/` that compiles but is `@Disabled` until Phase 3 — documents the intended rule in its Javadoc
- [x] 1.4 Document the `findByIdAndTenantId` + `findByIdOrThrow` pattern in `docs/FOR-DEVELOPERS.md` under a new "Tenant guard convention" section, linking to the `ReferralTokenService` reference implementation
- [x] 1.5 Commit Phase 1 and verify CI stays green (no behavior change; no new failing tests)

## 2. Phase 2 — Service fixes (VULN-HIGH + VULN-MED + renames) (2 days)

### 2.1 TenantOAuth2ProviderService (VULN-HIGH)

- [x] 2.1.1 Add `findByIdAndTenantId(UUID id, UUID tenantId)` to `TenantOAuth2ProviderRepository` using the V21 `findByIdAndTenantId` reference SQL shape
- [x] 2.1.2 Add `findByIdOrThrow(UUID id)` helper in `TenantOAuth2ProviderService` that pulls `TenantContext.getTenantId()`
- [x] 2.1.3 Refactor `TenantOAuth2ProviderService.update(UUID id, ...)` to route through `findByIdOrThrow`
- [x] 2.1.4 Refactor `TenantOAuth2ProviderService.delete(UUID id)` to route through `findByIdOrThrow` (replaces both the bare `findById` AND the bare `existsById(UUID)` on line 86)
- [x] 2.1.5 Write 2 integration tests mirroring `DvReferralIntegrationTest`: (a) cross-tenant 404 on both `update` and `delete`, (b) Tenant B's OAuth2 provider row is unchanged after both attempts (`issuerUri`, `clientId`, `clientSecret`, `updated_at` identical to pre-attempt state)
- [x] 2.1.6 **[URL-path-sink class, design D11]** Refactor `TenantOAuth2ProviderService.create` to drop the `UUID tenantId` parameter and source the value from `TenantContext.getTenantId()` internally. Update `OAuth2ProviderController.create` to validate the URL path `{tenantId}` matches `TenantContext.getTenantId()` and throw `NoSuchElementException` → 404 on mismatch (symmetric with D3 for read paths). Do not silently redirect the write; do not use 403 (would leak tenant existence).
- [x] 2.1.7 Write 1 integration test `tc_create_crossTenant_urlPath_returns404_noRowInsertedForTenantB` — Tenant A admin `POST /api/v1/tenants/{tenantB-uuid}/oauth2-providers` with an attacker-shaped create body (malicious `issuerUri`), assert 404 Not Found, assert zero rows inserted into `tenant_oauth2_provider` for Tenant B (and zero for Tenant A since the controller guard should short-circuit before the service runs).

### 2.2 ApiKeyService (VULN-HIGH)

- [x] 2.2.1 Add `findByIdAndTenantId(UUID id, UUID tenantId)` to `ApiKeyRepository`
- [x] 2.2.2 Add `findByIdOrThrow(UUID id)` helper in `ApiKeyService`
- [x] 2.2.3 Refactor `ApiKeyService.rotate(UUID keyId)` to route through `findByIdOrThrow`
- [x] 2.2.4 Refactor `ApiKeyService.deactivate(UUID keyId)` to route through `findByIdOrThrow`
- [x] 2.2.5 Write 2 integration tests: (a) cross-tenant 404 on both `rotate` and `deactivate`, (b) Tenant B's API key row unchanged (`active`, `rotated_at`, `updated_at` identical to pre-attempt state)
- [x] 2.2.6 **[D11 latent fix, warroom 2026-04-15]** Refactor `ApiKeyService.create` to drop the `UUID tenantId` parameter and source from `TenantContext.getTenantId()` internally. Update `ApiKeyController.createApiKey` to stop passing the pass-through. Update all test call sites (13 in `ApiKeyAuthTest`, 1 in `ApiKeyRateLimitTest`) to wrap calls in `TenantContext.runWithContext` / `callWithContext`. This is NOT a live vulnerability today (controller already sources from `TenantContext`) but the signature is an attractive-nuisance the Phase 3 ArchUnit Family B rule will flag; fixing now keeps Family B strict (no exception list required).

### 2.3 TotpController admin endpoints (VULN-HIGH)

- [ ] 2.3.1 Refactor `TotpController.disableUserTotp(UUID id)` to call `userService.getUser(id)` (existing tenant-scoped method) instead of bare `userRepository.findById(id)`
- [ ] 2.3.2 Refactor `TotpController.adminRegenerateRecoveryCodes(UUID id)` identically
- [ ] 2.3.3 Write 2 integration tests: (a) cross-tenant 404 on both `disableUserTotp` and `adminRegenerateRecoveryCodes`, (b) Tenant B user's TOTP state unchanged (`totp_enabled`, `totp_secret`, recovery codes row count identical to pre-attempt state)

### 2.4 SubscriptionService.delete (VULN-HIGH)

- [ ] 2.4.1 Add `findByIdAndTenantId(UUID id, UUID tenantId)` to `SubscriptionRepository`
- [ ] 2.4.2 Add `findByIdOrThrow(UUID id)` helper in `SubscriptionService`
- [ ] 2.4.3 Refactor `SubscriptionService.delete(UUID id)` to route through `findByIdOrThrow`
- [ ] 2.4.4 Write 2 integration tests: (a) cross-tenant 404 on delete, (b) Tenant B's subscription row unchanged (`status`, `active`, `updated_at` identical to pre-attempt state; webhook deliveries to Tenant B's endpoint continue after the failed cross-tenant attempt)
- [ ] 2.4.5 **[D11 latent fix, warroom 2026-04-15]** Refactor `SubscriptionService.create` to drop the `UUID tenantId` parameter and source from `TenantContext.getTenantId()` internally. Update `SubscriptionController` to stop passing the pass-through. Update all test call sites. Fold into the Phase 2.4 commit alongside 2.4.3 — same file, same refactor pattern, cheaper together than in separate commits.

### 2.4a EscalationPolicyService.update (D11 latent fix, warroom scope expansion)

- [ ] 2.4a.1 Refactor `EscalationPolicyService.update(UUID tenantId, ...)` to drop the `UUID tenantId` parameter and source from `TenantContext.getTenantId()` internally. Update the controller caller. Update test call sites.
- [ ] 2.4a.2 Commit as its own standalone commit on top of Phase 2.4 — the file was not previously in Phase 2 scope and warroom flagged the expansion explicitly, so separate commit keeps the audit trail honest.

### 2.5 AccessCodeController (VULN-MED)

- [ ] 2.5.1 Refactor `AccessCodeController.generateAccessCode` target-user lookup (line ~47) from `userRepository.findById(id)` to `userService.getUser(id)`
- [ ] 2.5.2 Refactor `AccessCodeController.generateAccessCode` admin-user lookup (line ~51) from `userRepository.findById(adminId)` to `userService.findById(adminId)` (per D10 — fix for consistency)
- [ ] 2.5.2a **Verify `UserService.findById` is genuinely tenant-scoped before 2.5.2 lands.** Open `UserService.findById(UUID)` — confirm it either (a) delegates to `userRepository.findByIdAndTenantId` or (b) applies an `Optional.filter(u -> u.getTenantId().equals(tenantId))` chain. If neither, switch 2.5.2 to `userService.getUser(adminId)` instead (which has an explicit tenant check). Document the finding in the PR description.
- [ ] 2.5.3 Write 2 integration tests: (a) cross-tenant 404 when admin in Tenant A calls `POST /api/v1/access-codes` with a Tenant B userId; (b) **Casey's VAWA audit assertion** — query `audit_events` after the failed attempt and assert zero rows with `event_type IN ('ACCESS_CODE_GENERATED', 'ACCESS_CODE_GENERATED_FOR_PROTECTED_USER')` reference Tenant B's userId; assert zero rows were inserted into `one_time_access_code` referencing Tenant B; assert `hmis_outbox` has no delivery queued for Tenant B as a downstream effect

### 2.6 Batch-callable renames (D7)

- [ ] 2.6.1 Rename `EscalationPolicyService.findById(UUID)` → `findByIdForBatch(UUID)` and update the single caller in `ReferralEscalationJobConfig`
- [ ] 2.6.2 Rename `SubscriptionService.markFailing(UUID)` → `markFailingInternal(UUID)` and update callers in `WebhookDeliveryService`
- [ ] 2.6.3 Rename `SubscriptionService.deactivate(UUID)` → `deactivateInternal(UUID)` and update callers in `WebhookDeliveryService`
- [ ] 2.6.4 Rename `SubscriptionService.recordDelivery(...)` internal-callable path → `recordDeliveryInternal(...)` and update callers in `WebhookDeliveryService`

### 2.7 Explicit @TenantUnscoped annotations for legitimate platform-wide methods

- [ ] 2.7.1 Annotate `ReservationService.expireReservation` with `@TenantUnscoped("system-scheduled reservation expiry runs platform-wide; tenant context is set from the fetched row")`
- [ ] 2.7.2 Annotate `EscalationPolicyService.findByIdForBatch` with `@TenantUnscoped("batch-job policy snapshot resolution for referral escalation — platform-wide by design")`
- [ ] 2.7.3 Annotate `SubscriptionService.markFailingInternal`, `.deactivateInternal`, `.recordDeliveryInternal` with matching `@TenantUnscoped` strings

### 2.8 Phase 2 verification

- [ ] 2.8.1 Run the full backend test suite; expect all Phase 2 integration tests green
- [ ] 2.8.2 Manually run a same-tenant happy-path probe for each fixed endpoint (curl + valid tenant A UUID → 200 or 204); verify no regression inside a tenant
- [ ] 2.8.3 Commit Phase 2 with a single cohesive commit message naming the 5 HIGH + 2 MED fixes + the renames

## 3. Phase 3 — Test + guard (2 days)

- [ ] 3.1 Create `CrossTenantIsolationParameterizedTest` under `backend/src/test/java/org/fabt/` using `@ParameterizedTest` + `@MethodSource`; yield one row per (endpoint, verb, role, path-variable-supplier) triple for every tenant-owned endpoint
- [ ] 3.2 Populate fixture rows for every endpoint touched in Phase 2 (12+ rows: update/delete oauth2 provider × 2 roles, rotate/deactivate api key × 2 roles, disable totp / regenerate codes × 2 roles, delete subscription × 2 roles, generate access code × 2 roles — sample subset; add the rest by endpoint)
- [ ] 3.3 Populate fixture rows for already-safe tenanted endpoints (shelter GET/PATCH, reservation GET/PATCH, referral GET/accept/reject — 6+ rows) so the fixture is a comprehensive regression guard, not just Phase-2-scoped
- [ ] 3.4 Verify the fixture passes green against Phase 2 code
- [ ] 3.4a **Red-test-first integrity check (per design.md Migration Plan).** Before committing the fixture green, locally `git stash` the Phase 2 service fixes and confirm `CrossTenantIsolationParameterizedTest` reports failures on the 5 VULN-HIGH + 2 VULN-MED rows (fixture correctly detects the pre-fix state). Then `git stash pop` to restore Phase 2, re-run, confirm green. Document the red-run output in the PR description (screenshot or log excerpt). Do NOT commit a red-main state — the stash/verify/restore is local-only.
- [ ] 3.5 Enable `TenantGuardArchitectureTest` (remove `@Disabled`); make it strict — two rule families. Family A (unsafe-lookup, D2): fires on any bare `findById(UUID)` or `existsById(UUID)` call in `org.fabt.*.service` or `org.fabt.*.api` without `@TenantUnscoped` annotation or `findByIdAndTenantId`-style method dispatch. Family B (URL-path-sink, D11): fires on **any write-method in `org.fabt.*.service` that accepts `UUID tenantId` as a parameter** and writes to a tenant-owned repository, unless the method carries `@TenantUnscoped("justification")`. Family B is **strict with zero exceptions** (no escape-hatch annotation like `@TenantFromCaller` is needed) because tasks 2.1.6, 2.2.6, 2.4.5, and 2.4a.1 eliminate every violator in the current codebase. Exact rule shape per design D11 §"Phase 3 enforcement extension"
- [ ] 3.6 Add second ArchUnit rule scoping `findByIdForBatch` callers to `org.fabt.referral.batch.*`
- [ ] 3.7 Add third ArchUnit rule scoping `*Internal` subscription methods to `WebhookDeliveryService`
- [ ] 3.8 Add 10 Mockito-based unit tests — one per refactored service method verifying repository is called with `(id, tenantId)` pair (catches "dropped the second arg" regressions)
- [ ] 3.9 Run full backend test suite; all ArchUnit rules pass, all unit + integration tests green
- [ ] 3.10 Commit Phase 3

## 4. Phase 4 — Docs + observability (1 day)

> **Parallelism note (per design.md Migration Plan):** sub-tasks 4.1-4.5 can be parallelized across two contributors — Elena on 4.1 (V56) + 4.2 (RLS coverage map), any engineer on 4.3 (Javadoc audit) + 4.4 (counter + Grafana) + 4.5 (SAFE-sites registry). Phase 4 completes when all five subsections are green.

### 4.1 V56 migration — referral_token RLS policy comment correction (D5)

- [ ] 4.1.1 Create `backend/src/main/resources/db/migration/V56__correct_referral_token_rls_policy_comment.sql`
- [ ] 4.1.2 Migration body: `COMMENT ON POLICY dv_referral_token_access ON referral_token IS 'Enforces dv_access inheritance through the shelter FK join — DOES NOT enforce tenant isolation. Tenant isolation is enforced at the service layer via findByIdAndTenantId. See openspec/changes/cross-tenant-isolation-audit for rationale. This corrects a misleading comment in V21.';`
- [ ] 4.1.3 Test locally against throwaway dev stack; verify `psql \d+ referral_token` shows the new comment

### 4.2 RLS coverage map (D1, D4, design task R6)

- [ ] 4.2.1 Create `docs/security/rls-coverage.md` with a table: tenant-owned table | RLS enabled (Y/N) | policy name | what policy enforces | service-layer guard method | test that pins cross-tenant
- [ ] 4.2.2 Populate every tenant-owned table in the current schema (enumerate via `\d` listing in dev DB)
- [ ] 4.2.3 Add a short header paragraph explaining D1 (service-layer is source of truth, RLS is defense-in-depth for `dv_access`)

### 4.3 Javadoc audit (design task R7)

- [ ] 4.3.1 Grep for "RLS" in every `*Service*.java` and `*Repository*.java` under `backend/src/main/java/`
- [ ] 4.3.2 For each hit, verify the comment against the actual policy/behavior; correct or remove inaccurate claims
- [ ] 4.3.3 Document the audit output (hits + actions) as a comment thread on the PR so reviewers can verify

### 4.4 Observability — cross_tenant_404s counter + Grafana panel

- [ ] 4.4.1 Register `fabt.security.cross_tenant_404s` Counter in `GlobalExceptionHandler` (or equivalent 404 emission path); tag by `resource_type`
- [ ] 4.4.2 Emit the counter on every 404 returned for a tenant-owned resource endpoint — intentionally NOT distinguishing "cross-tenant" from "nonexistent" (per D9)
- [ ] 4.4.3 Add Grafana panel "Cross-tenant 404s per minute (by resource)" to the FABT security dashboard JSON under `infra/grafana/dashboards/`
- [ ] 4.4.4 Include the spike-vs-baseline threshold guidance in the panel description text (per spec)
- [ ] 4.4.5 Manually fire a cross-tenant probe against the local dev stack and verify the counter increments

### 4.5 SAFE-sites registry (documentation of the 17 sites the audit cleared)

- [ ] 4.5.1 Create `docs/security/safe-tenant-bypass-sites.md` with a table: file:method | why it is safe despite calling `findById(UUID)` (one-line rationale per site: "public-data endpoint", "token-is-tenant-proof", "self-path keyed from JWT subject", "internal caller with pre-validated id", etc.)
- [ ] 4.5.2 Populate from the warroom audit's 17 SAFE entries (BedSearchService.searchBeds, AvailabilityService.createSnapshot, PasswordResetService.resetPassword, OAuth2AccountLinkService.linkOrReject, UserService.getUser, UserService.findById, PasswordController.changePassword, PasswordController.resetPassword, TotpController enrollTotp/confirmTotpEnrollment/regenerateRecoveryCodes, NotificationPersistenceService.markActed, ShelterService.findById/updateShelter/getDetail, SubscriptionService.updateStatus/findRecentDeliveries)
- [ ] 4.5.3 Link the SAFE-sites registry from `docs/security/rls-coverage.md` so both docs reinforce each other — the RLS map shows tables, the SAFE-sites doc shows call sites

### 4.6 Phase 4 verification

- [ ] 4.6.1 Run full backend test suite green; Flyway applies V56 without error
- [ ] 4.6.2 Commit Phase 4

## 5. Phase 5 — E2E + rollout (1 day)

### 5.1 Playwright cross-tenant E2E spec (D8)

- [ ] 5.1.1 Create `e2e/playwright/tests/cross-tenant-isolation.spec.ts` that logs in as Tenant A admin (via `TestAuthHelper`-equivalent Playwright seed) and attempts cross-tenant access against the 5 admin surfaces (oauth2 provider update, api key rotate, totp admin disable, subscription delete, access code generate)
- [ ] 5.1.2 Assert HTTP 404 on every attempt via network-log inspection
- [ ] 5.1.3 Assert the UI surfaces a "not found" message (or equivalent per-surface UX), not a stack trace
- [ ] 5.1.4 Verify Tenant B's state is unchanged after the 5 attempts

### 5.2 Karate cross-tenant E2E spec (D8)

- [ ] 5.2.1 Create `e2e/karate/src/test/resources/cross-tenant-isolation.feature` authenticating as Tenant A admin and exercising the 5 admin HTTP endpoints cross-tenant
- [ ] 5.2.2 Assert 404 on every response with no entity-body leakage from Tenant B
- [ ] 5.2.3 Assert the response shape matches the standard error envelope

### 5.3 Post-deploy smoke integration

- [ ] 5.3.1 Add the Playwright spec to the `deploy/playwright.config.ts` project list (runs in `post-deploy-smoke` suite)
- [ ] 5.3.2 Add the Karate feature to the CI E2E job configuration (runs on every PR and in post-deploy smoke)
- [ ] 5.3.3 Verify total post-deploy smoke runtime increases by ≤ 30 seconds (per spec non-functional requirement)

### 5.4 Runbook + release notes

- [ ] 5.4.1 Add a runbook note in `docs/runbook.md`: "Cross-tenant access now returns 404 by design. If a tenant admin reports 'can't rotate my API key / disable TOTP / etc.,' first confirm they are logged in to the correct tenant before escalating."
- [ ] 5.4.2 Draft `docs/oracle-update-notes-v0.XX.0.md` following the v0.39 template, highlighting: 5 security fixes, 1 migration (V56 comment-only), new ArchUnit guard, 30s post-deploy smoke delta, rollback plan
- [ ] 5.4.3 CHANGELOG v0.XX.0 entry summarizing the 7 security fixes + the ArchUnit guard + the observability counter

### 5.5 Security validation (Marcus Webb)

- [ ] 5.5.1 Run manual OWASP ZAP-guided cross-tenant sweep against every `/api/v1/**/{id}` endpoint using a Tenant A token and Tenant B UUIDs from the local dev stack; document findings
- [ ] 5.5.2 Re-read the Phase 2 + Phase 3 diffs with a pen-test lens; flag any call paths not covered by the parameterized fixture
- [ ] 5.5.3 Approval sign-off recorded as a PR comment before merge

### 5.6 Phase 5 verification and ship

- [ ] 5.6.1 Full CI green on the branch (backend, frontend, E2E, Karate, legal, CodeQL)
- [ ] 5.6.2 Open PR; request review from Corey + at least one other reviewer
- [ ] 5.6.3 Merge PR with merge-commit strategy per project convention (`Merge cross-tenant-isolation-audit: 7 security fixes + guard + observability`)
- [ ] 5.6.4 Tag v0.XX.0 + `gh release create` + deploy per `docs/oracle-update-notes-v0.XX.0.md`
- [ ] 5.6.5 Post-deploy: verify `fabt.security.cross_tenant_404s` counter appears on Grafana after first 404; confirm cross-tenant Playwright + Karate specs pass against live site
- [ ] 5.6.6 Close issue #117 with a comment linking the merge commit, the cross-tenant Playwright + Karate runs, and the Grafana panel URL

## 6. Archive and sync

- [ ] 6.1 Run `/opsx:verify cross-tenant-isolation-audit` pre-archive to confirm all tasks checked + spec coverage
- [ ] 6.2 Run `/opsx:sync cross-tenant-isolation-audit` to merge delta specs into main specs
- [ ] 6.3 Run `/opsx:archive cross-tenant-isolation-audit`
- [ ] 6.4 Update memory `project_issue_117_resolution.md` noting the audit is closed and what the enforcement mechanism now looks like
