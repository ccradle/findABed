## Why

An SRE review identified three high-priority infrastructure security items that must be addressed before the Raleigh pilot go-live: DynamoDB state lock table lacks deletion protection (accidental `terraform destroy` could corrupt state coordination), OWASP dependency CVEs are reported but not gated (90 mediums pass silently), and four Terraform security posture items need explicit verification (IAM role separation, RDS public access, Secrets Manager, security group chain).

## What Changes

- Add `deletion_protection_enabled = true` to DynamoDB state lock table in `bootstrap/main.tf`
- Add OWASP dependency-check Maven plugin with `failBuildOnCVSS=7` gate + suppressions file
- Add OWASP check step to CI pipeline (`.github/workflows/ci.yml`)
- Verify and fix 4 Terraform security posture items: ECS task/execution role separation, RDS `publicly_accessible = false`, credentials via Secrets Manager, security group least-privilege chain

## Capabilities

### New Capabilities

_(none — infrastructure hardening only)_

### Modified Capabilities

- `deployment-profiles`: Terraform modules hardened with deletion protection, IAM separation, and security group verification

## Impact

- **Modified files**: `infra/terraform/bootstrap/main.tf`, `infra/terraform/modules/app/main.tf`, `infra/terraform/modules/postgres/main.tf`, `infra/terraform/modules/network/main.tf`, `backend/pom.xml`, `.github/workflows/ci.yml`
- **New file**: `backend/owasp-suppressions.xml`
- **No application code changes**
- **Requires `terraform apply` on bootstrap stack** for deletion protection
