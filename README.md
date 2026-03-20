# Finding A Bed Tonight — Project Documentation

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](finding-a-bed-tonight/LICENSE)

Open-source emergency shelter bed availability platform — project documentation, specifications, and planning artifacts.

---

## Problem Statement & Business Value

### The Problem

A family of five is sitting in a parking lot at midnight. A social worker has 30 minutes before the family stops cooperating. Right now, that social worker is making phone calls — to shelters that may be closed, full, or unable to serve that family's specific needs. There is no shared system for real-time shelter bed availability in most US communities.

Commercial software does not serve this space because there is no profit motive. Homeless services operate on tight grants with no margin for per-seat licensing. The result: social workers keep personal spreadsheets, shelter coordinators answer midnight phone calls, and families wait in parking lots while the system fails them.

### The Goal

An open-source platform that matches homeless individuals and families to available shelter beds in real time. Reduce the time from crisis call to bed placement from 2 hours to 20 minutes. Three deployment tiers (Lite, Standard, Full) ensure any community — from a rural volunteer-run CoC to a metro area with 50 shelters — can adopt the platform at a cost they can sustain.

### Business Value

| Stakeholder | Value |
|---|---|
| **Families/individuals in crisis** | Faster placement, fewer nights unsheltered |
| **Social workers/outreach teams** | Reduced cognitive load, real-time availability instead of phone calls |
| **Shelter coordinators** | 3-tap bed count updates, automated reporting |
| **City/county governments** | Data-driven resource allocation, HUD reporting |
| **Foundations/funders** | Measurable impact metrics, cost-effective open-source model |

### How It Fits Together

```
┌──────────────────────────────────────────────────────────────────┐
│                    Docs Repo (this repo)                         │
│  Proposals · Designs · Specs · Tasks · Playbooks                 │
└────────────────────────────┬─────────────────────────────────────┘
                             │ OpenSpec workflow drives implementation
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Code Repo (finding-a-bed-tonight)              │
│  Backend (Spring Boot) · Frontend (React PWA) · Infra (Terraform)│
└────────────────────────────┬─────────────────────────────────────┘
                             │ Deploy
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Deployed Platform                              │
│  Lite (PostgreSQL only) · Standard (+Redis) · Full (+Kafka)      │
└──────────────────────────────────────────────────────────────────┘
```

---

## OpenSpec Workflow

### What Is OpenSpec?

