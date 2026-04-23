## 0. Pre-flight: fix known test failure before starting harness work

- [x] 0.1 Fix strict mode violation in `e2e/playwright/tests/demo-211-import-edit.spec.ts:192` — change locator from `'[role="alert"], [data-testid="error-message"]'` to `'[role="alert"]:not([data-testid="critical-notification-banner"])'`; the old locator matches both the import error div AND the SSE notification banner when a prior test leaves one visible (chromium-only failure in full-suite run; nginx project passed because notification had expired). Root cause: test isolation — prior test fires a notification that outlives the test; fix excludes the known-unrelated banner rather than requiring notification dismissal.
- [x] 0.2 Confirm fix: run `BASE_URL=http://localhost:8081 NGINX=1 npx playwright test demo-211-import-edit --trace on` — expect all 6 tests pass in both `[chromium]` and `[nginx]` projects

## 1. Setup

- [x] 1.1 Create feature branch `feature/deploy-rehearsal-harness` from `main` (per `feedback_branch_in_tasks.md`)
- [x] 1.2 Confirm Docker Engine version on operator laptop supports `docker compose alpha dry-run` (Docker Engine 24+); if not, fall back path is documented in design.md decision 5
- [x] 1.3 Read `scripts/phase-b-rehearsal.sh` as the precedent harness — note structure (function-per-step, FAIL early on first error, single PASS/FAIL exit) for reuse

## 2. Author the rehearsal env example

