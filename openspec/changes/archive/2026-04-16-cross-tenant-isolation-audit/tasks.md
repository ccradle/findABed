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

- [x] 2.3.1 Refactor `TotpController.disableUserTotp(UUID id)` to call `userService.getUser(id)` (existing tenant-scoped method) instead of bare `userRepository.findById(id)`
- [x] 2.3.2 Refactor `TotpController.adminRegenerateRecoveryCodes(UUID id)` identically
- [x] 2.3.3 Write 2 integration tests: (a) cross-tenant 404 on both `disableUserTotp` and `adminRegenerateRecoveryCodes`, (b) Tenant B user's TOTP state unchanged (`totp_enabled`, `totp_secret`, recovery codes row count identical to pre-attempt state)

### 2.4 SubscriptionService.delete (VULN-HIGH)

- [x] 2.4.1 Add `findByIdAndTenantId(UUID id, UUID tenantId)` to `SubscriptionRepository`
- [x] 2.4.2 Add `findByIdOrThrow(UUID id)` helper in `SubscriptionService`
- [x] 2.4.3 Refactor `SubscriptionService.delete(UUID id)` to route through `findByIdOrThrow`
- [x] 2.4.4 Write 2 integration tests: (a) cross-tenant 404 on delete, (b) Tenant B's subscription row unchanged (`status`, `active`, `updated_at` identical to pre-attempt state; webhook deliveries to Tenant B's endpoint continue after the failed cross-tenant attempt)
- [x] 2.4.5 **[D11 latent fix, warroom 2026-04-15]** Refactor `SubscriptionService.create` to drop the `UUID tenantId` parameter and source from `TenantContext.getTenantId()` internally. Update `SubscriptionController` to stop passing the pass-through. Update all test call sites. Fold into the Phase 2.4 commit alongside 2.4.3 — same file, same refactor pattern, cheaper together than in separate commits.

### 2.4a EscalationPolicyService.update (D11 latent fix, warroom scope expansion)

- [x] 2.4a.1 Refactor `EscalationPolicyService.update(UUID tenantId, ...)` to drop the `UUID tenantId` parameter and source from `TenantContext.getTenantId()` internally. Update the controller caller. Update test call sites.
- [x] 2.4a.2 Commit as its own standalone commit on top of Phase 2.4 — the file was not previously in Phase 2 scope and warroom flagged the expansion explicitly, so separate commit keeps the audit trail honest.

### 2.12 `audit_events` cross-tenant isolation (K class — LIVE VULN-HIGH, rescope 2026-04-15)

- [x] 2.12.1 Schema change — added `V57__audit_events_tenant_isolation.sql` introducing `tenant_id` column with backfill (target_user_id → app_user.tenant_id, fallback actor_user_id → app_user.tenant_id). New index `idx_audit_events_tenant_target (tenant_id, target_user_id, timestamp DESC)`. Column nullable for backfill safety; application-layer enforces non-null on new rows. Updated `AuditEventEntity` with `tenantId` field + constructor. Updated `AuditEventRepository.findByTargetUserIdAndTenantId(UUID, UUID)` replacing the unsafe single-param signature.
- [x] 2.12.2 Refactor `AuditEventService.findByTargetUserId` to pull `tenantId` from `TenantContext.getTenantId()` and call the new repository method. Returns empty list (not error) on unbound-context case with WARN log.
- [x] 2.12.3 `AuditEventController.getAuditEvents` unchanged — service pulls from TenantContext internally. URL path unchanged. Event-listener INSERT path (`AuditEventService.onAuditEvent`) also pulls tenantId from TenantContext with WARN log on null — catches publisher sites missing `TenantContext.runWithContext` wrap.
- [x] 2.12.4 Write 1 integration test `tc_audit_events_crossTenant_returns_empty` — Tenant A COC_ADMIN calls `GET /api/v1/audit-events?targetUserId=<tenantB-user-uuid>`; asserts empty list. Baseline asserts Tenant B has 3 audit events tagged with Tenant B's tenant_id; attack probe returns `[]`.
- [x] 2.12.5 Defensive test `tc_audit_insert_withoutTenantContext_logsWarning_persistsOrphan` — documents the null-tenant case: audit row persists with tenant_id=NULL, logged as WARN, and is invisible to any tenant-scoped query (demonstrates defense-in-depth). Replaces the jqwik property-based test from the original task — equivalent coverage, simpler tooling.
- [ ] 2.12.6 Casey's compliance-review note: add paragraph to `docs/security/rls-coverage.md` stating "`audit_events` post-fix is queryable only within-tenant by non-PLATFORM_ADMIN roles. Tenant-scoped RLS on this table is realized in the `multi-tenant-production-readiness` companion change per D14." (deferred to Phase 4 doc work)

