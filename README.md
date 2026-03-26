# Finding A Bed Tonight — Project Documentation

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](finding-a-bed-tonight/LICENSE)

Open-source emergency shelter bed availability platform — project documentation, specifications, and planning artifacts.

**[View the Demo Walkthrough](https://ccradle.github.io/findABed/demo/index.html)** — 18 annotated screenshots covering login, bed search, reservations, coordinator dashboard, admin panel, observability, Grafana, and Jaeger. Also works offline: clone the repo and open `demo/index.html`. Regenerate with `./demo/capture.sh`.

**[DV Opaque Referral Walkthrough](https://ccradle.github.io/findABed/demo/dvindex.html)** — 7 screenshots showing the privacy-preserving referral flow for domestic violence shelters (designed to support VAWA/FVPSA requirements).

**[HMIS Bridge Walkthrough](https://ccradle.github.io/findABed/demo/hmisindex.html)** — 4 screenshots showing async push of bed inventory to HMIS vendors with DV aggregation and Grafana monitoring.

**[CoC Analytics Walkthrough](https://ccradle.github.io/findABed/demo/analyticsindex.html)** — 6 screenshots showing the analytics dashboard: executive summary, utilization trends, demand signals, batch job management, HIC/PIT export, Grafana CoC Analytics.

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
│                    Code Repo (finding-a-bed-tonight)             │
│  Backend (Spring Boot) · Frontend (React PWA) · Infra (Terraform)│
└────────────────────────────┬─────────────────────────────────────┘
                             │ Deploy
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Deployed Platform                             │
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
├── specs/                               # Main project specifications (49 capabilities)
│   ├── auth-and-roles/
│   ├── bed-availability-query/
│   ├── bed-reservation/
│   ├── reservation-expiry/
│   ├── rls-enforcement/
│   ├── surge-lifecycle/
│   ├── surge-broadcast/
│   ├── surge-overflow/
│   ├── shelter-availability-update/
│   ├── shelter-profile/
│   ├── deployment-profiles/
│   ├── observability/
│   ├── webhook-subscriptions/
│   └── ... (20+ more)
└── changes/
    └── archive/
        ├── 2026-03-20-platform-foundation/
        ├── 2026-03-20-bed-availability/
        ├── 2026-03-20-reservation-system/
        ├── 2026-03-21-asyncapi-contract-hardening/
        ├── 2026-03-21-infra-security-hardening/
        ├── 2026-03-21-e2e-test-automation/
        ├── 2026-03-21-e2e-test-automation-hardening/
        ├── 2026-03-21-surge-mode/
        ├── 2026-03-22-operational-monitoring/
        ├── 2026-03-23-bed-availability-calculation-hardening/
        ├── 2026-03-23-dv-opaque-referral/
        ├── 2026-03-24-dv-address-redaction/
        └── 2026-03-25-hmis-bridge/
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
- **[bed-availability](openspec/changes/archive/2026-03-20-bed-availability/)** — Real-time bed availability with append-only snapshots, ranked bed search, coordinator update flow, data freshness. 40/40 tasks. Archived 2026-03-20.
- **[reservation-system](openspec/changes/archive/2026-03-20-reservation-system/)** — Soft-hold bed reservations with auto-expiry, availability integration, countdown UI. 44/44 tasks. Archived 2026-03-20.
- **[asyncapi-contract-hardening](openspec/changes/archive/2026-03-21-asyncapi-contract-hardening/)** — DV security annotations (x-security), surge payload enrichment. 10/10 tasks. Archived 2026-03-21.
- **[infra-security-hardening](openspec/changes/archive/2026-03-21-infra-security-hardening/)** — DynamoDB protection, OWASP CVE gate, Terraform security posture. 10/10 tasks. Archived 2026-03-21.
- **[e2e-test-automation](openspec/changes/archive/2026-03-21-e2e-test-automation/)** — Playwright UI + Karate API end-to-end test suite with CI pipeline. 49/49 tasks. Archived 2026-03-21.
- **[e2e-test-automation-hardening](openspec/changes/archive/2026-03-21-e2e-test-automation-hardening/)** — RLS enforcement, DV canary gate, reservation E2E, offline queue, Gatling perf suite. 35/35 tasks. Archived 2026-03-21.
- **[surge-mode](openspec/changes/archive/2026-03-21-surge-mode/)** — White Flag emergency activation, overflow capacity, surge broadcast, bed search integration. 37/37 tasks. Archived 2026-03-21.
- **[operational-monitoring](openspec/changes/archive/2026-03-22-operational-monitoring/)** — Cloud-agnostic Micrometer metrics, OTel tracing, @Scheduled monitors (stale shelter, DV canary, temperature/surge gap), Grafana dashboards, Admin UI observability tab, management port security. 68/68 tasks. Tagged v0.8.0. Archived 2026-03-22.
- **[oauth2-redirect-flow](openspec/changes/archive/2026-03-22-oauth2-redirect-flow/)** — OAuth2 authorization code + PKCE, dynamic client registration, closed registration, Keycloak dev profile, JWKS circuit breaker, Admin UI provider management. 69/69 tasks. Tagged v0.9.0. Archived 2026-03-22.
- **[offline-demo-capture](openspec/changes/archive/2026-03-22-offline-demo-capture/)** — Demo screenshot capture and walkthrough. 15/15 tasks. Archived 2026-03-22.
- **[security-dependency-upgrade](openspec/changes/archive/2026-03-24-security-dependency-upgrade/)** — Spring Boot 3.4.4→3.4.13, springdoc 2.8.6→2.8.16, 16 CVEs resolved. 35/35 tasks. Tagged v0.9.1. Archived 2026-03-24.
- **[legal-language-corrections](openspec/changes/archive/2026-03-24-legal-language-corrections/)** — Qualify compliance claims, add disclaimers, consent reasoning, PII risk notes. 17/17 tasks. Archived 2026-03-24.
- **[bed-availability-calculation-hardening](openspec/changes/archive/2026-03-23-bed-availability-calculation-hardening/)** — Single source of truth for `beds_total` (eliminated `shelter_capacity` table), 9-invariant server-side enforcement, concurrent hold safety, unified coordinator UI with `data-testid` locators. 117/117 tasks. Tagged v0.9.2. Archived 2026-03-23.
- **[dv-opaque-referral](openspec/changes/archive/2026-03-23-dv-opaque-referral/)** — Zero-PII referral tokens (designed to support VAWA/FVPSA), warm handoff, defense-in-depth RLS (SET ROLE + dvAccess check), DV Grafana dashboard, address redaction. 114/114 tasks. Tagged v0.10.0. Archived 2026-03-23.
- **[dv-address-redaction](openspec/changes/archive/2026-03-24-dv-address-redaction/)** — Configurable tenant policy for DV shelter address visibility (ADMIN_AND_ASSIGNED/ADMIN_ONLY/ALL_DV_ACCESS/NONE), API-level redaction, secured policy change endpoint. 46/46 tasks. Tagged v0.10.1. Archived 2026-03-24.
- **[hmis-bridge](openspec/changes/archive/2026-03-25-hmis-bridge/)** — Async push of bed inventory (HMIS Element 2.07) to vendors (Clarity/WellSky/ClientTrack), outbox pattern, DV aggregation, Admin UI export tab, Grafana dashboard. 85/85 tasks. Tagged v0.11.0. Archived 2026-03-25.
- **[coc-analytics](openspec/changes/archive/2026-03-25-coc-analytics/)** — Aggregate analytics dashboard, HIC/PIT exports, unmet demand tracking, Spring Batch job management, pre-aggregation, DV small-cell suppression (D18). 137/142 tasks. Tagged v0.12.0. Archived 2026-03-25.
- **[demo-seed-data](openspec/changes/archive/2026-03-25-demo-seed-data/)** — Realistic 28-day activity data, exception logging hardening (22 catch blocks), bed search query optimization (Little's Law + V25 index). 54/56 tasks. Tagged v0.12.1. Archived 2026-03-25.
- **[wcag-accessibility-audit](openspec/changes/archive/2026-03-26-wcag-accessibility-audit/)** — WCAG 2.1 AA: axe-core CI gate (zero violations), focus management, color independence, touch targets, ARIA remediation, session timeout warning (alertdialog), ACR document (VPAT 2.5), virtual screen reader tests, legal language review. 63/70 tasks. Tagged v0.13.0. Archived 2026-03-26.
- **[hold-duration-admin-config](openspec/changes/archive/2026-03-26-hold-duration-admin-config/)** — Admin UI for hold duration configuration (default 45→90 min), tenant config GET+merge+PUT, Swagger 401 fix (web.ignoring), observability null-safety, clean-room validation. 58/58 tasks. Tagged v0.13.1–v0.13.3. Archived 2026-03-26.

### Active Changes

(none)

### Planned Changes

(none — Phase 1 complete)

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
├── PERSONAS.md                                  # User and team personas for UX, QA, accessibility
├── PRE-DEMO-CHECKLIST.md                        # Pre-demo gap tracking (tiered: blocking, important, future)
├── demo/                                        # Offline demo walkthroughs
│   ├── index.html                               # Main walkthrough (18 screenshots)
│   ├── dvindex.html                             # DV opaque referral walkthrough (7 screenshots)
│   ├── hmisindex.html                           # HMIS bridge walkthrough (4 screenshots)
│   ├── analyticsindex.html                      # CoC analytics walkthrough (6 screenshots)
│   ├── capture.sh                               # Regenerate screenshots via Playwright
│   └── screenshots/                             # 35 captured views across 4 walkthroughs
├── openspec/                                    # OpenSpec artifacts
│   ├── config.yaml                              # OpenSpec configuration
│   ├── specs/                                   # Main specs (49 capabilities, synced from changes)
│   └── changes/
│       └── archive/                             # 21 archived changes
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

**Reservation (Soft-Hold)** — Temporary claim on a bed during transport. Lifecycle: HELD → CONFIRMED | CANCELLED | EXPIRED. Default hold duration: 90 minutes, configurable per tenant via Admin UI (range: 5–480 minutes).

**Opaque Referral** — Privacy-preserving DV shelter referral that does not reveal the shelter's location or existence to unauthorized users. Uses time-limited tokens with zero client PII.

**Warm Handoff** — Standard DV referral practice where the referring worker calls the shelter directly to arrange arrival. Required by VAWA/FVPSA — sensitive details are exchanged verbally, never stored in the system.

**VAWA (Violence Against Women Act)** — Federal law (34 U.S.C. 12291(b)(2)) prohibiting disclosure of DV survivor PII. FABT is designed to support VAWA requirements through zero-PII referral tokens and address redaction.

**FVPSA (Family Violence Prevention and Services Act)** — Federal law (45 CFR Part 1370) requiring DV shelter address confidentiality. FABT enforces configurable address visibility policies per tenant.

**Data Freshness** — Indicator of availability data age: FRESH (<2 hours), AGING (2–8 hours), STALE (>8 hours), UNKNOWN. Displayed in UI and monitored by operational alerts.

**WCAG 2.1 Level AA** — Web Content Accessibility Guidelines — the standard mandated by ADA Title II for state and local government web content. FABT self-assesses conformance via an ACR (Accessibility Conformance Report).

**Small-Cell Suppression** — Privacy technique for DV analytics: suppress aggregations with fewer than 3 distinct shelters or fewer than 5 beds to prevent identification of individual DV shelters.

**HMIS (Homeless Management Information System)** — HUD-mandated database for tracking homeless services. FABT pushes bed inventory (Element 2.07) to HMIS vendors via the HMIS Bridge.

**HIC (Housing Inventory Count)** — Annual HUD report of all beds and units dedicated to homeless populations in a CoC. FABT generates HIC CSV exports from bed availability snapshots.

**SPM (System Performance Measures)** — Seven HUD-mandated metrics for CoC performance evaluation. FABT provides complementary project-level data (utilization, capacity, demand) but does not replicate client-level SPMs (which require HMIS enrollment data).

**Spring Batch** — Framework for chunk-oriented job processing. Used in FABT for daily pre-aggregation, HMIS push, and HIC/PIT export with execution history, retry, and restart from failure.

**MCP (Model Context Protocol)** — Open standard by Anthropic for AI agent integration. Platform is MCP-ready for Phase 2 natural language interface.

---

## License

[Apache License 2.0](finding-a-bed-tonight/LICENSE)

> Finding A Bed Tonight is provided as-is, without warranty of any kind. Availability data is supplied by shelter operators and may not reflect current conditions. This platform is not a guarantee of shelter availability. See the [Apache 2.0 License](finding-a-bed-tonight/LICENSE) for full warranty disclaimer and limitation of liability terms.
