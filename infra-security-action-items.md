# Infrastructure & Security Review — Action Items
**Reviewer:** Site Reliability Engineering  
**Date:** March 2026  
**Scope:** `security-remediation-2026-03-20.md` + `infra/terraform/` (structural assessment)  
**Repos:** `ccradle/finding-a-bed-tonight` · `ccradle/findABed`

---

## TL;DR

The security posture at this stage is better than most open-source civic tech
projects at equivalent maturity. Four Semgrep findings were caught, fixed, and
documented with correct rationale before public launch. The Terraform module
structure is sound. Eight action items follow — one immediate, three before
pilot go-live, four deferred but tracked.

---

## Immediate (Before Next Commit)

### ACTION-1 — Delete `security-remediation-2026-03-20.md`

**Priority:** Immediate  
**Effort:** 2 minutes  
**File:** `security-remediation-2026-03-20.md` (repo root)

Delete this file. The remediations are complete. Keeping a dated remediation
doc in the repo root creates confusion for contributors who will find it and
wonder whether it's still relevant, already applied, or describing an open
risk.

The correct long-term home for this information is:
- **Git history** — the commit that applied the fixes is the audit trail
- **CI scan results** — Semgrep/OWASP reports are evidence of closure
- **This document** — a summary of what was found and fixed is preserved here

```bash
git rm security-remediation-2026-03-20.md
git commit -m "chore: remove security remediation working doc — findings closed, history in git log"
```

---

## Before Pilot Go-Live (Pre-Raleigh)

### ACTION-2 — Add `deletion_protection_enabled` to DynamoDB state lock table

**Priority:** High  
**Effort:** 5 minutes  
**File:** `infra/terraform/bootstrap/main.tf`

The bootstrap DynamoDB table (state lock) already has encryption and PITR
enabled (Finding 1 fix). Add one more line:

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  # ... existing config ...
  deletion_protection_enabled = true   # ADD THIS
}
```

**Why it matters:** If someone runs `terraform destroy` on the bootstrap stack
— accidentally or during cleanup — losing the lock table means losing the
ability to coordinate Terraform state across all contributors and CI runs.
Recovery requires manual state surgery. `deletion_protection_enabled` prevents
accidental destruction at zero cost. This cannot be set after the fact without
disabling it first, which is the point.

**Note:** This requires a `terraform apply` on the bootstrap stack, not the
main stack.

---

### ACTION-3 — Add OWASP dependency CVE gate to CI pipeline

**Priority:** High  
**Effort:** 30 minutes  
**File:** `.github/workflows/ci.yml` + `backend/pom.xml`

The security scan summary shows **90 medium dependency CVEs** from OWASP
dependency check. "Medium" in OWASP's mapping covers CVSS scores from 4.0 to
8.9 — a range that includes issues bordering on HIGH. Right now these are
reported but not gates; the build passes regardless.

**Step 1:** Add a fail threshold to the Maven OWASP plugin in `pom.xml`:

```xml
<plugin>
  <groupId>org.owasp</groupId>
  <artifactId>dependency-check-maven</artifactId>
  <configuration>
    <failBuildOnCVSS>7</failBuildOnCVSS>   <!-- fail on HIGH and CRITICAL -->
    <suppressionFile>owasp-suppressions.xml</suppressionFile>
  </configuration>
</plugin>
```

**Step 2:** Create `backend/owasp-suppressions.xml` to suppress known
false-positives with documented rationale. Each suppression must include a
`<notes>` block explaining why it is suppressed and a review date.

**Step 3:** Add to CI pipeline:

```yaml
- name: OWASP Dependency Check
  run: mvn dependency-check:check -DfailBuildOnCVSS=7
