## ADDED Requirements

### Requirement: dev-coc-west-demo-seed
The system SHALL add a permanent second tenant "Blue Ridge CoC (demo)" to `infra/scripts/seed-data.sql` (per M1, D12) via Flyway migration V76. Tenant UUID SHALL be pinned to `a0000000-0000-0000-0000-000000000002`; slug SHALL be `dev-coc-west`. The seed SHALL be idempotent (INSERT ... ON CONFLICT DO UPDATE) and SHALL include a full matrix: 6 role users, 3-5 shelters (at least one DV shelter), sample bed availability, and 1 pending DV referral. "Blue Ridge" is a fictional-for-CoC-purposes regional name (geographic mountain range spanning multiple states; NOT a HUD-registered CoC).

#### Scenario: Seed creates tenant with pinned UUID
- **WHEN** V76 runs on a fresh DB
- **THEN** a tenant row with UUID `a0000000-0000-0000-0000-000000000002` and slug `dev-coc-west` exists
- **AND** the display name is `Blue Ridge CoC (demo)` per D12

#### Scenario: Seed is idempotent
- **GIVEN** V76 has already run and the Blue Ridge tenant exists
- **WHEN** V76 (or an equivalent re-seed script) runs again
- **THEN** the INSERT ... ON CONFLICT DO UPDATE pattern preserves the tenant UUID and updates changed columns
- **AND** no duplicate tenant rows, users, or shelters are created

#### Scenario: Seed includes DV shelter for isolation exercise
- **WHEN** the seed completes
- **THEN** at least one shelter in `dev-coc-west` is flagged `dv_shelter=true`
- **AND** the DV-access isolation boundary is exercisable from cross-tenant tests and live probes

#### Scenario: Seed users include full role matrix
- **WHEN** the seed completes
- **THEN** `dev-coc-west` has users for PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER, DV_COORDINATOR, DV_OUTREACH roles
- **AND** the demo credential `admin@blueridge.fabt.org / admin123` works for login

### Requirement: dev-coc-east-demo-seed
The system SHALL add a permanent third tenant "Pamlico Sound CoC (demo)" to `infra/scripts/seed-data.sql` (per M1, D12) via Flyway migration V77. Tenant UUID SHALL be pinned to `a0000000-0000-0000-0000-000000000003`; slug SHALL be `dev-coc-east`. The seed SHALL be idempotent (INSERT ... ON CONFLICT DO UPDATE) and SHALL include a full matrix: 6 role users, 3-5 shelters (at least one DV shelter), sample bed availability, and 1 pending DV referral. Credential convention: `admin@pamlico.fabt.org` / `admin123` (mirrors west and core tenant passwords for demo-visitor convenience). "Pamlico Sound" is a fictional-for-CoC-purposes regional name (geographic coastal lagoon; NOT a HUD-registered CoC).

#### Scenario: Seed creates tenant with pinned UUID
- **WHEN** V77 runs on a fresh DB
- **THEN** a tenant row with UUID `a0000000-0000-0000-0000-000000000003` and slug `dev-coc-east` exists
- **AND** the display name is `Pamlico Sound CoC (demo)` per D12

#### Scenario: Seed is idempotent
- **GIVEN** V77 has already run and the Pamlico Sound tenant exists
- **WHEN** V77 (or an equivalent re-seed script) runs again
- **THEN** the INSERT ... ON CONFLICT DO UPDATE pattern preserves the tenant UUID and updates changed columns
- **AND** no duplicate tenant rows, users, or shelters are created

#### Scenario: Seed includes DV shelter for isolation exercise
- **WHEN** the seed completes
- **THEN** at least one shelter in `dev-coc-east` is flagged `dv_shelter=true`
- **AND** the DV-access isolation boundary is exercisable from cross-tenant tests and live probes involving dev-coc-east as either source or target

#### Scenario: Seed users include full role matrix
- **WHEN** the seed completes
- **THEN** `dev-coc-east` has users for PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER, DV_COORDINATOR, DV_OUTREACH roles
- **AND** the demo credential `admin@pamlico.fabt.org / admin123` works for login

### Requirement: platform-admin-tenant-scoping-v0.48

