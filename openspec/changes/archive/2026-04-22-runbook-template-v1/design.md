## Context

FABT releases land on a 1–3-per-week cadence. Each release ships a `docs/oracle-update-notes-vX.Y.Z.md` runbook authored manually by the operator (or by Claude under operator review). The current authoring workflow is "open the previous release's runbook, copy it, edit for the new release." Memory entries (~24 `feedback_*.md` files plus `project_live_deployment_status.md`) accumulate institutional learning but only enter the next runbook when the author manually consults them. The v0.49.0 deploy demonstrated this fails reliably: 5 of 10 mid-flight issues were duplicates of lessons already in memory.

Stakeholders: operator (Corey), Claude (acts as runbook author + deploy executor), the 7 warroom personas (Alex, Jordan, Marcus Webb, Sam, Riley, Casey, Elena) who collectively produced the strategic proposal this design implements.

Constraints:
- No new tooling required to AUTHOR runbooks — must work with plain markdown today; the `opsx-runbook-draft-skill` change (separate) layers on top later.
- Must work for the existing `docs/oracle-update-notes-vX.Y.Z.md` series — no parallel doc tree.
- Lintable by a simple shell script (the `ci-runbook-consulted-check` change consumes the convention).
- Compatible with the `--no-cache` / `--force-recreate` patterns codified in `feedback_prod_docker_build_pattern.md`.

External validation: Google SRE Workbook + Atlassian + incident.io blogs all converge on a "consistent template, mandatory sections, lessons-learned propagated as actionable items with owners" pattern. Our `consulted:` frontmatter is the FABT-shaped expression of that pattern.

## Goals / Non-Goals

**Goals:**

- A single `docs/runbook-template.md` that defines the canonical structure for every future deploy runbook.
- Mandatory `consulted:` frontmatter block listing every memory file the author reviewed during runbook authoring.
- A pinned service-recreate matrix capturing cross-service coupling lessons (backend↔frontend, prometheus on `prometheus.yml` change, alertmanager on rendered-config change, postgres on `pgaudit.conf` change).
- Pre-deploy gate checklist mechanically derived from the existing `feedback_*.md` corpus.
- Mandatory Playwright post-deploy smoke gate — not optional, not "if time permits."
- A worked example: back-convert `docs/oracle-update-notes-v0.49.0.md` to the new template so future authors see the shape applied to a real release.
- A `docs/runbook-memory-index.md` companion: flat list of every deploy-relevant memory with one-line descriptions, so the author can scan in one place rather than walk the memory directory.

**Non-Goals:**

