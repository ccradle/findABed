## ADDED Requirements

### Requirement: asheville-coc-demo-seed
The system SHALL add a permanent second tenant "Asheville CoC (demo)" to `infra/scripts/seed-data.sql` (per M1, D12) via Flyway migration V75. Tenant UUID SHALL be pinned to `a0000000-0000-0000-0000-000000000002`; slug SHALL be `asheville-coc`. The seed SHALL be idempotent (INSERT ... ON CONFLICT DO UPDATE) and SHALL include a full matrix: 6 role users, 3-5 shelters (at least one DV shelter), sample bed availability, and 1 pending DV referral.

#### Scenario: Seed creates tenant with pinned UUID
- **WHEN** V75 runs on a fresh DB
- **THEN** a tenant row with UUID `a0000000-0000-0000-0000-000000000002` and slug `asheville-coc` exists
- **AND** the display name is `Asheville CoC (demo)` per D12

#### Scenario: Seed is idempotent
- **GIVEN** V75 has already run and the Asheville tenant exists
- **WHEN** V75 (or an equivalent re-seed script) runs again
- **THEN** the INSERT ... ON CONFLICT DO UPDATE pattern preserves the tenant UUID and updates changed columns
- **AND** no duplicate tenant rows, users, or shelters are created

#### Scenario: Seed includes DV shelter for isolation exercise
- **WHEN** the seed completes
- **THEN** at least one shelter in `asheville-coc` is flagged `dv_shelter=true`
- **AND** the DV-access isolation boundary is exercisable from cross-tenant tests and live probes

#### Scenario: Seed users include full role matrix
- **WHEN** the seed completes
- **THEN** `asheville-coc` has users for PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER, DV_COORDINATOR, DV_OUTREACH roles
- **AND** the demo credential `admin@asheville.fabt.org / admin123` works for login

### Requirement: branding-demo-suffix
The system SHALL display the Asheville tenant name as `Asheville CoC (demo)` (per M2, D12) in login UI, landing page, admin panel header, page title, and training materials. Seed data SHALL use demonstrably-fictional shelter names (e.g., "Example House North"), non-geocodable addresses, and persona-derived fake contact names. Real-PII patterns SHALL NOT appear.

#### Scenario: Login UI surfaces "Asheville CoC (demo)"
- **WHEN** a demo visitor loads the login page and selects the Asheville tenant
- **THEN** the tenant label reads "Asheville CoC (demo)" (not "Asheville CoC")
- **AND** the `(demo)` suffix is visible in the tenant-selector dropdown and page title

#### Scenario: Shelter names are fictional
- **WHEN** the seed completes
- **THEN** every shelter name in `asheville-coc` matches documented fictional patterns (e.g., starts with "Example")
- **AND** no real Asheville shelter names appear

#### Scenario: Addresses are non-geocodable
- **WHEN** a demo visitor attempts to geocode any seeded address
- **THEN** the geocode returns no match (addresses follow documented non-geocodable pattern)
- **AND** no real Asheville street addresses appear in seed data

### Requirement: visible-tenant-indicator-in-ui
The system SHALL display a visible tenant indicator (per M3) in the Layout component (header or footer) showing the current tenant name + a subtle accent color differentiator. The `<title>` element SHALL carry the tenant name. Tenant switches between dev-coc and asheville-coc SHALL produce obviously-different UI state. Tenant name SHALL be announced on page load per WCAG 2.4.2.

#### Scenario: Header shows active tenant
- **WHEN** a user is logged into `dev-coc`
- **THEN** the header displays "Dev CoC" with its accent color
- **AND** when the same user re-logs as asheville-coc, the header displays "Asheville CoC (demo)" with a distinct accent color

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
- **GIVEN** a demo visitor is logged into `dev-coc` and pastes a URL containing an `asheville-coc` shelter UUID
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

### Requirement: post-deploy-smoke-both-tenants
The system SHALL include post-deploy smoke specs (per M5) that exercise both tenants: login to each, attempt cross-tenant URL access, and expect 404 with the educational envelope. Playwright + Karate layers SHALL both cover this flow.

