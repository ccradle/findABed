# runbook-template Specification

## Purpose
TBD - created by archiving change runbook-template-v1. Update Purpose after archive.
## Requirements
### Requirement: Template file exists at canonical path

The system SHALL provide `docs/runbook-template.md` containing the canonical structure every `docs/oracle-update-notes-vX.Y.Z.md` MUST follow. The template SHALL be a markdown document, version-controlled, and committed to the main branch.

#### Scenario: Template file is present

- **WHEN** an operator authoring a new release runbook looks for the template
- **THEN** `docs/runbook-template.md` exists in the repository
- **AND** the file contains every mandatory section listed in the requirements below

### Requirement: Mandatory section order

The template SHALL define a fixed section order that every release runbook follows. The required sections SHALL be, in order: (1) `Consulted Memories` frontmatter block, (2) `Scope & Non-Scope`, (3) `Service-Recreate Matrix`, (4) `Pre-Deploy Gates`, (5) `Deploy Steps`, (6) `Post-Deploy Gates`, (7) `Rollback Matrix`, (8) `Post-Deploy Housekeeping`.

#### Scenario: Future runbook follows the section order

- **WHEN** a new `docs/oracle-update-notes-vX.Y.Z.md` is authored after this change ships
- **THEN** the runbook contains all 8 mandatory sections
- **AND** the sections appear in the order defined by the template

#### Scenario: Lint check rejects out-of-order sections

- **WHEN** a runbook author submits a runbook missing a mandatory section or with sections in the wrong order
- **THEN** a lint script (delivered as part of `ci-runbook-consulted-check` change) flags the deviation

### Requirement: Consulted memories frontmatter block

Every release runbook SHALL include a `consulted:` block at the top of the document listing every memory file (`feedback_*.md` or `project_*.md`) the author reviewed during runbook authoring. The block SHALL use a fenced markdown code block with `yaml` language hint. Each entry MAY include an optional `# why-cited:` comment explaining the relevance. Memory files NOT applicable to the release SHALL be listed under a `not-applicable:` sub-block with a one-line justification.

#### Scenario: Author cites a relevant memory

- **WHEN** the runbook covers a deploy that recreates backend
- **THEN** the `consulted:` block lists `feedback_prod_docker_build_pattern.md`
- **AND** the entry carries a `# why-cited:` comment referencing the `--no-cache + --force-recreate` requirement

#### Scenario: Author marks an irrelevant memory

- **WHEN** the runbook covers a deploy that does NOT change Postgres
- **THEN** `feedback_pgaudit_include_dir_existing_volume.md` MAY be listed under `not-applicable:` with reason "no Postgres change in this release"
- **OR** MAY be omitted entirely if the lint script does not flag it

#### Scenario: Lint script enforces citation of new memories

- **WHEN** a `feedback_*.md` file is added in the same PR as a runbook update
- **THEN** the lint script (delivered as part of `ci-runbook-consulted-check`) requires the new file to appear in the runbook's `consulted:` or `not-applicable:` block

### Requirement: Pinned service-recreate matrix

The template SHALL include a service-recreate matrix that captures cross-service coupling lessons. The matrix SHALL include at minimum the following rows: (a) any backend change requires recreating backend AND frontend together; (b) any `prometheus.yml` or `deploy/prometheus/*` change requires `--force-recreate prometheus` (not `/-/reload` alone); (c) any `deploy/alertmanager*.tmpl` or rendered `~/fabt-secrets/alertmanager.yml` change requires `--force-recreate alertmanager`; (d) any `pgaudit.conf` change requires recreating postgres; (e) any host nginx config change requires `nginx -t` plus `nginx -s reload` (NOT a docker service).

#### Scenario: Author copies the matrix into a release runbook

- **WHEN** an author writes a release runbook
- **THEN** the runbook contains the service-recreate matrix verbatim from the template
- **AND** the author marks which rows apply to this release (e.g. by checkbox or applicability column)

#### Scenario: Backend-only change still recreates frontend

- **WHEN** a release recreates the backend container
- **THEN** the runbook's deploy step includes `--force-recreate backend frontend` together (per matrix row a)
- **AND** the rationale `// per service-recreate matrix row a — backend↔frontend docker network coupling` is present

### Requirement: Mandatory pre-deploy gate checklist

