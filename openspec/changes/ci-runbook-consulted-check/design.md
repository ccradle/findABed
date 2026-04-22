## Context

This change is the third leg of the v0.50 runbook-overhaul triad: `runbook-template-v1` (template) + `opsx-runbook-draft-skill` (auto-populator) + `ci-runbook-consulted-check` (backstop). Skill raises the floor; CI raises the ceiling. Per the warroom proposal, neither alone is sufficient — operators can skip the skill or commit half-baked drafts. The CI check enforces the convention at PR-merge boundary.

External validation (web research):
- `dorny/paths-filter` is the GitHub Actions community standard for path-filtered triggers; native `paths:` filter is simpler when single-check-per-workflow is sufficient
- Atlassian / incident.io: lessons-learned require ENFORCEMENT mechanisms beyond convention; CI is the canonical enforcement layer
- Important caveat: GitHub Actions `paths:` filter has a 300-file diff cap; if a PR touches >300 files the filter may not trigger correctly

Constraints:
- The check MUST be path-filtered — running on every PR is wasteful and creates noise
- The check MUST be a shell script, not a smart linter — the convention is structural, not semantic
- The check MUST be defeatable for legitimate edge cases (e.g. emergency hotfix where the operator skips ceremony deliberately) — `[skip-runbook-check]` PR title token
- The check MUST NOT depend on the operator's per-laptop memory corpus — only on files in the repo

## Goals / Non-Goals

**Goals:**

