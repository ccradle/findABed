## ADDED Requirements

### Requirement: Path-filtered CI workflow

The system SHALL provide a GitHub Actions workflow at `.github/workflows/runbook-consulted-check.yml` that triggers ONLY on PRs touching `docs/oracle-update-notes-v*.md` files (using the native `paths:` filter on the `pull_request:` trigger). The workflow SHALL run a single job with a single step invoking `scripts/ci/check-runbook-consulted-memories.sh`.

#### Scenario: PR touching a runbook triggers the workflow

- **WHEN** a PR modifies `docs/oracle-update-notes-v0.50.0.md`
- **THEN** the `runbook-consulted-check` workflow runs
- **AND** the script's exit code is the workflow's pass/fail signal

#### Scenario: PR not touching runbooks does NOT trigger

- **WHEN** a PR modifies only `frontend/src/App.tsx`
- **THEN** the `runbook-consulted-check` workflow does NOT trigger
- **AND** no CI minutes are consumed by it

### Requirement: Detect missing consulted block

The check SHALL fail with a clear error message if any modified `docs/oracle-update-notes-v*.md` file does NOT contain a `consulted:` fenced YAML block. The error message SHALL point to `docs/runbook-template.md` and the `runbook-template-v1` spec.

#### Scenario: Missing consulted block fails

- **WHEN** a PR modifies `docs/oracle-update-notes-v0.50.0.md` and the file does NOT contain a line matching `^consulted:` inside a fenced ` ```yaml ` block
- **THEN** the check exits non-zero
- **AND** the error message reads: "FAIL: docs/oracle-update-notes-v0.50.0.md missing `consulted:` block. See docs/runbook-template.md and runbook-template-v1 spec."

#### Scenario: Present consulted block passes

- **WHEN** the modified runbook contains a properly-formed `consulted:` block
- **THEN** this assertion passes; subsequent assertions still run

### Requirement: Detect leftover draft warning

The check SHALL fail if any modified runbook contains the `> [!WARNING]` self-disclosure callout that `opsx-runbook-draft-skill` writes (matched by the literal substring `This draft is generated`). This catches the case where the operator commits the skill's output without removing the warning.

#### Scenario: Leftover warning fails

- **WHEN** a runbook contains a line matching `^> \[!WARNING\]` AND the next line contains `This draft is generated`
- **THEN** the check exits non-zero with message: "FAIL: docs/oracle-update-notes-v0.50.0.md still contains the [!WARNING] generated-draft callout. Remove the warning before committing — see opsx-runbook-draft-skill."

#### Scenario: No warning passes

- **WHEN** the runbook does NOT contain the warning text
- **THEN** this assertion passes

### Requirement: Detect uncited new memory files

The check SHALL fail if a PR adds any new `feedback_*.md` file (under any path the PR touches that includes `feedback_*.md`) AND the modified runbook does NOT reference the new file by name in either its `consulted:` or `not-applicable:` block.

#### Scenario: New memory file uncited fails

- **WHEN** a PR adds `feedback_v050_new_lesson.md` AND modifies `docs/oracle-update-notes-v0.50.0.md` AND the runbook does NOT contain the substring `feedback_v050_new_lesson.md`
- **THEN** the check exits non-zero with message: "FAIL: feedback_v050_new_lesson.md added in this PR but not cited in docs/oracle-update-notes-v0.50.0.md. Add it to the runbook's `consulted:` or `not-applicable:` block."

#### Scenario: New memory file cited passes

- **WHEN** the PR adds a memory file AND the runbook contains the file's name (substring match) anywhere in the document
- **THEN** this assertion passes

#### Scenario: Memory file deletion does NOT trigger

- **WHEN** the PR removes a `feedback_*.md` file (rather than adding) — captured via `git diff --diff-filter=A` for added-only
- **THEN** the check does NOT require the deletion to be cited in the runbook

#### Scenario: Memory file added without runbook change

- **WHEN** the PR adds `feedback_*.md` but does NOT modify any runbook file
- **THEN** the check does NOT trigger (no runbook touched, nothing to assert)

### Requirement: Escape hatch via PR title token

The check SHALL accept a `[skip-runbook-check]` literal substring in the PR title as an opt-out. When present, the check SHALL exit 0 with a warning logged.

#### Scenario: PR title with skip token bypasses check

- **WHEN** the PR title contains `[skip-runbook-check]` (e.g. "fix: emergency hotfix [skip-runbook-check]")
- **THEN** the check exits 0
- **AND** prints "WARN: skip-runbook-check used; bypass logged for review"

#### Scenario: Skip token is logged for tracking

- **WHEN** the skip token is used
- **THEN** the workflow output preserves the PR title + skip-token detection
- **AND** the artifact can be queried for skip-frequency review

### Requirement: Failure messages are self-actionable

Every failure message SHALL include: (a) the offending file path, (b) the failed assertion in plain language, (c) a pointer to the source-of-truth doc or spec the operator should consult.

#### Scenario: Failure points to template

- **WHEN** the check fails on missing `consulted:` block
- **THEN** the error message includes: filename, "missing consulted: block", AND a pointer to `docs/runbook-template.md` and the `runbook-template-v1` spec

#### Scenario: Failure points to skill

- **WHEN** the check fails on leftover warning
- **THEN** the error message includes: filename, "still contains [!WARNING]", AND a pointer to `opsx-runbook-draft-skill` for context on why the warning exists

#### Scenario: Failure points to citation requirement

- **WHEN** the check fails on uncited new memory
- **THEN** the error message includes: the new memory's filename, the runbook's filename, AND the suggested fix ("add to consulted: or not-applicable: block")

### Requirement: Single PASS/FAIL exit code

The check script SHALL exit 0 on full success or non-zero on any failed assertion. The workflow SHALL surface the exit code as the PR check status.

#### Scenario: All assertions pass

- **WHEN** all 3 assertions pass
- **THEN** the script exits 0
- **AND** prints "PASS: all runbook checks ok"

#### Scenario: Any assertion fails

- **WHEN** any single assertion fails
- **THEN** the script exits non-zero with the specific failure message
- **AND** the workflow PR check shows red

### Requirement: Local pre-commit invocation

The check script SHALL be runnable locally by operators (pre-commit) by invoking `bash scripts/ci/check-runbook-consulted-memories.sh` from the repo root. The script SHALL detect when run locally vs in CI (via `$CI` env var) and adapt error message formatting accordingly.

#### Scenario: Operator runs check locally

- **WHEN** an operator runs `bash scripts/ci/check-runbook-consulted-memories.sh` from the repo root before committing
- **THEN** the script computes diff against `origin/main` (rather than CI's `${{ github.event.pull_request.base.sha }}`)
- **AND** produces the same PASS/FAIL output as CI would

#### Scenario: Script handles dirty working tree

- **WHEN** the operator has uncommitted changes
- **THEN** the script considers both committed and uncommitted modifications to runbook files (rather than only committed)
- **AND** runs the same assertions

### Requirement: POSIX-portable shell (Windows compatibility)

The check script SHALL use POSIX-portable shell features only — no GNU-specific extensions, no bashisms beyond `set -euo pipefail`, no GNU `awk`-only features. This ensures the script runs on operator's Windows + Git Bash environment per `feedback_windows_taskkill.md`.

#### Scenario: Script runs on Windows + Git Bash

- **WHEN** the operator runs the script on Windows in Git Bash
- **THEN** all assertions execute correctly
- **AND** path handling uses forward slashes (POSIX), not backslashes