#### Scenario: Playwright smoke covers both tenants
- **WHEN** the post-deploy Playwright smoke runs against a live deploy
- **THEN** it logs in to `dev-coc`, attempts cross-tenant URL, asserts 404 with educational envelope
- **AND** it repeats the flow from `asheville-coc` → `dev-coc`
- **AND** both directions assert 404

#### Scenario: Karate smoke covers both tenants at the API layer
- **WHEN** the post-deploy Karate smoke runs
- **THEN** it authenticates as admin in each tenant and attempts cross-tenant API calls
- **AND** both tenants return 404 with the educational envelope

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
- **AND** it covers log in dev-coc → observe shelters → log out → log in asheville-coc → attempt cross-tenant URL → observe educational 404

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
The project SHALL require pre-merge review (per M8) on the Flyway migration that creates the Asheville tenant: Casey confirms branding consistency, Marcus confirms no real-PII patterns, Maria confirms procurement-audience language. Deploy SHALL only proceed after M5 post-deploy smoke passes.

#### Scenario: Three-reviewer sign-off required
- **GIVEN** the V75 Asheville seed PR is open
- **WHEN** review is requested
- **THEN** Casey, Marcus, and Maria each provide an explicit approval (or persona-proxy approval per project_personas.md)
- **AND** the PR cannot merge without all three approvals

#### Scenario: Deploy gated on smoke pass
- **GIVEN** the V75 migration lands in prod
- **WHEN** M5 post-deploy smoke runs
- **THEN** opsx:archive is blocked until the smoke passes
- **AND** a failing smoke reverts deploy closure

### Requirement: noisy-neighbor-live-validation
The system SHALL support a "against-live-demo" variant of `NoisyNeighborSimulation` (per M9) that an operator can trigger: hostile-load `asheville-coc` while monitoring `dev-coc` p99. This validates per-tenant performance isolation on the production code path.

#### Scenario: Operator triggers noisy-neighbor drill
- **WHEN** an operator runs the noisy-neighbor drill against the live demo
- **THEN** asheville-coc receives 3x normal load
- **AND** dev-coc p99 latency degradation is ≤ 20% per the documented SLO

#### Scenario: Drill metrics captured for review
- **WHEN** the drill completes
- **THEN** per-tenant p95 / p99 and error counts are captured in Grafana
- **AND** the results are archived with the drill timestamp

### Requirement: tenant-quarantine-live-drill
The system SHALL support a live tenant-quarantine drill on `asheville-coc` (per M10): operator quarantines the tenant, shows logins fail with 503, un-quarantines, shows login restored. Drill SHALL be quarterly.

#### Scenario: Quarterly quarantine drill runs end-to-end
- **GIVEN** the quarterly drill is scheduled
- **WHEN** an operator runs the drill
- **THEN** asheville-coc login returns 503 during the quarantine window
- **AND** after un-quarantine, login succeeds and normal traffic resumes

#### Scenario: Drill is audit-logged
- **WHEN** the drill runs
- **THEN** both the quarantine action and the un-quarantine action are recorded in `audit_events` and `platform_admin_access_log`
- **AND** the justification string identifies the event as a drill

### Requirement: offboard-live-drill
The system SHALL support a live offboard drill on `asheville-coc` (per M11): operator exports data, destroys the per-tenant DEK (crypto-shred), re-seeds fresh. Drill SHALL be quarterly and proves end-to-end tenant lifecycle on production.

#### Scenario: Offboard produces export and shreds DEK
- **WHEN** an operator runs the offboard drill on asheville-coc
- **THEN** a JSON export is produced per F5
- **AND** the per-tenant DEK is destroyed per F6 crypto-shred

#### Scenario: Re-seed restores demo tenant
- **GIVEN** asheville-coc was offboarded as part of the drill
- **WHEN** the re-seed script runs (V75 idempotent seed)
- **THEN** a fresh asheville-coc tenant is created with a new UUID (not the old one, since the old one is shredded)
- **AND** the live demo is back to a 2-tenant state

#### Scenario: Drill validates irreversibility of crypto-shred
- **GIVEN** the old asheville-coc DEK was destroyed
- **WHEN** an operator attempts to decrypt a retained export ciphertext with the old DEK context
- **THEN** decrypt fails (key material unrecoverable)
- **AND** the drill log captures this expected failure as a validation checkpoint
