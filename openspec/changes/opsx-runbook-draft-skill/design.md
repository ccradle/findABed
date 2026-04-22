## Context

FABT uses Claude Code as the primary deploy author + executor. The project has 5 existing `/opsx:` skills (`apply`, `ff`, `archive`, `verify`, `sync`) for OpenSpec change lifecycle. We add a 6th: `/opsx:draft-runbook`. The skill consumes the canonical template from `runbook-template-v1` (must merge first) and the user's memory corpus at `~/.claude/projects/<project-id>/memory/`.

The user's memory corpus is per-laptop, indexed by `MEMORY.md` at the corpus root. Existing entries (~24 deploy-relevant `feedback_*.md` plus several `project_*.md`) carry YAML frontmatter with `name`, `description`, `type`. The `description` field is a 1-line summary suitable for relevance scoring.

External validation (web research):
- Atlassian / incident.io: lessons-learned must be CONNECTED to next runbook with named ownership; the skill IS the connection mechanism for FABT
- Mem.ai patterns: AI-assisted runbook drafting from prior runbooks + lessons learned is a recognized pattern in 2026
- DZone / TechTarget: runbook templates evolve as institutional learning accumulates; tooling should pull lessons forward, not require manual recall

Constraints:
- Must NOT execute commands (skill is in Claude conversation, not CI); operator-driven
- Must work across operator-laptop variation (different memory corpora)
- Must NOT auto-commit the draft — operator reviews and refines
- Must produce DETERMINISTIC output for the same inputs (so the skill is testable)
- Must respect `feedback_verify_doc_facts_against_source.md` — the skill should NOT invent rule names, slugs, table counts; it should cite from source files (pom.xml, git log) only

## Goals / Non-Goals

**Goals:**

- A `/opsx:draft-runbook vX.Y.Z` skill that produces `docs/oracle-update-notes-vX.Y.Z.md.draft`
- Pre-populated `consulted:` frontmatter block with relevance-scored memory citations + `# why-cited:` comments
- Pre-populated service-recreate matrix with applicable rows pre-marked based on git diff
- Skeleton deploy steps inheriting from previous release's structure + adapting to current change surface
- Honest output: the draft prints "OPERATOR: review and edit before committing" prominently
- Compatible with `runbook-template-v1` structure exactly (no template drift)

**Non-Goals:**

- Auto-commit or auto-PR the draft — strictly operator-driven
- Replace human authoring — skill provides STARTING POINT, not finished artifact
- Validate the operator's edits against the template — that's `ci-runbook-consulted-check`
- Run any commands on the VM, deploy, or stage anything — purely a doc-generation skill
- Re-rank or curate the memory corpus — skill reads what's there; quarterly memory-review is a separate concern
- Integrate with non-Claude tooling (e.g. CLI generation outside Claude Code) — Claude-conversation only for v1

## Decisions

**1. Skill lives at the FABT project's `/opsx:` skill location.**

Decision: Add the new skill alongside `apply`, `ff`, `archive`, `verify`, `sync` — wherever those live in the project's skill configuration. Survey on implementation; likely `~/.claude/projects/<project>/skills/opsx/` or a project-level `.claude/skills/opsx/` directory.

Alternatives considered:
- A standalone non-`opsx:` skill (e.g. `/draft-runbook`). REJECTED — breaks the namespace pattern; operators have muscle memory around `/opsx:`.
- Embed in an existing skill (e.g. extend `/opsx:apply`). REJECTED — `/opsx:apply` is for OpenSpec change implementation, not deploy doc generation; conflating violates SRP.

**2. Relevance-scoring heuristic — file-path keyword match + frontmatter description match.**

Decision: For each memory file, compute a relevance score against the change surface:
- +5 points if any file path in `git diff --name-only v<prev>..HEAD` keyword-matches the memory's filename or `description` field
- +3 points if any commit message in `git log v<prev>..HEAD` keyword-matches `description`
- +1 point if memory `type:` is `feedback` AND any file under `deploy/`, `docker-compose.yml`, `prometheus*`, `alertmanager*`, or `infra/` was touched (deploy-relevance baseline)

Memories scoring ≥ 3 get auto-cited in the `consulted:` block; memories scoring 1-2 get auto-cited under `not-applicable:` with reason "low relevance score — operator review"; memories scoring 0 are omitted but listed in a verbose-mode appendix.

Alternatives considered:
- LLM-based relevance scoring (Claude itself ranks memories). PARTIAL — the skill IS Claude; the skill prompt asks Claude to score. Trade-off: scoring is non-deterministic. ACCEPTED — emit "operator review" wording so non-determinism is visible.
- Cite ALL memories. REJECTED — defeats the purpose; operator drowns in noise.
- Cite only HIGHEST-scoring memory. REJECTED — under-cites; operator misses adjacent lessons.

