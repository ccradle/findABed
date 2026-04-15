## Context

FABT is a modular Spring Boot monolith with Postgres 16 RLS used selectively. Tenant isolation today is enforced primarily at the service layer via `TenantContext` (a Java 25 `ScopedValue` bound in `JwtAuthenticationFilter`), with RLS serving as a defense-in-depth layer on tables that also carry `dv_access` sensitivity (`shelter`, `referral_token`, `notification`, `shelter_constraints`, `bed_availability`, `reservation`, `surge_event`, `escalation_policy`). The RLS policies on those tables enforce **only the `dv_access` flag** — they do not include tenant predicates. Tables without RLS at all (`app_user`, `api_key`, `subscription`, `webhook_delivery_log`, `tenant_oauth2_provider`, `one_time_access_code`, `password_reset_token`, `user_oauth2_link`, `audit_events`, `hmis_outbox`, `hmis_audit_log`) depend entirely on service-layer guards.

During Phase 4 of Issue #106, a cross-tenant leak in `/api/v1/dv-referrals/{id}` was fixed via a repository-layer `findByIdAndTenantId` method and a service-layer `findByIdOrThrow` helper. The audit (Issue #117) confirms the same defect pattern across 7 other service/controller methods (5 HIGH + 2 MED) and surfaces systemic enforcement gaps: no ArchUnit rule prevents a new bare `findById(UUID)`, no parameterized cross-tenant test catches new endpoints, no RLS coverage map tells contributors which tables depend on service-layer guards versus RLS, and at least one RLS policy comment (`referral_token` V21) makes a false tenant-enforcement claim.

**Stakeholders:** Alex Chen (architecture, pattern enforcement), Elena Vasquez (RLS + JDBC internals), Marcus Webb (threat model), Casey Drummond (VAWA/HIPAA downstream concerns), Sam Okafor (perf cost of added predicates), Riley Cho (test strategy), Jordan Reyes (rollout + observability).

**Constraints:**
- Flyway migrations are immutable after application (`feedback_flyway_immutable_after_apply.md`) — V21's policy comment cannot be edited in place; a new migration must supply the correction.
- Tenant context lives in `ScopedValue` and is set before `@Transactional` acquires the connection; any refactor must preserve this ordering (`feedback_transactional_rls_scoped_value_ordering.md`).
- Single-tenant demo site has zero exploit exposure; the audit blocks multi-tenant pilots, not production operations today.
- The project uses Spring Data with `JdbcTemplate`-based repositories (no Spring Data JPA CrudRepository); every tenant predicate is a hand-written SQL addition.

## Goals / Non-Goals

**Goals:**
- Close all 5 VULN-HIGH and 2 VULN-MED call sites identified by the warroom audit, using the v0.39 DV referral fix as the canonical pattern.
- Install an ArchUnit rule that makes the defect pattern mechanically unreachable for future contributors, with strict build-failure enforcement from day one.
- Provide a parameterized `(endpoint, verb, role)` integration test fixture that every new tenanted endpoint must extend.
- Correct the `referral_token` RLS policy comment via a new Flyway migration so `psql \d+` tells the truth.
- Publish an RLS coverage map (`docs/security/rls-coverage.md`) that shows, table-by-table, whether RLS enforces tenant, enforces `dv_access`, enforces nothing, and what the corresponding service-layer guard is.
- Add a `fabt.security.cross_tenant_404s` Micrometer counter so future cross-tenant probing is detectable on the Grafana dashboard.
- Cover the admin HTTP surface with both a Playwright E2E spec (browser-level, catches nginx/CORS/JWT-filter regressions) and a Karate E2E spec (contract-level, catches handler regressions).