```

**Why it matters:** A passive report that never fails the build is not a
security gate — it is a report that gets ignored. The 90 current mediums need
to be triaged: legitimate suppressions documented, anything scoring ≥ 7.0
either patched or explicitly accepted with a date for re-evaluation.

---

### ACTION-4 — Verify four Terraform security posture items

**Priority:** High  
**Effort:** 30 minutes (review) + fixes as needed  
**Files:** `modules/app/main.tf`, `modules/postgres/main.tf`, `modules/network/main.tf`

The Terraform module structure is correct but four specific items could not
be verified from the repo without direct file access. These must be confirmed
before the pilot deployment is provisioned. Paste the three `main.tf` files
into the team chat or share them directly for a line-level review.

**Item 4a — ECS task role vs. execution role separation**

Two separate IAM roles are required:

| Role | Purpose | Minimum permissions |
|---|---|---|
| **Execution role** | ECS agent pulling images and writing logs | `ecr:GetAuthorizationToken`, `logs:CreateLogStream`, `logs:PutLogEvents`, `secretsmanager:GetSecretValue` |
| **Task role** | Application code at runtime | RDS access (via Secrets Manager), nothing else |

Conflating these two into a single role is one of the most common ECS IAM
misconfigurations in practice. The task role should never have ECR or
CloudWatch permissions. The execution role should never have application-level
permissions.

**Item 4b — RDS instance not publicly accessible**

Confirm `publicly_accessible = false` is set on the RDS instance and the
instance is in a **private subnet**, reachable only from the ECS task
security group. Given Finding 3 concerned public subnet auto-IP assignment,
this needs explicit verification.

```hcl
resource "aws_db_instance" "postgres" {
  publicly_accessible = false   # MUST be present and false
  db_subnet_group_name = aws_db_subnet_group.private.name
  # ...
}
```

**Item 4c — Credentials via Secrets Manager, not environment variables**

Hard rule from `CLAUDE-CODE-BRIEF.md`: no secrets in `application.yml` or
environment variables committed to Git. Confirm the ECS task definition
injects database credentials as ECS secrets (pulled from AWS Secrets Manager
at task start) — not as plaintext `environment` entries in the task definition.

```hcl
# CORRECT pattern in ECS task definition
secrets = [
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = aws_secretsmanager_secret.db_password.arn
  }
]
# NOT this:
# environment = [{ name = "DB_PASSWORD", value = "plaintext" }]
```

**Item 4d — Security group least privilege (three rules)**

Verify the security group chain is tight:

```
Internet → ALB SG (443, 80 from 0.0.0.0/0)
ALB SG  → ECS Task SG (8080 from ALB SG only)
ECS SG  → RDS SG (5432 from ECS Task SG only)
```

No security group should have `0.0.0.0/0` as an ingress source except the
ALB on ports 80 and 443. A single misconfigured `0.0.0.0/0` ingress on the
RDS security group would expose the database directly to the internet.

---

## Deferred — Track for Upcoming Changes

### ACTION-5 — Add `"iam"` to RDS CloudWatch log exports (oauth2-redirect-flow)

**Priority:** Medium  
**Effort:** 5 minutes  
**File:** `modules/postgres/main.tf`  
**Target change:** `oauth2-redirect-flow`

Finding 4 added `["postgresql", "upgrade"]` log exports. When IAM
authentication is enabled for OAuth2 (the upcoming `oauth2-redirect-flow`
change), add `"iam"` to this list:

```hcl
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade", "iam"]
```

IAM authentication events become useful for the audit trail once OAuth2
provider integration is live. Add this as a task in the `oauth2-redirect-flow`
OpenSpec change, not now.

---

### ACTION-6 — Add CloudWatch alarms for the three behavioral monitors

**Priority:** Medium  
**Effort:** 2–3 hours  
**File:** New `modules/monitoring/main.tf`  
**Target change:** New OpenSpec change `operational-monitoring`

Three behavioral monitors were identified during the initial architecture
review that are not yet implemented anywhere in the Terraform or application
code. These are not infrastructure uptime monitors — they are data quality
and operational state monitors specific to this domain.

**Monitor 1 — Stale shelter data detection**

```
Alert: Any active shelter has not published an availability snapshot
       in more than 8 hours.
Mechanism: Scheduled query job → custom CloudWatch metric →
           CloudWatch alarm → SNS → email/Slack to onboarding team.
Severity: Non-paging (business hours notification, not 3am page).
Action: Onboarding lead follows up with shelter coordinator.
```

**Monitor 2 — DV shelter misclassification canary**

```
Alert: A shelter with dv_shelter = true appears in a public
       /api/v1/queries/beds response.
Mechanism: Post-deployment Lambda canary → runs after every deploy →
           asserts zero DV shelters in public query results →
           CloudWatch alarm on failure → pages immediately.
Severity: PAGING. This is a data breach condition.
Action: Immediate investigation. Take the shelter offline if confirmed.
```

**Monitor 3 — Temperature / surge gap alert**

```
Alert: Ambient temperature at pilot city drops below 32°F and no
       active SurgeEvent exists in the database.
Mechanism: Lambda on cron (hourly in winter) → queries NOAA API for
           pilot city temperature → queries /api/v1/surge-events for
           active events → publishes mismatch metric →
           CloudWatch alarm → SNS → email to CoC admin contact.
