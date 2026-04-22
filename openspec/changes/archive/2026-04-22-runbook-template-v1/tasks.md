## 1. Setup

- [x] 1.1 Create feature branch `feature/runbook-template-v1` from `main` (per `feedback_branch_in_tasks.md` — branch creation happens at apply time, not spec time)
- [x] 1.2 Read `feedback_periodic_resume_save.md` to confirm the after-every-commit memory-save discipline applies to this change

## 2. Author the canonical template

- [x] 2.1 Create `docs/runbook-template.md` with the 8 mandatory sections in fixed order (Consulted Memories, Scope & Non-Scope, Service-Recreate Matrix, Pre-Deploy Gates, Deploy Steps, Post-Deploy Gates, Rollback Matrix, Post-Deploy Housekeeping) per spec requirement "Mandatory section order"
- [x] 2.2 Embed the `consulted:` block convention in the template with an annotated example (one cited memory, one `not-applicable:` entry, one `# why-cited:` comment) per spec requirement "Consulted memories frontmatter block"
- [x] 2.3 Embed the service-recreate matrix as a markdown table with the 5 mandatory rows (backend↔frontend, prometheus on prometheus.yml, alertmanager on rendered config, postgres on pgaudit.conf, host nginx on nginx config) per spec requirement "Pinned service-recreate matrix"
- [x] 2.4 Embed the pre-deploy gate checklist with the 7 mandatory gates (env-var trailing-space lint, container UID vs perms, mvn clean, pg_dump, CI green, SSH access, compose dry-render) per spec requirement "Mandatory pre-deploy gate checklist"
- [x] 2.5 Embed the mandatory Playwright smoke gate with the exact invocation `cd e2e/playwright && BASE_URL=https://findabed.org npx playwright test --config=deploy/playwright.config.ts --reporter=list --trace on 2>&1 | tee ../../logs/post-deploy-smoke-vX.Y.Z.log` per spec requirement "Mandatory Playwright post-deploy smoke gate"
- [x] 2.6 Embed the readiness-gate URL convention `http://localhost:9091/actuator/health` (with basic auth from `.env.prod`) and an explicit "do NOT use the public URL" callout citing v0.49 issue #8 per spec requirement "Internal actuator URL by default"
- [x] 2.7 Self-review the template: every section header matches the spec's mandated names exactly (whitespace-insensitive); every mandatory matrix row + gate is present

## 3. Author the memory index companion

- [x] 3.1 Create `docs/runbook-memory-index.md` with one-line entries for every deploy-relevant memory file (use MEMORY.md as the source corpus, filtered to deploy-relevant entries — `feedback_prod_docker_build_pattern.md`, `feedback_bind_mount_inode_pitfall.md`, `feedback_smoke_spec_default_target.md`, `feedback_never_print_rendered_secrets.md`, `feedback_verify_doc_facts_against_source.md`, `project_live_deployment_status.md`, `project_oracle_deployment_lessons.md`, etc.) per spec requirement "Memory index companion file"
- [x] 3.2 Each entry MUST be ≤150 chars (skim discipline)
- [x] 3.3 Add an editorial note at the top of the index explaining that future entries are added when new `feedback_*.md` files are created with deploy/runbook relevance

## 4. Convert v0.49 runbook as the worked example

- [x] 4.1 Read the current `docs/oracle-update-notes-v0.49.0.md` (deployed runbook with the post-tag fixes from commit 35e14fa)
- [x] 4.2 Insert the `consulted:` frontmatter block at the top, citing every memory that the v0.49 author SHOULD have consulted (the ones noted as "back-cited" in the proposal) — `feedback_prod_docker_build_pattern.md`, `feedback_bind_mount_inode_pitfall.md`, `project_live_deployment_status.md#lesson-3`, `feedback_smoke_spec_default_target.md`, `feedback_never_print_rendered_secrets.md` (created mid-deploy), `feedback_verify_doc_facts_against_source.md` (created mid-deploy)
- [x] 4.3 Reorder existing sections to match the template's 8 mandatory sections; preserve all existing content (do not delete the runbook's actual deploy steps)
- [x] 4.4 Add the service-recreate matrix in the new section, with row (a) backend↔frontend explicitly checked off (and an inline comment "this row is the v0.49 issue #4 lesson; deploy step 5 was originally wrong here, fixed in commit 35e14fa")
- [x] 4.5 Add a "Lessons Surfaced" subsection (under Post-Deploy Housekeeping) listing the 10 issues hit during v0.49 deploy and which became new memory files vs which already existed but were missed
- [x] 4.6 Verify the converted runbook still passes a manual smoke read (sections in right order, no content lost, citations are accurate per `feedback_verify_doc_facts_against_source.md`)

## 5. Cross-link with companion changes

- [x] 5.1 Add a "Related changes" footer to `docs/runbook-template.md` linking to `opsx-runbook-draft-skill` (will populate the template) and `ci-runbook-consulted-check` (will lint the template)
- [x] 5.2 Update `RELEASE-NOTES-STRATEGY.md` to reference the new template as the authoritative shape for `docs/oracle-update-notes-vX.Y.Z.md`

## 6. Verification

- [x] 6.1 Open `docs/runbook-template.md` in a markdown renderer (GitHub preview or VS Code) and confirm the `consulted:` fenced YAML block renders correctly
- [x] 6.2 Open the converted `docs/oracle-update-notes-v0.49.0.md` and confirm the same
- [x] 6.3 Open `docs/runbook-memory-index.md` and confirm every entry is ≤150 chars (use `awk '{print length, $0}' docs/runbook-memory-index.md | sort -rn | head -5` to find any over-long entries)
- [x] 6.4 Manual review against `PERSONAS.md` lens — Alex (architecture / single-source-of-truth), Jordan (SRE / repeatability), Marcus (security / no inline secrets in template examples), Riley (QA / lintability)
- [x] 6.5 No automated tests required — this change ships markdown only; lint enforcement lands in `ci-runbook-consulted-check`

## 7. Commit + ship

- [x] 7.1 Stage `docs/runbook-template.md`, `docs/runbook-memory-index.md`, `docs/oracle-update-notes-v0.49.0.md` (modified)
- [x] 7.2 Commit with conventional message: `docs(runbook): canonical template + memory index + v0.49 worked example`
- [x] 7.3 Push to origin, open PR
- [x] 7.4 Per `feedback_release_after_scans.md` — wait for CI green before merge
- [x] 7.5 Merge to main; this change is docs-only so no version bump, no deploy, no release tag

## 8. Update memory after archival

- [x] 8.1 After this change is merged + archived (via `/opsx:archive`), add a one-line entry to `MEMORY.md` index pointing to a new `feedback_runbook_template_v1.md` file
- [x] 8.2 The new feedback memory documents the convention so future `/opsx:apply` runs on companion changes (`opsx-runbook-draft-skill`, `ci-runbook-consulted-check`) inherit the convention