**Non-Goals:**
- Adding RLS policies to `tenant_oauth2_provider`, `api_key`, `subscription` (see D4 rejection rationale).
- Refactoring `TenantContext` itself — the ScopedValue design is correct (validated in v0.38); no change.
- Migrating the whole codebase to Spring Data JPA repositories — out of scope, separate architectural discussion.
- Schema-per-tenant or database-per-tenant architecture — FABT is discriminator-column + selective RLS by design; we are not revisiting that.
- Adding tenant predicates to RLS policies on the currently-RLS tables — their job is `dv_access`, not tenant; D1 codifies this.
- Deep-refactoring `SubscriptionService.markFailing`/`deactivate`/`recordDelivery` to accept a `tenantId` parameter — they are internal-caller-only after the rename; the ArchUnit rule restricts callers to `WebhookDeliveryService`.
- **Tenant-specific pool-bleed assertion.** The existing `cross-tenant-isolation-test` spec already covers a dvAccess-flavored pool-bleed test ("Connection pool does not leak dvAccess across requests" — 100 sequential iterations). Elena flagged during the audit that no parallel assertion exists for `tenant_id` session-variable bleed. We considered adding it to the parameterized fixture (R5) but deferred: (a) the dvAccess variant is the tightest proxy and has never flaked in two years; (b) the ScopedValue+HikariCP interaction is validated in v0.38's existing tests; (c) adding it here would expand R5 scope. Slated as a follow-up issue to be filed on merge of this change. The `CrossTenantIsolationTest` concurrent-virtual-thread suite already fires 100 requests per tenant at the same pool — bleed would surface indirectly as response-body contamination there.

## Decisions

### D1 — Service-layer tenant guard is the system of record; RLS is defense-in-depth only

The canonical tenant check lives in the service layer via `findByIdAndTenantId(UUID, UUID)` → throws `NoSuchElementException` → 404. RLS policies on the currently-protected tables enforce `dv_access` only. We do not add tenant predicates to any RLS policy.

**Rationale:** Per `feedback_per_user_rls_wrong_pattern.md`, Postgres RLS is a poor fit for tables accessed by system processes (batch jobs, scheduled expirers, reconciliation tasks) — those processes need platform-wide visibility and would either need to bypass RLS via `SECURITY DEFINER` (which introduces a worse class of bug) or run as a superuser (which defeats the purpose). Service-layer guards have per-method precision, are visible in code review, and integrate cleanly with `ScopedValue`-based context. RLS is retained on the `dv_access`-gated tables because `dv_access` is a cross-cutting UI/UX filter (DV shelters disappear from non-DV-access user search results regardless of endpoint) — the exact case RLS is good at.

**Alternatives considered:**
- *Full tenant RLS on every table.* Rejected — conflicts with the batch-job and reconciliation tasklet access patterns; forces `SECURITY DEFINER` workarounds.
- *Hibernate `@FilterDef` discriminator filter.* Rejected — the project is JdbcTemplate-based, not JPA; adopting Hibernate filters would require a migration larger than this change.
- *Single base repository with `findById` overridden to inject tenant.* Rejected — works for Spring Data JPA (`SimpleJpaRepository` override) but not for our hand-written JdbcTemplate repositories.

### D2 — `@TenantUnscoped("justification")` annotation + ArchUnit rule

A new marker annotation `org.fabt.shared.security.TenantUnscoped(String justification)` marks methods that intentionally call `findById(UUID)` or `existsById(UUID)` on a tenant-owned repository. An ArchUnit rule in the test classpath fails the build if any class in `org.fabt.*.service` or `org.fabt.*.api` calls these repository methods on a tenant-owned entity without either (a) the annotation with a non-empty `justification`, or (b) a compile-time whitelist of method signatures (`findByIdAndTenantId`, `findByIdForBatch`, `findByIdInternal`).

**Rationale:** Strict enforcement from day one, not advisory — per the warroom resolution. Advisory rules are ignored; the whole point of this change is to catch the NEXT bare `findById` before it ships. The annotation's `justification` string forces an explicit author decision at the point of use, which doubles as documentation for future reviewers. The rule covers both `findById(UUID)` AND `existsById(UUID)` per the warroom resolution — the latter has the same defect shape (`TenantOAuth2ProviderService.delete` uses `existsById` on line 86).