The system SHALL treat `PLATFORM_ADMIN` as a **tenant-scoped role** in v0.48 (Phase M-light). Each of the three demo tenants (`dev-coc`, `dev-coc-west`, `dev-coc-east`) SHALL have its own independently-seeded `PLATFORM_ADMIN` user; per-tenant seeds are intentional, not a bug or redundancy. A user issued `PLATFORM_ADMIN` in one tenant SHALL NOT be able to log in to a different tenant with the same credential — their JWT's `tenantId` claim fails cross-check against any other tenant's per-tenant signing key per Phase A D25 (`JwtService.validateNew` at `backend/src/main/java/org/fabt/auth/service/JwtService.java:409-424`).

This matches current behavior (Role enum at `backend/src/main/java/org/fabt/auth/domain/Role.java:3-8`; login flow at `AuthController.login` keying users on `(tenantId, email)`). The name "PLATFORM_ADMIN" is a **known misnomer** — it reads as "platform-spanning super-admin" but implements as "top role within a tenant." The rename + split is deferred to **Phase F** (see D15 below).

**Rationale for deferral (warroom 2026-04-20):**

- 13+ `@PreAuthorize("hasRole('PLATFORM_ADMIN')")` call sites across controllers plus SecurityConfig entries; a blanket rename today is a 2-3 day PR of its own
- Some of those endpoints ARE genuinely platform-scoped (`TenantController.create`, `BatchJobController`, `HmisExportController`) — they should stay gated by a TRUE platform role once one exists. A bulk rename to TENANT_ADMIN would then need reverse-migration at F/G → two renames instead of one
- Marcus verdict: current tenant-binding is actually SAFER than a sloppy cross-tenant flag; the kid-resolves-to-tenant cross-check is a hard containment boundary. Cross-tenant elevation MUST go through a dedicated flow (per-access justification + audit), never a role flag on a regular session
- Elena verdict: VAWA H4 (design.md §H4) requires platform operators cannot silently read DV survivor PII; tenant-bound today preserves that posture. The `@PlatformAdminOnly` aspect + `platform_admin_access_log` table in Phase G (tasks 8.2, 8.7, 8.8, 8.16) deliver the audited-unseal channel
- Jordan verdict: the 3am break-glass use-case is the K1 CLI (task 12.1–12.2), not a UI-spanning admin session

**Until Phase F closes** (introduces `TenantLifecycleController` break-glass endpoints + new platform-scoped identity), operator cross-tenant actions SHALL flow through the K1 break-glass CLI — not a UI session.

#### Scenario: `dev-coc` PLATFORM_ADMIN cannot log in to `dev-coc-west`

