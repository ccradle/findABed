## 1. Setup

- [ ] 1.1 Confirm `runbook-template-v1` is merged to main BEFORE starting this change (hard dependency — needs the `consulted:` convention to exist)
- [ ] 1.2 Confirm `opsx-runbook-draft-skill` is merged or near-merge so the `[!WARNING]` self-disclosure marker text is finalized
- [ ] 1.3 Create feature branch `feature/ci-runbook-consulted-check` from `main` (per `feedback_branch_in_tasks.md`)
- [ ] 1.4 Survey existing `scripts/ci/` patterns by reading `scripts/ci/verify-release-gate-pins.sh` for shell style + error message conventions

## 2. Author the check script

- [ ] 2.1 Create `scripts/ci/check-runbook-consulted-memories.sh` with `#!/usr/bin/env bash` + `set -euo pipefail`
- [ ] 2.2 Add top-of-file comment block citing `runbook-template-v1` (the convention this enforces) and `opsx-runbook-draft-skill` (the marker text source)
- [ ] 2.3 Implement helper: `detect_changed_files()` — uses `git diff --name-only origin/main...HEAD` in CI, or `git diff --name-only HEAD` plus `git ls-files --others --exclude-standard` locally to capture uncommitted changes per spec requirement "Local pre-commit invocation"
- [ ] 2.4 Implement helper: `pr_title_contains_skip_token()` — checks `$GITHUB_PR_TITLE` env var (set by workflow) for `[skip-runbook-check]` substring per spec requirement "Escape hatch via PR title token"
- [ ] 2.5 Implement assertion 1: `check_consulted_block_present()` — for each modified runbook, grep for fenced ` ```yaml ` block containing `^consulted:` per spec requirement "Detect missing consulted block"
- [ ] 2.6 Implement assertion 2: `check_no_leftover_warning()` — for each modified runbook, grep for `> \[!WARNING\]` AND adjacent line containing `This draft is generated` per spec requirement "Detect leftover draft warning"
- [ ] 2.7 Implement assertion 3: `check_new_memories_cited()` — for each newly-added `feedback_*.md` file (via `git diff --diff-filter=A`), grep each modified runbook for the new file's basename per spec requirement "Detect uncited new memory files"
- [ ] 2.8 Implement main flow: detect_changed_files → if no runbook touched, exit 0 → if skip token present, exit 0 with warning → run all 3 assertions → exit 0 if all pass, non-zero on first failure
- [ ] 2.9 Implement error message helper that formats per spec requirement "Failure messages are self-actionable" — file path + plain-language assertion + pointer to source-of-truth
- [ ] 2.10 Verify POSIX portability per spec requirement "POSIX-portable shell (Windows compatibility)" — use only `grep`, `sed`, `awk` features available in busybox/macOS/Git-Bash

## 3. Author the GitHub Actions workflow

- [ ] 3.1 Create `.github/workflows/runbook-consulted-check.yml` with `pull_request:` trigger and `paths:` filter on `docs/oracle-update-notes-v*.md` per spec requirement "Path-filtered CI workflow"
- [ ] 3.2 Single job: `check`, runs-on `ubuntu-latest`, single step: `bash scripts/ci/check-runbook-consulted-memories.sh`
- [ ] 3.3 Pass `GITHUB_PR_TITLE: ${{ github.event.pull_request.title }}` as env to the step so the script can detect the skip token
- [ ] 3.4 Set `actions/checkout@v4` with `fetch-depth: 0` so `git diff origin/main...HEAD` works correctly

## 4. Local + CI verification

- [ ] 4.1 Run `bash scripts/ci/check-runbook-consulted-memories.sh` locally against current main — expect "no runbook touched, exit 0" since main has no in-flight changes
- [ ] 4.2 Test assertion 1: locally edit `docs/oracle-update-notes-v0.49.0.md` to remove the `consulted:` block — run script — expect FAIL with the documented error
- [ ] 4.3 Test assertion 2: locally inject `> [!WARNING]\nThis draft is generated` into a runbook — run script — expect FAIL
- [ ] 4.4 Test assertion 3: locally add a fake `feedback_test.md` to memory + edit a runbook without citing it — run script — expect FAIL
- [ ] 4.5 Test escape hatch: set `GITHUB_PR_TITLE='fix [skip-runbook-check]'` and re-run a failing scenario — expect exit 0 with skip warning
- [ ] 4.6 Test on Windows Git Bash (per `feedback_windows_taskkill.md`) — confirm POSIX portability per spec requirement "POSIX-portable shell (Windows compatibility)"

## 5. End-to-end PR test

- [ ] 5.1 Open a test PR that touches `docs/oracle-update-notes-v0.49.0.md` (the converted v0.49 worked example) — confirm the workflow triggers AND passes (the worked example already has a valid `consulted:` block by `runbook-template-v1` design)
- [ ] 5.2 Open a deliberately-failing test PR (e.g. delete the `consulted:` block from a runbook) — confirm the workflow fails with the right error message
- [ ] 5.3 Add a `[skip-runbook-check]` to the failing PR's title — confirm the workflow now passes with the skip warning logged
- [ ] 5.4 Close the test PRs without merging

## 6. Update FOR-DEVELOPERS.md

- [ ] 6.1 Add to "Pre-tag rehearsal" subsection: "Before pushing a PR that touches `docs/oracle-update-notes-v*.md`, run `bash scripts/ci/check-runbook-consulted-memories.sh` locally to catch issues before CI does."
- [ ] 6.2 Document the `[skip-runbook-check]` escape hatch with a strong recommendation: "Use ONLY for emergency hotfixes; abuse will be reviewed quarterly."

## 7. Commit + ship

- [ ] 7.1 Stage `scripts/ci/check-runbook-consulted-memories.sh`, `.github/workflows/runbook-consulted-check.yml`, `FOR-DEVELOPERS.md` (modified)
- [ ] 7.2 Commit with conventional message: `ci(runbook): enforce consulted-memories convention on runbook PRs`
- [ ] 7.3 Push, open PR, wait for CI green per `feedback_release_after_scans.md` (this PR will trigger its own check — confirm it passes since the PR doesn't touch a runbook file itself)
- [ ] 7.4 Merge to main; this change is CI tooling, no version bump, no deploy

## 8. Post-merge — observe

- [ ] 8.1 Watch the next 2-3 PRs that touch runbook files; confirm the check runs as expected
- [ ] 8.2 Watch any `[skip-runbook-check]` usages in the next month; if frequency > 1/release, file a follow-up to investigate
- [ ] 8.3 If the check produces false positives, file follow-up issues to refine the regexes

## 9. Cross-link with companion changes

- [ ] 9.1 Add a "Related changes" line to the new workflow file commenting that the `[!WARNING]` marker text MUST stay in sync with `opsx-runbook-draft-skill`'s self-disclosure
- [ ] 9.2 Verify the marker text in the spec matches the marker text in `opsx-runbook-draft-skill`'s spec (manually compare both spec files)
