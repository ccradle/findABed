## ADDED Requirements

### Requirement: Rehearsal harness exists at canonical path

The system SHALL provide `scripts/deploy-rehearsal.sh` as the operator-runnable rehearsal harness. The script SHALL be executable, version-controlled, and committed to the main branch.

#### Scenario: Operator can invoke the harness

- **WHEN** the operator runs `make rehearse-deploy` from the repo root
- **THEN** `scripts/deploy-rehearsal.sh` executes
- **AND** the script returns a single PASS or FAIL exit code

#### Scenario: Direct invocation also works

- **WHEN** the operator runs `bash scripts/deploy-rehearsal.sh` directly
- **THEN** the script executes the same flow as the Makefile target

### Requirement: Trailing-space env-var lint as first step

The harness SHALL run a lint check on the rehearsal env file as its first step, failing loud on any line matching `^[A-Z_]+= ` (KEY equals SPACE — bash treats this as "set KEY empty then run value as command"). This catches the v0.49 issue #1 class.

#### Scenario: Lint catches a trailing-space env var

- **WHEN** `.env.rehearsal` contains a line `FABT_ALERT_NTFY_TOPIC= test-topic` (note space after `=`)
- **THEN** the harness exits non-zero with an error message naming the offending line and the bash-sourcing failure mode
- **AND** no further harness steps execute

#### Scenario: Lint passes on a clean env file

- **WHEN** `.env.rehearsal` has all values immediately following `=` with no whitespace
- **THEN** the lint step prints "env file format OK" and proceeds

### Requirement: Container UID vs host file perm verification

The harness SHALL enumerate the runtime UID of every container that bind-mounts a host file and verify the host file's permissions allow that UID to read. This catches the v0.49 issue #2 class (alertmanager UID 65534 cannot read a 0600 file owned by ubuntu UID 1000).

#### Scenario: Mismatched UID and perm fails the gate

- **WHEN** the rehearsal renders `alertmanager.yml` with `chmod 600` and the alertmanager container runs as UID 65534
- **THEN** the harness flags "UID 65534 cannot read 0600 file owned by 1000" and exits non-zero
- **AND** the error message includes the suggested fix (`chmod 644` with rationale that parent dir 700 still protects against host-side reads)

#### Scenario: Compatible UID and perm passes the gate

- **WHEN** the rehearsal renders `alertmanager.yml` with `chmod 644`
- **THEN** the UID/perm gate passes for alertmanager
- **AND** the harness proceeds to the next step

### Requirement: Compose merge dry-render validation

The harness SHALL validate the prod-mirroring compose merge layout via `docker compose alpha dry-run` (preferred when available) or `docker compose config + diff vs golden` (fallback). The validation SHALL detect volume target conflicts, missing service definitions, and unexpected service additions.

#### Scenario: Dry-render succeeds for a clean overlay

- **WHEN** the harness runs `docker compose -f docker-compose.yml -f deploy/rehearsal-prod-overlay.yml --env-file .env.rehearsal --profile alerting alpha dry-run up alertmanager backend frontend`
- **THEN** the command exits 0
- **AND** the harness prints "compose dry-render OK"

#### Scenario: Dry-render fails on volume target conflict

- **WHEN** an overlay introduces a second mount targeting the same container path with no override resolution
- **THEN** the dry-render fails with a clear error
- **AND** the harness exits non-zero

### Requirement: Service-recreate matrix is exercised

The harness SHALL exercise the same service-recreate matrix that `runbook-template-v1` defines for runbooks. When the harness simulates a backend recreate, it SHALL also recreate frontend (per matrix row a). When the harness simulates a `prometheus.yml` change, it SHALL `--force-recreate prometheus` (not `/-/reload`). The harness's matrix SHALL match the template's matrix; drift between the two is itself a defect.

#### Scenario: Backend recreate triggers frontend recreate

- **WHEN** the harness's "build + start" step recreates backend
- **THEN** the same step also recreates frontend (per matrix row a — backend↔frontend docker network coupling)

#### Scenario: prometheus.yml change requires --force-recreate

- **WHEN** the harness simulates editing `prometheus.yml`
- **THEN** the harness runs `docker compose ... up -d --force-recreate prometheus`
- **AND** does NOT rely on `curl -X POST /-/reload` alone (per `feedback_bind_mount_inode_pitfall.md`)

### Requirement: Stubbed receivers, no real Gmail / ntfy

The harness SHALL NOT send real SMTP email or hit real ntfy.sh during alert-routing tests. It SHALL spin up local stub receivers (e.g. MailHog for SMTP capture, a local HTTP listener for ntfy webhook capture) on ports that do not collide with the operator's running dev stack.

#### Scenario: Synthetic CRITICAL alert routes to stub receivers

- **WHEN** the harness fires a synthetic `FabtRehearsalTest` alert with `severity=critical` against the stubbed alertmanager via `docker exec fabt-rehearsal-alertmanager-1 amtool --alertmanager.url http://127.0.0.1:9093 alert add ...`
- **THEN** the Mailpit container (`axllent/mailpit`, port 1025 SMTP / 8025 HTTP UI) records SMTP receipt queryable via its HTTP API
- **AND** the Python `http.server` ntfy stub records the webhook POST
- **AND** no traffic leaves the operator laptop