**3. Service-recreate matrix is pre-marked from git diff.**

Decision: The skill examines `git diff --name-only v<prev>..HEAD` and pre-checks rows in the matrix:
- `prometheus.yml` or `deploy/prometheus/*` changed → prometheus row pre-marked applicable
- `deploy/alertmanager*.tmpl` changed → alertmanager row pre-marked applicable
- ANY backend Java file or `pom.xml` changed → backend↔frontend row pre-marked applicable (per matrix row a — backend recreate triggers frontend recreate)
- `pgaudit.conf` or `deploy/pgaudit.Dockerfile` changed → postgres row pre-marked applicable
- `nginx*.conf` (in repo, not host) changed → host nginx row pre-marked with note "operator must SSH and run nginx -t / -s reload manually"

**4. Honest non-determinism disclaimer in skill output.**

Decision: The draft's first line after the title MUST be a `> [!WARNING]` callout: "This draft is generated; operator MUST review every citation, every gate, every step before committing. Skill is a starting point, not the finished artifact. Verify every cited memory is still accurate per `feedback_verify_doc_facts_against_source.md`."

Rationale: `feedback_verify_doc_facts_against_source.md` was created during v0.49 specifically because Claude (me) hallucinated tenant slugs and rule names. The skill MUST self-disclose its non-determinism so the operator doesn't trust it blindly.

**5. Skill prompts for the new release version if not provided.**

Decision: `/opsx:draft-runbook` with no argument prompts via `AskUserQuestion`: "What version are you releasing? (e.g. v0.50.0 — bumped from current pom.xml)". `/opsx:draft-runbook v0.50.0` skips the prompt.

**6. Output is `.draft` — not the final filename.**

Decision: Skill writes to `docs/oracle-update-notes-vX.Y.Z.md.draft`. Operator reviews + renames to `.md` (drops the `.draft` suffix) when satisfied. The `.draft` extension is a clear signal that this is an intermediate artifact.

Alternatives considered:
- Write directly to `.md`. REJECTED — too easy to commit accidentally.
- Write to a sidecar dir. REJECTED — adds path complexity.

## Risks / Trade-offs

- **[Hallucinated content in draft]** — the skill is Claude; Claude can hallucinate. Mitigation: explicit disclaimer (decision 4); operator review is mandatory; the `consulted:` block is the operator's checkpoint to verify.
- **[Memory corpus drift]** — skill cites a memory file that encodes a no-longer-true fact. Mitigation: each citation includes a `# why-cited:` comment explaining the operator's responsibility to verify; quarterly memory-review pass (separate concern) keeps the corpus fresh.
- **[Operator commits the .draft as-is]** — defeats the purpose of "review and refine." Mitigation: `ci-runbook-consulted-check` (separate change) MAY enforce that no committed runbook still has the `[!WARNING] generated draft` marker.
- **[Per-laptop memory variance]** — operator A and operator B may have different memory corpora; the skill produces different drafts on different laptops. Mitigation: this is a feature, not a bug — each operator brings their own learning to the draft. For consistency, the project's authoritative memory snapshots could be exported via `MEMORY.md` (already done) and operators sync occasionally. Out of scope for v1.
- **[Skill versioning]** — when the template at `runbook-template-v1` evolves, the skill's output structure must update in lockstep. Mitigation: the skill reads `docs/runbook-template.md` at runtime as the SOURCE OF TRUTH for structure, rather than encoding the structure inline. If the template changes, the skill auto-adapts.

## Migration Plan

1. Wait for `runbook-template-v1` to merge first (hard dependency — the skill needs the template to exist).
2. Land the skill definition at the `/opsx:` skill location.
3. Operator runs `/opsx:draft-runbook v0.50.0` for the next release; reviews the output; refines into the final runbook.
4. Document in `FOR-DEVELOPERS.md` "Pre-tag rehearsal" subsection: "Before authoring the runbook by hand, run `/opsx:draft-runbook` for a starting point."
5. After 2 release cycles using the skill, evaluate: are operators still hand-citing memories the skill missed? If yes, tune the relevance heuristic.

Rollback: delete the skill file. The runbook template + manual authoring still works without the skill.

## Open Questions

- Where exactly does the project store `/opsx:` skills? Survey at implementation time — likely `~/.claude/projects/<project-id>/skills/opsx/` per Claude Code project-skill convention.
- Should the skill output the draft to a different path on Windows (operator laptop)? Decision: same path — `docs/oracle-update-notes-vX.Y.Z.md.draft` — paths are POSIX-compatible.
- Should the skill detect when no significant changes warrant a new release (empty git log between tags) and refuse? Decision: warn, don't refuse — operator may have legitimate reason (e.g. CI-only release tag).
- Should we ship a "test mode" that runs the skill against a synthetic git history? Decision: no for v1 — the skill is markdown, easy to inspect; testing mode adds complexity.
