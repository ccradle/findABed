# Docs Archive

Historical documents preserved for reference. Not part of the live
documentation surface; consult only when working with code or
artifacts from the matching era.

## Contents

- **`oracle-demo-runbook-v0.14.1.md`** — original one-shot Oracle
  Always Free deploy runbook from v0.14.1 (March 2026). Documents
  the first VM provisioning, host nginx setup, and the bare-IP demo
  (pre-Cloudflare / pre-custom-domain).

- **`oracle-demo-runbook-v0.21.0.md`** — second iteration, current
  through v0.24. Documents the same VM with hardening additions and
  the host-nginx + Cloudflare proxy chain. Referenced as "Base
  runbook" by `oracle-update-notes-v0.25.0.md` and
  `oracle-update-notes-v0.27.0.md` (in the code repo at
  `finding-a-bed-tonight/docs/`).

## Why archived

Both files were superseded by the **per-release update-notes
pattern** introduced in v0.25 (April 2026). Today every release
ships its own runbook at
`finding-a-bed-tonight/docs/oracle-update-notes-vX.Y.Z.md`, with a
mandatory template at `finding-a-bed-tonight/docs/runbook-template.md`
(per `feedback_runbook_template_v1.md`). The one-shot files in this
archive are kept so historical update notes' cross-references still
resolve, but no operator should follow them for a fresh deploy on
v0.25 or later.