#### Scenario: Real-receiver opt-in is gated

- **WHEN** the operator wants to test against real Gmail (rare; only before a release that changes receiver wiring)
- **THEN** they MUST set `REHEARSAL_REAL_EMAIL=1` AND provide a throwaway Gmail app password via env
- **AND** the harness prints a security warning before sending

### Requirement: Playwright smoke against local nginx

The harness SHALL run the Playwright post-deploy smoke spec against `http://localhost:8081` (the nginx-fronted port that mirrors prod's request flow), per `feedback_check_ports_before_assuming.md` and `feedback_test_with_nginx_in_dev.md`. The harness SHALL NOT run the smoke against bare Vite (`http://localhost:5173`).

#### Scenario: Smoke runs against nginx port

- **WHEN** the harness's smoke step executes
- **THEN** the invocation sets `FABT_BASE_URL=http://localhost:8081` (NOT `BASE_URL` — `post-deploy-smoke.spec.ts` reads `process.env.FABT_BASE_URL` directly, bypassing Playwright's `baseURL` config)
- **AND** the spec is invoked explicitly as `npx playwright test ./deploy/post-deploy-smoke.spec.ts --project chromium` (since `playwright.config.ts` `testDir` is `./tests`, not `./deploy`)
- **AND** output is tee'd to `logs/rehearsal-smoke-<timestamp>.log` per `feedback_run_tests_once_to_logs.md`

#### Scenario: Smoke failure fails the harness

- **WHEN** any Playwright smoke test in `e2e/playwright/deploy/post-deploy-smoke.spec.ts` fails
- **THEN** the harness exits non-zero
- **AND** the harness preserves the trace.zip artifacts under `/tmp/deploy-rehearsal-<timestamp>/`

### Requirement: Single PASS/FAIL exit code

The harness SHALL exit with code 0 on full success or non-zero on any gate failure. The exit code SHALL be the only signal the operator (or future CI) needs to determine pass/fail. Per-gate output SHALL be human-readable but non-blocking on output parsing.

#### Scenario: All gates pass

- **WHEN** every gate (env-var lint, UID/perm, compose dry-render, build, recreate matrix, healthchecks, alert routing, Playwright smoke) passes
- **THEN** the harness exits 0
- **AND** prints "REHEARSAL PASS — safe to tag" with a timestamp

#### Scenario: Any gate fails

- **WHEN** any single gate fails
- **THEN** the harness exits non-zero
- **AND** prints "REHEARSAL FAIL — DO NOT TAG" with the failing gate's name + the relevant artifact path (log file, trace zip, etc.)

### Requirement: Release-gate-pin integration

The system SHALL add a `rehearsal-green-within-72h` pin to `deploy/release-gate-pins.txt`. The pin SHALL be enforced by `scripts/ci/verify-release-gate-pins.sh` (modified) at PR-time on `main`-targeting PRs that include a CHANGELOG version bump.

#### Scenario: Pin is present

- **WHEN** an operator inspects `deploy/release-gate-pins.txt`
- **THEN** a `rehearsal-green-within-72h` line is present with a brief description of the requirement

#### Scenario: PR with version bump references the pin

- **WHEN** a PR bumps `backend/pom.xml` version AND adds a new `## [vX.Y.Z]` line to `CHANGELOG.md`
- **THEN** the PR description (or a sidecar artifact) MUST reference the rehearsal log filename or attest that rehearsal passed within the last 72 h
- **AND** `verify-release-gate-pins.sh` flags violations

### Requirement: Full-suite Playwright run is clean before harness ships

The change SHALL fix the known strict mode violation in `e2e/playwright/tests/demo-211-import-edit.spec.ts` so that the full Playwright suite (chromium + nginx projects) passes with no unexpected failures before this change merges. This ensures the harness verification step (task 8.1) runs against a clean baseline.

#### Scenario: 211 import negative-case test passes in both projects

- **WHEN** the full Playwright suite runs with `BASE_URL=http://localhost:8081 NGINX=1`
- **THEN** `demo-211-import-edit.spec.ts › headers-only file shows error message` passes in both `[chromium]` and `[nginx]` projects
- **AND** no strict mode violation is raised by the locator in that test

### Requirement: Operator-laptop only — no CI integration in this change

This change SHALL ship the harness as operator-laptop only. CI integration is Phase F (`phase-f-ci-rehearsal-gate`, separate change). The harness MAY be designed to be CI-runnable but MUST NOT add any GitHub Actions workflow or other CI integration as part of this change.

#### Scenario: No CI workflow added

- **WHEN** the change is reviewed at archive time
- **THEN** no new files exist under `.github/workflows/` referencing the rehearsal harness
- **AND** `scripts/ci/` may contain helper scripts called by the harness, but no CI workflow yaml triggers them automatically