[OpenSpec](https://openspec.dev) is a lightweight spec-driven development framework designed for AI coding assistants. Specifications, proposals, and designs live in the repository alongside code — ensuring every feature is documented before it is implemented.

GitHub: [https://github.com/Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec)

### How We Use It

Every feature starts as an OpenSpec change and follows this lifecycle:

1. **Proposal** — Business case and scope
2. **Design** — Architecture decisions and trade-offs
3. **Specs** — Capability specifications with requirements and scenarios
4. **Tasks** — Implementation task list with checkpoints
5. **Implementation** — Code written against the spec
6. **Verification** — `/opsx:verify` confirms implementation matches specs
7. **Archive** — Change is finalized and archived

### Directory Structure

```
openspec/
├── config.yaml                          # OpenSpec configuration
├── specs/                               # Main project specifications (synced from changes)
└── changes/
    └── platform-foundation/             # Active change
        ├── .openspec.yaml               # Change metadata
        ├── proposal.md                  # Business case
        ├── design.md                    # Architecture decisions
        ├── specs/                       # 8 capability specs, 30+ requirements
        │   ├── auth-and-roles/
        │   ├── data-import/
        │   ├── deployment-profiles/
        │   ├── multi-tenancy/
        │   ├── observability/
        │   ├── pwa-shell/
        │   ├── shelter-profile/
        │   └── webhook-subscriptions/
        └── tasks.md                     # 119 tasks across 13 sections
```

### Available Commands

| Command | Purpose |
|---|---|
| `/opsx:new` | Create a new change — scaffolds the change directory |
| `/opsx:ff` | Fast-forward through all artifact creation (proposal through tasks) |
| `/opsx:continue` | Resume work on an in-progress change |
| `/opsx:apply` | Implement tasks from tasks.md |
| `/opsx:verify` | Verify implementation matches all artifacts |
| `/opsx:sync` | Sync delta specs to main specs if drift detected |
| `/opsx:archive` | Finalize and archive the completed change |

### Archived Changes

- **[platform-foundation](openspec/changes/archive/2026-03-20-platform-foundation/)** — Modular monolith backend, multi-tenant auth, shelter profiles, data import, observability, PWA, CI/CD, Terraform. 130/131 tasks. Archived 2026-03-20.

### Active Changes

- **[bed-availability](openspec/changes/bed-availability/)** — Real-time bed availability with append-only snapshots, ranked search, coordinator update flow. 35 tasks. Specced, ready for implementation.

### Planned Changes

| Change | Description | Status |
|--------|-------------|--------|
| **reservation-system** | Soft-hold for bed placement (configurable duration, auto-expiry, Redis acceleration) | Not started |
| **surge-mode** | White Flag / emergency activation, CoC-admin triggered, broadcast to outreach workers | Not started |
| **oauth2-redirect-flow** | Browser OAuth2 redirect/callback with Keycloak, dynamic provider registration | Not started |
| **e2e-test-automation** | Playwright (UI) + Karate (API) end-to-end test suite | Not started |
| **dv-opaque-referral** | Privacy-preserving DV shelter referral with human-in-the-loop confirmation | Not started |
| **hmis-bridge** | Async push adapter to HMIS vendors, circuit breaker isolated | Not started |
| **coc-analytics** | Aggregate anonymized metrics, unmet demand reporting, HUD grant support | Not started |

### How to Contribute a Change

1. Fork this repository
2. Create a feature branch
3. Run `/opsx:new` to scaffold a new change
4. Develop specs with `/opsx:ff`
5. Implement with `/opsx:apply`
6. Verify with `/opsx:verify`
7. Submit a pull request

---

## Repository Structure

```
findABed/                                        # Docs repo root
├── README.md                                    # This file
├── CLAUDE-CODE-BRIEF.md                         # AI session primer
├── MCP-BRIEFING.md                              # MCP server decision record
├── fabt-openspec-proposal.md                    # Original OpenSpec proposal
├── fabt-hsds-extension-spec.md                  # HSDS 3.0 bed availability extension
├── finding-a-bed-tonight-proposal.docx          # Business case and solution overview
├── city-adoption-playbook.docx                  # Guide for cities adopting the platform
├── shelter-onboarding-workflow.docx             # 7-day shelter onboarding process
├── openspec/                                    # OpenSpec artifacts
│   ├── config.yaml                              # OpenSpec configuration
│   ├── specs/                                   # Main specs (synced from changes)
│   └── changes/
│       └── platform-foundation/                 # Active change (see OpenSpec section)
└── finding-a-bed-tonight/                       # Code monorepo (Git submodule)
```

---

## Related Repositories

| Repository | Description |
|---|---|
| [finding-a-bed-tonight](https://github.com/ccradle/finding-a-bed-tonight) | Code monorepo — Spring Boot backend, React PWA frontend, Terraform infrastructure |

---

## Key Documents

| Document | Description |
|---|---|
| [finding-a-bed-tonight-proposal.docx](finding-a-bed-tonight-proposal.docx) | Business case, target users, solution overview |
| [fabt-hsds-extension-spec.md](fabt-hsds-extension-spec.md) | HSDS 3.0 bed availability extension specification |
| [fabt-openspec-proposal.md](fabt-openspec-proposal.md) | Original OpenSpec proposal for the project |
| [city-adoption-playbook.docx](city-adoption-playbook.docx) | Step-by-step guide for cities adopting the platform |
| [shelter-onboarding-workflow.docx](shelter-onboarding-workflow.docx) | 7-day shelter onboarding process |
| [MCP-BRIEFING.md](MCP-BRIEFING.md) | MCP server decision record — Phase 1 hold with MCP-ready design requirements |
| [CLAUDE-CODE-BRIEF.md](CLAUDE-CODE-BRIEF.md) | AI coding session primer with project context and rules |

---

## Domain Glossary

**CoC (Continuum of Care)** — HUD-defined regional body coordinating homeless services. Each CoC has a unique ID (e.g., NC-507 for Wake County). Maps to a tenant in the platform.

**Tenant** — A CoC or administrative boundary served by a single platform deployment. Multi-tenant design allows one deployment to serve multiple CoCs.

**DV Shelter (Domestic Violence)** — Shelter serving DV survivors. Location and existence protected by PostgreSQL Row Level Security. Never exposed through public queries.

**HSDS (Human Services Data Specification)** — Open Referral standard (v3.0) for describing social services. FABT extends HSDS with bed availability objects.

**Surge Event / White Flag** — Emergency activation when weather or crisis requires expanded shelter capacity. CoC-admin triggered, broadcast to all outreach workers.

**PIT Count (Point-in-Time)** — Annual HUD-mandated count of sheltered and unsheltered homeless individuals.

**Bed Availability** — Real-time count of open beds by population type at a shelter. Append-only snapshots, never updated in place.

**Population Type** — Category of individuals a shelter serves: `SINGLE_ADULT`, `FAMILY_WITH_CHILDREN`, `WOMEN_ONLY`, `VETERAN`, `YOUTH_18_24`, `YOUTH_UNDER_18`, `DV_SURVIVOR`.

**Outreach Worker** — Frontline staff who connects homeless individuals to services. Primary user of the bed search interface.

**Coordinator** — Shelter staff responsible for updating bed counts and managing shelter profile.

**Opaque Referral** — Privacy-preserving DV shelter referral that does not reveal the shelter's location or existence to unauthorized users.

**MCP (Model Context Protocol)** — Open standard by Anthropic for AI agent integration. Platform is MCP-ready for Phase 2 natural language interface.

---

## License

[Apache License 2.0](finding-a-bed-tonight/LICENSE)