- A path-filtered GitHub Actions workflow that runs the check ONLY on PRs touching `docs/oracle-update-notes-v*.md` or memory files
- Detect missing `consulted:` block in modified runbooks
- Detect leftover `[!WARNING] generated draft` callout (operator forgot to remove)
- Detect new `feedback_*.md` added in same PR but NOT cited in the modified runbook
- Single PASS/FAIL exit code from the shell script
- Sub-30-second runtime (so the check doesn't slow PRs)
- `[skip-runbook-check]` PR title escape hatch for emergencies
- Compatible with existing `scripts/ci/` conventions (verify-release-gate-pins.sh, etc.)

**Non-Goals:**

- Validate the QUALITY of citations (skill / human review handles this)
- Validate that cited memories are still accurate (out of scope; quarterly memory review)
- Run on every PR (path-filtered)
- Block emergency hotfixes (escape hatch)
- Replace the runbook template enforcement (template lives in docs; check is at CI layer; both are needed)
- Integrate with the rehearsal harness CI gate (that's `phase-f-ci-rehearsal-gate`, separate change, deferred)

## Decisions

**1. Native GitHub Actions `paths:` filter, NOT `dorny/paths-filter`.**

Decision: Use GitHub's built-in `paths:` filter on the workflow's `pull_request:` trigger.

Alternatives considered:
- `dorny/paths-filter` for richer per-job filtering. REJECTED for v1 — overkill for a single-check workflow; adds external action dependency.
- Run on every PR, filter inside the script. REJECTED — wastes CI minutes and adds noise on unrelated PRs.

Trade-off: the 300-file diff cap may misfire on huge PRs. Mitigation: documented in proposal Impact; runbook PRs should be small anyway.

**2. Shell script, not a Node/Python linter.**

Decision: `scripts/ci/check-runbook-consulted-memories.sh` is a portable bash script with `set -euo pipefail`.

Alternatives considered:
- A Node-based markdown linter (e.g. `remark-lint` plugin). REJECTED — heavy dependency for a structural check; bash + grep is sufficient.
- A Python script. REJECTED — the project does not depend on Python; introducing it for one check is overkill.
- A Java/Maven plugin. REJECTED — laughable overkill.

Rationale: shell + grep is the right tool; matches existing `scripts/ci/verify-release-gate-pins.sh` style.

**3. Three structural assertions, in this order.**

Decision: The script runs three checks per modified runbook:
1. Has `consulted:` fenced YAML block (regex match on `^consulted:` after a ` ```yaml` fence)
2. Does NOT have a `> [!WARNING]` callout matching the `opsx-runbook-draft-skill` self-disclosure text
3. If any `feedback_*.md` is added in the same PR (per `git diff --name-only --diff-filter=A`), the new memory is referenced in the runbook's `consulted:` or `not-applicable:` block (substring match on the memory's filename)

Failure on any assertion exits non-zero with a descriptive error message.

**4. Escape hatch via `[skip-runbook-check]` in PR title.**

Decision: If the PR title contains the literal string `[skip-runbook-check]`, the script exits 0 with a warning logged.

Alternatives considered:
- Allow `[skip ci]` (broader skip). REJECTED — too broad; we want runbook-specific opt-out.
- No escape hatch. REJECTED — Marcus would object on operational-flexibility grounds; emergency hotfixes need a path forward.
- Require explicit reviewer approval to bypass. CONSIDERED — adds friction; deferred until escape hatch is shown to be abused.

**5. Single workflow, single job, single step.**

Decision: `.github/workflows/runbook-consulted-check.yml` has ONE job with ONE step that runs the script. No matrix, no parallel jobs, no caching beyond default.

Rationale: simplicity; the script runs in <30 s; complex workflows are harder to debug.

**6. Failure messages point to source-of-truth docs.**

Decision: Every failure message includes a pointer to the relevant doc:
- Missing `consulted:` block → "See docs/runbook-template.md and runbook-template-v1 spec"
- Leftover `[!WARNING]` → "See opsx-runbook-draft-skill — remove the warning before committing"
- Missing memory citation → "Add `<filename>` to the runbook's `consulted:` or `not-applicable:` block"

Rationale: errors must be self-actionable; operator should not need to hunt for context.

## Risks / Trade-offs

- **[300-file diff cap]** — GitHub `paths:` filter may misfire on huge PRs (per web research). Mitigation: documented in proposal; runbook PRs should be small.
- **[Escape hatch abuse]** — operators may use `[skip-runbook-check]` cavalierly. Mitigation: log every use to a tracking artifact (e.g. comment on the PR with "skip-runbook-check used") so the pattern is visible; quarterly review of skip frequency.
- **[False positives on legitimate edge cases]** — a runbook that documents removing a memory file might fail check 3. Mitigation: the script's check 3 only fires on ADDED memories (per `git diff --diff-filter=A`); deleted memories don't trigger.
- **[Marker-text drift between skill and CI]** — the `[!WARNING]` self-disclosure text MUST match between `opsx-runbook-draft-skill` (which writes it) and `ci-runbook-consulted-check` (which detects it). Mitigation: pin the marker text in BOTH spec files (`opsx-runbook-draft` requirement "Draft includes self-disclosure warning" + `runbook-consulted-check` requirement "Detect leftover draft warning"); changing the text requires updating both specs.
- **[Convention rot]** — if `runbook-template-v1` evolves the `consulted:` block format, the regex in this check must update in lockstep. Mitigation: the check's regex is at the top of the script with a comment pointing to `runbook-template-v1` spec; reviewers know to check both.
- **[Runs on per-user memory file PRs]** — `~/.claude/projects/*/memory/*.md` is per-user; if those somehow land in the repo (they shouldn't), the check would trigger inappropriately. Mitigation: gitignore enforcement should already prevent this; the check only triggers on memory files INSIDE the repo if any exist.

## Migration Plan

1. Wait for `runbook-template-v1` to merge first (dependency — needs the `consulted:` convention to exist).
2. `opsx-runbook-draft-skill` SHOULD merge before this check, so the skill's `[!WARNING]` text is pinned and the check can match it. If skill doesn't ship in time, the check still works for assertions 1 and 3 (just skips 2 with a warning).
3. Land the check + workflow in a single PR.
4. First test: open a PR that touches `docs/oracle-update-notes-v0.49.0.md` (the converted v0.49 worked example from `runbook-template-v1`) — confirm the check passes (the worked example has a valid `consulted:` block by design).
5. Negative test: open a test PR that adds a `feedback_*.md` without citing it — confirm the check fails.
6. Document the check in `FOR-DEVELOPERS.md` "Pre-tag rehearsal" subsection (created in `deploy-rehearsal-harness`).

Rollback: delete the workflow file. The script can stay; without the workflow trigger, it's inert.

## Open Questions

- Does the FABT repo already have a `paths:` pattern for `docs/oracle-update-notes-v*.md` in any other workflow? Survey at implementation; reuse the pattern if so.
- Should the check fail or warn on a `[skip-runbook-check]` PR? Decision: warn + log + pass (operator-trust model); revisit if the escape hatch is abused.
- Should the script run locally too (operator pre-commit)? Decision: yes — make it executable from any working dir; document in `FOR-DEVELOPERS.md` as `bash scripts/ci/check-runbook-consulted-memories.sh` for pre-commit verification.
- Does this check need to work on Windows / Git Bash? Decision: yes — the script uses POSIX-portable shell features only (no GNU-specific extensions).
