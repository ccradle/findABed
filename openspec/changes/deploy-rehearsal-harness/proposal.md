## Why

The v0.49.0 deploy hit 10 mid-flight issues. Six of them — `KEY= value` env-var trailing-space, `chmod 600` blocking the alertmanager UID, Sprig `default` function in template, missing frontend recreate, bind-mount inode pitfall on prometheus.yml, wrong actuator URL — would have surfaced in dev rehearsal had we run the EXACT prod flow against a throwaway local stack. Instead, every failure happened against live findabed.org with operator + Claude troubleshooting under deploy time pressure. We have precedent for this: `scripts/phase-b-rehearsal.sh` was the rehearsal harness for the Phase B FORCE RLS deploy and caught real issues before they reached prod. We need the same discipline generalized to every release.

## What Changes

- **NEW `scripts/deploy-rehearsal.sh`** — operator-runnable script that mirrors the EXACT prod deploy flow against a local docker-compose stack: envsubst render with operator-style `.env`, container UID enumeration vs file perms, compose merge dry-render, build + start with `--force-recreate` matrix discipline, health checks across recreated services, synthetic alert routing (stubbed receivers — no real Gmail/ntfy), Playwright smoke against `http://localhost:8081` (the nginx front).
- **NEW `deploy/rehearsal.env.example`** — committed safe-placeholder env file for rehearsal (fake SMTP credentials, dummy ntfy topic, stub URLs); operator copies to `.env.rehearsal` (gitignored) and customizes if needed.
- **NEW `deploy/rehearsal-prod-overlay.yml`** — committed compose overlay that mirrors the operator-side `~/fabt-secrets/docker-compose.prod*.yml` chain WITHOUT real secrets, so the rehearsal exercises the merge layout that prod actually runs.
- **NEW `make rehearse-deploy` target** (or `dev-start.sh rehearse` subcommand — see design.md decision) — single entry point operator runs before tagging.
- **NEW `deploy/release-gate-pins.txt` entry**: `rehearsal-green-within-72h` — extends the existing release-gate-pins pattern (codified by `scripts/ci/verify-release-gate-pins.sh`) so the runbook can pin "rehearsal must have passed within 72h of tag."
- **No CI integration in this change** — that's Phase F (`phase-f-ci-rehearsal-gate`); this change ships the harness only, to be exercised manually by the operator for at least 2 releases before being made gating.

## Capabilities

### New Capabilities

- `deploy-rehearsal`: Operator-laptop dev rehearsal harness that mirrors the prod deploy flow against a local docker-compose stack, including envsubst render, container-UID/perm verification, compose dry-render, service recreate matrix exercise, stubbed alert routing, and Playwright smoke. Designed to catch the ~80% of deploy issues that are reproducible in dev (per the warroom honesty assessment — VM-side `git checkout` drift, Cloudflare 429s, real SMTP/ntfy deliverability are NOT caught).

### Modified Capabilities

(none — net-new harness; no existing capabilities depend on it yet — `runbook-template-v1` will reference it)

## Impact

- **New files:** `scripts/deploy-rehearsal.sh` (~200-400 lines bash), `deploy/rehearsal.env.example` (~50 lines), `deploy/rehearsal-prod-overlay.yml` (~80 lines compose YAML), `Makefile` snippet OR `dev-start.sh` subcommand (~10 lines)
- **Modified files:** `deploy/release-gate-pins.txt` (one new pin), `scripts/ci/verify-release-gate-pins.sh` (one new check if the pin format demands it), `FOR-DEVELOPERS.md` (one new "Pre-tag rehearsal" subsection)
- **Disk + time cost:** rehearsal run uses ~600 MB extra ephemeral docker volumes; ~5-10 min wall time per run on operator laptop (Maven build + image build + compose up + Playwright smoke)
- **No production impact** — runs entirely on operator laptop; no VM SSH, no real SMTP, no real ntfy, no Cloudflare
- **Enables:** the v0.50 release runbook can include "rehearsal green within 72h" as a pre-deploy gate; `phase-f-ci-rehearsal-gate` (separate change) can layer a CI job on top
- **Memory impact:** new `feedback_deploy_rehearsal_lessons.md` will accrue as the harness surfaces issues across releases