The template SHALL include a pre-deploy gate checklist with at minimum the following gates: (1) `KEY= value` trailing-space lint on `~/fabt-secrets/.env.prod`, (2) container UID vs host file permissions for every bind-mounted secret, (3) `mvn clean` performed before backend image build, (4) `pg_dump` backup with SHA-256 pin, (5) CI green on tag target, (6) operator SSH access confirmed reachable, (7) compose dry-render succeeds.

Each gate SHALL cite at least one memory file or document the new lesson if no prior memory exists.

#### Scenario: Pre-deploy gate cites memory

- **WHEN** a runbook's pre-deploy gate "no `KEY= value` trailing-space" appears
- **THEN** it carries a citation noting the v0.49 issue #1 incident or a future memory file documenting the same

#### Scenario: Container UID gate

- **WHEN** the release adds a new bind-mounted secret file (e.g. `~/fabt-secrets/alertmanager.yml`)
- **THEN** the runbook's pre-deploy gate enumerates the container UID for the consuming service (e.g. `nobody` UID 65534 for alertmanager) and verifies the host file's permissions allow that UID to read

### Requirement: Mandatory Playwright post-deploy smoke gate

Every release runbook SHALL include a numbered post-deploy gate that runs the Playwright post-deploy smoke spec against `https://findabed.org`. The gate SHALL specify the exact invocation: `cd e2e/playwright && BASE_URL=https://findabed.org npx playwright test --config=deploy/playwright.config.ts --reporter=list --trace on 2>&1 | tee ../../logs/post-deploy-smoke-vX.Y.Z.log`.

The gate SHALL NOT be marked optional, conditional, or "if time permits."

#### Scenario: Smoke gate is mandatory

- **WHEN** a release runbook is authored
- **THEN** the post-deploy gates section contains a smoke gate with the exact invocation specified above
- **AND** the gate has no "optional" or "if time permits" wording

#### Scenario: Smoke gate captures output

- **WHEN** the smoke gate runs
- **THEN** output is tee'd to `logs/post-deploy-smoke-vX.Y.Z.log` (per `feedback_run_tests_once_to_logs.md` and `feedback_test_output_and_traces.md`)
- **AND** the runbook author preserves the log file alongside the deploy incident thread

### Requirement: Internal actuator URL by default

Every release runbook's readiness gates and health checks SHALL default to the VM-internal actuator endpoint `http://localhost:9091/actuator/health` with basic auth from `~/fabt-secrets/.env.prod` (`FABT_ACTUATOR_USER`, `FABT_ACTUATOR_PASSWORD`). The runbook SHALL NOT use the public `https://findabed.org/actuator/health` URL for readiness, because that endpoint returns 404 (actuator binds to `:9091` localhost-only).

#### Scenario: Readiness gate uses :9091

- **WHEN** a deploy step waits for backend readiness
- **THEN** the polling loop hits `http://localhost:9091/actuator/health` from inside the VM with basic auth
- **AND** does NOT hit `https://findabed.org/actuator/health`

### Requirement: Memory index companion file

The system SHALL provide `docs/runbook-memory-index.md` — a flat list of every deploy-relevant `feedback_*.md` and `project_*.md` memory file with a one-line description per entry. The index SHALL be hand-curated (or later auto-generated by `opsx-runbook-draft-skill`) and updated when memories are added or removed.

#### Scenario: Author scans the index before authoring

- **WHEN** an operator starts authoring a new release runbook
- **THEN** they read `docs/runbook-memory-index.md` to identify candidate memories for the `consulted:` block
- **AND** the index entries are concise enough (≤150 chars per line) to skim in under 2 minutes

### Requirement: Worked example via v0.49 back-conversion

The change SHALL convert `docs/oracle-update-notes-v0.49.0.md` to the new template format as the canonical worked example. The converted runbook SHALL retroactively cite the memory files that should have been consulted during the original v0.49 authoring (`feedback_prod_docker_build_pattern.md`, `feedback_bind_mount_inode_pitfall.md`, `project_live_deployment_status.md` Lesson 3, `feedback_smoke_spec_default_target.md`, etc.), with a `not-applicable` block where they were missed during original authoring.

#### Scenario: v0.49 runbook follows the new template

- **WHEN** a future operator reads `docs/oracle-update-notes-v0.49.0.md`
- **THEN** the document follows the new template's section order, contains a `consulted:` frontmatter block, includes the service-recreate matrix, and has the mandatory smoke gate

#### Scenario: v0.49 runbook flags the missed memories

- **WHEN** an operator reviewing the v0.49 worked example reads the `consulted:` block
- **THEN** the block contains entries for the 5 memories that should have been consulted but weren't (with a comment indicating "back-cited" status)

