## 1. Branch + scaffolding (G-4.0 prework)

- [x] 1.1 Create branch `feature/platform-admin-split-and-access-log` off latest main (verify main is at v0.52.0+)
- [x] 1.2 Read `feedback_compile_locally_first.md` reminder; verify `mvn compile -q` clean baseline
- [x] 1.3 Read `project_oci_audit_anchor_credentials.md`, `project_live_deployment_status.md`, `project_logback_dedup_filter_v052_bug.md` for context
- [x] 1.4 Spin up `dev-start.sh` local stack; confirm v0.52 baseline: 8 batch jobs registered, V85 schema present
- [x] 1.5 Confirm warroom personas synthesis review captured (this OpenSpec is post-warroom; design decisions 8-16 reflect persona feedback)

## 2. G-4.1 — Schema + identity (V87)

- [x] 2.1 Create Flyway V87 migration `V87__platform_user_and_key_material.sql`:
  - `CREATE TABLE platform_user (id UUID PK, email TEXT, password_hash TEXT, mfa_secret TEXT, mfa_enabled BOOLEAN NOT NULL DEFAULT false, account_locked BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), last_login_at TIMESTAMPTZ NULL, anonymized_at TIMESTAMPTZ NULL)` — `anonymized_at` for GDPR Art-17 (Decision 15)
  - `CREATE UNIQUE INDEX platform_user_email_unique ON platform_user (email) WHERE email IS NOT NULL` — Elena's UNIQUE recommendation
  - `CREATE TABLE platform_user_backup_code (id UUID PK, platform_user_id UUID FK platform_user(id), code_hash TEXT NOT NULL, code_salt BYTEA NOT NULL, used_at TIMESTAMPTZ NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())` — SHA-256 + salt per Decision 12
  - `CREATE TABLE platform_key_material (id UUID PK, generation INT NOT NULL, kid TEXT NOT NULL UNIQUE, key_bytes BYTEA NOT NULL, active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())`
  - `INSERT INTO platform_user (id, email, password_hash, account_locked) VALUES ('00000000-0000-0000-0000-000000000fab', NULL, NULL, true)` — bootstrap row
  - `REVOKE ALL ON platform_user FROM fabt_app`
  - `REVOKE ALL ON platform_user_backup_code FROM fabt_app`
  - SECURITY DEFINER functions for fabt_app access (mirrors Phase G-1 chain-head pattern): `platform_user_lookup_by_email(email)`, `platform_user_update_login_state(...)`, `platform_user_record_failed_attempt(id)`, `platform_user_increment_lockout_counter(id)`, etc.
  - **`ALTER FUNCTION ... OWNER TO fabt;`** for each SECURITY DEFINER function (Elena's correctness check)
  - COC_ADMIN backfill WITH token-version bump (Decision 16):
    ```sql
    UPDATE app_user
       SET roles = roles || ARRAY['COC_ADMIN'],
           token_version = token_version + 1
     WHERE 'PLATFORM_ADMIN' = ANY(roles)
       AND NOT ('COC_ADMIN' = ANY(roles));
    ```
  - For tenants with > 10K admin rows (currently N/A but defensive): document batched DO-block as comment in migration (Elena's lock-contention note)
- [x] 2.2 Add `Role.PLATFORM_OPERATOR` to `Role.java`; mark `PLATFORM_ADMIN` `@Deprecated(forRemoval = true, since = "0.53.0")`; add Javadoc explaining migration path
- [x] 2.3 Run `mvn compile -q` locally; verify no compilation errors
- [x] 2.4 Add JUnit test `RoleEnumTest`: 4/4 pass (5 enum values; PLATFORM_ADMIN `@Deprecated(forRemoval=true, since="0.53.0")`; non-deprecated roles unannotated)
- [x] 2.5 Add Flyway integration test `V87MigrationIntegrationTest`: 13/13 pass (table shapes via pg_catalog since fabt_app lacks table grants; bootstrap row read via SECURITY DEFINER function; partial UNIQUE email index predicate verified; REVOKE on platform_user / platform_user_backup_code from fabt_app verified; SELECT-only on platform_key_material verified; SECURITY DEFINER functions enumerated; COC_ADMIN backfill applied; backfill is idempotent). Note: removed explicit `OWNER TO fabt` from migration since `fabt` role does not exist in test container; functions inherit ownership from migration runner per V82 precedent (Elena's correctness check satisfied implicitly — migration runner IS the table owner in both prod and test).
- [x] 2.6 Commit + PR #160: `feat(auth): G-4.1 — Role.PLATFORM_OPERATOR + V87 platform_user schema + COC_ADMIN backfill with token-version bump`. Post-implementation warroom review found 4 issues, all fixed pre-PR (added platform_key_material_create_first_active SECURITY DEFINER func per Alex; replaced EXCLUDE with partial UNIQUE index per Elena; restored defensive OWNER TO fabt via DO-block per Elena; added positive permission/constraint/CASCADE tests per Riley). First CI run surfaced 3 more failures fixed in amended commit `481293a`: (a) added V87 to `MigrationLintTest.SECURITY_DEFINER_ALLOWLIST` with warroom citation; (b) refactored 2 backfill assertions to controlled probe-row pattern (CI had 35 PLATFORM_ADMIN-only rows from other test fixtures' runtime inserts that V87 didn't see — global assertion was wrong); (c) updated `TestAuthHelper.setupAdminUser` to grant both PLATFORM_ADMIN+COC_ADMIN matching post-V87 reality. Final test count: RoleEnumTest 4/4, V87MigrationIntegrationTest 16/16, MigrationLintTest 1/1, auth-family smoke 42/42.

## 3. G-4.2 — Auth flow + JWT classes + fabt-cli + rate limits

- [x] 3.1 Create `org.fabt.auth.platform` package: `PlatformUser.java` entity, `PlatformUserRepository.java` (uses SECURITY DEFINER functions, NOT direct table SELECT)
- [x] 3.2 Create `PlatformKeyRotationService.java`: on app startup, if no active row in `platform_key_material`, derive key via HKDF from master KEK and INSERT (gen=1, kid=random UUID, active=true). Log clearly to ops log on key creation event.
- [x] 3.3 Create `PlatformJwtService.java`: issues JWTs with `iss="fabt-platform"`, no `tenantId` claim, 15-min expiry, signs with platform key from `platform_key_material`
- [x] 3.4 Create `PlatformAuthController.java` with endpoints: `POST /auth/platform/login`, `POST /auth/platform/mfa-setup`, `POST /auth/platform/mfa-confirm`, `POST /auth/platform/login/mfa-verify`
- [x] 3.5 Implement forced MFA-on-first-login flow: first password auth returns MFA-setup-only token (10-min expiry, scope-limited via JWT `scope` claim); MFA setup endpoint returns QR + 10 backup codes (SHA-256 hashed); confirm endpoint verifies TOTP and flips `mfa_enabled=true`. **MFA-setup token scope MUST be SERVER-validated, not just URL-path-restricted** (Marcus's hard constraint — explicit scenario in spec).
- [x] 3.6 Implement TOTP verification on subsequent logins: accepts TOTP code OR backup code; backup codes are SHA-256 + salt hashed in `platform_user_backup_code`, marked `used_at` on use
- [x] 3.7 Implement DUAL lockout: per-account 5-fail/15-min (locks account) AND per-IP 20-fail/15-min on `/auth/platform/*` (DDoS protection). Track per-account in DB; per-IP in JVM-scoped Caffeine cache (rebuilds on restart — acceptable for short window). Lockout entry written to `platform_admin_access_log` with action `PLATFORM_USER_LOCKED_OUT`. Cron task auto-unlocks after 15 min.
- [x] 3.8 Add per-IP rate limit on `/auth/platform/login` at 5/15min via bucket4j (Marcus's hard constraint — separate from MFA lockout above; this is the password-attempt throttle)
- [x] 3.9 Update `SecurityConfig.java` JwtDecoder: iss-routed dispatch (tenant kids → `jwt_key_generation`; platform kids → `platform_key_material`); validate iss BEFORE signature verification (avoid wasted compute on wrong-key signature attempts); ensure cross-tenant cross-check at `JwtService:409-424` is bypassed for platform JWTs (separate code path, NOT loosened conditional)
- [ ] ~~3.10 Create new Maven module `fabt-cli/` (Decision 8): pom.xml inheriting from parent~~ — **DEFERRED per design.md F4**: single-module project layout retained; `org.fabt.tooling.HashPasswordCli` ships inside the backend JAR instead. Multi-module split tracked as future work when ops volume justifies.
- [ ] ~~3.11 Update root pom.xml `<modules>` to include `fabt-cli`~~ — **N/A per F4 deferral above**.
- [x] 3.12 Add IT family `PlatformAuthIntegrationTest`: scenarios for first-login MFA flow, subsequent TOTP login, backup code use (SHA-256 verification), lockout after 5 failures (per-account), per-IP rate limit triggers at 6th request, MFA-setup token scope server-validated (presented to wrong endpoint → 403), account_locked rejects login, NULL password_hash rejects login
- [x] 3.13 Update `AuthControllerTest`: assert tenant login still uses `iss="fabt-tenant"`; add scenarios for forged platform JWT presented to tenant endpoint
- [x] 3.14 Run full `mvn test` locally; verify all G-4.2 ITs pass
- [x] 3.15 Commit: `feat(auth): G-4.2 — platform login + MFA + JWT class + iss-routed dispatch + V88 lockout schema` (shipped as `daf616d` via PR #161; fabt-cli module deferred per F4)

## 4. G-4.3 — Audited access log + AOP aspect (V89)

> **Slice numbering note (warroom 2026-04-25):** V88 was originally drafted
> here for the access log. During G-4.2 implementation we discovered that
> per-account MFA lockout requires DB columns + SECURITY DEFINER wrappers
> on `platform_user`, which naturally lives with the auth flow that uses
> them — so V88 is now claimed by G-4.2's `V88__platform_user_lockout_columns.sql`,
> and the access log shifts to **V89** here.

> **Warroom amendments (G-4.3 design review, 2026-04-25):** Seven
> decisions locked before implementation, plus three scope additions
> moved into G-4.3 from G-4.5. Numbered references appear inline below.
>
> **D1 (A2)** — PAL.audit_event_id has NO foreign-key constraint. Theoretical orphan risk accepted; AE deletes are forbidden by Phase B append-only posture. Revisit as F6 if a compliance audit flags it.
>
> **D2 (M3)** — `request_body_excerpt` stores `Content-Type` + `Content-Length` + `SHA-256(body)` only. Raw body content is NEVER captured; a forensic reader correlates the SHA-256 against application logs (which already redact sensitive fields per Phase A). Closes the "TenantController.create body contains config secrets" + "platform_user create contains password" leak vectors.
>
> **D3 (P1)** — `audit_events.details` JSONB does NOT contain `platform_user_email`. Stores `platform_user_id` only. Audit reader joins `platform_user` on demand; anonymized rows show "anonymized" in the join. Avoids the GDPR Art-17 retroactive-redaction problem in the audit chain.
>
> **D4 (E2)** — V89 ships an append-only trigger function `platform_admin_access_log_no_mutate()` raising on UPDATE/DELETE in addition to the `REVOKE`. Belt-and-suspenders against future `GRANT` regressions.
>
> **D5 (J1, F3 partial)** — `MDC.put("platform_action", "true")` set at aspect entry, removed at exit. Moved INTO G-4.3 (was deferred to G-4.5). The aspect is the natural place; without it the G-4.5 alerts have nothing to filter on.
>
> **D6 (A4)** — Lockout-transition PAL row is written by direct call from `PlatformAuthService.recordFailureAndMaybeLock`, NOT via the aspect. The lockout fires from an internal service path the aspect can't reach. New `PlatformAdminAccessLogger.logLockout(userId)` method exposes the same write surface.
>
> **D7 (A1)** — V89 schema adds CHECK constraints: `length(request_body_excerpt) <= 2000`, `pg_column_size(before_state) <= 65536`, `pg_column_size(after_state) <= 65536`. Aspect truncates / sanitizes pre-INSERT.

- [x] 4.1 Create Flyway V89 migration `V89__platform_admin_access_log.sql`:
  - `CREATE TABLE platform_admin_access_log (id UUID PK, platform_user_id UUID FK platform_user(id), action TEXT NOT NULL, resource TEXT NULL, resource_id UUID NULL, justification TEXT NOT NULL CHECK (length(trim(justification)) >= 10), request_method TEXT NOT NULL, request_path TEXT NOT NULL, request_body_excerpt TEXT NULL CHECK (request_body_excerpt IS NULL OR length(request_body_excerpt) <= 2000), before_state JSONB NULL CHECK (before_state IS NULL OR pg_column_size(before_state) <= 65536), after_state JSONB NULL CHECK (after_state IS NULL OR pg_column_size(after_state) <= 65536), audit_event_id UUID NULL, timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW())` — **D1**: NO FK on `audit_event_id`; **D7**: size CHECKs on excerpt + state columns
  - `REVOKE UPDATE, DELETE ON platform_admin_access_log FROM fabt_app`
  - **D4**: `CREATE FUNCTION platform_admin_access_log_no_mutate() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'platform_admin_access_log is append-only'; END; $$;` + `CREATE TRIGGER platform_admin_access_log_no_mutate_trigger BEFORE UPDATE OR DELETE ON platform_admin_access_log FOR EACH ROW EXECUTE FUNCTION platform_admin_access_log_no_mutate();`
  - Indexes: `(platform_user_id, timestamp DESC)`, `(timestamp DESC)`, `(resource_id) WHERE resource_id IS NOT NULL`, **`(action, timestamp DESC)`** (Elena's compliance-query optimization)
- [x] 4.2 Create annotation `@PlatformAdminOnly(reason String, emits AuditEventType)` per Decision 9. Both members are required (no default). Annotation has `@Target(ElementType.METHOD), @Retention(RetentionPolicy.RUNTIME)`.
- [x] 4.3 Add 12 new `AuditEventType` enum values: `PLATFORM_TENANT_CREATED`, `PLATFORM_TENANT_SUSPENDED`, `PLATFORM_TENANT_UNSUSPENDED`, `PLATFORM_TENANT_OFFBOARDED`, `PLATFORM_TENANT_HARD_DELETED`, `PLATFORM_KEY_ROTATED`, `PLATFORM_HMIS_EXPORTED`, `PLATFORM_OAUTH2_TESTED`, `PLATFORM_BATCH_JOB_TRIGGERED`, `PLATFORM_TEST_RESET_INVOKED`, `PLATFORM_USER_LOCKED_OUT`, `PLATFORM_USER_CREATED`, plus `PLATFORM_USER_RESET_TO_BOOTSTRAP` (folded in from F5 follow-up captured during G-4.2 hardening commit `aceb1d9`).
- [x] 4.4 Create `JustificationValidationFilter.java` (Spring filter, NOT aspect — Alex's split recommendation): checks `X-Platform-Justification` header presence + length >= 10 chars on requests to `@PlatformAdminOnly`-annotated endpoints; rejects 400 if invalid.
  - **(M2 implementation note):** Filter resolves the request to a controller method via `RequestMappingHandlerMapping.getHandler(request)`, then inspects the resolved `HandlerMethod.getMethodAnnotation(PlatformAdminOnly.class)`. Skip filter logic for non-`@PlatformAdminOnly` paths and for non-controller paths (static resources, error pages).
  - **(M-RV2 implementation drift, warroom 2026-04-25 G-4.3 review):** Original task said "BEFORE Spring Security" for a perf optimization on rejected requests. As implemented (`@Component` + `@Order(-100)` on an `OncePerRequestFilter`), the filter actually runs AFTER Spring Security (whose chain runs at `Ordered.HIGHEST_PRECEDENCE + 50 = Integer.MIN_VALUE + 50`, much higher precedence than `-100`). We deliberately KEEP the post-Security ordering rather than forcing pre-Security via a `FilterRegistrationBean`. Rationale: post-Security ordering means an unauthenticated probe to a `@PlatformAdminOnly` endpoint gets 401 (no info-disclosure), authenticated-wrong-role gets 403, and only authenticated-correct-role-missing-justification gets 400. Better security posture; perf cost is microseconds on platform-admin endpoints (low volume).
- [x] 4.5 Create `PlatformAdminLogger.java` (Spring AOP aspect, single-purpose per Alex): runs `@Around` on methods annotated `@PlatformAdminOnly`. In a single REQUIRES_NEW transaction:
  - **D5**: `MDC.put("platform_action", "true")` at aspect entry; `MDC.remove("platform_action")` in finally block at exit
  - Generate UUIDs for new PAL row and new AE row up front (client-side, Decision 11)
  - **D2**: Compute `request_body_excerpt = "Content-Type=" + ct + ";Content-Length=" + cl + ";SHA-256=" + hex(sha256(body))` — never raw body content
  - **(P2 sanitization)**: For `before_state`/`after_state`, capture only an explicit allowlist of fields (`status`, `slug`, `name`, `created_at` for tenant actions; method-specific allowlists for others). NEVER capture credentials / OAuth2 secrets / API keys.
  - INSERT PAL with `audit_event_id = <pre-gen AE UUID>`, `justification = "<annotation reason> | request: <header value>"`
  - **D3**: INSERT AE with `id = <pre-gen AE UUID>`, `action = <annotation.emits()>`, `details = jsonb_build_object('platform_admin_access_log_id', <pre-gen PAL UUID>, 'platform_user_id', <pu-id>, 'justification_excerpt', substr(justification, 1, 200), 'request_method', <method>, 'request_path', <path>)` — **NO `platform_user_email` field**
  - Determine AE `tenant_id` from method parameter named `tenantId` (UUID type) — defaults to SYSTEM_TENANT_ID
  - **Special case**: if `annotation.emits() == PLATFORM_TENANT_HARD_DELETED`, force `tenant_id = SYSTEM_TENANT_ID` regardless of method param (Decision 13 — survives the cascade delete)
  - If `tenant_id != SYSTEM_TENANT_ID`, AuditChainHasher chains the row (Phase G-1 path)
  - Commit; method body executes
  - On commit failure: log WARN to application log with `platform_action: true` MDC marker (Jordan's SOC filtering)
- [x] 4.5a **(D6)** Add `PlatformAdminAccessLogger.logLockout(UUID userId)` method that emits the same PAL + AE rows for `PLATFORM_USER_LOCKED_OUT` action, called directly (NOT via aspect) from `PlatformAuthService.recordFailureAndMaybeLock` when the lockout transition fires. The aspect can't reach internal service calls.
- [x] 4.6 Apply `@PlatformAdminOnly(reason="canary endpoint for G-4.3 — exercises AOP aspect", emits=AuditEventType.PLATFORM_BATCH_JOB_TRIGGERED)` to `BatchJobController.run` only (canary; rest in G-4.4); also apply `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")`
- [x] 4.7 Add IT family `PlatformAdminAccessAspectTest`:
  - missing X-Platform-Justification → 400 (filter rejection), no log rows
  - justification < 10 chars → 400, no log rows
  - **method throws AFTER aspect commit → both log rows persist (REQUIRES_NEW commit semantics test)** (Riley's specific requirement)
  - unauthorized request (wrong role) → 403 (Spring Security rejection), no log rows (filter ran but aspect did not — Spring Security runs between filter and aspect)
  - successful call → both rows present and linked by id (PAL.audit_event_id == AE.id; AE.details->>'platform_admin_access_log_id' == PAL.id)
  - tenant-affecting action (e.g., suspend with tenantId=X) → audit_events.tenant_id = X; chained
  - PLATFORM_TENANT_HARD_DELETED action → audit_events.tenant_id = SYSTEM_TENANT_ID (NOT target tenant — Decision 13)
  - platform-wide action (BatchJobController.run) → audit_events.tenant_id = SYSTEM_TENANT_ID; not chained
  - **(R1 from G-4.3 warroom)** body-not-captured: POST a body, assert `request_body_excerpt` contains `SHA-256=...` + `Content-Type=...` + `Content-Length=...`, NEVER raw body content
  - **(R1)** FK enforcement: INSERT into PAL with `platform_user_id` not in `platform_user` raises constraint violation despite REVOKE on platform_user (proves FK works via constraint trigger)
  - **(R1, J1)** MDC marker: assert `MDC.get("platform_action") == "true"` inside the proceeding business method; assert removed after aspect exit
  - **(D4)** append-only trigger fires: directly attempt UPDATE / DELETE against PAL as fabt_app, expect `platform_admin_access_log is append-only` error
  - **(P2)** sanitization: a tenant-suspend action's `before_state` does NOT contain OAuth2 client secrets / HMIS API keys / passwords
- [x] 4.7a **(R3)** Build `TestAuthHelper.setupPlatformUser(...)` once. Inserts a platform_user row at a chosen UUID with known email + bcrypt password + plaintext mfa_secret (skips the enrollment flow), generates 10 backup codes with known plaintexts → SHA-256+salt-stored. Returns `{userId, plaintextPassword, totpSecret, plaintextBackupCodes, accessToken}`. Used by every IT in G-4.3 / G-4.4 / G-4.5.
- [x] 4.8 Add ArchUnit test `PlatformAdminOnlyArchitectureTest`:
  - **(existing)** Any method annotated `@PlatformAdminOnly` MUST also be annotated `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` (defense-in-depth). Scope rule to `.java` source files only (Riley — exclude SQL migration files which legitimately mention `PLATFORM_ADMIN`).
  - **(R4 new)** Any method annotated `@PlatformAdminOnly` MUST be in a `..api..` package (controller layer only — service-layer audit annotations are out of scope for this aspect).
- [x] 4.9 Run `mvn test` locally
- [x] 4.10 **(metrics — J2)** Aspect emits Micrometer counters: `fabt.platform.admin.action{action=<emits>, outcome=committed|aspect_failed|method_failed_after_audit}`; filter emits `fabt.platform.admin.justification.rejected{reason=missing|too_short}`. G-4.5 Prometheus alerts query these; without the counters the alert rules have nothing to fire on.
- [x] 4.11 Commit: `feat(audit): G-4.3 — V89 platform_admin_access_log + @PlatformAdminOnly(reason,emits) + JustificationValidationFilter + PlatformAdminLogger aspect (warroom-vetted)` (shipped as `1e1498d` via PR #162)

## 5. G-4.4 — Endpoint migration + Playwright + ArchUnit guard

> **Warroom amendments (G-4.4 design review, 2026-04-25):** 9 changes
> applied based on the warroom held during G-4.3 CI runtime. Numbered
> references inline.
>
> **Confirmed decisions (no scope change, captured for reference):**
> - Frontend platform-operator UI is **out of scope for v0.53**; UI ships
>   in a separate slice after G. Buttons that currently invoke platform
>   endpoints will get 403; G-4.5 §6.b will add a UI shim that
>   hides/grays them. Captured as F11 follow-up in design.md.
> - Q1 from design.md (hide platform login link in prod public nav):
>   **lean = yes, hide in prod, visible in dev** — confirm during
>   implementation.
> - G-4.3 MUST deploy before G-4.4. Naturally enforced by the
>   `@PlatformAdminOnly` → V89 dependency chain.

### 5.a Migrate the 18 @PreAuthorize sites

- [x] 5.1 Identify the 11 tenant-scoped sites (verified ground truth from Phase G-3 deploy session): TestResetController (1), TenantConfigController (2), UserController, ApiKeyController, OAuth2ProviderController, TotpController, AccessCodeController, PasswordController, AvailabilityController (admin), ShelterController (admin) — exact split confirmed during implementation by grepping `@PreAuthorize.*PLATFORM_ADMIN` and reviewing each
- [x] 5.2 Migrate the 11 tenant-scoped sites: change `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` → `@PreAuthorize("hasRole('COC_ADMIN')")`. **(R-S3 pairing rule):** each endpoint migration commits PAIRED with its test migration (don't separate) to keep main green.
- [x] 5.3 Identify the 7 platform-scoped sites: TenantController.create, TenantLifecycleController (suspend/unsuspend/offboard/hardDelete = 4 sites), TenantKeyRotationController.rotate (1), HmisExportController (6 — **REVERTED to COC_ADMIN in triage pass 2 per F14**; service reads TenantContext, incompatible with platform JWTs), OAuth2TestConnectionController.test (1), BatchJobController (4 — `/run` already canaried in G-4.3, **plus 3 siblings: `/restart`, `/abandon`, `/stop` per warroom M-S3** must also receive `@PlatformAdminOnly`).
- [x] 5.4 Migrate the 7 platform-scoped sites: change `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` → `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` AND add `@PlatformAdminOnly(reason="<endpoint-specific justification template>", emits=AuditEventType.<appropriate>)` annotation. Each site picks its own AuditEventType from the 10 new values. **Triage pass 2 amendments:** HMIS push/vendors reverted to COC_ADMIN (F14); TenantPathGuard removed from 4 TenantController @PlatformAdminOnly methods (F15) since platform JWTs carry no tenantId.
- [x] 5.4a **(A-S1 NEW)** State capture mechanism. The G-4.3 aspect leaves `before_state` / `after_state` JSONB columns NULL because it can't reasonably know HOW to capture state per action. Add a request-scoped `PlatformActionStateCapture` bean exposing `captureBefore(Object stateAllowlist)` / `captureAfter(Object stateAllowlist)` helpers. Each `@PlatformAdminOnly` controller method that has meaningful state delta (TenantLifecycleController.suspend/unsuspend/offboard/hardDelete, TenantKeyRotationController.rotate) calls the helpers explicitly with an allowlisted snapshot. The aspect drains the captured state into the PAL row at audit-write time. Allowlist enforcement happens at the helper boundary so credentials / OAuth2 secrets / API keys CANNOT slip into PAL rows.
- [x] 5.4b **(M-S2 BLOCKER → F2 lands here)** `@PlatformAdminOnly` aspect or the JustificationValidationFilter MUST assert `mfaVerified=true` on the platform JWT. Defense-in-depth on top of G-4.2's `JwtAuthenticationFilter.handlePlatformToken` which already requires `mfaVerified` before binding SecurityContext. Reject 401 if a token somehow reaches a `@PlatformAdminOnly` endpoint with `mfaVerified=false`. ~5 LoC + 1 IT scenario (R-S4 below).
- [x] 5.5 Update SecurityConfig.java path patterns. Triage pass 2 added `/api/v1/test/**` widening to PLATFORM_OPERATOR + PLATFORM_ADMIN (URL rule was short-circuiting platform-operator JWTs from reaching TestResetController's @PreAuthorize gate).
- [x] 5.6 Add ArchUnit test `NoPlatformAdminPreauthorizeTest`: build fails if any `@PreAuthorize` annotation in `org.fabt.*.api` references `PLATFORM_ADMIN`. Scope to `.java` files only. **Plus** triage pass 2 added narrow exception to `shared_non_security_should_not_depend_on_modules` rule for `auth.platform.PlatformAdminOnly` (cross-cutting security annotation analogous to @PreAuthorize).

### 5.b Playwright fixture refactor

- [x] 5.7 Create test helper `e2e/playwright/auth/multi-tenant-seed.ts`: seeds tenants A and B, creates COC_ADMIN of A, returns auth tokens for both. Reusable across CrossTenantIsolationTest scenarios (Riley's test infrastructure requirement).
- [x] 5.8 Create test helper `e2e/playwright/auth/totp-helper.ts`: **(R-S1 amendment)** instead of reading `platform_user.mfa_secret` directly from test DB (blocked by V87 REVOKE), the helper receives the plaintext secret from `TestAuthHelper.setupPlatformOperator` (or a small test-profile-only HTTP endpoint that wraps it). Computes valid TOTP code at test time using the secret + current Unix time / 30 (RFC 6238). Used by platformOperatorPage fixture for automated MFA login.
- [x] 5.9 Update `e2e/playwright/auth/admin.json` (the `cocadminPage` fixture): seed user already has COC_ADMIN via V87 backfill; verify fixture authenticates and JWT now has `roles=[COC_ADMIN]`; update any test that asserted role string explicitly
- [x] 5.10 Create `e2e/playwright/auth/platform-operator.json` fixture: helper provisions a test platform_user with known password + seeds TOTP secret directly (test profile only); platformOperatorPage fixture uses `/auth/platform/login` + totp-helper
- [x] 5.11 Update existing tests that explicitly required PLATFORM_ADMIN — replace with platformOperatorPage where appropriate. Per R-S3, this happens IN THE SAME COMMIT as the corresponding endpoint migration in 5.2 / 5.4.
- [x] 5.12 Add new Playwright test `platform-admin-access-log.spec.ts`: PLATFORM_OPERATOR triggers BatchJobController.run with X-Platform-Justification header; verify audit_events row exists under SYSTEM_TENANT_ID and platform_admin_access_log row exists with expected justification
- [x] 5.13 Add Playwright test `platform-totp-lockout.spec.ts`: 5 failed TOTP verifications → account locked → 401 on subsequent attempts. **(R-S2 amendment)** Test profile externalizes `PlatformLockoutCronJob` rate via a `@Value("${fabt.platform.lockout-cron.fixed-rate-ms:60000}")` property + override in `application-test.yml`. OR: expose a test-only `unlockExpiredNow()` HTTP endpoint that the test calls deterministically. Recommend the test-only endpoint (more deterministic).
- [x] 5.13a **(R-S4 NEW, paired with 5.4b)** Add IT scenario to `PlatformAdminAccessAspectTest`: a forged platform JWT with `mfaVerified=false` presented to a `@PlatformAdminOnly` endpoint → 401, no log rows.

### 5.c Verification

- [x] 5.14 Run full backend `mvn test` locally; verify ArchUnit + integration + new aspect tests pass — **DONE 2026-04-25 night, 1242/1242 green at 6d64075**
- [x] 5.15 Run full Playwright suite via dev-start.sh nginx (port 8081)
- [x] 5.16 **(M-S1 amendment)** PR description for the migration commit MUST include a per-endpoint OLD-role → NEW-role + chosen `AuditEventType` table. Reviewer signs off endpoint-by-endpoint. The ArchUnit guard at 5.6 catches "PLATFORM_ADMIN still appears" but not misclassification (wrong cohort, wrong AuditEventType, accidental role widening); this manual review step closes the gap.
- [ ] ~~5.16a **(C-S1 NEW)** Customer-communication note for v0.53 release notes + runbook section~~ — **DEFERRED per operator decision 2026-04-26**: customer-comms send cancelled for v0.53 deploy. Reference template retained in `oracle-update-notes-v0.53.0.md` §3 for future deploys that reactivate the comms step.
- [x] 5.17 Commit: `feat(auth): G-4.4 — endpoint migration + Playwright fixtures + ArchUnit guard + mfaVerified assertion (warroom-vetted)` (shipped as `7f735b2` via PR #163)

## 6. G-4.5 — Demo expansion + DV defenses + accessibility + monitoring (NEW slice — split from G-4.4 per Riley)

### 6.a Demo seed expansion

- [x] 6.1 Update `infra/scripts/seed-data.sql`: ensure existing seed admin@dev.fabt.org becomes COC_ADMIN; add seed users for dev-coc-west and dev-coc-east (admin, outreach, dv-coordinator, dv-outreach × 3 tenants = 12 total). All `admin123`.
- [x] 6.2 Verify all 12 seed users authenticate with `admin123` against their respective tenantSlug
- [x] 6.3 Update `index.html` "Try it Live" section: list all 12 demo users grouped by tenant with role labels (CoC Admin, Outreach Worker, DV Coordinator, DV Outreach Worker); per-user one-sentence description (Devon's accessibility/clarity recommendation)
- [x] 6.4 Add public monitoring notice to "Try it Live": "These are real demo credentials in a real environment. The demo is monitored; abuse triggers automated rate-limits and alerts." Visible body text, not footer.
- [x] 6.5 Update `frontend/src/i18n/{en,es}.json` for any "Platform Admin" → "CoC Admin" string changes; add new strings for platform-operator-related UI; finalize role display labels (Maria's spec: "CoC Admin", "CoC Administrator", or "Administrator (CoC scope)" — pick one in this task)
- [x] 6.6 Update README.md role/user table to reflect new role taxonomy

### 6.b DV-defense package (6 items)

- [x] 6.7 Add bucket4j filter entry: per-IP rate limit on `POST /api/v1/dv-referrals` at 5/hour
- [x] 6.8 Add Prometheus metric `fabt_dv_referrals_created_total` labeled by source_ip; add alert rule `FabtDvReferralBurstFromSingleIp` in `deploy/prometheus/dv-defenses.rules.yml` (rate > 10/min sustained 2 min) — cardinality nuance captured as F22 in design.md
- [x] 6.9 Create `docs/security/dv-incident-response.md` with documented psql queries for identifying suspicious DV access patterns; tabletop with persona
- [x] 6.10 Implement `dvReferralDemoCleanup` batch job (cron: every 6 hours): DELETE PENDING DV referrals from demo tenants older than 48 hours; emits `DV_REFERRAL_DEMO_CLEANUP` audit event under affected tenant chain — gated by `@Profile("demo")` + `slug LIKE 'dev-%'` (belt + suspenders)
- [x] 6.11 Add Sec-Fetch-Site header check on `POST /api/v1/dv-referrals`: reject 403 if header present and value is `cross-site`; allow if header is `same-origin`/`same-site`/`none` or absent. Document in spec that this is "raise abuse cost slightly" not "block abuse" (Marcus's accuracy note).

### 6.c Accessibility refinements (Tomás)

- [x] 6.12 TOTP entry input HTML semantics: `<input type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" aria-label="6-digit code from authenticator">`. Apply on platform login MFA verify page AND tenant-side TOTP enrollment confirm.
- [x] 6.13 QR code page semantics: `<canvas role="img" aria-label="...">` plus `<details>` disclosure with code + keyboard-accessible Copy button (kept the disclosure pattern instead of always-visible per UX read; both forms are keyboard-accessible).
- [x] 6.14 Backup codes display: semantic `<ol>` with each code in `<li>`; per-code copy-to-clipboard button (keyboard accessible); copy-all + download + print buttons; `@media print` rule with `.fabt-print-hide` class; large monospace; "Save these codes" h2 heading
- [x] 6.15 Lockout error region: `aria-live="polite"` + `aria-atomic="true"` + conditional `role="alert"` on the LoginPage error div. Lockout text comes from API (already localized).
- [x] 6.16 "Try it Live" page caption: existing `<table>` already had thead/tbody/th[scope=col]; added `<caption>` describing the multi-tenant matrix purpose. Caption replaces the prior aria-label so sighted users get the same context too.

### 6.d Monitoring + observability additions (Jordan)

- [x] 6.17 Add Prometheus alert rules in `deploy/prometheus/phase-g-platform-admin.rules.yml`:
  - [x] `FabtPlatformLoginFailureBurst` — backed by `fabt.platform.login.failures{reason}` counter (4 reasons: bad_email/locked/bad_password/mfa_disabled)
  - [x] `FabtPlatformActionWithoutJustification` — backed by `fabt.platform.action.without_justification{action}` counter; aspect-side defense-in-depth check that throws AccessDeniedException if X-Platform-Justification missing
  - [ ] `FabtPlatformUserDelayedActivation` — DEFERRED to F28 (needs V94 SECURITY DEFINER function + scheduled gauge; operational gap covered by isLoginAllowed() + §5.10 runbook)
  - [x] `FabtPlatformUserLockedOut` — backed by `fabt.platform.user.locked_out` counter; fires only on the lockout TRANSITION
- [x] 6.18 MDC marker `platform_action: true` — already applied at PlatformAdminLogger aspect entry from G-4.4 (line 124-125); added explicit set+remove in PlatformAdminAccessLogger.logLockout error path so SOC filters catch service-internal lockout audit failures too.
- [x] 6.19 `docs/observability/platform-admin-monitoring.md` — what v0.53 emits (counters + MDC + audit_events surfaces), 3 active alert rules + 1 deferred (F28), 6 Grafana panel sketches for Phase H+, dashboard JSON skeleton.

### 6.e Verification

- [x] 6.20 Run full backend + Playwright tests (backend 1278/1278 GREEN; Playwright through G-4.5 + post-deploy smoke 14/15 with F36 testID-viewport flake on test 13)
- [x] 6.21 Run `make rehearse-deploy` — PASS at 2026-04-26 17:18:08 UTC (safe-to-tag window)
- [x] 6.22 Commit: `feat(auth): G-4.5 — demo expansion + DV defenses + accessibility + monitoring` (shipped as `48398ae` via PR #164)

## 6a. G-4.6 — TenantLifecycleController REST endpoints (NEW slice, decided 2026-04-25)

> **Why this slice was added:** during G-4.4 inventory we discovered
> tasks.md §5.3 referenced a `TenantLifecycleController` (suspend /
> unsuspend / offboard / hardDelete) that was aspirational — Phase F
> shipped the service layer + state machine but never landed REST
> endpoints. The audit-chain story for v0.53 wants every tenant
> lifecycle action to flow through the `@PlatformAdminOnly` aspect so
> operators get PAL + chained AE rows with justification + identity.
> Without this slice, lifecycle actions in production would happen via
> `psql` against the DB owner — no audit row produced, no MFA gate.
> 4-6h of work; service layer + state machine already battle-tested in
> Phase F so the controller is a thin wrapper. Captured as design.md F12.

- [x] 6a.1 Create `org.fabt.tenant.api.TenantLifecycleController`. Four endpoints, each a thin wrapper over the existing `TenantLifecycleService` method:
  - `POST /api/v1/tenants/{id}/suspend` → `TenantLifecycleService.suspend(tenantId, justification)`
  - `POST /api/v1/tenants/{id}/unsuspend` → `unsuspend(...)`
  - `POST /api/v1/tenants/{id}/offboard` → `offboard(...)`
  - `DELETE /api/v1/tenants/{id}` → `hardDelete(...)` (HTTP DELETE matches the destructive nature; controller method body is the same plumbing)
- [x] 6a.2 Each endpoint annotated:
  - `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")`
  - `@PlatformAdminOnly(reason="<endpoint-specific>", emits=AuditEventType.PLATFORM_TENANT_<ACTION>)` — picks the matching enum value already added in G-4.3 §4.3
- [x] 6a.3 Each endpoint uses `PlatformActionStateCapture` (G-4.4 §5.4a) to record before/after state. Allowlist for tenant lifecycle: `{slug, name, state, archived_at}` — never `tenantId` (in path), never DEKs/keys.
- [x] 6a.4 Add IT family `TenantLifecycleControllerTest`:
  - happy-path suspend → 200, tenant.state=SUSPENDED, PAL + AE rows with PLATFORM_TENANT_SUSPENDED action, AE.tenant_id = target tenant (chained)
  - happy-path unsuspend / offboard / hardDelete (state-machine valid pre-conditions)
  - state-machine rejection: suspend on already-SUSPENDED tenant → 409 (or whatever the existing `IllegalStateTransitionException` maps to); aspect's audit row WAS committed (REQUIRES_NEW pre-method per Decision 11) so PAL row exists with PLATFORM_TENANT_SUSPEND_REJECTED... wait, Phase F's existing service emits TENANT_SUSPEND_REJECTED via `DetachedAuditPersister`. Decide: does the aspect-emitted PLATFORM_TENANT_SUSPENDED still write because the aspect commits BEFORE proceed throws? Per G-4.3 IT pattern "method throws AFTER aspect commit → both log rows persist" — yes, PAL row exists. Document this is acceptable: the aspect captures the ATTEMPT; runbook correlates with TENANT_SUSPEND_REJECTED at the same audit_event_id timestamp.
  - PLATFORM_TENANT_HARD_DELETED: AE.tenant_id forced to SYSTEM_TENANT_ID (Decision 13) so the audit row survives the cascade delete; verify after the call that tenant row is gone but PAL + AE rows persist
  - missing X-Platform-Justification → 400 (filter rejection per G-4.3)
  - non-PLATFORM_OPERATOR caller (e.g., COC_ADMIN tenant JWT) → 403
  - mfaVerified=false platform JWT → 401 (per G-4.4 §5.4b mfaVerified gate)
- [x] 6a.5 Update SecurityConfig.java: `/api/v1/tenants/**` URL rules — `POST/PUT/DELETE` paths require `PLATFORM_OPERATOR`; `GET /api/v1/tenants/*/oauth2-providers/public` remains public per G-4.2 (already permitAll).
- [ ] 6a.6 New Playwright spec `tenant-lifecycle.spec.ts` — **DEFERRED**: backend IT (`TenantLifecycleControllerTest` 7/7 GREEN) covers the contract; Playwright spec was descoped per warroom and is not deploy-blocking. Capture as v0.54+ follow-up alongside F11 platform-operator UI work.
- [x] 6a.7 Run full backend + Playwright tests (backend 1278/1278 + post-deploy smoke 14/15 — F36 flake on test 13)
- [x] 6a.8 Commit: `feat(tenant): G-4.6 — TenantLifecycleController REST endpoints + warroom hardening (#165)` (shipped as `f4cb151`; warroom-driven additions: PlatformAdminLogger.resolveAndWarnOnFallback, @Order(HIGHEST_PRECEDENCE) on TenantLifecycleExceptionAdvice, F31-F36 follow-ups)

## 7. Documentation + runbook

- [x] 7.1 Create `docs/runbook.md` section "First platform_user activation" — landed as `oracle-update-notes-v0.53.0.md` §5.10 (per the per-release runbook pattern; not a single docs/runbook.md). Covers HashPasswordCli invocation, UPDATE platform_user SQL, MFA enrollment via the API flow.
- [ ] 7.2 Create `docs/runbook.md` section "Platform key rotation break-glass" — **DEFERRED** to v0.54+ documentation pass; not exercised yet.
- [ ] 7.3 Create `docs/security/platform-admin-justification-conventions.md` — **DEFERRED** to v0.54+.
- [ ] 7.4 Create `docs/training/platform-operator-101.md` — **DEFERRED** to v0.54+ (likely paired with F11 platform-operator UI ship).
- [ ] 7.5 Create `docs/operations/platform-operator-handbook.md` — **DEFERRED** to v0.54+ (paired with F11 + first non-demo tenant onboarding).
- [x] 7.6 Update `docs/oracle-update-notes-v0.53.0.md` per `feedback_runbook_template_v1.md` — done multiple times this slice, including ground-truth fixes (commits `49e6a9e`, `39542f9`, `9dc67ea`).
- [ ] 7.7 Create `docs/security/platform-admin-forensic-walk.md` — **DEFERRED** to v0.54+.
- [x] 7.8 Update frontend role-visibility checks for COC_ADMIN — handled in G-4.5 §6.b UI shim work (admin panel + i18n role label sweep).
- [ ] 7.9 Update `PLATFORM-STANDARDS.md` (in `corey-portfolio-platform` repo): add Lesson 79 — **DEFERRED** (separate repo; not part of this OpenSpec slice's scope).
- [x] 7.10 Update memory: `project_live_deployment_status.md` rewritten to v0.53 state; `project_phase_g_implementation_plan.md` to be marked complete; resume point + new feedback memories saved (`feedback_runbook_groundtruth_vm.md`, `feedback_platform_login_via_ssh_tunnel.md`, `project_live_demo_seed_inventory.md`, `project_f11_platform_login_ui_priority.md`).
- [ ] ~~7.11 Draft customer-facing 1-paragraph note~~ — **DEFERRED per operator decision**: customer-comms cancelled for v0.53. Reference template at `oracle-update-notes-v0.53.0.md` §3 retained for future deploys.

## 8. Pre-deploy gates (v0.53.0 release prep)

- [x] 8.1 Open release-prep PR: pom version bump `0.52.0 → 0.53.0`; CHANGELOG.md `[v0.53.0]` entry — shipped as `afbb310 chore(release): v0.53.0 — bump pom + promote CHANGELOG`. (No fabt-cli.jar release artifact per F4 deferral.)
- [x] 8.2 CI green on main (Backend Maven, E2E, CodeQL, ArchUnit, legal-language scan) — confirmed before tag (Backend + CodeQL green; E2E was in_progress at tag time, user explicit override per `feedback_release_after_scans.md` precedent).
- [x] 8.3 Tag v0.53.0; push tag; create GitHub release with notes from `RELEASE-v0.53.0.md` — done at https://github.com/ccradle/finding-a-bed-tonight/releases/tag/v0.53.0.
- [x] 8.4 Run `make rehearse-deploy` within 72h of tag — PASS at 2026-04-26 17:18:08 UTC; tag at ~22:30 UTC same day; well within 72h window.

## 9. Deploy (v0.53.0)

- [x] 9.1 Pre-deploy gate: confirm v0.52.0 baseline on prod (Flyway HWM = 85, 3 tenants, all 8 batch jobs registered) — verified during runbook §5.1-§5.3.
- [x] 9.2 Pre-deploy gate: pg_dump → `~/fabt-backups/v0.53.0-pre-{schema,data}.sql` (92KB schema + 1.76MB data) per §5.4.
- [x] 9.3 Pre-deploy operator readiness checklist — all 5 items confirmed before §5.10.
- [x] 9.4 Deploy v0.53.0 per oracle-update-notes runbook (5-file compose chain — same as v0.52). Force-recreate completed at 2026-04-26 ~22:55 UTC.
- [x] 9.5 Verify backend healthy + Flyway HWM = **89** (V87+V88+V89 all `success=t` at 22:56:23 UTC) + COC_ADMIN backfill applied + token_version incremented per §5.7-§5.9.
- [x] 9.6 Activate first platform_user via `org.fabt.tooling.HashPasswordCli` + UPDATE `platform_user` SQL (heredoc-piped to avoid shell `$` expansion of bcrypt hash — see v0.53 Lesson 5).
- [x] 9.7 Login at API endpoint (no UI yet per F11 deferral); MFA enrolled via `/login` → `/mfa-setup` → `/mfa-confirm` curl flow; 10 backup codes saved off-VM.
- [ ] 9.8 Trigger BatchJobController.run as canary — **DEFERRED**: §6.5/§6.6/§6.7 surface checks confirmed gate behavior + endpoint reachability + @ConditionalOnProperty for G-4.6. Canary run is a redundant smoke if the endpoint surfaces are correct; capture as v0.54 if needed.
- [ ] 9.9 Provision 2nd platform_user as recovery contact — **DEFERRED**: `/api/v1/platform/users` (provisioning endpoint) ships in F11 UI slice. For now, recovery is via direct `platform_user_reset_to_bootstrap` SECURITY DEFINER call on the VM.
- [x] 9.10 Run Playwright smoke against findabed.org — 14/15 passed; 1 failure is F36 testID-conditional-on-viewport, NOT a deploy regression.

## 10. Post-deploy housekeeping

- [x] 10.1 Update `project_live_deployment_status.md` with v0.53.0 state — done.
- [ ] 10.2 Mark issue #141 closed on GitHub with link to v0.53.0 release notes — **PENDING** (operator action).
- [x] 10.3 Save resume point memory: Phase G-4 complete; F11 platform-operator UI prioritized as next slice (per operator post-deploy decision); reentry-spec bumped one slot.
- [ ] 10.4 Calendar reminder: post-v0.53 cleanup release should remove `Role.PLATFORM_ADMIN` enum value entirely after one release window of deprecation — **PENDING** (operator action).
- [ ] 10.5 Verify OCI anchor still working post-deploy (week-1 anchor should fire on schedule and include the new platform-admin audit rows for tenants with chained PLATFORM_* events) — **PENDING** (passive verification, fires on its own cron schedule).
- [ ] ~~10.6 Send customer-facing role-split note~~ — **DEFERRED per operator decision**: customer-comms cancelled for v0.53.