**Alternatives considered:**
- *Checkstyle / Error Prone / Spotbugs rule.* Rejected — build-time rules on method-name patterns are brittle; ArchUnit's model-based approach handles package moves, refactors, and method renames gracefully.
- *JdbcTemplate wrapper that rejects SQL without `tenant_id =`.* Not rejected; slated as a future enhancement (see Open Questions). The ArchUnit rule is the first-line guard; SQL literal assertion is a belt-and-suspenders addition for later.
- *Code review checklist only.* Rejected — code review missed ~10 sites for months; mechanical enforcement is required.

### D3 — 404 not 403 for cross-tenant access

Every cross-tenant resource access (read or mutation) returns 404, matching the v0.39 DV referral pattern. 403 would leak existence (the caller would know the UUID exists, just in a tenant they don't own); 404 does not.

**Rationale:** Consistent with OWASP ASVS V4 and the v0.39 convention. The warroom confirmed this is the right default for every endpoint covered by this change.

**Alternatives considered:**
- *403 with a generic error body.* Rejected — existence disclosure is a real finding in pen tests (Marcus Webb); 404 is the de-facto web convention for "this doesn't exist (from your perspective)."

### D4 — RLS stays binary (`dv_access` true/false), not tenant-scoped — explicitly considered and rejected for `tenant_oauth2_provider`, `api_key`, `subscription`

We considered extending RLS to cover the currently-unprotected tenant-owned tables. We rejected that approach for three reasons: (1) D1's "service-layer guard is system of record" means RLS adds no new enforcement and a lot of maintenance cost; (2) these tables are accessed by system processes (webhook delivery, API key rotation under batch, subscription reconciliation) that would require `SECURITY DEFINER` bypass (same objection as D1); (3) the RLS on the currently-protected tables is specifically shaped for `dv_access` (a flag on the row being filtered), not tenant ownership (which requires a join through `TenantContext`-populated session variables). Mixing semantics across RLS policies would be confusing.

**Rationale (Elena):** Recording this explicitly because future contributors might ask "why isn't there RLS on `api_key`?" — the answer is intentional, not oversight.

### D5 — Fix the misleading `referral_token` RLS policy comment via V56 (new migration, not V21 edit)

The V21 policy `dv_referral_token_access` has a `USING` clause that checks only `EXISTS (SELECT 1 FROM shelter s WHERE s.id = referral_token.shelter_id)` — it does not enforce tenant ownership of the shelter. A Javadoc comment elsewhere in the code (since removed in v0.39) claimed this policy "inherits tenant access." That claim was false; the v0.39 fix patched behavior via `findByIdAndTenantId` but left the policy comment misleading.

Flyway's immutability rule prevents editing V21. Instead, **V56** runs a `COMMENT ON POLICY dv_referral_token_access ON referral_token IS '...'` that correctly describes what the policy actually enforces (dv_access inheritance through the shelter join, nothing about tenant). Future `psql \d+ referral_token` output reflects the truth.

**Rationale:** Elena — "show me `pg_policies`, not hypotheses." If the policy claims to do X but does Y, a future incident response is slower because responders trust the comment.

**Alternatives considered:**
- *Replace the RLS policy entirely with a tenant-inclusive version.* Rejected per D1/D4 — we don't want tenant in RLS; service-layer is the right layer.
- *Leave the comment as-is and document the truth in a separate file.* Rejected — `pg_policies` is the first place a DBA looks during an incident; correcting it at the source is cheap.

### D6 — Parameterized cross-tenant test fixture as a standing PR requirement

`CrossTenantIsolationParameterizedTest` uses `@ParameterizedTest` + `@MethodSource` yielding one row per `(endpoint, verb, role, pathVariableSupplier)` triple. Every tenant-owned endpoint must add a row. Catching a missing row is a PR-checklist item; Riley rejects PRs that add a new tenanted endpoint without a matching row.

The existing `CrossTenantIsolationTest` (concurrent-virtual-thread suite) stays — that one measures concurrent-execution isolation under load; the new parameterized one measures coverage breadth. Different jobs, both required.

### D7 — Rename `EscalationPolicyService.findById` → `findByIdForBatch` (not tenantId-parameterize)

Per user decision (open question 1 resolution): rename-and-restrict wins over symmetry. The ArchUnit rule scopes callers of `findByIdForBatch` to `org.fabt.referral.batch.*`. The method is intentionally platform-wide for the batch snapshot case; the rename makes that intent obvious at call sites.

`SubscriptionService.markFailing` / `.deactivate` / `.recordDelivery` get the same treatment with an `Internal` suffix and an ArchUnit restriction to `WebhookDeliveryService`.

### D8 — Dual-framework E2E coverage: Playwright AND Karate

Per user decision (open question 4 resolution): both. Playwright covers browser-to-API (catches nginx routing, CORS, JWT filter regressions that Spring integration tests do not see). Karate covers API-only contract (catches handler-level regressions without browser overhead; faster in CI; runs as part of the E2E job already). The overlap is intentional — each framework catches a different class of regression.

**Cost:** Adds ~30s to post-deploy smoke across both specs combined. Acceptable.

### D9 — Observability counter emits on 404 even when the UUID simply doesn't exist

`fabt.security.cross_tenant_404s` increments on every 404 returned from a tenant-owned resource endpoint, regardless of whether the UUID exists in another tenant or nowhere at all. We cannot distinguish the two cases without a cross-tenant lookup (which would defeat isolation).

**Rationale:** The counter is for spike detection (baseline rate + alert on 5× spike), not attribution. A single probing attempt looks identical to a user typo; a sweeping attack shows up as a rate spike. Attribution belongs to other instrumentation (audit logs), not this counter.

### D10 — Fix `AccessCodeController:51` admin-self-lookup for consistency, not with an exemption annotation

Per user decision (open question 6 resolution): the admin-self-lookup via JWT `auth.getName()` is practically safe (you can't impersonate yourself into another tenant), but formally mismatched to D2's service-layer convention. Cost of the refactor is ~5 minutes; value is a cleaner convention. Fix it.

### D11 — Tenant-owned writes MUST source `tenantId` from `TenantContext`, not from request URL path or body (URL-path-sink class)

Discovered during Phase 2.1 implementation (2026-04-15 warroom). `OAuth2ProviderService.create` accepted a `tenantId` parameter that the controller sourced from the URL path variable `{tenantId}`. Spring Security's `@PreAuthorize("hasAnyRole('COC_ADMIN','PLATFORM_ADMIN')")` gates the role, not the tenant match — a Tenant A admin `POST /api/v1/tenants/{tenantB}/oauth2-providers` wrote a new provider under Tenant B with attacker-controlled fields. Marcus's threat ranking placed this **worse than the unsafe-lookup `update` path** because no existing row diff signals the anomaly and the fresh row cannot be identified as cross-tenant-injected after the fact.

**Decision:** Service methods that write to tenant-owned tables SHALL source `tenantId` from `TenantContext.getTenantId()` internally, NOT accept it as a method parameter. Controllers with `{tenantId}` in the URL path SHALL additionally validate the path value matches `TenantContext.getTenantId()` and return 404 on mismatch (symmetric with D3 for read paths). The URL-path value is thus observably "display-only" — mismatch yields 404 before the service is invoked, and even if it weren't validated the service could not be misled because the parameter no longer exists.

**Why type-level, not runtime-guard:**
- A `Preconditions.check(tenantId.equals(TenantContext.getTenantId()))` guard at method entry still requires every caller to remember to pass the right tenantId — same foot-gun the original bug was.
- Removing the parameter from the service signature eliminates the error at the type level: the method cannot be called with the wrong tenant because the caller cannot supply one.
- Symmetric with `ApiKeyController.createApiKey` and `SubscriptionController.create`, which already source `tenantId = TenantContext.getTenantId()` internally (confirmed by the warroom survey).

**Response code on URL-path mismatch:** 404 Not Found (per D3). Treating the path as "the resource collection of tenant X" and the caller as "not in tenant X" yields 404 naturally; this also matches the downstream unsafe-lookup behavior so cross-tenant probing produces a uniform signal to any caller.

**Alternatives considered:**
- *Silent redirect of the write to the caller's tenant.* Rejected — would return 201 Created for a URL path the caller does not own; confusing for legitimate admin tooling that might construct URLs from a tenant-selector UI.
- *422 Unprocessable Entity.* Rejected — leaks existence of the tenant in the URL path (mismatch implies the target tenant is real). 404 does not.
- *Remove `{tenantId}` from the URL entirely (breaking API change).* Rejected for this change — out of scope; would require client coordination. File follow-up if we do a breaking API version bump.

**Sibling services — deferred to follow-up:** `TenantConfigController.updateConfig`, `TenantController PUT /{id}/*` (if COC_ADMIN is in the role set), `OAuth2ProviderController.list` (read-side enumeration). The warroom survey confirmed `ApiKeyController`, `SubscriptionController`, and `AccessCodeController` are SAFE on URL-path-sink — they do not have `{tenantId}` in the URL path.

**Phase 3 enforcement extension:** the ArchUnit rule SHALL additionally fail the build when a class in `org.fabt.*.service` accepts `UUID tenantId` as a method parameter AND writes to a tenant-owned repository, unless the method is marked `@TenantUnscoped("justification")` (same escape hatch as unsafe-lookup). Exact rule shape is Phase 3's responsibility per D2.

**Casey's audit-trail note:** URL-path-sink writes produce a categorically distinct failure mode from unsafe-lookup reads. When a Tenant A admin successfully wrote a row into Tenant B, both tenants' audit trails became falsified evidence — Tenant A's audit shows action on "their" tenant (no indication of crossing), Tenant B's audit reviewer sees a row appear with no corresponding action by any Tenant B admin. This matters for VAWA per-tenant audit completeness and for HIPAA BAA audit integrity; documented here so downstream compliance review understands the fix closes a different class of legal risk than D1/D2/D3.

## Risks / Trade-offs

- **[Risk] ArchUnit rule misses a call path we didn't catalog.** → Mitigation: the ArchUnit rule runs on every test-classpath build, including CI; false negatives would be caught at the next test run. Write the rule to fail LOUDLY on violation (full package + method name in failure message).
- **[Risk] A legitimate admin endpoint starts returning 404 post-deploy where it used to return 200.** → Mitigation: unit tests per refactored service verify the happy path inside a single tenant. Smoke test includes one cross-tenant and one same-tenant probe per fixed endpoint. Rollback criterion is strict: any "can't do X inside my own tenant" report in the first 30 minutes post-deploy triggers rollback investigation.
- **[Risk] ArchUnit rule creates friction for future contributors who legitimately need to call `findById(UUID)` on a tenant-owned table.** → Mitigation: the `@TenantUnscoped("justification")` escape hatch is intentional and documented; the justification becomes the author's future-self note. If the rule proves too noisy after two weeks of use, loosen the package scope.
- **[Risk] The Karate E2E spec becomes a maintenance burden alongside the Playwright spec.** → Mitigation: the Karate spec asserts HTTP-level contract only (status codes + response body keys), not UI behavior. The Playwright spec covers the UI surface. They do not duplicate coverage; they cover different layers.
- **[Risk] The `fabt.security.cross_tenant_404s` counter has false positives (user typos, race conditions during referral expiry).** → Mitigation: the counter is paired with a Grafana threshold alert on spike-vs-baseline, not absolute rate. One typo per hour is fine; 100 in a minute is not. Document the alert threshold in the Grafana dashboard notes.
- **[Trade-off] Strict ArchUnit from day one fails the build until R1+R2 land.** → Mitigation: sequencing is explicit in tasks.md — the rule is introduced disabled in Phase 1, then activated in Phase 3 after Phase 2 fixes the call sites.
- **[Trade-off] `@TenantUnscoped` justification strings are free-form text, not a taxonomy.** → Acceptable — a taxonomy would be premature without seeing the natural set of use cases. Revisit after 10+ uses.
- **[Trade-off] Parameterized-fixture maintenance cost is real — every new endpoint adds a row.** → Acceptable — this is the same discipline the `DvReferralIntegrationTest` enforces; the warroom agrees the cost is much smaller than the next-leak cost.

## Migration Plan

**Sequencing (matches tasks.md phases — 6 total, Phase 6 is archive+sync via `/opsx:*`):**

1. **Phase 1 — Foundations.** `@TenantUnscoped` annotation + ArchUnit skeleton (disabled) + `findByIdOrThrow` pattern documentation. Ships as one commit; zero behavior change.
2. **Phase 2 — Service fixes (R1 + R2 + D7 + D10).** 5 VULN-HIGH + 2 VULN-MED + rename-and-restrict for `EscalationPolicyService` and `SubscriptionService` internal methods. Ships as one commit with matching unit + integration tests.
3. **Phase 3 — Test + guard.** Activate ArchUnit rule (strict); enable `CrossTenantIsolationParameterizedTest`; new unit tests per service. Ships as one commit. Build fails if Phase 2 missed a site — that's the point.
4. **Phase 4 — Docs + observability.** V56 RLS policy comment migration; `docs/security/rls-coverage.md`; SAFE-sites registry; Javadoc audit; `fabt.security.cross_tenant_404s` counter + Grafana panel. **Sub-tasks 4.1-4.4 can be parallelized across two contributors** (Elena on 4.1+4.2, any engineer on 4.3+4.4 + SAFE-sites registry).
5. **Phase 5 — E2E + rollout.** Playwright spec; Karate spec; release notes; runbook addition.
6. **Phase 6 — Archive + sync.** `/opsx:verify` → `/opsx:sync` → `/opsx:archive`; memory update.

**Red-test-first sequencing note (addresses warroom R5 "ship fixture first as a red test").** The warroom plan was: ship R5 (parameterized fixture) first as a failing test, then R1+R2 to green it. We depart from that plan because we ship as a single deploy with no broken-main interval. The integrity check moves into Phase 3: before committing the parameterized fixture green-against-Phase-2, the implementer `git stash`es the Phase 2 fixes locally and confirms the fixture goes red, then restores and confirms green. Task 3.4a encodes this locally-verified red/green cycle without ever committing a red-state main. This preserves the test-quality assurance of red-first without the ops cost of a mid-merge broken build.

**Single deploy** at the end of Phase 5. No flag gate. No canary (findabed.org is single-tenant; legitimate admins see no behavior change). Standard v0.XX.0 tag + release flow per `docs/oracle-update-notes-*` template.

**Rollback:** V56 is a `COMMENT ON POLICY` — trivially reversible via a new migration (or left as-is; comments don't affect behavior). All service-layer changes are backward compatible at the HTTP shape level (same path, same verbs, same auth) — only the behavior on cross-tenant access changes. Rollback is a standard `git checkout <previous-tag>` + rebuild.

**Rollback criteria (Jordan):**
- Legitimate admin reports 404 for a same-tenant resource within 30 minutes post-deploy → investigate bug in fix; roll back if not hot-fixable within the hour.
- `fabt.security.cross_tenant_404s` counter spikes without a corresponding demo-traffic explanation → investigate before rollback; likely benign.

## Open Questions

All 6 warroom open questions resolved pre-spec by user (Corey):

1. **EscalationPolicyService.findById fate:** rename to `findByIdForBatch` (D7).
2. **ArchUnit rule scope:** covers both `findById(UUID)` AND `existsById(UUID)` (D2).
3. **RLS for `tenant_oauth2_provider`:** considered and rejected, recorded in D4.
4. **Playwright vs Karate for E2E:** both (D8).
5. **ArchUnit strictness at launch:** strict (fail build) from day one (D2).
6. **AccessCodeController:51 admin-self-lookup:** fix for consistency (D10).

No remaining open questions. Ready for tasks.md.