- Tooling to AUTOMATE the `consulted:` block population — that's the `opsx-runbook-draft-skill` change.
- CI enforcement of the `consulted:` block — that's the `ci-runbook-consulted-check` change.
- A full rehearsal harness — that's `deploy-rehearsal-harness`.
- Migration of older runbooks (v0.39 through v0.48) to the new template — they're frozen historical artifacts; only forward-going runbooks adopt.
- Replacing the operator-side `~/fabt-secrets/docker-compose.prod*.yml` files with anything; those stay where they are.
- Solving VM-side `git checkout` working-tree drift (v0.49 issue #5) — the new template will include a "VM `git status` clean" gate but cannot prevent operator override.

## Decisions

**1. `consulted:` frontmatter block, NOT per-step footnotes, NOT a sidecar file.**

Decision: One YAML-fenced block at the top of every runbook listing every memory file reviewed.

Alternatives considered:
- Per-step footnotes (e.g. `[See feedback_X.md]` next to each gate). REJECTED — pollutes readable flow; encourages copy-paste rot when the same memory applies to multiple steps; runbook becomes a tangled mess of citations.
- Sidecar file (`docs/oracle-update-notes-vX.Y.Z.consulted.md`). REJECTED — second artifact silently drifts from the runbook; defeats "single source of truth."
- No mechanism, rely on author discipline. REJECTED — that's exactly what failed in v0.49.

Rationale: one block is dense, diff-friendly, lintable by a shell script grep, and gives the author one place to prove the work was done. Each entry carries an optional `# why-cited:` line so citations aren't ceremonial — borrowed from the Atlassian/incident.io "actionable items with owners" pattern surfaced in web research.

**2. Pinned service-recreate matrix, NOT per-release re-derivation.**

Decision: A table in the template lists the service-coupling rules. Authors copy the table into their runbook and check off the rows that apply.

Alternatives considered:
- Free-text "remember to recreate frontend with backend." REJECTED — exactly how v0.49 issue #4 happened.
- Auto-detected coupling from compose changes. REJECTED — too smart; encodes assumptions about diff parsing that will break.

Rationale: matrix is human-readable, version-controlled, easy to extend when a new coupling lesson emerges (a new row gets added in the next runbook draft and stays for all subsequent runbooks).

**3. Mandatory Playwright smoke gate as a numbered post-deploy step.**

Decision: Every runbook MUST include a numbered post-deploy gate "Playwright smoke against `https://findabed.org`" with the explicit invocation pattern. No "optional" wording.

Alternatives considered:
- Smoke as a separate doc. REJECTED — then it's never run; v0.49 proved this.
- Smoke as opt-in. REJECTED — same failure mode.

Rationale: the smoke is the only gate that exercises the full Cloudflare → host nginx → frontend → backend chain end-to-end. If we don't make it mandatory, it gets skipped under deploy time pressure (v0.49 again).

**4. Pre-deploy gates derived mechanically from `feedback_*.md` corpus.**

Decision: The template carries a checklist of pre-deploy gates each tied to one or more memory files. Examples:
- `KEY= value` trailing-space lint on `.env.prod` (v0.49 issue #1, no prior memory — new gate added when this is shipped)
- Container UID vs host file perm check (v0.49 issue #2, no prior memory)
- `mvn clean` (`feedback_deploy_old_jars.md`)
- `pg_dump` backup
- CI green (`feedback_release_after_scans.md`)
- Operator SSH confirmed (`feedback_no_ssh_tunnels.md`)

Alternatives considered:
- Free-text "do the usual checks." REJECTED — same root cause as everything else.

Rationale: a checklist is testable; freeform isn't.

**5. `docs/runbook-memory-index.md` companion file.**

Decision: A flat one-line-per-memory index, regenerated by hand (or by `opsx-runbook-draft-skill` later) when memories are added. The runbook author scans this index to know what's available without walking the memory directory.

Alternatives considered:
- Auto-generate from MEMORY.md. PARTIAL — MEMORY.md already has one-line descriptions, but it's user-private (`~/.claude/projects/.../memory/`) and contains non-deploy-relevant entries. Index is a deploy-filtered subset.
- Embed in the template itself. REJECTED — bloats the template; makes the template stale every time a memory is added.

Rationale: separating the index from the template lets us update memories without touching the template.

**6. Back-convert v0.49 runbook as the worked example.**

Decision: `docs/oracle-update-notes-v0.49.0.md` is updated to the new template format as part of this change. Future authors read it as the canonical example.

Alternatives considered:
- Generate a synthetic example. REJECTED — synthetic examples lack the messy reality of actual deploys (compose-override coupling, real env-var names, real testid references).
- Wait for v0.50 deploy to be the worked example. REJECTED — delays the "what does a runbook in this template look like?" answer by weeks.

## Risks / Trade-offs

- **[Authoring burden of the `consulted:` block]** — author has to walk the memory corpus and decide what's in scope. → Mitigated by the `docs/runbook-memory-index.md` companion (one-line scannable), and by the future `opsx-runbook-draft-skill` (auto-populates the block).
- **[Memory corpus drift]** — a memory file may encode a no-longer-true fact; the runbook then cites stale guidance. → Mitigated by quarterly memory-review sweep (out of scope for this change; tracked separately).
- **[Template ossification]** — once the template is in place, changing it becomes painful (every existing runbook is "out of date"). → Mitigated by the "applies to forward-going runbooks only" rule; older runbooks are frozen artifacts.
- **[Service-recreate matrix gets out of date]** — when we add a new container or change a coupling, the matrix must be updated. → Mitigated by the convention that any deploy that surfaces a new coupling triggers a follow-up commit to the template, NOT just to the per-release runbook.
- **[Lintability disagreement with `opsx-runbook-draft-skill` and `ci-runbook-consulted-check`]** — the three changes encode the same convention; if they drift in interpretation we get false-positive CI failures or skill-output that doesn't lint. → Mitigated by landing this template change FIRST (per the warroom dependency order); the other two changes anchor to it.

## Migration Plan

1. Land `docs/runbook-template.md` and `docs/runbook-memory-index.md` (no operational impact; pure docs).
2. Convert `docs/oracle-update-notes-v0.49.0.md` to the new template (the worked example) — this is the v0.49 retroactive runbook update; the deploy already happened, but the conversion serves as the canonical example future authors imitate.
3. Update the `release-prep` workflow expectation: any new `docs/oracle-update-notes-vX.Y.Z.md` MUST follow the template. Documented in `docs/runbook-template.md` itself + `RELEASE-NOTES-STRATEGY.md`.
4. Future deploys author per the template; gradual adoption — no big-bang migration.

Rollback: revert the docs commits. No code, no schema, no service impact.

## Open Questions

- Should `docs/runbook-memory-index.md` be hand-curated or auto-generated from MEMORY.md? Hand-curated for v1 (lower complexity, author has full control over what's deploy-relevant); revisit when `opsx-runbook-draft-skill` lands.
- Should the `consulted:` block use YAML frontmatter (`---` delimited at top of file) or a fenced markdown code block (` ```yaml `)? Frontmatter is more standard but markdown renderers vary in how they display it. Decision: fenced markdown code block — renders as a clearly-visible block in any viewer, lintable by a regex on `^consulted:`.
- Do we cite v0.47/v0.48 runbooks in the worked-example v0.49 conversion as "this is what we should have done"? Probably yes — flag the missed memories explicitly so the lesson is visible.
