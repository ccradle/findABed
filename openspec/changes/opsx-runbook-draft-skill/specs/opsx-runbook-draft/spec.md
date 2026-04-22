## ADDED Requirements

### Requirement: Skill is invokable as `/opsx:draft-runbook`

The system SHALL provide a Claude `/opsx:` skill named `draft-runbook` accessible via the standard `/opsx:` namespace alongside `apply`, `ff`, `archive`, `verify`, `sync`. The skill SHALL accept an optional version argument (`vX.Y.Z` format) and SHALL prompt for the version via `AskUserQuestion` if not provided.

#### Scenario: Operator invokes with version argument

- **WHEN** the operator runs `/opsx:draft-runbook v0.50.0`
- **THEN** the skill proceeds without prompting

#### Scenario: Operator invokes without argument

- **WHEN** the operator runs `/opsx:draft-runbook`
- **THEN** the skill prompts via `AskUserQuestion`: "What version are you releasing? (e.g. v0.50.0 — bumped from current pom.xml)"
- **AND** waits for response before proceeding

### Requirement: Skill reads repo state for change surface

The skill SHALL read repo state to determine the change surface since the last release:
- `backend/pom.xml` for current version
- `git log v<prev>..HEAD` for commit subjects
- `git diff --name-only v<prev>..HEAD` for changed file paths

The skill SHALL handle the case where `v<prev>` does not exist (no prior tag) by falling back to the most recent commit on `main` minus 50 commits.

#### Scenario: Skill reads pom version

- **WHEN** the skill executes
- **THEN** it parses `backend/pom.xml` and extracts the current `<version>` value
- **AND** uses it to determine `v<prev>` (the most recent git tag matching `vX.Y.Z`)

#### Scenario: Skill handles missing prior tag

- **WHEN** no prior `vX.Y.Z` tag exists
- **THEN** the skill falls back to `git log -50 --format=%H | tail -1` as the comparison anchor
- **AND** notes this in the draft output

### Requirement: Skill walks memory corpus and scores relevance

