# FABT Weekly Report — Addendum

**Date:** Thursday Mar 27, 2026
**Corrects/supplements:** The original weekly report (delivered verbally, now superseded)
**Primary audience:** Jordan Reyes (SRE) | Also relevant to: Riley (QA), Sam (Perf), Casey (Legal), Teresa (City IT)

---

## TL;DR

The Java 25 migration is on `main` and fully deployed — not on a feature branch as originally reported. We found and fixed stale deployment artifacts, a long-standing shutdown hang, and a CI failure. All tests pass. The project now has a CHANGELOG, GitHub Releases, and a README with table of contents and dashboard documentation. Tagged **v0.14.1**.

---

## Correction: Java 25 Migration Status

The original report stated the Java 25 / Spring Boot 4.0 migration was "on a feature branch — not yet merged." **This was incorrect.**

The migration was committed directly to `main` in the code repo on Thu Mar 26 at 9:42 PM. The `feature/java25-boot4-virtual-threads` branch existed only in the docs repo for OpenSpec tracking and was already identical to `main`. That branch has been deleted.

---

## Issues Found and Fixed

### 1. Stale Java 21 References (v0.14.1)

Two files were missed during the Java 25 migration:

| File | Was | Now |
|------|-----|-----|
| `infra/docker/Dockerfile.backend` | `eclipse-temurin:21-jre-alpine` | `eclipse-temurin:25-jre-alpine` |
| `e2e/gatling/pom.xml` | `maven.compiler.source/target: 21` | `maven.compiler.release: 25` |

**Jordan:** The Docker image would have built with JDK 21 despite the app requiring 25. Fixed and verified.

### 2. Gatling CI Failure — ASM Bytecode Version (v0.14.1)

Gatling 3.11.5 shipped with an older ASM that couldn't read Java 25 class files (version 69). CI failed with `Unsupported class file major version 69`.

**Fix:** Upgraded Gatling 3.11.5 → 3.14.9, plugin 4.9.6 → 4.21.5. Gatling 3.14.9 supports JDK 11–25.

### 3. Spring Boot Shutdown Hang — Root Cause Analysis (v0.14.1)

The backend process refused to stop when killed via `dev-start.sh stop`. This had been happening since the Java 25 migration. **Five contributing causes identified:**

| # | Cause | Fix |
|---|-------|-----|
| 1 | **`dev-start.sh` killed Maven, not the JVM.** `spring-boot:run` always forks a child JVM since Boot 3.0. `$!` captured Maven's PID; the actual JVM on port 8080 was orphaned. | Stop command now finds the JVM by port (`netstat` on Windows, `lsof` on Linux) |
| 2 | **No graceful shutdown configured.** Without `server.shutdown=graceful`, Spring doesn't drain in-flight requests or notify lifecycle beans. | Added `server.shutdown=graceful` + `spring.lifecycle.timeout-per-shutdown-phase=30s` |
| 3 | **`SimpleAsyncTaskScheduler` had no termination timeout.** Without `taskTerminationTimeout`, the scheduler doesn't interrupt running `@Scheduled` tasks on shutdown. | Added `taskTerminationTimeout(30_000)` to `VirtualThreadConfig` |
| 4 | **`BoundedFanOut` had a 5-minute await.** If shutdown hit mid-fan-out, the executor blocked for up to 5 minutes. | Reduced to 60s with `shutdownNow()` escalation |
| 5 | **Git Bash `kill` can't signal Windows PIDs.** POSIX `kill` in MSYS2/Git Bash doesn't translate to Windows process signals. | Platform detection: PowerShell `Stop-Process` on Windows, POSIX `kill` on Linux/macOS |

**Result:** Shutdown after a full 25-test Karate run now completes in **~1 second** (was 36+ seconds with force-kill).

**Jordan:** The `dev-start.sh stop` fix is cross-platform. On Linux CI runners, it uses `lsof`/`kill` as expected. On Windows dev machines, it uses PowerShell. Both paths tested.

### 4. `JAVA_HOME` Mismatch (Developer Documentation)

The system `JAVA_HOME` environment variable still points to JDK 21. Maven uses `JAVA_HOME`, not `PATH`. The `java` command on PATH resolves to JDK 25 correctly, but `mvn` commands fail unless `JAVA_HOME` is set:

```
JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.1.8-hotspot
```

