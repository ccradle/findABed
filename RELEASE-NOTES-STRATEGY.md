# FABT Release Notes Strategy

**Authors:** Alex Chen (Principal Engineer), Jordan Reyes (SRE), Casey Drummond (Attorney)
**Date:** March 2026
**Audience:** Project maintainer (Corey Cradle)
**Commit to:** `findABed/RELEASE-NOTES-STRATEGY.md`

---

## Recommendation Summary

Use **GitHub Releases** as the primary mechanism, backed by a **`CHANGELOG.md`**
in each repo. These serve different audiences and together take about two minutes
per release to maintain.

Do not use GitHub Discussions as the primary home for release notes. Discussions
are better suited to Q&A and community conversation than versioned change records.

---

## Why Two Places

| Artifact | Audience | When They Read It |
|---|---|---|
| GitHub Releases | Watchers, evaluators, new contributors | When notified of a new release, or when evaluating the project for the first time |
| `CHANGELOG.md` | Operators, deployers, existing users | When deciding whether to upgrade a running deployment |

These are different moments in the relationship someone has with the project.
A city IT officer evaluating the repo for the first time will check the Releases
tab. A CoC admin who deployed v0.9.0 and wants to know what changed in v0.11.0
will `cat CHANGELOG.md` after pulling the repo.

---

## GitHub Releases

### How to Create a Release

1. Go to `github.com/ccradle/finding-a-bed-tonight`
2. Click **Releases** in the right sidebar (or `/releases`)
3. Click **Draft a new release**
4. Select the existing tag (e.g., `v0.11.0`) from the tag dropdown
5. Set the release title: `v0.11.0 — HMIS Bridge`
6. Paste the release notes (markdown, see format below)
7. Click **Publish release**

Repeat for the `findABed` docs repo releases (same tag, different notes).

### Release Notes Format

```markdown
## v0.11.0 — HMIS Bridge

One sentence describing the primary capability this release adds.

### Added
- Bullet describing each significant new capability
- Keep to one line per item — link to docs or commits if detail is needed
- Admin UI additions go here

### Changed
- Behavior changes that affect existing deployments
- Configuration changes (especially env vars added or renamed)
- Default value changes (e.g., hold duration 45 → 90 minutes)

### Fixed
- Notable bugs resolved

### Security
- CVEs resolved (reference CVE number if applicable)
- Security posture changes (e.g., RLS enforcement, auth changes)

### Database
- List each new Flyway migration by number and description
- Flag any migrations that are irreversible or require downtime

### Tests
- Summary test counts: X integration tests, Y Playwright, Z Karate

### Upgrading from vX.X.X
- Any manual steps required (env var additions, config changes)
- Note if a clean database is required

**Diff:** [v0.10.1...v0.11.0](https://github.com/ccradle/finding-a-bed-tonight/compare/v0.10.1...v0.11.0)
```

### What to Omit

- Internal refactoring with no user-visible impact
- Test-only changes (unless they reveal a previously hidden bug)
- Documentation typo fixes
- Dependency bumps with no security relevance

### Tone

Write for two audiences simultaneously: a developer deciding whether to upgrade,
and a non-technical evaluator (city IT officer, program officer) reading the
history for the first time. Keep language clear. Avoid jargon in the summary
line. Technical detail belongs in the sections, not the headline.

---

## CHANGELOG.md Format