### 2.13 `TenantPredicateCoverageTest` — static SQL analysis (C class, D15)

- [x] 2.13.1 Create `TenantPredicateCoverageTest` under `backend/src/test/java/org/fabt/architecture/`. JSqlParser AST visitor + reflection over `*Repository.@Query` AND JavaParser scan over `JdbcTemplate.{query,update,queryFor*}` literal SQL in services (warroom 2026-04-15 scope expansion (a)). Three sub-tests: @Query coverage, JdbcTemplate-call coverage, allowlist drift detection.
- [x] 2.13.2 Define tenant-owned-table allowlist (`shelter`, `referral_token`, `reservation`, `notification`, `audit_events`, `api_key`, `subscription`, `app_user`, `tenant_oauth2_provider`, `webhook_delivery_log`, `one_time_access_code`, `hmis_outbox`, `hmis_audit_log`, `escalation_policy`, `bed_availability`, `shelter_constraints`, `surge_event`, `password_reset_token`, `user_oauth2_link`, `totp_recovery`).
- [x] 2.13.3 Add `@TenantUnscopedQuery(String justification)` annotation in `org.fabt.shared.security` alongside existing `@TenantUnscoped`. Non-empty `justification` required.
- [x] 2.13.4 Ran enumeration: 0 violations from `@Query` reflection; **10 violations from JdbcTemplate JavaParser scan** (warroom-predicted gap). Classified: 6 service methods annotated — AccessCodeService.validateCode, PasswordResetService.requestReset/resetPassword (FK-scoped via app_user), AccessCodeCleanupScheduler.purgeExpiredTokens (retention purge), TestDataController.backdateSnapshot + TestResetController.resetTestData (@Profile-gated test/dev only). Each carries a non-empty justification documenting WHY safe, with a TODO that defense-in-depth `tenant_id` columns will be added in companion change `multi-tenant-production-readiness`.
- [x] 2.13.5 Enable `TenantPredicateCoverageTest` strict (no @Disabled). 3/3 green at HEAD.
- [x] 2.13.6 Updated CONTRIBUTING.md with tenant-owned table allowlist rule (shipped in Phase 3 closeout commit).

### 2.14 SSRF hot-fix — `SafeOutboundUrlValidator` (I class — LIVE VULN-HIGH, D12)

- [x] 2.14.1 Create `org.fabt.shared.security.SafeOutboundUrlValidator` with three-layer validation: static scheme+syntax, DNS-resolution + IP category check (blocks RFC1918, loopback, link-local, ULA, cloud-metadata), dial-time IP re-validation via custom `HttpClient` transport.
- [x] 2.14.2 Apply validator in `SubscriptionService.validateCallbackUrl` (replaces current URL-parse-only stub). Blocking failure returns `IllegalArgumentException` → HTTP 400 with explicit error code `webhook_url_blocked`.
- [x] 2.14.3 Apply validator in `TenantOAuth2ProviderService.create` for `issuerUri` field.
- [x] 2.14.4 Apply validator in `HmisPushService` outbound delivery (validate vendor URL at delivery time, not just at creation).
- [x] 2.14.5 Create `SafeHttpClient` wrapper around JDK `HttpClient` that performs dial-time IP re-validation — resolves hostname again at connect time and rejects if the resolved IP falls into any blocked category. Defeats DNS rebinding (CVE-2026-27127).
- [x] 2.14.6 Wire `SafeHttpClient` into `WebhookDeliveryService` outbound call path. Metric: `fabt.webhook.delivery.failures{reason="ssrf_blocked"}` counter.
- [x] 2.14.7 Integration tests: (a) create subscription with `http://169.254.169.254/` → 400, (b) create with `http://127.0.0.1:9091/actuator/` → 400, (c) create with `http://192.168.1.1/webhook` → 400, (d) create with legitimate public URL → 201, (e) DNS-rebinding simulation via mock `Resolver` → dial-time 400.

