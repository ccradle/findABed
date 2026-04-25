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

- [ ] 3.1 Create `org.fabt.auth.platform` package: `PlatformUser.java` entity, `PlatformUserRepository.java` (uses SECURITY DEFINER functions, NOT direct table SELECT)
- [ ] 3.2 Create `PlatformKeyRotationService.java`: on app startup, if no active row in `platform_key_material`, derive key via HKDF from master KEK and INSERT (gen=1, kid=random UUID, active=true). Log clearly to ops log on key creation event.
- [ ] 3.3 Create `PlatformJwtService.java`: issues JWTs with `iss="fabt-platform"`, no `tenantId` claim, 15-min expiry, signs with platform key from `platform_key_material`
- [ ] 3.4 Create `PlatformAuthController.java` with endpoints: `POST /auth/platform/login`, `POST /auth/platform/mfa-setup`, `POST /auth/platform/mfa-confirm`, `POST /auth/platform/login/mfa-verify`
- [ ] 3.5 Implement forced MFA-on-first-login flow: first password auth returns MFA-setup-only token (10-min expiry, scope-limited via JWT `scope` claim); MFA setup endpoint returns QR + 10 backup codes (SHA-256 hashed); confirm endpoint verifies TOTP and flips `mfa_enabled=true`. **MFA-setup token scope MUST be SERVER-validated, not just URL-path-restricted** (Marcus's hard constraint — explicit scenario in spec).
- [ ] 3.6 Implement TOTP verification on subsequent logins: accepts TOTP code OR backup code; backup codes are SHA-256 + salt hashed in `platform_user_backup_code`, marked `used_at` on use
- [ ] 3.7 Implement DUAL lockout: per-account 5-fail/15-min (locks account) AND per-IP 20-fail/15-min on `/auth/platform/*` (DDoS protection). Track per-account in DB; per-IP in JVM-scoped Caffeine cache (rebuilds on restart — acceptable for short window). Lockout entry written to `platform_admin_access_log` with action `PLATFORM_USER_LOCKED_OUT`. Cron task auto-unlocks after 15 min.
- [ ] 3.8 Add per-IP rate limit on `/auth/platform/login` at 5/15min via bucket4j (Marcus's hard constraint — separate from MFA lockout above; this is the password-attempt throttle)
- [ ] 3.9 Update `SecurityConfig.java` JwtDecoder: iss-routed dispatch (tenant kids → `jwt_key_generation`; platform kids → `platform_key_material`); validate iss BEFORE signature verification (avoid wasted compute on wrong-key signature attempts); ensure cross-tenant cross-check at `JwtService:409-424` is bypassed for platform JWTs (separate code path, NOT loosened conditional)
- [ ] 3.10 Create new Maven module `fabt-cli/` (Decision 8): pom.xml inheriting from parent; single CommandLineRunner with `hash-password` command that prompts for password (interactive), validates strength (min 16 chars for ops accounts), prints bcrypt-12 hash. Include `--help` and `--version` subcommands. Builds to `fabt-cli/target/fabt-cli.jar`.
- [ ] 3.11 Update root pom.xml `<modules>` to include `fabt-cli`. Verify `mvn package` builds both backend JAR and CLI JAR.
- [ ] 3.12 Add IT family `PlatformAuthIntegrationTest`: scenarios for first-login MFA flow, subsequent TOTP login, backup code use (SHA-256 verification), lockout after 5 failures (per-account), per-IP rate limit triggers at 6th request, MFA-setup token scope server-validated (presented to wrong endpoint → 403), account_locked rejects login, NULL password_hash rejects login
- [ ] 3.13 Update `AuthControllerTest`: assert tenant login still uses `iss="fabt-tenant"`; add scenarios for forged platform JWT presented to tenant endpoint
- [ ] 3.14 Run full `mvn test` locally; verify all G-4.2 ITs pass
- [ ] 3.15 Commit: `feat(auth): G-4.2 — platform login + MFA + JWT class + fabt-cli module + dual lockout`

## 4. G-4.3 — Audited access log + AOP aspect (V89)

> **Slice numbering note (warroom 2026-04-25):** V88 was originally drafted
> here for the access log. During G-4.2 implementation we discovered that
> per-account MFA lockout requires DB columns + SECURITY DEFINER wrappers
> on `platform_user`, which naturally lives with the auth flow that uses
> them — so V88 is now claimed by G-4.2's `V88__platform_user_lockout_columns.sql`,
> and the access log shifts to **V89** here. The slice content below is
> unchanged; only the migration filename moves.

- [ ] 4.1 Create Flyway V89 migration `V89__platform_admin_access_log.sql`:
  - `CREATE TABLE platform_admin_access_log (id UUID PK, platform_user_id UUID FK platform_user(id), action TEXT NOT NULL, resource TEXT NULL, resource_id UUID NULL, justification TEXT NOT NULL CHECK (length(trim(justification)) >= 10), request_method TEXT NOT NULL, request_path TEXT NOT NULL, request_body_excerpt TEXT NULL, before_state JSONB NULL, after_state JSONB NULL, audit_event_id UUID NULL, timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW())`
  - `REVOKE UPDATE, DELETE ON platform_admin_access_log FROM fabt_app`
  - Indexes: `(platform_user_id, timestamp DESC)`, `(timestamp DESC)`, `(resource_id) WHERE resource_id IS NOT NULL`, **`(action, timestamp DESC)`** (Elena's compliance-query optimization)
- [ ] 4.2 Create annotation `@PlatformAdminOnly(reason String, emits AuditEventType)` per Decision 9. Both members are required (no default). Annotation has `@Target(ElementType.METHOD), @Retention(RetentionPolicy.RUNTIME)`.
- [ ] 4.3 Add 10 new `AuditEventType` enum values: `PLATFORM_TENANT_CREATED`, `PLATFORM_TENANT_SUSPENDED`, `PLATFORM_TENANT_UNSUSPENDED`, `PLATFORM_TENANT_OFFBOARDED`, `PLATFORM_TENANT_HARD_DELETED`, `PLATFORM_KEY_ROTATED`, `PLATFORM_HMIS_EXPORTED`, `PLATFORM_OAUTH2_TESTED`, `PLATFORM_BATCH_JOB_TRIGGERED`, `PLATFORM_TEST_RESET_INVOKED`. Plus `PLATFORM_USER_LOCKED_OUT` and `PLATFORM_USER_CREATED` for identity-related actions.
- [ ] 4.4 Create `JustificationValidationFilter.java` (Spring filter, NOT aspect — Alex's split recommendation): runs in filter chain BEFORE Spring Security; checks `X-Platform-Justification` header presence + length >= 10 chars on requests to `@PlatformAdminOnly`-annotated endpoints (uses request URI → controller method lookup); rejects 400 if invalid. Allows the JWT auth + `@PreAuthorize` to handle authorization next.
- [ ] 4.5 Create `PlatformAdminLogger.java` (Spring AOP aspect, single-purpose per Alex): runs `@Around` on methods annotated `@PlatformAdminOnly`. In a single REQUIRES_NEW transaction:
  - Generate UUIDs for new PAL row and new AE row up front (client-side, Decision 11)
  - INSERT PAL with `audit_event_id = <pre-gen AE UUID>`, `justification = "<annotation reason> | request: <header value>"`
  - INSERT AE with `id = <pre-gen AE UUID>`, `action = <annotation.emits()>`, `details = jsonb_build_object('platform_admin_access_log_id', <pre-gen PAL UUID>, 'platform_user_id', <pu-id>, 'platform_user_email', <email>, 'justification_excerpt', substr(justification, 1, 200), 'request_method', <method>, 'request_path', <path>)`
  - Determine AE `tenant_id` from method parameter named `tenantId` (UUID type) — defaults to SYSTEM_TENANT_ID
  - **Special case**: if `annotation.emits() == PLATFORM_TENANT_HARD_DELETED`, force `tenant_id = SYSTEM_TENANT_ID` regardless of method param (Decision 13 — survives the cascade delete)
  - If `tenant_id != SYSTEM_TENANT_ID`, AuditChainHasher chains the row (Phase G-1 path)
  - Commit; method body executes
  - On commit failure: log WARN to application log with `platform_action: true` MDC marker (Jordan's SOC filtering)
- [ ] 4.6 Apply `@PlatformAdminOnly(reason="canary endpoint for G-4.3 — exercises AOP aspect", emits=AuditEventType.PLATFORM_BATCH_JOB_TRIGGERED)` to `BatchJobController.run` only (canary; rest in G-4.4); also apply `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")`
- [ ] 4.7 Add IT family `PlatformAdminAccessAspectTest`:
  - missing X-Platform-Justification → 400 (filter rejection), no log rows
  - justification < 10 chars → 400, no log rows
  - **method throws AFTER aspect commit → both log rows persist (REQUIRES_NEW commit semantics test)** (Riley's specific requirement)
  - unauthorized request (wrong role) → 403 (Spring Security rejection), no log rows (filter ran but aspect did not — Spring Security runs between filter and aspect)
  - successful call → both rows present and linked by id (PAL.audit_event_id == AE.id; AE.details->>'platform_admin_access_log_id' == PAL.id)
  - tenant-affecting action (e.g., suspend with tenantId=X) → audit_events.tenant_id = X; chained
  - PLATFORM_TENANT_HARD_DELETED action → audit_events.tenant_id = SYSTEM_TENANT_ID (NOT target tenant — Decision 13)
  - platform-wide action (BatchJobController.run) → audit_events.tenant_id = SYSTEM_TENANT_ID; not chained
- [ ] 4.8 Add ArchUnit test `PlatformAdminOnlyArchitectureTest`: any method annotated `@PlatformAdminOnly` MUST also be annotated `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` (defense-in-depth). Scope rule to `.java` source files only (Riley — exclude SQL migration files which legitimately mention `PLATFORM_ADMIN`).
- [ ] 4.9 Run `mvn test` locally
- [ ] 4.10 Commit: `feat(audit): G-4.3 — V88 platform_admin_access_log + @PlatformAdminOnly(reason,emits) + JustificationValidationFilter + PlatformAdminLogger aspect`

## 5. G-4.4 — Endpoint migration + Playwright + ArchUnit guard

### 5.a Migrate the 18 @PreAuthorize sites

- [ ] 5.1 Identify the 11 tenant-scoped sites (verified ground truth from Phase G-3 deploy session): TestResetController (1), TenantConfigController (2), UserController, ApiKeyController, OAuth2ProviderController, TotpController, AccessCodeController, PasswordController, AvailabilityController (admin), ShelterController (admin) — exact split confirmed during implementation by grepping `@PreAuthorize.*PLATFORM_ADMIN` and reviewing each
- [ ] 5.2 Migrate the 11 tenant-scoped sites: change `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` → `@PreAuthorize("hasRole('COC_ADMIN')")`
- [ ] 5.3 Identify the 7 platform-scoped sites: TenantController.create, TenantLifecycleController (suspend/unsuspend/offboard/hardDelete = 4 sites), TenantKeyRotationController.rotate (1), HmisExportController (6), OAuth2TestConnectionController.test (1), BatchJobController (4 — already canaried)
- [ ] 5.4 Migrate the 7 platform-scoped sites: change `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` → `@PreAuthorize("hasRole('PLATFORM_OPERATOR')")` AND add `@PlatformAdminOnly(reason="<endpoint-specific justification template>", emits=AuditEventType.<appropriate>)` annotation. Each site picks its own AuditEventType from the 10 new values.
- [ ] 5.5 Update SecurityConfig.java path patterns (3 sites referencing PLATFORM_ADMIN — re-audit each for correct cohort per design.md)
- [ ] 5.6 Add ArchUnit test `NoPlatformAdminPreauthorizeTest`: build fails if any `@PreAuthorize` annotation in `org.fabt.*.api` references `PLATFORM_ADMIN`. Scope to `.java` files only.

### 5.b Playwright fixture refactor

- [ ] 5.7 Create test helper `e2e/playwright/auth/multi-tenant-seed.ts`: seeds tenants A and B, creates COC_ADMIN of A, returns auth tokens for both. Reusable across CrossTenantIsolationTest scenarios (Riley's test infrastructure requirement).
- [ ] 5.8 Create test helper `e2e/playwright/auth/totp-helper.ts`: reads `platform_user.mfa_secret` directly from test DB; computes valid TOTP code at test time using the secret + current Unix time / 30 (RFC 6238); used by platformOperatorPage fixture for automated MFA login (Riley's hard requirement)
- [ ] 5.9 Update `e2e/playwright/auth/admin.json` (the `cocadminPage` fixture): seed user already has COC_ADMIN via V87 backfill; verify fixture authenticates and JWT now has `roles=[COC_ADMIN]`; update any test that asserted role string explicitly
- [ ] 5.10 Create `e2e/playwright/auth/platform-operator.json` fixture: helper provisions a test platform_user with known password + seeds TOTP secret directly (test profile only); platformOperatorPage fixture uses `/auth/platform/login` + totp-helper
- [ ] 5.11 Update existing tests that explicitly required PLATFORM_ADMIN — replace with platformOperatorPage where appropriate
- [ ] 5.12 Add new Playwright test `platform-admin-access-log.spec.ts`: PLATFORM_OPERATOR triggers BatchJobController.run with X-Platform-Justification header; verify audit_events row exists under SYSTEM_TENANT_ID and platform_admin_access_log row exists with expected justification
- [ ] 5.13 Add Playwright test `platform-totp-lockout.spec.ts`: 5 failed TOTP verifications → account locked → 401 on subsequent attempts. Test profile overrides cron to clear lockout every 1 second (vs 15 min in prod) to make test runnable.

### 5.c Verification

- [ ] 5.14 Run full backend `mvn test` locally; verify ArchUnit + integration + new aspect tests pass
- [ ] 5.15 Run full Playwright suite via dev-start.sh nginx (port 8081)
- [ ] 5.16 Commit: `feat(auth): G-4.4 — endpoint migration + Playwright fixtures + ArchUnit guard`

## 6. G-4.5 — Demo expansion + DV defenses + accessibility + monitoring (NEW slice — split from G-4.4 per Riley)

### 6.a Demo seed expansion

- [ ] 6.1 Update `infra/scripts/seed-data.sql`: ensure existing seed admin@dev.fabt.org becomes COC_ADMIN; add seed users for dev-coc-west and dev-coc-east (admin, outreach, dv-coordinator, dv-outreach × 3 tenants = 12 total). All `admin123`.
- [ ] 6.2 Verify all 12 seed users authenticate with `admin123` against their respective tenantSlug
- [ ] 6.3 Update `index.html` "Try it Live" section: list all 12 demo users grouped by tenant with role labels (CoC Admin, Outreach Worker, DV Coordinator, DV Outreach Worker); per-user one-sentence description (Devon's accessibility/clarity recommendation)
- [ ] 6.4 Add public monitoring notice to "Try it Live": "These are real demo credentials in a real environment. The demo is monitored; abuse triggers automated rate-limits and alerts." Visible body text, not footer.
- [ ] 6.5 Update `frontend/src/i18n/{en,es}.json` for any "Platform Admin" → "CoC Admin" string changes; add new strings for platform-operator-related UI; finalize role display labels (Maria's spec: "CoC Admin", "CoC Administrator", or "Administrator (CoC scope)" — pick one in this task)
- [ ] 6.6 Update README.md role/user table to reflect new role taxonomy

### 6.b DV-defense package (6 items)

- [ ] 6.7 Add bucket4j filter entry: per-IP rate limit on `POST /api/v1/dv-referrals` at 5/hour
- [ ] 6.8 Add Prometheus metric `fabt_dv_referrals_created_total` labeled by source_ip; add alert rule `FabtDvReferralBurstFromSingleIp` in `deploy/prometheus/dv-defenses.rules.yml` (rate > 10/min sustained 2 min)
- [ ] 6.9 Create `docs/security/dv-incident-response.md` with documented psql queries for identifying suspicious DV access patterns; tabletop with persona
- [ ] 6.10 Implement `dvReferralDemoCleanup` batch job (cron: every 6 hours): DELETE PENDING DV referrals from demo tenants older than 48 hours; emits `DV_REFERRAL_DEMO_CLEANUP` audit event under affected tenant chain
- [ ] 6.11 Add Sec-Fetch-Site header check on `POST /api/v1/dv-referrals`: reject 403 if header present and value is `cross-site`; allow if header is `same-origin`/`same-site`/`none` or absent. Document in spec that this is "raise abuse cost slightly" not "block abuse" (Marcus's accuracy note).

### 6.c Accessibility refinements (Tomás)

- [ ] 6.12 TOTP entry input HTML semantics: `<input type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" aria-label="6-digit code from authenticator">`. Apply on platform login MFA verify page AND tenant-side TOTP enrollment confirm.
- [ ] 6.13 QR code page semantics: `<img alt="QR code: scan with your authenticator app to register MFA">` PLUS adjacent visible text element `<code>{secret}</code>` PLUS `<a>Can't scan? Enter this secret manually</a>` toggle. Make secret copy-to-clipboard button keyboard-accessible.
- [ ] 6.14 Backup codes display: semantic `<ol>` with each code in `<li>`; per-code copy-to-clipboard button (keyboard accessible); copy-all button; print-friendly stylesheet (CSS `@media print` rule renders without nav chrome); large monospace font (codes are alphanumeric); "Save these codes" h2 heading
- [ ] 6.15 Lockout error message: render in `aria-live="polite"` region with text "Account locked. Try again in 15 minutes." Screen-reader-friendly announcement
- [ ] 6.16 "Try it Live" page expansion: ensure `<h2>` per tenant; per-user role description for screen readers; semantic table or definition list (not just `<div>` soup)

### 6.d Monitoring + observability additions (Jordan)

- [ ] 6.17 Add Prometheus alert rules in `deploy/prometheus/phase-g-platform-admin.rules.yml`:
  - `FabtPlatformLoginFailureBurst` — `rate(fabt_platform_login_failures_total[5m]) > 5` sustained 2 min → page operator
  - `FabtPlatformActionWithoutJustification` — should never fire if AOP works; defense in depth alert (counter increments only on aspect-bug condition)
  - `FabtPlatformUserDelayedActivation` — `time_since(fabt_platform_user_created_seconds) > 86400 AND fabt_platform_user_mfa_enabled == 0` (operator forgot to activate)
  - `FabtPlatformUserLockedOut` — INFO-level alert when any platform_user enters lockout state
- [ ] 6.18 Add MDC marker `platform_action: true` to all PlatformAdminLogger aspect log statements (Jordan's SOC filtering)
- [ ] 6.19 Document Grafana dashboard panel ideas in `docs/observability/platform-admin-monitoring.md` (panels can be built Phase H+; documented now for continuity)

### 6.e Verification

- [ ] 6.20 Run full backend + Playwright tests
- [ ] 6.21 Run `make rehearse-deploy` — should succeed (rehearsal stack uses lite profile + test seed)
- [ ] 6.22 Commit: `feat(auth): G-4.5 — demo expansion + DV defenses + accessibility + monitoring`

## 7. Documentation + runbook

- [ ] 7.1 Create `docs/runbook.md` section "First platform_user activation" (post-V87 deploy step): pre-requisites checklist (TOTP app installed, backup-code storage ready, fabt-cli pre-staged on VM); each command with expected output; troubleshooting ("What if `fabt-cli.jar` is not found?"); verification steps (Devon's hand-holding requirement)
- [ ] 7.2 Create `docs/runbook.md` section "Platform key rotation break-glass" (per design Decision 8 — even if "manual rotation later," document the procedure NOW): SQL to insert a new active platform_key_material row + flip old to inactive + restart backend
- [ ] 7.3 Create `docs/security/platform-admin-justification-conventions.md`: style guide for X-Platform-Justification header content (Marcus's documentation requirement). Examples of good vs bad justifications. Categories: ROUTINE_OPS, INCIDENT_RESPONSE, COMPLIANCE_AUDIT, BREAK_GLASS, etc.
- [ ] 7.4 Create `docs/training/platform-operator-101.md`: "Day in the life of a platform operator" walkthrough (Devon + Maria): common scenarios (tenant create, suspend, key rotation, batch job trigger), what MUST go in justification header, what audit trail looks like, recovery scenarios
- [ ] 7.5 Create `docs/operations/platform-operator-handbook.md`: step-by-step ops manual with screenshots — login flow, MFA setup, backup code storage best practices, recovery (lost MFA, exhausted backup codes), how to provision a 2nd platform_user
- [ ] 7.6 Update `docs/oracle-update-notes-v0.53.0.md` (per `feedback_runbook_template_v1.md`): include all `consulted:` memories; pre-deploy gates including verifying COC_ADMIN backfill on staging first; post-deploy gates including platform user activation; rollback matrix with token-version-bump impact note (every active session re-logs in)
- [ ] 7.7 Create `docs/security/platform-admin-forensic-walk.md`: documented psql queries — list all platform admin actions in time window; join to audit_events for chained tamper-evidence; cross-reference with OCI anchor objects
- [ ] 7.8 Update `frontend/src/components/AdminPanel.tsx` and similar: role-visibility checks updated for COC_ADMIN; remove any stale references to PLATFORM_ADMIN
- [ ] 7.9 Update `PLATFORM-STANDARDS.md` (in `corey-portfolio-platform` repo): add Lesson 79 "Don't rename a domain-meaningful role for architectural symmetry — split it instead"
- [ ] 7.10 Update memory: mark issue #141 as resolved; mark Phase G-4 as complete in `project_phase_g_implementation_plan.md`; add lessons learned to `project_resume_point.md`
- [ ] 7.11 Draft customer-facing 1-paragraph note explaining the role split (Maria's pilot communication); share with Sarah Dickerson before deploy: "FABT v0.53 introduces a clearer separation between tenant-scoped admin and platform-scoped operations. Your CoC admin role is unchanged — same permissions, slightly different label. No action required."

## 8. Pre-deploy gates (v0.53.0 release prep)

- [ ] 8.1 Open release-prep PR: pom version bump `0.52.0 → 0.53.0`; CHANGELOG.md `[v0.53.0]` entry mentioning all 5 slices + 6 DV defenses + accessibility refinements; oracle-update-notes-v0.53.0.md
- [ ] 8.2 CI green on main (Backend Maven, E2E, CodeQL, ArchUnit, legal-language scan)
- [ ] 8.3 Tag v0.53.0; push tag; create GitHub release with auto-generated notes — include `fabt-cli.jar` as release artifact
- [ ] 8.4 Run `make rehearse-deploy` within 72h of tag (release-gate-pins.txt requirement)

## 9. Deploy (v0.53.0)

- [ ] 9.1 Pre-deploy gate: confirm v0.52.0 baseline on prod (Flyway HWM = 85, 3 tenants, all 8 batch jobs registered)
- [ ] 9.2 Pre-deploy gate: pg_dump → `~/fabt-backups/fabt-pre-v0.53.dump`
- [ ] 9.3 **Pre-deploy operator readiness checklist** (per design Migration Plan / cold-start mitigation):
  - [ ] Operator has TOTP app installed and accessible
  - [ ] Operator has password-manager / secured-physical-storage ready for backup codes
  - [ ] If first-ever platform_user: 2nd operator on standby for recovery; deploy in maintenance window
  - [ ] `fabt-cli.jar` pre-built and pre-staged on VM via `scp`
  - [ ] Activation runbook section pre-rehearsed (operator has read it)
- [ ] 9.4 Deploy v0.53.0 per oracle-update-notes runbook (5-file compose chain — same as v0.52)
- [ ] 9.5 Verify backend healthy + Flyway HWM = 88 + V87 + V88 columns present + COC_ADMIN backfill applied + token_version incremented
- [ ] 9.6 Activate first platform_user: SSH to VM, run `java -jar fabt-cli.jar hash-password`, UPDATE platform_user via psql to set email + password_hash + unlock
- [ ] 9.7 Login at https://findabed.org/auth/platform/login (or via SSH-tunnel if public access disabled), complete MFA setup, store 10 backup codes in chosen secure location
- [ ] 9.8 Trigger BatchJobController.run as canary: verify both log rows written and linked
- [ ] 9.9 Provision 2nd platform_user as recovery contact (use first platform_user's session to POST `/api/v1/platform/users`)
- [ ] 9.10 Run Playwright smoke against findabed.org

## 10. Post-deploy housekeeping

- [ ] 10.1 Update `project_live_deployment_status.md` with v0.53.0 state
- [ ] 10.2 Mark issue #141 closed on GitHub with link to v0.53.0 release notes
- [ ] 10.3 Save resume point memory: Phase G-5 next (OTel baggage + per-tenant alert routing); G-6 docs + close-out
- [ ] 10.4 Calendar reminder: post-v0.53 cleanup release should remove `Role.PLATFORM_ADMIN` enum value entirely (after one release window of deprecation)
- [ ] 10.5 Verify OCI anchor still working post-deploy (week-1 anchor should fire on schedule and include the new platform-admin audit rows for tenants with chained PLATFORM_* events)
- [ ] 10.6 Send customer-facing role-split note (drafted in 7.11) to Sarah Dickerson + any other pilot CoC contacts