The skill SHALL walk `~/.claude/projects/<project-id>/memory/` (the user's memory corpus) and score each `feedback_*.md` and `project_*.md` for relevance to the change surface.

Scoring heuristic:
- +5 points: any file path in `git diff --name-only` keyword-matches the memory's filename or `description:` field
- +3 points: any commit message in `git log` keyword-matches the memory's `description:` field
- +1 point: memory `type:` is `feedback` AND any file under deploy-relevant paths (`deploy/`, `docker-compose.yml`, `prometheus*`, `alertmanager*`, `infra/`) was touched

#### Scenario: High-relevance memory is auto-cited

- **WHEN** the change surface includes a `prometheus.yml` edit AND `feedback_bind_mount_inode_pitfall.md` exists with `description:` containing the word "prometheus" or "bind-mount"
- **THEN** the memory scores ≥ 5 (filename-match path) + ≥ 3 (description-match path) = 8
- **AND** is auto-cited in the draft's `consulted:` block with a `# why-cited:` comment naming the matched signal

#### Scenario: Low-relevance memory goes to not-applicable

- **WHEN** a memory scores 1-2
- **THEN** it appears under `not-applicable:` with reason "low relevance score (≤2) — operator review"

#### Scenario: Zero-relevance memory is omitted

- **WHEN** a memory scores 0
- **THEN** it is NOT cited in the main draft
- **BUT** appears in a verbose-mode appendix the operator can request

### Requirement: Skill emits draft to canonical path

The skill SHALL emit the populated draft to `docs/oracle-update-notes-vX.Y.Z.md.draft` (the `.draft` suffix is mandatory, signals intermediate artifact). The skill SHALL NOT auto-commit, auto-stage, or auto-push the draft.

#### Scenario: Draft is written to .draft path

- **WHEN** the skill completes generation
- **THEN** the file `docs/oracle-update-notes-v0.50.0.md.draft` exists
- **AND** no git operations have been performed

#### Scenario: Operator promotes draft to final

- **WHEN** the operator reviews and accepts the draft
- **THEN** they manually `mv docs/oracle-update-notes-v0.50.0.md.draft docs/oracle-update-notes-v0.50.0.md` and commit

### Requirement: Draft includes self-disclosure warning

The draft SHALL begin with a `> [!WARNING]` callout immediately after the title: "This draft is generated. Operator MUST review every citation, every gate, every step before committing. Skill is a starting point, not the finished artifact. Verify every cited memory is still accurate per `feedback_verify_doc_facts_against_source.md`."

The warning SHALL remain in the draft until the operator manually removes it during refinement.

#### Scenario: Generated draft has the warning

- **WHEN** the operator opens a fresh draft from the skill
- **THEN** the second non-empty line of the file is the `> [!WARNING]` callout

#### Scenario: CI rejects committed draft retaining the warning

- **WHEN** an operator forgets to remove the warning and tries to commit `docs/oracle-update-notes-v0.50.0.md` with the warning still present
- **THEN** `ci-runbook-consulted-check` (separate change) flags the violation

### Requirement: Draft anchors against runbook-template-v1

The skill SHALL read `docs/runbook-template.md` at runtime as the source of truth for runbook structure. The draft's section order, mandatory blocks, and matrix rows SHALL exactly match the template; if the template changes, the skill SHALL auto-adapt without requiring a skill update.

#### Scenario: Template change propagates to draft

- **WHEN** `docs/runbook-template.md` adds a new mandatory section between Deploy Steps and Post-Deploy Gates
- **THEN** the next `/opsx:draft-runbook` invocation produces a draft with the new section present in the right position

#### Scenario: Skill fails loud if template missing

- **WHEN** `docs/runbook-template.md` does not exist (e.g. operator on a branch that pre-dates `runbook-template-v1`)
- **THEN** the skill exits with an error message: "runbook template not found at docs/runbook-template.md — merge runbook-template-v1 first"

### Requirement: Service-recreate matrix pre-marked from git diff

The draft's service-recreate matrix SHALL be pre-marked with applicability based on the git diff:
- `prometheus.yml` or `deploy/prometheus/*` changed → prometheus row marked applicable
- `deploy/alertmanager*.tmpl` changed → alertmanager row marked applicable
- ANY backend Java file or `pom.xml` changed → backend↔frontend row marked applicable
- `pgaudit.conf` or `deploy/pgaudit.Dockerfile` changed → postgres row marked applicable
- `nginx*.conf` (in repo, not host) changed → host nginx row marked with note "operator must SSH and run nginx -t / -s reload manually"

#### Scenario: Backend-only change pre-marks frontend

- **WHEN** the change surface includes ONLY backend Java files
- **THEN** the draft's matrix has the backend↔frontend row pre-checked
- **AND** the deploy step skeleton includes `--force-recreate backend frontend` (not just backend)

#### Scenario: No applicable rows

- **WHEN** the change surface includes only docs files (no service-touching changes)
- **THEN** the matrix is present in the draft but no rows are pre-checked
- **AND** the deploy step skeleton notes "no service recreate required for this docs-only release"

### Requirement: Skill is deterministic enough to test

For the same inputs (same `pom.xml`, same `git log`, same memory corpus), the skill SHALL produce structurally-identical drafts (same section order, same memory citations, same matrix markings). Free-text fields (descriptions, comments) MAY vary due to LLM non-determinism but the SKELETON SHALL be reproducible.

#### Scenario: Re-running on same inputs yields same skeleton

- **WHEN** the operator runs `/opsx:draft-runbook v0.50.0` twice in succession against the same git state
- **THEN** the two drafts have identical section headers, identical `consulted:` block entries, identical matrix markings
- **AND** may differ in free-text comments

### Requirement: Skill does not execute commands or modify state

The skill SHALL operate read-only on the repo and memory corpus. It SHALL NOT:
- Execute shell commands (other than the `git log` / `git diff` / `git rev-parse` reads required for change surface analysis)
- Modify any file other than `docs/oracle-update-notes-vX.Y.Z.md.draft`
- Create branches, commits, tags, or PRs
- Hit any external service (no SMTP, no Cloudflare, no ntfy)
- Call other `/opsx:` skills (no nested skill invocations)

#### Scenario: Skill leaves working tree unchanged except for the draft

- **WHEN** the skill completes
- **THEN** `git status` shows ONLY `docs/oracle-update-notes-vX.Y.Z.md.draft` as new/modified
- **AND** no other files in the working tree have been touched
