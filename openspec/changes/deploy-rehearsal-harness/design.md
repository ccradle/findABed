## Context

FABT prod is a single Oracle Always Free VM running docker-compose. Operator deploys via SSH from laptop. v0.49.0 deployment surfaced 10 issues mid-flight; 6 of them are reproducible in a local docker-compose stack if we faithfully mirror the prod compose-merge layout, secret rendering, container UID handling, and post-deploy health gates.

Existing precedent: `scripts/phase-b-rehearsal.sh` was the rehearsal harness for the Phase B FORCE RLS deploy. It ran the panic-script dry-run + Phase B migrations against a throwaway pgaudit container before the v0.43 deploy. That harness shipped, was used, and caught real issues. This change generalizes the pattern.

External validation (web research):
- Docker official: `docker compose alpha dry-run` exists since Docker Engine 24+ — could replace some of our manual `compose config + diff` work
- Testcontainers complements (not replaces) docker-compose for ephemeral testing
- Marcus/Security flag from web research: Prometheus devs explicitly discourage env-vars-for-secrets; for FABT demo-tier `envsubst + .env.prod` is acceptable per `compliance-posture-matrix.md`, but Phase F regulated-tier should migrate to file-mounted secrets or Vault — note this in design but do not block on it for v0.50

Constraints:
- Operator laptop is Windows + Git Bash (per memory `feedback_windows_taskkill.md` re: MSYS path conversion); the harness MUST work in that environment
- Must NOT touch real secrets (no real Gmail SMTP, no real ntfy.sh topic) — Marcus's red line
- Must work without internet for everything except docker-image-pulls and `npm install` (Cloudflare 429s + Gmail/ntfy deliverability cannot be reproduced offline anyway)
- Must complete in <15 min wall time on a typical laptop (otherwise operators won't run it)
- MUST follow `feedback_use_dev_start_script.md` — no raw `docker compose` commands; the harness wraps and calls compose, but operators invoke `make rehearse-deploy` or `dev-start.sh rehearse`

## Goals / Non-Goals

**Goals:**

- Reproduce the EXACT prod compose-merge layout in a local stack, so volume target conflicts, override resolution, and bind-mount inode handling are exercised identically.
- Catch the 6 reproducible-in-dev issue classes from v0.49: trailing-space env vars (#1), container-UID-vs-host-perm (#2), template-engine-incompatible functions like Sprig `default` (#3), missing-service-recreate (#4), bind-mount inode pitfall (#6), wrong actuator URL (#8).
- Stub all external receivers (no real Gmail, no real ntfy, no real Cloudflare) so the harness is safe + repeatable + offline-capable.
- Run Playwright smoke against the rehearsal stack (BASE_URL=`http://localhost:8081`) per `feedback_check_ports_before_assuming.md` and `feedback_test_with_nginx_in_dev.md`.
- Produce a single PASS/FAIL exit code so it can be wired into a release-gate-pin (this change) and later into CI (Phase F change).
- Be invokable BEFORE git-tagging a release; failure blocks the tag.

**Non-Goals:**

- Catch VM-side `git checkout` working-tree drift (v0.49 issue #5) — that's a stateful-VM-only failure mode; harness can't reproduce.
- Catch Cloudflare-side 429s on `/api/v1/version` — that's a CDN-side rate limit; harness has no Cloudflare in the loop.
- Validate Gmail SMTP deliverability or ntfy.sh push reliability — those are real-receiver tests; harness uses stubs.
- Replace the prod runbook — the harness exercises the *flow*; the runbook documents the *steps*. They are complementary, not redundant.
- Provide a CI-runnable harness — that's `phase-f-ci-rehearsal-gate`; this change is operator-laptop only for v0.50.
- Fix Phase F regulated-tier secrets handling (Vault, file-mounted secrets) — out of scope; flagged for future.

## Decisions

**1. `make rehearse-deploy` (Makefile target) over `dev-start.sh rehearse` subcommand.**

Decision: Add a `Makefile` at repo root (or extend if one exists) with a `rehearse-deploy:` target.

Alternatives considered:
- `dev-start.sh rehearse` subcommand. CONSIDERED — would centralize all dev tooling in one script (per `feedback_use_dev_start_script.md`). REJECTED because dev-start.sh already manages a "long-lived dev stack" workflow with PID files (`.pid-backend`); a rehearsal is a "throwaway run" workflow that should NOT touch the long-lived state. Mixing them risks the rehearsal nuking the operator's running dev stack.
- Direct invocation `bash scripts/deploy-rehearsal.sh`. CONSIDERED — simplest. REJECTED because makes the rehearsal feel "low ceremony" — Marcus + Jordan want a deliberate gate the operator runs intentionally before tagging.
- npm script in `frontend/package.json`. REJECTED — backend-heavy harness should not live in frontend tooling.

Rationale: Makefile makes the intent explicit, separates throwaway-rehearsal from long-lived-dev workflows, and is discoverable via `make help`.

**2. Stubbed receivers: Mailpit container (SMTP) + Python `http.server` subprocess (ntfy).**

Decision: For receiver-routing tests (alertmanager → email + ntfy):
- **SMTP stub**: `axllent/mailpit` container on port 1025 (SMTP) / port 8025 (HTTP UI). Mailpit is the actively-maintained drop-in successor to MailHog — MailHog's last commit was 2020 and is unmaintained. Same port contract, same API, ~15 MB image.
- **ntfy stub**: Python built-in `http.server` started as a background subprocess — returns 200 to any POST, logs bodies to the rehearsal artifact dir. No extra container image; Python is universally available in Git Bash. Simpler than nginx.

Alternatives considered:
- MailHog (`mailhog/mailhog`). CONSIDERED. REJECTED — abandoned since 2020; Mailpit is the maintained replacement.
- nginx container as ntfy stub. CONSIDERED. REJECTED — overengineered for a 200-OK stub; Python `http.server` requires no extra image.
- Mock in bash only (check logs for "would send"). REJECTED — doesn't exercise actual TCP flow; misses SMTP handshake errors.
- Real Gmail with throwaway app password. REJECTED — Marcus red line; real rate limits make harness flaky.
- Skip receiver-routing entirely. REJECTED — that's the v0.49 issue #3 class.

Rationale: Mailpit exercises the real SMTP path; Python stub handles the ntfy webhook with zero extra infrastructure. Combined extra disk: ~15 MB.

**3. Container UID enumeration via `docker inspect` + bind-mount perm check.**

Decision: A loop that runs `docker run --rm <image> id` for every service that bind-mounts a host file, then `stat -c '%u %a' <host-file>` and compares.

Alternatives considered:
- Hard-code the UIDs in the harness (e.g. "alertmanager runs as 65534, postgres as 999"). REJECTED — image upgrades change UIDs (e.g. postgres went from UID 70 to 999 in v0.44); hardcoded values bit-rot.
- Skip the check, rely on docker-compose-up to fail. REJECTED — that's exactly v0.49 issue #2 — alertmanager only crash-looped, not failed-to-start, so compose returned success and the operator missed it for ~6 min.

Rationale: dynamic enumeration adapts to image upgrades; explicit `stat` comparison fails loud BEFORE compose-up.

**4. Trailing-space env-var lint as a separate first-class step.**

Decision: First step of harness is `grep -nE "^[A-Z_]+= " .env.rehearsal` — fail loud on any match.

Rationale: catches v0.49 issue #1 in <100 ms with a clear error message. Reusable as a runbook pre-deploy gate.

**5. Use `docker compose alpha dry-run` for compose merge validation.**

Decision: Where available, prefer `docker compose alpha dry-run -- up alertmanager backend frontend` over manual `config + diff`. The `--` separator is required in Compose v5 to separate the `dry-run` subcommand from the target command — confirmed on Docker 29.2.1 / Compose v5.0.2 (operator's machine). Fall back to `docker compose config + diff vs golden` if unavailable.

Alternatives considered:
- Stick with `compose config + diff vs golden`. CONSIDERED — what v0.49 runbook used; works but produces noisy diffs.
- Use both. PARTIAL — fall back to `config + diff` if `alpha dry-run` is unavailable.

Rationale: `dry-run` is the Docker-blessed approach; less noisy; future-proof. Note: `docker compose alpha` is experimental — the `--` separator syntax is confirmed working on Compose v5.0.2.

**6. Playwright smoke target = local nginx (port 8081), NOT bare Vite.**

Decision: Per `feedback_check_ports_before_assuming.md` and `feedback_test_with_nginx_in_dev.md`, the rehearsal smoke MUST hit `http://localhost:8081` (the nginx-fronted port that mirrors prod's flow), not `http://localhost:5173` (bare Vite).

Implementation detail (ground-truth verified): `e2e/playwright/deploy/post-deploy-smoke.spec.ts` uses `process.env.FABT_BASE_URL` (NOT `BASE_URL`) with a default of `https://findabed.org`. The spec bypasses Playwright's `baseURL` config entirely via `page.goto(BASE + '/...')`. Therefore:
- The harness MUST set `FABT_BASE_URL=http://localhost:8081` (not `BASE_URL`).
- `NGINX=1` and Playwright's project `baseURL` have no effect on this spec.
- `playwright.config.ts` sets `testDir: './tests'` — the smoke spec lives in `./deploy/`, so the harness MUST invoke it with an explicit path: `npx playwright test ./deploy/post-deploy-smoke.spec.ts --project chromium`.

**7. Service-recreate matrix is encoded in the harness itself.**

Decision: The harness's "build + start" step uses the same matrix as the runbook template — backend recreate triggers frontend recreate, prometheus.yml change triggers prometheus recreate, etc. The harness's matrix and the template's matrix MUST match (linted by an integration test in `ci-runbook-consulted-check`, separate change).

Rationale: ensures "what the harness does" and "what the runbook says" never drift.

## Risks / Trade-offs

- **[Harness drift from prod compose layout]** — prod compose chain is 4 files; the rehearsal overlay only mirrors the structure with stub values. If a real prod compose file changes structurally (new override, new service), the rehearsal overlay must be updated in lockstep. → Mitigated by listing the rehearsal overlay in the v0.50 runbook template's "service-recreate matrix" follow-up checklist; any prod compose-layout change requires a paired rehearsal-overlay update in the same PR.
- **[Stub receiver behavior diverges from real Gmail/ntfy]** — Mailpit accepts everything; real Gmail rejects malformed Subject headers, has DKIM/SPF, etc. → Accepted; harness catches template-engine-level errors (the v0.49 issue #3 class), not delivery-quality issues. Document this clearly in the harness output: "Receivers are stubbed; this run does NOT validate real-Gmail deliverability."
- **[Operator skips the rehearsal under time pressure]** — without CI enforcement (Phase F), operator can tag without rehearsal. → Mitigated by adding the `rehearsal-green-within-72h` pin to `release-gate-pins.txt`; the v0.50 runbook template's pre-deploy gate references this pin and the runbook author MUST attach the rehearsal log file to the deploy incident thread. Not bulletproof; Phase F CI gate closes the loop.
- **[Marcus/Security concern: stubbed `.env.rehearsal` has fake credentials]** — even fake credentials in committed example files can train operators to put real ones there by mistake. → Mitigated by `.env.rehearsal` being gitignored; `deploy/rehearsal.env.example` (committed) has obvious placeholder strings like `STUB_DO_NOT_USE_IN_PROD` and includes a top-of-file warning.
- **[~10 min wall-time may discourage runs]** — `mvn clean package` is ~2 min, image build ~2 min, compose up + healthchecks ~2 min, Playwright smoke ~3 min. → Mitigated by `REHEARSAL_SKIP_BUILD=1` flag for fast iteration on harness changes (skips Maven if `target/*.jar` is fresher than last `git log -1 --format=%ct backend/`).
- **[Phase F regulated-tier]** — `envsubst + .env.prod` for secrets is acceptable for demo-tier (per `compliance-posture-matrix.md` Alerting Tier Posture section) but the web-research-confirmed Prometheus-team position is "discouraged for production." When FABT moves to regulated-tier, the rehearsal harness will need to be updated to exercise file-mounted secrets or Vault/External Secrets. Out of scope for this change; flagged in design.md so future authors don't forget.

## Migration Plan

1. Land `scripts/deploy-rehearsal.sh` + `deploy/rehearsal.env.example` + `deploy/rehearsal-prod-overlay.yml` + `Makefile` snippet + `docs/FOR-DEVELOPERS.md` "Pre-tag rehearsal" subsection.
2. Operator runs the harness manually before tagging v0.50 (this is the first real-world test of the harness).
3. If the harness catches an issue, fix it and re-run; if the harness itself is buggy, fix the harness in a follow-up commit.
4. After 2 releases of manual use (v0.50 + v0.51), revisit Phase F (`phase-f-ci-rehearsal-gate`) — the harness should have ~2 weeks of operator-usage data to inform the CI gate's failure modes and tolerance.
5. Add `rehearsal-green-within-72h` to `release-gate-pins.txt` after the first successful manual run.

Rollback: revert the commits. No production impact (harness runs only on operator laptop). The `release-gate-pins.txt` entry can be removed if the pin proves problematic.

## Open Questions

**[RESOLVED]** Does `docker compose alpha dry-run` work on the operator's Docker Desktop / Git Bash setup?
→ Yes. Confirmed available as `docker compose alpha dry-run -- up [services]` on Docker 29.2.1 / Compose v5.0.2. The `--` separator is required. Fall back to `compose config` if the experimental subcommand is removed in a future Compose version.

**[RESOLVED]** Should MailHog be replaced?
→ Yes. MailHog is abandoned (last commit 2020). Use Mailpit (`axllent/mailpit`) — drop-in replacement, same ports, actively maintained. ntfy stub replaced with Python `http.server` subprocess (simpler, no extra image). See Decision 2.

**[RESOLVED]** How to invoke `amtool` on Windows / Git Bash without a native binary?
→ `amtool` is bundled in the `prom/alertmanager:v0.27.0` image at `/bin/amtool`. Invoke via `docker exec` against the running rehearsal alertmanager container: `docker exec fabt-rehearsal-alertmanager-1 amtool --alertmanager.url http://127.0.0.1:9093 alert add ...`. No Windows binary install required.

Does the rehearsal need to exercise the Cloudflare → host nginx → frontend chain, or just frontend → backend? Decision: frontend → backend only for v0.50; the host-nginx layer is operator-side state, not in-repo. Document the gap.

Does `feedback_devstart_pid_desync.md` apply — i.e., does the rehearsal harness need to manage PID files? Decision: no — rehearsal uses a separate `COMPOSE_PROJECT_NAME=fabt-rehearsal` so it doesn't collide with the operator's running dev stack.
