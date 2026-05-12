---
name: opsx-runbook-draft
description: Generate a populated `docs/oracle-update-notes-vX.Y.Z.md.draft` for a release tag, anchored against `docs/runbook-template.md` and pre-filled with the canonical `consulted:` memory citations + a service-recreate matrix marked from `git diff`. The operator REFINES the draft into the final runbook — never commits the draft as-is. Use when starting a new release runbook so authoring begins from a relevant skeleton, not blank-page recall.
license: MIT
metadata:
  author: opsx-runbook-draft-skill OpenSpec change
  version: "1.0"
  source: openspec/changes/opsx-runbook-draft-skill/
---

Generate a populated runbook draft from current repo state + the user's memory corpus, anchored to `docs/runbook-template.md`. The operator refines the draft, then `mv`s it to drop the `.draft` suffix once it reflects reality.

> **Drafting principle.** This skill produces a STARTING POINT, not a finished artifact. Every citation in `consulted:` must be re-verified against current code/state; every line in the deploy steps must be ground-truthed against the live VM (per `feedback_runbook_groundtruth_vm.md`); every assertion in §6 post-deploy gates must match shipped behavior. A draft committed without that refinement is the v0.49-class incident in waiting.

## Input

The `/opsx-runbook-draft` invocation accepts an optional `vX.Y.Z` argument naming the upcoming release. Examples:

- `/opsx-runbook-draft v0.57.3` → emits `docs/oracle-update-notes-v0.57.3.md.draft`
- `/opsx-runbook-draft` → reads `backend/pom.xml` to infer the current pom version; if it's already bumped (e.g. pom shows `0.57.3` while latest tag is `v0.57.2`), use that; otherwise prompt via AskUserQuestion

## Steps

1. **Resolve the target version + previous tag**
   - Parse the argument if provided; else read `backend/pom.xml` line `^    <version>` for the inferred target
   - Run `git tag --list 'v*' --sort=-v:refname | head -1` to identify the previous tag (used for diff windows)
   - State both back to the operator: "Drafting `vX.Y.Z` from `vA.B.C` → diff window covers `<commit-count>` commits across `<file-count>` files"

2. **Read the canonical template**
   - Read `docs/runbook-template.md`. If absent, fail loud — the skill MUST anchor against the template
   - Extract the 8 mandatory section headings (verbatim) so the draft section order is correct
   - Note any release-class guidance in the template (e.g. "if this is a backend-only patch, frontend recreate-only is sufficient")

3. **Survey the change surface from git**
   - `git log v<prev>..HEAD --format='%h %s' --no-merges` → commit subject list (used for change-summary paragraph + relevance scoring)
   - `git diff --name-only v<prev>..HEAD` → file change set (used to mark service-recreate matrix rows + identify ops-relevant memories)
   - Detect class:
     - Has a `pom.xml` line change with a `<version>` bump? → backend-code class
     - Has changes under `frontend/src/` or `frontend/public/`? → frontend rebuild required
     - Has changes under `backend/src/main/resources/db/migration/`? → Flyway migrations to call out
     - Has changes under `infra/docker/`? → Dockerfile rebuild required
     - Has changes under `~/fabt-secrets/` mirrors (`deploy/rehearsal-prod-overlay.yml`, `deploy/rehearsal.env.example`)? → flag for env-passthrough verification

4. **Walk the memory corpus and score relevance**
   - List files in the user's memory directory (`~/.claude/projects/<project-id>/memory/` — discover from current session context). If the path is unavailable (operator-laptop variance), warn and skip relevance scoring; still emit a draft with a NOTE that the `consulted:` block is empty and operator must populate.
   - For each `feedback_*.md` and `project_*.md`:
     - Read the YAML frontmatter `description:` field
     - Score relevance:
       - **Score +3** if the memory's `description` contains a keyword that matches a directory name in the file change set (e.g. memory mentions `notification` and a file under `backend/src/main/java/org/fabt/notification/` was touched)
       - **Score +2** if a commit subject mentions a keyword that matches the memory's frontmatter `description`
       - **Score +1** if the memory file name contains tokens like `deploy`, `runbook`, `rehearsal`, `prod` (always-applicable for any release runbook)
       - **Score 0** otherwise
   - Bucket the results:
     - **Score ≥3** → include in `consulted:` with a `# why-cited:` comment derived from the matching keyword
     - **Score 1-2** → include as `not-applicable: <heuristic match but unclear if applies>` so operator can confirm or remove
     - **Score 0** → omit