One file per repo. Newest version at the top. Follow
[Keep a Changelog](https://keepachangelog.com) conventions.

### Template

```markdown
# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

*(Changes merged to main but not yet tagged)*

---

## [v0.11.0] — 2026-03-25 — HMIS Bridge

### Added
- Async push of bed inventory (HMIS Element 2.07) to Clarity, WellSky,
  and ClientTrack via outbox pattern
- DV shelter aggregation before push — individual DV shelter data never pushed
- Admin UI HMIS Export tab: status, data preview, history, push controls
- Grafana HMIS Bridge dashboard (push rate, failures, latency, queue depth)
- `hmis_outbox`, `hmis_audit_log`, `hmis_vendor_configs`,
  `hmis_inventory_records` tables (V22 migration)

### Security
- DV shelter occupancy aggregated across all DV shelters before HMIS push —
  individual shelter counts never transmitted

### Tests
- 10 integration tests, 5 Playwright tests, 6 Karate scenarios (354 total)

---

## [v0.10.1] — 2026-03-24 — DV Address Redaction

...

---

[Unreleased]: https://github.com/ccradle/finding-a-bed-tonight/compare/v0.11.0...HEAD
[v0.11.0]: https://github.com/ccradle/finding-a-bed-tonight/compare/v0.10.1...v0.11.0
[v0.10.1]: https://github.com/ccradle/finding-a-bed-tonight/compare/v0.10.0...v0.10.1
```

The diff links at the bottom are standard Keep a Changelog convention and let
a reader jump directly to the code diff for any version.

---

## Backfilling the Existing Tags

You have clean tags at v0.1.0 through v0.11.0 (plus v0.9.1 and v0.9.2).
Backfilling release notes for all of them takes about an hour and gives the
project a complete, credible public history from day one of broader visibility.

The weekly activity report and the OpenSpec archive entries have all the raw
material needed. Here's the mapping:

| Tag | Name | OpenSpec Change | Key Capability |
|---|---|---|---|
| v0.1.0 | Platform Foundation | platform-foundation | Backend, auth, shelter, PWA, CI |
| v0.2.0 | Bed Availability | bed-availability | Snapshots, bed search, freshness |
| v0.3.0 | Reservation System | reservation-system | Soft-hold lifecycle, countdown UI |
| v0.4.0 | Security Hardening | asyncapi + infra-security | DynamoDB protection, OWASP gate |
| v0.5.0 | E2E Test Automation | e2e-test-automation | Playwright, Karate, CI pipeline |
| v0.6.0 | E2E Hardening | e2e-test-automation-hardening | RLS enforcement, DV canary gate |
| v0.7.0 | Surge Mode | surge-mode | White Flag activation, overflow |
| v0.8.0 | Operational Monitoring | operational-monitoring | Micrometer, OTel, Grafana |
| v0.9.0 | OAuth2 | oauth2-redirect-flow | PKCE, dynamic providers, Keycloak |
| v0.9.1 | Security Upgrade | security-dependency-upgrade | Spring Boot 3.4.13, 16 CVEs |
| v0.9.2 | Availability Hardening | bed-availability-calculation-hardening | 9 invariants, single source of truth |
| v0.10.0 | DV Opaque Referral | dv-opaque-referral | VAWA zero-PII tokens, warm handoff |
| v0.10.1 | DV Address Redaction | dv-address-redaction | Configurable tenant visibility policy |
| v0.11.0 | HMIS Bridge | hmis-bridge | Async HMIS push, DV aggregation |

**Historical note:** This document was originally written before
v0.12.0 shipped. The "Suggested next tag" line below is preserved
for chronology but is no longer current — the codebase is at
**v0.52.0 live** with **v0.53.0 in PR review** (PR #164, Phase G-4
platform admin split). Each release v0.16+ has its own
`docs/oracle-update-notes-v0.X.Y.md` runbook in the code repo;
the strategy described in this doc has held throughout.

> *Original suggestion (v0.12.0 — CoC Analytics + WCAG + Hold
> Duration Config — these three shipped together in the week of
> March 24-27 2026.)*

---

## Two Repos, Two Changelogs

Maintain separate changelogs for the code and docs repos. They serve different
audiences and don't always tag at the same time.

**`finding-a-bed-tonight/CHANGELOG.md`** — technical changelog
- Audience: developers, operators, city IT officers
- Content: API changes, DB migrations, security fixes, performance changes,
  breaking changes, env var additions
- Level of detail: technical, specific

**`findABed/CHANGELOG.md`** — capability changelog
- Audience: CoC admins, city officials, funders, shelter operators
- Content: what the platform can do now that it couldn't before, what
  changed in workflows, what documentation was added
- Level of detail: plain English, no schema references

Example of the same release in each:

*Code repo:*
```
## [v0.11.0] — HMIS Bridge
### Added
- `hmis` module: outbox-pattern async push to Clarity, WellSky, ClientTrack
- V22 migration: 4 new tables (hmis_outbox, hmis_audit_log, ...)
- HmisPushScheduler: @Scheduled hourly poll of outbox
- DV aggregation: individual DV shelter counts never transmitted
```

*Docs repo:*
```
## [v0.11.0] — HMIS Bridge
### Added
- Shelter availability data can now be automatically sent to your HMIS
  system (Clarity, WellSky, or ClientTrack) on a nightly schedule
- Administrators can preview what data will be sent before pushing
- Domestic violence shelter data is protected — individual shelter
  counts are never transmitted to HMIS, only aggregated totals
```

---

## Maintenance Workflow

The weekly activity report you already produce is most of the raw material
for release notes. The workflow is:

1. When you cut a tag, spend 5 minutes writing the GitHub Release notes
   from the weekly report
2. Paste the same content (technical version) into `CHANGELOG.md` at the top
3. Paste a plain-English version into `findABed/CHANGELOG.md`

The OpenSpec archive entry for each change also contains most of the
content needed — task count, capability summary, and test counts.

---

## Governance Note (Casey Drummond)

Release notes become part of the project's public record. When a city IT
officer or program officer evaluates the project, they read the release
history. Consistent, clear release notes — even brief ones — signal a
maintained project with accountable stewardship. Gaps in the release
history signal the opposite.

Two specific items to always include for FABT releases:

1. **Any change to DV data handling** — state explicitly what changed
   and confirm the protection model is intact. DV shelter operators
   and their legal counsel will read these.
2. **Any change to env vars or DB migrations** — operators need to know
   what manual steps are required before upgrading. A migration that
   silently changes behavior without a changelog entry creates support
   burden and erodes trust.

---

## Files to Create

| File | Repo | Action |
|---|---|---|
| `CHANGELOG.md` | `finding-a-bed-tonight` | Create, backfill v0.1.0–v0.11.0 |
| `CHANGELOG.md` | `findABed` | Create, plain-English versions |
| GitHub Releases | Both repos | Create for each existing tag |

---

*Finding A Bed Tonight — Release Notes Strategy*
*Alex Chen · Jordan Reyes · Casey Drummond*
*March 2026*