- **GIVEN** a user `admin@dev.fabt.org` has `PLATFORM_ADMIN` role in `dev-coc`
- **WHEN** they attempt `/api/v1/auth/login` with `tenantSlug=dev-coc-west` + their same email/password
- **THEN** authentication fails with `Invalid credentials` (the `(tenantId, email)` lookup finds no matching user in `dev-coc-west`'s row set)

#### Scenario: Cross-tenant JWT replay rejected

- **GIVEN** a valid JWT issued for `dev-coc`'s `PLATFORM_ADMIN`
- **WHEN** a request targeting a `dev-coc-west`-scoped resource carries that token
- **THEN** JWT validation rejects with `CrossTenantJwtException` (kid-resolved tenantId ≠ claim.tenantId) OR the subsequent request reaches `TenantContext=dev-coc` and RLS blocks the cross-tenant read

#### Scenario: Each tenant has its own independently-seeded PLATFORM_ADMIN

- **WHEN** V76 + V77 seeds complete
- **THEN** `dev-coc-west` has an `admin@blueridge.fabt.org` user with `PLATFORM_ADMIN` role
- **AND** `dev-coc-east` has an `admin@pamlico.fabt.org` user with `PLATFORM_ADMIN` role
- **AND** these are three distinct user records (one per tenant) — NOT the same principal spanning three tenants

#### Scenario: Documentation surfaces the tenant-scoped semantics

- **GIVEN** a demo visitor reads the multi-tenant walkthrough doc (M6)
- **THEN** the doc explicitly notes that `PLATFORM_ADMIN` in v0.48 means "top role within this CoC," not "platform-spanning"
- **AND** the doc references Phase F / Phase G as the point where a platform-spanning break-glass identity ships

### Requirement: branding-demo-suffix
The system SHALL display the west tenant name as `Blue Ridge CoC (demo)` and the east tenant name as `Pamlico Sound CoC (demo)` (per M2, D12) in login UI, landing page, admin panel header, page title, and training materials. Both names are fictional regional labels NOT present in the HUD CoC registry; the `(demo)` suffix is retained as belt-and-suspenders per D12. Seed data SHALL use demonstrably-fictional shelter names (e.g., "Example House North", "Example Coastal House"), non-geocodable addresses, and persona-derived fake contact names. Real-PII patterns SHALL NOT appear in either tenant. Casey pre-merge review SHALL confirm no name collision with a registered HUD CoC.

#### Scenario: Login UI surfaces west tenant as "Blue Ridge CoC (demo)"
- **WHEN** a demo visitor loads the login page and selects the west tenant (`dev-coc-west`)
- **THEN** the tenant label reads "Blue Ridge CoC (demo)" (not "Blue Ridge CoC")
- **AND** the `(demo)` suffix is visible in the tenant-selector dropdown and page title

#### Scenario: Login UI surfaces east tenant as "Pamlico Sound CoC (demo)"
- **WHEN** a demo visitor loads the login page and selects the east tenant (`dev-coc-east`)
- **THEN** the tenant label reads "Pamlico Sound CoC (demo)" (not "Pamlico Sound CoC")
- **AND** the `(demo)` suffix is visible in the tenant-selector dropdown and page title

#### Scenario: Shelter names are fictional in both new tenants
- **WHEN** the seed completes
- **THEN** every shelter name in `dev-coc-west` AND `dev-coc-east` matches documented fictional patterns (e.g., starts with "Example")
- **AND** no real shelter names from any specific jurisdiction appear

#### Scenario: Addresses are non-geocodable in both new tenants
- **WHEN** a demo visitor attempts to geocode any seeded address across `dev-coc-west` or `dev-coc-east`
- **THEN** the geocode returns no match (addresses follow documented non-geocodable pattern)
- **AND** no real street addresses from any specific jurisdiction appear in seed data

### Requirement: visible-tenant-indicator-in-ui
The system SHALL display a visible tenant indicator (per M3) in the Layout component (header or footer) showing the current tenant name + a subtle accent color differentiator. The `<title>` element SHALL carry the tenant name. Tenant switches between any pair of `dev-coc`, `dev-coc-west`, and `dev-coc-east` SHALL produce obviously-different UI state. Tenant name SHALL be announced on page load per WCAG 2.4.2. Each of the three tenants SHALL have a distinct accent color so screenshot evidence of isolation is visually unambiguous.

#### Scenario: Header shows active tenant for all three tenants
- **WHEN** a user is logged into `dev-coc`
- **THEN** the header displays "Dev CoC" with its accent color
- **AND** when the same user re-logs as `dev-coc-west`, the header displays "Blue Ridge CoC (demo)" with a distinct accent color
- **AND** when the same user re-logs as `dev-coc-east`, the header displays "Pamlico Sound CoC (demo)" with a third distinct accent color

#### Scenario: Page title carries tenant
- **WHEN** a user navigates to the admin panel
- **THEN** the browser tab `<title>` contains the tenant name
- **AND** the title updates on tenant switch

#### Scenario: Tenant announced on load per WCAG 2.4.2
- **WHEN** a screen reader user loads any page
- **THEN** the tenant name is programmatically associated with the page title
- **AND** the assistive technology announces the tenant name

### Requirement: educational-cross-tenant-404-envelope
The system SHALL return a cross-tenant 404 response (per M4) with an educational body message: "This resource belongs to a different tenant. FABT's multi-tenant isolation prevents cross-tenant data access — this is the system working as designed." The message SHALL be gated by a feature flag so it can be toggled off if information-disclosure concerns ever arise. D3 existence-leak prevention SHALL remain intact — the message does not reveal the other tenant's state.

#### Scenario: Cross-tenant URL manipulation returns educational 404
- **GIVEN** a demo visitor is logged into `dev-coc` and pastes a URL containing an `dev-coc-west` shelter UUID
- **WHEN** the request reaches the backend
- **THEN** the response is 404 Not Found
- **AND** the response body contains the educational message from M4
- **AND** the message does NOT indicate which tenant owns the resource or confirm the UUID's cross-tenant existence

#### Scenario: Feature flag off restores plain 404
- **GIVEN** the educational-404 feature flag is toggled off
- **WHEN** a cross-tenant request arrives
- **THEN** the response is a plain 404 with the standard error envelope
- **AND** no educational text is returned

#### Scenario: Same educational envelope for nonexistent UUID
- **WHEN** a tenant A user requests a nonexistent UUID (not owned by any tenant)
- **THEN** the response is also 404 with the educational message
- **AND** the response shape is indistinguishable from cross-tenant 404 (no existence leak)

### Requirement: post-deploy-smoke-all-tenants
The system SHALL include post-deploy smoke specs (per M5) that exercise all three tenants (`dev-coc`, `dev-coc-west`, `dev-coc-east`): login to each, attempt cross-tenant URL access from each to at least one other, and expect 404 with the educational envelope. Playwright + Karate layers SHALL both cover this flow. Suite SHALL include at least one probe per ordered pair so an east→west leak and a west→east leak are both regression-guarded (the full 6-pair matrix is encouraged but a 3-probe rotation is the minimum gate).

#### Scenario: Playwright smoke covers all three tenants
- **WHEN** the post-deploy Playwright smoke runs against a live deploy
- **THEN** it logs in to `dev-coc`, attempts a cross-tenant URL pointing at a `dev-coc-west` resource, asserts 404 with educational envelope
- **AND** it logs in to `dev-coc-west`, attempts a cross-tenant URL pointing at a `dev-coc-east` resource, asserts 404 with educational envelope
- **AND** it logs in to `dev-coc-east`, attempts a cross-tenant URL pointing at a `dev-coc` resource, asserts 404 with educational envelope
- **AND** all three directions assert 404 with the educational envelope

#### Scenario: Karate smoke covers all three tenants at the API layer
- **WHEN** the post-deploy Karate smoke runs
- **THEN** it authenticates as admin in each of the three tenants and attempts cross-tenant API calls against at least one other tenant
- **AND** every cross-tenant call returns 404 with the educational envelope

#### Scenario: Smoke failure blocks deploy completion
- **GIVEN** a failure in either Playwright or Karate smoke
- **WHEN** the deploy pipeline evaluates the result
- **THEN** the deploy is marked failed
- **AND** the on-call is paged

### Requirement: multi-tenant-demo-walkthrough-doc
The project SHALL publish `docs/training/multi-tenant-demo-walkthrough.md` (per M6) with a 3-minute scripted visitor walkthrough. The walkthrough SHALL be linked from the findabed.org landing page and from the FOR-COORDINATORS / FOR-COC-ADMINS audience docs. A screenshot bundle SHALL accompany the doc.

#### Scenario: Doc exists with scripted walkthrough
- **GIVEN** `docs/training/multi-tenant-demo-walkthrough.md` is published
- **WHEN** a demo visitor opens the doc
- **THEN** the walkthrough steps are readable in under 3 minutes
- **AND** it covers log in `dev-coc` → observe shelters → log out → log in `dev-coc-west` (Blue Ridge CoC (demo)) → observe different shelters + different DV posture → attempt cross-tenant URL → observe educational 404 → log out → log in `dev-coc-east` (Pamlico Sound CoC (demo)) → same isolation probe → observe educational 404

#### Scenario: Landing page links the walkthrough
- **WHEN** a visitor loads findabed.org
- **THEN** a visible link to the multi-tenant walkthrough is present
- **AND** the link text indicates it is a demo walkthrough

#### Scenario: Screenshot bundle accompanies doc
- **GIVEN** the walkthrough references labeled screenshots
- **WHEN** the doc is rendered
- **THEN** the referenced screenshots exist in the asset bundle
- **AND** each step has at least one accompanying image

### Requirement: tenant-pair-validation-grafana-panel
The system SHALL add a Grafana panel (per M7) titled "Tenant-pair last validation timestamp" on the `fabt-cross-tenant-security` dashboard. The panel SHALL update when M5 post-deploy smoke runs and show green/yellow/red based on age.

#### Scenario: Panel renders with last validation timestamp
- **GIVEN** a post-deploy smoke run completes successfully
- **WHEN** an operator opens the dashboard
- **THEN** the panel shows the last validation timestamp
- **AND** the color is green if the validation was within 24 hours

#### Scenario: Panel turns yellow after 24 hours, red after 7 days
- **GIVEN** no post-deploy smoke has run for 30+ hours
- **WHEN** an operator opens the panel
- **THEN** the color is yellow with a note explaining the freshness threshold
- **AND** after 7 days with no validation the panel turns red

### Requirement: seed-migration-safety-gate
The project SHALL require pre-merge review (per M8) on BOTH Flyway migrations that create new demo tenants (V76 for `dev-coc-west` / Blue Ridge CoC (demo); V77 for `dev-coc-east` / Pamlico Sound CoC (demo)): Casey confirms fictional-name posture + no HUD-CoC-registry collision + `(demo)` suffix in every display surface, Marcus confirms no real-PII patterns in either seed, Maria confirms procurement-audience language. Deploy SHALL only proceed after the all-tenant post-deploy smoke (M5) passes.

#### Scenario: Three-reviewer sign-off required on each migration
- **GIVEN** the V76 (`dev-coc-west`) OR V77 (`dev-coc-east`) seed PR is open
- **WHEN** review is requested
- **THEN** Casey, Marcus, and Maria each provide an explicit approval (or persona-proxy approval per project_personas.md) on that PR
- **AND** the PR cannot merge without all three approvals
- **AND** the same review gate applies independently to each of the two new-tenant migrations (V76 + V77)

#### Scenario: Deploy gated on smoke pass
- **GIVEN** the V76 AND/OR V77 migrations land in prod
- **WHEN** M5 post-deploy smoke runs (all-tenant variant)
- **THEN** opsx:archive is blocked until the smoke passes
- **AND** a failing smoke reverts deploy closure

### Requirement: noisy-neighbor-live-validation
The system SHALL support a "against-live-demo" variant of `NoisyNeighborSimulation` (per M9) that an operator can trigger: hostile-load one of the non-primary demo tenants (`dev-coc-west` or `dev-coc-east`, operator's choice per drill) while monitoring `dev-coc` p99. This validates per-tenant performance isolation on the production code path.

#### Scenario: Operator triggers noisy-neighbor drill
- **WHEN** an operator runs the noisy-neighbor drill against the live demo targeting `dev-coc-west` OR `dev-coc-east`
- **THEN** the targeted tenant receives 3x normal load
- **AND** `dev-coc` p99 latency degradation is ≤ 20% per the documented SLO
- **AND** the non-targeted third tenant also shows ≤ 20% p99 degradation (verifies isolation holds in both directions — not just west→core)

#### Scenario: Drill metrics captured for review
- **WHEN** the drill completes
- **THEN** per-tenant p95 / p99 and error counts are captured in Grafana
- **AND** the results are archived with the drill timestamp

### Requirement: tenant-quarantine-live-drill
The system SHALL support a live tenant-quarantine drill (per M10) on either `dev-coc-west` or `dev-coc-east` (operator's choice per drill; rotate tenants across quarters to exercise both): operator quarantines the tenant, shows logins fail with 503, un-quarantines, shows login restored. Drill SHALL be quarterly. `dev-coc` (the core demo tenant) SHALL NOT be used as a quarantine target — its availability is the public-demo baseline.

#### Scenario: Quarterly quarantine drill runs end-to-end
- **GIVEN** the quarterly drill is scheduled
- **WHEN** an operator runs the drill targeting `dev-coc-west` OR `dev-coc-east`
- **THEN** the targeted tenant's login returns 503 during the quarantine window
- **AND** the other two tenants remain reachable (`dev-coc` + the non-targeted new tenant)
- **AND** after un-quarantine, login succeeds and normal traffic resumes

#### Scenario: Drill is audit-logged
- **WHEN** the drill runs
- **THEN** both the quarantine action and the un-quarantine action are recorded in `audit_events` and `platform_admin_access_log`
- **AND** the justification string identifies the event as a drill

### Requirement: offboard-live-drill
The system SHALL support a live offboard drill on either `dev-coc-west` or `dev-coc-east` (per M11; operator's choice per drill, rotate across quarters): operator exports data, destroys the per-tenant DEK (crypto-shred), re-seeds fresh. Drill SHALL be quarterly and proves end-to-end tenant lifecycle on production.

#### Scenario: Offboard produces export and shreds DEK
- **WHEN** an operator runs the offboard drill targeting `dev-coc-west` OR `dev-coc-east`
- **THEN** a JSON export is produced per F5
- **AND** the per-tenant DEK for the targeted tenant is destroyed per F6 crypto-shred

#### Scenario: Re-seed restores demo tenant
- **GIVEN** the targeted tenant (`dev-coc-west` or `dev-coc-east`) was offboarded as part of the drill
- **WHEN** the appropriate re-seed migration runs (V76 for west, V77 for east — both idempotent)
- **THEN** a fresh tenant row is created with a new UUID (not the old one, since the old one is shredded)
- **AND** the live demo is back to a 3-tenant state (`dev-coc` + both new tenants)

#### Scenario: Drill validates irreversibility of crypto-shred
- **GIVEN** the targeted tenant's old DEK was destroyed
- **WHEN** an operator attempts to decrypt a retained export ciphertext with the old DEK context
- **THEN** decrypt fails (key material unrecoverable)
- **AND** the drill log captures this expected failure as a validation checkpoint
