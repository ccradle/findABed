# Finding A Bed Tonight — Project Documentation

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Open-source emergency shelter bed availability platform — project documentation, specifications, and planning artifacts.

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `openspec/` | OpenSpec artifacts: proposals, designs, specs, tasks |
| `.claude/`, `.gemini/`, `.github/`, `.opencode/` | AI tool configurations (OpenSpec commands/skills) |
| `*.md`, `*.docx` | Project proposals, adoption playbook, onboarding workflow |

## Related Repositories

| Repository | Description |
|-----------|-------------|
| [finding-a-bed-tonight](https://github.com/ccradle/finding-a-bed-tonight) | Code monorepo (backend, frontend, infrastructure) |

## Current Change

**`platform-foundation`** — Modular monolith backend with multi-tenancy, hybrid auth (JWT + OAuth2 + API keys), PostgreSQL RLS for DV shelter protection, tiered deployment profiles (Lite/Standard/Full), and PWA shell.

- **Status:** Implementation in progress (CP2: Multi-Tenancy + Auth)
- **Tasks:** 119 across 13 sections
- **Specs:** 7 capability specs, 30 requirements, 91 scenarios

## Project Mission

A family of five sitting in a parking lot at midnight. A social worker has 30 minutes before the family stops cooperating. Every architectural decision in this codebase exists to get that family into a bed faster.

## Documentation

- [Project Proposal](finding-a-bed-tonight-proposal.docx) — Business case and solution overview
- [HSDS Extension Spec](fabt-hsds-extension-spec.md) — HSDS 3.0 bed availability extension
- [City Adoption Playbook](city-adoption-playbook.docx) — Guide for cities adopting the platform
- [Shelter Onboarding Workflow](shelter-onboarding-workflow.docx) — 7-day shelter onboarding process
