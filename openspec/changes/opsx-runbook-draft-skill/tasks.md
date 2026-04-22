## 1. Setup

- [ ] 1.1 Confirm `runbook-template-v1` is merged to main BEFORE starting this change (hard dependency — skill needs the template to exist)
- [ ] 1.2 Create feature branch `feature/opsx-runbook-draft-skill` from `main` (per `feedback_branch_in_tasks.md`)
- [ ] 1.3 Survey current `/opsx:` skill location: read one of the existing skills (e.g. `/opsx:apply`) to identify the skill-file path convention; the new skill MUST live in the same location

## 2. Author the skill definition

- [ ] 2.1 Create the new skill file at the discovered `/opsx:` path with name `draft-runbook` (e.g. `~/.claude/projects/<id>/skills/opsx/draft-runbook.md` or `.claude/skills/opsx/draft-runbook.md` per project convention)
- [ ] 2.2 Define the skill's frontmatter: name, description ("Generate a populated runbook draft from repo state + memory corpus"), allowed tools (Read, Bash for git commands, Write to `.md.draft` only)
- [ ] 2.3 Implement skill step 1: parse optional `vX.Y.Z` argument; if missing, prompt via `AskUserQuestion`
- [ ] 2.4 Implement skill step 2: read `backend/pom.xml` for current version, derive `v<prev>` via `git tag --list 'v*' --sort=-v:refname | head -1`
- [ ] 2.5 Implement skill step 3: read `git log v<prev>..HEAD --format=%s` for commit subjects, `git diff --name-only v<prev>..HEAD` for changed files
- [ ] 2.6 Implement skill step 4: walk `~/.claude/projects/<id>/memory/` (or wherever the user's memory corpus lives — discovery in design.md), read every `feedback_*.md` and `project_*.md` frontmatter `description:` per spec requirement "Skill walks memory corpus and scores relevance"
- [ ] 2.7 Implement skill step 5: relevance scoring per spec requirement "Skill walks memory corpus and scores relevance" (score ≥3 = `consulted:`, score 1-2 = `not-applicable:`, score 0 = omitted)
- [ ] 2.8 Implement skill step 6: read `docs/runbook-template.md` for canonical structure; if missing, fail loud per spec requirement "Draft anchors against runbook-template-v1"
- [ ] 2.9 Implement skill step 7: emit draft to `docs/oracle-update-notes-vX.Y.Z.md.draft` with: (a) the `[!WARNING]` self-disclosure per spec requirement "Draft includes self-disclosure warning"; (b) populated `consulted:` block; (c) service-recreate matrix with rows pre-marked from git diff per spec requirement "Service-recreate matrix pre-marked from git diff"; (d) skeleton sections inheriting from previous release runbook + adapting to current change surface
- [ ] 2.10 Implement skill step 8: print summary to operator: "Draft written to docs/oracle-update-notes-vX.Y.Z.md.draft. Review every citation, every gate, every step before committing. Refine, then `mv` to drop `.draft` suffix."
- [ ] 2.11 Verify skill is read-only per spec requirement "Skill does not execute commands or modify state": only `git log`/`git diff`/`git rev-parse`/`git tag` reads + Read on memory files + Write to the single `.draft` file

## 3. Verify the skill works against current state

- [ ] 3.1 Run `/opsx:draft-runbook v0.50.0` against current main (assuming `runbook-template-v1` merged) — expect a draft at `docs/oracle-update-notes-v0.50.0.md.draft`
- [ ] 3.2 Manually inspect the draft: section order matches template, `consulted:` block is populated with non-zero entries, service-recreate matrix has rows marked appropriate to the change surface
- [ ] 3.3 Run `/opsx:draft-runbook v0.50.0` a SECOND time without changing state — confirm structurally-identical output per spec requirement "Skill is deterministic enough to test" (free-text comments may vary; skeleton must match)
- [ ] 3.4 Intentionally modify `docs/runbook-template.md` to add a new mandatory section, re-run — confirm draft auto-adapts per spec requirement "Template change propagates to draft"
- [ ] 3.5 Intentionally rename `docs/runbook-template.md` away → re-run → confirm fail-loud per spec requirement "Skill fails loud if template missing"
- [ ] 3.6 Confirm `git status` after skill runs shows ONLY the `.draft` file as new — no other working tree changes per spec requirement "Skill leaves working tree unchanged except for the draft"

## 4. Update FOR-DEVELOPERS.md

- [ ] 4.1 Add to "Pre-tag rehearsal" subsection (created in `deploy-rehearsal-harness` change): "Before authoring the runbook by hand, run `/opsx:draft-runbook` for a starting point. The draft is generated; review every citation against current repo state per `feedback_verify_doc_facts_against_source.md` before committing."
- [ ] 4.2 Add a one-line entry to the runbook-related section of FOR-DEVELOPERS pointing to the skill

## 5. Cross-link with companion changes

- [ ] 5.1 Update `docs/runbook-template.md` (from `runbook-template-v1`) to mention the skill in the "Related changes" footer if not already
- [ ] 5.2 Verify the `[!WARNING]` self-disclosure callout text in the skill matches what `ci-runbook-consulted-check` expects to detect (the CI check rejects committed runbooks that still contain the warning — the marker text MUST match)

## 6. Commit + ship

- [ ] 6.1 Stage skill file + FOR-DEVELOPERS.md modification
- [ ] 6.2 Commit with conventional message: `feat(opsx): /opsx:draft-runbook skill — auto-populate runbook draft from memory + git state`
- [ ] 6.3 Push, open PR, wait for CI green per `feedback_release_after_scans.md`
- [ ] 6.4 Merge to main; this change is tooling, no version bump, no deploy

## 7. Post-merge — use it for v0.50

- [ ] 7.1 Operator uses `/opsx:draft-runbook v0.50.0` for the next release
- [ ] 7.2 Note any cases where skill cited a memory the operator dropped, OR omitted a memory the operator added — accumulate as relevance-heuristic tuning data
- [ ] 7.3 After 2 releases, review the relevance-heuristic effectiveness — if operators are still hand-citing memories the skill missed in >30% of cases, file a follow-up to tune the heuristic