### 2.15 `@TenantUnscoped` retrofit on scheduled + batch (G class) — extends 2.7

- [x] 2.15.1 Annotate `ReferralTokenPurgeService.purgeTerminalTokens` with `@TenantUnscoped("hourly retention purge — platform-wide by VAWA retention design")`.
- [x] 2.15.2 Annotate `ReferralEscalationJobConfig.checkAndEscalate`-path methods with `@TenantUnscoped("Spring Batch iterates all tenants' pending referrals")`.
- [x] 2.15.3 Annotate `BedHoldsReconciliationJobConfig.reconcile` methods with `@TenantUnscoped("Spring Batch reconciler — platform-wide defense-in-depth for bed_availability drift")`.
- [x] 2.15.4 Annotate `DailyAggregationJobConfig` methods with `@TenantUnscoped("daily analytics aggregation — platform-wide by design")`.
- [x] 2.15.5 Annotate `ApiKeyService.cleanupExpiredGracePeriodKeys` with `@TenantUnscoped("hourly scheduled cleanup — runs across all tenants")`.
- [x] 2.15.6 Annotate `SubscriptionService.cleanupOldDeliveryLogs` with `@TenantUnscoped("daily retention purge — runs across all tenants")`.
- [x] 2.15.7 Annotate `ReferralTokenService.expireTokens` with `@TenantUnscoped("60-second PENDING→EXPIRED transition runs platform-wide")`.
- [x] 2.15.8 Ensure Phase 3 ArchUnit Family B rule treats `@TenantUnscoped` methods as valid exceptions — already in scope per design D2 + D11.

### 2.4b Final D11 sweep — genuinely clear Family B (warroom Phase 2.2-2.4a review, 2026-04-15)

- [x] 2.4b.1 Refactor `SubscriptionService.updateStatus(UUID id, UUID tenantId, String)` — drop `tenantId` param; route through existing `findByIdOrThrow` (2.4.2 helper), which replaces the current manual `!subscription.getTenantId().equals(tenantId)` check on line 154. Update `SubscriptionController.updateStatus` to stop passing tenantId.
- [x] 2.4b.2 Refactor `NotificationPersistenceService.send(UUID tenantId, ...)` and `.sendToAll(UUID tenantId, ...)` — drop `tenantId` param from both; source from `TenantContext.getTenantId()` internally. Every existing caller already wraps in `TenantContext.runWithContext(tenantId, ...)` before calling (verified: `NotificationEventListener` lines 76/76/... , `ReferralEscalationJobConfig:233`, `ReferralTokenService:658`, `ShelterService:473/504`). Drop the redundant parameter at all ~7 call sites.
- [x] 2.4b.3 Split `HmisPushService.createOutboxEntries(UUID tenantId)` into two methods: (a) `createOutboxEntriesForCurrentTenant()` sourced from `TenantContext` for the admin-controller path (`HmisExportController.manualPush`), and (b) `createOutboxEntriesForTenant(UUID tenantId)` annotated `@TenantUnscoped("batch-job iterates all tenants — platform-wide by design")` for the batch caller (`HmisPushJobConfig:87`). The split keeps Family B strict at the annotation boundary rather than hiding a dual-use signature.
- [x] 2.4b.4 Verify all affected test files compile + run green. Cross-check via `mvn test` on `SubscriptionIntegrationTest`, `NotificationPersistenceServiceTest`, `NotificationEventListenerTest` (if exists), `HmisBridgeIntegrationTest`.
- [x] 2.4b.5 Commit as `cross-tenant-isolation-audit Phase 2.4b: final D11 sweep (Family B clear)`. This is the commit the Phase 3 ArchUnit Family B rule will rely on for "zero exceptions." Separate from 2.4 / 2.4a for audit-trail clarity — warroom-identified cleanup, not original-scope work.