5. **Mark the service-recreate matrix from the file diff**
   - For each row in the template's §3 matrix, evaluate whether the file change set warrants a `Changed? ☑` mark:
     - `backend + frontend` row: ☑ if any backend Java code or frontend source changed
     - `prometheus` row: ☑ if `prometheus.yml` or `deploy/prometheus/` changed
     - `alertmanager` row: ☑ if `alertmanager.yml.tmpl` or related changed
     - `postgres` row: ☑ if `pgaudit.conf` or related changed
     - Host nginx row: ☑ if `infra/nginx/` changed
   - Pre-mark the matrix in the draft; operator reviews + un-marks any false positives

6. **Inherit deploy-step skeleton from previous release**
   - Read the previous release's runbook at `docs/oracle-update-notes-v<prev>.md` (if it exists)
   - Copy §5 deploy steps as the skeleton, replacing every `vA.B.C` and `vX.Y.W` reference with the current target version
   - Note in the draft preamble: "Steps inherited from v<prev>. Adjust for any new env vars, new compose overrides, or new pre-deploy gates introduced by this release."

7. **Emit the draft**
   - Path: `docs/oracle-update-notes-vX.Y.Z.md.draft` (the `.draft` suffix is what `ci-runbook-consulted-check` detects to refuse merge)
   - First section: a `> [!WARNING]` callout with the EXACT marker text the CI check expects:
     ```
     > [!WARNING]
     > **This draft is generated** by `/opsx-runbook-draft`. Refine every citation
     > and every gate before committing. Remove this warning callout once the
     > runbook is reviewer-ready. The CI check `ci-runbook-consulted-check` will
     > refuse to merge a runbook that still contains this warning.
     ```
   - Then the canonical 8 sections from the template, populated per steps 4-6
   - Final operator-facing line in the skill output: "Draft written to `docs/oracle-update-notes-vX.Y.Z.md.draft`. Review every citation, every gate, every step before committing. Refine, then `mv` to drop `.draft`."

## Constraints

- **Read-only on memory** — the skill walks memory but never writes to it
- **Single write target** — the only file the skill writes is `docs/oracle-update-notes-vX.Y.Z.md.draft`. No CHANGELOG edits, no pom edits, no compose edits
- **No subprocess deploys** — the skill does not run `mvn`, `docker`, `gh`, or any deploy-affecting command. It only reads via `git log`, `git diff`, `git tag`, `git rev-parse`
- **Fail loud on missing template** — if `docs/runbook-template.md` is absent, abort with an error pointing to `runbook-template-v1`
- **Memory corpus may be absent** — operator-laptop variance means the memory directory may not exist (different operator, fresh checkout). Warn and emit a draft with empty `consulted:` block + note saying "populate from `docs/runbook-memory-index.md`"

## Output format

Brief operator-facing summary at the end of skill execution:

```
✓ Drafted docs/oracle-update-notes-vX.Y.Z.md.draft

Diff window: vA.B.C..HEAD (N commits, M files)
Release class: <backend-only | frontend-only | full | ops-only>
Memories scored: K cited, L marked not-applicable, total scanned P
Service-recreate matrix: rows pre-marked: <list>

NEXT: refine the draft. The CI check will refuse merge while the
[!WARNING] callout is present. Drop the .draft suffix when ready.
```

## Why this skill exists

`runbook-template-v1` defines the canonical structure but authoring from scratch every release reverts operators to recall-mode — exactly the failure that produced 5 of the 10 v0.49 incidents. A pre-populated draft moves the cognitive cost from "what should this section say?" to "is this draft right?", which is bounded review work even on a stressful day. The CI companion (`ci-runbook-consulted-check`) raises the ceiling: even an operator who skips this skill must satisfy the structural assertions before merge.

Reference: `openspec/changes/opsx-runbook-draft-skill/proposal.md` for the design intent. `feedback_verify_doc_facts_against_source.md` for the citation-accuracy discipline that operators must apply when refining the draft.
