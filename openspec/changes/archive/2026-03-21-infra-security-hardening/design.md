## Context

The Terraform infrastructure was reviewed by SRE after the security scan remediation (build #32). The four Semgrep findings were already fixed. Three additional high-priority items were identified as pre-pilot blockers that don't involve application code.

## Goals / Non-Goals

**Goals:**
- DynamoDB deletion protection on state lock table
- OWASP dependency CVE gate in CI (fail on CVSS >= 7)
- Verified Terraform security posture (4 items)

**Non-Goals:**
- Application code changes
- CloudWatch monitoring (separate `operational-monitoring` change)
- ALB access logging (separate `operational-monitoring` change)
- GCP/on-prem variants (Phase 2)

## Decisions

### D1: DynamoDB deletion protection

Add `deletion_protection_enabled = true` to the bootstrap DynamoDB state lock table. This prevents accidental destruction via `terraform destroy`. Recovery from a lost lock table requires manual state surgery.

### D2: OWASP CVE gate at CVSS 7+

Add `dependency-check-maven` plugin with `failBuildOnCVSS=7` to `pom.xml`. This gates the build on HIGH and CRITICAL CVEs while allowing MEDIUM to be reported without blocking. Known false-positives are suppressed in `owasp-suppressions.xml` with documented rationale and review dates.

### D3: Terraform security posture verification

Four items to verify and fix in the Terraform modules:

1. **ECS task role vs execution role separation** — Two distinct IAM roles: execution role (ECR pull, CloudWatch logs, Secrets Manager) and task role (RDS access only). Must not be conflated.
2. **RDS not publicly accessible** — `publicly_accessible = false`, instance in private subnet only.
3. **Credentials via Secrets Manager** — ECS task definition uses `secrets` block (Secrets Manager ARN), never plaintext `environment` entries.
4. **Security group least privilege** — Internet→ALB(443/80), ALB→ECS(8080), ECS→RDS(5432). No `0.0.0.0/0` ingress on ECS or RDS security groups.