CI workflows are correct (`java-version: '25'` in all jobs). This only affects local development.

---

## Test Results — Final State

All test suites green on JDK 25.0.1 (local) and JDK 25.0.2 (GitHub Actions):

| Suite | Count | Result |
|-------|-------|--------|
| Backend unit/integration | 236 | All passed |
| Frontend build (TypeScript) | — | Clean, PWA generated |
| Karate e2e (API + observability) | 25 | All passed |
| Playwright e2e (UI + a11y + screen reader) | 114 | All passed |
| Gatling performance | 1,945 requests | 0 failures, 76ms p95 |
| **CI: DV Access Control Canary** | — | **Passed** |
| **CI: E2E (Playwright + Karate)** | — | **Passed** |
| **CI: Performance (Gatling)** | — | **Passed** |
| **CI: CodeQL** | — | **Passed** |

---

## New Project Infrastructure

### CHANGELOG.md (Both Repos)

Full backfill from v0.1.0-foundation through v0.14.1.

- **Code repo** (`finding-a-bed-tonight/CHANGELOG.md`): Technical, Keep a Changelog format. Migrations, API changes, security fixes.
- **Docs repo** (`findABed/CHANGELOG.md`): Plain-English capability changelog for non-technical audiences (CoC admins, city officials, funders).

### GitHub Releases

Three milestone releases created on the code repo:

| Release | Title | Notes |
|---------|-------|-------|
| [v0.13.0](https://github.com/ccradle/finding-a-bed-tonight/releases/tag/v0.13.0) | WCAG 2.1 AA Accessibility | First accessibility-complete build |
| [v0.14.0](https://github.com/ccradle/finding-a-bed-tonight/releases/tag/v0.14.0) | Java 25 + Spring Boot 4.0 | Runtime modernization |
| [v0.14.1](https://github.com/ccradle/finding-a-bed-tonight/releases/tag/v0.14.1) | Shutdown Fixes + Release Notes | Current (Latest) |

Earlier tags (v0.1.0–v0.12.1) are preserved in git but not published as GitHub Releases — they represent incremental development before the platform was demo-ready.

### README Improvements

- **Table of contents** with anchor links to all 24 sections
- **Guides & Policy Documents** moved from under Database Schema to right after Business Value — funders and city IT officers see it immediately
- **Grafana Dashboards section** documenting all 5 dashboards:

| Dashboard | Purpose |
|-----------|---------|
| FABT Operations | Search rate, latency, availability, reservations, DV canary, surge, webhooks |
| DV Referrals | Referral volume, acceptance/rejection rates, token lifecycle (separate for DV sensitivity) |
| HMIS Bridge | Push success/failure, outbox queue, vendor latency |
| CoC Analytics | Utilization, zero-result rate, capacity trend, batch job metrics |
| Virtual Threads | Pool utilization, connection pool gauges, BoundedFanOut concurrency |

---

## Updated Risk Items for Jordan

| # | Item | Status |
|---|------|--------|
| 1 | ~~Java 25 not merged~~ | **Resolved.** On `main`, Dockerfile fixed, CI green. |
| 2 | Spring Batch schema (V24) is new | Monitor for unexpected growth. *(unchanged)* |
| 3 | HMIS outbox polling | Alerting rules not yet configured. *(unchanged)* |
| 4 | JWT payload changed | `tenantName` claim added in v0.13.1. *(unchanged)* |
| 5 | ~~Swagger UI bypasses auth~~ | `web.ignoring()` for static resources only. API endpoints still authenticated. *(downgraded)* |
| 6 | 6 DB migrations in 4 days (V22–V26 + V25 index) | Test clean-DB scenario before fresh deploys. *(unchanged)* |
| 7 | ~~`JAVA_HOME` mismatch~~ | Documented. CI correct. Developer machines need manual update. |
| 8 | ~~Shutdown hang~~ | **Resolved.** Graceful shutdown in ~1s under load. |

---

## Commits Since Tuesday 1 AM (Final Count)

| Repo | Commits | Tags |
|------|---------|------|
| `finding-a-bed-tonight` (code) | 44 | v0.14.0, v0.14.1 |
| `findABed` (docs) | 19 | v0.14.1 |

---

*Addendum generated 2026-03-27 by Claude Code. Source: git log analysis, CI results, and local test verification across both FABT repositories.*