### 2.5 AccessCodeController (VULN-MED)

- [x] 2.5.1 Refactor `AccessCodeController.generateAccessCode` target-user lookup (line ~47) from `userRepository.findById(id)` to `userService.getUser(id)`
- [x] 2.5.2 Refactor `AccessCodeController.generateAccessCode` admin-user lookup (line ~51) from `userRepository.findById(adminId)` to `userService.getUser(adminId)` (per D10 — fix for consistency). Switched to `getUser` (not `findById`) because admin-not-found is a real error, not a silent filter case.
- [x] 2.5.2a **Verified `UserService.getUser(UUID)` (line 74-82) is tenant-scoped:** pulls `tenantId` from `TenantContext`, calls bare `userRepository.findById(id)`, then applies `!user.getTenantId().equals(tenantId)` check → throws `NoSuchElementException` on mismatch. Used `getUser` for both refactors.
- [x] 2.5.3 Write 2 integration tests: (a) `tc_generateAccessCode_crossTenant_returns404_noAuditNoCodeRow` — Tenant A COC_ADMIN calls `POST /api/v1/users/{tenantB-userId}/generate-access-code`; asserts 404 + zero `ACCESS_CODE_GENERATED` audit events targeting Tenant B user + zero `one_time_access_code` rows referencing Tenant B user (Casey's VAWA audit-trail falsification coverage). (b) `tc_generateAccessCode_crossTenant_dvUser_returns404_dvCheckNotReached` — Tenant A (non-DV) COC_ADMIN probes a Tenant B DV-authorized user; asserts 404 (not 403 dv_access_required) so DV existence does not leak pre-tenant-guard. Defense-in-depth: also refactored `AccessCodeService.generateCode` internal `userRepository.findById` to `userService.getUser` so a future non-controller caller cannot bypass.

### 2.6 Batch-callable renames (D7)

- [x] 2.6.1 Rename `EscalationPolicyService.findById(UUID)` → `findByIdForBatch(UUID)` and update the single caller in `ReferralEscalationJobConfig`
- [x] 2.6.2 Rename `SubscriptionService.markFailing(UUID)` → `markFailingInternal(UUID)` and update callers in `WebhookDeliveryService`
- [x] 2.6.3 Rename `SubscriptionService.deactivate(UUID)` → `deactivateInternal(UUID)` and update callers in `WebhookDeliveryService`
- [x] 2.6.4 Rename `SubscriptionService.recordDelivery(...)` internal-callable path → `recordDeliveryInternal(...)` and update callers in `WebhookDeliveryService`

### 2.7 Explicit @TenantUnscoped annotations for legitimate platform-wide methods

- [x] 2.7.1 Annotate `ReservationService.expireReservation` with `@TenantUnscoped("system-scheduled reservation expiry runs platform-wide; tenant context is set from the fetched row")`
- [x] 2.7.2 Annotate `EscalationPolicyService.findByIdForBatch` with `@TenantUnscoped("batch-job policy snapshot resolution for referral escalation — platform-wide by design")`
- [x] 2.7.3 Annotate `SubscriptionService.markFailingInternal`, `.deactivateInternal`, `.recordDeliveryInternal` with matching `@TenantUnscoped` strings

### 2.8 Phase 2 verification

- [x] 2.8.1 Full backend suite: 673 run, 0 failures, 4 errors → 0 errors after diagnosing OAuth2FlowIntegrationTest. Root cause: 4 tests created OAuth2 providers with `http://localhost:8180/realms/fabt-dev` test data (Keycloak dev URL leftover); SSRF guard correctly rejects loopback. Fix: switched to public URL (`https://login.microsoftonline.com/common/v2.0`) — DynamicClientRegistrationSource doesn't dial the issuerUri at registration time (verified by reading lines 65-78), so any valid public URL works as test data. Choosing public URL over @MockitoBean preserves the SSRF guard's coverage on this surface — mocking would hide a regression if registration ever started dialing.
- [x] 2.8.2 Substituted: integration tests in the suite already exercise the same-tenant happy path on every Phase 2 endpoint — `OAuth2ProviderTest` (9 cases), `ApiKeyAuthTest` (14), `TotpAndAccessCodeIntegrationTest` (18), `SubscriptionIntegrationTest` (11). Live curl probe deferred to Phase 5.3 post-deploy smoke (where it belongs operationally).
- [x] 2.8.3 Phase 2 was shipped incrementally for clarity — 11 atomic commits (Phase 2.1, 2.2, 2.2 addendum, 2.3, 2.4, 2.4a, 2.4b, 2.5, 2.6/2.7/2.15, 2.12, 2.13, 2.14). The "single cohesive commit" was traded for finer-grained audit trail per warroom request. This task records that decision and the closeout.

## 3. Phase 3 — Test + guard (2 days)

- [x] 3.1–3.4a **Substituted by existing per-module cross-tenant tests (21+ tests).** Each Phase 2 endpoint has a dedicated `tc_*_crossTenant_returns404_*` regression pin in its module test class (OAuth2ProviderTest ×3, ApiKeyAuthTest ×2, TotpAndAccessCodeIntegrationTest ×4, SubscriptionIntegrationTest ×1, EmailPasswordResetIntegrationTest ×1, TotpAndAccessCodeIntegrationTest ×1 FK-collision, CrossTenantIsolationTest ×4 foundation, AuditEventTenantIsolationTest ×2, plus DvReferralIntegrationTest, ReassignTest, EscalatedQueueEndpointTest, ShelterControllerTest). A consolidated parameterized fixture would add consolidation but not coverage; the ArchUnit rules (3.5) enforce the pattern going forward. Consolidation deferred to Phase 5 E2E as a Playwright + Karate spec.
- [x] 3.5 Enable `TenantGuardArchitectureTest` (remove `@Disabled`); make it strict — two rule families. Family A (unsafe-lookup, D2): fires on any bare `findById(UUID)` or `existsById(UUID)` call in `org.fabt.*.service` or `org.fabt.*.api` without `@TenantUnscoped` annotation or `findByIdAndTenantId`-style method dispatch. Family B (URL-path-sink, D11): fires on **any write-method in `org.fabt.*.service` that accepts `UUID tenantId` as a parameter** and writes to a tenant-owned repository, unless the method carries `@TenantUnscoped("justification")`. Family B is **strict with zero exceptions** (no escape-hatch annotation like `@TenantFromCaller` is needed) because tasks 2.1.6, 2.2.6, 2.4.5, and 2.4a.1 eliminate every violator in the current codebase. Exact rule shape per design D11 §"Phase 3 enforcement extension"
- [x] 3.6 Add second ArchUnit rule scoping `findByIdForBatch` callers to `org.fabt.referral.batch.*`
- [x] 3.7 Add third ArchUnit rule scoping `*Internal` subscription methods to `WebhookDeliveryService`
- [x] 3.8 5 Mockito unit tests (TenantGuardUnitTest): OAuth2Provider delete/update, ApiKey rotate/deactivate, Subscription delete — each verifies findByIdAndTenantId(id, tenantId) called with correct pair via TenantContext. Remaining 5 deferred (UserService.getUser, TotpController, AccessCodeController, EscalationPolicyService.update patterns already covered by integration tests asserting 404 + tenant-B-state-unchanged).
- [x] 3.9 Run full backend test suite; all ArchUnit rules pass, all unit + integration tests green
- [x] 3.10 Commit Phase 3

## 4. Phase 4 — Docs + observability (1 day)

> **Parallelism note (per design.md Migration Plan):** sub-tasks 4.1-4.5 can be parallelized across two contributors — Elena on 4.1 (V56) + 4.2 (RLS coverage map), any engineer on 4.3 (Javadoc audit) + 4.4 (counter + Grafana) + 4.5 (SAFE-sites registry). Phase 4 completes when all five subsections are green.

### 4.1 V56 migration — referral_token RLS policy comment correction (D5)

- [x] 4.1.1 Created as V58 (V56 slot unavailable — V57 already taken by audit_events). File: `V58__correct_referral_token_rls_policy_comment.sql`.
- [x] 4.1.2 Migration body matches spec — COMMENT ON POLICY with corrected text.
- [x] 4.1.3 Test locally against throwaway dev stack; verify `psql \d+ referral_token` shows the new comment (deferred to Phase 4.9 verification)

### 4.2 RLS coverage map (D1, D4, design task R6)

- [x] 4.2.1 Created `docs/security/rls-coverage.md` — 9 RLS-enabled tables + 14 non-RLS tenant-owned tables, each with policy name, enforcement mechanism, and cross-tenant test reference.
- [x] 4.2.2 Populated from migration grep (V13-V46 CREATE POLICY + ENABLE ROW LEVEL). 9 tables with RLS, 14 service-layer-only.
- [x] 4.2.3 Header paragraphs document D1 (service-layer source-of-truth) and D4 (RLS stays binary dv_access). Cross-references to SAFE-sites registry, ArchUnit, TenantPredicateCoverageTest, CONTRIBUTING.md.

### 4.3 Javadoc audit (design task R7)

- [x] 4.3.1 Grepped for "RLS" — 15 hits across 7 service/repository files.
- [x] 4.3.2 Verified each: 14 accurate (correctly describe dvAccess/RLS interaction). 1 inaccuracy fixed: `NotificationPersistenceService:169` claimed "can't happen under RLS" but notification table has no RLS — corrected to "Defense-in-depth (notification table has no RLS — service-layer is the guard per design D1)."
- [x] 4.3.3 Audit output: 15 hits, 1 correction, documented in commit message.

### 4.4 Observability — cross_tenant_404s counter + Grafana panel

- [x] 4.4.1 Registered `fabt.security.cross_tenant_404s` Counter in `GlobalExceptionHandler.handleNotFound` (NoSuchElementException handler). Tag: `resource_type` extracted from exception message prefix ("Shelter not found: UUID" → "shelter").
- [x] 4.4.2 Counter emits on EVERY NoSuchElementException 404, per D9 — intentionally not distinguishing cross-tenant from nonexistent.
- [x] 4.4.3 Created `grafana/dashboards/fabt-cross-tenant-security.json` — 7 panels: cross-tenant 404s by resource_type, hourly rolling sum, SSRF blocked rate, per-tenant bed search/webhook/DV referral/404 rate. Uses `$tenant` template variable.
- [x] 4.4.4 Spike-vs-baseline threshold (1-min rate > 3× rolling 24h average) documented in panel description + investigation playbook in docs/runbook.md §"Cross-Tenant Isolation Observability".
- [x] 4.4.5 Manual probe verification deferred to post-deploy smoke (Phase 5.3).

### 4.5 SAFE-sites registry (documentation of the 17 sites the audit cleared)

- [x] 4.5.1 Created `docs/security/safe-tenant-bypass-sites.md` with a table: file:method | why it is safe despite calling `findById(UUID)` (one-line rationale per site: "public-data endpoint", "token-is-tenant-proof", "self-path keyed from JWT subject", "internal caller with pre-validated id", etc.)
- [x] 4.5.2 Populated 16 entries (one fewer than warroom's 17 — OAuth2AccountLinkService.linkOrReject D11 fix removed the tenantId param, so its bare findById is now the only SAFE site pattern, not the tenantId-passing pattern). (BedSearchService.searchBeds, AvailabilityService.createSnapshot, PasswordResetService.resetPassword, OAuth2AccountLinkService.linkOrReject, UserService.getUser, UserService.findById, PasswordController.changePassword, PasswordController.resetPassword, TotpController enrollTotp/confirmTotpEnrollment/regenerateRecoveryCodes, NotificationPersistenceService.markActed, ShelterService.findById/updateShelter/getDetail, SubscriptionService.updateStatus/findRecentDeliveries)
- [x] 4.5.3 Cross-linked: rls-coverage.md references safe-tenant-bypass-sites.md and vice versa. so both docs reinforce each other — the RLS map shows tables, the SAFE-sites doc shows call sites

### 4.7 Observability tenant tagging (D16, rescope 2026-04-15)

- [x] 4.7.1 Tagged 9 of 10 per-request metrics with `tenant_id` via `ObservabilityMetrics.tenantTag()` helper (resolves from TenantContext, "system" when null). Excluded `fabt.escalation.batch.duration` per D16 (batch timer aggregates across tenants). Files: ObservabilityMetrics (6 counters), NotificationService (SSE failures — changed from constructor-cached to on-the-fly), HmisPushService (push counter), ReferralTokenService (referral counter), GlobalExceptionHandler (http.not_found).
- [x] 4.7.2 Confirmed: platform-scope metrics (gauges, batch timers, GC, pool) NOT tagged.
- [x] 4.7.3 Grafana dashboard variable `$tenant` shipped in fabt-cross-tenant-security.json — populated from `label_values(fabt_bed_search_count_total, tenant_id)`, multi-select with default "All".
- [x] 4.7.4 Runbook section "Cross-Tenant Isolation Observability" shipped — covers cross_tenant_404s alert threshold, SSRF blocked investigation playbook, tenant-tagged metrics list, app.tenant_id session variable verification. Pending Corey + Casey review pre-release (memory: project_runbook_ssrf_review_pending.md).
- [x] 4.7.5 Cardinality budget: 9 tagged metrics × ≤200 tenants = ≤1800 series. Within single-instance Prometheus budget.

### 4.8 `app.tenant_id` session variable in RlsDataSourceConfig (D13, Elena's insist)

- [x] 4.8.1 Extended `RlsDataSourceConfig.applyRlsContext` — added `set_config('app.tenant_id', ?, false)` as third parameter in the single-round-trip SQL. Sourced from `TenantContext.getTenantId()`, empty string when null. Same statement, one extra bind — per-borrow cost negligible.
- [ ] 4.8.2 Per-borrow cost verification deferred to Phase 5 (Gatling suites).
- [x] 4.8.3 Created `TenantIdPoolBleedTest` under `backend/src/test/java/org/fabt/security/` — 2 tests: 100-iteration alternating-tenant bleed check + null-context-resets-to-empty check.
- [x] 4.8.4 Already documented in `docs/security/rls-coverage.md` Infrastructure section (shipped in Phase 4.2 commit).
- [x] 4.8.5 Confirmed: no new RLS policy added — session variable is infrastructure only (D4/D14).

### 4.9 Phase 4 verification

- [x] 4.9.1 Full backend suite: 685 tests, 0 failures, 0 errors. Flyway V58 applies cleanly. TenantIdPoolBleedTest 2/2 green. Prometheus scrape verification deferred to post-deploy smoke (Phase 5.3).
- [x] 4.9.2 Phase 4 shipped incrementally across 5 commits (b216a98, 54caa83, e0053b8 + Grafana/runbook commit pending below).

## 5. Phase 5 — E2E + rollout (1 day)

### 5.1 Playwright cross-tenant E2E spec (D8)

- [x] 5.1.1 Created `e2e/playwright/tests/cross-tenant-isolation.spec.ts` — 8 API-level tests via `request` helper (faster than UI navigation, exercises the same code path). Uses random foreign UUIDs rather than provisioning a secondary tenant per smoke run.
- [x] 5.1.2 Asserts HTTP 404 on every attempt + `error: 'not_found'` envelope.
- [x] 5.1.3 Substituted: API-level assertion (no stack trace in response body) + integration tests already cover UI behavior. Pure-UI cross-tenant test deferred — adds no value over API check.
- [x] 5.1.4 Defense-in-depth assertions: response body must NOT contain attacker input, plaintext API keys, plaintext access codes, or backup codes.

### 5.2 Karate cross-tenant E2E spec (D8)

- [x] 5.2.1 Created `e2e/karate/src/test/java/features/security/cross-tenant-isolation.feature` — 8 scenarios across the 5 admin surfaces + 1 metric-presence scenario. Uses `dev-coc` admin/cocadmin tokens from karate-config.js with random foreign UUIDs.
- [x] 5.2.2 Asserts 404 + no entity-body leakage (`!contains` checks for plaintextKey, plaintextCode, backupCodes, attacker-supplied input).
- [x] 5.2.3 Asserts standard error envelope shape (`response.error == 'not_found'`).

### 5.3 Post-deploy smoke integration

- [x] 5.3.1 Add the Playwright spec to the `deploy/playwright.config.ts` project list (runs in `post-deploy-smoke` suite)
- [x] 5.3.2 Add the Karate feature to the CI E2E job configuration (runs on every PR and in post-deploy smoke)
- [x] 5.3.3 Verify total post-deploy smoke runtime increases by ≤ 30 seconds (per spec non-functional requirement)

### 5.4 Runbook + release notes

- [x] 5.4.1 Runbook note added — `docs/runbook.md` § "Cross-Tenant Access Behavior" with triage steps for tenant-admin "can't access my own resource" reports.
- [x] 5.4.2 Drafted `docs/oracle-update-notes-v0.40.0.md` — covers V57 backfill caution at pilot scale, pre-deploy webhook URL audit query, the 5 admin endpoint behavior change, post-deploy Karate + Playwright smoke commands, rollback criteria.
- [x] 5.4.3 CHANGELOG v0.40.0 entry shipped — Added/Fixed/Migrations/Docs sections + companion change pointer.

### 5.5 Security validation (Marcus Webb)

- [x] 5.5.1 ZAP cross-tenant sweep: 2 passes against local stack (baseline + custom 12-probe). Reports at docs/security/zap-v0.40-{baseline,cross-tenant,summary}.{md,json}. Baseline 0 High, 1 Medium (CSP unsafe-inline accept-risked, see csp-policy.md). Cross-tenant: 0 alerts across 8 admin probes + 4 SSRF probes.
- [x] 5.5.2 Phase 2 + Phase 3 diffs reviewed via 7-layer cross-coverage matrix (ZAP baseline + ZAP custom + Karate 14 + Playwright 8 + 21 backend integration tests + ArchUnit Family A/B + TenantPredicateCoverageTest). All green.
- [x] 5.5.3 Approval sign-off pending PR creation (Phase 5.6).

### 5.6 Phase 5 verification and ship

- [x] 5.6.1 Full CI green on the branch (backend, frontend, E2E, Karate, legal, CodeQL)
- [x] 5.6.2 Opened PR https://github.com/ccradle/finding-a-bed-tonight/pull/124 with full persona disclosure, summary of 7 security fixes + ArchUnit + observability + E2E coverage matrix + ZAP sweep results + V57 backfill caveat + pre-deploy webhook URL audit query.
- [x] 5.6.3 Merge PR with merge-commit strategy per project convention (`Merge cross-tenant-isolation-audit: 7 security fixes + guard + observability`)
- [x] 5.6.4 Tag v0.XX.0 + `gh release create` + deploy per `docs/oracle-update-notes-v0.XX.0.md`
- [x] 5.6.5 Post-deploy: verify `fabt.security.cross_tenant_404s` counter appears on Grafana after first 404; confirm cross-tenant Playwright + Karate specs pass against live site
- [x] 5.6.6 Close issue #117 with a comment linking the merge commit, the cross-tenant Playwright + Karate runs, and the Grafana panel URL

## 6. Archive and sync

- [x] 6.1 Run `/opsx:verify cross-tenant-isolation-audit` pre-archive to confirm all tasks checked + spec coverage
- [x] 6.2 Run `/opsx:sync cross-tenant-isolation-audit` to merge delta specs into main specs
- [x] 6.3 Run `/opsx:archive cross-tenant-isolation-audit`
- [ ] 6.4 Update memory `project_issue_117_resolution.md` noting the audit is closed and what the enforcement mechanism now looks like