- [x] 2.1 Create `deploy/rehearsal.env.example` with all `FABT_*` env vars present in operator's `~/fabt-secrets/.env.prod`, but with stub values (e.g. `FABT_ALERT_SMTP_HOST=localhost`, `FABT_ALERT_SMTP_PORT=1025` for MailHog, `FABT_ALERT_NTFY_TOPIC=stub-do-not-use-in-prod`)
- [x] 2.2 Add a top-of-file warning header: "STUB VALUES — never commit real credentials to this file. Real prod values live in operator's `~/fabt-secrets/.env.prod` only."
- [x] 2.3 Add a `.gitignore` line for `.env.rehearsal` (operator's local copy)
- [x] 2.4 Document in `FOR-DEVELOPERS.md` that operator copies `deploy/rehearsal.env.example → .env.rehearsal` and customizes if needed

## 3. Author the rehearsal compose overlay

- [x] 3.1 Create `deploy/rehearsal-prod-overlay.yml` mirroring the structure of operator's `~/fabt-secrets/docker-compose.prod.yml` chain
- [x] 3.2 Include all services that prod recreates: backend, frontend, alertmanager, prometheus
- [x] 3.3 Add stub Mailpit service (`axllent/mailpit`, port 1025 SMTP, port 8025 HTTP UI — Mailpit is the maintained successor to MailHog which was abandoned in 2020) opt-in via the `alerting` profile; ntfy stub is a Python `http.server` subprocess started by the harness script itself (no separate compose service needed)
- [x] 3.4 Use `COMPOSE_PROJECT_NAME=fabt-rehearsal` so rehearsal containers do NOT collide with the operator's running dev stack (per `feedback_devstart_pid_desync.md` lesson — separate state from long-lived dev workflow)
- [x] 3.5 Mirror the rendered-config bind-mount pattern: `${HOME}/.fabt-rehearsal/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro` (rendered to `~/.fabt-rehearsal/`, gitignored)

## 4. Author the rehearsal harness script

- [x] 4.1 Create `scripts/deploy-rehearsal.sh` with `set -euo pipefail` + a function-per-step structure (mirror `scripts/phase-b-rehearsal.sh` style)
- [x] 4.2 Implement step 1: prereq check (`docker`, `envsubst`, `mvn`, `jq`, `psql`, `npx playwright` present) — fail loud on missing prereq
- [x] 4.3 Implement step 2: trailing-space env-var lint via `grep -nE "^[A-Z_]+= " .env.rehearsal` — fail loud on any match (catches v0.49 issue #1) per spec requirement "Trailing-space env-var lint"
- [x] 4.4 Implement step 3: envsubst render of `deploy/alertmanager.yml.tmpl` to `~/.fabt-rehearsal/alertmanager.yml` using exact whitelist from prod runbook
- [x] 4.5 Implement step 4: container UID enumeration loop — for each bind-mounting service (alertmanager, postgres, prometheus), `docker run --rm <image> id`, store in `/tmp/rehearsal-uids.txt`, then `stat -c '%u %a' <host-file>` and verify the container UID can read per spec requirement "Container UID vs host file perm verification"
- [x] 4.6 Implement step 5: compose merge dry-render via `docker compose alpha dry-run` (preferred) or `compose config + diff vs golden` (fallback) per spec requirement "Compose merge dry-render validation"
- [x] 4.7 Implement step 6: build (`mvn clean package` for backend, `docker build --no-cache -f infra/docker/Dockerfile.backend`); honor `REHEARSAL_SKIP_BUILD=1` flag with mtime check
- [x] 4.8 Implement step 7: start with service-recreate matrix exercise — `docker compose ... up -d --force-recreate alertmanager backend frontend` (NOT just one) per spec requirement "Service-recreate matrix is exercised" + matrix row a from `runbook-template-v1`
- [x] 4.9 Implement step 8: health checks via VM-internal-style endpoints — `localhost:9091/actuator/health` (backend, NOT public URL — catches v0.49 issue #8 class), `localhost:9093/-/healthy` (alertmanager), `localhost:9090/-/ready` (prometheus)
- [x] 4.10 Implement step 9: synthetic alert routing — fire `FabtRehearsalTest` CRITICAL alert via `docker exec fabt-rehearsal-alertmanager-1 amtool --alertmanager.url http://127.0.0.1:9093 alert add FabtRehearsalTest severity=critical` (`amtool` is bundled in the alertmanager image at `/bin/amtool` — no Windows install needed); assert Mailpit HTTP API (`http://localhost:8025/api/v1/messages`) shows receipt + Python ntfy stub log shows POST within 30 s per spec requirement "Stubbed receivers, no real Gmail / ntfy"
- [x] 4.11 Implement step 10: Playwright smoke — invoke `FABT_BASE_URL=http://localhost:8081 npx playwright test ./deploy/post-deploy-smoke.spec.ts --project chromium --trace on` (NOT `BASE_URL` — spec reads `process.env.FABT_BASE_URL` directly; NOT default testDir invocation — spec lives in `./deploy/`, not `./tests/`); tee output to `logs/rehearsal-smoke-$(date +%Y%m%d-%H%M%S).log` per spec requirement "Playwright smoke against local nginx"
- [x] 4.12 Implement teardown: stop + remove `fabt-rehearsal` project containers; preserve artifacts under `/tmp/deploy-rehearsal-<timestamp>/` for the operator
- [x] 4.13 Final exit: PASS prints "REHEARSAL PASS — safe to tag <timestamp>", FAIL prints "REHEARSAL FAIL — DO NOT TAG" with failing gate name + artifact path per spec requirement "Single PASS/FAIL exit code"

## 5. Add Makefile target

- [x] 5.1 Create `Makefile` at repo root (no Makefile currently exists) with `rehearse-deploy:` target invoking `bash scripts/deploy-rehearsal.sh`
- [x] 5.2 Add `make help` listing including `rehearse-deploy` description
- [x] 5.3 Document in `docs/FOR-DEVELOPERS.md` that operator runs `make rehearse-deploy` before tagging any release (new "Pre-tag rehearsal" subsection)

## 6. Add release-gate-pin

- [x] 6.1 Append `rehearsal-green-within-72h` pin to `deploy/release-gate-pins.txt` with brief description per spec requirement "Release-gate-pin integration"
- [x] 6.2 Update `scripts/ci/verify-release-gate-pins.sh` to enforce: any PR bumping `backend/pom.xml` version AND modifying `CHANGELOG.md` MUST reference the rehearsal log filename in the PR description OR have a sidecar `deploy/rehearsal-attest-<version>.txt` artifact

## 7. Update FOR-DEVELOPERS.md

- [x] 7.1 Add new "Pre-tag rehearsal" subsection to `docs/FOR-DEVELOPERS.md` (file exists at that path; add subsection under the deploy/ops section)
- [x] 7.2 Document the harness flow (10 steps), expected wall time (~10 min), what's caught vs what's not (per design.md non-goals section)
- [x] 7.3 Add operator-laptop prereq list (Docker Desktop, Maven, Node + Playwright, jq, envsubst, Python 3 for ntfy stub — most already present from regular dev work)

## 8. Verification

- [ ] 8.1 Run `make rehearse-deploy` against the current main branch — expect PASS
- [ ] 8.2 Intentionally introduce a `KEY= value` typo in `.env.rehearsal` — expect FAIL with the v0.49 issue #1 error message
- [ ] 8.3 Intentionally `chmod 600 ~/.fabt-rehearsal/alertmanager.yml` after envsubst step — expect FAIL with the v0.49 issue #2 error message
- [ ] 8.4 Intentionally edit a Sprig `default` function back into `deploy/alertmanager-templates.tmpl` (revert the v0.49 fix) — expect FAIL when alertmanager fails to load templates
- [ ] 8.5 Intentionally remove `frontend` from the recreate list in the harness step 7 — expect FAIL when Playwright smoke 502s (or sustained delay)
- [ ] 8.6 Confirm artifacts preserved under `/tmp/deploy-rehearsal-<timestamp>/` after each FAIL run
- [ ] 8.7 Confirm no rehearsal containers remain after PASS run (clean teardown)

## 9. Commit + ship

- [x] 9.1 Stage all new files: `scripts/deploy-rehearsal.sh`, `deploy/rehearsal.env.example`, `deploy/rehearsal-prod-overlay.yml`, `Makefile` (or modifications), `FOR-DEVELOPERS.md` (modified), `deploy/release-gate-pins.txt` (modified), `scripts/ci/verify-release-gate-pins.sh` (modified)
- [x] 9.2 Commit with conventional message: `feat(ops): deploy rehearsal harness — operator-laptop prod-mirror gate before tagging`
- [x] 9.3 Push, open PR, wait for CI green per `feedback_release_after_scans.md`
- [x] 9.4 Merge to main; this change is operator-tooling, no version bump, no deploy — merged as PR #149 (2026-04-23)

## 10. Post-merge validation (use it for v0.50)

- [ ] 10.1 Operator runs `make rehearse-deploy` before tagging the next release (v0.50)
- [ ] 10.2 If the harness catches an issue, fix it and document in `feedback_deploy_rehearsal_lessons.md` (new memory)
- [ ] 10.3 If the harness itself is buggy, fix and PR back as a follow-up commit
- [ ] 10.4 After 2 successful manual runs (v0.50 + v0.51 deploys), revisit Phase F (`phase-f-ci-rehearsal-gate`) to wire the harness into CI on deploy-touching PRs
