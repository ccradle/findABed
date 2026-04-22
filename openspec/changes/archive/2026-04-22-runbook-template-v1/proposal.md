## Why

The v0.49.0 deploy hit 10 mid-flight issues. Five of them — frontend not recreated alongside backend, bind-mount inode pitfall on `prometheus.yml` reload, missing Playwright smoke gate, wrong actuator URL (public vs `:9091`), and a duplicate of the v0.47 lesson on `external_labels` placement — had pre-existing `feedback_*.md` or `project_live_deployment_status.md` entries that the runbook author never consulted. Each `docs/oracle-update-notes-vX.Y.Z.md` is currently authored fresh from the prior release's file plus recollection, so accumulated institutional learning never re-enters the artifact. The Google SRE Workbook position on this is unambiguous: every runbook should follow a consistent template so readers and authors both know what to expect; without it, every deploy re-discovers the same lessons.

## What Changes

- **NEW `docs/runbook-template.md`** — single canonical template every `docs/oracle-update-notes-vX.Y.Z.md` MUST follow, with a fixed section order, a `consulted:` frontmatter block naming every memory file reviewed during authoring, and a pinned service-recreate matrix that captures cross-service coupling (backend↔frontend, prometheus when `prometheus.yml` changes, etc.).
- **Conversion of `docs/oracle-update-notes-v0.49.0.md`** to the new template as the worked example + back-fill citation of the memories that should have been consulted.
- **Memory citation discipline:** the `consulted:` frontmatter is the ONE place a runbook proves the author cross-checked memory; per-step footnotes are out (encourage rot, pollute readable flow), sidecar files are out (drift silently). One block, top of doc, lintable.
- **Service-recreate matrix is pinned in the template, not re-derived per release** — captures lessons like "any backend recreate requires frontend recreate" (v0.49 issue #4) and "prometheus.yml edit requires `--force-recreate` not `/-/reload`" (`feedback_bind_mount_inode_pitfall.md`).
- **Mandatory Playwright smoke gate** — every release-runbook MUST include the smoke as a numbered post-deploy gate, not an "if time permits" footnote.
- **Pre-deploy gate checklist** derived from the feedback corpus (no `KEY= value` trailing-space bugs, container-UID vs host-file-perm, `mvn clean`, `pg_dump`, CI-green, no SSH-execute-without-confirmation, etc.).

This is a **convention + template change, not a code change.** No backend, no frontend, no DB.

## Capabilities

### New Capabilities

- `runbook-template`: Canonical structure for `docs/oracle-update-notes-vX.Y.Z.md` deploy runbooks — mandatory sections, frontmatter `consulted:` block convention, service-recreate matrix, pre-deploy gate checklist derived from `feedback_*.md` corpus, mandatory Playwright smoke as a numbered post-deploy gate, and a worked example (back-converted v0.49 runbook).

### Modified Capabilities

(none — this is a net-new template; existing capabilities are unchanged)

## Impact

- **New file:** `docs/runbook-template.md` (~3-5 KB markdown, no executable content)
- **Modified file:** `docs/oracle-update-notes-v0.49.0.md` — converted to the template as the worked example
- **Convention applied to:** all future `docs/oracle-update-notes-vX.Y.Z.md`
- **Enables:** `opsx-runbook-draft-skill` (separate change) — that skill seeds future runbooks from this template; without the template, the skill has nothing to populate against
- **Enables:** `ci-runbook-consulted-check` (separate change) — the CI check assumes the `consulted:` frontmatter convention defined here
- **No code, build, CI, or deploy artifact change.** No version bump triggered by this change alone.
- **Memory corpus:** seeds a `docs/runbook-memory-index.md` companion (a flat list with one-line descriptions of every deploy-relevant `feedback_*.md` and `project_*.md`) so the next runbook author can scan it in one place — drains the per-author burden of remembering which memories exist.
