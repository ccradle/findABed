## Why

`runbook-template-v1` defines the `consulted:` frontmatter convention; `opsx-runbook-draft-skill` pre-populates it for the operator. Together they raise the floor — operators START with a populated draft. But the operator can still: (a) skip the skill entirely and hand-author from recollection (reverting to the v0.49 failure mode); (b) accept the draft but commit it WITHOUT removing the `[!WARNING] generated draft` self-disclosure (committing a half-baked artifact); (c) add a new `feedback_*.md` memory in the same PR but forget to cite it in the runbook (the lesson lands in memory but never enters a runbook); (d) drop relevant memories the skill cited because they "looked tedious" rather than refining `# why-cited:` reasons.

A backstop CI check raises the ceiling: PRs that touch `docs/oracle-update-notes-v*.md` or add `feedback_*.md` MUST satisfy a small set of structural assertions. The check is a shell script, not a smart linter — Atlassian/incident.io research confirms that "lessons must propagate to runbooks with named ownership" and a CI-enforced convention is the standard pattern.

## What Changes

- **NEW `scripts/ci/check-runbook-consulted-memories.sh`** — shell script that:
  1. Detects PR-touched files via `git diff --name-only origin/main...HEAD`
  2. If any `docs/oracle-update-notes-v*.md` is touched, asserts the file contains the canonical `consulted:` fenced YAML block (regex match)
  3. If the file does NOT contain a `consulted:` block, fails the PR with a message pointing to `runbook-template-v1` and `/opsx:draft-runbook`
  4. If the file contains a `> [!WARNING]` callout matching the skill's self-disclosure text, fails the PR (operator forgot to remove the draft warning)
  5. If any `feedback_*.md` is added in the same PR AND a runbook is also touched, asserts the new feedback file is referenced in the runbook's `consulted:` or `not-applicable:` block
  6. If a runbook is touched but no `feedback_*.md` is added, only checks (2)+(4); does not require new memory citations
- **NEW GitHub Actions workflow** at `.github/workflows/runbook-consulted-check.yml` — path-filtered to trigger ONLY on PRs touching `docs/oracle-update-notes-v*.md` or `~/.claude/projects/*/memory/*.md` (per `dorny/paths-filter` pattern from web research; native `paths:` filter is sufficient for this single check)
- **Modified `scripts/ci/verify-release-gate-pins.sh`** — minor, only if the new check needs to integrate (likely not; the new check is independent)

## Capabilities

### New Capabilities

- `runbook-consulted-check`: A path-filtered CI check that enforces the `consulted:` frontmatter convention from `runbook-template-v1`. Catches the failure modes that skill + template alone don't catch — operator skipping skill, committing draft warnings, adding memories without citing them. Backstop, not floor; raises the ceiling.

### Modified Capabilities

(none — net-new CI check; depends on `runbook-template-v1` for the `consulted:` convention to exist)

## Impact

- **New files:** `scripts/ci/check-runbook-consulted-memories.sh` (~80-150 lines bash), `.github/workflows/runbook-consulted-check.yml` (~30 lines yaml)
- **Modified files:** none expected (the check is self-contained)
- **CI cost:** path-filtered, runs in <30 s when triggered, only on PRs touching runbook files OR memory files. At FABT's release cadence (~1-3 PRs/week touching these files), CI minutes cost is negligible.
- **No production impact** — purely PR-time validation; does not deploy, build, or modify state
- **Failure mode:** if the check is too strict, operators get blocked at PR-time; mitigation is `[skip-runbook-check]` PR-title escape hatch (rare; documented in the script).
- **GitHub Actions 300-file diff cap caveat** (per web research) — for very large PRs, `paths:` filter may misfire; mitigation is to keep runbook PRs small and isolated (good practice anyway).
