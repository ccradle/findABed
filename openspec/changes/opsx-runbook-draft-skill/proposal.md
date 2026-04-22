## Why

`runbook-template-v1` defines the canonical structure for `docs/oracle-update-notes-vX.Y.Z.md`, including a mandatory `consulted:` frontmatter block listing every memory file the author reviewed. Authoring that block by hand requires walking the memory corpus (~24 files today, growing) and cross-referencing against the change surface (commits since last release, files touched, services affected). That's tedious enough that operators will cut corners — exactly the failure mode that produced 5 of the 10 v0.49 issues. We need tooling that pre-populates the runbook draft from the memory corpus + git log + pom bump, so the operator edits from a relevant starting point rather than authoring fresh from recollection.

This change ships a `/opsx:` skill (one of the existing project skill family — `/opsx:apply`, `/opsx:ff`, `/opsx:archive`, `/opsx:verify`, `/opsx:sync`) — `/opsx:draft-runbook`. It runs in Claude conversations, reads repo state + memory, and emits `docs/oracle-update-notes-vX.Y.Z.md.draft` for the operator to refine.

## What Changes

- **NEW skill at `.claude/skills/opsx/draft-runbook.md`** (or wherever the existing `/opsx:` skills live — discovery in design.md) — implements the `/opsx:draft-runbook` command, taking optional `vX.Y.Z` argument and emitting a populated draft.
- **Skill behavior**:
  - Reads `backend/pom.xml` for current version
  - Reads `git log v<prev>..HEAD` for commit surface
  - Reads `git diff --name-only v<prev>..HEAD` for the file change surface
  - Walks `~/.claude/projects/.../memory/` and scores each `feedback_*.md` and `project_*.md` for relevance to the change surface (heuristic: file-path keyword match, plus YAML frontmatter `description:` keyword match against commit messages)
  - Emits `docs/oracle-update-notes-vX.Y.Z.md.draft` populated with: (a) the canonical template structure (per `runbook-template-v1`), (b) the `consulted:` block pre-populated with relevance-scored memories + `# why-cited:` comments, (c) the service-recreate matrix with applicable rows pre-checked based on git diff (e.g. if `prometheus.yml` changed, prometheus row is pre-marked applicable), (d) skeleton deploy steps based on the previous release's runbook + the change surface diff
- **The operator EDITS the draft** — does not commit it as-is. The draft is a starting point, not the finished artifact. The skill is explicit about this in its output.

## Capabilities

### New Capabilities

- `opsx-runbook-draft`: A Claude `/opsx:` skill that generates a pre-populated `docs/oracle-update-notes-vX.Y.Z.md.draft` from repo state (pom version, git log, file diff since last release) + memory corpus (relevance-scored citations). Anchors against `runbook-template-v1` for structure. Operator refines the draft into the final runbook.

### Modified Capabilities

(none — net-new skill; depends on `runbook-template-v1` being merged first so the template path + structure exist)

## Impact

- **New file:** `.claude/skills/opsx/draft-runbook.md` (or equivalent path per project skill convention; ~100-200 lines markdown defining the skill)
- **No code changes** in repo (skills are markdown definitions consumed by Claude)
- **No CI/build/deploy changes**
- **Memory corpus dependency:** the skill reads `~/.claude/projects/.../memory/` which is per-user; authors on different operator laptops will have slightly different memory corpora. The skill SHALL handle this gracefully (warn, not fail).
- **Enables:** `ci-runbook-consulted-check` (separate change) — together they form the layered defense (skill raises floor, CI raises ceiling).
- **Risk:** the skill confidently cites stale memories if the corpus is not curated. Mitigation: skill output includes a "TODO operator: re-verify each citation against current state" reminder; quarterly memory-review pass is tracked separately.