Severity: Non-paging (human decision required; alert, do not auto-activate).
Action: CoC admin reviews and activates surge event if appropriate.
Note: Implement after surge-mode OpenSpec change is complete.
```

Monitors 1 and 2 can be built now. Monitor 3 depends on the `surge-mode`
OpenSpec change being complete. A new `operational-monitoring` OpenSpec change
should spec and task all three together.

---

### ACTION-7 — Add ALB access logging

**Priority:** Low  
**Effort:** 15 minutes  
**File:** `modules/app/main.tf`  
**Target change:** `operational-monitoring`

ALB access logs are not enabled by default and are not currently in the
Terraform. They are the primary forensic record for any incident involving
the public-facing API — who called what endpoint, when, from which IP, with
what response code.

```hcl
resource "aws_alb" "main" {
  # ... existing config ...
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "fabt-alb"
    enabled = true
  }
}
```

S3 storage cost for ALB logs is negligible at pilot scale (< $1/month).
Add a lifecycle rule to expire logs after 90 days. Bundle this into the
`operational-monitoring` OpenSpec change alongside ACTION-6.

---

### ACTION-8 — GCP and on-prem deployment variants

**Priority:** Low  
**Effort:** Multi-week  
**Files:** New `infra/terraform/gcp/` + new `infra/docker/compose-prod.yml`  
**Target:** Phase 2 — after Raleigh pilot validates the platform

Some cities — particularly smaller ones, or those with strict data residency
requirements — cannot deploy to AWS. Two alternative deployment paths are
needed for broad adoption:

**GCP variant:** Cloud Run (equivalent to ECS Fargate), Cloud SQL (PostgreSQL),
Memorystore (Redis), Pub/Sub (Kafka equivalent for Full tier). The application
has no AWS-specific dependencies — the managed service choices are swappable.
Estimated Terraform effort: 2–3 weeks for an experienced GCP practitioner.

**On-prem / self-hosted variant:** Production-grade Docker Compose with
PostgreSQL, Redis, and optional Kafka as containers. Health checks, restart
policies, log rotation, and backup scripts. The `docker-compose.yml` already
exists for local dev — the on-prem variant adds persistent volume configuration,
environment variable management via `.env` files (not committed), and a basic
backup script for the PostgreSQL volume. Estimated effort: 3–5 days.

Both variants should wait until the Raleigh pilot has validated the core
platform under real-world conditions. Building deployment variants before the
core is proven is premature optimization.

---

## Summary Table

| # | Action | Priority | Effort | When |
|---|---|---|---|---|
| ACTION-1 | Delete `security-remediation-2026-03-20.md` | Immediate | 2 min | Now |
| ACTION-2 | DynamoDB `deletion_protection_enabled` | High | 5 min | Before pilot |
| ACTION-3 | OWASP CVE gate in CI (`failBuildOnCVSS=7`) | High | 30 min | Before pilot |
| ACTION-4 | Verify 4 Terraform security posture items | High | 30 min + | Before pilot |
| ACTION-5 | Add `"iam"` to RDS log exports | Medium | 5 min | `oauth2-redirect-flow` change |
| ACTION-6 | Three behavioral monitors (CloudWatch) | Medium | 2–3 hrs | `operational-monitoring` change |
| ACTION-7 | ALB access logging | Low | 15 min | `operational-monitoring` change |
| ACTION-8 | GCP + on-prem deployment variants | Low | Weeks | Phase 2 post-pilot |

---

## Suggested New OpenSpec Change

**`operational-monitoring`** — Spec and implement the three behavioral
monitors (ACTION-6) and ALB access logging (ACTION-7) as a single bounded
change. Estimated task count: 8–12. Can start after `asyncapi-contract-hardening`
is archived.

Proposed tasks:
- [ ] `modules/monitoring/main.tf` — CloudWatch metric filter for shelter data age
- [ ] Scheduled job publishing `shelter_last_updated_age_seconds` per shelter
- [ ] CloudWatch alarm + SNS for stale data (non-paging, 8-hour threshold)
- [ ] Lambda canary for DV shelter public query assertion (post-deploy)
- [ ] CloudWatch alarm + SNS for DV canary failure (paging)
- [ ] NOAA temperature feed Lambda (implement after `surge-mode` is complete)
- [ ] CloudWatch alarm + SNS for temperature/surge gap (non-paging, hourly)
- [ ] ALB access logging S3 bucket + lifecycle policy + `modules/app/main.tf` update
- [ ] `docs/runbook.md` — operational runbook covering all three alert types

---

*Finding A Bed Tonight — SRE Review*  
*github.com/ccradle/finding-a-bed-tonight*
